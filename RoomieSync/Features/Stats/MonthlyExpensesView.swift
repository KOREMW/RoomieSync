//
//  MonthlyExpensesView.swift
//  RoomieSync
//
//  달별 지출 내역 — 한 번에 한 달을 보여준다.
//  ◀ ▶ 로 한 달씩 이동, 년·월 텍스트를 누르면 휠 피커로 직접 선택.
//

import SwiftUI

struct MonthlyExpensesView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories

    @State private var allExpenses: [Expense] = []
    @State private var nameByID: [UUID: String] = [:]
    @State private var isLoading = true
    @State private var showPicker = false

    @State private var year: Int = Calendar.current.component(.year, from: .now)
    @State private var month: Int = Calendar.current.component(.month, from: .now)

    private var monthExpenses: [Expense] {
        let cal = Calendar.current
        return allExpenses.filter {
            let c = cal.dateComponents([.year, .month], from: $0.date)
            return c.year == year && c.month == month
        }.sorted { $0.date > $1.date }
    }
    private var monthTotal: Decimal { monthExpenses.reduce(Decimal(0)) { $0 + $1.amount } }

    private var years: [Int] {
        let cur = Calendar.current.component(.year, from: .now)
        var set = Set((cur - 5)...(cur + 1))
        set.insert(year)
        if let earliest = allExpenses.map({ Calendar.current.component(.year, from: $0.date) }).min() {
            (earliest...max(earliest, cur)).forEach { set.insert($0) }
        }
        return set.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            monthNavigator
            Divider()
            content
        }
        .navigationTitle("\(year)년 \(month)월 지출 내역")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showPicker) {
            pickerSheet
        }
    }

    // MARK: - 월 이동 바 (◀ 2026년 6월 ▶)

    private var monthNavigator: some View {
        HStack(spacing: Spacing.m) {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
            }
            Button { showPicker = true } label: {
                HStack(spacing: 4) {
                    Text("\(year)년 \(month)월").font(Typo.sectionTitle()).foregroundStyle(Tokens.textPrimary)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.textSecondary)
                }
            }
            .buttonStyle(.plain)
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("합계").font(.system(size: 10)).foregroundStyle(Tokens.textTertiary)
                Text(CurrencyFormatter.format(monthTotal)).font(Typo.bodyBold()).foregroundStyle(Tokens.primary)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .background(Tokens.surface)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer(); ProgressView(); Spacer()
        } else if monthExpenses.isEmpty {
            ContentUnavailableView("이 달은 지출이 없어요", systemImage: "creditcard",
                                   description: Text("◀ ▶ 로 다른 달을 확인해보세요."))
        } else {
            List {
                ForEach(monthExpenses) { e in row(e) }
            }
        }
    }

    // MARK: - 년·월 선택 시트

    private var pickerSheet: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("년", selection: $year) {
                    ForEach(years, id: \.self) { Text("\($0)년").tag($0) }
                }
                .pickerStyle(.wheel)
                Picker("월", selection: $month) {
                    ForEach(1...12, id: \.self) { Text("\($0)월").tag($0) }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("년·월 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { showPicker = false } } }
        }
        .presentationDetents([.height(300)])
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

    private func shiftMonth(_ delta: Int) {
        var m = month + delta, y = year
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        month = m; year = y
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
        allExpenses = (try? await repositories.expense.fetchExpenses(groupID: groupID, includeSettled: true)) ?? []
        isLoading = false
    }
}
