//
//  ExpenseViewModel.swift
//  RoomieSync
//
//  계획서 참조: Stitch 시안 ③④, 2 P0 ③ 공동 지출 입력·정산
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import Observation

public enum ExpenseFilter: String, CaseIterable, Identifiable {
    case all, pending, settled
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .all:     return "전체"
        case .pending: return "정산 대기"
        case .settled: return "정산 완료"
        }
    }
}

@MainActor
@Observable
public final class ExpenseViewModel {

    public let groupID: UUID
    private let groupRepo: any GroupRepositoryProtocol
    private let expenseRepo: any ExpenseRepositoryProtocol

    public private(set) var expenses: [Expense] = []
    public private(set) var members: [Member] = []
    public var filter: ExpenseFilter = .all
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String? = nil

    public init(groupID: UUID, repositories: RepositoryBundle) {
        self.groupID = groupID
        self.groupRepo = repositories.group
        self.expenseRepo = repositories.expense
    }

    public var filtered: [Expense] {
        switch filter {
        case .all:     return expenses
        case .pending: return expenses.filter { !$0.isSettled }
        case .settled: return expenses.filter { $0.isSettled }
        }
    }

    public var totalThisMonth: Decimal {
        let cal = Calendar.current
        let now = Date.now
        let thisMonth = expenses.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        return thisMonth.reduce(Decimal(0)) { $0 + $1.amount }
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            members = try await groupRepo.fetchMembers(ofGroup: groupID)
            expenses = try await expenseRepo.fetchExpenses(groupID: groupID, includeSettled: true)
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }

    public func addExpense(_ expense: Expense) async -> Bool {
        do {
            let saved = try await expenseRepo.createExpense(expense)
            let payerName = members.first(where: { $0.id == saved.paidByMemberID })?.name ?? "누군가"
            await NotificationService.shared.notifyExpenseAdded(expense: saved, payerName: payerName)
            await load()
            return true
        } catch RepositoryError.invalidInput(let reason) {
            errorMessage = reason
            return false
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
            return false
        }
    }

    public func updateExpense(_ expense: Expense) async -> Bool {
        do {
            _ = try await expenseRepo.updateExpense(expense)
            await load()
            return true
        } catch RepositoryError.invalidInput(let reason) {
            errorMessage = reason
            return false
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
            return false
        }
    }

    public func deleteExpense(_ expenseID: UUID) async -> Bool {
        do {
            try await expenseRepo.deleteExpense(expenseID)
            await load()
            return true
        } catch RepositoryError.invalidInput(let reason) {
            errorMessage = reason
            return false
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
            return false
        }
    }

    public func performSettlement() async -> [Settlement] {
        do {
            let pending = expenses.filter { !$0.isSettled }
            let plan = SettlementCalculator.calculate(
                expenses: pending,
                members: members,
                groupID: groupID
            )
            try await expenseRepo.saveSettlements(plan)
            try await expenseRepo.markSettled(pending.map(\.id))
            await load()
            return plan
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
            return []
        }
    }
}
