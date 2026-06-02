//
//  OnboardingView.swift
//  RoomieSync
//
//  계획서 참조: 6.2 학습용이성 — 첫 실행 시 3장 온보딩 (문제 → 솔루션 → 사용법)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "exclamationmark.bubble.fill",
            title: "이런 적 있으셨나요?",
            body: "누가 쓰레기 버릴 차례지?\n휴지 값 누가 냈었지?\n매번 까먹어 룸메이트랑 다툰 적 있나요?"
        ),
        OnboardingPage(
            icon: "arrow.triangle.2.circlepath",
            title: "RoomieSync가 자동으로",
            body: "가사는 자동으로 멤버 순서대로 배정,\n공동 지출은 한 번 입력으로 자동 정산.\n앱이 알아서 알림까지 보내요."
        ),
        OnboardingPage(
            icon: "iphone.gen3",
            title: "위젯·잠금화면에서 한눈에",
            body: "앱을 열지 않아도\n위젯·잠금화면·Dynamic Island로\n오늘 내 차례를 즉시 확인해요."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { idx, page in
                    pageView(page).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            RoomieButton(pageIndex == pages.count - 1 ? "시작하기" : "다음") {
                if pageIndex == pages.count - 1 {
                    Task {
                        _ = await NotificationService.shared.requestAuthorizationIfNeeded()
                        onFinish()
                    }
                } else {
                    withAnimation { pageIndex += 1 }
                }
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.xxl)

            Button("건너뛰기", action: onFinish)
                .font(Typo.caption())
                .foregroundStyle(Tokens.textTertiary)
                .padding(.bottom, Spacing.l)
        }
        .background(Tokens.surface.ignoresSafeArea())
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(Tokens.primary)
                .symbolRenderingMode(.hierarchical)
            Text(page.title)
                .font(Typo.title())
                .foregroundStyle(Tokens.textPrimary)
                .multilineTextAlignment(.center)
            Text(page.body)
                .font(Typo.body())
                .foregroundStyle(Tokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
