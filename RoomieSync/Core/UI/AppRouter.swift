//
//  AppRouter.swift
//  RoomieSync
//
//  알림 탭 → 해당 기능 화면으로 이동시키기 위한 전역 라우터.
//  NotificationService 가 route 를 설정하면 MainTabView 가 반응해 탭 전환/시트 표시.
//

import Foundation
import Observation

@MainActor
@Observable
public final class AppRouter {
    public static let shared = AppRouter()

    public enum Route: Equatable {
        case chores       // 가사 탭
        case expenses     // 지출 탭
        case settlement   // 정산 화면(시트)
        case notes        // 공지 보드(시트)
        case inbox        // 알림함(시트)
    }

    /// 처리 대기 중인 라우트. 화면이 소비한 뒤 nil 로 되돌린다.
    public var pending: Route?

    private init() {}

    /// 알림 userInfo["route"] 문자열 → Route.
    public static func route(forKey key: String?) -> Route? {
        switch key {
        case "chores":     return .chores
        case "expenses":   return .expenses
        case "settlement": return .settlement
        case "notes":      return .notes
        case "inbox":      return .inbox
        default:           return nil
        }
    }
}
