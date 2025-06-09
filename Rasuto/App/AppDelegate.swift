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
    // eBay integration provided via SerpAPI
    let networkMonitor = NetworkMonitor.shared
    let apiConfig = APIConfig()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Monitoring network activity
        networkMonitor.startMonitoring()
        
        // Configure API keys
        configureAPIKeys()
        
        // Initial setup
        configureAppAppearance()
        
        // Setup eBay webhook handling (disabled)
        // eBay webhooks not needed - using SerpAPI integration
        
        // Initialize eBay notification system (disabled)
        // eBay notifications handled via SerpAPI
        
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
    
    
    // Configure API keys for SerpAPI + fallback services
    private func configureAPIKeys() {
        // Initialize API keys from DefaultKeys file to keychain securely
        apiConfig.initializeAPIKeys()
        
        #if DEBUG
        // For development testing, check if test keys should be used
        if ProcessInfo.processInfo.arguments.contains("USE_TEST_KEYS") {
            do {
                try apiConfig.setupTestKeys()
                print("✅ Using test API keys for development (SerpAPI + fallbacks)")
            } catch {
                print("❌ Failed to set up test API keys: \(error)")
            }
        }
        #endif
    }
    
    // MARK: - eBay Notification System - Removed (using SerpAPI)
    
    /*
    private func setupEbayNotificationSystem() {
        // Initialize the notification system
        // eBay notification system disabled
        // Task {
        //     do {
        //         try await ebayNotificationManager.initializeNotificationSystem()
        //         print("eBay notification system initialized successfully")
        //         
        //         // Set up observers for network restoration
        //         NotificationCenter.default.addObserver(
        //             self,
        //             selector: #selector(networkConnectionRestored),
        //             name: .networkConnectionRestored,
        //             object: nil
        //         )
        //     } catch {
        //         print("Failed to initialize eBay notification system: \(error)")
        //     }
        // }
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
    */
    
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
        // eBay webhook processing disabled
        // do {
        //     // Process the webhook
        //     try await ebayNotificationManager.processWebhook(data: data, headers: headers)
        // } catch {
        //     print("Error processing eBay webhook: \(error)")
        // }
        print("eBay webhook processing disabled - EbayNotificationManager unavailable")
    }
}
