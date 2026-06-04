//
//  BankAccountFormatter.swift
//  RoomieSync
//
//  선택한 은행 형식에 맞춰 계좌번호를 하이픈으로 분할해 '표시'한다.
//
//  주의: 한국 계좌번호는 은행/상품별로 자리수·구분이 제각각이라 아래 그룹은 '대표 형식' 근사치다.
//        저장·동기화되는 값은 항상 숫자만(InputValidator.accountNumber)이며, 하이픈은 화면 표시용이다.
//        따라서 그룹이 실제와 달라도 송금/저장에는 영향이 없다.
//

import Foundation

public enum BankAccountFormatter {

    /// 은행명 → 자리수 그룹(세그먼트 길이). nil 이면 하이픈 없이 숫자만 표시.
    static func groups(for bank: String) -> [Int]? {
        switch bank {
        case "카카오뱅크":  return [4, 2, 7]
        case "토스뱅크":    return [4, 4, 4]
        case "케이뱅크":    return [3, 3, 6]
        case "국민":        return [6, 2, 6]
        case "신한":        return [3, 3, 6]
        case "우리":        return [4, 3, 6]
        case "하나":        return [3, 6, 5]
        case "농협":        return [3, 4, 4, 2]
        case "기업":        return [3, 6, 2, 3]
        case "SC제일":      return [3, 2, 6]
        case "씨티":        return [3, 3, 4]
        case "산업":        return [3, 6, 2]
        case "수협":        return [3, 4, 4]
        case "부산":        return [3, 4, 4]
        case "대구":        return [3, 3, 6]
        case "경남":        return [3, 4, 4]
        case "광주":        return [3, 3, 6]
        case "전북":        return [3, 2, 6]
        case "제주":        return [3, 3, 6]
        case "새마을금고":  return [4, 4, 4]
        case "신협":        return [4, 4, 4]
        case "우체국":      return [6, 2, 6]
        default:           return nil
        }
    }

    /// 입력값(숫자/하이픈 혼재 가능)을 은행 형식대로 하이픈 분할해 반환한다.
    /// - 아직 다음 그룹 자리가 입력되지 않으면 끝에 하이픈을 붙이지 않는다(타이핑·삭제 시 자연스럽게 갱신).
    /// - 정의된 그룹 합계를 넘는 자리는 마지막에 한 덩어리로 이어 붙인다(자리수 가변 대응).
    /// - 은행 미선택/미정의면 숫자만 반환(하이픈 없음 → 지우면 원상복구).
    public static func format(_ input: String, bank: String) -> String {
        let digits = String(input.filter(\.isNumber))
        guard !digits.isEmpty, let groups = groups(for: bank) else { return digits }

        var segments: [String] = []
        var idx = digits.startIndex
        var remaining = digits.count
        for (i, len) in groups.enumerated() {
            guard remaining > 0 else { break }
            let take = min(len, remaining)
            let end = digits.index(idx, offsetBy: take)
            segments.append(String(digits[idx..<end]))
            idx = end
            remaining -= take
            if i == groups.count - 1, remaining > 0 {   // 마지막 그룹 초과분
                segments.append(String(digits[idx...]))
                remaining = 0
            }
        }
        return segments.joined(separator: "-")
    }
}
