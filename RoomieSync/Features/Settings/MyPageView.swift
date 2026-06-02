//
//  MyPageView.swift
//  RoomieSync
//
//  계획서 참조: 4.2 푸시 알림 사용자별 토글 + 프로필/초대 코드 관리.
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//
//  하단 탭 "마이페이지" — 프로필(이름 수정)·초대 코드·알림 설정·그룹·정보.
//

import SwiftUI
import UserNotifications

struct MyPageView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories

    // 프로필 / 초대 코드
    @State private var myMemberID: UUID? = nil
    @State private var myName: String = ""
    @State private var inviteCode: String = ""
    @State private var isSavingName: Bool = false
    @State private var nameSaved: Bool = false
    @State private var codeCopied: Bool = false

    // 정산 계좌 (로컬 저장)
    @AppStorage("settlementBankName") private var bankName: String = ""
    @AppStorage("settlementAccountNumber") private var accountNumber: String = ""
    @AppStorage("settlementAccountHolder") private var accountHolder: String = ""

    // 알림
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
            // MARK: 프로필 (이름 수정)
            Section("내 프로필") {
                HStack {
                    TextField("이름", text: $myName)
                        .onChange(of: myName) { _, _ in nameSaved = false }
                    Button {
                        Task { await saveName() }
                    } label: {
                        if isSavingName { ProgressView() }
                        else { Text(nameSaved ? "저장됨" : "저장").fontWeight(.semibold) }
                    }
                    .disabled(myMemberID == nil ||
                              myName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              isSavingName)
                }
            }

            // MARK: 정산 계좌
            Section("정산 계좌") {
                TextField("은행 (예: 카카오뱅크)", text: $bankName)
                TextField("계좌번호", text: $accountNumber)
                    .keyboardType(.numbersAndPunctuation)
                TextField("예금주", text: $accountHolder)
                Text("룸메이트가 정산할 때 보낼 내 계좌입니다. 이 기기에 저장됩니다.")
                    .font(Typo.caption())
                    .foregroundStyle(Tokens.textSecondary)
            }

            // MARK: 초대 코드
            Section("초대 코드") {
                HStack {
                    Text(inviteCode.isEmpty ? "—" : inviteCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Tokens.primary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = inviteCode
                        codeCopied = true
                    } label: {
                        Label(codeCopied ? "복사됨" : "복사", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(inviteCode.isEmpty)
                }
                Text("이 코드를 룸메이트에게 공유하면 같은 그룹에 참여할 수 있어요.")
                    .font(Typo.caption())
                    .foregroundStyle(Tokens.textSecondary)
            }

            // MARK: 알림
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

            Section("정보") {
                LabeledContent("학번", value: "2091188")
                LabeledContent("작성자", value: "엄민욱")
                LabeledContent("버전", value: "1.0.0")
                LabeledContent("라이선스", value: "MIT")
            }
        }
        .navigationTitle("마이페이지")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            permissionGranted = settings.authorizationStatus == .authorized
            await loadProfile()
        }
    }

    @MainActor
    private func loadProfile() async {
        do {
            let group = try await repositories.group.fetchGroup(id: groupID)
            inviteCode = group.inviteCode
            let members = try await repositories.group.fetchMembers(ofGroup: groupID)
            if let me = members.first {
                myMemberID = me.id
                myName = me.name
            }
        } catch {
            // 프로필 로드 실패는 조용히 무시(마이페이지의 알림 설정은 계속 사용 가능)
        }
    }

    @MainActor
    private func saveName() async {
        guard let id = myMemberID else { return }
        let trimmed = myName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSavingName = true
        defer { isSavingName = false }
        do {
            _ = try await repositories.group.updateMemberName(id, name: trimmed)
            myName = trimmed
            nameSaved = true
            HapticManager.shared.success()
        } catch {
            // 실패 시 저장 상태 미표시
        }
    }

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    }
}

#Preview {
    NavigationStack { MyPageView(groupID: UUID()) }
        .environment(\.repositories, .preview())
}
