//
//  MemberEntity.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 (SwiftData) — Member
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import SwiftData

@Model
public final class MemberEntity {
    public var id: UUID = UUID()
    public var name: String = ""
    public var avatarColorHex: String = "#4F46E5"   // 기본은 Primary
    public var joinedAt: Date = Date()

    /// 소속 그룹 — Member 단독 삭제 시 Group 은 유지 (.nullify)
    @Relationship(deleteRule: .nullify)
    public var group: GroupEntity?

    public init(
        id: UUID = UUID(),
        name: String = "",
        avatarColorHex: String = "#4F46E5",
        joinedAt: Date = Date(),
        group: GroupEntity? = nil
    ) {
        self.id = id
        self.name = name
        self.avatarColorHex = avatarColorHex
        self.joinedAt = joinedAt
        self.group = group
    }
}

// MARK: - Domain Mapping
public extension MemberEntity {
    func toDomain() -> Member {
        Member(
            id: id,
            name: name,
            avatarColorHex: avatarColorHex,
            joinedAt: joinedAt,
            groupID: group?.id ?? UUID()   // 정상 데이터라면 항상 group 존재
        )
    }

    func apply(_ domain: Member) {
        self.name = domain.name
        self.avatarColorHex = domain.avatarColorHex
        self.joinedAt = domain.joinedAt
    }
}
