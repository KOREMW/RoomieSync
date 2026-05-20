//
//  ChoreCompletion.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 — ChoreCompletion, 4.2 룸메이트 완료 알림
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

/// 가사 1 회 수행 로그. KPI 측정의 1 차 데이터 (계획서 1.4 "그룹당 주 평균 가사 완료율").
public struct ChoreCompletion: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var choreID: UUID
    public var memberID: UUID
    public var completedAt: Date
    /// 5 초 취소 토스트 (계획서 6.2 오류 정정) 가 만료된 이후에만 true.
    /// 토스트 도중에는 false 로 두고, 만료 시점에 true 로 승격.
    public var isConfirmed: Bool
    /// 충돌 해결용 — 어느 기기에서 기록됐는지 (계획서 6.3 last-write-wins).
    public var deviceIdentifier: String

    public init(
        id: UUID = UUID(),
        choreID: UUID,
        memberID: UUID,
        completedAt: Date = .now,
        isConfirmed: Bool = true,
        deviceIdentifier: String
    ) {
        self.id = id
        self.choreID = choreID
        self.memberID = memberID
        self.completedAt = completedAt
        self.isConfirmed = isConfirmed
        self.deviceIdentifier = deviceIdentifier
    }
}
