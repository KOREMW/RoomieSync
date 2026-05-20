//
//  RoomieSyncApp.swift
//  RoomieSync
//
//  계획서 참조: 3.1 전체 구조 (Presentation Layer 진입점)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI
import SwiftData

@main
struct RoomieSyncApp: App {

    /// 앱 전역 ModelContainer.
    /// 3주차에 cloudKitDatabase = .private(...) 활성화 예정.
    let container: ModelContainer

    init() {
        do {
            self.container = try ModelContainerFactory.makePersistent(inMemoryOnly: false)
        } catch {
            // 실 운영에서는 onboarding 단계에서 에러 화면 전환,
            // 1주차/2주차 빌드 안정성을 위해 in-memory fallback.
            print("⚠️ ModelContainer 생성 실패 → in-memory fallback: \(error)")
            self.container = ModelContainerFactory.makePreview()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.repositories, .live(container: container))
        }
        .modelContainer(container)
    }
}
