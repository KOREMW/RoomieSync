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
        SettlementEntity.self,
        NoteEntity.self
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
            // CloudKit 미러링은 ① Firestore 백엔드를 쓰지 않고 ② iCloud 계정이 있고
            // ③ iCloud entitlement 가 있는 빌드일 때만 켠다.
            //  - Firestore(Firebase) 사용 시 CloudKit 은 중복이고, entitlement 없는 빌드에서
            //    켜면 백그라운드 큐에서 크래시(흰 화면)한다 → 끈다.
            //  - LITE_BUILD(무료 사이드로드/친구 폰 배포)는 entitlement 가 없으므로 항상 끈다.
            let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
            var useCloudKit = iCloudAvailable
            if FirebaseBootstrap.isConfigured { useCloudKit = false }
            #if LITE_BUILD
            useCloudKit = false
            #endif
            config = ModelConfiguration(
                "RoomieSync",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: useCloudKit ? .private(cloudKitContainerID) : .none
            )
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    public static func makePreview() -> ModelContainer {
        try! makePersistent(inMemoryOnly: true)
    }
}
