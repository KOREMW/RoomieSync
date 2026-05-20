//
//  OfflineQueue.swift
//  RoomieSync
//
//  계획서 참조: 6.3 오프라인 (SwiftData 로컬 후 복귀 시 CloudKit 동기화), 6.4 오프라인 → 온라인 복귀 테스트
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  CloudKit 자체 큐는 시스템이 일부 처리하나, 도메인 작업 단위 (지출 1건 / 가사 완료 1건)
//  순서 보장과 재시도 제어를 위해 별도 큐를 둔다.
//

import Foundation

/// 오프라인 큐가 실행할 단위 작업.
public enum QueuedOperation: Sendable, Equatable {
    case createExpense(Expense)
    case recordChoreCompletion(ChoreCompletion)
    case markExpenseSettled(expenseID: UUID)
}

/// 큐가 위임할 원격 동기화 인터페이스 — 3주차 CloudKit 어댑터 또는 테스트 mock 이 구현.
public protocol RemoteSyncProtocol: Sendable {
    func apply(_ op: QueuedOperation) async throws
}

public actor OfflineQueue {
    private var pending: [QueuedOperation] = []
    private let remote: any RemoteSyncProtocol

    public init(remote: any RemoteSyncProtocol) {
        self.remote = remote
    }

    public func enqueue(_ op: QueuedOperation) {
        pending.append(op)
    }

    public var pendingCount: Int { pending.count }

    public func snapshot() -> [QueuedOperation] { pending }

    /// 순차 flush — 하나 실패하면 그 위치에서 중단하고 나머지는 큐에 남김.
    /// 반환: 성공적으로 전송된 작업 개수.
    @discardableResult
    public func flush() async throws -> Int {
        var processed = 0
        while !pending.isEmpty {
            let head = pending[0]
            try await remote.apply(head)
            pending.removeFirst()
            processed += 1
        }
        return processed
    }
}
