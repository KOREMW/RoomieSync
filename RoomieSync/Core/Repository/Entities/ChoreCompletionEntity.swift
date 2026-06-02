//
//  ChoreCompletionEntity.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 (SwiftData) — ChoreCompletion
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import SwiftData

@Model
public final class ChoreCompletionEntity {
    public var id: UUID = UUID()
    public var memberID: UUID = UUID()
    public var completedAt: Date = Date()
    public var isConfirmed: Bool = true
    public var deviceIdentifier: String = ""

    @Relationship(deleteRule: .nullify)
    public var chore: ChoreEntity?

    public init(
        id: UUID = UUID(),
        memberID: UUID = UUID(),
        completedAt: Date = Date(),
        isConfirmed: Bool = true,
        deviceIdentifier: String = "",
        chore: ChoreEntity? = nil
    ) {
        self.id = id
        self.memberID = memberID
        self.completedAt = completedAt
        self.isConfirmed = isConfirmed
        self.deviceIdentifier = deviceIdentifier
        self.chore = chore
    }
}

public extension ChoreCompletionEntity {
    func toDomain() -> ChoreCompletion {
        ChoreCompletion(
            id: id,
            choreID: chore?.id ?? UUID(),
            memberID: memberID,
            completedAt: completedAt,
            isConfirmed: isConfirmed,
            deviceIdentifier: deviceIdentifier
        )
    }

    func apply(_ domain: ChoreCompletion) {
        self.memberID = domain.memberID
        self.completedAt = domain.completedAt
        self.isConfirmed = domain.isConfirmed
        self.deviceIdentifier = domain.deviceIdentifier
    }
}
