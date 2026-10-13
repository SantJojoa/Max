//
//  ConnectivityMonitor.swift
//  Max
//
//  Created by Santiago Jojoa on 30/08/26.
//

import Foundation
import Network

@Observable
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")

    var isConnected = false
    var onReconnect: (() -> Void)?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasConnected = self.isConnected
            let nowConnected = path.status == .satisfied

            DispatchQueue.main.async {
                self.isConnected = nowConnected
                if !wasConnected && nowConnected {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }
}
