//
//  ShareController.swift
//  RoomieSync
//
//  계획서 참조: 7 기술 스택 — CloudKit Sharing, 3주차 3-2
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//
//  Group 1개 = CKShare 1개. 호스트가 share() 로 생성 → 초대 링크/메시지로 전달 →
//  수신자가 acceptShare(metadata:) 로 자동 합류.
//
//  주의:
//   - SwiftData + CloudKit 자동 미러링과 별개로, CKShare 자체는 CloudKit API 를 직접 호출해야 함.
//   - GroupEntity 가 root record 가 되도록 한 그룹의 모든 자식 (Member/Chore/...) 이
//     동일 record zone 에 있어야 함 (3-1 §6 의 inverse 변경 금지와 연결).
//

import Foundation
import CloudKit

@MainActor
public final class ShareController {

    public static let shared = ShareController()
    private let container: CKContainer
    private let database: CKDatabase

    private init() {
        self.container = CKContainer(identifier: ModelContainerFactory.cloudKitContainerID)
        self.database = container.privateCloudDatabase
    }

    // MARK: - 호스트 측: 그룹 공유 생성

    /// Group 의 root CKRecord 에 CKShare 를 생성하고, 공유 URL 을 반환한다.
    /// UICloudSharingController 가 받아서 활동 시트(메시지/Mail/링크 복사)로 띄움.
    public func makeShare(for groupID: UUID) async throws -> (CKShare, CKContainer) {
        let recordID = CKRecord.ID(recordName: groupID.uuidString)
        let share = CKShare(rootRecord: CKRecord(recordType: "CD_GroupEntity", recordID: recordID))
        share[CKShare.SystemFieldKey.title] = "RoomieSync — 우리집 공유" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.roomiesync.group" as CKRecordValue
        share.publicPermission = .none   // 초대받은 사람만

        // CKShare 저장 — modifyRecords API
        let (saveResults, _) = try await database.modifyRecords(
            saving: [share],
            deleting: []
        )
        for (_, result) in saveResults {
            if case .failure(let error) = result {
                throw CKErrorMapper.map(error)
            }
        }
        return (share, container)
    }

    // MARK: - 수신자 측: 공유 수락

    /// 사용자가 공유 링크를 탭하면 SceneDelegate 가 받아서 이 메서드 호출.
    /// 수락 후 SwiftData 가 자동으로 shared zone 의 데이터를 미러링.
    public func acceptShare(metadata: CKShare.Metadata) async throws {
        do {
            _ = try await container.accept(metadata)
        } catch {
            throw CKErrorMapper.map(error)
        }
    }
}
