//
//  TodayChoreWidget.swift
//  RoomieSync
//
//  계획서 참조: 4.1 위젯 (Small + Medium) — 오늘 내 차례 + 룸메 전원 진행 상황
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-09
//

import WidgetKit
import SwiftUI
import AppIntents

struct TodayChoreWidget: Widget {
    let kind: String = "TodayChoreWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectGroupIntent.self,
            provider: TodayChoreTimelineProvider()
        ) { entry in
            TodayChoreWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("오늘 가사")
        .description("오늘 내 차례인 가사와 룸메이트 진행 상황을 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayChoreWidgetView: View {
    var entry: TodayChoreEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        default:            smallView
        }
    }

    // Small — 내 차례 가사 1개 + 완료 버튼
    @ViewBuilder
    private var smallView: some View {
        let myChore = entry.snapshot.todayChores.first(where: { $0.isMine && !$0.isCompleted })
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.snapshot.groupName)
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "house.fill")
                    .font(.caption2).foregroundStyle(.tint)
            }
            Spacer()
            if let chore = myChore {
                Text(chore.icon).font(.system(size: 32))
                Text(chore.title).font(.subheadline).bold()
                Text("내 차례")
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
                Button(intent: CompleteChoreIntent(choreID: chore.id)) {
                    Label("완료", systemImage: "checkmark.circle.fill")
                        .font(.caption).bold()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32)).foregroundStyle(.green)
                Text("오늘 할 일 끝!")
                    .font(.subheadline).bold()
            }
            Spacer()
        }
    }

    // Medium — 멤버 전원 체크리스트
    @ViewBuilder
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.snapshot.groupName).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("오늘 \(entry.snapshot.todayChores.count)건")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(entry.snapshot.todayChores.prefix(4)) { chore in
                HStack(spacing: 8) {
                    Text(chore.icon).font(.callout)
                    Text(chore.title).font(.callout)
                    Spacer()
                    Text(chore.assigneeName)
                        .font(.caption).foregroundStyle(.secondary)
                    Image(systemName: chore.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(chore.isCompleted ? .green : .secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Lock Screen / accessory*
struct TodayChoreLockScreenWidget: Widget {
    let kind = "TodayChoreLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleLockProvider()) { entry in
            LockScreenView(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("남은 가사")
        .description("잠금화면에서 남은 가사 수를 확인해요.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

struct LockEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot
}

struct SimpleLockProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockEntry {
        LockEntry(date: .now, snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (LockEntry) -> Void) {
        completion(LockEntry(date: .now, snapshot: SharedSnapshotStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockEntry>) -> Void) {
        let entry = LockEntry(date: .now, snapshot: SharedSnapshotStore.read())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LockScreenView: View {
    var entry: LockEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(entry.snapshot.undoneCountForMe)")
                        .font(.system(size: 22, weight: .bold))
                    Text("남음").font(.system(size: 8))
                }
            }
        case .accessoryInline:
            Text("남은 가사 \(entry.snapshot.undoneCountForMe)건")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("오늘 남은 가사").font(.caption2).foregroundStyle(.secondary)
                if let mine = entry.snapshot.todayChores.first(where: { $0.isMine && !$0.isCompleted }) {
                    HStack(spacing: 4) {
                        Text(mine.icon)
                        Text(mine.title).font(.headline)
                    }
                } else {
                    Text("끝!").font(.headline)
                }
            }
        default:
            EmptyView()
        }
    }
}

// WidgetReloader 는 Core/Shared/WidgetReloader.swift 로 이동
// (메인 앱에서 위젯 갱신을 요청하므로 양쪽 타깃에서 공유)

#Preview(as: .systemSmall) {
    TodayChoreWidget()
} timeline: {
    TodayChoreEntry(date: .now, snapshot: .placeholder, configuration: SelectGroupIntent())
}
