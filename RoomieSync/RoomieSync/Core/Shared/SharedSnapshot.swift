//
//  SharedSnapshot.swift
//  RoomieSync
//
//  계획서 참조: 4.1 홈/잠금화면 위젯 — 위젯이 메인 앱과 공유할 데이터 DTO
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-09
//
//  AppGroup (group.com.roomiesync.shared) UserDefaults 로 직렬화/역직렬화.
//  Widget Extension 은 SwiftData 컨테이너 접근이 무거우니 가벼운 스냅샷을 쓴다.
//

import Foundation

public struct SharedSnapshot: Codable, Sendable, Equatable {

    public struct ChoreItem: Codable, Sendable, Equatable, Identifiable {
        public var id: UUID
        public var title: String
        public var icon: String
        public var assigneeName: String
        public var assigneeColorHex: String
        public var isMine: Bool
        public var isCompleted: Bool

        public init(id: UUID, title: String, icon: String,
                    assigneeName: String, assigneeColorHex: String,
                    isMine: Bool, isCompleted: Bool) {
            self.id = id; self.title = title; self.icon = icon
            self.assigneeName = assigneeName; self.assigneeColorHex = assigneeColorHex
            self.isMine = isMine; self.isCompleted = isCompleted
        }
    }

    public var groupID: UUID
    public var groupName: String
    public var generatedAt: Date
    public var todayChores: [ChoreItem]
    public var undoneCountForMe: Int

    public init(groupID: UUID, groupName: String, generatedAt: Date = .now,
                todayChores: [ChoreItem], undoneCountForMe: Int) {
        self.groupID = groupID; self.groupName = groupName
        self.generatedAt = generatedAt; self.todayChores = todayChores
        self.undoneCountForMe = undoneCountForMe
    }

    public static let empty = SharedSnapshot(
        groupID: UUID(),
        groupName: "—",
        todayChores: [],
        undoneCountForMe: 0
    )
}

/// AppGroup UserDefaults 키.
public enum SharedSnapshotStore {
    public static let appGroupID = AppKeys.AppGroup.identifier
    public static let userDefaultsKey = AppKeys.AppGroup.snapshot

    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func write(_ snapshot: SharedSnapshot) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: userDefaultsKey)
        }
    }

    public static func read() -> SharedSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: userDefaultsKey),
              let snap = try? JSONDecoder().decode(SharedSnapshot.self, from: data)
        else { return .empty }
        return snap
    }
}
