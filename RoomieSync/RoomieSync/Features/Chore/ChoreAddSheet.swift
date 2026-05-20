//
//  ChoreAddSheet.swift
//  RoomieSync
//
//  계획서 참조: 6.1 #3 가사 세팅 — 템플릿 또는 직접 추가
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct ChoreAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ChoreViewModel

    @State private var title: String = ""
    @State private var selectedIcon: String = "🗑"
    @State private var cycle: ChoreCycle = .daily
    @State private var isWorking: Bool = false

    /// 시안 ②의 이모지 그룹 + 흔한 가사 이모지.
    private let icons = ["🗑", "🍽", "🧹", "🚿", "🧺", "🛒", "🪟", "🪴"]

    var body: some View {
        NavigationStack {
            Form {
                Section("가사 이름") {
                    TextField("예) 쓰레기 배출, 거실 청소", text: $title)
                }
                Section("아이콘") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.m) {
                        ForEach(icons, id: \.self) { icon in
                            Text(icon)
                                .font(.system(size: 28))
                                .frame(width: 48, height: 48)
                                .background(selectedIcon == icon ? Tokens.primaryLight : Tokens.surfaceMuted)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                }
                Section("주기") {
                    Picker("주기", selection: $cycle) {
                        ForEach(ChoreCycle.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text("멤버 \(viewModel.members.count)명이 순서대로 자동 배정됩니다.")
                        .font(Typo.caption())
                        .foregroundStyle(Tokens.textSecondary)
                }
            }
            .navigationTitle("새 가사")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        Task {
                            isWorking = true
                            let ok = await viewModel.addChore(
                                title: title.trimmingCharacters(in: .whitespaces),
                                icon: selectedIcon,
                                cycle: cycle
                            )
                            isWorking = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                }
            }
        }
    }
}

#Preview {
    ChoreAddSheet(
        viewModel: ChoreViewModel(groupID: UUID(), repositories: .preview())
    )
}
