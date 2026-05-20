//
//  BalanceCard.swift
//  RoomieSync
//
//  계획서 참조: 6.2 피드백 — 잔액 카운트업 애니메이션
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  Stitch 시안 ①의 "받을 돈 +12,500원" / "줄 돈 −8,000원" 카드 페어 구현.
//

import SwiftUI

public struct BalanceCard: View {

    public enum Kind { case receive, pay }

    public let kind: Kind
    public let amount: Decimal

    @State private var animatedAmount: Decimal = 0

    public init(kind: Kind, amount: Decimal) {
        self.kind = kind
        self.amount = amount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(kind == .receive ? "받을 돈" : "줄 돈")
                .font(Typo.caption())
                .foregroundStyle(textColor.opacity(0.8))
            Text(displayString)
                .font(Typo.amount(20))
                .foregroundStyle(textColor)
                .contentTransition(.numericText(value: Double(truncating: animatedAmount as NSDecimalNumber)))
                .accessibilityLabel(accessibilityText)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .onAppear { runCountUp() }
        .onChange(of: amount) { _, _ in runCountUp() }
    }

    private var backgroundColor: Color {
        kind == .receive ? Tokens.receiveCardBG : Tokens.payCardBG
    }
    private var textColor: Color {
        kind == .receive ? Tokens.receiveCardText : Tokens.payCardText
    }
    private var displayString: String {
        switch kind {
        case .receive: return CurrencyFormatter.format(animatedAmount, withSign: true)
        case .pay:     return "−" + CurrencyFormatter.format(animatedAmount)
        }
    }
    private var accessibilityText: String {
        let kindLabel = kind == .receive ? "받을 돈" : "줄 돈"
        return "\(kindLabel) \(CurrencyFormatter.format(amount))"
    }

    private func runCountUp() {
        animatedAmount = 0
        withAnimation(.easeOut(duration: 0.6)) {
            animatedAmount = amount
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        BalanceCard(kind: .receive, amount: 12_500)
        BalanceCard(kind: .pay, amount: 8_000)
    }
    .padding()
}
