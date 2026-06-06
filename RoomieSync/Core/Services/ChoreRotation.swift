//
//  ChoreRotation.swift
//  RoomieSync
//
//  계획서 참조: 2 P0 ② 가사 자동 로테이션, 6.3 당번 회피
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  순수 함수 모듈 — Repository 와 분리하여 단위 테스트 (1-6 RotationTests) 대상으로.
//  로테이션 순서는 chore.rotationMemberIDs 스냅샷 기준 (멤버 추가/제거 시 무결성 보장).
//

import Foundation

public enum ChoreRotation {

    /// 현재 assignee 다음 차례 멤버 ID. 마지막이면 처음으로 wrap-around.
    /// rotationMemberIDs 에서 currentAssignee 를 못 찾으면 첫 번째 멤버 반환 (안전 디폴트).
    public static func nextAssignee(_ chore: Chore) -> UUID {
        guard !chore.rotationMemberIDs.isEmpty else { return chore.currentAssigneeID }
        guard let idx = chore.rotationMemberIDs.firstIndex(of: chore.currentAssigneeID) else {
            return chore.rotationMemberIDs[0]
        }
        let next = (idx + 1) % chore.rotationMemberIDs.count
        return chore.rotationMemberIDs[next]
    }

    // MARK: - 날짜 기준 담당자 (완료가 아니라 '날짜가 지나야' 회전)

    /// rotationStartedAt 을 기준점(인덱스 0)으로, 주기가 한 번 지날 때마다 다음 멤버로 회전.
    /// 완료 버튼을 눌러도 그날의 담당자는 그대로이고, 날짜(주/월)가 넘어가야 다음 사람으로 바뀐다.
    public static func assigneeIndex(_ chore: Chore, on date: Date = .now) -> Int {
        let count = chore.rotationMemberIDs.count
        guard count > 0 else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: chore.rotationStartedAt)
        let today = cal.startOfDay(for: date)
        let periods: Int
        switch chore.cycleType {
        case .daily:
            periods = max(0, cal.dateComponents([.day], from: start, to: today).day ?? 0)
        case .weekly:
            let days = max(0, cal.dateComponents([.day], from: start, to: today).day ?? 0)
            periods = days / 7
        case .monthly:
            periods = max(0, cal.dateComponents([.month], from: start, to: today).month ?? 0)
        case .once:
            periods = 0   // 1회성은 회전 없음
        }
        return periods % count
    }

    /// 날짜 기준 현재(오늘) 담당자 멤버 ID.
    public static func assignee(_ chore: Chore, on date: Date = .now) -> UUID {
        let ids = chore.rotationMemberIDs
        guard !ids.isEmpty else { return chore.currentAssigneeID }
        return ids[assigneeIndex(chore, on: date)]
    }

    /// 날짜 기준 다음 차례 담당자 멤버 ID (1인 로테이션이면 nil).
    public static func upcomingAssignee(_ chore: Chore, on date: Date = .now) -> UUID? {
        let ids = chore.rotationMemberIDs
        guard ids.count > 1 else { return nil }
        let next = (assigneeIndex(chore, on: date) + 1) % ids.count
        return ids[next]
    }

    /// 완료 확정 시 호출 — assignee 를 다음 멤버로 회전하고 nextDueDate 갱신.
    public static func rotateToNext(_ chore: Chore, now: Date = .now) -> Chore {
        var updated = chore
        updated.currentAssigneeID = nextAssignee(chore)
        let days = chore.cycleType.approximateIntervalDays
        updated.nextDueDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        return updated
    }

    /// "오늘 못해요" 스왑 — 현재 멤버와 다음 멤버의 rotationMemberIDs 순서 교환.
    /// currentAssignee 도 다음 멤버로 이동 (계획서 6.3 당번 회피 → 다음 멤버에게 요청 → 수락 시 순서 교체).
    public static func swapCurrentWithNext(_ chore: Chore, now: Date = .now) -> Chore {
        var updated = chore
        guard chore.rotationMemberIDs.count > 1 else { return chore }
        // 날짜 기준 '오늘 슬롯'과 다음 슬롯을 교환 → 오늘 담당이 다음 사람에게 넘어간다.
        let curIdx = assigneeIndex(chore, on: now)
        let nextIdx = (curIdx + 1) % chore.rotationMemberIDs.count
        updated.rotationMemberIDs.swapAt(curIdx, nextIdx)
        return updated
    }

    /// 멤버가 제거되었을 때 rotation 안정성 — 제거된 멤버를 순서에서 빼고
    /// currentAssignee 가 제거 대상이면 다음 차례로 이동.
    public static func removingMember(_ memberID: UUID, from chore: Chore) -> Chore {
        var updated = chore
        // 현재 assignee 가 제거 대상이면 미리 다음으로 회전
        if chore.currentAssigneeID == memberID {
            updated.currentAssigneeID = nextAssignee(chore)
        }
        updated.rotationMemberIDs.removeAll { $0 == memberID }
        // 회전 결과가 비어버린 케이스: currentAssigneeID 는 그대로 유지(변동 없음),
        // 다음 사이클부터 미할당 상태가 된다 — 별도 처리 불필요.
        return updated
    }

    /// 신규 멤버를 rotation 끝에 추가.
    public static func addingMember(_ memberID: UUID, to chore: Chore) -> Chore {
        var updated = chore
        guard !updated.rotationMemberIDs.contains(memberID) else { return chore }
        updated.rotationMemberIDs.append(memberID)
        return updated
    }
}
