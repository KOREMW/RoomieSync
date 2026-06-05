//
//  GroupSwitcherSheet.swift
//  RoomieSync
//
//  홈 좌상단 모임 목록 — 내가 속한 모임을 전환하거나 새 모임을 추가/참여.
//  작성자: 엄민욱 (2091188)
//

import SwiftUI

struct GroupSwitcherSheet: View {
    let currentGroupID: UUID
    @Environment(\.repositories) private var repositories
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppKeys.Storage.currentGroupID) private var currentGroupIDString: String = ""

    @State private var groups: [Group] = []
    @State private var isLoading = true
    @State private var editingGroup: Group? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("내 모임") {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if groups.isEmpty {
                        Text("표시할 모임이 없어요").foregroundStyle(Tokens.textSecondary)
                    } else {
                        ForEach(groups) { group in
                            HStack(spacing: Spacing.m) {
                                // 전환 (행 본문 탭)
                                Button {
                                    currentGroupIDString = group.id.uuidString
                                    dismiss()
                                } label: {
                                    HStack(spacing: Spacing.m) {
                                        ZStack {
                                            Circle().fill(Color(hex: group.iconColorHex))
                                            Text(group.icon).font(.system(size: 18))
                                        }
                                        .frame(width: 36, height: 36)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(group.name).foregroundStyle(Tokens.textPrimary)
                                            Text("멤버 \(group.memberIDs.count)명")
                                                .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                                        }
                                        Spacer()
                                        if group.id == currentGroupID {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.primary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                // 수정 (모임 정보 편집)
                                Button {
                                    editingGroup = group
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Tokens.textSecondary)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("\(group.name) 모임 정보 수정")
                            }
                        }
                    }
                }

                Section {
                    Button {
                        // 그룹 선택 해제 → RootView 가 그룹 만들기/참여 화면을 띄움
                        currentGroupIDString = ""
                        dismiss()
                    } label: {
                        Label("새 모임 만들기 / 참여", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("모임")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
            .task { await reload() }
            .sheet(item: $editingGroup) { group in
                GroupEditView(groupID: group.id, onSaved: { Task { await reload() } })
            }
        }
    }

    @MainActor
    private func reload() async {
        do { groups = try await repositories.group.fetchAllGroups() }
        catch { groups = [] }
        isLoading = false
    }
}
