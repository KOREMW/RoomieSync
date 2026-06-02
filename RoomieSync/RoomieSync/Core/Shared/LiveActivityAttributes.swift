//
//  LiveActivityAttributes.swift
//  RoomieSync
//
//  Live Activity 속성 정의 — 메인 앱(시작/갱신/종료)과 위젯 확장(렌더링)
//  양쪽에서 참조하므로 Core/Shared 에 둔다. (UI 레이아웃은 LiveActivity/ 에 분리)
//

import ActivityKit
import Foundation

public struct ChoreInProgressAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var elapsedSeconds: Int
        public var memberInitials: String
        public init(elapsedSeconds: Int = 0, memberInitials: String) {
            self.elapsedSeconds = elapsedSeconds
            self.memberInitials = memberInitials
        }
    }

    public var choreTitle: String
    public var choreIcon: String
    public var memberName: String
    public var startedAt: Date

    public init(choreTitle: String, choreIcon: String,
                memberName: String, startedAt: Date = .now) {
        self.choreTitle = choreTitle
        self.choreIcon = choreIcon
        self.memberName = memberName
        self.startedAt = startedAt
    }
}

public struct SettlementCountdownAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var daysRemaining: Int
        public var receiveAmountKRW: Int
        public init(daysRemaining: Int, receiveAmountKRW: Int) {
            self.daysRemaining = daysRemaining
            self.receiveAmountKRW = receiveAmountKRW
        }
    }
    public var groupName: String
    public init(groupName: String) { self.groupName = groupName }
}
