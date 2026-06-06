//
//  MonthlyExpensesView.swift
//  RoomieSync
//
//  달별 지출 내역 — 월 단위로 묶어 합계와 각 지출을 보여준다.
//  통계 탭의 '월별 지출 추이' 카드에서 진입.
//

import SwiftUI

struct MonthlyExpensesView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories

    private struct MonthGroup: Identifiable {
        let id: Int          // year*100 + month (정렬용)
        let label: String    // "2026년 6월"
        let total: Decimal
        let items: [Expense]
    }

    @State private var groups: [MonthGroup] = []
    @State private var nameByID: [UUID: String] = [:]
    @State private var isLoading = true

    var body: some View {
        SwiftUI.Group {
            if isLoading {
                ProgressView()
            } else if groups.isEmpty {
                ContentUnavailableView("지출 내역이 없어요", systemImage: "creditcard",
                                       description: Text("지출을 등록하면 달별로 모아 보여줘요."))
            } else {
                List {
                    ForEach(groups) { g in
                        Section {
                            ForEach(g.items) { e in row(e) }
                        } header: {
                            HStack {
                                Text(g.label)
                                Spacer()
                                Text(CurrencyFormatter.format(g.total))
                                    .foregroundStyle(Tokens.primary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("월별 지출 내역")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func row(_ e: Expense) -> some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.s).fill(Tokens.surfaceHighlight)
                Image(systemName: e.category.sfSymbolName).foregroundStyle(Tokens.primary)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(e.title).font(Typo.bodyBold())
                    if e.isSettled {
                        Text("정산완료").font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Tokens.receiveCardBG).foregroundStyle(Tokens.receiveCardText)
                            .clipShape(Capsule())
                    }
                }
                Text("\(nameByID[e.paidByMemberID] ?? "?") 결제 · \(dayString(e.date))")
                    .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
            }
            Spacer()
            Text(CurrencyFormatter.format(e.amount)).font(Typo.bodyBold()).foregroundStyle(Tokens.primary)
        }
        .padding(.vertical, 2)
    }

    private func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: date)
    }

    @MainActor
    private func load() async {
        let members = (try? await repositories.group.fetchMembers(ofGroup: groupID)) ?? []
        nameByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })
        let expenses = (try? await repositories.expense.fetchExpenses(groupID: groupID, includeSettled: true)) ?? []

        let cal = Calendar.current
        let byKey = Dictionary(grouping: expenses) { (e: Expense) -> Int in
            let c = cal.dateComponents([.year, .month], from: e.date)
            return (c.year ?? 0) * 100 + (c.month ?? 0)
        }
        groups = byKey.keys.sorted(by: >).map { key in
            let items = (byKey[key] ?? []).sorted { $0.date > $1.date }
            let total = items.reduce(Decimal(0)) { $0 + $1.amount }
            return MonthGroup(id: key, label: "\(key / 100)년 \(key % 100)월", total: total, items: items)
        }
        isLoading = false
    }
}
