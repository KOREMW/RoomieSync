//
//  HomeViewModel.swift
//  RoomieSync
//
//  계획서 참조: 6.1 #4 일상 사용, 4.1 위젯 데이터 공급
//  작성자: 엄민욱 (2091188)
//  Created: 2026-05-19
//

import Foundation
import Observation

@MainActor
@Observable
public final class HomeViewModel {

    public let groupID: UUID
    private let groupRepo: any GroupRepositoryProtocol
    private let choreRepo: any ChoreRepositoryProtocol
    private let expenseRepo: any ExpenseRepositoryProtocol

    public private(set) var greetingName: String = ""
    public private(set) var todayChores: [Chore] = []
    public private(set) var membersByID: [UUID: Member] = [:]
    public private(set) var receiveAmount: Decimal = 0
    public private(set) var payAmount: Decimal = 0
    public private(set) var weekCompletionRate: Double = 0
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String? = nil
    public private(set) var currentUserID: UUID? = nil

    public init(groupID: UUID, repositories: RepositoryBundle) {
        self.groupID = groupID
        self.groupRepo = repositories.group
        self.choreRepo = repositories.chore
        self.expenseRepo = repositories.expense
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let members = try await groupRepo.fetchMembers(ofGroup: groupID)
            let group = try await groupRepo.fetchGroup(id: groupID)
            membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            currentUserID = members.first?.id
            greetingName = members.first?.name ?? ""

            todayChores = try await choreRepo.fetchChores(groupID: groupID)

            let pendingExpenses = try await expenseRepo.fetchExpenses(groupID: groupID, includeSettled: false)
            let net = SettlementCalculator.netBalances(expenses: pendingExpenses, members: members)
            if let me = currentUserID, let myNet = net[me] {
                if myNet >= 0 {
                    receiveAmount = myNet
                    payAmount = 0
                } else {
                    receiveAmount = 0
                    payAmount = -myNet
                }
            }

            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
            let weekCompletions = try await choreRepo.fetchAllCompletions(groupID: groupID, since: weekAgo)
            // 완료율 = (이번 주 1회 이상 완료된 가사 수) / (전체 가사 수)
            // 가사 2개 중 1개 완료 → 50% 처럼 가사 1개당 비율이 직관적으로 반영된다.
            let completedChoreIDs = Set(weekCompletions.map(\.choreID))
            let doneCount = todayChores.filter { completedChoreIDs.contains($0.id) }.count
            weekCompletionRate = todayChores.isEmpty ? 0 : Double(doneCount) / Double(todayChores.count)

            let myUndoneCount = todayChores.filter { $0.currentAssigneeID == currentUserID }.count
            NotificationService.shared.setBadge(myUndoneCount)

            // 4주차: 위젯에 노출할 AppGroup 스냅샷 갱신 + 위젯 reload
            await updateSharedSnapshot(group: group, members: members, undoneForMe: myUndoneCount)

            // 위젯 큐에서 메인 앱으로 들어온 액션 처리
            await drainWidgetActions()
        } catch {
            errorMessage = CKErrorMapper.userMessage(for: error)
        }
    }

    private func updateSharedSnapshot(group: Group, members: [Member], undoneForMe: Int) async {
        let items: [SharedSnapshot.ChoreItem] = todayChores.map { chore in
            let assignee = members.first(where: { $0.id == chore.currentAssigneeID })
            return SharedSnapshot.ChoreItem(
                id: chore.id,
                title: chore.title,
                icon: chore.icon,
                assigneeName: assignee?.name ?? "?",
                assigneeColorHex: assignee?.avatarColorHex ?? "#4F46E5",
                isMine: chore.currentAssigneeID == currentUserID,
                isCompleted: false
            )
        }
        let snap = SharedSnapshot(
            groupID: group.id,
            groupName: group.name,
            todayChores: items,
            undoneCountForMe: undoneForMe
        )
        SharedSnapshotStore.write(snap)
        WidgetReloader.reloadAll()
    }

    private func drainWidgetActions() async {
        let actions = PendingWidgetActions.drain()
        guard let me = currentUserID else { return }
        for action in actions {
            switch action {
            case .completeChore(let id, _):
                do {
                    let completion = try await choreRepo.recordCompletion(
                        choreID: id, memberID: me,
                        deviceIdentifier: "widget", isConfirmed: true
                    )
                    _ = try await choreRepo.confirmCompletion(completion.id)
                } catch {
                    print("⚠️ 위젯/알림 완료 액션 처리 실패: \(error)")
                }
            case .swapChore(let id, _):
                do {
                    _ = try await choreRepo.swapWithNext(choreID: id)
                } catch {
                    print("⚠️ 알림 교대 액션 처리 실패: \(error)")
                }
            }
        }
    }
}
