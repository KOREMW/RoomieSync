//
//  GroupNotesCard.swift
//  RoomieSync
//
//  홈 탭의 공지/메모 요약 카드(#13). 고정 공지 우선 최대 3건 표시 후 보드로 연결.
//  HomeViewModel 에 의존하지 않도록 자체적으로 데이터를 로드한다.
//

import SwiftUI

struct GroupNotesCard: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories
    @State private var notes: [GroupNote] = []

    var body: some View {
        NavigationLink {
            NotesBoardView(groupID: groupID)
        } label: {
            SectionCard {
                HStack {
                    Label("공지·메모", systemImage: "pin.fill")
                        .font(Typo.sectionTitle())
                        .foregroundStyle(Tokens.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.textTertiary)
                }

                if notes.isEmpty {
                    Text("공유할 공지를 남겨보세요 (분리수거·소모품 등)")
                        .font(Typo.caption())
                        .foregroundStyle(Tokens.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(notes.prefix(3)) { note in
                            HStack(spacing: 6) {
                                Image(systemName: note.isPinned ? "pin.fill" : "circle.fill")
                                    .font(.system(size: note.isPinned ? 10 : 5))
                                    .foregroundStyle(note.isPinned ? Tokens.primary : Tokens.textTertiary)
                                Text(note.text)
                                    .font(Typo.body())
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }
            }
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
