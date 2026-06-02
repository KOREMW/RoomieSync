//
//  NotificationService.swift
//  RoomieSync
//
//  계획서 참조: 4.2 푸시 알림 전략 (5 시나리오)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//
//  5 시나리오:
//   1) scheduleMorningDuty       오전 9시 — 당번 본인에게
//   2) scheduleEveningReminder   오후 9시 — 미완료자에게
//   3) notifyMemberCompletion    룸메 완료 시 — 그룹 전체
//   4) notifyExpenseAdded        지출 입력 시 — 참여자 전체 (무음)
//   5) scheduleMonthlySettlement 매월 마지막 날 오전 10시
//
//  Cancellation 규칙:
//   - 가사 1 개당 morning/evening 알림 식별자는 "duty.\(choreID).\(member)"
//   - 가사 삭제 / 멤버 회전 시 동일 식별자로 cancel 후 새로 schedule.
//   - 사용자가 OFF 한 알림 종류는 시도 자체 안 함 (UserDefaults 토글).
//

import Foundation
import UserNotifications

@MainActor
public final class NotificationService: NSObject {

    public static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        Task { await registerCategories() }
    }

    // MARK: - 권한 요청

    /// 사용자에게 권한 다이얼로그를 띄운다. 결과 true/false.
    /// 호출 시점: 온보딩 마지막 페이지 직후 또는 첫 가사 추가 직후.
    public func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                return granted
            } catch {
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - 시나리오 1: 오전 9시 당번

    /// 매일 오전 9시에 당번 본인에게 알림. cycleType.daily 가사 위주.
    public func scheduleMorningDuty(
        chore: Chore,
        memberName: String,
        hour: Int = 9,
        minute: Int = 0
    ) async {
        guard userPrefers(.morningDuty) else { return }
        let content = UNMutableNotificationContent()
        content.title = "오늘 \(chore.title) 당번이에요 \(chore.icon)"
        content.body = "\(memberName)님, 잊지 말고 챙겨주세요!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.choreDuty.rawValue
        content.userInfo = ["choreID": chore.id.uuidString]

        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)

        let request = UNNotificationRequest(
            identifier: "duty.morning.\(chore.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    // MARK: - 시나리오 2: 오후 9시 미완료 리마인드

    public func scheduleEveningReminder(
        chore: Chore,
        memberName: String,
        hour: Int = 21
    ) async {
        guard userPrefers(.eveningReminder) else { return }
        let content = UNMutableNotificationContent()
        content.title = "아직 \(chore.title) 안 하셨네요"
        content.body = "한 번 확인해보세요. \(memberName)님!"
        content.sound = .default
        content.interruptionLevel = .passive   // 조용한 톤 (계획서 4.2)

        var date = DateComponents()
        date.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)

        let request = UNNotificationRequest(
            identifier: "duty.evening.\(chore.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    // MARK: - 시나리오 3: 룸메이트 완료 알림

    public func notifyMemberCompletion(
        member: Member,
        chore: Chore
    ) async {
        guard userPrefers(.memberCompletion) else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(member.name)이 \(chore.title)을(를) 완료했어요 ✓"
        content.sound = .default
        content.interruptionLevel = .passive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "completion.\(chore.id.uuidString).\(member.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    // MARK: - 시나리오 4: 지출 입력 알림 (무음)

    public func notifyExpenseAdded(
        expense: Expense,
        payerName: String
    ) async {
        guard userPrefers(.expenseAdded) else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(payerName)이 \(expense.title) \(CurrencyFormatter.format(expense.amount))을 등록했어요"
        content.sound = nil   // 무음
        content.interruptionLevel = .passive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "expense.\(expense.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    // MARK: - 시나리오 5: 월말 정산

    /// 매월 마지막 날 오전 10시.
    public func scheduleMonthlySettlement(receiveAmount: Decimal) async {
        guard userPrefers(.monthlySettlement) else { return }
        let content = UNMutableNotificationContent()
        content.title = "이번 달 정산할 시간이에요"
        let amountStr = receiveAmount > 0
            ? "받을 돈 \(CurrencyFormatter.format(receiveAmount))"
            : "정산 항목을 확인해주세요"
        content.body = amountStr
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.monthlySettlement.rawValue

        // 매월 마지막 날 추출 — Calendar 기반
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.hour = 10
        comps.day = -1   // 다음 달 첫째 날 -1 = 이번 달 마지막 날 (iOS Calendar 트릭)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        _ = calendar  // silence warning in some configurations

        let request = UNNotificationRequest(
            identifier: "settlement.monthly",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    // MARK: - 통합 헬퍼

    /// 그룹 1 개에 대한 5 시나리오 일괄 예약.
    public func scheduleAll(
        for chores: [Chore],
        members: [Member]
    ) async {
        let byID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        for chore in chores {
            let assignee = byID[chore.currentAssigneeID]
            await scheduleMorningDuty(chore: chore, memberName: assignee?.name ?? "")
            await scheduleEveningReminder(chore: chore, memberName: assignee?.name ?? "")
        }
        // 월말 정산은 receiveAmount=0 으로 일단 등록, 실제 트리거 시 ViewModel 이 갱신.
        await scheduleMonthlySettlement(receiveAmount: 0)
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    public func cancelForChore(_ choreID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "duty.morning.\(choreID.uuidString)",
            "duty.evening.\(choreID.uuidString)"
        ])
    }

    // MARK: - 사용자 토글

    public enum NotificationKind: String, CaseIterable {
        case morningDuty       = "notif.morningDuty"
        case eveningReminder   = "notif.eveningReminder"
        case memberCompletion  = "notif.memberCompletion"
        case expenseAdded      = "notif.expenseAdded"
        case monthlySettlement = "notif.monthlySettlement"

        public var displayName: String {
            switch self {
            case .morningDuty:       return "오전 당번 알림"
            case .eveningReminder:   return "저녁 미완료 리마인드"
            case .memberCompletion:  return "룸메이트 완료 알림"
            case .expenseAdded:      return "지출 입력 알림"
            case .monthlySettlement: return "월말 정산 알림"
            }
        }

        public var defaultValue: Bool {
            switch self {
            case .memberCompletion: return false   // 피로도 방지 (계획서 4.2)
            default: return true
            }
        }
    }

    public func userPrefers(_ kind: NotificationKind) -> Bool {
        let key = kind.rawValue
        if UserDefaults.standard.object(forKey: key) == nil {
            return kind.defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    public func setPreference(_ kind: NotificationKind, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: kind.rawValue)
    }

    // MARK: - 카테고리/액션 (당번 알림 푸시에서 바로 "완료" 가능)

    private func registerCategories() async {
        let completeAction = UNNotificationAction(
            identifier: "ACTION_COMPLETE",
            title: "완료 표시",
            options: [.foreground]
        )
        let swapAction = UNNotificationAction(
            identifier: "ACTION_SWAP",
            title: "오늘 못해요",
            options: []
        )
        let dutyCategory = UNNotificationCategory(
            identifier: NotificationCategory.choreDuty.rawValue,
            actions: [completeAction, swapAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let settlementCategory = UNNotificationCategory(
            identifier: NotificationCategory.monthlySettlement.rawValue,
            actions: [
                UNNotificationAction(identifier: "ACTION_OPEN_SETTLE", title: "정산 시작", options: [.foreground])
            ],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([dutyCategory, settlementCategory])
    }

    // MARK: - 앱 아이콘 배지

    public func setBadge(_ count: Int) {
        Task { try? await center.setBadgeCount(count) }
    }
}

public enum NotificationCategory: String {
    case choreDuty        = "CATEGORY_DUTY"
    case monthlySettlement = "CATEGORY_SETTLEMENT"
}

// MARK: - Foreground 표시 + 액션 처리

extension NotificationService: @preconcurrency UNUserNotificationCenterDelegate {

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // foreground 에서도 배너 + 사운드 보여줌
        completionHandler([.banner, .sound, .badge, .list])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // TODO: ChoreViewModel.handleQuickAction(...) 호출
        // 액션 식별자별 분기는 4주차 Widget AppIntent 와 통합하면서 정리
        switch response.actionIdentifier {
        case "ACTION_COMPLETE":
            // 푸시 → 완료 처리 — userInfo 의 choreID 로 Repository 호출
            break
        case "ACTION_SWAP":
            break
        case "ACTION_OPEN_SETTLE":
            break
        default:
            break
        }
        completionHandler()
    }
}
