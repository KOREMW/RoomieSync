//
//  SettlementSummarySheet.swift
//  RoomieSync
//
//  계획서 참조: 6.1 #6 월말 정산, 3.3 채무 단순화 결과 표시
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct SettlementSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let plan: [Settlement]
    let members: [Member]

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.l) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("최소 송금안")
                            .font(Typo.sectionTitle())
                        Text("\(plan.count)건의 송금으로 정산이 완료돼요")
                            .font(Typo.caption())
                            .foregroundStyle(Tokens.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)

                ScrollView {
                    VStack(spacing: Spacing.m) {
                        ForEach(plan) { s in
                            settlementRow(s)
                                .padding(.horizontal, Spacing.l)
                        }
                    }
                }

                Spacer()
            }
            .padding(.top, Spacing.l)
            .background(Tokens.surface.ignoresSafeArea())
            .navigationTitle("정산 결과")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func settlementRow(_ s: Settlement) -> some View {
        let from = members.first(where: { $0.id == s.fromMemberID })
        let to = members.first(where: { $0.id == s.toMemberID })

        HStack(spacing: Spacing.m) {
            if let from { MemberAvatarView(member: from, size: 36) }
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(from?.name ?? "?")
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Tokens.textTertiary)
                    Text(to?.name ?? "?")
                }
                .font(Typo.body())
                Text("토스 / 카카오페이로 송금")
                    .font(Typo.caption())
                    .foregroundStyle(Tokens.textTertiary)
            }
            Spacer()
            Text(CurrencyFormatter.format(s.amount))
                .font(Typo.amount(18))
                .foregroundStyle(Tokens.primary)
            if let to { MemberAvatarView(member: to, size: 36) }
        }
        .padding(Spacing.l)
        .background(Tokens.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
    }
}

#Preview {
    let m1 = Member(name: "김지훈", avatarColorHex: "#4F46E5", groupID: UUID())
    let m2 = Member(name: "박서연", avatarColorHex: "#10B981", groupID: UUID())
    let m3 = Member(name: "이민호", avatarColorHex: "#F59E0B", groupID: UUID())
    let plan = [
        Settlement(groupID: UUID(), fromMemberID: m2.id, toMemberID: m1.id, amount: 9_900),
        Settlement(groupID: UUID(), fromMemberID: m3.id, toMemberID: m1.id, amount: 14_500)
    ]
    return SettlementSummarySheet(plan: plan, members: [m1, m2, m3])
}
