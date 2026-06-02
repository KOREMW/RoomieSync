//
//  DeviceIdentifierProvider.swift
//  RoomieSync
//
//  계획서 참조: 리팩토링 — ChoreViewModel 의 #if canImport 분기를 protocol 뒤로
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-20
//
//  목적: ViewModel 이 UIKit 에 직접 의존하지 않도록 → 테스트에서 mock 주입 가능.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public protocol DeviceIdentifierProviding: Sendable {
    func deviceIdentifier() -> String
}

public struct DeviceIdentifierProvider: DeviceIdentifierProviding {
    public init() {}

    public func deviceIdentifier() -> String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        #else
        return "preview-device"
        #endif
    }
}

/// 테스트/Preview 용 — 결정적 ID 반환.
public struct FixedDeviceIdentifierProvider: DeviceIdentifierProviding {
    public let id: String
    public init(_ id: String = "test-device") { self.id = id }
    public func deviceIdentifier() -> String { id }
}
