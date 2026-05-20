//
//  ChoreRepositoryProtocol.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern, 2 P0 ② 가사 자동 로테이션
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

public protocol ChoreRepositoryProtocol: Sendable {
    /// 가사 생성 — 초기 currentAssigneeID 는 rotationMemberIDs.first.
    func createChore(
        groupID: UUID,
        title: String,
        icon: String,
        cycle: ChoreCycle,
        rotationMemberIDs: [UUID]
    ) async throws -> Chore

    /// 그룹 내 모든 가사.
    func fetchChores(groupID: UUID) async throws -> [Chore]

    /// 단일 가사.
    func fetchChore(id: UUID) async throws -> Chore

    /// 완료 체크 — 5초 취소 토스트 기간 동안은 isConfirmed=false 로 기록 후, 확정 시 true 로 승격.
    func recordCompletion(
        choreID: UUID,
        memberID: UUID,
        deviceIdentifier: String,
        isConfirmed: Bool
    ) async throws -> ChoreCompletion

    /// 5 초 내 취소 — 미확정(.isConfirmed == false) 완료 로그를 삭제하고 currentAssignee/nextDueDate 원복.
    func cancelCompletion(_ completionID: UUID) async throws

    /// 완료 확정 (5 초 경과 시 호출) → 다음 멤버로 로테이션.
    func confirmCompletion(_ completionID: UUID) async throws -> Chore

    /// 가사 1 개의 모든 완료 로그.
    func fetchCompletions(choreID: UUID) async throws -> [ChoreCompletion]

    /// 그룹 내 전체 완료 로그 (통계용, 기간 옵션).
    func fetchAllCompletions(groupID: UUID, since: Date?) async throws -> [ChoreCompletion]

    /// "오늘 못해요" 스왑 — 다음 차례 멤버와 currentAssignee 를 교환.
    func swapWithNext(choreID: UUID) async throws -> Chore

    /// 가사 삭제.
    func deleteChore(_ choreID: UUID) async throws
}
