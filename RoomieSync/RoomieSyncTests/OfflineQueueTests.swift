//
//  OfflineQueueTests.swift
//  RoomieSyncTests
//
//  계획서 참조: 6.3 오프라인, 6.4 오프라인 → 온라인 복귀
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Testing
import Foundation
@testable import RoomieSync

// MARK: - Mock 원격 (모든 전송 성공)

private actor MockRemote: RemoteSyncProtocol {
    private(set) var applied: [QueuedOperation] = []

    func apply(_ op: QueuedOperation) async throws {
        applied.append(op)
    }
}

// MARK: - Mock 원격 (N 번째 호출에서 1 회 실패 후 성공)

private actor FailingRemote: RemoteSyncProtocol {
    private(set) var applied: [QueuedOperation] = []
    private var failOnceAtIndex: Int
    private var callCount: Int = 0

    init(failOnceAtIndex: Int) { self.failOnceAtIndex = failOnceAtIndex }

    func apply(_ op: QueuedOperation) async throws {
        callCount += 1
        if callCount == failOnceAtIndex + 1 {   // 1-based
            failOnceAtIndex = -1   // 다음부터는 성공
            throw RepositoryError.networkUnavailable
        }
        applied.append(op)
    }
}

@Suite("OfflineQueue — enqueue & flush")
struct OfflineQueueTests {

    @Test("3건 enqueue 후 flush 시 모두 순서 보존하여 전달")
    func flushAllInOrder() async throws {
        let remote = MockRemote()
        let queue = OfflineQueue(remote: remote)

        let exp1 = TestFixtures.makeExpense(amount: 1_000, paidBy: UUID(), participants: [UUID()])
        let exp2 = TestFixtures.makeExpense(amount: 2_000, paidBy: UUID(), participants: [UUID()])
        let exp3 = TestFixtures.makeExpense(amount: 3_000, paidBy: UUID(), participants: [UUID()])

        await queue.enqueue(.createExpense(exp1))
        await queue.enqueue(.createExpense(exp2))
        await queue.enqueue(.createExpense(exp3))

        let processed = try await queue.flush()
        #expect(processed == 3)

        let applied = await remote.applied
        #expect(applied.count == 3)
        #expect(applied[0] == .createExpense(exp1))
        #expect(applied[1] == .createExpense(exp2))
        #expect(applied[2] == .createExpense(exp3))

        let remaining = await queue.pendingCount
        #expect(remaining == 0)
    }

    @Test("flush 중 실패 시 그 위치에서 중단, 나머지는 큐에 남음")
    func flushStopsOnFailure() async throws {
        let remote = FailingRemote(failOnceAtIndex: 1)   // 2번째 호출에서 실패
        let queue = OfflineQueue(remote: remote)

        await queue.enqueue(.createExpense(TestFixtures.makeExpense(amount: 1_000, paidBy: UUID(), participants: [UUID()])))
        await queue.enqueue(.createExpense(TestFixtures.makeExpense(amount: 2_000, paidBy: UUID(), participants: [UUID()])))
        await queue.enqueue(.createExpense(TestFixtures.makeExpense(amount: 3_000, paidBy: UUID(), participants: [UUID()])))

        // 첫 flush — 1개 성공 후 2번째에서 throw
        do {
            _ = try await queue.flush()
            Issue.record("실패가 발생해야 하는데 통과함")
        } catch {
            // 예상된 실패
        }

        let pendingAfter = await queue.pendingCount
        #expect(pendingAfter == 2, "1개 성공 + 2개 남아야 함, 실제: \(pendingAfter)")

        // 재시도 flush — 이번엔 모두 성공
        let processed = try await queue.flush()
        #expect(processed == 2)

        let final = await queue.pendingCount
        #expect(final == 0)
    }

    @Test("빈 큐 flush 는 0 반환")
    func emptyFlush() async throws {
        let remote = MockRemote()
        let queue = OfflineQueue(remote: remote)
        let processed = try await queue.flush()
        #expect(processed == 0)
    }
}
