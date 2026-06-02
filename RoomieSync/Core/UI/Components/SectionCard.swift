//
//  SectionCard.swift
//  RoomieSync
//
//  계획서 참조: 리팩토링 — HomeView/StatsView 의 cardContainer 중복 제거
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-20
//
//  흰 배경 + 둥근 모서리 + 가벼운 그림자의 카드 컨테이너.
//  화면 측면 padding 까지 포함된 form factor 를 통일.
//

import SwiftUI

public struct SectionCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            content
        }
        .padding(Spacing.l)
        .background(Tokens.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal, Spacing.l)
    }
}

#Preview {
    VStack {
        SectionCard {
            Text("카드 제목").font(Typo.sectionTitle())
            Text("본문 내용입니다").font(Typo.body())
        }
        SectionCard {
            HStack {
                Text("좌측")
                Spacer()
                Text("우측")
            }
        }
    }
    .background(Tokens.surface)
}
