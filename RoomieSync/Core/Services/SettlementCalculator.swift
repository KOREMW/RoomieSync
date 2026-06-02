//
//  SettlementCalculator.swift
//  RoomieSync
//
//  계획서 참조: 3.3 핵심 알고리즘 — 채무 단순화 (Debt Simplification)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  알고리즘 (계획서 3.3 4단계 그대로):
//   1. 각 멤버 net_balance = (받을 돈) − (줄 돈)
//   2. 양수 큐(채권자) · 음수 큐(채무자) 분리·정렬
//   3. 두 큐의 head 끼리 min(|채권|, |채무|) 만큼 송금 매칭
//   4. 0 이 된 쪽 제거, 반복
//
//  Invariant:
//   ∑ net_balance ≈ 0  (Decimal 정확도 내, 부동소수 오차 없음)
//   결과 송금 횟수 ≤ N − 1  (N = 채권자 + 채무자, 0 잔액 멤버 제외)
//
//  복잡도: O(N log N) 정렬 + O(N) 매칭.
//

import Foundation

public enum SettlementCalculator {

    /// 메인 진입점.
    /// - Parameters:
    ///   - expenses: 정산 대상 지출 (보통 isSettled == false 만 넘김)
    ///   - members: 그룹 멤버 전원
    ///   - groupID: 결과 Settlement 의 groupID
    ///   - now: 결정적 테스트를 위해 시각 주입 가능 (기본값 .now 는 사용 안 함, settledAt 은 nil)
    /// - Returns: 그리디 매칭 결과 — 빈 배열이면 정산할 게 없음.
    public static func calculate(
        expenses: [Expense],
        members: [Member],
        groupID: UUID
    ) -> [Settlement] {
        guard !members.isEmpty, !expenses.isEmpty else { return [] }

        // ── 1) net_balance 계산 ─────────────────────────────
        var net: [UUID: Decimal] = Dictionary(uniqueKeysWithValues: members.map { ($0.id, 0) })

        for expense in expenses {
            let participants = expense.participantMemberIDs
            guard !participants.isEmpty, expense.amount > 0 else { continue }

            // 결제자는 amount 만큼 받을 권리
            net[expense.paidByMemberID, default: 0] += expense.amount
            // 참여자 각자는 자기 부담금(직접 입력 또는 균등)만큼 줄 의무
            for participantID in participants {
                net[participantID, default: 0] -= expense.share(for: participantID)
            }
        }

        // ── 2) 양수/음수 큐 분리·정렬 ───────────────────────
        // 결정적 결과를 위해 잔액 내림차순 정렬 + ID 사전순 tie-break.
        struct Balance: Equatable {
            let memberID: UUID
            var amount: Decimal
        }

        let epsilon: Decimal = 0.005   // KRW 1 원 미만은 0 으로 간주 (현실적으로 발생하지 않음)
        var creditors = net.compactMap { (id, bal) -> Balance? in
            bal > epsilon ? Balance(memberID: id, amount: bal) : nil
        }
        var debtors = net.compactMap { (id, bal) -> Balance? in
            bal < -epsilon ? Balance(memberID: id, amount: -bal) : nil   // 부호 반전 → 양수로
        }

        creditors.sort { lhs, rhs in
            if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
            return lhs.memberID.uuidString < rhs.memberID.uuidString
        }
        debtors.sort { lhs, rhs in
            if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
            return lhs.memberID.uuidString < rhs.memberID.uuidString
        }

        // ── 3·4) 그리디 매칭 ────────────────────────────────
        var settlements: [Settlement] = []

        var ci = 0   // creditors index
        var di = 0   // debtors index

        while ci < creditors.count && di < debtors.count {
            let pay = min(creditors[ci].amount, debtors[di].amount)
            settlements.append(Settlement(
                groupID: groupID,
                fromMemberID: debtors[di].memberID,
                toMemberID: creditors[ci].memberID,
                amount: pay
            ))
            creditors[ci].amount -= pay
            debtors[di].amount -= pay

            // 0 이 된 쪽 advance
            if creditors[ci].amount <= epsilon { ci += 1 }
            if debtors[di].amount <= epsilon { di += 1 }
        }

        return settlements
    }

    // MARK: - Diagnostics (테스트 용)

    /// 각 멤버의 net_balance — 테스트에서 invariant 검증용.
    public static func netBalances(
        expenses: [Expense],
        members: [Member]
    ) -> [UUID: Decimal] {
        var net: [UUID: Decimal] = Dictionary(uniqueKeysWithValues: members.map { ($0.id, 0) })
        for expense in expenses {
            let participants = expense.participantMemberIDs
            guard !participants.isEmpty, expense.amount > 0 else { continue }
            net[expense.paidByMemberID, default: 0] += expense.amount
            for pid in participants {
                net[pid, default: 0] -= expense.share(for: pid)
            }
        }
        return net
    }

    /// Settlement 적용 후 각 멤버의 in − out 합. net_balance 와 같아야 한다.
    public static func netFlow(
        settlements: [Settlement],
        memberIDs: [UUID]
    ) -> [UUID: Decimal] {
        var flow: [UUID: Decimal] = Dictionary(uniqueKeysWithValues: memberIDs.map { ($0, 0) })
        for s in settlements {
            flow[s.fromMemberID, default: 0] -= s.amount   // 송금 = 줄 돈 차감
            flow[s.toMemberID, default: 0]   += s.amount   // 수금 = 받을 돈 추가
        }
        return flow
    }
}
