//
//  NetworkMonitor.swift
//  RoomieSync
//
//  계획서 참조: 6.3 오프라인 (네트워크 복귀 감지)
//  작성자: 엄민욱 (2091188)
//  Created: 2026-06-02
//

import Foundation
import Network

@MainActor
public final class NetworkMonitor {

    public static let shared = NetworkMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.roomiesync.network")
    public private(set) var isReachable: Bool = true

    public var onChange: (@MainActor (Bool) -> Void)?

    private init() {
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied
            Task { @MainActor in
                self?.isReachable = reachable
                self?.onChange?(reachable)
            }
        }
        monitor.start(queue: queue)
    }
}
