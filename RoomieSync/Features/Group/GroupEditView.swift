//
//  GroupEditView.swift
//  RoomieSync
//
//  모임 정보(이름·아이콘·아이콘 색) 수정 시트. 모임 목록(스위처)에서 각 모임의
//  수정 버튼으로 진입한다.
//

import SwiftUI

struct GroupEditView: View {
    let groupID: UUID
    var onSaved: () -> Void = {}

    @Environment(\.repositories) private var repositories
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var icon: String = Group.defaultIcon
    @State private var colorIndex: Int = 0
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private static let icons: [String] = [
        "🏠", "🏡", "🏢", "🛏️", "🍳", "🛋️", "🚪", "🧹", "🐾", "🌿", "🎓", "⭐"
    ]

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else {
                    Section("모임 이름") {
                        HStack(spacing: Spacing.m) {
                            ZStack {
                                Circle().fill(Color(hex: AvatarPalette.hex(at: colorIndex)))
                                Text(icon).font(.system(size: 22))
                            }
                            .frame(width: 44, height: 44)
                            TextField("모임 이름", text: $name)
                        }
                    }
                    Section("모임 아이콘") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.s) {
                                ForEach(Self.icons, id: \.self) { emoji in
                                    Text(emoji)
                                        .font(.system(size: 22))
                                        .frame(width: 40, height: 40)
                                        .background(icon == emoji ? Tokens.surfaceHighlight : Tokens.surfaceMuted)
                                        .clipShape(Circle())
                                        .overlay { if icon == emoji { Circle().stroke(Tokens.primary, lineWidth: 2) } }
                                        .onTapGesture { icon = emoji }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    Section("모임 아이콘 색") {
                        AvatarColorPicker(selectedIndex: $colorIndex)
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(Tokens.danger) }
                    }
                }
            }
            .navigationTitle("모임 정보 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() }
                    else {
                        Button("저장") { Task { await save() } }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .task { await load() }
        }
    }

    @MainActor
    private func load() async {
        do {
            let group = try await repositories.group.fetchGroup(id: groupID)
            name = group.name
            icon = group.icon
            colorIndex = AvatarPalette.hexValues.firstIndex(of: group.iconColorHex) ?? 0
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
        isLoading = false
    }

    @MainActor
    private func save() async {
        let trimmed = InputValidator.groupName(name)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await repositories.group.updateGroupInfo(
                groupID, name: trimmed, icon: icon,
                iconColorHex: AvatarPalette.hex(at: colorIndex)
            )
            HapticManager.shared.success()
            onSaved()
            dismiss()
        } catch {
            HapticManager.shared.error()
            errorMessage = "모임 정보 저장에 실패했어요.\n(\(CKErrorMapper.userMessage(for: error)))"
        }
    }
}
