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

public enum ExpenseSort: String, CaseIterable, Identifiable {
    case dateDesc, dateAsc, amountDesc, amountAsc
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .dateDesc:   return "최신순"
        case .dateAsc:    return "오래된순"
        case .amountDesc: return "금액 높은순"
        case .amountAsc:  return "금액 낮은순"
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
    public var sort: ExpenseSort = .dateDesc
    public var searchText: String = ""
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String? = nil

    public init(groupID: UUID, repositories: RepositoryBundle) {
        self.groupID = groupID
        self.groupRepo = repositories.group
        self.expenseRepo = repositories.expense
    }

    /// 검색어가 입력되어 있거나 기본(전체) 필터가 아닌지 — 빈 결과 메시지 분기에 사용.
    public var isNarrowed: Bool {
        filter != .all || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var filtered: [Expense] {
        var items: [Expense]
        switch filter {
        case .all:     items = expenses
        case .pending: items = expenses.filter { !$0.isSettled }
        case .settled: items = expenses.filter { $0.isSettled }
        }

        // 검색: 제목·메모·결제자 이름
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            items = items.filter { exp in
                if exp.title.lowercased().contains(q) { return true }
                if let memo = exp.memo, memo.lowercased().contains(q) { return true }
                if let payer = members.first(where: { $0.id == exp.paidByMemberID }),
                   payer.name.lowercased().contains(q) { return true }
                return false
            }
        }

        // 정렬
        switch sort {
        case .dateDesc:   items.sort { $0.date > $1.date }
        case .dateAsc:    items.sort { $0.date < $1.date }
        case .amountDesc: items.sort { $0.amount > $1.amount }
        case .amountAsc:  items.sort { $0.amount < $1.amount }
        }
        return items
    }

    public var totalThisMonth: Decimal {
        let cal = Calendar.current
        let now = cal.dateComponents([.year, .month], from: .now)
        return expenses.reduce(Decimal(0)) { sum, e in
            let c = cal.dateComponents([.year, .month], from: e.date)
            return (c.year == now.year && c.month == now.month) ? sum + e.amount : sum
        }
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            members = try await groupRepo.fetchMembers(ofGroup: groupID)
            expenses = try await expenseRepo.fetchExpenses(groupID: groupID, includeSettled: true)
            await generateDueRecurringExpenses()
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }

    /// 반복 지출(#8) — 이번 달 생성 예정 템플릿을 실제 지출로 만든다(기기 로컬 템플릿 기준).
    private func generateDueRecurringExpenses() async {
        var templates = ExpenseTemplateStore.load(groupID)
        let due = RecurringExpenseGenerator.due(templates: templates)
        guard !due.isEmpty else { return }
        let ym = RecurringExpenseGenerator.yearMonth(of: .now)
        var createdAny = false
        for (template, date) in due {
            let expense = Expense(
                groupID: groupID, title: template.title, amount: template.amount,
                paidByMemberID: template.paidByMemberID,
                participantMemberIDs: template.participantMemberIDs,
                date: date, category: template.category, memo: template.memo
            )
            if (try? await expenseRepo.createExpense(expense)) != nil {
                createdAny = true
                if let idx = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[idx].lastGeneratedYearMonth = ym
                }
            }
        }
        ExpenseTemplateStore.save(groupID, templates)
        if createdAny {
            expenses = (try? await expenseRepo.fetchExpenses(groupID: groupID, includeSettled: true)) ?? expenses
        }
    }

    public func addExpense(_ expense: Expense) async -> Bool {
        do {
            let saved = try await expenseRepo.createExpense(expense)
            // 새 지출 알림은 '다른 멤버'가 앱을 열 때 감지해 발송(HomeViewModel).
            _ = saved
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
}
