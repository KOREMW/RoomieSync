//
//  ChoreViewModel.swift
//  RoomieSync
//
//  계획서 참조: Stitch 시안 ②, 6.2 피드백·오류정정 (5초 취소 토스트)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import Observation

public enum ChoreFilter: String, CaseIterable, Identifiable {
    case all, daily, weekly, monthly, once
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .all:     return "전체"
        case .daily:   return "매일"
        case .weekly:  return "매주"
        case .monthly: return "매 월"
        case .once:    return "선택"
        }
    }
    public var cycle: ChoreCycle? {
        switch self {
        case .all:     return nil
        case .daily:   return .daily
        case .weekly:  return .weekly
        case .monthly: return .monthly
        case .once:    return .once
        }
    }
}

@MainActor
@Observable
public final class ChoreViewModel {

    public let groupID: UUID
    private let groupRepo: any GroupRepositoryProtocol
    private let choreRepo: any ChoreRepositoryProtocol
    private let device: any DeviceIdentifierProviding

    public private(set) var allChores: [Chore] = []
    public private(set) var members: [Member] = []
    public var filter: ChoreFilter = .all
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String? = nil
    public private(set) var currentUserID: UUID? = nil

    public init(groupID: UUID, repositories: RepositoryBundle) {
        self.groupID = groupID
        self.groupRepo = repositories.group
        self.choreRepo = repositories.chore
        self.device = repositories.device
    }

    public var filteredChores: [Chore] {
        guard let cycle = filter.cycle else { return allChores }
        return allChores.filter { $0.cycleType == cycle }
    }

    public func clearError() { errorMessage = nil }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            members = try await groupRepo.fetchMembers(ofGroup: groupID)
            currentUserID = members.first?.id
            allChores = try await choreRepo.fetchChores(groupID: groupID)
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }

    public func addChore(
        title: String, icon: String, cycle: ChoreCycle, weekdays: [Int], anchorDate: Date? = nil,
        notifyMorning: Bool = true, notifyEvening: Bool = true,
        morningMinutes: Int = 540, eveningMinutes: Int = 1260
    ) async -> Bool {
        do {
            let chore = try await choreRepo.createChore(
                groupID: groupID,
                title: title,
                icon: icon,
                cycle: cycle,
                weekdays: weekdays,
                anchorDate: anchorDate,
                rotationMemberIDs: members.map(\.id)
            )
            applyChoreNotifications(chore: chore, morning: notifyMorning, evening: notifyEvening,
                                    morningMinutes: morningMinutes, eveningMinutes: eveningMinutes)
            await load()
            return true
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
            return false
        }
    }

    public func updateChore(
        _ chore: Chore, notifyMorning: Bool? = nil, notifyEvening: Bool? = nil,
        morningMinutes: Int = 540, eveningMinutes: Int = 1260
    ) async -> Bool {
        do {
            _ = try await choreRepo.updateChore(chore)
            if let m = notifyMorning, let e = notifyEvening {
                NotificationService.shared.cancelForChore(chore.id)
                applyChoreNotifications(chore: chore, morning: m, evening: e,
                                        morningMinutes: morningMinutes, eveningMinutes: eveningMinutes)
            }
            await load()
            return true
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
            return false
        }
    }

    /// 가사별 알림 토글·시각 저장 + (켜진 경우) 스케줄링.
    private func applyChoreNotifications(chore: Chore, morning: Bool, evening: Bool,
                                         morningMinutes: Int, eveningMinutes: Int) {
        let ns = NotificationService.shared
        ns.setChorePreference(.morningDuty, choreID: chore.id, enabled: morning)
        ns.setChorePreference(.eveningReminder, choreID: chore.id, enabled: evening)
        ns.setChoreTimeMinutes(.morningDuty, choreID: chore.id, minutes: morningMinutes)
        ns.setChoreTimeMinutes(.eveningReminder, choreID: chore.id, minutes: eveningMinutes)
        let assigneeName = members.first(where: { $0.id == chore.currentAssigneeID })?.name ?? ""
        Task {
            await ns.scheduleMorningDuty(chore: chore, memberName: assigneeName,
                                         hour: morningMinutes / 60, minute: morningMinutes % 60)
            await ns.scheduleEveningReminder(chore: chore, memberName: assigneeName,
                                             hour: eveningMinutes / 60, minute: eveningMinutes % 60)
        }
    }

    public func deleteChore(_ choreID: UUID) async -> Bool {
        do {
            try await choreRepo.deleteChore(choreID)
            await load()
            return true
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
            return false
        }
    }

    public func tentativeComplete(chore: Chore) async -> UUID? {
        guard let memberID = currentUserID else { return nil }
        do {
            let completion = try await choreRepo.recordCompletion(
                choreID: chore.id,
                memberID: memberID,
                deviceIdentifier: device.deviceIdentifier(),
                isConfirmed: false
            )
            HapticManager.shared.success()
            return completion.id
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
            return nil
        }
    }

    public func confirmComplete(completionID: UUID) async {
        do {
            let rotated = try await choreRepo.confirmCompletion(completionID)
            if let me = currentUserID,
               let member = members.first(where: { $0.id == me }) {
                await NotificationService.shared.notifyMemberCompletion(member: member, chore: rotated)
            }
            await load()
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }

    public func cancelComplete(completionID: UUID) async {
        do {
            try await choreRepo.cancelCompletion(completionID)
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }

    public func swap(chore: Chore) async {
        do {
            _ = try await choreRepo.swapWithNext(choreID: chore.id)
            await load()
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }

}
