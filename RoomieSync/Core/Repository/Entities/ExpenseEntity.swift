//
//  ExpenseEntity.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 (SwiftData) — Expense
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import SwiftData

@Model
public final class ExpenseEntity {
    public var id: UUID = UUID()
    public var title: String = ""
    /// Decimal 은 SwiftData 가 NSDecimalNumber 로 보관. CloudKit 도 호환.
    public var amount: Decimal = 0
    public var paidByMemberID: UUID = UUID()
    /// [UUID] 직접 보관 — primitive array 는 SwiftData 가 지원하나, CloudKit 안정성 위해 JSON 화
    public var participantMemberIDsJSON: String = "[]"
    public var date: Date = Date()
    public var isSettled: Bool = false
    public var categoryRaw: String = ExpenseCategory.other.rawValue
    public var memo: String? = nil
    /// 참여자별 직접 부담금 — { uuidString: 금액문자열 } JSON. 빈 문자열이면 균등 분배(nil).
    public var customSharesJSON: String = ""
    /// 영수증 이미지 — Data 는 CloudKit 의 CKAsset 으로 자동 매핑됨
    @Attribute(.externalStorage)
    public var receiptImageData: Data? = nil

    @Relationship(deleteRule: .nullify)
    public var group: GroupEntity?

    public init(
        id: UUID = UUID(),
        title: String = "",
        amount: Decimal = 0,
        paidByMemberID: UUID = UUID(),
        participantMemberIDsJSON: String = "[]",
        date: Date = Date(),
        isSettled: Bool = false,
        categoryRaw: String = ExpenseCategory.other.rawValue,
        memo: String? = nil,
        receiptImageData: Data? = nil,
        group: GroupEntity? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.paidByMemberID = paidByMemberID
        self.participantMemberIDsJSON = participantMemberIDsJSON
        self.date = date
        self.isSettled = isSettled
        self.categoryRaw = categoryRaw
        self.memo = memo
        self.receiptImageData = receiptImageData
        self.group = group
    }
}

public extension ExpenseEntity {
    func toDomain() -> Expense {
        let participants: [UUID] = {
            guard let data = participantMemberIDsJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([UUID].self, from: data) else { return [] }
            return arr
        }()
        let category = ExpenseCategory(rawValue: categoryRaw) ?? .other
        return Expense(
            id: id,
            groupID: group?.id ?? UUID(),
            title: title,
            amount: amount,
            paidByMemberID: paidByMemberID,
            participantMemberIDs: participants,
            date: date,
            isSettled: isSettled,
            category: category,
            memo: memo,
            receiptImageData: receiptImageData,
            customShares: Self.decodeShares(customSharesJSON)
        )
    }

    static func decodeShares(_ json: String) -> [UUID: Decimal]? {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        var result: [UUID: Decimal] = [:]
        for (k, v) in raw {
            if let id = UUID(uuidString: k), let dec = Decimal(string: v) { result[id] = dec }
        }
        return result.isEmpty ? nil : result
    }

    static func encodeShares(_ shares: [UUID: Decimal]?) -> String {
        guard let shares, !shares.isEmpty else { return "" }
        let raw = Dictionary(uniqueKeysWithValues: shares.map { ($0.key.uuidString, NSDecimalNumber(decimal: $0.value).stringValue) })
        guard let data = try? JSONEncoder().encode(raw), let json = String(data: data, encoding: .utf8) else { return "" }
        return json
    }

    func apply(_ domain: Expense) {
        self.title = domain.title
        self.amount = domain.amount
        self.paidByMemberID = domain.paidByMemberID
        if let data = try? JSONEncoder().encode(domain.participantMemberIDs),
           let json = String(data: data, encoding: .utf8) {
            self.participantMemberIDsJSON = json
        }
        self.date = domain.date
        self.isSettled = domain.isSettled
        self.categoryRaw = domain.category.rawValue
        self.memo = domain.memo
        self.receiptImageData = domain.receiptImageData
        self.customSharesJSON = Self.encodeShares(domain.customShares)
    }
}
