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
    private var notes: [UUID: GroupNote] = [:]

    public init(seed: [(Group, [Member])] = []) {
        for (g, ms) in seed {
            groups[g.id] = g
            for m in ms { members[m.id] = m }
        }
    }

    public func createGroup(name: String, icon: String, iconColorHex: String,
                            hostName: String, hostAvatarColorHex: String) async throws -> Group {
        let groupID = UUID()
        let host = Member(name: hostName, avatarColorHex: hostAvatarColorHex, groupID: groupID)
        let group = Group(
            id: groupID,
            name: name,
            inviteCode: Group.generateInviteCode(),
            memberIDs: [host.id],
            icon: icon,
            iconColorHex: iconColorHex
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

    public func updateGroupInfo(_ groupID: UUID, name: String, icon: String, iconColorHex: String) async throws -> Group {
        guard var group = groups[groupID] else { throw RepositoryError.notFound }
        group.name = name
        group.icon = icon
        group.iconColorHex = iconColorHex
        groups[groupID] = group
        return group
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

    public func updateMemberName(_ memberID: UUID, name: String) async throws -> Member {
        guard var member = members[memberID] else { throw RepositoryError.notFound }
        member.name = name
        members[memberID] = member
        return member
    }

    public func updateMemberAccount(_ memberID: UUID, bankName: String, accountNumber: String) async throws -> Member {
        guard var member = members[memberID] else { throw RepositoryError.notFound }
        member.bankName = bankName
        member.accountNumber = accountNumber
        members[memberID] = member
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
        notes = notes.filter { $0.value.groupID != groupID }
    }

    public func fetchAllGroups() async throws -> [Group] {
        groups.values.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - 공지/메모 (#13)

    public func fetchNotes(groupID: UUID) async throws -> [GroupNote] {
        notes.values
            .filter { $0.groupID == groupID }
            .sorted { ($0.isPinned ? 1 : 0, $0.createdAt) > ($1.isPinned ? 1 : 0, $1.createdAt) }
    }

    public func addNote(groupID: UUID, authorMemberID: UUID, text: String) async throws -> GroupNote {
        let note = GroupNote(groupID: groupID, authorMemberID: authorMemberID, text: text)
        notes[note.id] = note
        return note
    }

    public func deleteNote(_ noteID: UUID) async throws {
        guard notes[noteID] != nil else { throw RepositoryError.notFound }
        notes[noteID] = nil
    }

    public func setNotePinned(_ noteID: UUID, pinned: Bool) async throws -> GroupNote {
        guard var note = notes[noteID] else { throw RepositoryError.notFound }
        note.isPinned = pinned
        notes[noteID] = note
        return note
    }
}
