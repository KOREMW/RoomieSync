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

/// 게이미피케이션 뱃지 (기존 완료 기록에서 파생, 별도 저장 없음).
public struct Badge: Identifiable {
    public let id = UUID()
    public let title: String
    public let icon: String      // SF Symbol
    public let earned: Bool
    public let detail: String
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

    // 게이미피케이션 (현재 사용자 기준, 완료 기록에서 파생)
    public private(set) var myStreakDays: Int = 0
    public private(set) var myTotalCompletions: Int = 0
    public private(set) var badges: [Badge] = []

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

            // 완료 기록은 전체를 한 번에 받아 30일 통계·게이미피케이션에 함께 사용.
            let allCompletions = try await choreRepo.fetchAllCompletions(groupID: groupID, since: nil)

            // 가사 완료 횟수 — 지난 30일
            let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            let completions = allCompletions.filter { $0.completedAt >= monthAgo }
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

            // 게이미피케이션 — 현재 사용자 기준 (전체 기록에서 파생)
            let myCompletions = myID.map { id in allCompletions.filter { $0.memberID == id } } ?? []
            myTotalCompletions = myCompletions.count
            myStreakDays = currentStreak(from: myCompletions)
            badges = buildBadges(total: myTotalCompletions, streak: myStreakDays, fairness: fairnessIndex)

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

    // MARK: - 게이미피케이션

    /// 오늘(또는 어제)부터 거꾸로 이어지는 '완료한 날' 연속 일수.
    /// 오늘 아직 안 했으면 어제부터 세어, 진행 중 streak 가 깨진 것처럼 보이지 않게 한다.
    private func currentStreak(from completions: [ChoreCompletion]) -> Int {
        let cal = Calendar.current
        let days = Set(completions.map { cal.startOfDay(for: $0.completedAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = cal.startOfDay(for: .now)
        if !days.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func buildBadges(total: Int, streak: Int, fairness: Int) -> [Badge] {
        [
            Badge(title: "첫 완료", icon: "star.fill", earned: total >= 1, detail: "가사 1회 완료"),
            Badge(title: "10회 달성", icon: "10.circle.fill", earned: total >= 10, detail: "누적 10회 완료"),
            Badge(title: "30회 달성", icon: "30.circle.fill", earned: total >= 30, detail: "누적 30회 완료"),
            Badge(title: "50회 달성", icon: "50.circle.fill", earned: total >= 50, detail: "누적 50회 완료"),
            Badge(title: "3일 연속", icon: "flame.fill", earned: streak >= 3, detail: "3일 연속 완료"),
            Badge(title: "7일 연속", icon: "flame.circle.fill", earned: streak >= 7, detail: "7일 연속 완료"),
            Badge(title: "공정왕", icon: "scalemass.fill", earned: fairness >= 80, detail: "그룹 공정지수 80 이상")
        ]
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
