//
//  RepositoryError.swift
//  RoomieSync
//
//  계획서 참조: 3.1 Repository Pattern, 6.3 엣지 케이스 (오프라인/충돌)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

/// Repository 계층에서 발생할 수 있는 오류.
/// CloudKit 충돌·네트워크·쿼터 등은 3주차 NotificationService 가 매핑.
public enum RepositoryError: Error, Equatable, Sendable {
    case notFound
    case invalidInput(reason: String)
    case duplicate(field: String)
    case persistenceFailure(underlying: String)
    case networkUnavailable
    case quotaExceeded
    case conflict(message: String)
}
