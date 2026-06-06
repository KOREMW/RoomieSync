//
//  SettlementActionView.swift
//  RoomieSync
//
//  '정산하기' 진입 — 채무 단순화 결과를 바탕으로
//   · 받을 돈: 내 계좌(마이페이지)를 공유/복사
//   · 낼 돈: 받는 사람(정산 상대)의 계좌로 토스 송금 링크 / 계좌 복사
//  작성자: 엄민욱 (2091188)
//

import SwiftUI

/// 송금 링크 생성 (best-effort). 토스 송금 스킴 + 계좌 복사 폴백.
enum PaymentLink {
    /// 토스 송금: supertoss://send?bank=은행&accountNo=계좌&amount=금액
    static func toss(bank: String, account: String, amount: Decimal) -> URL? {
        var comps = URLComponents(string: "supertoss://send")
        comps?.queryItems = [
            URLQueryItem(name: "bank", value: bank),
            URLQueryItem(name: "accountNo", value: account),
            URLQueryItem(name: "amount", value: NSDecimalNumber(decimal: amount).stringValue)
        ]
        return comps?.url
    }
    static func accountString(bank: String, account: String) -> String {
        "\(bank) \(account)"
    }
}

struct SettlementActionView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var membersByID: [UUID: Member] = [:]
    @State private var meID: UUID? = nil
    @State private var settlements: [Settlement] = []
    @State private var pendingExpenseIDs: [UUID] = []
    @State private var isLoading = true
    @State private var copied = false
    @State private var errorMessage: String? = nil

    private var me: Member? { meID.flatMap { membersByID[$0] } }
    private var toMe: [Settlement] { settlements.filter { $0.toMemberID == meID } }      // 받을 돈
    private var fromMe: [Settlement] { settlements.filter { $0.fromMemberID == meID } }  // 낼 돈

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if isLoading {
                    ProgressView()
                } else if settlements.isEmpty {
                    ContentUnavailableView("정산할 내역이 없어요", systemImage: "checkmark.circle",
                                           description: Text("미정산 지출이 균형 상태입니다."))
                } else {
                    List {
                        if !toMe.isEmpty { receiveSection }
                        if !fromMe.isEmpty { paySection }
                        Section {
                            Button {
                                Task { await markAllSettled() }
                            } label: {
                                HStack { Spacer(); Text("정산 완료로 표시").fontWeight(.semibold); Spacer() }
                            }
                        } footer: {
                            Text("송금을 마친 뒤 눌러주세요. 미정산 지출이 정산 완료 처리됩니다.")
                        }
                    }
                }
            }
            .navigationTitle("정산하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
            .alert("정산 처리 실패", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await load() }
        }
    }

    // 받을 돈 — 내 계좌 공유
    private var receiveSection: some View {
        Section {
            ForEach(toMe) { s in
                let payer = membersByID[s.fromMemberID]?.name ?? "?"
                HStack {
                    Text("\(payer) 님에게 받기")
                    Spacer()
                    Text(CurrencyFormatter.format(s.amount)).fontWeight(.bold)
                        .foregroundStyle(Tokens.receiveCardText)
                }
            }
            if let me, me.hasAccount {
                let shown = BankAccountFormatter.format(me.accountNumber ?? "", bank: me.bankName ?? "")
                Button {
                    // 복사·송금은 숫자만(은행 앱 호환). 표시만 하이픈.
                    copySensitive(PaymentLink.accountString(bank: me.bankName ?? "", account: me.accountNumber ?? ""))
                    copied = true
                } label: {
                    Label(copied ? "내 계좌 복사됨" : "내 계좌 복사 (\(me.bankName ?? "") \(shown))",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
            } else {
                Text("내 계좌가 없어요. 마이페이지에서 정산 계좌를 먼저 저장하세요.")
                    .font(Typo.caption()).foregroundStyle(Tokens.danger)
            }
        } header: {
            Label("받을 돈", systemImage: "arrow.down.circle.fill").foregroundStyle(Tokens.receiveCardText)
        }
    }

    // 낼 돈 — 상대 계좌로 송금
    private var paySection: some View {
        Section {
            ForEach(fromMe) { s in
                let payee = membersByID[s.toMemberID]
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack {
                        Text("\(payee?.name ?? "?") 님에게 보내기")
                        Spacer()
                        Text(CurrencyFormatter.format(s.amount)).fontWeight(.bold)
                            .foregroundStyle(Tokens.payCardText)
                    }
                    if let payee, payee.hasAccount {
                        Text("\(payee.bankName ?? "") \(BankAccountFormatter.format(payee.accountNumber ?? "", bank: payee.bankName ?? ""))")
                            .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                        HStack(spacing: Spacing.s) {
                            Button {
                                if let url = PaymentLink.toss(bank: payee.bankName ?? "",
                                                              account: payee.accountNumber ?? "",
                                                              amount: s.amount) {
                                    openURL(url)
                                }
                            } label: {
                                Label("토스로 송금", systemImage: "arrow.up.right.circle.fill")
                                    .font(Typo.caption()).fontWeight(.semibold)
                                    .padding(.horizontal, Spacing.m).padding(.vertical, 6)
                                    .background(Tokens.primary).foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            Button {
                                UIPasteboard.general.string = PaymentLink.accountString(bank: payee.bankName ?? "", account: payee.accountNumber ?? "")
                                copied = true
                            } label: {
                                Label("계좌 복사", systemImage: "doc.on.doc")
                                    .font(Typo.caption())
                                    .padding(.horizontal, Spacing.m).padding(.vertical, 6)
                                    .background(Tokens.surfaceMuted).foregroundStyle(Tokens.textPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("\(payee?.name ?? "상대")님이 아직 계좌를 등록하지 않았어요.")
                            .font(Typo.caption()).foregroundStyle(Tokens.danger)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Label("낼 돈", systemImage: "arrow.up.circle.fill").foregroundStyle(Tokens.payCardText)
        }
    }

    /// 민감정보(계좌)는 60초 후 자동 삭제 + 기기 로컬 전용으로 복사.
    private func copySensitive(_ text: String) {
        UIPasteboard.general.setItems(
            [["public.utf8-plain-text": text]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)]
        )
    }

    @MainActor
    private func load() async {
        do {
            let members = try await repositories.group.fetchMembers(ofGroup: groupID)
            membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            meID = CurrentMemberStore.resolve(members, groupID: groupID)?.id
            let pending = try await repositories.expense.fetchExpenses(groupID: groupID, includeSettled: false)
            pendingExpenseIDs = pending.map(\.id)
            settlements = SettlementCalculator.calculate(expenses: pending, members: members, groupID: groupID)
        } catch {
            settlements = []
        }
        isLoading = false
    }

    @MainActor
    private func markAllSettled() async {
        do {
            // 정산 완료 시각을 기록해 '정산 내역(#5)'에 남도록 한다.
            let stamped = settlements.map {
                Settlement(id: $0.id, groupID: $0.groupID, fromMemberID: $0.fromMemberID,
                           toMemberID: $0.toMemberID, amount: $0.amount, settledAt: .now)
            }
            if !stamped.isEmpty { try await repositories.expense.saveSettlements(stamped) }
            if !pendingExpenseIDs.isEmpty { try await repositories.expense.markSettled(pendingExpenseIDs) }
            HapticManager.shared.success()
            dismiss()
        } catch {
            HapticManager.shared.error()
            errorMessage = "정산 완료 처리에 실패했어요. 네트워크를 확인하고 다시 시도해주세요.\n(\(CKErrorMapper.userMessage(for: error)))"
        }
    }
}
