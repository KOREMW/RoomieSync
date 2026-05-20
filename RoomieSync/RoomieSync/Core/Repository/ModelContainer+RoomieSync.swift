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
            config = ModelConfiguration(
                "RoomieSync",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    public static func makePreview() -> ModelContainer {
        try! makePersistent(inMemoryOnly: true)
    }
}
