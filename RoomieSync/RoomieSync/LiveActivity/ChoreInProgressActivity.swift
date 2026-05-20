//
//  ChoreInProgressActivity.swift
//  RoomieSync
//
//  계획서 참조: 4.3 가사 진행 중 Live Activity
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-09
//
//  Dynamic Island compact/expanded/minimal + 잠금화면 widget 레이아웃 구현.
//

import ActivityKit
import WidgetKit
import SwiftUI

public struct ChoreInProgressAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var elapsedSeconds: Int
        public var memberInitials: String
        public init(elapsedSeconds: Int = 0, memberInitials: String) {
            self.elapsedSeconds = elapsedSeconds
            self.memberInitials = memberInitials
        }
    }

    public var choreTitle: String
    public var choreIcon: String
    public var memberName: String
    public var startedAt: Date

    public init(choreTitle: String, choreIcon: String,
                memberName: String, startedAt: Date = .now) {
        self.choreTitle = choreTitle
        self.choreIcon = choreIcon
        self.memberName = memberName
        self.startedAt = startedAt
    }
}

struct ChoreInProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChoreInProgressAttributes.self) { context in
            // 잠금화면 / 알림 센터 레이아웃
            LockScreenChoreView(context: context)
                .activityBackgroundTint(.indigo.opacity(0.15))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                // expanded
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.choreIcon).font(.system(size: 36))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(elapsedString(from: context.attributes.startedAt))
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(.indigo)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.choreTitle).font(.headline)
                        Text("\(context.attributes.memberName) 진행 중").font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("완료하면 자동으로 다음 차례로 넘어가요")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text(context.attributes.choreIcon)
            } compactTrailing: {
                Text(context.state.memberInitials)
                    .font(.caption2).bold()
                    .foregroundStyle(.indigo)
            } minimal: {
                Text(context.attributes.choreIcon)
            }
            .widgetURL(URL(string: "roomiesync://chore"))
            .keylineTint(.indigo)
        }
    }
}

private struct LockScreenChoreView: View {
    let context: ActivityViewContext<ChoreInProgressAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Text(context.attributes.choreIcon).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.choreTitle).font(.headline)
                Text("\(context.attributes.memberName) 진행 중").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(elapsedString(from: context.attributes.startedAt))
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.indigo)
        }
        .padding()
    }
}

private func elapsedString(from start: Date) -> String {
    let s = Int(Date.now.timeIntervalSince(start))
    let m = s / 60
    let r = s % 60
    return String(format: "%02d:%02d", m, r)
}
