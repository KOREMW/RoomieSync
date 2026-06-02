//
//  FirestoreChoreRepository.swift
//  RoomieSync
//
//  ChoreRepositoryProtocol 의 Cloud Firestore 구현.
//  로테이션/스왑 로직은 기존 ChoreRotation 순수 함수를 그대로 재사용해 SwiftData 구현과 동일하게 동작.
//  자식 id 만 받는 메서드는 collectionGroup 쿼리로 문서 위치를 찾는다.
//
//  주의: collectionGroup + 다중 필터는 복합 인덱스를 요구할 수 있어, isConfirmed/기간 필터는 메모리에서 처리.
//

#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

public actor FirestoreChoreRepository: ChoreRepositoryProtocol {
    private let db = Firestore.firestore()
    private var groups: CollectionReference { db.collection("groups") }

    public init() {}

    public func createChore(
        groupID: UUID,
        title: String,
        icon: String,
        cycle: ChoreCycle,
        rotationMemberIDs: [UUID]
    ) async throws -> Chore {
        guard let first = rotationMemberIDs.first else {
            throw RepositoryError.invalidInput(reason: "로테이션 멤버가 0명입니다")
        }
        let chore = Chore(groupID: groupID, title: title, icon: icon, cycleType: cycle,
                          currentAssigneeID: first, nextDueDate: nextDate(from: .now, cycle: cycle),
                          rotationMemberIDs: rotationMemberIDs)
        try await groups.document(groupID.uuidString)
            .collection("chores").document(chore.id.uuidString)
            .setData(chore.fsDict)
        return chore
    }

    public func fetchChores(groupID: UUID) async throws -> [Chore] {
        let snap = try await groups.document(groupID.uuidString).collection("chores").getDocuments()
        return snap.documents.compactMap { Chore(fs: $0.data()) }.sorted { $0.title < $1.title }
    }

    public func fetchChore(id: UUID) async throws -> Chore {
        try await choreDoc(id: id).1
    }

    public func recordCompletion(
        choreID: UUID,
        memberID: UUID,
        deviceIdentifier: String,
        isConfirmed: Bool
    ) async throws -> ChoreCompletion {
        let (_, chore) = try await choreDoc(id: choreID)
        let completion = ChoreCompletion(choreID: choreID, memberID: memberID,
                                         isConfirmed: isConfirmed, deviceIdentifier: deviceIdentifier)
        try await groups.document(chore.groupID.uuidString)
            .collection("choreCompletions").document(completion.id.uuidString)
            .setData(completion.fsDict)
        return completion
    }

    public func cancelCompletion(_ completionID: UUID) async throws {
        let (ref, completion) = try await completionDoc(id: completionID)
        guard !completion.isConfirmed else {
            throw RepositoryError.invalidInput(reason: "이미 확정된 완료는 취소할 수 없습니다")
        }
        try await ref.delete()
    }

    public func confirmCompletion(_ completionID: UUID) async throws -> Chore {
        let (compRef, completion) = try await completionDoc(id: completionID)
        try await compRef.updateData(["isConfirmed": true])
        let (choreRef, chore) = try await choreDoc(id: completion.choreID)
        let rotated = ChoreRotation.rotateToNext(chore)
        try await choreRef.setData(rotated.fsDict)
        return rotated
    }

    public func fetchCompletions(choreID: UUID) async throws -> [ChoreCompletion] {
        let snap = try await db.collectionGroup("choreCompletions")
            .whereField("choreID", isEqualTo: choreID.uuidString)
            .getDocuments()
        return snap.documents.compactMap { ChoreCompletion(fs: $0.data()) }
            .filter { $0.isConfirmed }
            .sorted { $0.completedAt > $1.completedAt }
    }

    public func fetchAllCompletions(groupID: UUID, since: Date?) async throws -> [ChoreCompletion] {
        let snap = try await groups.document(groupID.uuidString).collection("choreCompletions").getDocuments()
        var items = snap.documents.compactMap { ChoreCompletion(fs: $0.data()) }.filter { $0.isConfirmed }
        if let since { items = items.filter { $0.completedAt >= since } }
        return items.sorted { $0.completedAt > $1.completedAt }
    }

    public func swapWithNext(choreID: UUID) async throws -> Chore {
        let (ref, chore) = try await choreDoc(id: choreID)
        let swapped = ChoreRotation.swapCurrentWithNext(chore)
        try await ref.setData(swapped.fsDict)
        return swapped
    }

    public func deleteChore(_ choreID: UUID) async throws {
        let (ref, _) = try await choreDoc(id: choreID)
        try await ref.delete()
    }

    // MARK: - Private

    private func choreDoc(id: UUID) async throws -> (DocumentReference, Chore) {
        let snap = try await db.collectionGroup("chores")
            .whereField("id", isEqualTo: id.uuidString)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first, let chore = Chore(fs: doc.data()) else {
            throw RepositoryError.notFound
        }
        return (doc.reference, chore)
    }

    private func completionDoc(id: UUID) async throws -> (DocumentReference, ChoreCompletion) {
        let snap = try await db.collectionGroup("choreCompletions")
            .whereField("id", isEqualTo: id.uuidString)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first, let completion = ChoreCompletion(fs: doc.data()) else {
            throw RepositoryError.notFound
        }
        return (doc.reference, completion)
    }

    private func nextDate(from base: Date, cycle: ChoreCycle) -> Date {
        Calendar.current.date(byAdding: .day, value: cycle.approximateIntervalDays, to: base) ?? base
    }
}
#endif
