//
//  CKErrorMapper.swift
//  RoomieSync
//
//  계획서 참조: 6.3 엣지 케이스 — CKError 핸들링 (network, quota 등)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//

import Foundation
import CloudKit

public enum CKErrorMapper {

    /// CKError 또는 일반 Error → 우리 RepositoryError 로 변환.
    public static func map(_ error: Error) -> RepositoryError {
        let ckError = error as? CKError ?? CKError(.internalError)

        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .serverRecordChanged, .changeTokenExpired, .batchRequestFailed:
            return .conflict(message: "서버 데이터가 변경되었습니다. 다시 시도해주세요.")
        case .notAuthenticated:
            return .invalidInput(reason: "iCloud 로그인이 필요합니다. (설정 → Apple ID)")
        case .permissionFailure:
            return .invalidInput(reason: "iCloud 권한이 거부되었습니다.")
        case .partialFailure:
            // partialFailure 의 내부 dict 에서 첫 에러만 추출
            if let dict = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
               let first = dict.values.first {
                return map(first)
            }
            return .persistenceFailure(underlying: ckError.localizedDescription)
        default:
            return .persistenceFailure(underlying: ckError.localizedDescription)
        }
    }

    /// 사용자에게 보여줄 친화 메시지.
    public static func userMessage(for error: RepositoryError) -> String {
        switch error {
        case .networkUnavailable:   return "인터넷에 연결되어 있지 않아요. 잠시 후 다시 시도해주세요."
        case .quotaExceeded:        return "iCloud 저장 공간이 부족해요. 영수증 이미지를 삭제해보세요."
        case .conflict(let m):      return m
        case .notFound:             return "데이터를 찾을 수 없어요."
        case .invalidInput(let r):  return r
        case .duplicate(let f):     return "중복된 \(f) 입니다."
        case .persistenceFailure:   return "저장에 실패했어요. 잠시 후 다시 시도해주세요."
        }
    }

    /// 일반 Error → 친화 메시지 (RepositoryError 로 변환 후 위임).
    public static func userMessage(for error: Error) -> String {
        if let repoError = error as? RepositoryError {
            return userMessage(for: repoError)
        }
        return userMessage(for: map(error))
    }
}
