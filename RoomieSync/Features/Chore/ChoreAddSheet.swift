//
//  ChoreAddSheet.swift
//  RoomieSync
//
//  가사 추가/수정 — 주기(매일·매주·매 월·선택) + 가사별 알림(시각 지정).
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
    @State private var pickedDate: Date = .now          // 매 월 / 선택용 캘린더 날짜
    @State private var difficulty: ChoreDifficulty = .normal
    @State private var notifyMorning: Bool = true
    @State private var notifyEvening: Bool = true
    @State private var morningTime: Date = Self.time(9, 0)
    @State private var eveningTime: Date = Self.time(21, 0)
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

                    switch cycle {
                    case .weekly:    weekdayPicker
                    case .monthly:   calendarPicker(caption: "매월 이 날짜에 반복돼요")
                    case .once:      calendarPicker(caption: "이 날짜에 1회만 진행돼요")
                    case .daily:     EmptyView()
                    }
                }
                Section("난이도") {
                    Picker("난이도", selection: $difficulty) {
                        ForEach(ChoreDifficulty.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("난이도가 높을수록 통계의 공정지수에 더 큰 부담으로 반영돼요.")
                        .font(Typo.caption())
                        .foregroundStyle(Tokens.textSecondary)
                }
                Section("이 가사 알림") {
                    Toggle("오전 당번 알림", isOn: $notifyMorning)
                    if notifyMorning {
                        DatePicker("오전 알림 시각", selection: $morningTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("저녁 미완료 알림", isOn: $notifyEvening)
                    if notifyEvening {
                        DatePicker("저녁 알림 시각", selection: $eveningTime, displayedComponents: .hourAndMinute)
                    }
                }
                Section {
                    Text("멤버 \(viewModel.members.count)명이 순서대로 자동 배정됩니다.")
                        .font(Typo.caption())
                        .foregroundStyle(Tokens.textSecondary)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            HStack { Spacer(); Label("이 가사 삭제", systemImage: "trash"); Spacer() }
                        }
                        .disabled(isWorking)
                    }
                }
            }
            .navigationTitle(isEditing ? "가사 수정" : "가사 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "수정" : "추가") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                }
            }
            .confirmationDialog("이 가사를 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { Task { await deleteChore() } }
                Button("취소", role: .cancel) {}
            }
            .task { prefillIfNeeded() }
        }
    }

    // MARK: - 요일 선택 (컨테이너 꽉 차게 균등 배치)

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("반복 요일").font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    let on = weekdays.contains(day)
                    Text(weekdayLabels[day - 1])
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(on ? Tokens.primary : Tokens.surfaceMuted)
                        .foregroundStyle(on ? .white : Tokens.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                        .contentShape(Rectangle())
                        .onTapGesture { if on { weekdays.remove(day) } else { weekdays.insert(day) } }
                }
            }
            if !weekdays.isEmpty {
                Text("주 \(weekdays.count)회 — \(weekdays.sorted().map { weekdayLabels[$0 - 1] }.joined(separator: "·"))")
                    .font(Typo.caption()).foregroundStyle(Tokens.primary)
            }
        }
        .padding(.vertical, 4)
    }

    private func calendarPicker(caption: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            DatePicker("날짜", selection: $pickedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "ko_KR"))
            Text(caption).font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
        }
    }

    // MARK: - 로직

    private func prefillIfNeeded() {
        guard !didPrefill else { return }
        didPrefill = true
        guard let c = editing else { return }
        title = c.title
        selectedIcon = c.icon
        cycle = c.cycleType
        weekdays = Set(c.weekdays)
        difficulty = c.difficulty
        if let a = c.anchorDate { pickedDate = a }
        let ns = NotificationService.shared
        notifyMorning = ns.userPrefersChore(.morningDuty, choreID: c.id)
        notifyEvening = ns.userPrefersChore(.eveningReminder, choreID: c.id)
        morningTime = Self.dateFromMinutes(ns.choreTimeMinutes(.morningDuty, choreID: c.id))
        eveningTime = Self.dateFromMinutes(ns.choreTimeMinutes(.eveningReminder, choreID: c.id))
    }

    @MainActor
    private func save() async {
        isWorking = true
        defer { isWorking = false }
        let days = cycle == .weekly ? Array(weekdays).sorted() : []
        let anchor: Date? = (cycle == .monthly || cycle == .once) ? pickedDate : nil
        let mMin = Self.minutes(from: morningTime)
        let eMin = Self.minutes(from: eveningTime)
        let ok: Bool
        if var updated = editing {
            updated.title = InputValidator.choreTitle(title)
            updated.icon = selectedIcon
            updated.cycleType = cycle
            updated.weekdays = days
            updated.anchorDate = anchor
            updated.difficulty = difficulty
            ok = await viewModel.updateChore(updated, notifyMorning: notifyMorning, notifyEvening: notifyEvening,
                                             morningMinutes: mMin, eveningMinutes: eMin)
        } else {
            ok = await viewModel.addChore(
                title: InputValidator.choreTitle(title),
                icon: selectedIcon, cycle: cycle, weekdays: days, anchorDate: anchor,
                difficulty: difficulty,
                notifyMorning: notifyMorning, notifyEvening: notifyEvening,
                morningMinutes: mMin, eveningMinutes: eMin
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

    // MARK: - 시간 헬퍼
    private static func time(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now
    }
    private static func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    private static func dateFromMinutes(_ minutes: Int) -> Date {
        time(minutes / 60, minutes % 60)
    }
}

#Preview {
    ChoreAddSheet(viewModel: ChoreViewModel(groupID: UUID(), repositories: .preview()))
}
