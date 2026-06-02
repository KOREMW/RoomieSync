//
//  GroupEntryView.swift
//  RoomieSync
//
//  계획서 참조: 6.1 #1 (호스트) / #2 (룸메이트 합류)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct GroupEntryView: View {
    let onGroupReady: (UUID) -> Void

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: Spacing.xxl) {
                Spacer()

                Image(systemName: "house.and.flag.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Tokens.primary)

                Text("우리집을 시작해볼까요?")
                    .font(Typo.title())
                    .foregroundStyle(Tokens.textPrimary)

                Text("새 그룹을 만들거나 룸메이트의 초대 코드로 합류하세요.")
                    .font(Typo.body())
                    .foregroundStyle(Tokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)

                Spacer()

                VStack(spacing: Spacing.m) {
                    RoomieButton("새 그룹 만들기", icon: "plus.circle.fill") {
                        path.append(GroupRoute.create)
                    }
                    RoomieButton("초대 코드로 참여", style: .secondary, icon: "person.2.fill") {
                        path.append(GroupRoute.join)
                    }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Tokens.surface.ignoresSafeArea())
            .navigationDestination(for: GroupRoute.self) { route in
                switch route {
                case .create: GroupCreateView(onCreated: onGroupReady)
                case .join:   GroupJoinView(onJoined: onGroupReady)
                }
            }
        }
    }
}

enum GroupRoute: Hashable {
    case create, join
}

#Preview {
    GroupEntryView(onGroupReady: { _ in })
        .environment(\.repositories, .preview())
}
