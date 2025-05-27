//
//  NetworkMonitor.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/16/25.
//

import Foundation
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                
                // If connection was restored, notify for tunnel restart
                if path.status == .satisfied {
                    NotificationCenter.default.post(name: .networkConnectionRestored, object: nil)
                }
            }
        }
    }
    
    func startMonitoring() {
        monitor.start(queue: queue)
        print("Network monitoring started")
    }
    
    func stopMonitoring() {
        monitor.cancel()
        print("Network monitoring stopped")
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }
    
    deinit {
        stopMonitoring()
    }
}

extension Notification.Name {
    static let networkConnectionRestored = Notification.Name("networkConnectionRestored")
}
