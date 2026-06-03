//
//  InputValidator.swift
//  RoomieSync
//
//  사용자 입력 정규화/검증 — 과도한 길이·제어문자·공백 악용을 막아
//  저장 계층(SwiftData/Firestore)과 UI 의 안정성을 높인다.
//  작성자: 엄민욱 (2091188)
//

import Foundation

public enum InputValidator {

    public enum Limits {
        public static let name = 20          // 멤버/사용자 이름
        public static let groupName = 30
        public static let choreTitle = 40
        public static let expenseTitle = 40
        public static let memo = 300
        public static let accountNumber = 32
        public static let inviteCode = 6
    }

    /// 앞뒤 공백 제거 + 개행/제어문자 제거 + 최대 길이 절단.
    public static func clean(_ raw: String, max: Int) -> String {
        let noControl = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let collapsed = String(String.UnicodeScalarView(noControl))
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(max))
    }

    public static func name(_ raw: String) -> String { clean(raw, max: Limits.name) }
    public static func groupName(_ raw: String) -> String { clean(raw, max: Limits.groupName) }
    public static func choreTitle(_ raw: String) -> String { clean(raw, max: Limits.choreTitle) }
    public static func expenseTitle(_ raw: String) -> String { clean(raw, max: Limits.expenseTitle) }

    /// 메모는 개행 허용(제어문자 중 줄바꿈만 유지).
    public static func memo(_ raw: String) -> String {
        let allowed = raw.unicodeScalars.filter { c in
            !CharacterSet.controlCharacters.contains(c) || c == "\n" || c == "\r"
        }
        let s = String(String.UnicodeScalarView(allowed)).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(s.prefix(Limits.memo))
    }

    /// 계좌번호 — 숫자만, 최대 길이 절단.
    public static func accountNumber(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(Limits.accountNumber))
    }

    /// 초대 코드 정규화 — 대문자 영숫자만, 6자.
    public static func inviteCode(_ raw: String) -> String {
        let upper = raw.uppercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) && $0.isASCII
        }
        return String(String(String.UnicodeScalarView(upper)).prefix(Limits.inviteCode))
    }
}
