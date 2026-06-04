//
//  GroupNote.swift
//  RoomieSync
//
//  공지/메모 보드(#13) — 그룹 구성원이 공유하는 가벼운 공지·메모 한 줄.
//  예: "이번 주 분리수거는 일요일", "공용 세제 다 떨어짐".
//

import Foundation

public struct GroupNote: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var groupID: UUID
    public var authorMemberID: UUID
    public var text: String
    public var createdAt: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        groupID: UUID,
        authorMemberID: UUID,
        text: String,
        createdAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.groupID = groupID
        self.authorMemberID = authorMemberID
        self.text = text
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}
