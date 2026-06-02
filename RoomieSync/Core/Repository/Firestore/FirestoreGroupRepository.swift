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
    private let db = Firestore.firestore()
    private var groups: CollectionReference { db.collection("groups") }
    private var membersCol: CollectionReference { db.collection("members") }

    public init() {}

    public func createGroup(name: String, hostName: String, hostAvatarColorHex: String) async throws -> Group {
        let groupID = UUID()
        let host = Member(name: hostName, avatarColorHex: hostAvatarColorHex, groupID: groupID)
        let group = Group(id: groupID, name: name,
                          inviteCode: Group.generateInviteCode(), memberIDs: [host.id])
        try await groups.document(groupID.uuidString).setData(group.fsDict)
        try await membersCol.document(host.id.uuidString).setData(host.fsDict)
        return group
    }

    public func findGroup(byInviteCode code: String) async throws -> Group {
        let snap = try await groups.whereField("inviteCode", isEqualTo: code).limit(to: 1).getDocuments()
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
        try await membersCol.document(member.id.uuidString).setData(member.fsDict)
        group.memberIDs.append(member.id)
        try await groupRef.updateData(["memberIDs": FSMap.ids(group.memberIDs)])
        return member
    }

    public func updateMemberName(_ memberID: UUID, name: String) async throws -> Member {
        let ref = membersCol.document(memberID.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), var member = Member(fs: data) else { throw RepositoryError.notFound }
        try await ref.updateData(["name": name])
        member.name = name
        return member
    }

    public func fetchMembers(ofGroup groupID: UUID) async throws -> [Member] {
        let snap = try await membersCol.whereField("groupID", isEqualTo: groupID.uuidString).getDocuments()
        return snap.documents.compactMap { Member(fs: $0.data()) }.sorted { $0.joinedAt < $1.joinedAt }
    }

    public func removeMember(_ memberID: UUID) async throws {
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
        let gid = groupID.uuidString
        for col in ["members", "chores", "choreCompletions", "expenses", "settlements"] {
            let docs = try await db.collection(col).whereField("groupID", isEqualTo: gid).getDocuments()
            for d in docs.documents { try await d.reference.delete() }
        }
        try await groups.document(gid).delete()
    }

    public func fetchAllGroups() async throws -> [Group] {
        // PoC: 인증/멤버십 스코프가 없어 전체 groups 를 반환.
        let snap = try await groups.getDocuments()
        return snap.documents.compactMap { Group(fs: $0.data()) }
    }
}
#endif
