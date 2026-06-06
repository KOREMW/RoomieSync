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
    /// 아바타 아이콘(이모지). 빈 문자열이면 이름 이니셜로 표시(기본).
    public var avatarIcon: String
    public var joinedAt: Date

    /// 그룹 소속 — Domain Layer 에서는 ID 만 보관, 관계는 Repository 가 해석
    public var groupID: UUID

    /// 정산 입금 계좌 (선택). 다른 멤버가 송금할 때 사용.
    public var bankName: String?
    public var accountNumber: String?

    /// 이 멤버를 만든 기기의 익명 인증 uid (#14). 기기에서 '나'를 식별하는 데 사용.
    public var ownerUID: String?

    public init(
        id: UUID = UUID(),
        name: String,
        avatarColorHex: String,
        avatarIcon: String = "",
        joinedAt: Date = .now,
        groupID: UUID,
        bankName: String? = nil,
        accountNumber: String? = nil,
        ownerUID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.avatarColorHex = avatarColorHex
        self.avatarIcon = avatarIcon
        self.joinedAt = joinedAt
        self.groupID = groupID
        self.bankName = bankName
        self.accountNumber = accountNumber
        self.ownerUID = ownerUID
    }

    /// 구버전 데이터(avatarIcon/ownerUID 키 없음) 디코딩 시 기본 처리.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.avatarColorHex = try c.decode(String.self, forKey: .avatarColorHex)
        self.avatarIcon = try c.decodeIfPresent(String.self, forKey: .avatarIcon) ?? ""
        self.joinedAt = try c.decode(Date.self, forKey: .joinedAt)
        self.groupID = try c.decode(UUID.self, forKey: .groupID)
        self.bankName = try c.decodeIfPresent(String.self, forKey: .bankName)
        self.accountNumber = try c.decodeIfPresent(String.self, forKey: .accountNumber)
        self.ownerUID = try c.decodeIfPresent(String.self, forKey: .ownerUID)
    }

    /// 계좌 등록 여부.
    public var hasAccount: Bool {
        !(bankName ?? "").isEmpty && !(accountNumber ?? "").isEmpty
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
