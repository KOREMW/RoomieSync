//
//  NotificationInboxView.swift
//  RoomieSync
//
//  앱 안에서 받은 알림 모아보기(알림함) — 내 앞으로 온 송금 요청 + 그룹 공지.
//  (시스템 푸시가 아닌 Firestore 기록을 모아 보여줘, 시스템 알림을 놓쳐도 확인 가능)
//

import SwiftUI

struct NotificationInboxView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories
    @Environment(\.dismiss) private var dismiss

    struct InboxItem: Identifiable {
        let id: UUID
        let icon: String
        let tint: Color
        let title: String
        let subtitle: String
        let date: Date
        let route: AppRouter.Route   // 탭하면 이동할 화면
    }

    @State private var items: [InboxItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if isLoading {
                    ProgressView()
                } else if items.isEmpty {
                    ContentUnavailableView("새 알림이 없어요", systemImage: "bell.slash",
                                           description: Text("송금 요청·공지가 여기에 모여요."))
                } else {
                    List {
                        ForEach(items) { item in
                            Button {
                                open(item)
                            } label: {
                                HStack(spacing: Spacing.m) {
                                    ZStack {
                                        Circle().fill(item.tint.opacity(0.15))
                                        Image(systemName: item.icon).foregroundStyle(item.tint)
                                    }
                                    .frame(width: 38, height: 38)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(Typo.bodyBold())
                                        Text(item.subtitle).font(Typo.caption())
                                            .foregroundStyle(Tokens.textSecondary).lineLimit(2)
                                    }
                                    Spacer()
                                    Text(relativeDate(item.date))
                                        .font(.system(size: 11)).foregroundStyle(Tokens.textTertiary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11)).foregroundStyle(Tokens.textTertiary)
                                }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(item) } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("알림")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) { deleteAll() } label: { Text("전체 삭제") }
                        .disabled(items.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
            .task { await load() }
        }
    }

    /// 알림함 항목 탭 → 푸시 알림 탭과 동일하게 해당 화면으로 이동.
    /// 알림함 시트를 먼저 닫은 뒤 라우팅(시트 위 시트 충돌 방지).
    private func open(_ item: InboxItem) {
        let route = item.route
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))   // 알림함 시트 닫힘 대기
            AppRouter.shared.pending = route
        }
    }

    private func delete(_ item: InboxItem) {
        InboxDismissStore.add(item.id, groupID)
        items.removeAll { $0.id == item.id }
        HapticManager.shared.impact(.light)
    }

    private func deleteAll() {
        InboxDismissStore.add(items.map { $0.id }, groupID)
        items = []
        HapticManager.shared.impact(.medium)
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: .now)
    }

    @MainActor
    private func load() async {
        let members = (try? await repositories.group.fetchMembers(ofGroup: groupID)) ?? []
        let myID = CurrentMemberStore.resolve(members, groupID: groupID)?.id
        let nameByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })

        var result: [InboxItem] = []

        // 송금 요청 (내 앞으로 온 것)
        let requests = (try? await repositories.group.fetchPaymentRequests(groupID: groupID)) ?? []
        for r in requests where r.toMemberID == myID && r.fromMemberID != myID {
            let account = (r.bankName.map { "\($0) " } ?? "") + (r.accountNumber ?? "")
            result.append(InboxItem(
                id: r.id, icon: "bell.badge", tint: Tokens.receiveCardText,
                title: "송금 요청 · \(r.fromName)",
                subtitle: "\(CurrencyFormatter.format(r.amount)) 보내주세요" + (account.isEmpty ? "" : " · \(account)"),
                date: r.createdAt, route: .settlement))
        }

        // 공지
        let notes = (try? await repositories.group.fetchNotes(groupID: groupID)) ?? []
        for n in notes {
            result.append(InboxItem(
                id: n.id, icon: "megaphone.fill", tint: Tokens.primary,
                title: "공지" + (n.isPinned ? " · 고정" : ""),
                subtitle: "\(nameByID[n.authorMemberID] ?? "") · \(n.text)",
                date: n.createdAt, route: .notes))
        }

        // 내 알림함에서 삭제(숨김)한 항목 제외
        let hidden = InboxDismissStore.dismissed(groupID)
        items = result.filter { !hidden.contains($0.id.uuidString) }.sorted { $0.date > $1.date }
        isLoading = false

        // 알림함 확인 시각 기록 → 홈 종 배지 해제
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "inboxLastOpened.\(groupID.uuidString)")
    }
}
