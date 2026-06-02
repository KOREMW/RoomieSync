//
//  ExpenseRepositoryProtocol.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern, 2 P0 ③ 공동 지출 입력·정산
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

public protocol ExpenseRepositoryProtocol: Sendable {
    func createExpense(_ expense: Expense) async throws -> Expense

    func fetchExpenses(groupID: UUID, includeSettled: Bool) async throws -> [Expense]

    func fetchExpense(id: UUID) async throws -> Expense

    /// 지출 수정 — isSettled==true 면 RepositoryError.invalidInput (계획서 6.3 감사 추적성).
    func updateExpense(_ expense: Expense) async throws -> Expense

    /// 지출 삭제 — 정산 완료된 항목은 삭제 불가.
    func deleteExpense(_ expenseID: UUID) async throws

    /// 정산 완료 처리 — 일괄 (월말 정산 시 여러 건 동시 처리).
    func markSettled(_ expenseIDs: [UUID]) async throws

    /// Settlement 저장.
    func saveSettlements(_ settlements: [Settlement]) async throws

    func fetchSettlements(groupID: UUID, onlyPending: Bool) async throws -> [Settlement]

    func markSettlementCompleted(_ settlementID: UUID, at date: Date) async throws
}
