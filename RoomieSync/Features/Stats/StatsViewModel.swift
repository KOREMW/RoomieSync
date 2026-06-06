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
    /// 미획득 시 진행도 표시(예: "3/10"). 획득했거나 표시 불필요하면 nil.
    public var progressText: String? = nil
    /// 획득 방법 설명(탭하면 보여줌).
    public var howTo: String = ""
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
    public private(set) var myLongestStreak: Int = 0
    public private(set) var myTotalCompletions: Int = 0
    public private(set) var badges: [Badge] = []

    // 레벨 (누적 난이도 가중 포인트 기반)
    public private(set) var myPoints: Int = 0
    public private(set) var myLevel: Int = 1
    public private(set) var myLevelTitle: String = "살림 새내기"
    public private(set) var levelIntoPoints: Int = 0     // 현재 레벨에서 모은 포인트
    public private(set) var levelSpanPoints: Int = 1     // 다음 레벨까지 필요한 총 포인트
    public var levelProgress: Double {
        levelSpanPoints > 0 ? min(1, Double(levelIntoPoints) / Double(levelSpanPoints)) : 0
    }
    public var pointsToNextLevel: Int { max(0, levelSpanPoints - levelIntoPoints) }

    // 주간 목표 (이번 주 난이도 가중 포인트)
    public private(set) var myWeekPoints: Int = 0
    public let weeklyGoal: Int = 14
    public var weekProgress: Double { min(1, Double(myWeekPoints) / Double(weeklyGoal)) }

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
            let myID = CurrentMemberStore.resolve(members, groupID: groupID)?.id

            // 완료 기록은 전체를 한 번에 받아 30일 통계·게이미피케이션에 함께 사용.
            let allCompletions = try await choreRepo.fetchAllCompletions(groupID: groupID, since: nil)
            // 난이도 가중을 위해 가사별 점수 맵 (choreID → points)
            let chores = try await choreRepo.fetchChores(groupID: groupID)
            let pointsByChore = Dictionary(uniqueKeysWithValues: chores.map { ($0.id, $0.difficulty.points) })

            // 가사 완료 횟수 — 지난 30일
            let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            let completions = allCompletions.filter { $0.completedAt >= monthAgo }
            var counts: [UUID: Int] = [:]   // 실제 완료 횟수(막대/MVP용)
            var burden: [UUID: Int] = [:]   // 난이도 가중 점수(공정지수용)
            for c in completions {
                counts[c.memberID, default: 0] += 1
                burden[c.memberID, default: 0] += (pointsByChore[c.choreID] ?? ChoreDifficulty.normal.points)
            }
            memberCounts = members
                .map { m in
                    MemberChoreCount(member: m, count: counts[m.id] ?? 0, isCurrentUser: m.id == myID)
                }
                .sorted { $0.count > $1.count }

            // 공정 지수 — 난이도 가중 부담(burden) 기준 min/max × 100.
            // 횟수가 같아도 어려운 가사를 더 많이 한 사람의 부담이 크게 반영된다.
            let nonZero = burden.values.filter { $0 > 0 }
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

            // ===== 게이미피케이션 — 현재 사용자 기준 (전체 기록에서 파생) =====
            let myCompletions = myID.map { id in allCompletions.filter { $0.memberID == id } } ?? []
            myTotalCompletions = myCompletions.count
            myStreakDays = currentStreak(from: myCompletions)
            myLongestStreak = longestStreak(from: myCompletions)

            // 난이도 가중 포인트 합 (가사별 점수). 가사가 삭제됐으면 보통(2) 가정.
            func points(_ comps: [ChoreCompletion]) -> Int {
                comps.reduce(0) { $0 + (pointsByChore[$1.choreID] ?? ChoreDifficulty.normal.points) }
            }
            myPoints = points(myCompletions)
            let info = levelInfo(points: myPoints)
            myLevel = info.level
            myLevelTitle = info.title
            levelIntoPoints = info.intoLevel
            levelSpanPoints = info.span

            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
            myWeekPoints = points(myCompletions.filter { $0.completedAt >= weekAgo })

            // 뱃지용 보조 집계
            let hardCount = myCompletions.filter { (pointsByChore[$0.choreID] ?? 2) >= ChoreDifficulty.hard.points }.count
            let myExpenseCount = allExpenses.filter { $0.paidByMemberID == myID }.count
            badges = buildBadges(total: myTotalCompletions, longestStreak: myLongestStreak,
                                 fairness: fairnessIndex, hardCount: hardCount, expenseCount: myExpenseCount)
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

    /// 가장 긴 연속 완료 일수(역대 기록).
    private func longestStreak(from completions: [ChoreCompletion]) -> Int {
        let cal = Calendar.current
        let days = Set(completions.map { cal.startOfDay(for: $0.completedAt) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, current = 1
        for i in 1..<days.count {
            if cal.date(byAdding: .day, value: 1, to: days[i - 1]) == days[i] {
                current += 1; best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    /// 누적 포인트 → 레벨/타이틀/현재 레벨 진행도.
    /// 레벨 L 도달 누적 포인트 = 10 · L · (L-1)  → 레벨이 오를수록 더 많은 포인트 필요.
    private func levelInfo(points: Int) -> (level: Int, title: String, intoLevel: Int, span: Int) {
        func reach(_ level: Int) -> Int { 10 * level * (level - 1) }
        var level = 1
        while reach(level + 1) <= points { level += 1 }
        let base = reach(level)
        let next = reach(level + 1)
        return (level, levelTitle(level), points - base, max(1, next - base))
    }

    private func levelTitle(_ level: Int) -> String {
        switch level {
        case 1:  return "살림 새내기"
        case 2:  return "살림 입문"
        case 3:  return "살림 견습"
        case 4:  return "살림 능숙"
        case 5:  return "살림 고수"
        case 6:  return "살림 달인"
        default: return "살림 마스터"
        }
    }

    private func buildBadges(total: Int, longestStreak: Int, fairness: Int,
                             hardCount: Int, expenseCount: Int) -> [Badge] {
        func badge(_ title: String, _ icon: String, value: Int, target: Int, unit: String, howTo: String) -> Badge {
            let earned = value >= target
            return Badge(title: title, icon: icon, earned: earned,
                         detail: "\(target)\(unit) 달성",
                         progressText: earned ? nil : "\(min(value, target))/\(target)",
                         howTo: howTo)
        }
        return [
            badge("첫 완료", "star.fill", value: total, target: 1, unit: "회",
                  howTo: "가사를 1회 완료하면 획득해요."),
            badge("10회", "10.circle.fill", value: total, target: 10, unit: "회",
                  howTo: "가사를 누적 10회 완료하면 획득해요."),
            badge("30회", "30.circle.fill", value: total, target: 30, unit: "회",
                  howTo: "가사를 누적 30회 완료하면 획득해요."),
            badge("50회", "50.circle.fill", value: total, target: 50, unit: "회",
                  howTo: "가사를 누적 50회 완료하면 획득해요."),
            badge("100회", "rosette", value: total, target: 100, unit: "회",
                  howTo: "가사를 누적 100회 완료하면 획득해요."),
            badge("3일 연속", "flame.fill", value: longestStreak, target: 3, unit: "일",
                  howTo: "3일 연속(매일 1회 이상) 가사를 완료하면 획득해요."),
            badge("7일 연속", "flame.circle.fill", value: longestStreak, target: 7, unit: "일",
                  howTo: "7일 연속(매일 1회 이상) 가사를 완료하면 획득해요."),
            badge("14일 연속", "flame.circle", value: longestStreak, target: 14, unit: "일",
                  howTo: "14일 연속(매일 1회 이상) 가사를 완료하면 획득해요."),
            badge("고난도 마스터", "bolt.fill", value: hardCount, target: 10, unit: "회",
                  howTo: "'어려움' 난이도 가사를 10회 완료하면 획득해요. (가사 추가 시 난이도를 설정할 수 있어요)"),
            badge("기록왕", "doc.text.fill", value: expenseCount, target: 10, unit: "건",
                  howTo: "내가 결제한 지출을 10건 등록하면 획득해요."),
            Badge(title: "공정왕", icon: "scalemass.fill", earned: fairness >= 80,
                  detail: "공정지수 80 이상", progressText: fairness >= 80 ? nil : "\(fairness)/80",
                  howTo: "그룹의 공정지수를 80 이상으로 유지하면 획득해요. (멤버 간 가사 부담이 고를수록 높아져요)")
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
