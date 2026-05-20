//
//  InMemoryGroupRepository.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern (Mock)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  용도: SwiftUI #Preview · 단위 테스트 · 빌드 검증.
//        actor 로 격리하여 Swift 6 strict concurrency 하에서도 안전.
//

import Foundation

public actor InMemoryGroupRepository: GroupRepositoryProtocol {
    private var groups: [UUID: Group] = [:]
    private var members: [UUID: Member] = [:]

    public init(seed: [(Group, [Member])] = []) {
        for (g, ms) in seed {
            groups[g.id] = g
            for m in ms { members[m.id] = m }
        }
    }

    public func createGroup(name: String, hostName: String, hostAvatarColorHex: String) async throws -> Group {
        let groupID = UUID()
        let host = Member(name: hostName, avatarColorHex: hostAvatarColorHex, groupID: groupID)
        let group = Group(
            id: groupID,
            name: name,
            inviteCode: Group.generateInviteCode(),
            memberIDs: [host.id]
        )
        groups[group.id] = group
        members[host.id] = host
        return group
    }

    public func findGroup(byInviteCode code: String) async throws -> Group {
        guard let g = groups.values.first(where: { $0.inviteCode == code }) else {
            throw RepositoryError.notFound
        }
        return g
    }

    public func fetchGroup(id: UUID) async throws -> Group {
        guard let g = groups[id] else { throw RepositoryError.notFound }
        return g
    }

    public func addMember(toGroup groupID: UUID, name: String, avatarColorHex: String) async throws -> Member {
        guard var group = groups[groupID] else { throw RepositoryError.notFound }
        guard group.memberIDs.count < 6 else {
            throw RepositoryError.invalidInput(reason: "그룹 최대 인원(6명) 초과")
        }
        let member = Member(name: name, avatarColorHex: avatarColorHex, groupID: groupID)
        members[member.id] = member
        group.memberIDs.append(member.id)
        groups[groupID] = group
        return member
    }

    public func fetchMembers(ofGroup groupID: UUID) async throws -> [Member] {
        guard let group = groups[groupID] else { throw RepositoryError.notFound }
        return group.memberIDs.compactMap { members[$0] }
    }

    public func removeMember(_ memberID: UUID) async throws {
        guard let member = members[memberID] else { throw RepositoryError.notFound }
        members[memberID] = nil
        if var group = groups[member.groupID] {
            group.memberIDs.removeAll { $0 == memberID }
            groups[member.groupID] = group
        }
    }

    public func deleteGroup(_ groupID: UUID) async throws {
        guard groups[groupID] != nil else { throw RepositoryError.notFound }
        groups[groupID] = nil
        members = members.filter { $0.value.groupID != groupID }
    }

    public func fetchAllGroups() async throws -> [Group] {
        groups.values.sorted { $0.createdAt > $1.createdAt }
    }
}
