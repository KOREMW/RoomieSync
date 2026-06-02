//
//  StatsViewModel.swift
//  RoomieSync
//
//  계획서 참조: Stitch 시안 ⑤, 1.4 KPI 공정 지수 정의
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import Observation

public struct MemberChoreCount: Identifiable {
    public let id = UUID()
    public let member: Member
    public let count: Int
    public var isCurrentUser: Bool
}

public struct MonthlyExpensePoint: Identifiable {
    public let id = UUID()
    public let month: Date
    public let total: Decimal
}

public struct CategorySpending: Identifiable {
    public let id = UUID()
    public let category: ExpenseCategory
    public let total: Decimal
    public let percentage: Double  // 0.0 ~ 1.0
}

@MainActor
@Observable
public final class StatsViewModel {

    public let groupID: UUID
    private let groupRepo: any GroupRepositoryProtocol
    private let choreRepo: any ChoreRepositoryProtocol
    private let expenseRepo: any ExpenseRepositoryProtocol

    public private(set) var memberCounts: [MemberChoreCount] = []
    public private(set) var monthlySeries: [MonthlyExpensePoint] = []
    public private(set) var categorySpendings: [CategorySpending] = []
    public private(set) var totalSpending: Decimal = 0
    public private(set) var fairnessIndex: Int = 0   // 0~100
    public private(set) var mvp: Member? = nil
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String? = nil

    public init(groupID: UUID, repositories: RepositoryBundle) {
        self.groupID = groupID
        self.groupRepo = repositories.group
        self.choreRepo = repositories.chore
        self.expenseRepo = repositories.expense
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let members = try await groupRepo.fetchMembers(ofGroup: groupID)
            let myID = members.first?.id

            // 가사 완료 횟수 — 지난 30일
            let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            let completions = try await choreRepo.fetchAllCompletions(groupID: groupID, since: monthAgo)
            var counts: [UUID: Int] = [:]
            for c in completions { counts[c.memberID, default: 0] += 1 }
            memberCounts = members
                .map { m in
                    MemberChoreCount(member: m, count: counts[m.id] ?? 0, isCurrentUser: m.id == myID)
                }
                .sorted { $0.count > $1.count }

            // 공정 지수 — min(완료횟수) / max(완료횟수) × 100
            // 계획서 1.4 정의 그대로
            let nonZero = counts.values.filter { $0 > 0 }
            if let mn = nonZero.min(), let mx = nonZero.max(), mx > 0 {
                fairnessIndex = Int((Double(mn) / Double(mx)) * 100)
            } else {
                fairnessIndex = 100
            }

            // MVP — 최다 완료자
            mvp = memberCounts.first.map(\.member)

            // 월별 지출 — 최근 6개월
            let allExpenses = try await expenseRepo.fetchExpenses(groupID: groupID, includeSettled: true)
            monthlySeries = buildMonthlySeries(allExpenses, monthsBack: 6)

            // 카테고리 도넛
            let thisMonth = allExpenses.filter {
                Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month)
            }
            totalSpending = thisMonth.reduce(Decimal(0)) { $0 + $1.amount }
            categorySpendings = buildCategorySpending(thisMonth)
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }

    // MARK: - Builders

    private func buildMonthlySeries(_ expenses: [Expense], monthsBack: Int) -> [MonthlyExpensePoint] {
        let cal = Calendar.current
        let now = Date.now
        var points: [MonthlyExpensePoint] = []
        for offset in stride(from: monthsBack - 1, through: 0, by: -1) {
            guard let month = cal.date(byAdding: .month, value: -offset, to: now) else { continue }
            let comps = cal.dateComponents([.year, .month], from: month)
            let bucket = expenses.filter { e in
                let c = cal.dateComponents([.year, .month], from: e.date)
                return c.year == comps.year && c.month == comps.month
            }
            let total = bucket.reduce(Decimal(0)) { $0 + $1.amount }
            points.append(MonthlyExpensePoint(month: month, total: total))
        }
        return points
    }

    private func buildCategorySpending(_ expenses: [Expense]) -> [CategorySpending] {
        let total = expenses.reduce(Decimal(0)) { $0 + $1.amount }
        let totalDouble = (total as NSDecimalNumber).doubleValue
        var result: [CategorySpending] = []
        for cat in ExpenseCategory.allCases {
            let sum = expenses.filter { $0.category == cat }.reduce(Decimal(0)) { $0 + $1.amount }
            let sumDouble = (sum as NSDecimalNumber).doubleValue
            let pct = totalDouble > 0 ? sumDouble / totalDouble : 0
            result.append(CategorySpending(category: cat, total: sum, percentage: pct))
        }
        return result.sorted { $0.total > $1.total }
    }
}
