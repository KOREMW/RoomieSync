//
//  RotationTests.swift
//  RoomieSyncTests
//
//  계획서 참조: 2 P0 ② 가사 자동 로테이션, 6.4 가사 로테이션 무결성
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Testing
import Foundation
@testable import RoomieSync

@Suite("ChoreRotation — 로테이션 순서 무결성")
struct RotationTests {

    @Test("round-robin: 6명 그룹에서 12 사이클 회전 시 순서 보존")
    func roundRobin() {
        let members = TestFixtures.makeMembers(count: 6)
        var chore = TestFixtures.makeChore(rotationMemberIDs: members.map(\.id))
        var sequence: [UUID] = [chore.currentAssigneeID]

        for _ in 0..<12 {
            chore = ChoreRotation.rotateToNext(chore)
            sequence.append(chore.currentAssigneeID)
        }

        // 13개 시퀀스 = 시작 + 12회 회전
        for (idx, id) in sequence.enumerated() {
            let expected = members[idx % 6].id
            #expect(id == expected, "idx=\(idx)에서 회전 어긋남")
        }
    }

    @Test("swap: 현재와 다음 멤버 순서 교환 + currentAssignee 가 다음 멤버로")
    func swap() {
        let members = TestFixtures.makeMembers(count: 4)
        let chore = TestFixtures.makeChore(rotationMemberIDs: members.map(\.id))
        let originalOrder = chore.rotationMemberIDs

        let swapped = ChoreRotation.swapCurrentWithNext(chore)

        // index 0 과 1 이 교환되어야 함
        #expect(swapped.rotationMemberIDs[0] == originalOrder[1])
        #expect(swapped.rotationMemberIDs[1] == originalOrder[0])
        // currentAssignee 는 같은 index(0) 자리의 새 멤버 → 원래 다음 사람
        #expect(swapped.currentAssigneeID == originalOrder[1])
    }

    @Test("멤버 제거: currentAssignee 제거 시 다음 멤버로 점프")
    func removeCurrentAssignee() {
        let members = TestFixtures.makeMembers(count: 4)
        let chore = TestFixtures.makeChore(rotationMemberIDs: members.map(\.id))
        let original = chore.rotationMemberIDs

        let after = ChoreRotation.removingMember(original[0], from: chore)

        #expect(!after.rotationMemberIDs.contains(original[0]))
        #expect(after.currentAssigneeID == original[1])
        #expect(after.rotationMemberIDs.count == 3)
    }

    @Test("멤버 제거: 비-currentAssignee 제거 시 currentAssignee 유지")
    func removeOtherMember() {
        let members = TestFixtures.makeMembers(count: 4)
        let chore = TestFixtures.makeChore(rotationMemberIDs: members.map(\.id))
        let original = chore.rotationMemberIDs

        let after = ChoreRotation.removingMember(original[2], from: chore)

        #expect(after.currentAssigneeID == original[0])
        #expect(after.rotationMemberIDs.count == 3)
        #expect(!after.rotationMemberIDs.contains(original[2]))
    }

    @Test("멤버 추가: rotation 끝에 append, currentAssignee 불변")
    func addMember() {
        let members = TestFixtures.makeMembers(count: 3)
        let chore = TestFixtures.makeChore(rotationMemberIDs: members.map(\.id))
        let newMemberID = TestFixtures.memberIDs[3]

        let after = ChoreRotation.addingMember(newMemberID, to: chore)

        #expect(after.rotationMemberIDs.count == 4)
        #expect(after.rotationMemberIDs.last == newMemberID)
        #expect(after.currentAssigneeID == chore.currentAssigneeID)
    }

    @Test("멤버 추가: 중복 시 변화 없음")
    func addDuplicateMember() {
        let members = TestFixtures.makeMembers(count: 3)
        let chore = TestFixtures.makeChore(rotationMemberIDs: members.map(\.id))

        let after = ChoreRotation.addingMember(members[1].id, to: chore)

        #expect(after.rotationMemberIDs.count == 3)
        #expect(after.rotationMemberIDs == chore.rotationMemberIDs)
    }

    @Test("nextAssignee: 마지막에서 wrap-around")
    func wrapAround() {
        let members = TestFixtures.makeMembers(count: 3)
        var chore = TestFixtures.makeChore(rotationMemberIDs: members.map(\.id))
        chore.currentAssigneeID = members[2].id   // 마지막 멤버

        #expect(ChoreRotation.nextAssignee(chore) == members[0].id)
    }
}
