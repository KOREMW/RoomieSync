//
//  MemberAvatarView.swift
//  RoomieSync
//
//  계획서 참조: 5.1 디자인 시스템 (색 + 아이콘 + 텍스트 3중 표현)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  Stitch 시안 ②의 "JH", "SY", "MH" 원형 이니셜 칩과 1:1 매핑.
//

import SwiftUI

public struct MemberAvatarView: View {
    public let member: Member
    public let size: CGFloat
    public let highlighted: Bool

    public init(member: Member, size: CGFloat = 36, highlighted: Bool = false) {
        self.member = member
        self.size = size
        self.highlighted = highlighted
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: member.avatarColorHex).opacity(0.18))
            if member.avatarIcon.isEmpty {
                Text(member.initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Color(hex: member.avatarColorHex))
            } else {
                Text(member.avatarIcon)
                    .font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Tokens.primary, lineWidth: highlighted ? 2 : 0)
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(0..<4) { i in
            MemberAvatarView(
                member: Member(
                    name: ["김지훈", "박서연", "이민호", "Alex"][i],
                    avatarColorHex: Tokens.avatarPalette[i].toHex(),
                    groupID: UUID()
                ),
                size: 48,
                highlighted: i == 0
            )
        }
    }
    .padding()
}

// Preview 헬퍼 — Color → hex 문자열 (시안에서는 Member.avatarColorHex 이 String 이므로 변환 필요)
private extension Color {
    func toHex() -> String {
        // Preview 한정 단순화 — 실제 운영에서는 NSColor/UIColor 경유.
        // 색맹 팔레트 6 색 중 하나라 임시로 알려진 hex 반환.
        switch self {
        case Tokens.avatarPalette[0]: return "#4F46E5"
        case Tokens.avatarPalette[1]: return "#10B981"
        case Tokens.avatarPalette[2]: return "#F59E0B"
        case Tokens.avatarPalette[3]: return "#EF4444"
        case Tokens.avatarPalette[4]: return "#8B5CF6"
        case Tokens.avatarPalette[5]: return "#06B6D4"
        default: return "#4F46E5"
        }
    }
}
