//
//  SettlementHistoryView.swift
//  RoomieSync
//
//  완료된 정산 기록(#5). 정산 완료로 표시한 송금 내역을 날짜별로 보여준다.
//  Settlement.settledAt 가 있는 항목만 표시(분쟁 방지용 기록 보존).
//

import SwiftUI

struct SettlementHistoryView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories

    @State private var membersByID: [UUID: Member] = [:]
    @State private var sections: [DaySection] = []
    @State private var isLoading = true

    private struct DaySection: Identifiable {
        let id: Date          // 해당 날짜(자정)
        let title: String
        let items: [Settlement]
        var total: Decimal { items.reduce(Decimal(0)) { $0 + $1.amount } }
    }

    var body: some View {
        SwiftUI.Group {
            if isLoading {
                ProgressView()
            } else if sections.isEmpty {
                ContentUnavailableView("정산 내역이 없어요", systemImage: "clock.arrow.circlepath",
                                       description: Text("정산을 완료하면 여기에 기록이 남아요."))
            } else {
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.items) { s in
                                HStack {
                                    Text("\(name(s.fromMemberID)) → \(name(s.toMemberID))")
                                    Spacer()
                                    Text(CurrencyFormatter.format(s.amount)).fontWeight(.semibold)
                                }
                            }
                        } header: {
                            HStack {
                                Text(section.title)
                                Spacer()
                                Text("합계 \(CurrencyFormatter.format(section.total))")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("정산 내역")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func name(_ id: UUID) -> String { membersByID[id]?.name ?? "?" }

    @MainActor
    private func load() async {
        do {
            let members = try await repositories.group.fetchMembers(ofGroup: groupID)
            membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            let all = try await repositories.expense.fetchSettlements(groupID: groupID, onlyPending: false)
            let completed = all.filter { $0.isSettled }
            sections = buildSections(completed)
        } catch {
            sections = []
        }
        isLoading = false
    }

    private func buildSections(_ settlements: [Settlement]) -> [DaySection] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: settlements) { s in
            cal.startOfDay(for: s.settledAt ?? .now)
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ko_KR")
        fmt.dateFormat = "yyyy년 M월 d일"
        return grouped.keys.sorted(by: >).map { day in
            let items = (grouped[day] ?? []).sorted { ($0.settledAt ?? .now) > ($1.settledAt ?? .now) }
            return DaySection(id: day, title: fmt.string(from: day), items: items)
        }
    }
}
