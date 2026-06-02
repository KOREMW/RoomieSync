//
//  ChoreAddSheet.swift
//  RoomieSync
//
//  계획서 참조: 6.1 #3 가사 세팅 — 추가/수정 + 주기(매일·요일 지정).
//  작성자: 엄민욱 (2091188)
//

import SwiftUI

struct ChoreAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ChoreViewModel
    /// nil 이면 신규 추가, 값이 있으면 해당 가사 수정 모드.
    var editing: Chore? = nil

    @State private var title: String = ""
    @State private var selectedIcon: String = "🗑"
    @State private var cycle: ChoreCycle = .daily
    @State private var weekdays: Set<Int> = []          // 1=일 … 7=토
    @State private var isWorking: Bool = false
    @State private var didPrefill: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private let icons = ["🗑", "🍽", "🧹", "🚿", "🧺", "🛒", "🪟", "🪴"]
    private let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]

    private var isEditing: Bool { editing != nil }

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

                    if cycle == .weekly {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("반복 요일")
                                .font(Typo.caption())
                                .foregroundStyle(Tokens.textSecondary)
                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { day in
                                    let on = weekdays.contains(day)
                                    Button {
                                        if on { weekdays.remove(day) } else { weekdays.insert(day) }
                                    } label: {
                                        Text(weekdayLabels[day - 1])
                                            .font(.system(size: 14, weight: .semibold))
                                            .frame(width: 36, height: 36)
                                            .background(on ? Tokens.primary : Tokens.surfaceMuted)
                                            .foregroundStyle(on ? .white : Tokens.textSecondary)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if !weekdays.isEmpty {
                                Text("주 \(weekdays.count)회 — \(selectedWeekdaysSummary)")
                                    .font(Typo.caption())
                                    .foregroundStyle(Tokens.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section {
                    Text("멤버 \(viewModel.members.count)명이 순서대로 자동 배정됩니다.")
                        .font(Typo.caption())
                        .foregroundStyle(Tokens.textSecondary)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack { Spacer(); Label("이 가사 삭제", systemImage: "trash"); Spacer() }
                        }
                        .disabled(isWorking)
                    }
                }
            }
            .navigationTitle(isEditing ? "가사 수정" : "새 가사")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "수정" : "추가") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                }
            }
            .confirmationDialog("이 가사를 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { Task { await deleteChore() } }
                Button("취소", role: .cancel) {}
            }
            .task {
                guard !didPrefill else { return }
                didPrefill = true
                if let c = editing {
                    title = c.title
                    selectedIcon = c.icon
                    cycle = c.cycleType
                    weekdays = Set(c.weekdays)
                }
            }
        }
    }

    private var selectedWeekdaysSummary: String {
        weekdays.sorted().map { weekdayLabels[$0 - 1] }.joined(separator: "·")
    }

    @MainActor
    private func save() async {
        isWorking = true
        defer { isWorking = false }
        let days = cycle == .weekly ? Array(weekdays).sorted() : []
        let ok: Bool
        if var updated = editing {
            updated.title = title.trimmingCharacters(in: .whitespaces)
            updated.icon = selectedIcon
            updated.cycleType = cycle
            updated.weekdays = days
            ok = await viewModel.updateChore(updated)
        } else {
            ok = await viewModel.addChore(
                title: title.trimmingCharacters(in: .whitespaces),
                icon: selectedIcon,
                cycle: cycle,
                weekdays: days
            )
        }
        if ok { dismiss() }
    }

    @MainActor
    private func deleteChore() async {
        guard let id = editing?.id else { return }
        isWorking = true
        defer { isWorking = false }
        if await viewModel.deleteChore(id) { dismiss() }
    }
}

#Preview {
    ChoreAddSheet(
        viewModel: ChoreViewModel(groupID: UUID(), repositories: .preview())
    )
}
