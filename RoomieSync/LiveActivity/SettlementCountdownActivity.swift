//
//  SettlementCountdownActivity.swift
//  RoomieSync
//
//  계획서 참조: 4.3 정산 카운트다운 Live Activity
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-09
//

import ActivityKit
import WidgetKit
import SwiftUI

// SettlementCountdownAttributes 정의는 Core/Shared/LiveActivityAttributes.swift 로 이동
// (메인 앱 + 위젯 확장 양쪽에서 공유)

struct SettlementCountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SettlementCountdownAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 36))
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("이번 달 정산까지").font(.caption).foregroundStyle(.secondary)
                    Text("D-\(context.state.daysRemaining)").font(.title2).bold()
                }
                Spacer()
                if context.state.receiveAmountKRW > 0 {
                    VStack(alignment: .trailing) {
                        Text("받을 돈").font(.caption).foregroundStyle(.secondary)
                        Text("\(context.state.receiveAmountKRW)원").font(.headline).foregroundStyle(.green)
                    }
                }
            }
            .padding()
            .activityBackgroundTint(.indigo.opacity(0.12))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "calendar.badge.clock").font(.title2).foregroundStyle(.indigo)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text("정산까지").font(.caption)
                        Text("D-\(context.state.daysRemaining)").font(.title2).bold()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.receiveAmountKRW)원")
                        .font(.headline).foregroundStyle(.green)
                }
            } compactLeading: {
                Image(systemName: "calendar")
            } compactTrailing: {
                Text("D-\(context.state.daysRemaining)").font(.caption2).bold()
            } minimal: {
                Text("D-\(context.state.daysRemaining)").font(.caption2)
            }
            .keylineTint(.indigo)
        }
    }
}
