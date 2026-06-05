//
//  GroupEntity.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 (SwiftData), 6.3 CloudKit 동기화
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  CloudKit 호환 규칙 (3주차에 활성화될 .cloudKitDatabase 옵션 대비)
//   - 모든 stored property 는 optional 또는 default value
//   - @Relationship 은 inverse 명시 + deleteRule 명시
//   - 고유 식별자 id 는 UUID, .unique 제약은 CloudKit 비호환이라 사용 금지
//

import Foundation
import SwiftData

@Model
public final class GroupEntity {
    public var id: UUID = UUID()
    public var name: String = ""
    public var inviteCode: String = ""
    public var createdAt: Date = Date()
    /// 모임 아이콘(이모지)과 아이콘 배경색(hex).
    public var icon: String = Group.defaultIcon
    public var iconColorHex: String = Group.defaultIconColorHex

    /// 멤버 — Group 삭제 시 멤버도 함께 삭제 (.cascade).
    @Relationship(deleteRule: .cascade, inverse: \MemberEntity.group)
    public var members: [MemberEntity]? = []

    /// 가사 — 마찬가지로 cascade
    @Relationship(deleteRule: .cascade, inverse: \ChoreEntity.group)
    public var chores: [ChoreEntity]? = []

    /// 지출 — cascade
    @Relationship(deleteRule: .cascade, inverse: \ExpenseEntity.group)
    public var expenses: [ExpenseEntity]? = []

    /// 정산 — cascade
    @Relationship(deleteRule: .cascade, inverse: \SettlementEntity.group)
    public var settlements: [SettlementEntity]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        inviteCode: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }
}

// MARK: - Domain Mapping
public extension GroupEntity {
    func toDomain() -> Group {
        Group(
            id: id,
            name: name,
            inviteCode: inviteCode,
            createdAt: createdAt,
            memberIDs: (members ?? []).map(\.id),
            icon: icon,
            iconColorHex: iconColorHex
        )
    }

    func apply(_ domain: Group) {
        self.name = domain.name
        self.inviteCode = domain.inviteCode
        self.createdAt = domain.createdAt
        self.icon = domain.icon
        self.iconColorHex = domain.iconColorHex
    }
}
