//
//  DesignSystem.swift
//  RoomieSync
//
//  계획서 참조: 5.1 디자인 시스템
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  Stitch 시안 5장에서 추출한 색상 토큰을 그대로 SwiftUI 로.
//  단일 Primary 컬러(#4F46E5)로 일관성, 색 + 아이콘 + 텍스트 3중 표현 (접근성).
//

import SwiftUI

// MARK: - Color Tokens

public enum Tokens {

    // 시맨틱 컬러 (계획서 5.1 Semantic Colors)
    public static let primary       = Color(hex: "#4F46E5")    // Indigo 600 — 행동 유도
    public static let primaryDark   = Color(hex: "#3525CD")    // 시안 primary
    public static let primaryLight  = Color(hex: "#DAD7FF")    // primary-container

    public static let success       = Color(hex: "#10B981")    // 완료
    public static let danger        = Color(hex: "#EF4444")    // 오늘 내 차례 / 경고
    public static let warning       = Color(hex: "#F59E0B")    // 정산 대기

    // Surface (시안 ④ 지출 추가 / 시안 ⑤ 통계 카드 배경)
    public static let surface           = Color(hex: "#F9F9FF")
    public static let surfaceContainer  = Color(hex: "#FFFFFF")
    public static let surfaceMuted      = Color(hex: "#F1F3FF")
    public static let surfaceHighlight  = Color(hex: "#E1E8FD")

    // On-surface
    public static let textPrimary       = Color(hex: "#141B2B")
    public static let textSecondary     = Color(hex: "#464555")
    public static let textTertiary      = Color(hex: "#777587")
    public static let divider           = Color(hex: "#C7C4D8")

    // 받을 돈 / 줄 돈 카드 (시안 ① "이번 주 정산")
    public static let receiveCardBG     = Color(hex: "#DCFCE7")
    public static let receiveCardText   = Color(hex: "#10B981")
    public static let payCardBG         = Color(hex: "#FEE2E2")
    public static let payCardText       = Color(hex: "#EF4444")

    // 멤버 아바타 팔레트 (계획서 5.1 접근성: 색맹 대응 위해 6 색 분리)
    public static let avatarPalette: [Color] = [
        Color(hex: "#4F46E5"),  // indigo
        Color(hex: "#10B981"),  // emerald
        Color(hex: "#F59E0B"),  // amber
        Color(hex: "#EF4444"),  // red
        Color(hex: "#8B5CF6"),  // violet
        Color(hex: "#06B6D4")   // cyan
    ]
}

// MARK: - Typography (SF Pro 시스템)

public enum Typo {
    /// Title 28pt Bold (계획서 5.1) — 시안 ① "안녕하세요, 지훈님" 헤더
    public static func title() -> Font { .system(size: 28, weight: .bold) }
    /// Section heading — 시안 카드 제목 "오늘 할 일" 등
    public static func sectionTitle() -> Font { .system(size: 20, weight: .bold) }
    /// Body 17pt
    public static func body() -> Font { .system(size: 17, weight: .regular) }
    public static func bodyBold() -> Font { .system(size: 17, weight: .semibold) }
    /// Caption 13pt
    public static func caption() -> Font { .system(size: 13, weight: .regular) }
    /// 금액 강조 — 시안 ① "+12,500원", 시안 ③ "137,500원"
    public static func amount(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Spacing & Radius

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
}

public enum Radius {
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let pill: CGFloat = 999
}

// MARK: - Hex Color Helper

public extension Color {
    /// "#RRGGBB" / "#RRGGBBAA" / "RRGGBB" 모두 허용.
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        var rgba: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&rgba)

        let r, g, b, a: Double
        switch raw.count {
        case 6:
            r = Double((rgba >> 16) & 0xFF) / 255.0
            g = Double((rgba >> 8) & 0xFF) / 255.0
            b = Double(rgba & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgba >> 24) & 0xFF) / 255.0
            g = Double((rgba >> 16) & 0xFF) / 255.0
            b = Double((rgba >> 8) & 0xFF) / 255.0
            a = Double(rgba & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Currency Formatter (KRW)

public enum CurrencyFormatter {
    nonisolated(unsafe) private static let krw: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f
    }()

    public static func format(_ amount: Decimal, withSign: Bool = false) -> String {
        let raw = amount as NSDecimalNumber
        let str = krw.string(from: raw) ?? "0"
        if withSign, amount > 0 {
            return "+\(str)원"
        }
        return "\(str)원"
    }
}
