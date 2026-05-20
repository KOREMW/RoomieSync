//
//  Settlement.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 — Settlement, 3.3 채무 단순화 알고리즘
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

/// 정산 1 건 — "A → B 에게 N 원 송금" 한 줄.
/// SettlementCalculator 의 그리디 매칭 결과 각 줄이 Settlement 1 개.
public struct Settlement: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var groupID: UUID
    public var fromMemberID: UUID
    public var toMemberID: UUID
    public var amount: Decimal       // 항상 양수 (0 송금은 생성되지 않음)
    public var settledAt: Date?      // nil 이면 미정산, 값 있으면 송금 완료 시각

    public init(
        id: UUID = UUID(),
        groupID: UUID,
        fromMemberID: UUID,
        toMemberID: UUID,
        amount: Decimal,
        settledAt: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.fromMemberID = fromMemberID
        self.toMemberID = toMemberID
        self.amount = amount
        self.settledAt = settledAt
    }

    public var isSettled: Bool { settledAt != nil }
}
