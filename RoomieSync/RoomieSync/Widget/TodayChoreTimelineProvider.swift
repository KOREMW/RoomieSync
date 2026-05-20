//
//  TodayChoreTimelineProvider.swift
//  RoomieSync
//
//  계획서 참조: 4.1 위젯 — TimelineProvider 구현
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-09
//

import WidgetKit
import Foundation

struct TodayChoreEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot
    let configuration: SelectGroupIntent
}

struct TodayChoreTimelineProvider: AppIntentTimelineProvider {

    typealias Intent = SelectGroupIntent
    typealias Entry = TodayChoreEntry

    func placeholder(in context: Context) -> TodayChoreEntry {
        TodayChoreEntry(date: .now, snapshot: .placeholder, configuration: SelectGroupIntent())
    }

    func snapshot(for configuration: SelectGroupIntent, in context: Context) async -> TodayChoreEntry {
        let snap = context.isPreview ? .placeholder : SharedSnapshotStore.read()
        return TodayChoreEntry(date: .now, snapshot: snap, configuration: configuration)
    }

    func timeline(for configuration: SelectGroupIntent, in context: Context) async -> Timeline<TodayChoreEntry> {
        let snap = SharedSnapshotStore.read()
        let entry = TodayChoreEntry(date: .now, snapshot: snap, configuration: configuration)
        // 1시간마다 갱신 (cycle daily 가사 기준), 자정에 강제 reload 는 main app 에서 WidgetCenter.reloadAll.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

extension SharedSnapshot {
    /// 위젯 미리보기 / Preview 용 더미.
    static let placeholder: SharedSnapshot = {
        SharedSnapshot(
            groupID: UUID(),
            groupName: "우리집",
            todayChores: [
                .init(id: UUID(), title: "쓰레기 배출", icon: "🗑",
                      assigneeName: "김지훈", assigneeColorHex: "#4F46E5",
                      isMine: true, isCompleted: false),
                .init(id: UUID(), title: "설거지", icon: "🍽",
                      assigneeName: "박서연", assigneeColorHex: "#10B981",
                      isMine: false, isCompleted: false),
                .init(id: UUID(), title: "거실 청소", icon: "🧹",
                      assigneeName: "이민호", assigneeColorHex: "#F59E0B",
                      isMine: false, isCompleted: true)
            ],
            undoneCountForMe: 1
        )
    }()
}
