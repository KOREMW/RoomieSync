//
//  CKErrorMapperTests.swift
//  RoomieSyncTests
//
//  계획서 참조: 6.3 CKError 핸들링
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//

import Testing
import Foundation
import CloudKit
@testable import RoomieSync

@Suite("CKErrorMapper — CKError → RepositoryError")
struct CKErrorMapperTests {

    @Test("networkUnavailable → .networkUnavailable")
    func networkUnavailable() {
        let cke = CKError(.networkUnavailable)
        let mapped = CKErrorMapper.map(cke)
        #expect(mapped == .networkUnavailable)
    }

    @Test("quotaExceeded → .quotaExceeded")
    func quotaExceeded() {
        let cke = CKError(.quotaExceeded)
        #expect(CKErrorMapper.map(cke) == .quotaExceeded)
    }

    @Test("notAuthenticated → invalidInput with iCloud 안내")
    func notAuthenticated() {
        let cke = CKError(.notAuthenticated)
        if case .invalidInput(let reason) = CKErrorMapper.map(cke) {
            #expect(reason.contains("iCloud"))
        } else {
            Issue.record("invalidInput 이어야 함")
        }
    }

    @Test("serverRecordChanged → .conflict")
    func conflict() {
        let cke = CKError(.serverRecordChanged)
        if case .conflict = CKErrorMapper.map(cke) {
            // OK
        } else {
            Issue.record("conflict 이어야 함")
        }
    }

    @Test("userMessage 는 한국어 한 문장")
    func userMessageKorean() {
        let msg = CKErrorMapper.userMessage(for: .networkUnavailable)
        #expect(msg.contains("인터넷"))
    }
}
