//
//  PaymentRequest.swift
//  RoomieSync
//
//  '송금 요청' — 받을 돈이 있는 사람(fromMember)이 보낼 사람(toMember)에게 요청을 남긴다.
//  서버 푸시가 없으므로 Firestore 에 기록하고, 상대 앱이 동기화(앱 진입/새로고침)할 때
//  자기 앞으로 온 새 요청을 로컬 알림으로 띄운다.
//

import Foundation

public struct PaymentRequest: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var groupID: UUID
    public var fromMemberID: UUID   // 요청자(받을 사람)
    public var toMemberID: UUID     // 요청 대상(보낼 사람)
    public var fromName: String     // 요청자 이름(알림 표시용)
    public var amount: Decimal
    public var bankName: String?    // 요청자 입금 계좌
    public var accountNumber: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        groupID: UUID,
        fromMemberID: UUID,
        toMemberID: UUID,
        fromName: String,
        amount: Decimal,
        bankName: String? = nil,
        accountNumber: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.groupID = groupID
        self.fromMemberID = fromMemberID
        self.toMemberID = toMemberID
        self.fromName = fromName
        self.amount = amount
        self.bankName = bankName
        self.accountNumber = accountNumber
        self.createdAt = createdAt
    }
}
