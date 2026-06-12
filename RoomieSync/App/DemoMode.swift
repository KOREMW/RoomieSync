//
//  DemoMode.swift
//  RoomieSync
//
//  스크린샷/시연용 데모 모드 — 실행 인자로 시드 데이터 + 시작 탭/시트를 지정.
//  -DemoSeed            : 온보딩을 건너뛰고 시드된 인메모리 그룹으로 바로 진입
//  -DemoTab <name>      : home|chore|expense|stats|mypage 중 시작 탭
//  -DemoSheet add       : 진입 직후 지출 추가 시트 표시
//  운영 빌드에는 영향 없음(인자 없으면 전부 비활성).
//

import Foundation

@MainActor
enum DemoMode {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-DemoSeed")

    static let initialTab: Int = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-DemoTab"), i + 1 < args.count else { return 0 }
        switch args[i + 1] {
        case "home":    return 0
        case "chore":   return 1
        case "expense": return 2
        case "stats":   return 3
        case "mypage":  return 4
        default:        return 0
        }
    }()

    static var presentAddExpense: Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-DemoSheet"), i + 1 < args.count else { return false }
        return args[i + 1] == "add"
    }

    private static var cached: (RepositoryBundle, UUID)?
    static func seeded() -> (RepositoryBundle, UUID) {
        if let c = cached { return c }
        let s = InMemorySeed.preview()
        cached = s
        return s
    }
}
