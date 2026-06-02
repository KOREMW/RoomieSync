//
//  AvatarColorPicker.swift
//  RoomieSync
//
//  계획서 참조: 리팩토링 — GroupCreate/Join 의 6색 팔레트 선택 UI 중복 제거
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-20
//

import SwiftUI

/// 6 색 아바타 팔레트 선택기. selectedIndex 양방향 바인딩.
public struct AvatarColorPicker: View {
    @Binding public var selectedIndex: Int

    public init(selectedIndex: Binding<Int>) {
        self._selectedIndex = selectedIndex
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            ForEach(Array(Tokens.avatarPalette.enumerated()), id: \.offset) { idx, color in
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .overlay {
                        if idx == selectedIndex {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .onTapGesture { selectedIndex = idx }
                    .accessibilityLabel("아바타 색상 \(idx + 1)")
            }
        }
    }
}

/// 6 색 팔레트의 hex 문자열 — Domain Member.avatarColorHex 와 호환.
public enum AvatarPalette {
    public static let hexValues: [String] = [
        "#4F46E5",  // indigo
        "#10B981",  // emerald
        "#F59E0B",  // amber
        "#EF4444",  // red
        "#8B5CF6",  // violet
        "#06B6D4"   // cyan
    ]

    public static func hex(at index: Int) -> String {
        hexValues[index % hexValues.count]
    }
}

#Preview {
    StatefulPreview()
}

private struct StatefulPreview: View {
    @State var idx: Int = 0
    var body: some View {
        VStack(spacing: 20) {
            AvatarColorPicker(selectedIndex: $idx)
            Text("선택: \(AvatarPalette.hex(at: idx))")
                .font(.caption.monospaced())
        }
        .padding()
    }
}
