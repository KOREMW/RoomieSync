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

public enum FirebaseBootstrap {
    /// 앱 시작 시 한 번 호출. 시작 시점에 단일 스레드에서만 만지므로 nonisolated(unsafe).
    nonisolated(unsafe) public private(set) static var isConfigured = false

    /// GoogleService-Info.plist 존재 시에만 Firebase 구성. 그 외에는 no-op.
    public static func configureIfAvailable() {
        #if canImport(FirebaseCore)
        guard !isConfigured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("ℹ️ GoogleService-Info.plist 없음 → Firestore 비활성 (로컬/CloudKit 사용)")
            return
        }
        FirebaseApp.configure()
        isConfigured = true
        print("✅ Firebase 구성 완료 → Firestore 백엔드 사용")
        #endif
    }
}
