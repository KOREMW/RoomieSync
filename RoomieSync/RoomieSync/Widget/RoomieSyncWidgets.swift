//
//  RoomieSyncWidgets.swift
//  RoomieSync
//
//  계획서 참조: 4.1 위젯 + 4.3 Live Activity (단일 Extension)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-09
//

import WidgetKit
import SwiftUI

@main
struct RoomieSyncWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayChoreWidget()
        TodayChoreLockScreenWidget()
        ChoreInProgressLiveActivity()
        SettlementCountdownLiveActivity()
    }
}
