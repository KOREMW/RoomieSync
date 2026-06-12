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
    @Environment(\.repositories) private var repositories
    @State private var tab: Int

    init(groupID: UUID) {
        self.groupID = groupID
        _tab = State(initialValue: DemoMode.isEnabled ? DemoMode.initialTab : 0)
    }
    @State private var myAvatarIcon: String = ""
    @State private var router = AppRouter.shared
    @State private var showSettlement = false
    @State private var showNotes = false
    @State private var showInbox = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView(groupID: groupID, onOpenChores: { tab = 1 }) }
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(0)

            NavigationStack { ChoreListView(groupID: groupID) }
                .tabItem { Label("가사", systemImage: "checkmark.square.fill") }
                .tag(1)

            NavigationStack { ExpenseListView(groupID: groupID) }
                .tabItem { Label("지출", systemImage: "creditcard.fill") }
                .tag(2)

            NavigationStack { StatsView(groupID: groupID) }
                .tabItem { Label("통계", systemImage: "chart.bar.fill") }
                .tag(3)

            NavigationStack { MyPageView(groupID: groupID) }
                .tabItem { myPageTabItem }
                .tag(4)
        }
        .tint(Tokens.primary)
        .task { await loadAvatarIcon() }
        // 탭 전환 시마다 갱신 → 마이페이지에서 아바타를 바꾸면 탭 아이콘도 반영.
        .onChange(of: tab) { _, _ in Task { await loadAvatarIcon() } }
        // 알림 탭 → 라우트 처리 (콜드런치/백그라운드 둘 다)
        .onChange(of: router.pending) { _, r in if let r { handleRoute(r) } }
        .task { if let r = router.pending { handleRoute(r) } }
        .sheet(isPresented: $showSettlement) { SettlementActionView(groupID: groupID) }
        .sheet(isPresented: $showNotes) { NavigationStack { NotesBoardView(groupID: groupID) } }
        .sheet(isPresented: $showInbox) { NotificationInboxView(groupID: groupID) }
    }

    private func handleRoute(_ route: AppRouter.Route) {
        switch route {
        case .chores:     tab = 1
        case .expenses:   tab = 2
        case .settlement: showSettlement = true
        case .notes:      showNotes = true
        case .inbox:      showInbox = true
        }
        AppRouter.shared.pending = nil
    }

    @ViewBuilder
    private var myPageTabItem: some View {
        if let image = Self.emojiTabImage(myAvatarIcon) {
            Label { Text("마이페이지") } icon: { Image(uiImage: image) }
        } else {
            Label("마이페이지", systemImage: "person.crop.circle.fill")
        }
    }

    private func loadAvatarIcon() async {
        let members = (try? await repositories.group.fetchMembers(ofGroup: groupID)) ?? []
        myAvatarIcon = members.first?.avatarIcon ?? ""
    }

    /// 이모지를 탭 아이콘용 UIImage 로 렌더링. 빈 문자열이면 nil(기본 SF Symbol 사용).
    private static func emojiTabImage(_ emoji: String) -> UIImage? {
        guard !emoji.isEmpty else { return nil }
        let size = CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let str = emoji as NSString
            let font = UIFont.systemFont(ofSize: 24)
            let textSize = str.size(withAttributes: [.font: font])
            let rect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            str.draw(in: rect, withAttributes: [.font: font])
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}

#Preview("4탭 전체") {
    let (repos, groupID) = InMemorySeed.preview()
    return MainTabView(groupID: groupID)
        .environment(\.repositories, repos)
}
