//
//  LiveActivityController.swift
//  RoomieSync
//
//  계획서 참조: 4.3 Live Activity — 시작/업데이트/종료 트리거
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-09
//

import Foundation
import ActivityKit

@MainActor
public final class LiveActivityController {

    public static let shared = LiveActivityController()
    private init() {}

    private var inProgressActivity: Activity<ChoreInProgressAttributes>?
    private var countdownActivity: Activity<SettlementCountdownAttributes>?

    // MARK: - Chore in progress

    /// 사용자가 "가사 시작" 누르면 호출.
    public func startChore(_ chore: Chore, member: Member) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endChoreIfNeeded()

        let attrs = ChoreInProgressAttributes(
            choreTitle: chore.title,
            choreIcon: chore.icon,
            memberName: member.name,
            startedAt: .now
        )
        let state = ChoreInProgressAttributes.ContentState(
            elapsedSeconds: 0,
            memberInitials: member.initials
        )
        do {
            inProgressActivity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: .now.addingTimeInterval(7200)),
                pushType: nil
            )
        } catch {
            print("⚠️ Live Activity 시작 실패: \(error)")
        }
    }

    public func endChoreIfNeeded() {
        guard let act = inProgressActivity else { return }
        inProgressActivity = nil
        // Activity 는 Sendable 이 아니지만, @MainActor 로 직렬화되어 실제 경합은 없다.
        nonisolated(unsafe) let activity = act
        Task { await activity.end(activity.content, dismissalPolicy: .immediate) }
    }

    // MARK: - 정산 카운트다운

    public func startSettlementCountdown(groupName: String, daysRemaining: Int, receiveKRW: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endCountdownIfNeeded()
        let attrs = SettlementCountdownAttributes(groupName: groupName)
        let state = SettlementCountdownAttributes.ContentState(
            daysRemaining: daysRemaining,
            receiveAmountKRW: receiveKRW
        )
        do {
            countdownActivity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("⚠️ 정산 Live Activity 실패: \(error)")
        }
    }

    public func updateCountdown(daysRemaining: Int, receiveKRW: Int) {
        guard let act = countdownActivity else { return }
        let content = ActivityContent(
            state: SettlementCountdownAttributes.ContentState(
                daysRemaining: daysRemaining, receiveAmountKRW: receiveKRW
            ),
            staleDate: nil
        )
        nonisolated(unsafe) let activity = act
        Task { await activity.update(content) }
    }

    public func endCountdownIfNeeded() {
        guard let act = countdownActivity else { return }
        countdownActivity = nil
        nonisolated(unsafe) let activity = act
        Task { await activity.end(activity.content, dismissalPolicy: .immediate) }
    }
}
