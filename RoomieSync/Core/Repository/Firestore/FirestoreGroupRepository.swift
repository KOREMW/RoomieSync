//
//  FirestoreGroupRepository.swift
//  RoomieSync
//
//  GroupRepositoryProtocol 의 Cloud Firestore 구현 (CloudKit 대안 백엔드).
//
//  구조: 모든 엔티티를 최상위(top-level) 컬렉션에 두고 groupID 필드로 구분한다.
//   groups/{id} · members/{id} · chores/{id} · choreCompletions/{id} · expenses/{id} · settlements/{id}
//  → by-id 는 document(id) 직접 접근, 그룹별 조회는 whereField("groupID") 단일 필드 쿼리만 사용해
//     collectionGroup(별도 인덱스 필요) 의존을 제거한다.
//

#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

public actor FirestoreGroupRepository: GroupRepositoryProtocol {
    /// 그룹 최대 인원 (SwiftData 구현과 동일).
    private static let maxMembers = 6

    /// 현재 익명 인증 사용자의 uid. 멤버십 기반 그룹 격리(#14)에 사용.
    private func currentUID() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    // Firestore 인스턴스는 내부적으로 스레드-세이프하며, runTransaction 의 escaping 클로저로
    // 전달해야 하므로 nonisolated(unsafe) 로 둔다.
    nonisolated(unsafe) private let db = Firestore.firestore()
    private var groups: CollectionReference { db.collection("groups") }
    private var membersCol: CollectionReference { db.collection("members") }
    private var notesCol: CollectionReference { db.collection("notes") }

    public init() {}

    public func createGroup(name: String, hostName: String, hostAvatarColorHex: String) async throws -> Group {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let groupID = UUID()
        let host = Member(name: hostName, avatarColorHex: hostAvatarColorHex, groupID: groupID)
        let group = Group(id: groupID, name: name,
                          inviteCode: Group.generateInviteCode(), memberIDs: [host.id])
        let uid = currentUID()
        // 그룹 격리(#14): 그룹 doc 에 멤버 uid 목록, 멤버 doc 에 소유 uid 기록.
        var groupDict = group.fsDict
        groupDict["memberUIDs"] = uid.map { [$0] } ?? []
        var hostDict = host.fsDict
        if let uid { hostDict["ownerUID"] = uid }
        try await groups.document(groupID.uuidString).setData(groupDict)
        try await membersCol.document(host.id.uuidString).setData(hostDict)
        return group
    }

    public func findGroup(byInviteCode code: String) async throws -> Group {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let snap = try await groups.whereField("inviteCode", isEqualTo: code).limit(to: 1).getDocuments()
        guard let doc = snap.documents.first, let group = Group(fs: doc.data()) else {
            throw RepositoryError.notFound
        }
        return group
    }

    public func fetchGroup(id: UUID) async throws -> Group {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let doc = try await groups.document(id.uuidString).getDocument()
        guard let data = doc.data(), let group = Group(fs: data) else { throw RepositoryError.notFound }
        return group
    }

    public func updateGroupInfo(_ groupID: UUID, name: String, icon: String, iconColorHex: String) async throws -> Group {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let ref = groups.document(groupID.uuidString)
        // memberUIDs 등 다른 필드는 건드리지 않도록 부분 업데이트.
        try await ref.updateData(["name": name, "icon": icon, "iconColorHex": iconColorHex])
        let doc = try await ref.getDocument()
        guard let data = doc.data(), let group = Group(fs: data) else { throw RepositoryError.notFound }
        return group
    }

    public func addMember(toGroup groupID: UUID, name: String, avatarColorHex: String) async throws -> Member {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let member = Member(name: name, avatarColorHex: avatarColorHex, groupID: groupID)
        let groupRef = groups.document(groupID.uuidString)
        let memberRef = membersCol.document(member.id.uuidString)
        let uid = currentUID()
        var memberDict = member.fsDict
        if let uid { memberDict["ownerUID"] = uid }   // 격리(#14): 멤버 doc 소유 uid
        let newMemberIDString = member.id.uuidString

        // 트랜잭션으로 "인원수 확인 → 멤버 추가"를 원자적으로 처리한다.
        //  - #1 최대 인원(6명) 초과 방지 (Firestore 에도 SwiftData 와 동일 검증 적용)
        //  - #2 동시 합류 경쟁 방지: memberIDs 를 읽고-쓰는 레이스로 멤버가 누락되지 않도록
        //        트랜잭션 + arrayUnion 으로 원자적 추가.
        do {
            _ = try await db.runTransaction { transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(groupRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                guard let data = snapshot.data(), let group = Group(fs: data) else {
                    errorPointer?.pointee = NSError(domain: "RoomieSync", code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "그룹을 찾을 수 없습니다"])
                    return nil
                }
                guard group.memberIDs.count < Self.maxMembers else {
                    errorPointer?.pointee = NSError(domain: "RoomieSync", code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "그룹 최대 인원(\(Self.maxMembers)명)을 초과했습니다"])
                    return nil
                }
                transaction.setData(memberDict, forDocument: memberRef)
                // 격리(#14): 그룹 memberUIDs 에 합류자 uid 도 원자적으로 추가.
                var groupUpdate: [String: Any] = ["memberIDs": FieldValue.arrayUnion([newMemberIDString])]
                if let uid { groupUpdate["memberUIDs"] = FieldValue.arrayUnion([uid]) }
                transaction.updateData(groupUpdate, forDocument: groupRef)
                return nil
            }
        } catch let error as NSError where error.domain == "RoomieSync" {
            if error.code == 404 { throw RepositoryError.notFound }
            throw RepositoryError.invalidInput(reason: error.localizedDescription)
        }
        return member
    }

    public func updateMemberName(_ memberID: UUID, name: String) async throws -> Member {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let ref = membersCol.document(memberID.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), var member = Member(fs: data) else { throw RepositoryError.notFound }
        try await ref.updateData(["name": name])
        member.name = name
        return member
    }

    public func updateMemberAccount(_ memberID: UUID, bankName: String, accountNumber: String) async throws -> Member {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let ref = membersCol.document(memberID.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), var member = Member(fs: data) else { throw RepositoryError.notFound }
        try await ref.updateData(["bankName": bankName, "accountNumber": accountNumber])
        member.bankName = bankName
        member.accountNumber = accountNumber
        return member
    }

    public func fetchMembers(ofGroup groupID: UUID) async throws -> [Member] {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let snap = try await membersCol.whereField("groupID", isEqualTo: groupID.uuidString).getDocuments()
        return snap.documents.compactMap { Member(fs: $0.data()) }.sorted { $0.joinedAt < $1.joinedAt }
    }

    public func removeMember(_ memberID: UUID) async throws {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let ref = membersCol.document(memberID.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), let member = Member(fs: data) else { throw RepositoryError.notFound }
        let ownerUID = data["ownerUID"] as? String   // 격리(#14): 그룹 memberUIDs 에서 제거할 uid
        try await ref.delete()
        let groupRef = groups.document(member.groupID.uuidString)
        // memberIDs 제거 + memberUIDs 에서 소유 uid 제거(원자적 arrayRemove).
        var update: [String: Any] = ["memberIDs": FieldValue.arrayRemove([memberID.uuidString])]
        if let ownerUID { update["memberUIDs"] = FieldValue.arrayRemove([ownerUID]) }
        try await groupRef.updateData(update)
    }

    public func deleteGroup(_ groupID: UUID) async throws {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let gid = groupID.uuidString
        for col in ["members", "chores", "choreCompletions", "expenses", "settlements", "notes"] {
            let docs = try await db.collection(col).whereField("groupID", isEqualTo: gid).getDocuments()
            for d in docs.documents { try await d.reference.delete() }
        }
        try await groups.document(gid).delete()
    }

    public func fetchAllGroups() async throws -> [Group] {
        await FirebaseAuthGate.shared.ensureSignedIn()
        // 격리(#14): 내 uid 가 memberUIDs 에 포함된 그룹만 반환.
        // (memberUIDs 가 없는 레거시 그룹은 #14 적용 후 접근 대상이 아니므로 제외)
        guard let uid = currentUID() else {
            let snap = try await groups.getDocuments()
            return snap.documents.compactMap { Group(fs: $0.data()) }
        }
        let snap = try await groups.whereField("memberUIDs", arrayContains: uid).getDocuments()
        return snap.documents.compactMap { Group(fs: $0.data()) }
    }

    // MARK: - 공지/메모 (#13)

    public func fetchNotes(groupID: UUID) async throws -> [GroupNote] {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let snap = try await notesCol.whereField("groupID", isEqualTo: groupID.uuidString).getDocuments()
        return snap.documents.compactMap { GroupNote(fs: $0.data()) }
            .sorted { ($0.isPinned ? 1 : 0, $0.createdAt) > ($1.isPinned ? 1 : 0, $1.createdAt) }
    }

    public func addNote(groupID: UUID, authorMemberID: UUID, text: String) async throws -> GroupNote {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let note = GroupNote(groupID: groupID, authorMemberID: authorMemberID, text: text)
        try await notesCol.document(note.id.uuidString).setData(note.fsDict)
        return note
    }

    public func deleteNote(_ noteID: UUID) async throws {
        await FirebaseAuthGate.shared.ensureSignedIn()
        try await notesCol.document(noteID.uuidString).delete()
    }

    public func setNotePinned(_ noteID: UUID, pinned: Bool) async throws -> GroupNote {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let ref = notesCol.document(noteID.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), var note = GroupNote(fs: data) else { throw RepositoryError.notFound }
        try await ref.updateData(["isPinned": pinned])
        note.isPinned = pinned
        return note
    }
}
#endif
