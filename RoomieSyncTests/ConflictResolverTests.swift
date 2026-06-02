//
//  ConflictResolverTests.swift
//  RoomieSyncTests
//
//  계획서 참조: 6.3 last-write-wins, 6.4 CloudKit 동기화 충돌
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Testing
import Foundation
@testable import RoomieSync

@Suite("ConflictResolver — last-write-wins")
struct ConflictResolverTests {

    @Test("ChoreCompletion: 더 늦은 timestamp 가 채택")
    func choreCompletion_laterWins() {
        let choreID = UUID()
        let memberID = UUID()
        let earlier = ChoreCompletion(
            choreID: choreID,
            memberID: memberID,
            completedAt: Date(timeIntervalSince1970: 1000),
            deviceIdentifier: "device-A"
        )
        let later = ChoreCompletion(
            choreID: choreID,
            memberID: memberID,
            completedAt: Date(timeIntervalSince1970: 2000),
            deviceIdentifier: "device-B"
        )

        let resolved = ConflictResolver.resolve(local: earlier, remote: later)
        #expect(resolved.id == later.id)

        let reversed = ConflictResolver.resolve(local: later, remote: earlier)
        #expect(reversed.id == later.id)
    }

    @Test("ChoreCompletion: 동일 timestamp 면 deviceID 사전순 큰 쪽 (결정적)")
    func choreCompletion_deterministicTieBreak() {
        let when = Date(timeIntervalSince1970: 5000)
        let a = ChoreCompletion(choreID: UUID(), memberID: UUID(), completedAt: when, deviceIdentifier: "AAA")
        let b = ChoreCompletion(choreID: UUID(), memberID: UUID(), completedAt: when, deviceIdentifier: "ZZZ")

        let r1 = ConflictResolver.resolve(local: a, remote: b)
        let r2 = ConflictResolver.resolve(local: b, remote: a)

        #expect(r1.id == b.id)
        #expect(r2.id == b.id)
    }

    @Test("Expense: isSettled=true 가 우선 (감사 추적성)")
    func expense_settledWins() {
        let groupID = UUID()
        let paidBy = UUID()
        let settled = TestFixtures.makeExpense(amount: 10_000, paidBy: paidBy, participants: [paidBy])
        var settledMutable = settled
        settledMutable.isSettled = true
        settledMutable.date = Date(timeIntervalSince1970: 1000)   // 더 오래된 timestamp

        let pending = TestFixtures.makeExpense(amount: 12_000, paidBy: paidBy, participants: [paidBy])
        var pendingMutable = pending
        pendingMutable.date = Date(timeIntervalSince1970: 5000)   // 더 최근

        // settled 가 timestamp 가 더 오래됐지만 isSettled 가 true 라 우선
        let resolved = ConflictResolver.resolve(local: settledMutable, remote: pendingMutable)
        #expect(resolved.id == settledMutable.id)
    }

    @Test("Expense: 둘 다 pending 이면 더 늦은 date 채택")
    func expense_laterDateWins() {
        let paidBy = UUID()
        var a = TestFixtures.makeExpense(amount: 10_000, paidBy: paidBy, participants: [paidBy])
        a.date = Date(timeIntervalSince1970: 1000)
        var b = TestFixtures.makeExpense(amount: 20_000, paidBy: paidBy, participants: [paidBy])
        b.date = Date(timeIntervalSince1970: 2000)

        let resolved = ConflictResolver.resolve(local: a, remote: b)
        #expect(resolved.id == b.id)
    }
}
