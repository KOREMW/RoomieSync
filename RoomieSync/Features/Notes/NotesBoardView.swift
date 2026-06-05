//
//  NotesBoardView.swift
//  RoomieSync
//
//  공지/메모 보드(#13) — 그룹 구성원이 공유하는 공지·메모.
//  고정(핀) 항목이 상단, 그 외 최신순. 추가/고정/삭제 지원.
//

import SwiftUI

struct NotesBoardView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories

    @State private var notes: [GroupNote] = []
    @State private var membersByID: [UUID: Member] = [:]
    @State private var myMemberID: UUID? = nil
    @State private var draft: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    /// 마지막으로 확인한 공지 시각(epoch). 홈 배너의 'NEW' 강조 해제에 사용.
    @AppStorage private var lastSeen: Double

    init(groupID: UUID) {
        self.groupID = groupID
        self._lastSeen = AppStorage(wrappedValue: 0, "notesLastSeen.\(groupID.uuidString)")
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.s) {
                    TextField("공지 입력 (예: 이번 주 분리수거는 일요일)", text: $draft, axis: .vertical)
                        .lineLimit(1...3)
                    Button {
                        Task { await add() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || myMemberID == nil)
                }
            }

            if isLoading {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            } else if notes.isEmpty {
                Section {
                    Text("아직 공지가 없어요. 첫 공지를 남겨보세요.")
                        .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                }
            } else {
                ForEach(notes) { note in
                    noteRow(note)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await delete(note) }
                            } label: { Label("삭제", systemImage: "trash") }
                            Button {
                                Task { await togglePin(note) }
                            } label: {
                                Label(note.isPinned ? "고정 해제" : "고정",
                                      systemImage: note.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(Tokens.primary)
                        }
                }
            }
        }
        .navigationTitle("공지")
        .navigationBarTitleDisplayMode(.inline)
        .alert("문제가 발생했어요", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .task { await load() }
    }

    @ViewBuilder
    private func noteRow(_ note: GroupNote) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            if let author = membersByID[note.authorMemberID] {
                MemberAvatarView(member: author, size: 32)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if note.isPinned {
                        Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(Tokens.primary)
                    }
                    Text(note.text)
                }
                Text("\(membersByID[note.authorMemberID]?.name ?? "?") · \(relativeDate(note.createdAt))")
                    .font(Typo.caption()).foregroundStyle(Tokens.textTertiary)
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: .now)
    }

    @MainActor
    private func load() async {
        do {
            let members = try await repositories.group.fetchMembers(ofGroup: groupID)
            membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            myMemberID = members.first?.id
            notes = try await repositories.group.fetchNotes(groupID: groupID)
            // 보드를 열어 확인했으므로 가장 최신 공지 시각을 '읽음'으로 기록 → 홈 배너 NEW 해제.
            if let latest = notes.map(\.createdAt).max()?.timeIntervalSince1970 {
                lastSeen = max(lastSeen, latest)
            }
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
        isLoading = false
    }

    @MainActor
    private func add() async {
        guard let me = myMemberID else { return }
        let text = InputValidator.memo(draft)
        guard !text.isEmpty else { return }
        let authorName = membersByID[me]?.name ?? "누군가"
        do {
            _ = try await repositories.group.addNote(groupID: groupID, authorMemberID: me, text: text)
            draft = ""
            HapticManager.shared.success()
            await NotificationService.shared.notifyAnnouncement(text: text, authorName: authorName)
            await load()
        } catch {
            errorMessage = "공지 저장에 실패했어요.\n(\(CKErrorMapper.userMessage(for: error)))"
        }
    }

    @MainActor
    private func delete(_ note: GroupNote) async {
        do {
            try await repositories.group.deleteNote(note.id)
            await load()
        } catch {
            errorMessage = "삭제에 실패했어요.\n(\(CKErrorMapper.userMessage(for: error)))"
        }
    }

    @MainActor
    private func togglePin(_ note: GroupNote) async {
        do {
            _ = try await repositories.group.setNotePinned(note.id, pinned: !note.isPinned)
            await load()
        } catch {
            errorMessage = "고정 변경에 실패했어요.\n(\(CKErrorMapper.userMessage(for: error)))"
        }
    }
}
