//
//  SettingsView.swift
//  RoomieSync
//
//  계획서 참조: 4.2 푸시 알림 — 사용자별 토글 (피로도 방지)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories

    @State private var morningTime: Date = Self.defaultTime(hour: 9)
    @State private var eveningTime: Date = Self.defaultTime(hour: 21)
    @State private var morningOn: Bool = NotificationService.shared.userPrefers(.morningDuty)
    @State private var eveningOn: Bool = NotificationService.shared.userPrefers(.eveningReminder)
    @State private var memberCompletionOn: Bool = NotificationService.shared.userPrefers(.memberCompletion)
    @State private var expenseAddedOn: Bool = NotificationService.shared.userPrefers(.expenseAdded)
    @State private var monthlyOn: Bool = NotificationService.shared.userPrefers(.monthlySettlement)
    @State private var permissionGranted: Bool = false

    var body: some View {
        Form {
            Section("알림 권한") {
                HStack {
                    Image(systemName: permissionGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(permissionGranted ? Tokens.success : Tokens.warning)
                    Text(permissionGranted ? "활성화됨" : "비활성화 — 설정 앱에서 권한 허용 필요")
                        .font(Typo.caption())
                }
                if !permissionGranted {
                    Button("설정 앱 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            Section("당번 알림") {
                Toggle("오전 당번 알림", isOn: $morningOn)
                    .onChange(of: morningOn) { _, v in
                        NotificationService.shared.setPreference(.morningDuty, enabled: v)
                    }
                if morningOn {
                    DatePicker("오전 알림 시각", selection: $morningTime, displayedComponents: .hourAndMinute)
                }
                Toggle("저녁 미완료 리마인드", isOn: $eveningOn)
                    .onChange(of: eveningOn) { _, v in
                        NotificationService.shared.setPreference(.eveningReminder, enabled: v)
                    }
                if eveningOn {
                    DatePicker("저녁 리마인드 시각", selection: $eveningTime, displayedComponents: .hourAndMinute)
                }
            }

            Section("그룹 알림") {
                Toggle("룸메이트가 완료했을 때", isOn: $memberCompletionOn)
                    .onChange(of: memberCompletionOn) { _, v in
                        NotificationService.shared.setPreference(.memberCompletion, enabled: v)
                    }
                Toggle("새 지출이 등록됐을 때 (무음)", isOn: $expenseAddedOn)
                    .onChange(of: expenseAddedOn) { _, v in
                        NotificationService.shared.setPreference(.expenseAdded, enabled: v)
                    }
                Toggle("월말 정산 리마인드", isOn: $monthlyOn)
                    .onChange(of: monthlyOn) { _, v in
                        NotificationService.shared.setPreference(.monthlySettlement, enabled: v)
                    }
            }

            Section("그룹") {
                Button("이 그룹에서 나가기", role: .destructive) {
                    // TODO: GroupRepo.removeMember + 정산 잔액 0 검증 + 그룹 nil 처리
                }
            }

            Section("정보") {
                LabeledContent("학번", value: "2091188")
                LabeledContent("작성자", value: "엄민욱")
                LabeledContent("버전", value: "1.0.0")
                LabeledContent("라이선스", value: "MIT")
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            permissionGranted = settings.authorizationStatus == .authorized
        }
    }

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    }
}

#Preview {
    NavigationStack { SettingsView(groupID: UUID()) }
        .environment(\.repositories, .preview())
}
