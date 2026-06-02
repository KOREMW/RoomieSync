//
//  ChoreListView.swift
//  RoomieSync
//
//  계획서 참조: Stitch 시안 ②, 2 P0 ② 가사 자동 로테이션
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct ChoreListView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories
    @State private var viewModel: ChoreViewModel?
    @State private var showAddSheet: Bool = false
    @State private var pendingToast: UndoToastConfig? = nil
    @State private var editingChore: Chore? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                if let vm = viewModel {
                    // 상단 필터 칩
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.s) {
                            ForEach(ChoreFilter.allCases) { f in
                                filterChip(f, selected: vm.filter == f) { vm.filter = f }
                            }
                        }
                        .padding(.horizontal, Spacing.l)
                    }

                    if vm.filteredChores.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.square",
                            title: "아직 가사가 없어요",
                            message: "쓰레기·설거지·청소 같은 가사를 추가하면\n자동으로 멤버 순서대로 배정돼요.",
                            actionTitle: "+ 가사 추가",
                            action: { showAddSheet = true }
                        )
                        .frame(minHeight: 400)
                    } else {
                        ForEach(vm.filteredChores) { chore in
                            choreCard(chore, vm: vm)
                                .padding(.horizontal, Spacing.l)
                                .contentShape(Rectangle())
                                .onTapGesture { editingChore = chore }
                        }
                    }
                } else {
                    ProgressView().padding(Spacing.xxl)
                }
            }
            .padding(.vertical, Spacing.m)
        }
        .background(Tokens.surface.ignoresSafeArea())
        .navigationTitle("가사 당번")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            if let vm = viewModel {
                ChoreAddSheet(viewModel: vm)
            }
        }
        .sheet(item: $editingChore) { chore in
            if let vm = viewModel {
                ChoreAddSheet(viewModel: vm, editing: chore)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ChoreViewModel(groupID: groupID, repositories: repositories)
            }
            await viewModel?.load()
        }
        .undoToast(item: $pendingToast)
        .alert("오류", isPresented: errorBinding) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
        .overlay(alignment: .bottomTrailing) {
            if let vm = viewModel, !vm.filteredChores.isEmpty {
                RoomieButton("새 가사", icon: "plus") {
                    showAddSheet = true
                }
                .fixedSize()
                .padding(Spacing.l)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.clearError() } }
        )
    }

    // MARK: - 필터 칩

    @ViewBuilder
    private func filterChip(_ filter: ChoreFilter, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(filter.label)
                .font(Typo.caption())
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, 8)
                .background(selected ? Tokens.primary : Tokens.surfaceContainer)
                .foregroundStyle(selected ? .white : Tokens.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Tokens.divider.opacity(selected ? 0 : 0.5), lineWidth: 1)
                )
        }
    }

    // MARK: - 가사 카드

    @ViewBuilder
    private func choreCard(_ chore: Chore, vm: ChoreViewModel) -> some View {
        let isMine = chore.currentAssigneeID == vm.currentUserID
        let assignee = vm.members.first(where: { $0.id == chore.currentAssigneeID })

        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Text(chore.icon).font(.system(size: 22))
                Text(chore.title).font(Typo.bodyBold())
                Text(chore.cycleType.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, Spacing.s).padding(.vertical, 2)
                    .background(Tokens.primaryLight)
                    .foregroundStyle(Tokens.primary)
                    .clipShape(Capsule())
                Spacer()
                if isMine {
                    Button {
                        Task { await handleComplete(chore, vm: vm) }
                    } label: {
                        Text("완료")
                            .font(Typo.bodyBold())
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, 6)
                            .background(Tokens.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                    }
                }
            }
            HStack(spacing: Spacing.s) {
                if let assignee {
                    MemberAvatarView(member: assignee, size: 28, highlighted: isMine)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("오늘:").font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                        Text(assignee?.name ?? "—")
                            .font(Typo.caption())
                            .foregroundStyle(isMine ? Tokens.primary : Tokens.textPrimary)
                        if isMine {
                            Text("(나)").font(Typo.caption()).foregroundStyle(Tokens.primary)
                        }
                    }
                    if let nextID = nextAssigneeID(chore: chore, vm: vm),
                       let next = vm.members.first(where: { $0.id == nextID }) {
                        HStack(spacing: 4) {
                            Text("다음:").font(Typo.caption()).foregroundStyle(Tokens.textTertiary)
                            Text(next.name).font(Typo.caption()).foregroundStyle(Tokens.textTertiary)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(Spacing.l)
        .background(Tokens.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
        .overlay(alignment: .leading) {
            if isMine {
                Rectangle()
                    .fill(Tokens.primary)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .contextMenu {
            Button("오늘 못해요 (다음 멤버에게)", systemImage: "arrow.right.arrow.left") {
                Task { await vm.swap(chore: chore) }
            }
        }
    }

    private func nextAssigneeID(chore: Chore, vm: ChoreViewModel) -> UUID? {
        guard chore.rotationMemberIDs.count > 1,
              let idx = chore.rotationMemberIDs.firstIndex(of: chore.currentAssigneeID) else { return nil }
        let next = (idx + 1) % chore.rotationMemberIDs.count
        return chore.rotationMemberIDs[next]
    }

    @MainActor
    private func handleComplete(_ chore: Chore, vm: ChoreViewModel) async {
        guard let completionID = await vm.tentativeComplete(chore: chore) else { return }
        pendingToast = UndoToastConfig(
            message: "\(chore.icon) \(chore.title) 완료",
            duration: 5.0,
            onCancel: { Task { await vm.cancelComplete(completionID: completionID) } },
            onConfirm: { Task { await vm.confirmComplete(completionID: completionID) } }
        )
    }
}

#Preview("시안 ② 가사") {
    let (repos, groupID) = InMemorySeed.preview()
    return NavigationStack {
        ChoreListView(groupID: groupID)
            .environment(\.repositories, repos)
    }
}
