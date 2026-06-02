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
    public let id: UUID
    public var name: String
    /// 6 자리 초대 코드 (계획서 6.1 #1). 알파넘 대문자.
    public var inviteCode: String
    public var createdAt: Date
    public var memberIDs: [UUID]

    public init(
        id: UUID = UUID(),
        name: String,
        inviteCode: String,
        createdAt: Date = .now,
        memberIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.createdAt = createdAt
        self.memberIDs = memberIDs
    }

    /// 6 자리 알파넘 대문자 초대 코드 생성. 혼동 문자(0/O, 1/I/L)는 제외.
    public static func generateInviteCode() -> String {
        let chars = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
