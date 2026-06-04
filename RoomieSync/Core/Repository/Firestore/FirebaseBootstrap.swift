//
//  FirebaseBootstrap.swift
//  RoomieSync
//
//  CloudKit 대안으로 추가한 Firestore 백엔드의 초기화 게이트.
//  GoogleService-Info.plist 가 번들에 있을 때만 Firebase 를 구성하고,
//  없으면 아무 것도 하지 않아 앱은 기존 로컬/CloudKit 백엔드로 동작한다.
//
//  Firebase SDK(SPM) 가 링크되지 않은 경우에도 컴파일되도록 canImport 로 가드.
//

import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

public enum FirebaseBootstrap {
    /// 앱 시작 시 한 번 호출. 시작 시점에 단일 스레드에서만 만지므로 nonisolated(unsafe).
    nonisolated(unsafe) public private(set) static var isConfigured = false

    /// GoogleService-Info.plist 존재 시에만 Firebase 구성. 그 외에는 no-op.
    public static func configureIfAvailable() {
        #if canImport(FirebaseCore)
        guard !isConfigured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            debugLog("ℹ️ GoogleService-Info.plist 없음 → Firestore 비활성 (로컬/CloudKit 사용)")
            return
        }
        FirebaseApp.configure()
        isConfigured = true
        debugLog("✅ Firebase 구성 완료 → Firestore 백엔드 사용")
        signInAnonymouslyIfNeeded()
        #endif
    }

    /// 보안: Firestore 접근을 인증된 세션으로 제한하기 위해 익명 로그인.
    /// (콘솔에서 Anonymous Auth 활성화 + 인증 요구 보안 규칙 배포 시 효력 발생)
    /// 실패해도 앱은 계속 동작하므로 best-effort.
    private static func signInAnonymouslyIfNeeded() {
        #if canImport(FirebaseAuth)
        if Auth.auth().currentUser != nil { return }
        Auth.auth().signInAnonymously { _, error in
            if let error {
                debugLog("ℹ️ 익명 로그인 실패(콘솔에서 Anonymous Auth 활성화 필요): \(error.localizedDescription)")
            } else {
                debugLog("✅ Firebase 익명 인증 완료")
            }
        }
        #endif
    }

    private static func debugLog(_ message: String) {
        #if DEBUG
        NSLog("[RoomieSync] %@", message)
        #endif
    }
}
