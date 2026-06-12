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
    public private(set) var inboxUnreadCount: Int = 0
    public private(set) var groupName: String = ""
    public private(set) var groupIcon: String = Group.defaultIcon
    public private(set) var groupColorHex: String = Group.defaultIconColorHex
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

    private var isLoadInFlight = false

    public func load() async {
        // .task 와 .onAppear 가 동시에 호출해도 한 번만 (송금요청 알림 중복 방지)
        guard !isLoadInFlight else { return }
        isLoadInFlight = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; isLoadInFlight = false }
        do {
            let members = try await groupRepo.fetchMembers(ofGroup: groupID)
            let group = try await groupRepo.fetchGroup(id: groupID)
            membersByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            let me = CurrentMemberStore.resolve(members, groupID: groupID)
            currentUserID = me?.id
            greetingName = me?.name ?? ""
            groupName = group.name
            groupIcon = group.icon
            groupColorHex = group.iconColorHex

            // 내 앞으로 온 새 송금 요청 → 로컬 알림 (서버 푸시 없이 동기화 시점에 처리)
            await checkIncomingPaymentRequests(myID: me?.id)
            // 알림함 안 읽음 개수(송금요청+공지) → 홈 종 배지
            await updateInboxUnread(myID: me?.id)

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

            // 다른 멤버의 새 활동(완료/지출) → 로컬 알림 (서버 푸시 없이 앱 진입 시 감지)
            await notifyOthersActivity(myID: currentUserID, chores: todayChores,
                                       completions: weekCompletions, expenses: pendingExpenses)

            let myUndoneCount = todayChores.filter { ChoreRotation.assignee($0) == currentUserID }.count
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
            let assigneeID = ChoreRotation.assignee(chore)
            let assignee = members.first(where: { $0.id == assigneeID })
            return SharedSnapshot.ChoreItem(
                id: chore.id,
                title: chore.title,
                icon: chore.icon,
                assigneeName: assignee?.name ?? "?",
                assigneeColorHex: assignee?.avatarColorHex ?? "#4F46E5",
                isMine: assigneeID == currentUserID,
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

    /// 내 앞으로 온 송금 요청 중 '아직 알리지 않은 것'을 로컬 알림으로 띄운다.
    /// ID 기반 중복관리 → 상대가 보낸 첫 요청도 (앱을 열거나 새로고침하면) 즉시 알림.
    private func checkIncomingPaymentRequests(myID: UUID?) async {
        guard let myID else { return }
        let key = "payreqSeenIDs.\(groupID.uuidString)"
        var seen = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let requests = (try? await groupRepo.fetchPaymentRequests(groupID: groupID)) ?? []
        let mine = requests.filter { $0.toMemberID == myID && $0.fromMemberID != myID }

        // 오래된 백로그 스팸 방지: 최근 7일 이내 + 아직 안 알린 요청만 알림.
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        for req in mine where !seen.contains(req.id.uuidString) && req.createdAt >= weekAgo {
            let account = (req.bankName.map { "\($0) " } ?? "") + (req.accountNumber ?? "")
            await NotificationService.shared.notifyPaymentRequest(
                fromName: req.fromName, amount: req.amount,
                account: account.isEmpty ? nil : account)
        }
        // 내 앞 모든 요청을 '확인함'으로 기록(재알림 방지).
        mine.forEach { seen.insert($0.id.uuidString) }
        UserDefaults.standard.set(Array(seen), forKey: key)
    }

    /// 다른 멤버의 새 완료/지출/가사를 감지해 로컬 알림. 최근(2일) 항목만, id 기반 dedup.
    private func notifyOthersActivity(myID: UUID?, chores: [Chore],
                                     completions: [ChoreCompletion], expenses: [Expense]) async {
        guard let myID else { return }
        if DemoMode.isEnabled { return }   // 스크린샷 시 배너가 헤더를 가리지 않도록
        let recent = Date().addingTimeInterval(-2 * 24 * 3600)
        let choreByID = Dictionary(uniqueKeysWithValues: chores.map { ($0.id, $0) })

        if NotificationService.shared.userPrefers(.memberCompletion) {
            let items = completions.filter { $0.memberID != myID && $0.completedAt >= recent }
            await fireForNew(items.map { ($0.id, $0) }, key: "seenCompletions.\(groupID.uuidString)") { c in
                // 가사/멤버 조회가 실패해도 알림을 누락하지 않도록 폴백 문자열 사용.
                let chore = choreByID[c.choreID]
                let name = self.membersByID[c.memberID]?.name ?? "룸메이트"
                await NotificationService.shared.notifyMemberCompletion(
                    completionID: c.id, memberName: name,
                    choreTitle: chore?.title ?? "가사", choreIcon: chore?.icon ?? "✅")
            }
        }
        if NotificationService.shared.userPrefers(.expenseAdded) {
            let items = expenses.filter { $0.paidByMemberID != myID && $0.date >= recent }
            await fireForNew(items.map { ($0.id, $0) }, key: "seenExpenses.\(groupID.uuidString)") { e in
                let payer = self.membersByID[e.paidByMemberID]?.name ?? "누군가"
                await NotificationService.shared.notifyExpenseAdded(expense: e, payerName: payer)
            }
        }
        if NotificationService.shared.userPrefers(.choreAdded) {
            // 가사는 생성자 필드가 없어, 내가 만든 가사(ActivityLog)는 제외.
            let items = chores.filter {
                $0.rotationStartedAt >= recent && !ActivityLog.isMyCreatedChore($0.id, groupID: groupID)
            }
            await fireForNew(items.map { ($0.id, $0) }, key: "seenChores.\(groupID.uuidString)") { c in
                await NotificationService.shared.notifyChoreAdded(title: c.title, icon: c.icon)
            }
        }
    }

    /// id 기반 미확인 항목에만 fire(알림). 최근 항목만 넘기므로 첫 실행 스팸은 호출부 recency 로 방지.
    private func fireForNew<T: Sendable>(_ items: [(UUID, T)], key: String, _ fire: @MainActor (T) async -> Void) async {
        var seen = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        for (id, item) in items where !seen.contains(id.uuidString) {
            await fire(item)
            seen.insert(id.uuidString)
        }
        UserDefaults.standard.set(Array(seen), forKey: key)
    }

    /// 알림함(송금요청+공지) 안 읽음 개수 — 마지막으로 알림함을 연 시각 이후 생성된 항목.
    private func updateInboxUnread(myID: UUID?) async {
        guard let myID else { inboxUnreadCount = 0; return }
        let lastOpened = UserDefaults.standard.double(forKey: "inboxLastOpened.\(groupID.uuidString)")
        let cut = Date(timeIntervalSince1970: lastOpened)
        let hidden = InboxDismissStore.dismissed(groupID)
        func unread(_ id: UUID, _ date: Date) -> Bool { date > cut && !hidden.contains(id.uuidString) }

        let reqs = (try? await groupRepo.fetchPaymentRequests(groupID: groupID))?
            .filter { $0.toMemberID == myID && $0.fromMemberID != myID } ?? []
        let notes = (try? await groupRepo.fetchNotes(groupID: groupID)) ?? []
        let expenses = (try? await expenseRepo.fetchExpenses(groupID: groupID, includeSettled: true)) ?? []
        let completions = (try? await choreRepo.fetchAllCompletions(groupID: groupID, since: cut)) ?? []
        let chores = (try? await choreRepo.fetchChores(groupID: groupID)) ?? []

        var count = reqs.filter { unread($0.id, $0.createdAt) }.count
        count += notes.filter { unread($0.id, $0.createdAt) }.count
        count += expenses.filter { $0.paidByMemberID != myID && unread($0.id, $0.date) }.count
        count += completions.filter { $0.memberID != myID && unread($0.id, $0.completedAt) }.count
        count += chores.filter { !ActivityLog.isMyCreatedChore($0.id, groupID: groupID) && unread($0.id, $0.rotationStartedAt) }.count
        inboxUnreadCount = count
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
