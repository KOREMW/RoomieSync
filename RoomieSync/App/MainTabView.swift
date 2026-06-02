//
//  MainTabView.swift
//  RoomieSync
//
//  계획서 참조: 시안 5장 하단 4탭 — 홈/가사/지출/통계
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct MainTabView: View {
    let groupID: UUID

    var body: some View {
        TabView {
            NavigationStack { HomeView(groupID: groupID) }
                .tabItem { Label("홈", systemImage: "house.fill") }

            NavigationStack { ChoreListView(groupID: groupID) }
                .tabItem { Label("가사", systemImage: "checkmark.square.fill") }

            NavigationStack { ExpenseListView(groupID: groupID) }
                .tabItem { Label("지출", systemImage: "creditcard.fill") }

            NavigationStack { StatsView(groupID: groupID) }
                .tabItem { Label("통계", systemImage: "chart.bar.fill") }
        }
        .tint(Tokens.primary)
    }
}

#Preview("4탭 전체") {
    let (repos, groupID) = InMemorySeed.preview()
    return MainTabView(groupID: groupID)
        .environment(\.repositories, repos)
}
