//
//  InboxDismissStore.swift
//  RoomieSync
//
//  알림함에서 '내 화면에서만 숨김(삭제)'한 항목 id 를 그룹별로 로컬 저장.
//  공지는 그룹 공용이라 실제 Firestore 문서를 지우지 않고, 이 기기 알림함에서만 감춘다.
//

import Foundation

public enum InboxDismissStore {
    private static func key(_ groupID: UUID) -> String { "inboxDismissed.\(groupID.uuidString)" }

    public static func dismissed(_ groupID: UUID) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(groupID)) ?? [])
    }

    public static func contains(_ id: UUID, _ groupID: UUID) -> Bool {
        dismissed(groupID).contains(id.uuidString)
    }

    public static func add(_ id: UUID, _ groupID: UUID) {
        var set = dismissed(groupID)
        set.insert(id.uuidString)
        UserDefaults.standard.set(Array(set), forKey: key(groupID))
    }

    public static func add(_ ids: [UUID], _ groupID: UUID) {
        var set = dismissed(groupID)
        ids.forEach { set.insert($0.uuidString) }
        UserDefaults.standard.set(Array(set), forKey: key(groupID))
    }
}
