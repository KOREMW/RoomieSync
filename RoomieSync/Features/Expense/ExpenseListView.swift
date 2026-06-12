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
    @State private var showSettlementAction: Bool = false
    @State private var editingExpense: Expense? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if let vm = viewModel {
                    monthTotalCard(vm)
                    filterChips(vm)
                    if vm.filtered.isEmpty {
                        if vm.isNarrowed {
                            ContentUnavailableView(
                                "결과가 없어요",
                                systemImage: "magnifyingglass",
                                description: Text("검색어나 필터를 바꿔보세요.")
                            )
                            .frame(minHeight: 360)
                        } else {
                            EmptyStateView(
                                icon: "creditcard",
                                title: "지출이 없어요",
                                message: "휴지·세제·공과금 등 공동 지출을\n등록하면 자동으로 정산돼요.",
                                actionTitle: "+ 지출 추가",
                                action: { showAddSheet = true }
                            )
                            .frame(minHeight: 360)
                        }
                    } else {
                        LazyVStack(spacing: Spacing.l) {
                            ForEach(vm.filtered) { exp in
                                Button { editingExpense = exp } label: {
                                    expenseRow(exp, vm: vm)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, Spacing.l)
                            }
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
        .searchable(text: searchBinding, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "제목·메모·결제자 검색")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RecurringExpensesView(groupID: groupID)
                } label: {
                    Image(systemName: "repeat")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SettlementHistoryView(groupID: groupID)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let vm = viewModel, !vm.filtered.isEmpty {
                RoomieButton("지출 추가", icon: "plus") {
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
        .sheet(item: $editingExpense) { exp in
            if let vm = viewModel {
                ExpenseAddView(viewModel: vm, editing: exp)
            }
        }
        .sheet(isPresented: $showSettlementAction) {
            SettlementActionView(groupID: groupID)
        }
        .task {
            if viewModel == nil {
                viewModel = ExpenseViewModel(groupID: groupID, repositories: repositories)
            }
            await viewModel?.load()
            if DemoMode.presentAddExpense { showAddSheet = true }   // 스크린샷용
        }
    }

    // MARK: - 검색 / 정렬

    private var searchBinding: Binding<String> {
        Binding(get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 })
    }

    @ViewBuilder
    private func sortMenu(_ vm: ExpenseViewModel) -> some View {
        Menu {
            Picker("정렬", selection: Binding(get: { vm.sort }, set: { vm.sort = $0 })) {
                ForEach(ExpenseSort.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            HStack(spacing: 2) {
                Text(vm.sort.label).font(Typo.caption())
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Tokens.textSecondary)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 월 합계 카드

    @ViewBuilder
    private func monthTotalCard(_ vm: ExpenseViewModel) -> some View {
        HStack(alignment: .center, spacing: Spacing.m) {
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
            Spacer()
            // 큰 원형 정산 버튼
            Button {
                showSettlementAction = true
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(.white)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Tokens.primary)
                    }
                    .frame(width: 60, height: 60)
                    Text("정산")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
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
            sortMenu(vm)
            Button { vm.filter = .all } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(8)
                    .background(Tokens.surfaceContainer)
                    .foregroundStyle(Tokens.textSecondary)
                    .clipShape(Circle())
            }
            .disabled(vm.filter == .all)
            .opacity(vm.filter == .all ? 0.4 : 1)
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
