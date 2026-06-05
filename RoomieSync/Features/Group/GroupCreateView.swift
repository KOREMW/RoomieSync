//
//  GroupCreateView.swift
//  RoomieSync
//
//  계획서 참조: 6.1 #1 호스트 — 이름·아바타 색 → 그룹 생성 → 초대코드 발급 → 클립보드 복사
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct GroupCreateView: View {
    let onCreated: (UUID) -> Void

    @Environment(\.repositories) private var repositories
    @State private var groupName: String = "우리집"
    @State private var groupIcon: String = Group.defaultIcon
    @State private var groupColorIndex: Int = 0
    @State private var hostName: String = ""
    @State private var selectedColorIndex: Int = 0
    @State private var generatedCode: String? = nil
    @State private var generatedGroupID: UUID? = nil
    @State private var isWorking: Bool = false
    @State private var errorMessage: String? = nil

    /// 모임 아이콘 후보(이모지).
    private static let groupIcons: [String] = [
        "🏠", "🏡", "🏢", "🛏️", "🍳", "🛋️", "🚪", "🧹", "🐾", "🌿", "🎓", "⭐"
    ]

    var body: some View {
        Form {
            Section("그룹 이름") {
                HStack(spacing: Spacing.m) {
                    ZStack {
                        Circle().fill(Color(hex: AvatarPalette.hex(at: groupColorIndex)))
                        Text(groupIcon).font(.system(size: 22))
                    }
                    .frame(width: 44, height: 44)
                    TextField("예) 우리집", text: $groupName)
                        .textInputAutocapitalization(.never)
                }
            }
            Section("모임 아이콘") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s) {
                        ForEach(Self.groupIcons, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 22))
                                .frame(width: 40, height: 40)
                                .background(groupIcon == emoji ? Tokens.surfaceHighlight : Tokens.surfaceMuted)
                                .clipShape(Circle())
                                .overlay { if groupIcon == emoji { Circle().stroke(Tokens.primary, lineWidth: 2) } }
                                .onTapGesture { groupIcon = emoji }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Section("모임 아이콘 색") {
                AvatarColorPicker(selectedIndex: $groupColorIndex)
            }
            Section("내 이름") {
                TextField("이름을 입력하세요", text: $hostName)
            }
            Section("내 아바타 색") {
                AvatarColorPicker(selectedIndex: $selectedColorIndex)
            }

            if let code = generatedCode {
                Section("초대 코드") {
                    HStack {
                        Text(code)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(Tokens.primary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = code
                        } label: {
                            Label("복사", systemImage: "doc.on.doc")
                        }
                    }
                    Text("이 코드를 룸메이트에게 공유하세요. 자동 클립보드 복사됨.")
                        .font(Typo.caption())
                        .foregroundStyle(Tokens.textSecondary)
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Tokens.danger) }
            }

            Section {
                if generatedCode == nil {
                    Button {
                        Task { await createGroup() }
                    } label: {
                        if isWorking { ProgressView() } else { Text("그룹 만들기") }
                    }
                    .disabled(hostName.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                } else {
                    Button("우리집 입장") {
                        if let id = generatedGroupID { onCreated(id) }
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .navigationTitle("그룹 만들기")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func createGroup() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let color = AvatarPalette.hex(at: selectedColorIndex)
            let group = try await repositories.group.createGroup(
                name: InputValidator.groupName(groupName),
                icon: groupIcon,
                iconColorHex: AvatarPalette.hex(at: groupColorIndex),
                hostName: InputValidator.name(hostName),
                hostAvatarColorHex: color
            )
            generatedCode = group.inviteCode
            generatedGroupID = group.id
            UIPasteboard.general.string = group.inviteCode
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }
}

struct GroupJoinView: View {
    let onJoined: (UUID) -> Void

    @Environment(\.repositories) private var repositories
    @State private var code: String = ""
    @State private var myName: String = ""
    @State private var selectedColorIndex: Int = 1
    @State private var isWorking: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Form {
            Section("초대 코드") {
                TextField("6자리 코드 (예: A3K9P2)", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.title3, design: .monospaced))
                    .onChange(of: code) { _, newValue in
                        code = InputValidator.inviteCode(newValue)
                    }
            }
            Section("내 이름") {
                TextField("이름을 입력하세요", text: $myName)
            }
            Section("내 아바타 색") {
                AvatarColorPicker(selectedIndex: $selectedColorIndex)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Tokens.danger) }
            }

            Section {
                Button {
                    Task { await joinGroup() }
                } label: {
                    if isWorking { ProgressView() } else { Text("참여하기") }
                }
                .disabled(code.count != 6 ||
                          myName.trimmingCharacters(in: .whitespaces).isEmpty ||
                          isWorking)
            }
        }
        .navigationTitle("그룹 참여")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func joinGroup() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let group = try await repositories.group.findGroup(byInviteCode: InputValidator.inviteCode(code))
            let color = AvatarPalette.hex(at: selectedColorIndex)
            _ = try await repositories.group.addMember(
                toGroup: group.id,
                name: InputValidator.name(myName),
                avatarColorHex: color
            )
            onJoined(group.id)
        } catch RepositoryError.notFound {
            errorMessage = "초대 코드를 찾을 수 없어요. 다시 확인해주세요."
        } catch RepositoryError.invalidInput(let reason) {
            errorMessage = reason
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }
}

#Preview("Create") {
    NavigationStack { GroupCreateView(onCreated: { _ in }) }
        .environment(\.repositories, .preview())
}

#Preview("Join") {
    NavigationStack { GroupJoinView(onJoined: { _ in }) }
        .environment(\.repositories, .preview())
}
