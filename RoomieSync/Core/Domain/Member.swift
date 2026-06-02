//
//  Member.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 — Member
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

/// 그룹에 속한 개별 멤버.
/// avatarColor 는 디자인 시스템의 6 가지 팔레트에서 자동 배정 (계획서 5.1).
public struct Member: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public var avatarColorHex: String   // "#RRGGBB"
    public var joinedAt: Date

    /// 그룹 소속 — Domain Layer 에서는 ID 만 보관, 관계는 Repository 가 해석
    public var groupID: UUID

    public init(
        id: UUID = UUID(),
        name: String,
        avatarColorHex: String,
        joinedAt: Date = .now,
        groupID: UUID
    ) {
        self.id = id
        self.name = name
        self.avatarColorHex = avatarColorHex
        self.joinedAt = joinedAt
        self.groupID = groupID
    }

    /// 이니셜 — 한글 1 자 + 영문 2 자까지. 시안의 "JH", "SY" 형태.
    public var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        // 한글이면 첫 글자 1 개만, 영문이면 단어별 첫 글자 최대 2 개
        if trimmed.unicodeScalars.first?.value ?? 0 >= 0xAC00 {
            return String(trimmed.prefix(1))
        }
        let words = trimmed.split(separator: " ")
        return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
