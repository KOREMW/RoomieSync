//
//  SwiftDataExpenseRepository.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern (Concrete), 2 P0 ③ 공동 지출
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import SwiftData

@ModelActor
public actor SwiftDataExpenseRepository: ExpenseRepositoryProtocol {

    public func createExpense(_ expense: Expense) async throws -> Expense {
        guard expense.amount > 0 else {
            throw RepositoryError.invalidInput(reason: "금액은 0원보다 커야 합니다")
        }
        guard !expense.participantMemberIDs.isEmpty else {
            throw RepositoryError.invalidInput(reason: "참여자가 1명 이상이어야 합니다")
        }
        let group = try fetchGroupEntity(id: expense.groupID)
        let entity = ExpenseEntity()
        entity.id = expense.id
        entity.apply(expense)
        entity.group = group
        modelContext.insert(entity)
        try saveOrThrow()
        return entity.toDomain()
    }

    public func fetchExpenses(groupID: UUID, includeSettled: Bool) async throws -> [Expense] {
        let predicate: Predicate<ExpenseEntity>
        if includeSettled {
            predicate = #Predicate<ExpenseEntity> { $0.group?.id == groupID }
        } else {
            predicate = #Predicate<ExpenseEntity> {
                $0.group?.id == groupID && $0.isSettled == false
            }
        }
        let descriptor = FetchDescriptor<ExpenseEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func fetchExpense(id: UUID) async throws -> Expense {
        try fetchExpenseEntity(id: id).toDomain()
    }

    public func updateExpense(_ expense: Expense) async throws -> Expense {
        let entity = try fetchExpenseEntity(id: expense.id)
        guard !entity.isSettled else {
            throw RepositoryError.invalidInput(reason: "정산 완료된 지출은 수정할 수 없습니다")
        }
        entity.apply(expense)
        try saveOrThrow()
        return entity.toDomain()
    }

    public func deleteExpense(_ expenseID: UUID) async throws {
        let entity = try fetchExpenseEntity(id: expenseID)
        guard !entity.isSettled else {
            throw RepositoryError.invalidInput(reason: "정산 완료된 지출은 삭제할 수 없습니다")
        }
        modelContext.delete(entity)
        try saveOrThrow()
    }

    public func markSettled(_ expenseIDs: [UUID]) async throws {
        for id in expenseIDs {
            let entity = try fetchExpenseEntity(id: id)
            entity.isSettled = true
        }
        try saveOrThrow()
    }

    public func saveSettlements(_ settlements: [Settlement]) async throws {
        guard let first = settlements.first else { return }
        let group = try fetchGroupEntity(id: first.groupID)
        for settlement in settlements {
            let entity = SettlementEntity()
            entity.id = settlement.id
            entity.apply(settlement)
            entity.group = group
            modelContext.insert(entity)
        }
        try saveOrThrow()
    }

    public func fetchSettlements(groupID: UUID, onlyPending: Bool) async throws -> [Settlement] {
        let predicate: Predicate<SettlementEntity>
        if onlyPending {
            predicate = #Predicate<SettlementEntity> {
                $0.group?.id == groupID && $0.settledAt == nil
            }
        } else {
            predicate = #Predicate<SettlementEntity> { $0.group?.id == groupID }
        }
        let descriptor = FetchDescriptor<SettlementEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func markSettlementCompleted(_ settlementID: UUID, at date: Date) async throws {
        let predicate = #Predicate<SettlementEntity> { $0.id == settlementID }
        guard let entity = try modelContext.fetch(FetchDescriptor(predicate: predicate)).first else {
            throw RepositoryError.notFound
        }
        entity.settledAt = date
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

    private func fetchExpenseEntity(id: UUID) throws -> ExpenseEntity {
        let predicate = #Predicate<ExpenseEntity> { $0.id == id }
        guard let e = try modelContext.fetch(FetchDescriptor<ExpenseEntity>(predicate: predicate)).first else {
            throw RepositoryError.notFound
        }
        return e
    }

    private func saveOrThrow() throws {
        do { try modelContext.save() } catch {
            throw RepositoryError.persistenceFailure(underlying: error.localizedDescription)
        }
    }
}
