//
//  ExpenseTemplate.swift
//  RoomieSync
//
//  반복 지출 템플릿(#8) — "관리비 매월 25일 15만원" 같은 고정 지출을 자동 생성.
//
//  설계: 템플릿 설정은 '기기 로컬'(UserDefaults)에 저장하고, 생성된 '지출'만 동기화한다.
//        → 한 사람만 템플릿을 등록하면 그 기기에서 매월 1회 생성되어 동기화되므로
//          여러 기기가 같은 템플릿으로 중복 생성하는 문제가 없고, 별도 컬렉션/규칙도 불필요.
//

import Foundation

public struct ExpenseTemplate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var groupID: UUID
    public var title: String
    public var amount: Decimal
    public var category: ExpenseCategory
    public var dayOfMonth: Int            // 1~31 (말일 초과 시 그 달 말일로 보정)
    public var memo: String?
    public var paidByMemberID: UUID
    public var participantMemberIDs: [UUID]
    /// 마지막으로 생성한 연-월("yyyy-MM"). 같은 달 중복 생성 방지.
    public var lastGeneratedYearMonth: String?

    public init(
        id: UUID = UUID(),
        groupID: UUID,
        title: String,
        amount: Decimal,
        category: ExpenseCategory = .utility,
        dayOfMonth: Int,
        memo: String? = nil,
        paidByMemberID: UUID,
        participantMemberIDs: [UUID],
        lastGeneratedYearMonth: String? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.amount = amount
        self.category = category
        self.dayOfMonth = dayOfMonth
        self.memo = memo
        self.paidByMemberID = paidByMemberID
        self.participantMemberIDs = participantMemberIDs
        self.lastGeneratedYearMonth = lastGeneratedYearMonth
    }
}

/// 반복 지출 템플릿의 기기-로컬 저장소 (그룹별).
public enum ExpenseTemplateStore {
    private static func key(_ groupID: UUID) -> String {
        "RoomieSync.expenseTemplates.\(groupID.uuidString)"
    }

    public static func load(_ groupID: UUID) -> [ExpenseTemplate] {
        guard let data = UserDefaults.standard.data(forKey: key(groupID)),
              let arr = try? JSONDecoder().decode([ExpenseTemplate].self, from: data) else { return [] }
        return arr
    }

    public static func save(_ groupID: UUID, _ templates: [ExpenseTemplate]) {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(data, forKey: key(groupID))
    }
}

/// 반복 지출 → 실제 지출 생성 로직(순수 함수, 테스트 가능).
public enum RecurringExpenseGenerator {
    public static func yearMonth(of date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// 이번 달에 생성해야 하는 템플릿과, 생성할 지출 날짜를 계산한다.
    /// 조건: 이번 달에 아직 생성 안 했고(lastGeneratedYearMonth != 이번달), 오늘이 dayOfMonth 이상.
    public static func due(
        templates: [ExpenseTemplate],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(template: ExpenseTemplate, date: Date)] {
        let ym = yearMonth(of: now, calendar: calendar)
        let today = calendar.component(.day, from: now)
        var result: [(ExpenseTemplate, Date)] = []
        for t in templates {
            guard t.lastGeneratedYearMonth != ym else { continue }
            guard today >= t.dayOfMonth else { continue }
            guard let date = dateForDay(t.dayOfMonth, in: now, calendar: calendar) else { continue }
            result.append((t, date))
        }
        return result
    }

    /// 이번 달의 dayOfMonth 날짜(말일 초과 시 말일로 보정).
    static func dateForDay(_ day: Int, in reference: Date, calendar: Calendar = .current) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: reference)
        let range = calendar.range(of: .day, in: .month, for: reference) ?? 1..<29
        comps.day = min(max(day, 1), range.upperBound - 1)
        return calendar.date(from: comps)
    }
}
