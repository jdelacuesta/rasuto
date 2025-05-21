//
//  RasutoApp.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI
import SwiftData
import CloudKit

// MARK: - Main App

@main
struct RasutoApp: App {
    
    // MARK: - Properties
    
    @State private var appDelegateInitialized = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var networkMonitorProxy = NetworkMonitorProxy()
    @Environment(\.scenePhase) private var scenePhase
    
    // Dark mode support
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    // MARK: - Initialization
    
    init() {
        // Setup CloudKit
        setupCloudKit()
        
        // Setup API credentials in development
        #if DEBUG
        setupDevelopmentEnvironment()
        #endif
    }
    
    // MARK: - App Scene
        
    var body: some Scene {
        WindowGroup {
            NavigationView {
                EbayAPITestView()
                    .environmentObject(EbayNotificationManager.shared)
                    .environmentObject(networkMonitorProxy)
                    .overlay(
                        !NetworkMonitor.shared.isConnected ?
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "wifi.slash")
                                Text("No internet connection")
                            }
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding()
                            Spacer().frame(height: 50)
                        }
                        : nil
                    )
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onAppear {
                // Configure app theme on launch
                configureAppTheme()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    // Check for credentials and prompt to set them up if needed
                    checkAPICredentials()
                }
            }
        }
    }
    
    // MARK: - CloudKit Setup
    
    private func setupCloudKit() {
        let container = CKContainer(identifier: "iCloud.com.Rasuto")
        container.privateCloudDatabase.fetchAllRecordZones { zones, error in
            if let error = error {
                print("CloudKit setup failed: \(error)")
            } else {
                print("CloudKit setup success. Zones: \(zones ?? [])")
            }
        }
    }
    
    // MARK: - Theme Configuration
    
    private func configureAppTheme() {
        Task { @MainActor in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                }
            }
        }
    }
    
    // MARK: - eBay API Configuration
    
    private func setupDevelopmentEnvironment() {
        // Setup test API keys
        APIConfig.setupTestKeys()
    }
    
    private func checkAPICredentials() {
        Task {
            // Check if eBay credentials are set up
            let hasEbayKey = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.ebay)
            let hasEbayClientID = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.ebayClientID)
            let hasEbayClientSecret = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.ebayClientSecret)
            
            if !hasEbayKey || !hasEbayClientID || !hasEbayClientSecret {
                // In a real app, you would show a settings screen where the user can enter their credentials
                print("eBay API credentials not found. Please set them up.")
            }
        }
    }
}

// MARK: - NetworkMonitorProxy

// This class acts as a proxy to observe the singleton NetworkMonitor
// and make it work with SwiftUI's environment
class NetworkMonitorProxy: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var connectionType: NetworkMonitor.ConnectionType = .unknown
    
    init() {
        // Observe changes from the singleton
        isConnected = NetworkMonitor.shared.isConnected
        connectionType = NetworkMonitor.shared.connectionType
        
        // Set up notification observer to update when network status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: .networkConnectionStatusChanged,
            object: nil
        )
    }
    
    @objc private func networkStatusChanged() {
        DispatchQueue.main.async {
            self.isConnected = NetworkMonitor.shared.isConnected
            self.connectionType = NetworkMonitor.shared.connectionType
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Add this extension to NetworkMonitor.swift
extension Notification.Name {
    static let networkConnectionStatusChanged = Notification.Name("networkConnectionStatusChanged")
}
