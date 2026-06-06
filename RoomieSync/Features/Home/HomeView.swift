//
//  HomeView.swift
//  RoomieSync
//
//  계획서 참조: Stitch 시안 ① (홈)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct HomeView: View {

    let groupID: UUID
    /// '오늘 할 일' 카드를 누르면 가사 탭으로 이동시키는 콜백.
    var onOpenChores: () -> Void = {}
    @Environment(\.repositories) private var repositories
    @State private var viewModel: HomeViewModel?
    @State private var showGroupSwitcher = false
    @State private var showBreakdown = false
    @State private var showSettlementAction = false
    @State private var showInbox = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                headerSection
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)
                GroupNotesCard(groupID: groupID)
                if let vm = viewModel {
                    todayChoresCard(vm)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpenChores() }
                    weeklySettlementCard(vm)
                    distributionCard(vm)
                } else {
                    ProgressView().padding(Spacing.xxl)
                }
            }
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Tokens.surface.ignoresSafeArea())
        .task {
            if viewModel == nil {
                viewModel = HomeViewModel(groupID: groupID, repositories: repositories)
            }
            await viewModel?.load()
        }
        .onAppear {
            // 다른 탭(가사 완료 등) 다녀온 뒤 돌아오면 즉시 최신화
            if viewModel != nil { Task { await viewModel?.load() } }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInbox = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell").foregroundStyle(Tokens.textPrimary)
                        if let vm = viewModel, vm.inboxUnreadCount > 0 {
                            Circle().fill(Tokens.danger)
                                .frame(width: 9, height: 9)
                                .offset(x: 4, y: -3)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showInbox, onDismiss: { Task { await viewModel?.load() } }) {
            NotificationInboxView(groupID: groupID)
        }
        .sheet(isPresented: $showGroupSwitcher) {
            GroupSwitcherSheet(currentGroupID: groupID)
        }
        .sheet(isPresented: $showBreakdown) {
            SettlementBreakdownView(groupID: groupID)
        }
        .sheet(isPresented: $showSettlementAction) {
            SettlementActionView(groupID: groupID)
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let vm = viewModel, !vm.groupName.isEmpty {
                Button {
                    showGroupSwitcher = true
                } label: {
                    HStack(spacing: Spacing.s) {
                        ZStack {
                            Circle().fill(Color(hex: vm.groupColorHex))
                            Text(vm.groupIcon).font(.system(size: 18))
                        }
                        .frame(width: 34, height: 34)
                        Text(vm.groupName)
                            .font(Typo.sectionTitle())
                            .foregroundStyle(Tokens.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.textSecondary)
                        Text("모임 변경")
                            .font(Typo.caption())
                            .foregroundStyle(Tokens.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("안녕하세요, \(viewModel?.greetingName ?? "")님 👋")
                    .font(Typo.title())
                    .foregroundStyle(Tokens.textPrimary)
                Text("오늘도 좋은 하루 보내세요")
                    .font(Typo.body())
                    .foregroundStyle(Tokens.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func todayChoresCard(_ vm: HomeViewModel) -> some View {
        SectionCard {
            HStack {
                Text("오늘 할 일").font(Typo.sectionTitle()).foregroundStyle(Tokens.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Tokens.textTertiary)
            }
            if vm.todayChores.isEmpty {
                Text("아직 등록된 가사가 없어요")
                    .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.m)
            } else {
                VStack(spacing: Spacing.s) {
                    ForEach(vm.todayChores.prefix(3)) { chore in
                        choreRow(chore, viewModel: vm)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func choreRow(_ chore: Chore, viewModel: HomeViewModel) -> some View {
        let isMine = chore.currentAssigneeID == viewModel.currentUserID
        let assignee = viewModel.membersByID[chore.currentAssigneeID]
        HStack(spacing: Spacing.m) {
            Text(chore.icon.isEmpty ? "✓" : chore.icon)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(Tokens.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            Text(chore.title).font(Typo.body()).foregroundStyle(Tokens.textPrimary)
            Spacer()
            if isMine {
                Text("내 차례")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, Spacing.s).padding(.vertical, 4)
                    .background(Tokens.payCardBG)
                    .foregroundStyle(Tokens.danger)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            } else if let assignee {
                HStack(spacing: 6) {
                    Text(assignee.name).font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                    MemberAvatarView(member: assignee, size: 24)
                }
            }
        }
        .padding(Spacing.m)
        .background(Tokens.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
    }

    @ViewBuilder
    private func weeklySettlementCard(_ vm: HomeViewModel) -> some View {
        SectionCard {
            HStack {
                Text("이번 주 정산").font(Typo.sectionTitle())
                Spacer()
                Button { showBreakdown = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(Tokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: Spacing.m) {
                BalanceCard(kind: .receive, amount: vm.receiveAmount)
                BalanceCard(kind: .pay, amount: vm.payAmount)
            }
            RoomieButton("정산하기") { showSettlementAction = true }.padding(.top, Spacing.s)
        }
        // '정산하기' 버튼을 제외한 컨테이너 전체를 탭하면 정산 내역으로 이동
        .contentShape(Rectangle())
        .onTapGesture { showBreakdown = true }
    }

    @ViewBuilder
    private func distributionCard(_ vm: HomeViewModel) -> some View {
        SectionCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("가사 분담 현황").font(Typo.sectionTitle())
                    Text("이번 주 전체 완료율 \(Int(vm.weekCompletionRate * 100))%")
                        .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                }
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 32)).foregroundStyle(Tokens.divider)
            }
            ProgressView(value: vm.weekCompletionRate)
                .progressViewStyle(.linear).tint(Tokens.success)
        }
    }

}

#Preview("시안 ① 홈") {
    let (repos, groupID) = InMemorySeed.preview()
    return NavigationStack {
        HomeView(groupID: groupID).environment(\.repositories, repos)
    }
}
