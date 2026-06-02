//
//  InMemorySeed.swift
//  RoomieSync
//
//  계획서 참조: 2주차 #Preview 데이터 (시안 5장 그대로 재현)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

@MainActor
public enum InMemorySeed {

    /// 시안과 정확히 같은 3인 그룹 + 4개 가사 + 5개 지출.
    public static func preview() -> (RepositoryBundle, UUID) {
        let groupID = UUID()
        let m1 = Member(id: UUID(), name: "김지훈", avatarColorHex: "#4F46E5", groupID: groupID)
        let m2 = Member(id: UUID(), name: "박서연", avatarColorHex: "#10B981", groupID: groupID)
        let m3 = Member(id: UUID(), name: "이민호", avatarColorHex: "#F59E0B", groupID: groupID)
        let group = Group(
            id: groupID,
            name: "우리집",
            inviteCode: "ABC123",
            memberIDs: [m1.id, m2.id, m3.id]
        )

        let chores = [
            Chore(groupID: groupID, title: "쓰레기 배출", icon: "🗑",
                  cycleType: .daily, currentAssigneeID: m1.id, nextDueDate: .now,
                  rotationMemberIDs: [m1.id, m2.id, m3.id]),
            Chore(groupID: groupID, title: "설거지", icon: "🍽",
                  cycleType: .daily, currentAssigneeID: m2.id, nextDueDate: .now,
                  rotationMemberIDs: [m2.id, m3.id, m1.id]),
            Chore(groupID: groupID, title: "거실 청소", icon: "🧹",
                  cycleType: .weekly, currentAssigneeID: m3.id, nextDueDate: .now,
                  rotationMemberIDs: [m3.id, m1.id, m2.id]),
            Chore(groupID: groupID, title: "화장실 청소", icon: "🚿",
                  cycleType: .weekly, currentAssigneeID: m1.id, nextDueDate: .now,
                  rotationMemberIDs: [m1.id, m2.id, m3.id])
        ]

        let now = Date.now
        let expenses = [
            Expense(groupID: groupID, title: "휴지 12롤", amount: 9_900,
                    paidByMemberID: m1.id, participantMemberIDs: [m1.id, m2.id, m3.id],
                    date: now.addingTimeInterval(-2 * 86400), category: .household),
            Expense(groupID: groupID, title: "세제 + 섬유유연제", amount: 15_800,
                    paidByMemberID: m2.id, participantMemberIDs: [m1.id, m2.id, m3.id],
                    date: now.addingTimeInterval(-5 * 86400), category: .household),
            Expense(groupID: groupID, title: "전기요금", amount: 42_000,
                    paidByMemberID: m3.id, participantMemberIDs: [m1.id, m2.id, m3.id],
                    date: now.addingTimeInterval(-7 * 86400), category: .utility),
            Expense(groupID: groupID, title: "가스요금", amount: 31_800,
                    paidByMemberID: m2.id, participantMemberIDs: [m1.id, m2.id, m3.id],
                    date: now.addingTimeInterval(-14 * 86400), category: .utility, memo: nil),
            Expense(groupID: groupID, title: "장보기", amount: 38_000,
                    paidByMemberID: m1.id, participantMemberIDs: [m1.id, m2.id, m3.id],
                    date: now.addingTimeInterval(-1 * 86400), category: .food)
        ]
        // 가스요금 1건은 정산완료 표시
        var expensesMutable = expenses
        expensesMutable[3].isSettled = true

        let bundle = RepositoryBundle(
            group: InMemoryGroupRepository(seed: [(group, [m1, m2, m3])]),
            chore: InMemoryChoreRepository(seedChores: chores),
            expense: InMemoryExpenseRepository(seedExpenses: expensesMutable)
        )
        return (bundle, groupID)
    }
}
