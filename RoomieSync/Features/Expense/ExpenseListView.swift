//
//  ExpenseListView.swift
//  RoomieSync
//
//  계획서 참조: Stitch 시안 ③ 공동 지출
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct ExpenseListView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories
    @State private var viewModel: ExpenseViewModel?
    @State private var showAddSheet: Bool = false
    @State private var settlementPlan: [Settlement] = []
    @State private var showSettlementSheet: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if let vm = viewModel {
                    monthTotalCard(vm)
                    filterChips(vm)
                    if vm.filtered.isEmpty {
                        EmptyStateView(
                            icon: "creditcard",
                            title: "지출이 없어요",
                            message: "휴지·세제·공과금 등 공동 지출을\n등록하면 자동으로 정산돼요.",
                            actionTitle: "+ 지출 추가",
                            action: { showAddSheet = true }
                        )
                        .frame(minHeight: 360)
                    } else {
                        ForEach(vm.filtered) { exp in
                            expenseRow(exp, vm: vm)
                                .padding(.horizontal, Spacing.l)
                        }
                    }
                } else {
                    ProgressView().padding(Spacing.xxl)
                }
            }
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Tokens.surface.ignoresSafeArea())
        .navigationTitle("공동 지출")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("정산 실행", systemImage: "checkmark.circle") {
                        Task {
                            if let vm = viewModel {
                                settlementPlan = await vm.performSettlement()
                                showSettlementSheet = !settlementPlan.isEmpty
                            }
                        }
                    }
                    Button("필터 초기화", systemImage: "line.3.horizontal.decrease.circle") {
                        viewModel?.filter = .all
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let vm = viewModel, !vm.filtered.isEmpty {
                RoomieButton("+ 지출 추가", icon: "plus") {
                    showAddSheet = true
                }
                .fixedSize()
                .padding(Spacing.l)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let vm = viewModel {
                ExpenseAddView(viewModel: vm)
            }
        }
        .sheet(isPresented: $showSettlementSheet) {
            if let vm = viewModel {
                SettlementSummarySheet(plan: settlementPlan, members: vm.members)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ExpenseViewModel(groupID: groupID, repositories: repositories)
            }
            await viewModel?.load()
        }
    }

    // MARK: - 월 합계 카드

    @ViewBuilder
    private func monthTotalCard(_ vm: ExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("이번 달 총 지출")
                .font(Typo.caption())
                .foregroundStyle(.white.opacity(0.8))
            Text(CurrencyFormatter.format(vm.totalThisMonth))
                .font(Typo.amount(28))
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                Text("\(vm.members.count)명이 함께 사용")
            }
            .font(Typo.caption())
            .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [Tokens.primary, Tokens.primaryDark],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .padding(.horizontal, Spacing.l)
    }

    // MARK: - 필터 칩

    @ViewBuilder
    private func filterChips(_ vm: ExpenseViewModel) -> some View {
        HStack(spacing: Spacing.s) {
            ForEach(ExpenseFilter.allCases) { f in
                Button { vm.filter = f } label: {
                    Text(f.label)
                        .font(Typo.caption())
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, 8)
                        .background(vm.filter == f ? Tokens.primary : Tokens.surfaceContainer)
                        .foregroundStyle(vm.filter == f ? .white : Tokens.textPrimary)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.l)
    }

    // MARK: - 지출 행

    @ViewBuilder
    private func expenseRow(_ exp: Expense, vm: ExpenseViewModel) -> some View {
        let payer = vm.members.first(where: { $0.id == exp.paidByMemberID })

        HStack(spacing: Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.s).fill(Tokens.surfaceHighlight)
                Image(systemName: exp.category.sfSymbolName)
                    .foregroundStyle(Tokens.primary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exp.title).font(Typo.bodyBold())
                    if exp.isSettled {
                        Text("정산완료")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Tokens.receiveCardBG)
                            .foregroundStyle(Tokens.receiveCardText)
                            .clipShape(Capsule())
                    }
                }
                Text("\(payer?.name ?? "?") 결제").font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.format(exp.amount))
                    .font(Typo.bodyBold())
                    .foregroundStyle(Tokens.primary)
                Text(relativeDate(exp.date))
                    .font(Typo.caption())
                    .foregroundStyle(Tokens.textTertiary)
            }
        }
        .padding(Spacing.m)
        .background(Tokens.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

#Preview("시안 ③ 지출") {
    let (repos, groupID) = InMemorySeed.preview()
    return NavigationStack {
        ExpenseListView(groupID: groupID)
            .environment(\.repositories, repos)
    }
}
