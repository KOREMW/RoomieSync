//
//  Group.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 — Group
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

/// 룸메이트 그룹.
/// 한 그룹 = 한 CloudKit shared zone 단위. 최대 6 명까지 (계획서 2 P0 ①).
public struct Group: Identifiable, Hashable, Sendable, Codable {
    /// 기본 모임 아이콘(이모지)·색.
    public static let defaultIcon = "🏠"
    public static let defaultIconColorHex = "#4F46E5"

    public let id: UUID
    public var name: String
    /// 6 자리 초대 코드 (계획서 6.1 #1). 알파넘 대문자.
    public var inviteCode: String
    public var createdAt: Date
    public var memberIDs: [UUID]
    /// 모임 아이콘(이모지)과 아이콘 배경색(hex). 홈 헤더·스위처 등에서 표시.
    public var icon: String
    public var iconColorHex: String

    public init(
        id: UUID = UUID(),
        name: String,
        inviteCode: String,
        createdAt: Date = .now,
        memberIDs: [UUID] = [],
        icon: String = Group.defaultIcon,
        iconColorHex: String = Group.defaultIconColorHex
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.createdAt = createdAt
        self.memberIDs = memberIDs
        self.icon = icon
        self.iconColorHex = iconColorHex
    }

    /// 구버전 데이터(icon/색 키 없음) 디코딩 시 기본값 처리.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.inviteCode = try c.decode(String.self, forKey: .inviteCode)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.memberIDs = try c.decodeIfPresent([UUID].self, forKey: .memberIDs) ?? []
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? Group.defaultIcon
        self.iconColorHex = try c.decodeIfPresent(String.self, forKey: .iconColorHex) ?? Group.defaultIconColorHex
    }

    /// 6 자리 알파넘 대문자 초대 코드 생성. 혼동 문자(0/O, 1/I/L)는 제외.
    public static func generateInviteCode() -> String {
        let chars = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
