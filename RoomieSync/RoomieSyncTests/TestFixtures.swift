//
//  TestFixtures.swift
//  RoomieSyncTests
//
//  계획서 참조: 6.4 테스트 시나리오
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
@testable import RoomieSync

enum TestFixtures {

    static let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// 결정적 ID — UUID 정렬 결과가 1→2→3→4→5 순서가 되도록 한다.
    static let memberIDs: [UUID] = (1...6).map { i in
        UUID(uuidString: "00000000-0000-0000-0000-00000000000\(i)")!
    }

    static func makeMembers(count: Int) -> [Member] {
        precondition((1...6).contains(count))
        let colors = ["#4F46E5", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#06B6D4"]
        return (0..<count).map { idx in
            Member(
                id: memberIDs[idx],
                name: "멤버\(idx + 1)",
                avatarColorHex: colors[idx],
                groupID: groupID
            )
        }
    }

    static func makeExpense(
        title: String = "지출",
        amount: Decimal,
        paidBy: UUID,
        participants: [UUID],
        category: ExpenseCategory = .household
    ) -> Expense {
        Expense(
            groupID: groupID,
            title: title,
            amount: amount,
            paidByMemberID: paidBy,
            participantMemberIDs: participants,
            category: category
        )
    }

    static func makeChore(
        rotationMemberIDs: [UUID],
        cycle: ChoreCycle = .daily,
        title: String = "쓰레기 배출"
    ) -> Chore {
        Chore(
            groupID: groupID,
            title: title,
            icon: "trash",
            cycleType: cycle,
            currentAssigneeID: rotationMemberIDs[0],
            nextDueDate: .now,
            rotationMemberIDs: rotationMemberIDs
        )
    }
}
