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
    /// nil 이면 신규 추가, 값이 있으면 해당 지출 수정 모드.
    var editing: Expense? = nil

    @State private var amountText: String = ""
    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var paidByID: UUID? = nil
    @State private var participantIDs: Set<UUID> = []
    @State private var category: ExpenseCategory = .household
    @State private var memo: String = ""
    @State private var customSplit: Bool = false              // false = 더치페이(균등)
    @State private var customAmounts: [UUID: String] = [:]    // 참여자별 직접 입력 금액
    @State private var isWorking: Bool = false
    @State private var didPrefill: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var isEditing: Bool { editing != nil }
    private var isSettled: Bool { editing?.isSettled ?? false }

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
                }

                if !participantIDs.isEmpty {
                    Section("분배 방식") {
                        Picker("분배 방식", selection: $customSplit) {
                            Text("더치페이(균등)").tag(false)
                            Text("직접 입력").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if customSplit {
                            ForEach(viewModel.members.filter { participantIDs.contains($0.id) }) { m in
                                HStack {
                                    MemberAvatarView(member: m, size: 24)
                                    Text(m.name)
                                    Spacer()
                                    TextField("0", text: bindingForCustom(m.id))
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 110)
                                    Text("원").foregroundStyle(Tokens.textSecondary)
                                }
                            }
                            let sum = customSum
                            HStack {
                                Text("합계")
                                Spacer()
                                Text("\(CurrencyFormatter.format(sum)) / \(CurrencyFormatter.format(amount))")
                                    .foregroundStyle(sum == amount ? Tokens.success : Tokens.danger)
                            }
                            .font(Typo.caption())
                            if sum != amount {
                                Text("부담금 합계가 총 금액과 일치해야 저장할 수 있어요.")
                                    .font(Typo.caption()).foregroundStyle(Tokens.danger)
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("각자 부담: \(CurrencyFormatter.format(perPerson))")
                                    .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                            }
                        }
                    }
                }

                Section("메모 (선택)") {
                    TextField("메모를 입력하세요", text: $memo, axis: .vertical)
                        .lineLimit(2...4)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("이 지출 삭제", systemImage: "trash")
                                Spacer()
                            }
                        }
                        .disabled(isWorking || isSettled)
                    } footer: {
                        if isSettled {
                            Text("정산 완료된 지출은 수정·삭제할 수 없습니다.")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "지출 수정" : "지출 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "수정" : "저장") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isWorking || isSettled)
                }
            }
            .confirmationDialog("이 지출을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { Task { await deleteExpense() } }
                Button("취소", role: .cancel) {}
            }
            .task {
                guard !didPrefill else { return }
                didPrefill = true
                if let e = editing {
                    amountText = NSDecimalNumber(decimal: e.amount).stringValue
                    title = e.title
                    date = e.date
                    paidByID = e.paidByMemberID
                    participantIDs = Set(e.participantMemberIDs)
                    category = e.category
                    memo = e.memo ?? ""
                    if let shares = e.customShares, !shares.isEmpty {
                        customSplit = true
                        customAmounts = Dictionary(uniqueKeysWithValues:
                            shares.map { ($0.key, NSDecimalNumber(decimal: $0.value).stringValue) })
                    }
                } else {
                    paidByID = viewModel.members.first?.id
                    participantIDs = Set(viewModel.members.map(\.id))
                }
            }
        }
    }

    private func bindingForCustom(_ id: UUID) -> Binding<String> {
        Binding(
            get: { customAmounts[id] ?? "" },
            set: { customAmounts[id] = $0.filter(\.isNumber) }
        )
    }

    private var customSum: Decimal {
        participantIDs.reduce(Decimal(0)) { $0 + (Decimal(string: customAmounts[$1] ?? "") ?? 0) }
    }

    private var builtCustomShares: [UUID: Decimal]? {
        guard customSplit else { return nil }
        var shares: [UUID: Decimal] = [:]
        for id in participantIDs { shares[id] = Decimal(string: customAmounts[id] ?? "") ?? 0 }
        return shares
    }

    private var canSave: Bool {
        amount > 0 &&
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        paidByID != nil &&
        !participantIDs.isEmpty &&
        (!customSplit || customSum == amount)
    }

    @MainActor
    private func save() async {
        guard let payer = paidByID else { return }
        isWorking = true
        defer { isWorking = false }
        let expense = Expense(
            id: editing?.id ?? UUID(),
            groupID: viewModel.groupID,
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            paidByMemberID: payer,
            participantMemberIDs: Array(participantIDs),
            date: date,
            isSettled: editing?.isSettled ?? false,
            category: category,
            memo: memo.isEmpty ? nil : memo,
            customShares: builtCustomShares
        )
        let ok = isEditing
            ? await viewModel.updateExpense(expense)
            : await viewModel.addExpense(expense)
        if ok {
            HapticManager.shared.success()
            dismiss()
        }
    }

    @MainActor
    private func deleteExpense() async {
        guard let id = editing?.id else { return }
        isWorking = true
        defer { isWorking = false }
        let ok = await viewModel.deleteExpense(id)
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
