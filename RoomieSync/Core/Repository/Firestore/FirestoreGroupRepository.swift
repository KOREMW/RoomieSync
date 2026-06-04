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

public actor FirestoreGroupRepository: GroupRepositoryProtocol {
    /// 그룹 최대 인원 (SwiftData 구현과 동일).
    private static let maxMembers = 6

    // Firestore 인스턴스는 내부적으로 스레드-세이프하며, runTransaction 의 escaping 클로저로
    // 전달해야 하므로 nonisolated(unsafe) 로 둔다.
    nonisolated(unsafe) private let db = Firestore.firestore()
    private var groups: CollectionReference { db.collection("groups") }
    private var membersCol: CollectionReference { db.collection("members") }

    public init() {}

    public func createGroup(name: String, hostName: String, hostAvatarColorHex: String) async throws -> Group {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let groupID = UUID()
        let host = Member(name: hostName, avatarColorHex: hostAvatarColorHex, groupID: groupID)
        let group = Group(id: groupID, name: name,
                          inviteCode: Group.generateInviteCode(), memberIDs: [host.id])
        try await groups.document(groupID.uuidString).setData(group.fsDict)
        try await membersCol.document(host.id.uuidString).setData(host.fsDict)
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

    public func addMember(toGroup groupID: UUID, name: String, avatarColorHex: String) async throws -> Member {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let member = Member(name: name, avatarColorHex: avatarColorHex, groupID: groupID)
        let groupRef = groups.document(groupID.uuidString)
        let memberRef = membersCol.document(member.id.uuidString)
        let memberDict = member.fsDict
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
                transaction.updateData(["memberIDs": FieldValue.arrayUnion([newMemberIDString])],
                                       forDocument: groupRef)
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
        try await ref.delete()
        let groupRef = groups.document(member.groupID.uuidString)
        let gdoc = try await groupRef.getDocument()
        if let gdata = gdoc.data(), var group = Group(fs: gdata) {
            group.memberIDs.removeAll { $0 == memberID }
            try await groupRef.updateData(["memberIDs": FSMap.ids(group.memberIDs)])
        }
    }

    public func deleteGroup(_ groupID: UUID) async throws {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let gid = groupID.uuidString
        for col in ["members", "chores", "choreCompletions", "expenses", "settlements"] {
            let docs = try await db.collection(col).whereField("groupID", isEqualTo: gid).getDocuments()
            for d in docs.documents { try await d.reference.delete() }
        }
        try await groups.document(gid).delete()
    }

    public func fetchAllGroups() async throws -> [Group] {
        await FirebaseAuthGate.shared.ensureSignedIn()
        // PoC: 인증/멤버십 스코프가 없어 전체 groups 를 반환.
        let snap = try await groups.getDocuments()
        return snap.documents.compactMap { Group(fs: $0.data()) }
    }
}
#endif
