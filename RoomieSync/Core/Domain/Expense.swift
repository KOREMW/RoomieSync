//
//  Expense.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 — Expense, 6.1 #5 지출 발생
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation

/// 공동 지출 1 건. 시안 ③ 공동 지출 목록 카드 1 줄과 1:1 매핑.
public struct Expense: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var groupID: UUID
    public var title: String                // 예: "휴지 12롤"
    public var amount: Decimal              // KRW 원 단위 (소수점 없음)
    public var paidByMemberID: UUID
    public var participantMemberIDs: [UUID] // 결제자 본인 포함 가능
    public var date: Date
    public var isSettled: Bool
    public var category: ExpenseCategory    // 시안 ⑤ 도넛 차트용
    public var memo: String?
    public var receiptImageData: Data?      // 시안 ④ 영수증 첨부 (선택)
    /// 직접 입력한 참여자별 부담금. nil 이면 균등 분배(더치페이).
    public var customShares: [UUID: Decimal]?

    public init(
        id: UUID = UUID(),
        groupID: UUID,
        title: String,
        amount: Decimal,
        paidByMemberID: UUID,
        participantMemberIDs: [UUID],
        date: Date = .now,
        isSettled: Bool = false,
        category: ExpenseCategory = .other,
        memo: String? = nil,
        receiptImageData: Data? = nil,
        customShares: [UUID: Decimal]? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.amount = amount
        self.paidByMemberID = paidByMemberID
        self.participantMemberIDs = participantMemberIDs
        self.date = date
        self.isSettled = isSettled
        self.category = category
        self.memo = memo
        self.receiptImageData = receiptImageData
        self.customShares = customShares
    }

    /// 1 인당 부담액 (균등 분배). 시안 ④ "각자 부담: 3,300원" 표시.
    public var amountPerParticipant: Decimal {
        guard !participantMemberIDs.isEmpty else { return 0 }
        return amount / Decimal(participantMemberIDs.count)
    }

    /// 특정 멤버의 부담금 — 직접 입력값이 있으면 그 값, 없으면 균등 분배.
    public func share(for memberID: UUID) -> Decimal {
        if let custom = customShares?[memberID] { return custom }
        return amountPerParticipant
    }
}

/// 지출 카테고리. 통계 화면 (시안 ⑤) 도넛 차트의 색상/라벨과 매칭.
public enum ExpenseCategory: String, Hashable, Sendable, Codable, CaseIterable {
    case food          // 식비 — 시안 35%
    case household     // 생활용품 — 시안 28%
    case utility       // 공과금 — 시안 25%
    case other         // 기타 — 시안 12%

    public var displayName: String {
        switch self {
        case .food:      return "식비"
        case .household: return "생활용품"
        case .utility:   return "공과금"
        case .other:     return "기타"
        }
    }

    /// SF Symbol 이름 — 시안 ③ 좌측 아이콘
    public var sfSymbolName: String {
        switch self {
        case .food:      return "fork.knife"
        case .household: return "bubbles.and.sparkles.fill"
        case .utility:   return "bolt.fill"
        case .other:     return "cart.fill"
        }
    }
}
