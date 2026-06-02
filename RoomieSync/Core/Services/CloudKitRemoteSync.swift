//
//  CloudKitRemoteSync.swift
//  RoomieSync
//
//  계획서 참조: 6.3 오프라인 → 온라인 복귀, 6.4 동기화 충돌
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//
//  OfflineQueue 가 사용하는 RemoteSyncProtocol 의 CloudKit 어댑터.
//  SwiftData + CloudKit 자동 미러링이 대부분의 동기화를 처리하므로,
//  본 어댑터는 "도메인 단위 작업이 반드시 원격에 도착했는지" 의 명시적 ACK 만 담당.
//
//  실제 구현: ExpenseRepository / ChoreRepository 를 다시 호출하여
//             SwiftData → CloudKit 미러링이 완료될 시간을 기다린 뒤 성공 반환.
//

import Foundation

public actor CloudKitRemoteSync: RemoteSyncProtocol {

    private let expenseRepo: any ExpenseRepositoryProtocol
    private let choreRepo: any ChoreRepositoryProtocol
    private let networkChecker: () async -> Bool

    public init(
        expense: any ExpenseRepositoryProtocol,
        chore: any ChoreRepositoryProtocol,
        networkChecker: @escaping () async -> Bool = { true }
    ) {
        self.expenseRepo = expense
        self.choreRepo = chore
        self.networkChecker = networkChecker
    }

    public func apply(_ op: QueuedOperation) async throws {
        guard await networkChecker() else {
            throw RepositoryError.networkUnavailable
        }
        switch op {
        case .createExpense(let expense):
            _ = try await expenseRepo.createExpense(expense)
        case .recordChoreCompletion(let completion):
            _ = try await choreRepo.recordCompletion(
                choreID: completion.choreID,
                memberID: completion.memberID,
                deviceIdentifier: completion.deviceIdentifier,
                isConfirmed: completion.isConfirmed
            )
        case .markExpenseSettled(let expenseID):
            try await expenseRepo.markSettled([expenseID])
        }
    }
}
