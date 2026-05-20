//
//  GroupRepositoryProtocol.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern, 2 P0 ① 그룹 생성·초대
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

public protocol GroupRepositoryProtocol: Sendable {
    /// 그룹 생성 — 호스트 멤버 1 명 자동 포함.
    func createGroup(name: String, hostName: String, hostAvatarColorHex: String) async throws -> Group

    /// 초대 코드로 그룹 조회.
    func findGroup(byInviteCode code: String) async throws -> Group

    /// 그룹 단일 조회.
    func fetchGroup(id: UUID) async throws -> Group

    /// 그룹에 멤버 추가 — 최대 6 명 (계획서 2 P0 ①).
    func addMember(toGroup groupID: UUID, name: String, avatarColorHex: String) async throws -> Member

    /// 그룹 내 멤버 전체.
    func fetchMembers(ofGroup groupID: UUID) async throws -> [Member]

    /// 멤버 제거 — 미정산 잔액 검증은 호출자(use-case) 책임.
    func removeMember(_ memberID: UUID) async throws

    /// 그룹 삭제.
    func deleteGroup(_ groupID: UUID) async throws

    /// 현재 사용자가 속한 모든 그룹 — 멀티 그룹 지원 (시안 ⑤ 통계 셀렉터 대비).
    func fetchAllGroups() async throws -> [Group]
}
