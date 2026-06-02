//
//  ToastView.swift
//  RoomieSync
//
//  계획서 참조: 6.2 오류 정정 — 가사 완료 후 5초 "취소" 토스트
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

/// 5초 카운트다운 + 취소 버튼이 달린 토스트.
/// 자동 만료 시 onConfirm, 사용자가 취소 누르면 onCancel.
public struct UndoToastView: View {
    public let message: String
    public let duration: TimeInterval
    public let onCancel: () -> Void
    public let onConfirm: () -> Void

    @State private var remaining: TimeInterval

    public init(
        message: String,
        duration: TimeInterval = 5.0,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.message = message
        self.duration = duration
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self._remaining = State(initialValue: duration)
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0, remaining / duration))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(ceil(remaining)))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)

            Text(message)
                .font(Typo.body())
                .foregroundStyle(.white)

            Spacer()

            Button("취소", action: onCancel)
                .font(Typo.bodyBold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .background(Tokens.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .padding(.horizontal, Spacing.l)
        .task {
            // 0.1초마다 감소 → 자연스러운 프로그레스
            let tick: TimeInterval = 0.1
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
                remaining -= tick
            }
            onConfirm()
        }
    }
}

// MARK: - 토스트 오버레이 modifier

public extension View {
    /// 화면 하단에 떠 있는 5초 취소 토스트.
    /// `binding` 이 non-nil 인 동안 표시.
    @ViewBuilder
    func undoToast(
        item: Binding<UndoToastConfig?>
    ) -> some View {
        self.overlay(alignment: .bottom) {
            if let config = item.wrappedValue {
                UndoToastView(
                    message: config.message,
                    duration: config.duration,
                    onCancel: {
                        config.onCancel()
                        item.wrappedValue = nil
                    },
                    onConfirm: {
                        config.onConfirm()
                        item.wrappedValue = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                // 하단 탭바(약 49~83pt)에 가려지지 않도록 충분히 띄운다.
                .padding(.bottom, Spacing.xxl + 70)
            }
        }
        .animation(.spring(duration: 0.3), value: item.wrappedValue != nil)
    }
}

public struct UndoToastConfig: Equatable {
    public let id: UUID
    public let message: String
    public let duration: TimeInterval
    public let onCancel: () -> Void
    public let onConfirm: () -> Void

    public init(
        message: String,
        duration: TimeInterval = 5.0,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.id = UUID()
        self.message = message
        self.duration = duration
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public static func == (lhs: UndoToastConfig, rhs: UndoToastConfig) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    UndoToastView(
        message: "🗑 쓰레기 배출 완료",
        onCancel: {},
        onConfirm: {}
    )
}
