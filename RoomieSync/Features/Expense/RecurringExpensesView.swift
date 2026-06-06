//
//  RecurringExpensesView.swift
//  RoomieSync
//
//  반복 지출 템플릿 관리(#8). 매월 자동 생성될 고정 지출을 등록/삭제한다.
//  템플릿은 기기 로컬에 저장되며, 생성된 지출은 지출 탭에 동기화된다.
//

import SwiftUI

struct RecurringExpensesView: View {
    let groupID: UUID
    @Environment(\.repositories) private var repositories

    @State private var templates: [ExpenseTemplate] = []
    @State private var members: [Member] = []
    @State private var myMemberID: UUID? = nil
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                Text("매월 지정한 날짜에 자동으로 지출이 등록됩니다. (예: 관리비 매월 25일)\n템플릿은 이 기기에 저장돼 중복 생성되지 않아요.")
                    .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
            }
            if templates.isEmpty {
                Section {
                    Text("등록된 반복 지출이 없어요.")
                        .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                }
            } else {
                Section("반복 지출") {
                    ForEach(templates) { t in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: t.category.sfSymbolName).foregroundStyle(Tokens.primary)
                                Text(t.title).font(Typo.bodyBold())
                                Spacer()
                                Text(CurrencyFormatter.format(t.amount)).font(Typo.bodyBold())
                            }
                            Text("매월 \(t.dayOfMonth)일 · \(payerName(t.paidByMemberID)) 결제 · \(t.participantMemberIDs.count)명 참여")
                                .font(Typo.caption()).foregroundStyle(Tokens.textSecondary)
                        }
                    }
                    .onDelete(perform: deleteTemplates)
                }
            }
        }
        .navigationTitle("반복 지출")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .disabled(members.isEmpty)
            }
        }
        .sheet(isPresented: $showAdd) {
            RecurringExpenseAddSheet(groupID: groupID, members: members,
                                     defaultPayer: myMemberID) { newTemplate in
                templates.append(newTemplate)
                ExpenseTemplateStore.save(groupID, templates)
            }
        }
        .task { await load() }
    }

    private func payerName(_ id: UUID) -> String { members.first { $0.id == id }?.name ?? "?" }

    private func deleteTemplates(_ offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        ExpenseTemplateStore.save(groupID, templates)
    }

    @MainActor
    private func load() async {
        members = (try? await repositories.group.fetchMembers(ofGroup: groupID)) ?? []
        myMemberID = CurrentMemberStore.resolve(members, groupID: groupID)?.id
        templates = ExpenseTemplateStore.load(groupID)
    }
}

private struct RecurringExpenseAddSheet: View {
    let groupID: UUID
    let members: [Member]
    let defaultPayer: UUID?
    let onAdd: (ExpenseTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .utility
    @State private var dayOfMonth = 25
    @State private var payerID: UUID?
    @State private var participants: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("항목") {
                    TextField("예: 관리비", text: $title)
                }
                Section("금액") {
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .onChange(of: amountText) { _, v in
                            let digits = v.filter(\.isNumber)
                            if digits != v { amountText = digits }
                        }
                }
                Section("카테고리") {
                    Picker("카테고리", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { c in
                            Label(c.displayName, systemImage: c.sfSymbolName).tag(c)
                        }
                    }
                }
                Section("매월 결제일") {
                    Picker("일", selection: $dayOfMonth) {
                        ForEach(1...31, id: \.self) { d in Text("\(d)일").tag(d) }
                    }
                }
                Section("결제자") {
                    Picker("결제자", selection: $payerID) {
                        ForEach(members) { m in Text(m.name).tag(Optional(m.id)) }
                    }
                }
                Section("참여자") {
                    ForEach(members) { m in
                        Button {
                            if participants.contains(m.id) { participants.remove(m.id) }
                            else { participants.insert(m.id) }
                        } label: {
                            HStack {
                                Text(m.name).foregroundStyle(Tokens.textPrimary)
                                Spacer()
                                if participants.contains(m.id) {
                                    Image(systemName: "checkmark").foregroundStyle(Tokens.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("반복 지출 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { add() }.disabled(!canSave)
                }
            }
            .onAppear {
                if payerID == nil { payerID = defaultPayer ?? members.first?.id }
                if participants.isEmpty { participants = Set(members.map(\.id)) }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && (Decimal(string: amountText) ?? 0) > 0
            && payerID != nil
            && !participants.isEmpty
    }

    private func add() {
        guard let payer = payerID, let amount = Decimal(string: amountText), amount > 0 else { return }
        let template = ExpenseTemplate(
            groupID: groupID,
            title: InputValidator.expenseTitle(title),
            amount: amount,
            category: category,
            dayOfMonth: dayOfMonth,
            paidByMemberID: payer,
            participantMemberIDs: Array(participants)
        )
        onAdd(template)
        dismiss()
    }
}
