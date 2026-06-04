//
//  NoteEntity.swift
//  RoomieSync
//
//  공지/메모 보드(#13) — SwiftData 영속 엔티티.
//  그룹 관계 대신 groupID 필드로 스코프(쿼리 단순화 + CloudKit 호환).
//

import Foundation
import SwiftData

@Model
public final class NoteEntity {
    public var id: UUID = UUID()
    public var groupID: UUID = UUID()
    public var authorMemberID: UUID = UUID()
    public var text: String = ""
    public var createdAt: Date = Date()
    public var isPinned: Bool = false

    public init(
        id: UUID = UUID(),
        groupID: UUID = UUID(),
        authorMemberID: UUID = UUID(),
        text: String = "",
        createdAt: Date = Date(),
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

public extension NoteEntity {
    func toDomain() -> GroupNote {
        GroupNote(id: id, groupID: groupID, authorMemberID: authorMemberID,
                  text: text, createdAt: createdAt, isPinned: isPinned)
    }
}
