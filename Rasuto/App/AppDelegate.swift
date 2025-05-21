//
//  AppDelegate.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    // Reference to singletons using shared instances
    let ebayNotificationManager = EbayNotificationManager.shared
    let networkMonitor = NetworkMonitor.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Monitoring network activity
        networkMonitor.startMonitoring()
        
        // Configure API keys
        configureAPIKeys()
        
        // Initial setup
        configureAppAppearance()
        
        // Setup eBay webhook handling
        setupEbayWebhookHandling()
        
        // Initialize eBay notification system
        setupEbayNotificationSystem()
        
        // Check if the app was launched with a URL
        if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL {
            processIncomingURL(url)
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Process the URL when app is opened via URL scheme
        processIncomingURL(url)
        return true
    }
    
    // MARK: - Configuration
    
    private func configureAppAppearance() {
        // Configure app appearance here
    }
    
    // Configure API keys for eBay services
    private func configureAPIKeys() {
        // Initialize API keys from SecretKeys file to keychain securely
        APIConfig.initializeAPIKeys()
        
        #if DEBUG
        // For development testing without real keys, you can use this
        if ProcessInfo.processInfo.arguments.contains("USE_TEST_KEYS") {
            do {
                let ebayClientID = try APIConfig.getAPIKey(for: APIConfig.Service.ebayClientID)
                let ebayClientSecret = try APIConfig.getAPIKey(for: APIConfig.Service.ebayClientSecret)
                let ebayAPIKey = try APIConfig.getAPIKey(for: APIConfig.Service.ebay)
                
                print("✅ eBay API credentials loaded:")
                print("   - Client ID: \(ebayClientID.prefix(4))...")
                print("   - Client Secret: \(ebayClientSecret.prefix(4))...")
                print("   - API Key: \(ebayAPIKey.prefix(4))...")
            } catch {
                print("❌ Failed to load eBay API credentials: \(error)")
                
                if ProcessInfo.processInfo.arguments.contains("USE_TEST_KEYS") {
                    do {
                        try APIConfig.setupTestKeys() // This uses your existing test key method
                        print("✅ Using test API keys for development")
                    } catch {
                        print("❌ Failed to set up test API keys: \(error)")
                    }
                }
            }
        }
            #endif
        }
    
    // MARK: - eBay Notification System
    
    private func setupEbayNotificationSystem() {
        // Initialize the notification system
        Task {
            do {
                try await ebayNotificationManager.initializeNotificationSystem()
                print("eBay notification system initialized successfully")
                
                // Set up observers for network restoration
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(networkConnectionRestored),
                    name: .networkConnectionRestored,
                    object: nil
                )
            } catch {
                print("Failed to initialize eBay notification system: \(error)")
            }
        }
    }
    
    @objc private func networkConnectionRestored() {
        print("Network connection restored, checking webhook and ngrok status")
        // Handle ngrok tunnel restart if needed
        Task {
            // Restart ngrok tunnel or check webhook status
            await checkNgrokStatus()
        }
    }
    
    private func checkNgrokStatus() async {
        // Add code to verify ngrok status and restart if needed
        print("Checking ngrok tunnel status")
    }
    
    // MARK: - eBay Webhook Handling
    
    /// Set up URL scheme for handling webhook callbacks
    private func setupEbayWebhookHandling() {
        // Register for notifications when the app is opened via the URL scheme
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenURL(_:)),
            name: UIApplication.didFinishLaunchingNotification,
            object: nil
        )
    }
    
    @objc private func handleOpenURL(_ notification: Notification) {
        // Check if the app was launched with a URL
        if let userInfo = notification.userInfo,
           let url = userInfo[UIApplication.LaunchOptionsKey.url] as? URL {
            // Process the URL
            processIncomingURL(url)
        }
    }
    
    /// Process incoming URLs which may be eBay webhook callbacks
    private func processIncomingURL(_ url: URL) {
        // Check if this is an eBay webhook URL
        if url.scheme == "rasuto" && url.host == "ebay-webhook" {
            // Extract webhook data from URL parameters
            // In a real implementation, the data would be in the request body
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let queryItems = components.queryItems {
                
                // Extract headers
                let headers = queryItems.reduce(into: [String: String]()) { result, item in
                    if item.name.hasPrefix("header_") {
                        let headerName = String(item.name.dropFirst(7)) // Remove "header_" prefix
                        result[headerName] = item.value
                    }
                }
                
                // Extract payload
                if let payloadItem = queryItems.first(where: { $0.name == "payload" }),
                   let payloadData = payloadItem.value?.data(using: .utf8) {
                    
                    // Process the webhook
                    Task {
                        await processEbayWebhook(data: payloadData, headers: headers)
                    }
                }
            }
        }
    }
    
    /// Process eBay webhook data
    private func processEbayWebhook(data: Data, headers: [String: String]) async {
        do {
            // Process the webhook
            try await ebayNotificationManager.processWebhook(data: data, headers: headers)
        } catch {
            print("Error processing eBay webhook: \(error)")
        }
    }
}
