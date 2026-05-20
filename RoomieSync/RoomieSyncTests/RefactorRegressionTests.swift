//
//  RefactorRegressionTests.swift
//  RoomieSyncTests
//
//  계획서 참조: 리팩토링 후 회귀 방지
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-20
//

import Testing
import Foundation
@testable import RoomieSync

@Suite("리팩토링 회귀 테스트")
struct RefactorRegressionTests {

    @Test("AvatarPalette: 6색 정확, 인덱스 wrap-around")
    func avatarPalette() {
        #expect(AvatarPalette.hexValues.count == 6)
        #expect(AvatarPalette.hex(at: 0) == "#4F46E5")
        #expect(AvatarPalette.hex(at: 5) == "#06B6D4")
        // wrap-around
        #expect(AvatarPalette.hex(at: 6) == AvatarPalette.hex(at: 0))
        #expect(AvatarPalette.hex(at: 100) == AvatarPalette.hex(at: 100 % 6))
        // Tokens.avatarPalette 와 동기화 검증
        #expect(AvatarPalette.hexValues.count == Tokens.avatarPalette.count)
    }

    @Test("AppKeys: 각 키는 비어있지 않고 namespace 가 일관됨")
    func appKeys() {
        #expect(!AppKeys.Storage.didCompleteOnboarding.isEmpty)
        #expect(!AppKeys.Storage.currentGroupID.isEmpty)
        #expect(AppKeys.AppGroup.identifier.hasPrefix("group."))
        #expect(AppKeys.AppGroup.snapshot.contains("RoomieSync"))
        #expect(AppKeys.AppGroup.pendingActions.contains("RoomieSync"))
        #expect(AppKeys.CloudKit.containerID.hasPrefix("iCloud."))
        #expect(AppKeys.URLScheme.main == "roomiesync")
    }

    @Test("DeviceIdentifierProvider: Fixed 는 결정적 반환")
    func fixedDevice() {
        let p = FixedDeviceIdentifierProvider("test-abc")
        #expect(p.deviceIdentifier() == "test-abc")
        // 같은 인스턴스 반복 호출도 동일
        #expect(p.deviceIdentifier() == p.deviceIdentifier())
    }

    @Test("DeviceIdentifierProvider: 기본 Provider 는 빈 문자열 아님")
    func defaultDevice() {
        let p = DeviceIdentifierProvider()
        let id = p.deviceIdentifier()
        #expect(!id.isEmpty)
    }

    @Test("CKErrorMapper.userMessage(for: Error) — RepositoryError 위임")
    func errorMessageOverload() {
        let err: Error = RepositoryError.networkUnavailable
        let msg = CKErrorMapper.userMessage(for: err)
        #expect(msg.contains("인터넷"))
    }
}
