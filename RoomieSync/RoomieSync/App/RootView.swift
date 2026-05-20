//
//  RootView.swift
//  RoomieSync
//
//  계획서 참조: 6.1 #1~#2 (최초 실행 / 룸메이트 합류)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  앱 진입 시 분기:
//   - 온보딩 미완료 → OnboardingView
//   - 온보딩 완료 + 그룹 미참여 → GroupCreate/Join 선택 화면
//   - 그룹 참여 완료 → MainTabView
//

import SwiftUI

struct RootView: View {

    // @AppStorage 는 2주차 mock 단계에서도 동작. 3주차에 CloudKit user record 와 동기화 검토.
    @AppStorage(AppKeys.Storage.didCompleteOnboarding) private var didCompleteOnboarding: Bool = false
    @AppStorage(AppKeys.Storage.currentGroupID) private var currentGroupIDString: String = ""

    var body: some View {
        Group {
            if !didCompleteOnboarding {
                OnboardingView(onFinish: { didCompleteOnboarding = true })
            } else if currentGroupIDString.isEmpty {
                GroupEntryView(onGroupReady: { id in
                    currentGroupIDString = id.uuidString
                })
            } else if let groupID = UUID(uuidString: currentGroupIDString) {
                MainTabView(groupID: groupID)
            } else {
                // 손상된 값 — 초기화
                Color.clear.onAppear { currentGroupIDString = "" }
            }
        }
        .tint(Tokens.primary)
    }
}

#Preview("온보딩 미완료") {
    let _ = UserDefaults.standard.removeObject(forKey: AppKeys.Storage.didCompleteOnboarding)
    return RootView()
}
