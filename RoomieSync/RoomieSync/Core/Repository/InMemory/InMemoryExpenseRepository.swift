//
//  InMemoryExpenseRepository.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern (Mock), 2 P0 ③ 공동 지출
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

public actor InMemoryExpenseRepository: ExpenseRepositoryProtocol {
    private var expenses: [UUID: Expense] = [:]
    private var settlements: [UUID: Settlement] = [:]

    public init(seedExpenses: [Expense] = [], seedSettlements: [Settlement] = []) {
        for e in seedExpenses { expenses[e.id] = e }
        for s in seedSettlements { settlements[s.id] = s }
    }

    public func createExpense(_ expense: Expense) async throws -> Expense {
        guard expense.amount > 0 else {
            throw RepositoryError.invalidInput(reason: "금액은 0원보다 커야 합니다")
        }
        guard !expense.participantMemberIDs.isEmpty else {
            throw RepositoryError.invalidInput(reason: "참여자가 1명 이상이어야 합니다")
        }
        expenses[expense.id] = expense
        return expense
    }

    public func fetchExpenses(groupID: UUID, includeSettled: Bool) async throws -> [Expense] {
        expenses.values
            .filter { $0.groupID == groupID && (includeSettled || !$0.isSettled) }
            .sorted { $0.date > $1.date }
    }

    public func fetchExpense(id: UUID) async throws -> Expense {
        guard let e = expenses[id] else { throw RepositoryError.notFound }
        return e
    }

    public func updateExpense(_ expense: Expense) async throws -> Expense {
        guard let existing = expenses[expense.id] else { throw RepositoryError.notFound }
        guard !existing.isSettled else {
            throw RepositoryError.invalidInput(reason: "정산 완료된 지출은 수정할 수 없습니다")
        }
        expenses[expense.id] = expense
        return expense
    }

    public func deleteExpense(_ expenseID: UUID) async throws {
        guard let existing = expenses[expenseID] else { throw RepositoryError.notFound }
        guard !existing.isSettled else {
            throw RepositoryError.invalidInput(reason: "정산 완료된 지출은 삭제할 수 없습니다")
        }
        expenses[expenseID] = nil
    }

    public func markSettled(_ expenseIDs: [UUID]) async throws {
        for id in expenseIDs {
            guard var e = expenses[id] else { throw RepositoryError.notFound }
            e.isSettled = true
            expenses[id] = e
        }
    }

    public func saveSettlements(_ settlements: [Settlement]) async throws {
        for s in settlements {
            self.settlements[s.id] = s
        }
    }

    public func fetchSettlements(groupID: UUID, onlyPending: Bool) async throws -> [Settlement] {
        settlements.values
            .filter { $0.groupID == groupID && (!onlyPending || !$0.isSettled) }
            .sorted { ($0.settledAt ?? .distantFuture) > ($1.settledAt ?? .distantFuture) }
    }

    public func markSettlementCompleted(_ settlementID: UUID, at date: Date) async throws {
        guard var s = settlements[settlementID] else { throw RepositoryError.notFound }
        s.settledAt = date
        settlements[settlementID] = s
    }
}
