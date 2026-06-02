//
//  FirestoreExpenseRepository.swift
//  RoomieSync
//
//  ExpenseRepositoryProtocol 의 Cloud Firestore 구현.
//  expenses/settlements 는 groups/{groupId} 하위 컬렉션. 검증 규칙(정산 완료 후 수정/삭제 금지 등)은
//  SwiftData 구현과 동일하게 맞춘다.
//

#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

public actor FirestoreExpenseRepository: ExpenseRepositoryProtocol {
    private let db = Firestore.firestore()
    private var groups: CollectionReference { db.collection("groups") }

    public init() {}

    public func createExpense(_ expense: Expense) async throws -> Expense {
        guard expense.amount > 0 else {
            throw RepositoryError.invalidInput(reason: "금액은 0원보다 커야 합니다")
        }
        guard !expense.participantMemberIDs.isEmpty else {
            throw RepositoryError.invalidInput(reason: "참여자가 1명 이상이어야 합니다")
        }
        try await expenseRef(groupID: expense.groupID, id: expense.id).setData(expense.fsDict)
        return expense
    }

    public func fetchExpenses(groupID: UUID, includeSettled: Bool) async throws -> [Expense] {
        let snap = try await groups.document(groupID.uuidString).collection("expenses").getDocuments()
        var items = snap.documents.compactMap { Expense(fs: $0.data()) }
        if !includeSettled { items = items.filter { !$0.isSettled } }
        return items.sorted { $0.date > $1.date }
    }

    public func fetchExpense(id: UUID) async throws -> Expense {
        try await expenseDoc(id: id).1
    }

    public func updateExpense(_ expense: Expense) async throws -> Expense {
        let ref = expenseRef(groupID: expense.groupID, id: expense.id)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), let existing = Expense(fs: data) else { throw RepositoryError.notFound }
        guard !existing.isSettled else {
            throw RepositoryError.invalidInput(reason: "정산 완료된 지출은 수정할 수 없습니다")
        }
        try await ref.setData(expense.fsDict)
        return expense
    }

    public func deleteExpense(_ expenseID: UUID) async throws {
        let (ref, existing) = try await expenseDoc(id: expenseID)
        guard !existing.isSettled else {
            throw RepositoryError.invalidInput(reason: "정산 완료된 지출은 삭제할 수 없습니다")
        }
        try await ref.delete()
    }

    public func markSettled(_ expenseIDs: [UUID]) async throws {
        for id in expenseIDs {
            let (ref, _) = try await expenseDoc(id: id)
            try await ref.updateData(["isSettled": true])
        }
    }

    public func saveSettlements(_ settlements: [Settlement]) async throws {
        for settlement in settlements {
            try await groups.document(settlement.groupID.uuidString)
                .collection("settlements").document(settlement.id.uuidString)
                .setData(settlement.fsDict)
        }
    }

    public func fetchSettlements(groupID: UUID, onlyPending: Bool) async throws -> [Settlement] {
        let snap = try await groups.document(groupID.uuidString).collection("settlements").getDocuments()
        var items = snap.documents.compactMap { Settlement(fs: $0.data()) }
        if onlyPending { items = items.filter { $0.settledAt == nil } }
        return items
    }

    public func markSettlementCompleted(_ settlementID: UUID, at date: Date) async throws {
        let snap = try await db.collectionGroup("settlements")
            .whereField("id", isEqualTo: settlementID.uuidString)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first else { throw RepositoryError.notFound }
        try await doc.reference.updateData(["settledAt": FSMap.epoch(date)])
    }

    // MARK: - Private

    private func expenseRef(groupID: UUID, id: UUID) -> DocumentReference {
        groups.document(groupID.uuidString).collection("expenses").document(id.uuidString)
    }

    private func expenseDoc(id: UUID) async throws -> (DocumentReference, Expense) {
        let snap = try await db.collectionGroup("expenses")
            .whereField("id", isEqualTo: id.uuidString)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first, let expense = Expense(fs: doc.data()) else {
            throw RepositoryError.notFound
        }
        return (doc.reference, expense)
    }
}
#endif
