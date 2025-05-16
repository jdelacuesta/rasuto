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
    @StateObject private var ebayNotificationManager: EbayNotificationManager
    @StateObject private var networkMonitor = NetworkMonitor()
    @Environment(\.scenePhase) private var scenePhase
    
    // Dark mode support
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    // MARK: - Initialization
    
    init() {
        // Initialize eBay API Service
        let ebayService: EbayAPIService
        
        do {
            ebayService = try APIConfig.createEbayService()
        } catch {
            print("Failed to initialize eBay service: \(error)")
            // Use a dummy service for now
            ebayService = EbayAPIService(apiKey: "mock_key")
        }
        
        // Initialize notification manager
        _ebayNotificationManager = StateObject(wrappedValue: EbayNotificationManager(ebayService: ebayService))
        
        // Initialize network monitor
        _networkMonitor = StateObject(wrappedValue: NetworkMonitor())
        
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
            if let container = ModelContainerManager.shared.container {
                SplashScreen()
                    .modelContainer(container)
                    .environmentObject(ebayNotificationManager)
                    .environmentObject(networkMonitor) // Add network monitor to environment
                    .preferredColorScheme(isDarkMode ? .dark : .light)
                    .overlay(
                        !networkMonitor.isConnected ?
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
                    .onAppear {
                        // Configure app theme on launch
                        configureAppTheme()
                        if !appDelegateInitialized {
                            // Pass references to AppDelegate
                            appDelegate.ebayNotificationManager = ebayNotificationManager
                            appDelegate.networkMonitor = networkMonitor // Pass network monitor to AppDelegate
                            appDelegateInitialized = true
                        }
                    }
                    .onOpenURL { url in
                        // Handle OAuth callback
                        if url.scheme == "rasuto" {
                            print("Received OAuth callback: \(url)")
                        }
                    }
            } else {
                Text("Failed to load data container.")
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Check for credentials and prompt to set them up if needed
                checkAPICredentials()
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
