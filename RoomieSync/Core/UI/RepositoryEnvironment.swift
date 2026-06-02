//
//  RepositoryEnvironment.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern — ViewModel 에 의존성 주입
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  Repository 를 SwiftUI Environment 로 노출하여 View → ViewModel 주입 통일.
//  Preview 에서는 InMemory* 로 자동 대체.
//

import SwiftUI
import SwiftData

// 보관하는 Repository 들은 모두 Sendable(actor) 이므로 번들 자체도 Sendable.
// @MainActor 격리가 없어 EnvironmentValues 기본값으로 바로 쓸 수 있다.
public struct RepositoryBundle: Sendable {
    public let group: any GroupRepositoryProtocol
    public let chore: any ChoreRepositoryProtocol
    public let expense: any ExpenseRepositoryProtocol
    public let device: any DeviceIdentifierProviding

    public init(
        group: any GroupRepositoryProtocol,
        chore: any ChoreRepositoryProtocol,
        expense: any ExpenseRepositoryProtocol,
        device: any DeviceIdentifierProviding = DeviceIdentifierProvider()
    ) {
        self.group = group
        self.chore = chore
        self.expense = expense
        self.device = device
    }

    /// 실 운영 — SwiftData 백엔드.
    public static func live(container: ModelContainer) -> RepositoryBundle {
        RepositoryBundle(
            group:   SwiftDataGroupRepository(modelContainer: container),
            chore:   SwiftDataChoreRepository(modelContainer: container),
            expense: SwiftDataExpenseRepository(modelContainer: container),
            device:  DeviceIdentifierProvider()
        )
    }

    /// Preview / 테스트 — InMemory.
    public static func preview() -> RepositoryBundle {
        RepositoryBundle(
            group:   InMemoryGroupRepository(),
            chore:   InMemoryChoreRepository(),
            expense: InMemoryExpenseRepository(),
            device:  FixedDeviceIdentifierProvider("preview")
        )
    }

    #if canImport(FirebaseFirestore)
    /// CloudKit 대안 — Cloud Firestore 백엔드 (FirebaseBootstrap.isConfigured 일 때 사용).
    public static func firestore() -> RepositoryBundle {
        RepositoryBundle(
            group:   FirestoreGroupRepository(),
            chore:   FirestoreChoreRepository(),
            expense: FirestoreExpenseRepository(),
            device:  DeviceIdentifierProvider()
        )
    }
    #endif
}

public extension EnvironmentValues {
    @Entry var repositories: RepositoryBundle = .preview()
}
