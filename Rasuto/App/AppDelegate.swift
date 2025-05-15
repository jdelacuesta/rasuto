//
//  AppDelegate.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    // Reference to the EbayNotificationManager
    var ebayNotificationManager: EbayNotificationManager?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure API keys
        configureAPIKeys()
        
        // Initial setup
        configureAppAppearance()
        
        // Setup eBay webhook handling
        setupEbayWebhookHandling()
        
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
    
    /// Configure API keys for eBay services
    private func configureAPIKeys() {
        do {
            // Set eBay API keys
            try APIConfig.saveAPIKey("SBX-8a6bc0b4d-f64bb84a", for: APIConfig.Service.ebay)
            try APIConfig.saveAPIKey("***REMOVED***", for: APIConfig.Service.ebayClientID)
            try APIConfig.saveAPIKey("***REMOVED***", for: APIConfig.Service.ebayClientSecret)
            
            print("Successfully configured eBay API keys")
        } catch {
            print("Failed to save API keys: \(error)")
        }
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
            // Get the notification manager
            guard let notificationManager = ebayNotificationManager else {
                print("Error: EbayNotificationManager not initialized yet")
                return
            }
            
            // Process the webhook
            try await notificationManager.processWebhook(data: data, headers: headers)
        } catch {
            print("Error processing eBay webhook: \(error)")
        }
    }
}
