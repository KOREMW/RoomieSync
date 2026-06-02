//
//  FirestoreGroupRepository.swift
//  RoomieSync
//
//  GroupRepositoryProtocol 의 Cloud Firestore 구현 (CloudKit 대안 백엔드).
//  구조: groups/{groupId} 문서 + 하위 컬렉션 members/chores/choreCompletions/expenses/settlements.
//  초대 코드 조회가 서버에서 동작하므로, "초대 코드로 참여"가 기기·계정 간에 실제로 작동한다.
//
//  Firebase SDK 미링크 시에도 컴파일되도록 canImport 가드.
//

#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

public actor FirestoreGroupRepository: GroupRepositoryProtocol {
    private let db = Firestore.firestore()
    private var groups: CollectionReference { db.collection("groups") }

    public init() {}

    public func createGroup(name: String, hostName: String, hostAvatarColorHex: String) async throws -> Group {
        let groupID = UUID()
        let host = Member(name: hostName, avatarColorHex: hostAvatarColorHex, groupID: groupID)
        let group = Group(id: groupID, name: name,
                          inviteCode: Group.generateInviteCode(), memberIDs: [host.id])
        let groupRef = groups.document(groupID.uuidString)
        try await groupRef.setData(group.fsDict)
        try await groupRef.collection("members").document(host.id.uuidString).setData(host.fsDict)
        return group
    }

    public func findGroup(byInviteCode code: String) async throws -> Group {
        let snap = try await groups
            .whereField("inviteCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first, let group = Group(fs: doc.data()) else {
            throw RepositoryError.notFound
        }
        return group
    }

    public func fetchGroup(id: UUID) async throws -> Group {
        let doc = try await groups.document(id.uuidString).getDocument()
        guard let data = doc.data(), let group = Group(fs: data) else { throw RepositoryError.notFound }
        return group
    }

    public func addMember(toGroup groupID: UUID, name: String, avatarColorHex: String) async throws -> Member {
        let groupRef = groups.document(groupID.uuidString)
        let doc = try await groupRef.getDocument()
        guard let data = doc.data(), var group = Group(fs: data) else { throw RepositoryError.notFound }
        let member = Member(name: name, avatarColorHex: avatarColorHex, groupID: groupID)
        try await groupRef.collection("members").document(member.id.uuidString).setData(member.fsDict)
        group.memberIDs.append(member.id)
        try await groupRef.updateData(["memberIDs": FSMap.ids(group.memberIDs)])
        return member
    }

    public func updateMemberName(_ memberID: UUID, name: String) async throws -> Member {
        let snap = try await db.collectionGroup("members")
            .whereField("id", isEqualTo: memberID.uuidString)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first, var member = Member(fs: doc.data()) else {
            throw RepositoryError.notFound
        }
        try await doc.reference.updateData(["name": name])
        member.name = name
        return member
    }

    public func fetchMembers(ofGroup groupID: UUID) async throws -> [Member] {
        let snap = try await groups.document(groupID.uuidString).collection("members").getDocuments()
        return snap.documents.compactMap { Member(fs: $0.data()) }.sorted { $0.joinedAt < $1.joinedAt }
    }

    public func removeMember(_ memberID: UUID) async throws {
        // groupID 를 모르므로 collectionGroup 으로 위치 탐색.
        let snap = try await db.collectionGroup("members")
            .whereField("id", isEqualTo: memberID.uuidString)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first else { throw RepositoryError.notFound }
        let memberRef = doc.reference
        let groupRef = memberRef.parent.parent   // members 컬렉션의 부모 = group 문서
        try await memberRef.delete()
        if let groupRef {
            let groupDoc = try await groupRef.getDocument()
            if let data = groupDoc.data(), var group = Group(fs: data) {
                group.memberIDs.removeAll { $0 == memberID }
                try await groupRef.updateData(["memberIDs": FSMap.ids(group.memberIDs)])
            }
        }
    }

    public func deleteGroup(_ groupID: UUID) async throws {
        let groupRef = groups.document(groupID.uuidString)
        // Firestore 는 하위 컬렉션을 cascade 삭제하지 않으므로 best-effort 로 정리.
        for sub in ["members", "chores", "choreCompletions", "expenses", "settlements"] {
            let docs = try await groupRef.collection(sub).getDocuments()
            for d in docs.documents { try await d.reference.delete() }
        }
        try await groupRef.delete()
    }

    public func fetchAllGroups() async throws -> [Group] {
        // PoC: 인증/멤버십 스코프가 없어 전체 groups 를 반환한다.
        // 운영에서는 인증 + membership 쿼리(예: memberIDs arrayContains uid)로 한정해야 함.
        let snap = try await groups.getDocuments()
        return snap.documents.compactMap { Group(fs: $0.data()) }
    }
}
#endif
