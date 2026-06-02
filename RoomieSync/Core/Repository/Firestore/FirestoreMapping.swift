//
//  FirestoreMapping.swift
//  RoomieSync
//
//  도메인 모델 ↔ Firestore 문서([String: Any]) 변환.
//  Firebase SDK 에 의존하지 않도록 Foundation 만 사용한다:
//   - 날짜는 epoch(TimeInterval, Double)로 저장/복원 (Firestore Timestamp 비의존)
//   - 금액 Decimal 은 Double 로 저장 (KRW 정수 범위 안전)
//   - UUID 는 uuidString 으로 저장
//   - 영수증 이미지(Data)는 문서 1MB 제한 때문에 동기화하지 않음 (PoC)
//

import Foundation

enum FSMap {
    // MARK: 디코딩 (Firestore 값 → Swift)
    static func str(_ v: Any?) -> String? { v as? String }
    static func uuid(_ v: Any?) -> UUID? { (v as? String).flatMap(UUID.init(uuidString:)) }
    static func bool(_ v: Any?) -> Bool { (v as? Bool) ?? false }
    static func date(_ v: Any?) -> Date? {
        if let t = v as? Double { return Date(timeIntervalSince1970: t) }
        if let n = v as? NSNumber { return Date(timeIntervalSince1970: n.doubleValue) }
        return nil
    }
    static func decimal(_ v: Any?) -> Decimal {
        if let n = v as? NSNumber { return n.decimalValue }
        if let d = v as? Double { return Decimal(d) }
        if let i = v as? Int { return Decimal(i) }
        return 0
    }
    static func uuids(_ v: Any?) -> [UUID] { (v as? [String])?.compactMap(UUID.init(uuidString:)) ?? [] }

    // MARK: 인코딩 헬퍼 (Swift → Firestore 값)
    static func ids(_ ids: [UUID]) -> [String] { ids.map(\.uuidString) }
    static func epoch(_ d: Date) -> Double { d.timeIntervalSince1970 }
    static func dbl(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
    static func ints(_ v: Any?) -> [Int] {
        if let arr = v as? [Int] { return arr }
        if let arr = v as? [NSNumber] { return arr.map(\.intValue) }
        return []
    }
}

// MARK: - Group

extension Group {
    var fsDict: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "inviteCode": inviteCode,
            "createdAt": FSMap.epoch(createdAt),
            "memberIDs": FSMap.ids(memberIDs)
        ]
    }
    init?(fs d: [String: Any]) {
        guard let id = FSMap.uuid(d["id"]),
              let name = FSMap.str(d["name"]),
              let code = FSMap.str(d["inviteCode"]),
              let created = FSMap.date(d["createdAt"]) else { return nil }
        self.init(id: id, name: name, inviteCode: code, createdAt: created,
                  memberIDs: FSMap.uuids(d["memberIDs"]))
    }
}

// MARK: - Member

extension Member {
    var fsDict: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "avatarColorHex": avatarColorHex,
            "joinedAt": FSMap.epoch(joinedAt),
            "groupID": groupID.uuidString
        ]
    }
    init?(fs d: [String: Any]) {
        guard let id = FSMap.uuid(d["id"]),
              let name = FSMap.str(d["name"]),
              let color = FSMap.str(d["avatarColorHex"]),
              let joined = FSMap.date(d["joinedAt"]),
              let gid = FSMap.uuid(d["groupID"]) else { return nil }
        self.init(id: id, name: name, avatarColorHex: color, joinedAt: joined, groupID: gid)
    }
}

// MARK: - Chore

extension Chore {
    var fsDict: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "groupID": groupID.uuidString,
            "title": title,
            "icon": icon,
            "cycleType": cycleType.rawValue,
            "currentAssigneeID": currentAssigneeID.uuidString,
            "nextDueDate": FSMap.epoch(nextDueDate),
            "rotationStartedAt": FSMap.epoch(rotationStartedAt),
            "rotationMemberIDs": FSMap.ids(rotationMemberIDs),
            "weekdays": weekdays
        ]
        if let anchorDate { dict["anchorDate"] = FSMap.epoch(anchorDate) }
        return dict
    }
    init?(fs d: [String: Any]) {
        guard let id = FSMap.uuid(d["id"]),
              let gid = FSMap.uuid(d["groupID"]),
              let title = FSMap.str(d["title"]),
              let icon = FSMap.str(d["icon"]),
              let cycleRaw = FSMap.str(d["cycleType"]),
              let cycle = ChoreCycle(rawValue: cycleRaw),
              let assignee = FSMap.uuid(d["currentAssigneeID"]),
              let due = FSMap.date(d["nextDueDate"]),
              let started = FSMap.date(d["rotationStartedAt"]) else { return nil }
        self.init(id: id, groupID: gid, title: title, icon: icon, cycleType: cycle,
                  currentAssigneeID: assignee, nextDueDate: due, rotationStartedAt: started,
                  rotationMemberIDs: FSMap.uuids(d["rotationMemberIDs"]),
                  weekdays: FSMap.ints(d["weekdays"]),
                  anchorDate: FSMap.date(d["anchorDate"]))
    }
}

// MARK: - ChoreCompletion

extension ChoreCompletion {
    var fsDict: [String: Any] {
        [
            "id": id.uuidString,
            "choreID": choreID.uuidString,
            "memberID": memberID.uuidString,
            "completedAt": FSMap.epoch(completedAt),
            "isConfirmed": isConfirmed,
            "deviceIdentifier": deviceIdentifier
        ]
    }
    init?(fs d: [String: Any]) {
        guard let id = FSMap.uuid(d["id"]),
              let cid = FSMap.uuid(d["choreID"]),
              let mid = FSMap.uuid(d["memberID"]),
              let at = FSMap.date(d["completedAt"]),
              let dev = FSMap.str(d["deviceIdentifier"]) else { return nil }
        self.init(id: id, choreID: cid, memberID: mid, completedAt: at,
                  isConfirmed: FSMap.bool(d["isConfirmed"]), deviceIdentifier: dev)
    }
}

// MARK: - Expense

extension Expense {
    var fsDict: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "groupID": groupID.uuidString,
            "title": title,
            "amount": FSMap.dbl(amount),
            "paidByMemberID": paidByMemberID.uuidString,
            "participantMemberIDs": FSMap.ids(participantMemberIDs),
            "date": FSMap.epoch(date),
            "isSettled": isSettled,
            "category": category.rawValue
        ]
        if let memo { dict["memo"] = memo }
        // receiptImageData 는 Firestore 1MB 문서 제한 때문에 동기화하지 않음 (운영 시 Cloud Storage 권장)
        return dict
    }
    init?(fs d: [String: Any]) {
        guard let id = FSMap.uuid(d["id"]),
              let gid = FSMap.uuid(d["groupID"]),
              let title = FSMap.str(d["title"]),
              let paidBy = FSMap.uuid(d["paidByMemberID"]),
              let date = FSMap.date(d["date"]),
              let catRaw = FSMap.str(d["category"]),
              let cat = ExpenseCategory(rawValue: catRaw) else { return nil }
        self.init(id: id, groupID: gid, title: title, amount: FSMap.decimal(d["amount"]),
                  paidByMemberID: paidBy, participantMemberIDs: FSMap.uuids(d["participantMemberIDs"]),
                  date: date, isSettled: FSMap.bool(d["isSettled"]), category: cat,
                  memo: FSMap.str(d["memo"]), receiptImageData: nil)
    }
}

// MARK: - Settlement

extension Settlement {
    var fsDict: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "groupID": groupID.uuidString,
            "fromMemberID": fromMemberID.uuidString,
            "toMemberID": toMemberID.uuidString,
            "amount": FSMap.dbl(amount)
        ]
        if let settledAt { dict["settledAt"] = FSMap.epoch(settledAt) }
        return dict
    }
    init?(fs d: [String: Any]) {
        guard let id = FSMap.uuid(d["id"]),
              let gid = FSMap.uuid(d["groupID"]),
              let from = FSMap.uuid(d["fromMemberID"]),
              let to = FSMap.uuid(d["toMemberID"]) else { return nil }
        self.init(id: id, groupID: gid, fromMemberID: from, toMemberID: to,
                  amount: FSMap.decimal(d["amount"]), settledAt: FSMap.date(d["settledAt"]))
    }
}
