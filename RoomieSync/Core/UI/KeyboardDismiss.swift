//
//  KeyboardDismiss.swift
//  RoomieSync
//
//  키패드(숫자/일반)가 올라온 상태에서 입력 영역 바깥을 탭하면 키보드를 내린다.
//  윈도우에 탭 제스처를 설치하되 cancelsTouchesInView=false + 동시 인식 허용으로
//  버튼/리스트/스크롤 등 기존 터치 동작은 막지 않는다.
//

import SwiftUI
import UIKit

final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismisser()
    private var installed = false

    func installIfNeeded() {
        guard !installed else { return }
        guard let window = Self.keyWindow() else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false      // 다른 탭(버튼 등)을 가로채지 않음
        tap.delegate = self
        window.addGestureRecognizer(tap)
        installed = true
    }

    @objc private func handleTap() {
        // 현재 first responder 에게 사임 요청 → 키보드 내려감
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // 버튼/스크롤/리스트 제스처와 동시에 인식되도록 허용(충돌 방지)
    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ??
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first
    }
}

extension View {
    /// 루트에 한 번 적용하면 앱 전체에서 '바깥 탭 → 키보드 내림'이 동작한다.
    func dismissKeyboardOnTapOutside() -> some View {
        onAppear {
            // 윈도우가 준비된 다음 틱에 설치
            DispatchQueue.main.async { KeyboardDismisser.shared.installIfNeeded() }
        }
    }
}
