//
//  ConflictResolver.swift
//  RoomieSync
//
//  계획서 참조: 6.3 엣지 케이스 (오프라인 / last-write-wins), 6.4 CloudKit 동기화 충돌 테스트
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//
//  CloudKit 통합 자체는 3주차에 수행. 충돌 해결 정책은 순수 함수로 분리하여
//  1주차에 결정적 단위 테스트 (ConflictResolverTests) 대상으로 삼는다.
//

import Foundation

public enum ConflictResolver {

    /// last-write-wins 정책.
    /// 1) completedAt 이 더 늦은 쪽 채택
    /// 2) 동일 timestamp 면 deviceIdentifier 사전순 (결정적 tie-break)
    public static func resolve(
        local: ChoreCompletion,
        remote: ChoreCompletion
    ) -> ChoreCompletion {
        if local.completedAt != remote.completedAt {
            return local.completedAt > remote.completedAt ? local : remote
        }
        return local.deviceIdentifier > remote.deviceIdentifier ? local : remote
    }

    /// Expense 충돌 — amount/title 등 모든 필드 last-write-wins 기준은 date.
    /// 정산 완료 (isSettled=true) 가 한 쪽에라도 있으면 그쪽이 우선 (감사 추적성 보호).
    public static func resolve(
        local: Expense,
        remote: Expense
    ) -> Expense {
        if local.isSettled != remote.isSettled {
            return local.isSettled ? local : remote
        }
        return local.date >= remote.date ? local : remote
    }
}
