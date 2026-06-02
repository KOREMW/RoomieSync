//
//  Chore.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 — Chore, 6.1 #3 가사 세팅
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

/// 가사 주기.
public enum ChoreCycle: String, Hashable, Sendable, Codable, CaseIterable {
    case daily              // 매일
    case weekly             // 매주 (요일 지정)
    case monthly            // 매월 (날짜 지정)
    case once               // 선택 (특정 날짜 1회, 비주기)

    /// 사용자 노출 한국어 라벨
    public var displayName: String {
        switch self {
        case .daily:   return "매일"
        case .weekly:  return "매주"
        case .monthly: return "매 월"
        case .once:    return "선택"
        }
    }

    /// 다음 차례 계산용 인터벌 (일 단위 근사).
    public var approximateIntervalDays: Int {
        switch self {
        case .daily:   return 1
        case .weekly:  return 7
        case .monthly: return 30
        case .once:    return 0
        }
    }
}

/// 가사 항목. currentAssigneeID 가 다음 차례 멤버를 가리키며, 완료 체크 시 다음 멤버로 회전.
public struct Chore: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var groupID: UUID
    public var title: String
    /// SF Symbol 또는 이모지. 시안 ②의 🗑️/🍽/🧹/🚿 와 같이 그대로 보여줌.
    public var icon: String
    public var cycleType: ChoreCycle
    public var currentAssigneeID: UUID
    public var nextDueDate: Date
    /// 로테이션 시작 시점 — 멤버 추가/제거 시 순서 안정성 보장용 (1-6 RotationTests).
    public var rotationStartedAt: Date
    /// 가사가 처음 만들어졌을 때의 멤버 순서 스냅샷. 회전은 이 순서를 따른다.
    public var rotationMemberIDs: [UUID]
    /// 주간 주기일 때 반복 요일 (Calendar 기준 1=일 … 7=토). 매일/매월/선택이면 빈 배열.
    public var weekdays: [Int]
    /// 선택(once): 1회 진행 날짜. 매 월(monthly): 매월 반복할 기준 날짜(일자 사용). 그 외 nil.
    public var anchorDate: Date?

    public init(
        id: UUID = UUID(),
        groupID: UUID,
        title: String,
        icon: String,
        cycleType: ChoreCycle,
        currentAssigneeID: UUID,
        nextDueDate: Date,
        rotationStartedAt: Date = .now,
        rotationMemberIDs: [UUID],
        weekdays: [Int] = [],
        anchorDate: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.icon = icon
        self.cycleType = cycleType
        self.currentAssigneeID = currentAssigneeID
        self.nextDueDate = nextDueDate
        self.rotationStartedAt = rotationStartedAt
        self.rotationMemberIDs = rotationMemberIDs
        self.weekdays = weekdays
        self.anchorDate = anchorDate
    }

    /// 주간 요일 한국어 요약 (예: "월·수·금"). 비어있으면 빈 문자열.
    public var weekdaysSummary: String {
        guard !weekdays.isEmpty else { return "" }
        let labels = ["일", "월", "화", "수", "목", "금", "토"]
        return weekdays.sorted().compactMap { (1...7).contains($0) ? labels[$0 - 1] : nil }.joined(separator: "·")
    }
}
