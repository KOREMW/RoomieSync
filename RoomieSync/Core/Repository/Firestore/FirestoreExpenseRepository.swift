//
//  FirestoreExpenseRepository.swift
//  RoomieSync
//
//  ExpenseRepositoryProtocol 의 Cloud Firestore 구현 (최상위 평면 컬렉션).
//  expenses/{id} · settlements/{id} (groupID 필드 보유).
//  검증 규칙(정산 완료 후 수정/삭제 금지 등)은 SwiftData 구현과 동일.
//

#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

public actor FirestoreExpenseRepository: ExpenseRepositoryProtocol {
    private let db = Firestore.firestore()
    private var expensesCol: CollectionReference { db.collection("expenses") }
    private var settlementsCol: CollectionReference { db.collection("settlements") }

    public init() {}

    public func createExpense(_ expense: Expense) async throws -> Expense {
        await FirebaseAuthGate.shared.ensureSignedIn()
        guard expense.amount > 0 else {
            throw RepositoryError.invalidInput(reason: "금액은 0원보다 커야 합니다")
        }
        guard !expense.participantMemberIDs.isEmpty else {
            throw RepositoryError.invalidInput(reason: "참여자가 1명 이상이어야 합니다")
        }
        try await expensesCol.document(expense.id.uuidString).setData(expense.fsDict)
        return expense
    }

    public func fetchExpenses(groupID: UUID, includeSettled: Bool) async throws -> [Expense] {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let snap = try await expensesCol.whereField("groupID", isEqualTo: groupID.uuidString).getDocuments()
        var items = snap.documents.compactMap { Expense(fs: $0.data()) }
        if !includeSettled { items = items.filter { !$0.isSettled } }
        return items.sorted { $0.date > $1.date }
    }

    public func fetchExpense(id: UUID) async throws -> Expense {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let doc = try await expensesCol.document(id.uuidString).getDocument()
        guard let data = doc.data(), let expense = Expense(fs: data) else { throw RepositoryError.notFound }
        return expense
    }

    public func updateExpense(_ expense: Expense) async throws -> Expense {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let ref = expensesCol.document(expense.id.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), let existing = Expense(fs: data) else { throw RepositoryError.notFound }
        guard !existing.isSettled else {
            throw RepositoryError.invalidInput(reason: "정산 완료된 지출은 수정할 수 없습니다")
        }
        try await ref.setData(expense.fsDict)
        return expense
    }

    public func deleteExpense(_ expenseID: UUID) async throws {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let ref = expensesCol.document(expenseID.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), let existing = Expense(fs: data) else { throw RepositoryError.notFound }
        guard !existing.isSettled else {
            throw RepositoryError.invalidInput(reason: "정산 완료된 지출은 삭제할 수 없습니다")
        }
        try await ref.delete()
    }

    public func markSettled(_ expenseIDs: [UUID]) async throws {
        await FirebaseAuthGate.shared.ensureSignedIn()
        for id in expenseIDs {
            try await expensesCol.document(id.uuidString).updateData(["isSettled": true])
        }
    }

    public func saveSettlements(_ settlements: [Settlement]) async throws {
        await FirebaseAuthGate.shared.ensureSignedIn()
        for settlement in settlements {
            try await settlementsCol.document(settlement.id.uuidString).setData(settlement.fsDict)
        }
    }

    public func fetchSettlements(groupID: UUID, onlyPending: Bool) async throws -> [Settlement] {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let snap = try await settlementsCol.whereField("groupID", isEqualTo: groupID.uuidString).getDocuments()
        var items = snap.documents.compactMap { Settlement(fs: $0.data()) }
        if onlyPending { items = items.filter { $0.settledAt == nil } }
        return items
    }

    public func markSettlementCompleted(_ settlementID: UUID, at date: Date) async throws {
        await FirebaseAuthGate.shared.ensureSignedIn()
        let ref = settlementsCol.document(settlementID.uuidString)
        let doc = try await ref.getDocument()
        guard doc.exists else { throw RepositoryError.notFound }
        try await ref.updateData(["settledAt": FSMap.epoch(date)])
    }
}
#endif
