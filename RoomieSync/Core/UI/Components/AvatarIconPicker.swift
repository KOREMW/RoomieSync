//
//  AvatarIconPicker.swift
//  RoomieSync
//
//  멤버 아바타 아이콘(이모지) 선택기. 빈 문자열("")은 이름 이니셜 사용을 의미한다.
//  GroupCreate/Join/MyPage 에서 공통 사용.
//

import SwiftUI

public struct AvatarIconPicker: View {
    @Binding public var selected: String   // "" = 이니셜(글자)

    /// 첫 항목 ""은 "글자(이니셜)" 옵션. 나머지는 동물/모양 이모지.
    public static let icons: [String] = [
        "", "🐶", "🐱", "🐰", "🐻", "🦊", "🐼", "🐯", "🦁", "🐸",
        "🐵", "🐧", "🐥", "🦄", "🐢", "🐙", "🦉", "⭐", "🌙", "🌸"
    ]

    public init(selected: Binding<String>) {
        self._selected = selected
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(Self.icons, id: \.self) { icon in
                    let isSelected = selected == icon
                    ZStack {
                        Circle().fill(isSelected ? Tokens.surfaceHighlight : Tokens.surfaceMuted)
                        if icon.isEmpty {
                            Image(systemName: "textformat")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Tokens.textSecondary)
                        } else {
                            Text(icon).font(.system(size: 22))
                        }
                    }
                    .frame(width: 40, height: 40)
                    .overlay { if isSelected { Circle().stroke(Tokens.primary, lineWidth: 2) } }
                    .onTapGesture { selected = icon }
                    .accessibilityLabel(icon.isEmpty ? "글자(이니셜)" : "아이콘 \(icon)")
                }
            }
            .padding(.vertical, 2)
        }
    }
}
