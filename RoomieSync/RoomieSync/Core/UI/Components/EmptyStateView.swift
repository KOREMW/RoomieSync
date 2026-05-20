//
//  EmptyStateView.swift
//  RoomieSync
//
//  계획서 참조: 6.2 학습용이성 — "빈 상태(Empty State) 화면마다 다음에 뭐 할지 안내"
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

public struct EmptyStateView: View {
    public let icon: String           // SF Symbol
    public let title: String
    public let message: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Tokens.textTertiary)
            Text(title)
                .font(Typo.sectionTitle())
                .foregroundStyle(Tokens.textPrimary)
            Text(message)
                .font(Typo.body())
                .foregroundStyle(Tokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)
            if let actionTitle, let action {
                RoomieButton(actionTitle, action: action)
                    .padding(.horizontal, Spacing.xxxl)
                    .padding(.top, Spacing.s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "tray",
        title: "아직 가사가 없어요",
        message: "쓰레기·설거지·청소 같은 가사를 추가하면\n자동으로 멤버 순서대로 배정돼요.",
        actionTitle: "+ 가사 추가",
        action: {}
    )
}
