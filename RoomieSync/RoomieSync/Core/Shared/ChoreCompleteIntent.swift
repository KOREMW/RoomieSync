//
//  ChoreCompleteIntent.swift
//  RoomieSync
//
//  계획서 참조: 4.1 Widget AppIntent — configurable 위젯 + 위젯에서 직접 완료
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-09
//

import Foundation
import AppIntents

/// 위젯의 "완료" 버튼 탭 → 앱을 열지 않고 처리.
public struct CompleteChoreIntent: AppIntent {
    @MainActor
    public static var title: LocalizedStringResource = "가사 완료 표시"
    @MainActor
    public static var description = IntentDescription("위젯에서 오늘의 가사를 완료 표시합니다.")
    @MainActor
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "가사 ID")
    public var choreID: String

    public init() { self.choreID = "" }

    public init(choreID: UUID) { self.choreID = choreID.uuidString }

    public func perform() async throws -> some IntentResult {
        // 1) AppGroup 스냅샷에서 해당 가사를 찾아 isCompleted = true 로 마킹
        var snap = SharedSnapshotStore.read()
        if let idx = snap.todayChores.firstIndex(where: { $0.id.uuidString == choreID }) {
            snap.todayChores[idx].isCompleted = true
            if snap.todayChores[idx].isMine {
                snap.undoneCountForMe = max(0, snap.undoneCountForMe - 1)
            }
            SharedSnapshotStore.write(snap)
        }
        // 2) 메인 앱에 동기화 요청 — 다음 앱 실행 시 ChoreRepository 에 반영
        var pending = PendingWidgetActions.read()
        pending.append(.completeChore(id: UUID(uuidString: choreID) ?? UUID(), at: .now))
        PendingWidgetActions.write(pending)
        return .result()
    }
}

/// 위젯이 메인 앱에 전달할 액션 큐 (AppGroup).
public enum PendingWidgetActions {
    public enum Action: Codable, Sendable {
        case completeChore(id: UUID, at: Date)
    }

    public static let key = AppKeys.AppGroup.pendingActions

    public static func read() -> [Action] {
        guard let d = SharedSnapshotStore.defaults,
              let data = d.data(forKey: key),
              let arr = try? JSONDecoder().decode([Action].self, from: data)
        else { return [] }
        return arr
    }

    public static func write(_ actions: [Action]) {
        guard let d = SharedSnapshotStore.defaults,
              let data = try? JSONEncoder().encode(actions) else { return }
        d.set(data, forKey: key)
    }

    public static func drain() -> [Action] {
        let actions = read()
        write([])
        return actions
    }
}

/// 위젯 configurable — 어느 그룹의 위젯인지 선택.
public struct SelectGroupIntent: AppIntent, WidgetConfigurationIntent {
    @MainActor
    public static var title: LocalizedStringResource = "그룹 선택"
    @MainActor
    public static var description = IntentDescription("위젯에 표시할 RoomieSync 그룹을 선택합니다.")

    @Parameter(title: "그룹 이름", default: "우리집")
    public var groupName: String

    public init() {}
}
