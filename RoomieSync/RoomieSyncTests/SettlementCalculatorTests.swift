//
//  SettlementCalculatorTests.swift
//  RoomieSyncTests
//
//  계획서 참조: 3.3 채무 단순화, 6.4 테스트 시나리오 #1
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  검증 invariant:
//   (a) ∑ net_balance ≈ 0
//   (b) 송금 횟수 ≤ N − 1   (N = 비영(非零) 잔액 멤버 수)
//   (c) 각 멤버 in − out (netFlow) == net_balance
//
//  Swift Testing (@Test) 사용. parameterized 로 15 개 케이스를 데이터 드리븐 표현.
//

import Testing
import Foundation
@testable import RoomieSync

// MARK: - 시나리오 정의

struct SettlementCase: Sendable, CustomStringConvertible {
    let label: String
    let memberCount: Int
    let expenses: [(paidByIndex: Int, amount: Decimal, participantIndices: [Int])]

    var description: String { "\(memberCount)인-\(label)" }
}

// MARK: - 3 인 시나리오 5 개

private let threePersonCases: [SettlementCase] = [
    SettlementCase(
        label: "균등1건",
        memberCount: 3,
        expenses: [(0, 9_900, [0, 1, 2])]
    ),
    SettlementCase(
        label: "단방향2건",
        memberCount: 3,
        expenses: [
            (0, 30_000, [0, 1, 2]),
            (0, 15_000, [0, 1, 2])
        ]
    ),
    SettlementCase(
        label: "양방향",
        memberCount: 3,
        expenses: [
            (0, 30_000, [0, 1, 2]),
            (1, 15_000, [0, 1, 2]),
            (2, 9_000,  [0, 1, 2])
        ]
    ),
    SettlementCase(
        label: "부분참여",
        memberCount: 3,
        expenses: [
            (0, 20_000, [0, 1]),     // 0 이 2 명 식사
            (1, 12_000, [1, 2])      // 1 이 다른 2 명과
        ]
    ),
    SettlementCase(
        label: "한명만결제",
        memberCount: 3,
        expenses: [
            (2, 60_000, [0, 1, 2]),
            (2, 30_000, [0, 1, 2]),
            (2, 15_000, [0, 1, 2])
        ]
    )
]

// MARK: - 4 인 시나리오 5 개

private let fourPersonCases: [SettlementCase] = [
    SettlementCase(
        label: "균등1건",
        memberCount: 4,
        expenses: [(0, 40_000, [0, 1, 2, 3])]
    ),
    SettlementCase(
        label: "각자결제",
        memberCount: 4,
        expenses: [
            (0, 12_000, [0, 1, 2, 3]),
            (1, 12_000, [0, 1, 2, 3]),
            (2, 12_000, [0, 1, 2, 3]),
            (3, 12_000, [0, 1, 2, 3])
        ]
    ),
    SettlementCase(
        label: "복잡혼합",
        memberCount: 4,
        expenses: [
            (0, 50_000, [0, 1, 2, 3]),
            (1, 28_000, [1, 2]),
            (2, 9_900,  [0, 1, 2, 3]),
            (3, 42_000, [0, 1, 2, 3])
        ]
    ),
    SettlementCase(
        label: "두명만참여",
        memberCount: 4,
        expenses: [
            (0, 22_000, [0, 1]),
            (2, 18_000, [2, 3]),
            (1, 10_000, [0, 1, 2, 3])
        ]
    ),
    SettlementCase(
        label: "큰금액",
        memberCount: 4,
        expenses: [
            (0, 1_200_000, [0, 1, 2, 3]),  // 보증금 분담
            (1, 50_000,    [0, 1, 2, 3]),
            (2, 75_000,    [0, 1, 2, 3])
        ]
    )
]

// MARK: - 5 인 시나리오 5 개

private let fivePersonCases: [SettlementCase] = [
    SettlementCase(
        label: "균등1건",
        memberCount: 5,
        expenses: [(0, 50_000, [0, 1, 2, 3, 4])]
    ),
    SettlementCase(
        label: "체인구조",
        memberCount: 5,
        expenses: [
            (0, 10_000, [0, 1]),
            (1, 10_000, [1, 2]),
            (2, 10_000, [2, 3]),
            (3, 10_000, [3, 4])
        ]
    ),
    SettlementCase(
        label: "한명소외",
        memberCount: 5,
        expenses: [
            (0, 30_000, [0, 1, 2, 3]),
            (1, 30_000, [0, 1, 2, 3]),
            (2, 30_000, [0, 1, 2, 3])
        ]
    ),
    SettlementCase(
        label: "대형정산",
        memberCount: 5,
        expenses: [
            (0, 137_500, [0, 1, 2, 3, 4]),
            (3, 42_000,  [0, 1, 2, 3, 4]),
            (4, 31_800,  [0, 1, 2, 3, 4]),
            (1, 15_800,  [0, 1, 2, 3, 4]),
            (2, 9_900,   [0, 1, 2, 3, 4])
        ]
    ),
    SettlementCase(
        label: "결제자2명",
        memberCount: 5,
        expenses: [
            (0, 80_000, [0, 1, 2, 3, 4]),
            (4, 80_000, [0, 1, 2, 3, 4])
        ]
    )
]

// MARK: - 통합 케이스

private let allCases: [SettlementCase] =
    threePersonCases + fourPersonCases + fivePersonCases

// MARK: - 파라미터라이즈 테스트

@Suite("SettlementCalculator — 채무 단순화 invariant")
struct SettlementCalculatorTests {

    @Test("invariant (a)(b)(c) 모두 성립", arguments: allCases)
    func invariants(_ scenario: SettlementCase) {
        let members = TestFixtures.makeMembers(count: scenario.memberCount)
        let expenses = scenario.expenses.map { tuple in
            TestFixtures.makeExpense(
                amount: tuple.amount,
                paidBy: members[tuple.paidByIndex].id,
                participants: tuple.participantIndices.map { members[$0].id }
            )
        }

        let net = SettlementCalculator.netBalances(expenses: expenses, members: members)

        // (a) ∑ net_balance ≈ 0
        let sum = net.values.reduce(Decimal(0), +)
        #expect(
            abs(sum) < Decimal(0.01),
            "[\(scenario)] net_balance 합이 0이 아님: \(sum)"
        )

        let settlements = SettlementCalculator.calculate(
            expenses: expenses,
            members: members,
            groupID: TestFixtures.groupID
        )

        // (b) 송금 횟수 ≤ N − 1 (N = 비영 잔액 멤버 수)
        let nonZeroCount = net.values.filter { abs($0) >= Decimal(0.01) }.count
        if nonZeroCount > 0 {
            #expect(
                settlements.count <= nonZeroCount - 1,
                "[\(scenario)] 송금 횟수 \(settlements.count) > N-1=\(nonZeroCount - 1)"
            )
        }

        // (c) netFlow == net_balance
        let flow = SettlementCalculator.netFlow(
            settlements: settlements,
            memberIDs: members.map(\.id)
        )
        for member in members {
            let netForMember = net[member.id] ?? 0
            let flowForMember = flow[member.id] ?? 0
            let diff = netForMember - flowForMember
            #expect(
                abs(diff) < Decimal(0.01),
                "[\(scenario)] \(member.name) net=\(netForMember) flow=\(flowForMember) diff=\(diff)"
            )
        }

        // 추가: 모든 송금 amount > 0
        for s in settlements {
            #expect(s.amount > 0, "[\(scenario)] 0원 송금 발생")
            #expect(s.fromMemberID != s.toMemberID, "[\(scenario)] 자기 자신 송금 발생")
        }
    }

    @Test("빈 입력은 빈 결과")
    func emptyInput() {
        let members = TestFixtures.makeMembers(count: 3)
        let settlements = SettlementCalculator.calculate(
            expenses: [],
            members: members,
            groupID: TestFixtures.groupID
        )
        #expect(settlements.isEmpty)
    }

    @Test("멤버 0명이면 빈 결과")
    func zeroMembers() {
        let settlements = SettlementCalculator.calculate(
            expenses: [],
            members: [],
            groupID: TestFixtures.groupID
        )
        #expect(settlements.isEmpty)
    }
}
