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
        // GoogleService-Info.plist 가 있으면 Firebase 구성 → Firestore 백엔드 사용.
        FirebaseBootstrap.configureIfAvailable()
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
                .environment(\.repositories, DemoMode.isEnabled ? DemoMode.seeded().0 : backendBundle())
                // 디자인 토큰이 라이트 고정색이라 다크모드에서는 흰 카드 위 흰 글자가 됨 → 라이트 고정.
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }

    /// 백엔드 선택: Firebase 구성 시 Firestore, 아니면 기존 SwiftData(+CloudKit)/로컬.
    private func backendBundle() -> RepositoryBundle {
        #if canImport(FirebaseFirestore)
        if FirebaseBootstrap.isConfigured { return .firestore() }
        #endif
        return .live(container: container)
    }
}
