//
//  ActivityLog.swift
//  RoomieSync
//
//  '이 기기에서 내가 만든 가사' id 를 그룹별로 로컬 기록.
//  가사는 생성자 필드가 없으므로, 생성 시 이 기기에 표시해 두고
//  새 가사 알림/알림함에서 생성자 본인을 제외하는 데 쓴다.
//

import Foundation

public enum ActivityLog {
    private static func createdChoresKey(_ groupID: UUID) -> String { "createdChores.\(groupID.uuidString)" }

    public static func markCreatedChore(_ choreID: UUID, groupID: UUID) {
        var set = createdChores(groupID)
        set.insert(choreID.uuidString)
        UserDefaults.standard.set(Array(set), forKey: createdChoresKey(groupID))
    }

    public static func createdChores(_ groupID: UUID) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: createdChoresKey(groupID)) ?? [])
    }

    public static func isMyCreatedChore(_ choreID: UUID, groupID: UUID) -> Bool {
        createdChores(groupID).contains(choreID.uuidString)
    }
}
