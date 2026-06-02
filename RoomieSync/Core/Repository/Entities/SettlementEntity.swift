//
//  SettlementEntity.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 (SwiftData) — Settlement
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import SwiftData

@Model
public final class SettlementEntity {
    public var id: UUID = UUID()
    public var fromMemberID: UUID = UUID()
    public var toMemberID: UUID = UUID()
    public var amount: Decimal = 0
    public var settledAt: Date? = nil

    @Relationship(deleteRule: .nullify)
    public var group: GroupEntity?

    public init(
        id: UUID = UUID(),
        fromMemberID: UUID = UUID(),
        toMemberID: UUID = UUID(),
        amount: Decimal = 0,
        settledAt: Date? = nil,
        group: GroupEntity? = nil
    ) {
        self.id = id
        self.fromMemberID = fromMemberID
        self.toMemberID = toMemberID
        self.amount = amount
        self.settledAt = settledAt
        self.group = group
    }
}

public extension SettlementEntity {
    func toDomain() -> Settlement {
        Settlement(
            id: id,
            groupID: group?.id ?? UUID(),
            fromMemberID: fromMemberID,
            toMemberID: toMemberID,
            amount: amount,
            settledAt: settledAt
        )
    }

    func apply(_ domain: Settlement) {
        self.fromMemberID = domain.fromMemberID
        self.toMemberID = domain.toMemberID
        self.amount = domain.amount
        self.settledAt = domain.settledAt
    }
}
