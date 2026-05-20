//
//  ExpenseAddView.swift
//  RoomieSync
//
//  계획서 참조: Stitch 시안 ④ 지출 추가
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import SwiftUI

struct ExpenseAddView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ExpenseViewModel

    @State private var amountText: String = ""
    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var paidByID: UUID? = nil
    @State private var participantIDs: Set<UUID> = []
    @State private var category: ExpenseCategory = .household
    @State private var memo: String = ""
    @State private var isWorking: Bool = false

    private var amount: Decimal { Decimal(string: amountText) ?? 0 }
    private var perPerson: Decimal {
        guard !participantIDs.isEmpty else { return 0 }
        return amount / Decimal(participantIDs.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("₩").font(Typo.amount(28)).foregroundStyle(Tokens.primary)
                        TextField("0", text: $amountText)
                            .font(Typo.amount(28))
                            .foregroundStyle(Tokens.primary)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                    }
                } header: { Text("금액") }

                Section("항목 이름") {
                    TextField("예: 휴지 12롤", text: $title)
                }

                Section("날짜") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section("카테고리") {
                    Picker("카테고리", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { c in
                            Label(c.displayName, systemImage: c.sfSymbolName).tag(c)
                        }
                    }
                }

                Section("결제한 사람") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.l) {
                            ForEach(viewModel.members) { m in
                                VStack(spacing: 6) {
                                    MemberAvatarView(member: m, size: 48, highlighted: paidByID == m.id)
                                    Text(m.name)
                                        .font(Typo.caption())
                                        .foregroundStyle(paidByID == m.id ? Tokens.primary : Tokens.textSecondary)
                                }
                                .onTapGesture { paidByID = m.id }
                            }
                        }
                    }
                }

                Section("함께 사용한 사람") {
                    ForEach(viewModel.members) { m in
                        Button {
                            if participantIDs.contains(m.id) { participantIDs.remove(m.id) }
                            else { participantIDs.insert(m.id) }
                        } label: {
                            HStack {
                                Image(systemName: participantIDs.contains(m.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(participantIDs.contains(m.id) ? Tokens.primary : Tokens.textTertiary)
                                MemberAvatarView(member: m, size: 28)
                                Text(m.name)
                                    .foregroundStyle(Tokens.textPrimary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if !participantIDs.isEmpty {
                        HStack {
                            Spacer()
                            Text("각자 부담: \(CurrencyFormatter.format(perPerson))")
                                .font(Typo.caption())
                                .foregroundStyle(Tokens.textSecondary)
                        }
                    }
                }

                Section("메모 (선택)") {
                    TextField("메모를 입력하세요", text: $memo, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("지출 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isWorking)
                }
            }
            .task {
                paidByID = viewModel.members.first?.id
                participantIDs = Set(viewModel.members.map(\.id))
            }
        }
    }

    private var canSave: Bool {
        amount > 0 &&
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        paidByID != nil &&
        !participantIDs.isEmpty
    }

    @MainActor
    private func save() async {
        guard let payer = paidByID else { return }
        isWorking = true
        defer { isWorking = false }
        let expense = Expense(
            groupID: viewModel.groupID,
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            paidByMemberID: payer,
            participantMemberIDs: Array(participantIDs),
            date: date,
            isSettled: false,
            category: category,
            memo: memo.isEmpty ? nil : memo
        )
        let ok = await viewModel.addExpense(expense)
        if ok {
            HapticManager.shared.success()
            dismiss()
        }
    }
}

#Preview {
    ExpenseAddView(
        viewModel: ExpenseViewModel(groupID: UUID(), repositories: .preview())
    )
}
