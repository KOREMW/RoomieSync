//
//  ChoreEntity.swift
//  RoomieSync
//
//  계획서 참조: 3.2 데이터 모델 (SwiftData) — Chore
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import SwiftData

@Model
public final class ChoreEntity {
    public var id: UUID = UUID()
    public var title: String = ""
    public var icon: String = "checkmark.square"
    /// ChoreCycle.rawValue 로 저장 — SwiftData 가 enum 직접 지원하나 CloudKit 호환을 위해 String 으로
    public var cycleTypeRaw: String = ChoreCycle.daily.rawValue
    public var currentAssigneeID: UUID = UUID()
    public var nextDueDate: Date = Date()
    public var rotationStartedAt: Date = Date()
    /// 로테이션 순서 스냅샷 — [UUID] 를 JSON 인코딩 후 String 으로
    /// (SwiftData + CloudKit 환경에서 array 직접 저장은 일부 케이스에서 동기화 이슈 보고됨)
    public var rotationMemberIDsJSON: String = "[]"
    /// 주간 반복 요일 — [Int] 를 JSON 인코딩 후 String 으로 (CloudKit 호환)
    public var weekdaysJSON: String = "[]"
    /// 선택(once)/매월(monthly) 기준 날짜.
    public var anchorDate: Date? = nil

    @Relationship(deleteRule: .nullify)
    public var group: GroupEntity?

    /// 완료 로그 — Chore 삭제 시 로그도 cascade
    @Relationship(deleteRule: .cascade, inverse: \ChoreCompletionEntity.chore)
    public var completions: [ChoreCompletionEntity]? = []

    public init(
        id: UUID = UUID(),
        title: String = "",
        icon: String = "checkmark.square",
        cycleTypeRaw: String = ChoreCycle.daily.rawValue,
        currentAssigneeID: UUID = UUID(),
        nextDueDate: Date = Date(),
        rotationStartedAt: Date = Date(),
        rotationMemberIDsJSON: String = "[]",
        group: GroupEntity? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.cycleTypeRaw = cycleTypeRaw
        self.currentAssigneeID = currentAssigneeID
        self.nextDueDate = nextDueDate
        self.rotationStartedAt = rotationStartedAt
        self.rotationMemberIDsJSON = rotationMemberIDsJSON
        self.group = group
    }
}

// MARK: - Domain Mapping
public extension ChoreEntity {
    func toDomain() -> Chore {
        let cycle = ChoreCycle(rawValue: cycleTypeRaw) ?? .daily
        let ids: [UUID] = {
            guard let data = rotationMemberIDsJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([UUID].self, from: data) else { return [] }
            return arr
        }()
        return Chore(
            id: id,
            groupID: group?.id ?? UUID(),
            title: title,
            icon: icon,
            cycleType: cycle,
            currentAssigneeID: currentAssigneeID,
            nextDueDate: nextDueDate,
            rotationStartedAt: rotationStartedAt,
            rotationMemberIDs: ids,
            weekdays: {
                guard let data = weekdaysJSON.data(using: .utf8),
                      let arr = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
                return arr
            }(),
            anchorDate: anchorDate
        )
    }

    func apply(_ domain: Chore) {
        self.title = domain.title
        self.icon = domain.icon
        self.cycleTypeRaw = domain.cycleType.rawValue
        self.currentAssigneeID = domain.currentAssigneeID
        self.nextDueDate = domain.nextDueDate
        self.rotationStartedAt = domain.rotationStartedAt
        if let data = try? JSONEncoder().encode(domain.rotationMemberIDs),
           let json = String(data: data, encoding: .utf8) {
            self.rotationMemberIDsJSON = json
        }
        if let data = try? JSONEncoder().encode(domain.weekdays),
           let json = String(data: data, encoding: .utf8) {
            self.weekdaysJSON = json
        }
        self.anchorDate = domain.anchorDate
    }
}
