//
//  SwiftDataChoreRepository.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern (Concrete), 2 P0 ② 가사 자동 로테이션
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import SwiftData

@ModelActor
public actor SwiftDataChoreRepository: ChoreRepositoryProtocol {

    public func createChore(
        groupID: UUID,
        title: String,
        icon: String,
        cycle: ChoreCycle,
        weekdays: [Int],
        anchorDate: Date?,
        rotationMemberIDs: [UUID]
    ) async throws -> Chore {
        guard let first = rotationMemberIDs.first else {
            throw RepositoryError.invalidInput(reason: "로테이션 멤버가 0명입니다")
        }
        let group = try fetchGroupEntity(id: groupID)

        let due = (cycle == .once || cycle == .monthly) ? (anchorDate ?? .now) : nextDate(from: .now, cycle: cycle)
        let chore = ChoreEntity(
            title: title,
            icon: icon,
            cycleTypeRaw: cycle.rawValue,
            currentAssigneeID: first,
            nextDueDate: due
        )
        chore.group = group
        chore.anchorDate = anchorDate
        if let data = try? JSONEncoder().encode(rotationMemberIDs),
           let json = String(data: data, encoding: .utf8) {
            chore.rotationMemberIDsJSON = json
        }
        if let data = try? JSONEncoder().encode(weekdays),
           let json = String(data: data, encoding: .utf8) {
            chore.weekdaysJSON = json
        }
        modelContext.insert(chore)
        try saveOrThrow()
        return chore.toDomain()
    }

    public func updateChore(_ chore: Chore) async throws -> Chore {
        let entity = try fetchChoreEntity(id: chore.id)
        entity.apply(chore)
        try saveOrThrow()
        return entity.toDomain()
    }

    public func fetchChores(groupID: UUID) async throws -> [Chore] {
        let predicate = #Predicate<ChoreEntity> { $0.group?.id == groupID }
        let descriptor = FetchDescriptor<ChoreEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.title)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func fetchChore(id: UUID) async throws -> Chore {
        try fetchChoreEntity(id: id).toDomain()
    }

    public func recordCompletion(
        choreID: UUID,
        memberID: UUID,
        deviceIdentifier: String,
        isConfirmed: Bool
    ) async throws -> ChoreCompletion {
        let chore = try fetchChoreEntity(id: choreID)
        let completion = ChoreCompletionEntity(
            memberID: memberID,
            isConfirmed: isConfirmed,
            deviceIdentifier: deviceIdentifier
        )
        completion.chore = chore
        modelContext.insert(completion)
        try saveOrThrow()
        return completion.toDomain()
    }

    public func cancelCompletion(_ completionID: UUID) async throws {
        let entity = try fetchCompletionEntity(id: completionID)
        guard !entity.isConfirmed else {
            throw RepositoryError.invalidInput(reason: "이미 확정된 완료는 취소할 수 없습니다")
        }
        modelContext.delete(entity)
        try saveOrThrow()
    }

    public func confirmCompletion(_ completionID: UUID) async throws -> Chore {
        let entity = try fetchCompletionEntity(id: completionID)
        entity.isConfirmed = true
        guard let chore = entity.chore else { throw RepositoryError.notFound }
        let rotated = ChoreRotation.rotateToNext(chore.toDomain())
        chore.apply(rotated)
        try saveOrThrow()
        return rotated
    }

    public func fetchCompletions(choreID: UUID) async throws -> [ChoreCompletion] {
        let predicate = #Predicate<ChoreCompletionEntity> {
            $0.chore?.id == choreID && $0.isConfirmed == true
        }
        let descriptor = FetchDescriptor<ChoreCompletionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func fetchAllCompletions(groupID: UUID, since: Date?) async throws -> [ChoreCompletion] {
        let predicate: Predicate<ChoreCompletionEntity>
        if let since {
            predicate = #Predicate<ChoreCompletionEntity> {
                $0.chore?.group?.id == groupID &&
                $0.isConfirmed == true &&
                $0.completedAt >= since
            }
        } else {
            predicate = #Predicate<ChoreCompletionEntity> {
                $0.chore?.group?.id == groupID && $0.isConfirmed == true
            }
        }
        let descriptor = FetchDescriptor<ChoreCompletionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func swapWithNext(choreID: UUID) async throws -> Chore {
        let entity = try fetchChoreEntity(id: choreID)
        let swapped = ChoreRotation.swapCurrentWithNext(entity.toDomain())
        entity.apply(swapped)
        try saveOrThrow()
        return swapped
    }

    public func deleteChore(_ choreID: UUID) async throws {
        let entity = try fetchChoreEntity(id: choreID)
        modelContext.delete(entity)
        try saveOrThrow()
    }

    // MARK: - Private

    private func fetchGroupEntity(id: UUID) throws -> GroupEntity {
        let predicate = #Predicate<GroupEntity> { $0.id == id }
        guard let e = try modelContext.fetch(FetchDescriptor<GroupEntity>(predicate: predicate)).first else {
            throw RepositoryError.notFound
        }
        return e
    }

    private func fetchChoreEntity(id: UUID) throws -> ChoreEntity {
        let predicate = #Predicate<ChoreEntity> { $0.id == id }
        guard let e = try modelContext.fetch(FetchDescriptor<ChoreEntity>(predicate: predicate)).first else {
            throw RepositoryError.notFound
        }
        return e
    }

    private func fetchCompletionEntity(id: UUID) throws -> ChoreCompletionEntity {
        let predicate = #Predicate<ChoreCompletionEntity> { $0.id == id }
        guard let e = try modelContext.fetch(FetchDescriptor<ChoreCompletionEntity>(predicate: predicate)).first else {
            throw RepositoryError.notFound
        }
        return e
    }

    private func saveOrThrow() throws {
        do { try modelContext.save() } catch {
            throw RepositoryError.persistenceFailure(underlying: error.localizedDescription)
        }
    }

    private func nextDate(from base: Date, cycle: ChoreCycle) -> Date {
        Calendar.current.date(byAdding: .day, value: cycle.approximateIntervalDays, to: base) ?? base
    }
}
