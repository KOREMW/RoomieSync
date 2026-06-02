//
//  SwiftDataGroupRepository.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern (Concrete), 6.3 CloudKit 동기화
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  @ModelActor 매크로 (iOS 17+) 로 ModelContext 를 actor 에 격리.
//  Swift 6 strict concurrency 하에서도 안전하며, 호출은 모두 async.
//

import Foundation
import SwiftData

@ModelActor
public actor SwiftDataGroupRepository: GroupRepositoryProtocol {

    public func createGroup(name: String, hostName: String, hostAvatarColorHex: String) async throws -> Group {
        let groupEntity = GroupEntity(
            name: name,
            inviteCode: Group.generateInviteCode()
        )
        modelContext.insert(groupEntity)

        let host = MemberEntity(
            name: hostName,
            avatarColorHex: hostAvatarColorHex
        )
        host.group = groupEntity
        modelContext.insert(host)

        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailure(underlying: error.localizedDescription)
        }
        return groupEntity.toDomain()
    }

    public func findGroup(byInviteCode code: String) async throws -> Group {
        let predicate = #Predicate<GroupEntity> { $0.inviteCode == code }
        let descriptor = FetchDescriptor<GroupEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        return entity.toDomain()
    }

    public func fetchGroup(id: UUID) async throws -> Group {
        try fetchGroupEntity(id: id).toDomain()
    }

    public func addMember(toGroup groupID: UUID, name: String, avatarColorHex: String) async throws -> Member {
        let group = try fetchGroupEntity(id: groupID)
        guard (group.members ?? []).count < 6 else {
            throw RepositoryError.invalidInput(reason: "그룹 최대 인원(6명) 초과")
        }
        let member = MemberEntity(name: name, avatarColorHex: avatarColorHex)
        member.group = group
        modelContext.insert(member)
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailure(underlying: error.localizedDescription)
        }
        return member.toDomain()
    }

    public func updateMemberName(_ memberID: UUID, name: String) async throws -> Member {
        let predicate = #Predicate<MemberEntity> { $0.id == memberID }
        guard let member = try modelContext.fetch(FetchDescriptor<MemberEntity>(predicate: predicate)).first else {
            throw RepositoryError.notFound
        }
        member.name = name
        do { try modelContext.save() } catch {
            throw RepositoryError.persistenceFailure(underlying: error.localizedDescription)
        }
        return member.toDomain()
    }

    public func fetchMembers(ofGroup groupID: UUID) async throws -> [Member] {
        let group = try fetchGroupEntity(id: groupID)
        return (group.members ?? []).map { $0.toDomain() }.sorted { $0.joinedAt < $1.joinedAt }
    }

    public func removeMember(_ memberID: UUID) async throws {
        let predicate = #Predicate<MemberEntity> { $0.id == memberID }
        guard let member = try modelContext.fetch(FetchDescriptor<MemberEntity>(predicate: predicate)).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(member)
        do { try modelContext.save() } catch {
            throw RepositoryError.persistenceFailure(underlying: error.localizedDescription)
        }
    }

    public func deleteGroup(_ groupID: UUID) async throws {
        let group = try fetchGroupEntity(id: groupID)
        modelContext.delete(group)
        do { try modelContext.save() } catch {
            throw RepositoryError.persistenceFailure(underlying: error.localizedDescription)
        }
    }

    public func fetchAllGroups() async throws -> [Group] {
        let descriptor = FetchDescriptor<GroupEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    // MARK: - Private

    private func fetchGroupEntity(id: UUID) throws -> GroupEntity {
        let predicate = #Predicate<GroupEntity> { $0.id == id }
        guard let entity = try modelContext.fetch(FetchDescriptor<GroupEntity>(predicate: predicate)).first else {
            throw RepositoryError.notFound
        }
        return entity
    }
}
