//
//  SettlementBreakdownView.swift
//  RoomieSync
//
//  홈 '이번 주 정산'의 ⓘ 에서 진입 — 받을 돈/줄 돈에 해당하는 지출 내역을 분리해 보여준다.
//  작성자: 엄민욱 (2091188)
//

import SwiftUI

struct SettlementBreakdownView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories
    @Environment(\.dismiss) private var dismiss

    @State private var expenses: [Expense] = []
    @State private var membersByID: [UUID: Member] = [:]
    @State private var meID: UUID? = nil
    @State private var isLoading = true

    /// 내가 결제 → 다른 참여자에게 받을 돈이 있는 지출.
    private var receiveItems: [Expense] {
        guard let me = meID else { return [] }
        return expenses.filter { !$0.isSettled && $0.paidByMemberID == me && $0.participantMemberIDs.contains(where: { $0 != me }) }
    }
    /// 남이 결제 + 내가 참여 → 내가 줄 돈이 있는 지출.
    private var payItems: [Expense] {
        guard let me = meID else { return [] }
        return expenses.filter { !$0.isSettled && $0.paidByMemberID != me && $0.participantMemberIDs.contains(me) }
    }

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if isLoading {
                    ProgressView()
                } else {
                    List {
                        Section {
                            if receiveItems.isEmpty {
                                Text("받을 돈에 해당하는 지출이 없어요").font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                            } else {
                                ForEach(receiveItems) { row($0, isReceive: true) }
                            }
                        } header: {
                            Label("받을 돈 내역", systemImage: "arrow.down.circle.fill").foregroundStyle(Tokens.receiveCardText)
                        }

                        Section {
                            if payItems.isEmpty {
                                Text("줄 돈에 해당하는 지출이 없어요").font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                            } else {
                                ForEach(payItems) { row($0, isReceive: false) }
                            }
                        } header: {
                            Label("줄 돈 내역", systemImage: "arrow.up.circle.fill").foregroundStyle(Tokens.payCardText)
                        }
                    }
                }
            }
            .navigationTitle("정산 내역")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
            .task { await load() }
        }
    }

    @ViewBuilder
    private func row(_ exp: Expense, isReceive: Bool) -> some View {
        let payer = membersByID[exp.paidByMemberID]?.name ?? "?"
        // 받을 돈: 다른 참여자가 내게 줄 합계 = 1인 부담 × (나 제외 참여자 수)
        // 줄 돈: 내가 낼 1인 부담
        let amount: Decimal = {
            guard let me = meID, !exp.participantMemberIDs.isEmpty else { return 0 }
            if isReceive {
                // 다른 참여자들이 내게 줄 부담금 합
                return exp.participantMemberIDs.filter { $0 != me }.reduce(Decimal(0)) { $0 + exp.share(for: $1) }
            } else {
                return exp.share(for: me)
            }
        }()
        HStack(spacing: Spacing.m) {
            Image(systemName: exp.category.sfSymbolName)
                .foregroundStyle(Tokens.primary).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(exp.title).font(Typo.bodyBold())
                Text("\(payer) 결제 · 총 \(CurrencyFormatter.format(exp.amount))")
                    .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
            }
            Spacer()
            Text((isReceive ? "+" : "-") + CurrencyFormatter.format(amount))
                .font(Typo.bodyBold())
                .foregroundStyle(isReceive ? Tokens.receiveCardText : Tokens.payCardText)
        }
    }

    @MainActor
    private func load() async {
        do {
            let members = try await repositories.group.fetchMembers(ofGroup: groupID)
            membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            meID = CurrentMemberStore.resolve(members, groupID: groupID)?.id
            expenses = try await repositories.expense.fetchExpenses(groupID: groupID, includeSettled: false)
        } catch {
            expenses = []
        }
        isLoading = false
    }
}
