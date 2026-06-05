//
//  GroupNotesCard.swift
//  RoomieSync
//
//  홈 탭 상단의 '공지' 배너(#13). 고정 공지 우선, 가장 중요한 공지 1건을 크게 보여주고
//  나머지 건수를 함께 표시. 누르면 공지 보드로 이동한다.
//  HomeViewModel 에 의존하지 않고 자체적으로 데이터를 로드한다.
//

import SwiftUI

struct GroupNotesCard: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories
    @State private var notes: [GroupNote] = []

    /// fetchNotes 는 고정(핀) 우선 + 최신순이라 첫 항목이 가장 중요한 공지.
    private var top: GroupNote? { notes.first }

    var body: some View {
        NavigationLink {
            NotesBoardView(groupID: groupID)
        } label: {
            HStack(spacing: Spacing.m) {
                ZStack {
                    Circle().fill(Tokens.primary.opacity(0.15))
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Tokens.primary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("공지").font(Typo.bodyBold()).foregroundStyle(Tokens.textPrimary)
                        if notes.count > 1 {
                            Text("\(notes.count)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Tokens.primary).foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        if let top, top.isPinned {
                            Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(Tokens.primary)
                        }
                    }
                    if let top {
                        Text(top.text)
                            .font(Typo.body())
                            .foregroundStyle(Tokens.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text("공유할 공지를 남겨보세요 (분리수거·소모품 등)")
                            .font(Typo.caption())
                            .foregroundStyle(Tokens.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.textTertiary)
            }
            .padding(Spacing.m)
            .background(Tokens.surfaceHighlight)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.l)
        .task { await load() }
    }

    @MainActor
    private func load() async {
        notes = (try? await repositories.group.fetchNotes(groupID: groupID)) ?? []
    }
}
