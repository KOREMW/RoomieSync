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

@MainActor
public struct RepositoryBundle {
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
    @MainActor
    public static func live(container: ModelContainer) -> RepositoryBundle {
        RepositoryBundle(
            group:   SwiftDataGroupRepository(modelContainer: container),
            chore:   SwiftDataChoreRepository(modelContainer: container),
            expense: SwiftDataExpenseRepository(modelContainer: container),
            device:  DeviceIdentifierProvider()
        )
    }

    /// Preview / 테스트 — InMemory.
    @MainActor
    public static func preview() -> RepositoryBundle {
        RepositoryBundle(
            group:   InMemoryGroupRepository(),
            chore:   InMemoryChoreRepository(),
            expense: InMemoryExpenseRepository(),
            device:  FixedDeviceIdentifierProvider("preview")
        )
    }
}

private struct RepositoryBundleKey: EnvironmentKey {
    @MainActor
    static let defaultValue: RepositoryBundle = .preview()
}

public extension EnvironmentValues {
    var repositories: RepositoryBundle {
        get { self[RepositoryBundleKey.self] }
        set { self[RepositoryBundleKey.self] = newValue }
    }
}
