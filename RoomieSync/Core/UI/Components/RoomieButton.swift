//
//  RoomieButton.swift
//  RoomieSync
//
//  계획서 참조: 5.1 디자인 시스템 (단일 Primary 컬러 행동 유도)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  Stitch 시안 ① "정산하기", 시안 ② "+ 새 가사", 시안 ④ "저장" 모두 이 컴포넌트.
//

import SwiftUI

public struct RoomieButton: View {

    public enum Style {
        case primary, secondary, danger, ghost
    }

    public let title: String
    public let style: Style
    public let isEnabled: Bool
    public let icon: String?
    public let action: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        isEnabled: Bool = true,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(Typo.bodyBold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            .opacity(isEnabled ? 1.0 : 0.45)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch style {
        case .primary:   return Tokens.primary
        case .secondary: return Tokens.surfaceMuted
        case .danger:    return Tokens.danger
        case .ghost:     return .clear
        }
    }
    private var foreground: Color {
        switch style {
        case .primary, .danger:   return .white
        case .secondary, .ghost:  return Tokens.primary
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        RoomieButton("정산하기") {}
        RoomieButton("+ 새 가사", style: .primary, icon: "plus") {}
        RoomieButton("취소", style: .secondary) {}
        RoomieButton("탈퇴하기", style: .danger) {}
        RoomieButton("비활성화", isEnabled: false) {}
    }
    .padding()
}
