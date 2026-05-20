//
//  HapticManager.swift
//  RoomieSync
//
//  계획서 참조: 6.2 피드백 (가사 완료 시 햅틱 .success), 3주차 3-5
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class HapticManager {
    public static let shared = HapticManager()
    private init() {}

    // MARK: - Notification haptics (성공/경고/실패)

    public func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    public func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    public func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    // MARK: - Impact haptics (강도별 — Live Activity 트리거 등)

    public enum Intensity { case light, medium, heavy, rigid, soft }

    public func impact(_ intensity: Intensity = .medium) {
        #if canImport(UIKit)
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch intensity {
        case .light:  style = .light
        case .medium: style = .medium
        case .heavy:  style = .heavy
        case .rigid:  style = .rigid
        case .soft:   style = .soft
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    /// 선택 변경 — picker / segmented 등.
    public func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
