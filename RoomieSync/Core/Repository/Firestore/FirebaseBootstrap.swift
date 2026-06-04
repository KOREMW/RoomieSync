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
        // 익명 인증을 미리 시작해 둔다(완료 대기는 FirebaseAuthGate 가 담당).
        Task { await FirebaseAuthGate.shared.ensureSignedIn() }
        #endif
    }

    static func debugLog(_ message: String) {
        #if DEBUG
        NSLog("[RoomieSync] %@", message)
        #endif
    }
}

/// 보안: Firestore 접근을 인증된 세션으로 제한하기 위한 익명 로그인 게이트.
///
/// 문제: `FirebaseApp.configure()` 직후 `signInAnonymously` 는 비동기라 완료까지 수백 ms 가
/// 걸린다. 그 사이에 Firestore 읽기/쓰기가 먼저 나가면 `request.auth == null` 상태로 전송되어
/// 보안 규칙이 거부하고("Missing or insufficient permissions"), 권한 오류는 자동 재시도되지 않는다.
///
/// 해결: 모든 Firestore 작업 직전에 `ensureSignedIn()` 을 await 해 인증 완료를 보장한다.
/// actor 로 직렬화하고 단일 Task 를 캐시해, 동시 호출이 와도 로그인은 한 번만 수행한다.
public actor FirebaseAuthGate {
    public static let shared = FirebaseAuthGate()

    private var signInTask: Task<Void, Never>?

    private init() {}

    /// 익명 인증이 끝날 때까지 대기. 이미 로그인돼 있으면 즉시 반환(저비용).
    public func ensureSignedIn() async {
        #if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { return }
        if Auth.auth().currentUser != nil { return }
        if signInTask == nil {
            signInTask = Task { await Self.performSignIn() }
        }
        await signInTask?.value
        #endif
    }

    #if canImport(FirebaseAuth)
    private static func performSignIn() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Auth.auth().signInAnonymously { _, error in
                if let error {
                    FirebaseBootstrap.debugLog("ℹ️ 익명 로그인 실패(콘솔에서 Anonymous Auth 활성화 필요): \(error.localizedDescription)")
                } else {
                    FirebaseBootstrap.debugLog("✅ Firebase 익명 인증 완료")
                }
                continuation.resume()
            }
        }
    }
    #endif
}
