//
//  AppKeys.swift
//  RoomieSync
//
//  계획서 참조: 리팩토링 — 산재된 문자열 키 통합
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-20
//
//  AppStorage / UserDefaults / Notification / AppGroup 키를 한 곳에 모은다.
//  새 키 추가 시 반드시 여기 등록 — 산재 방지.
//

import Foundation

public enum AppKeys {

    // MARK: - @AppStorage (사용자 설정)

    public enum Storage {
        public static let didCompleteOnboarding = "didCompleteOnboarding"
        public static let currentGroupID         = "currentGroupID"
    }

    // MARK: - AppGroup (메인 앱 ↔ 위젯 공유)

    public enum AppGroup {
        public static let identifier = "group.com.roomiesync.shared"
        public static let snapshot   = "RoomieSync.SharedSnapshot.v1"
        public static let pendingActions = "RoomieSync.PendingWidgetActions.v1"
    }

    // MARK: - CloudKit

    public enum CloudKit {
        public static let containerID = "iCloud.com.roomiesync.app"
    }

    // MARK: - URL Scheme

    public enum URLScheme {
        public static let main = "roomiesync"
    }

    // MARK: - Notification 카테고리 / 액션 ID

    public enum NotifyCategory {
        public static let duty       = "CATEGORY_DUTY"
        public static let settlement = "CATEGORY_SETTLEMENT"
    }
    public enum NotifyAction {
        public static let complete   = "ACTION_COMPLETE"
        public static let swap       = "ACTION_SWAP"
        public static let openSettle = "ACTION_OPEN_SETTLE"
    }

    // MARK: - Widget Kind ID (WidgetCenter reload 시 사용)

    public enum WidgetKind {
        public static let todayChore     = "TodayChoreWidget"
        public static let lockScreen     = "TodayChoreLockScreenWidget"
    }
}
