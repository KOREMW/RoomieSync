//
//  FirestoreChoreRepository.swift
//  RoomieSync
//
//  ChoreRepositoryProtocol 의 Cloud Firestore 구현 (최상위 평면 컬렉션).
//  chores/{id} · choreCompletions/{id} (groupID·choreID 필드 보유).
//  by-id 는 document(id) 직접 접근, 그룹/가사별 조회는 단일 필드 whereField 만 사용.
//  로테이션/스왑은 기존 ChoreRotation 순수 함수 재사용.
//

#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore

public actor FirestoreChoreRepository: ChoreRepositoryProtocol {
    private let db = Firestore.firestore()
    private var choresCol: CollectionReference { db.collection("chores") }
    private var completionsCol: CollectionReference { db.collection("choreCompletions") }

    public init() {}

    public func createChore(
        groupID: UUID,
        title: String,
        icon: String,
        cycle: ChoreCycle,
        weekdays: [Int],
        anchorDate: Date?,
        rotationMemberIDs: [UUID]
    ) async throws -> Chore {
        guard let first = rotationMemberIDs.first else {
            throw RepositoryError.invalidInput(reason: "로테이션 멤버가 0명입니다")
        }
        let due = (cycle == .once || cycle == .monthly) ? (anchorDate ?? .now) : nextDate(from: .now, cycle: cycle)
        let chore = Chore(groupID: groupID, title: title, icon: icon, cycleType: cycle,
                          currentAssigneeID: first, nextDueDate: due,
                          rotationMemberIDs: rotationMemberIDs, weekdays: weekdays, anchorDate: anchorDate)
        try await choresCol.document(chore.id.uuidString).setData(chore.fsDict)
        return chore
    }

    public func updateChore(_ chore: Chore) async throws -> Chore {
        let ref = choresCol.document(chore.id.uuidString)
        let doc = try await ref.getDocument()
        guard doc.exists else { throw RepositoryError.notFound }
        try await ref.setData(chore.fsDict)
        return chore
    }

    public func fetchChores(groupID: UUID) async throws -> [Chore] {
        let snap = try await choresCol.whereField("groupID", isEqualTo: groupID.uuidString).getDocuments()
        return snap.documents.compactMap { Chore(fs: $0.data()) }.sorted { $0.title < $1.title }
    }

    public func fetchChore(id: UUID) async throws -> Chore {
        let doc = try await choresCol.document(id.uuidString).getDocument()
        guard let data = doc.data(), let chore = Chore(fs: data) else { throw RepositoryError.notFound }
        return chore
    }

    public func recordCompletion(
        choreID: UUID,
        memberID: UUID,
        deviceIdentifier: String,
        isConfirmed: Bool
    ) async throws -> ChoreCompletion {
        let chore = try await fetchChore(id: choreID)
        let completion = ChoreCompletion(choreID: choreID, memberID: memberID,
                                         isConfirmed: isConfirmed, deviceIdentifier: deviceIdentifier)
        var dict = completion.fsDict
        dict["groupID"] = chore.groupID.uuidString   // 그룹별 통계 조회용
        try await completionsCol.document(completion.id.uuidString).setData(dict)
        return completion
    }

    public func cancelCompletion(_ completionID: UUID) async throws {
        let ref = completionsCol.document(completionID.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(), let completion = ChoreCompletion(fs: data) else {
            throw RepositoryError.notFound
        }
        guard !completion.isConfirmed else {
            throw RepositoryError.invalidInput(reason: "이미 확정된 완료는 취소할 수 없습니다")
        }
        try await ref.delete()
    }

    public func confirmCompletion(_ completionID: UUID) async throws -> Chore {
        let compRef = completionsCol.document(completionID.uuidString)
        let compDoc = try await compRef.getDocument()
        guard let cdata = compDoc.data(), let completion = ChoreCompletion(fs: cdata) else {
            throw RepositoryError.notFound
        }
        try await compRef.updateData(["isConfirmed": true])
        let chore = try await fetchChore(id: completion.choreID)
        let rotated = ChoreRotation.rotateToNext(chore)
        try await choresCol.document(rotated.id.uuidString).setData(rotated.fsDict)
        return rotated
    }

    public func fetchCompletions(choreID: UUID) async throws -> [ChoreCompletion] {
        let snap = try await completionsCol.whereField("choreID", isEqualTo: choreID.uuidString).getDocuments()
        return snap.documents.compactMap { ChoreCompletion(fs: $0.data()) }
            .filter { $0.isConfirmed }
            .sorted { $0.completedAt > $1.completedAt }
    }

    public func fetchAllCompletions(groupID: UUID, since: Date?) async throws -> [ChoreCompletion] {
        let snap = try await completionsCol.whereField("groupID", isEqualTo: groupID.uuidString).getDocuments()
        var items = snap.documents.compactMap { ChoreCompletion(fs: $0.data()) }.filter { $0.isConfirmed }
        if let since { items = items.filter { $0.completedAt >= since } }
        return items.sorted { $0.completedAt > $1.completedAt }
    }

    public func swapWithNext(choreID: UUID) async throws -> Chore {
        let chore = try await fetchChore(id: choreID)
        let swapped = ChoreRotation.swapCurrentWithNext(chore)
        try await choresCol.document(swapped.id.uuidString).setData(swapped.fsDict)
        return swapped
    }

    public func deleteChore(_ choreID: UUID) async throws {
        try await choresCol.document(choreID.uuidString).delete()
    }

    // MARK: - Private

    private func nextDate(from base: Date, cycle: ChoreCycle) -> Date {
        Calendar.current.date(byAdding: .day, value: cycle.approximateIntervalDays, to: base) ?? base
    }
}
#endif
