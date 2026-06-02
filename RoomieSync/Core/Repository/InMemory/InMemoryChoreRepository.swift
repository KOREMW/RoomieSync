//
//  InMemoryChoreRepository.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern (Mock), 2 P0 ② 가사 로테이션
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

public actor InMemoryChoreRepository: ChoreRepositoryProtocol {
    private var chores: [UUID: Chore] = [:]
    private var completions: [UUID: ChoreCompletion] = [:]

    public init(
        seedChores: [Chore] = [],
        seedCompletions: [ChoreCompletion] = []
    ) {
        for c in seedChores { chores[c.id] = c }
        for c in seedCompletions { completions[c.id] = c }
    }

    public func createChore(
        groupID: UUID,
        title: String,
        icon: String,
        cycle: ChoreCycle,
        weekdays: [Int],
        rotationMemberIDs: [UUID]
    ) async throws -> Chore {
        guard let first = rotationMemberIDs.first else {
            throw RepositoryError.invalidInput(reason: "로테이션 멤버가 0명입니다")
        }
        let chore = Chore(
            groupID: groupID,
            title: title,
            icon: icon,
            cycleType: cycle,
            currentAssigneeID: first,
            nextDueDate: nextDate(from: .now, cycle: cycle),
            rotationMemberIDs: rotationMemberIDs,
            weekdays: weekdays
        )
        chores[chore.id] = chore
        return chore
    }

    public func updateChore(_ chore: Chore) async throws -> Chore {
        guard chores[chore.id] != nil else { throw RepositoryError.notFound }
        chores[chore.id] = chore
        return chore
    }

    public func fetchChores(groupID: UUID) async throws -> [Chore] {
        chores.values.filter { $0.groupID == groupID }.sorted { $0.title < $1.title }
    }

    public func fetchChore(id: UUID) async throws -> Chore {
        guard let c = chores[id] else { throw RepositoryError.notFound }
        return c
    }

    public func recordCompletion(
        choreID: UUID,
        memberID: UUID,
        deviceIdentifier: String,
        isConfirmed: Bool
    ) async throws -> ChoreCompletion {
        guard chores[choreID] != nil else { throw RepositoryError.notFound }
        let completion = ChoreCompletion(
            choreID: choreID,
            memberID: memberID,
            isConfirmed: isConfirmed,
            deviceIdentifier: deviceIdentifier
        )
        completions[completion.id] = completion
        return completion
    }

    public func cancelCompletion(_ completionID: UUID) async throws {
        guard let c = completions[completionID] else { throw RepositoryError.notFound }
        guard !c.isConfirmed else {
            throw RepositoryError.invalidInput(reason: "이미 확정된 완료는 취소할 수 없습니다")
        }
        completions[completionID] = nil
    }

    public func confirmCompletion(_ completionID: UUID) async throws -> Chore {
        guard var completion = completions[completionID] else { throw RepositoryError.notFound }
        guard var chore = chores[completion.choreID] else { throw RepositoryError.notFound }
        completion.isConfirmed = true
        completions[completionID] = completion
        // 다음 차례 멤버로 회전
        chore = ChoreRotation.rotateToNext(chore)
        chores[chore.id] = chore
        return chore
    }

    public func fetchCompletions(choreID: UUID) async throws -> [ChoreCompletion] {
        completions.values
            .filter { $0.choreID == choreID && $0.isConfirmed }
            .sorted { $0.completedAt > $1.completedAt }
    }

    public func fetchAllCompletions(groupID: UUID, since: Date?) async throws -> [ChoreCompletion] {
        let choreIDs = Set(chores.values.filter { $0.groupID == groupID }.map(\.id))
        return completions.values.filter { completion in
            guard choreIDs.contains(completion.choreID), completion.isConfirmed else { return false }
            if let since { return completion.completedAt >= since }
            return true
        }.sorted { $0.completedAt > $1.completedAt }
    }

    public func swapWithNext(choreID: UUID) async throws -> Chore {
        guard var chore = chores[choreID] else { throw RepositoryError.notFound }
        chore = ChoreRotation.swapCurrentWithNext(chore)
        chores[chore.id] = chore
        return chore
    }

    public func deleteChore(_ choreID: UUID) async throws {
        guard chores[choreID] != nil else { throw RepositoryError.notFound }
        chores[choreID] = nil
        completions = completions.filter { $0.value.choreID != choreID }
    }

    private func nextDate(from base: Date, cycle: ChoreCycle) -> Date {
        let days = cycle.approximateIntervalDays
        return Calendar.current.date(byAdding: .day, value: days, to: base) ?? base
    }
}
