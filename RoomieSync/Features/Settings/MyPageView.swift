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

    // 정산 계좌 — 내 멤버 정보에 저장(동기화). 다른 멤버가 송금 시 조회.
    @State private var draftBank: String = ""
    @State private var draftAccount: String = ""
    @State private var accountSaved: Bool = false
    @State private var isSavingAccount: Bool = false
    @State private var revealAccount: Bool = false

    /// 정산 계좌 은행 선택 목록.
    private static let banks: [String] = [
        "카카오뱅크", "토스뱅크", "케이뱅크",
        "국민", "신한", "우리", "하나", "농협", "기업", "SC제일", "씨티",
        "부산", "대구", "경남", "광주", "전북", "제주",
        "새마을금고", "신협", "우체국", "산업", "수협"
    ]

    // 그룹 나가기
    @AppStorage(AppKeys.Storage.currentGroupID) private var currentGroupIDString: String = ""
    @State private var showLeaveConfirm: Bool = false

    // 실패 피드백 (조용한 실패 방지)
    @State private var errorMessage: String? = nil

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
                Picker("은행", selection: $draftBank) {
                    Text("은행 선택").tag("")
                    ForEach(Self.banks, id: \.self) { bank in
                        Text(bank).tag(bank)
                    }
                }
                .onChange(of: draftBank) { _, _ in
                    accountSaved = false
                    // 은행이 바뀌면 그 은행 형식대로 하이픈 재배치.
                    draftAccount = BankAccountFormatter.format(draftAccount, bank: draftBank)
                }
                HStack {
                    SwiftUI.Group {
                        if revealAccount {
                            TextField("계좌번호", text: $draftAccount)
                        } else {
                            SecureField("계좌번호", text: $draftAccount)
                        }
                    }
                    .keyboardType(.numberPad)
                    .onChange(of: draftAccount) { _, newValue in
                        // 선택한 은행 형식대로 하이픈 자동 분할(저장 시엔 숫자만 남는다).
                        // 지우면 자동으로 하이픈이 줄어 원상복구된다.
                        let formatted = BankAccountFormatter.format(newValue, bank: draftBank)
                        if formatted != newValue { draftAccount = formatted }
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
                Button {
                    Task { await saveAccount() }
                } label: {
                    HStack {
                        Spacer()
                        if isSavingAccount { ProgressView() }
                        else {
                            Label(accountSaved ? "저장됨" : "계좌 저장", systemImage: accountSaved ? "checkmark" : "tray.and.arrow.down")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(myMemberID == nil || isSavingAccount ||
                          draftBank.isEmpty || draftAccount.trimmingCharacters(in: .whitespaces).isEmpty)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }   // 구분선 전체 너비로
                Text("예금주는 내 이름(\(myName))으로 표시됩니다. 룸메이트가 정산할 때 이 계좌로 송금합니다.")
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
        .alert("문제가 발생했어요", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            permissionGranted = settings.authorizationStatus == .authorized
            await loadProfile()
        }
    }

    @MainActor
    private func leaveGroup() async {
        let repo = repositories.group
        do {
            // 1) 내 멤버 제거 (myMemberID 가 비어도 멤버 목록 첫 멤버로 보강)
            let before = try await repo.fetchMembers(ofGroup: groupID)
            if let id = myMemberID ?? before.first?.id {
                try await repo.removeMember(id)
            }
            // 2) 남은 멤버가 없으면 그룹 자체 삭제 → 모임 목록에 남지 않도록
            let remaining = try await repo.fetchMembers(ofGroup: groupID)
            if remaining.isEmpty {
                try await repo.deleteGroup(groupID)
            }
            // 3) 다른 모임이 있으면 그 모임의 홈으로, 없으면 시작 화면("")
            let others = (try? await repo.fetchAllGroups())?.filter { $0.id != groupID } ?? []
            currentGroupIDString = others.first?.id.uuidString ?? ""
        } catch {
            errorMessage = "그룹 나가기에 실패했어요. 네트워크를 확인하고 다시 시도해주세요.\n(\(CKErrorMapper.userMessage(for: error)))"
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
                draftBank = me.bankName ?? ""
                draftAccount = BankAccountFormatter.format(me.accountNumber ?? "", bank: me.bankName ?? "")
            }
        } catch {
            // 프로필 로드 실패는 조용히 무시(마이페이지의 알림 설정은 계속 사용 가능)
        }
    }

    @MainActor
    private func saveName() async {
        guard let id = myMemberID else { return }
        let trimmed = InputValidator.name(myName)
        guard !trimmed.isEmpty else { return }
        isSavingName = true
        defer { isSavingName = false }
        do {
            _ = try await repositories.group.updateMemberName(id, name: trimmed)
            myName = trimmed
            nameSaved = true
            HapticManager.shared.success()
        } catch {
            HapticManager.shared.error()
            errorMessage = "이름 저장에 실패했어요.\n(\(CKErrorMapper.userMessage(for: error)))"
        }
    }

    @MainActor
    private func saveAccount() async {
        guard let id = myMemberID else { return }
        isSavingAccount = true
        defer { isSavingAccount = false }
        do {
            _ = try await repositories.group.updateMemberAccount(
                id,
                bankName: draftBank.trimmingCharacters(in: .whitespaces),
                accountNumber: InputValidator.accountNumber(draftAccount)
            )
            accountSaved = true
            revealAccount = false
            HapticManager.shared.success()
        } catch {
            HapticManager.shared.error()
            errorMessage = "계좌 저장에 실패했어요.\n(\(CKErrorMapper.userMessage(for: error)))"
        }
    }
}

#Preview {
    NavigationStack { MyPageView(groupID: UUID()) }
        .environment(\.repositories, .preview())
}
