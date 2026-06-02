//
//  ModelContainer+RoomieSync.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern, 6.3 CloudKit 동기화
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  3주차 업데이트: cloudKitDatabase = .private(...) 활성화.
//

import Foundation
import SwiftData

public enum RoomieSyncSchema {
    public static let allTypes: [any PersistentModel.Type] = [
        GroupEntity.self,
        MemberEntity.self,
        ChoreEntity.self,
        ChoreCompletionEntity.self,
        ExpenseEntity.self,
        SettlementEntity.self
    ]
}

public enum ModelContainerFactory {
    public static let cloudKitContainerID = AppKeys.CloudKit.containerID

    @MainActor
    public static func makePersistent(inMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(RoomieSyncSchema.allTypes)
        let config: ModelConfiguration
        if inMemoryOnly {
            config = ModelConfiguration(
                "RoomieSync",
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        } else {
            // iCloud 계정이 없는 환경(예: iCloud 미로그인 시뮬레이터)에서는 CloudKit
            // 미러링 setup 이 백그라운드 큐에서 크래시한다. 계정이 있을 때만 CloudKit 을
            // 켜고, 없으면 로컬 전용 저장으로 폴백한다(동기화만 비활성, 기능은 정상).
            let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
            config = ModelConfiguration(
                "RoomieSync",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: iCloudAvailable ? .private(cloudKitContainerID) : .none
            )
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    public static func makePreview() -> ModelContainer {
        try! makePersistent(inMemoryOnly: true)
    }
}
