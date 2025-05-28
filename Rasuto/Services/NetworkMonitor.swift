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
    @Published var isWaitingForConnectivity = false
    @Published var networkStatusMessage = ""
    
    // URLSession configured with waitsForConnectivity
    private lazy var waitingSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }()
    
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
    
    // MARK: - Network Request with Connectivity Waiting
    
    /// Performs a network request that waits for connectivity if network is unavailable
    /// - Parameters:
    ///   - url: The URL to request
    ///   - responseType: The expected response type
    ///   - showUI: Whether to show UI feedback (default: true)
    /// - Returns: Decoded response object
    func performRequest<T: Codable>(
        url: URL,
        responseType: T.Type,
        showUI: Bool = true
    ) async throws -> T {
        
        if showUI {
            await MainActor.run {
                isWaitingForConnectivity = true
                networkStatusMessage = isConnected ? "Making request..." : "Waiting for network connection..."
            }
        }
        
        do {
            let (data, response) = try await waitingSession.data(from: url)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }
            
            // Decode response
            let decoder = JSONDecoder()
            let result = try decoder.decode(responseType, from: data)
            
            if showUI {
                await MainActor.run {
                    isWaitingForConnectivity = false
                    networkStatusMessage = "Request completed successfully"
                    
                    // Clear success message after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.networkStatusMessage = ""
                    }
                }
            }
            
            return result
            
        } catch {
            if showUI {
                await MainActor.run {
                    isWaitingForConnectivity = false
                    networkStatusMessage = "Request failed: \(error.localizedDescription)"
                    
                    // Clear error message after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.networkStatusMessage = ""
                    }
                }
            }
            throw error
        }
    }
    
    /// Performs a basic network request for testing connectivity
    /// - Parameter showUI: Whether to show UI feedback
    func testConnectivity(showUI: Bool = true) async {
        guard let url = URL(string: "https://httpbin.org/json") else { return }
        
        do {
            let _: TestResponse = try await performRequest(
                url: url,
                responseType: TestResponse.self,
                showUI: showUI
            )
        } catch {
            print("Connectivity test failed: \(error)")
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Test Response Model
private struct TestResponse: Codable {
    // HTTPBin JSON endpoint returns various fields, we'll just capture what we need
    let slideshow: Slideshow?
    
    struct Slideshow: Codable {
        let author: String?
        let title: String?
    }
}

extension Notification.Name {
    static let networkConnectionRestored = Notification.Name("networkConnectionRestored")
}
