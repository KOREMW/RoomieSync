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

    // 정산 계좌 (로컬 저장) — 저장 버튼으로만 반영
    @AppStorage("settlementBankName") private var bankName: String = ""
    @AppStorage("settlementAccountNumber") private var accountNumber: String = ""
    @AppStorage("settlementAccountHolder") private var accountHolder: String = ""
    @State private var draftBank: String = ""
    @State private var draftAccount: String = ""
    @State private var draftHolder: String = ""
    @State private var accountSaved: Bool = false
    @State private var revealAccount: Bool = false

    // 그룹 나가기
    @AppStorage(AppKeys.Storage.currentGroupID) private var currentGroupIDString: String = ""
    @State private var showLeaveConfirm: Bool = false

    // 알림 (당번 알림은 가사별로 이동 → 여기선 그룹 알림만)
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
                TextField("은행 (예: 카카오뱅크)", text: $draftBank)
                    .onChange(of: draftBank) { _, _ in accountSaved = false }
                HStack {
                    SwiftUI.Group {
                        if revealAccount {
                            TextField("계좌번호 (숫자만)", text: $draftAccount)
                        } else {
                            SecureField("계좌번호 (숫자만)", text: $draftAccount)
                        }
                    }
                    .keyboardType(.numberPad)
                    .onChange(of: draftAccount) { _, newValue in
                        // 숫자만 허용
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue { draftAccount = digits }
                        accountSaved = false
                    }
                    Button {
                        revealAccount.toggle()
                    } label: {
                        Image(systemName: revealAccount ? "eye.slash" : "eye")
                            .foregroundStyle(Tokens.textSecondary)
                    }
                    .buttonStyle(.borderless)
                }
                TextField("예금주", text: $draftHolder)
                    .onChange(of: draftHolder) { _, _ in accountSaved = false }
                Button {
                    bankName = draftBank.trimmingCharacters(in: .whitespaces)
                    accountNumber = draftAccount.trimmingCharacters(in: .whitespaces)
                    accountHolder = draftHolder.trimmingCharacters(in: .whitespaces)
                    accountSaved = true
                    revealAccount = false
                    HapticManager.shared.success()
                } label: {
                    HStack {
                        Spacer()
                        Label(accountSaved ? "저장됨" : "계좌 저장", systemImage: accountSaved ? "checkmark" : "tray.and.arrow.down")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }   // 구분선 전체 너비로
                Text("룸메이트가 정산할 때 보낼 내 계좌입니다. 계좌번호는 숨겨지며 '눈' 버튼으로 확인하세요.")
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
                    Button("알림 설정 열기") {
                        // iOS 16+ : 앱의 '알림' 설정 화면으로 바로 이동 (권한 허용 토글 직전).
                        let target = UIApplication.openNotificationSettingsURLString
                        let url = URL(string: target) ?? URL(string: UIApplication.openSettingsURLString)
                        if let url { UIApplication.shared.open(url) }
                    }
                }
            }

            Section {
                Text("당번 알림(오전/저녁)은 가사마다 따로 설정합니다. 가사 탭에서 가사를 추가/수정할 때 켜고 끌 수 있어요.")
                    .font(Typo.caption())
                    .foregroundStyle(Tokens.textSecondary)
            } header: { Text("당번 알림") }

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
                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Label("이 그룹에서 나가기", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("마이페이지")
        .navigationBarTitleDisplayMode(.inline)
        .alert("이 그룹에서 나갈까요?", isPresented: $showLeaveConfirm) {
            Button("나가기", role: .destructive) { Task { await leaveGroup() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("다른 모임이 있으면 그 모임으로 이동하고, 없으면 시작 화면으로 돌아갑니다.")
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            permissionGranted = settings.authorizationStatus == .authorized
            draftBank = bankName
            draftAccount = accountNumber
            draftHolder = accountHolder
            await loadProfile()
        }
    }

    @MainActor
    private func leaveGroup() async {
        let repo = repositories.group
        // 1) 내 멤버 제거 (myMemberID 가 비어도 멤버 목록 첫 멤버로 보강)
        let before = (try? await repo.fetchMembers(ofGroup: groupID)) ?? []
        if let id = myMemberID ?? before.first?.id {
            try? await repo.removeMember(id)
        }
        // 2) 남은 멤버가 없으면 그룹 자체 삭제 → 모임 목록에 남지 않도록
        let remaining = (try? await repo.fetchMembers(ofGroup: groupID)) ?? []
        if remaining.isEmpty {
            try? await repo.deleteGroup(groupID)
        }
        // 3) 다른 모임이 있으면 그 모임의 홈으로, 없으면 시작 화면("")
        let others = (try? await repo.fetchAllGroups())?.filter { $0.id != groupID } ?? []
        currentGroupIDString = others.first?.id.uuidString ?? ""
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
}

#Preview {
    NavigationStack { MyPageView(groupID: UUID()) }
        .environment(\.repositories, .preview())
}
