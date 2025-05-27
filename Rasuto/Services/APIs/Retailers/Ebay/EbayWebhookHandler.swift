//
//  EbayWebhookHandler.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/30/25.
//

import Foundation
import SwiftUI
import CommonCrypto // Import needed for SHA-256 calculation


// This class handles incoming eBay webhook notifications
class EbayWebhookHandler {
    enum WebhookError: Error {
        case invalidRequest
        case signatureVerificationFailed
        case processingFailed
        case challengeResponseFailed
    }
    
    // MARK: - Properties
    
    private let notificationService: EbayNotificationService
    private let notificationManager: EbayNotificationManager
    
    /// Verification token used to verify the endpoint
    private let verificationToken: String
    
    // MARK: - Initialization
    
    init(notificationService: EbayNotificationService, notificationManager: EbayNotificationManager) {
        self.notificationService = notificationService
        self.notificationManager = notificationManager
        
        // Load or generate verification token
        if let savedToken = UserDefaults.standard.string(forKey: "ebay_verification_token") {
            self.verificationToken = savedToken
        } else {
            // Generate a new token
            let newToken = UUID().uuidString
            UserDefaults.standard.set(newToken, forKey: "ebay_verification_token")
            self.verificationToken = newToken
        }
    }
    
    // MARK: - Challenge Response
    
    /// Handle the initial challenge request from eBay when registering a webhook endpoint
    func handleChallengeRequest(challengeCode: String) -> String {
        // eBay sends a challenge code that we need to process and return
        // The challenge code should be hashed with the verification token
        // and returned as the challenge response
        
        // Combine challenge code and verification token
        let combinedString = challengeCode + ":" + verificationToken
        
        // Hash the combined string using SHA-256
        if let data = combinedString.data(using: .utf8) {
            let hash = data.sha256()
            return hash.base64EncodedString()
        }
        
        return ""
    }
    
    // MARK: - Notification Handling
    
    /// Process an incoming webhook request
    func processWebhookRequest(data: Data, headers: [String: String]) async throws {
        // Check if this is a challenge request
        if let challengeHeader = headers["X-EBAY-SIGNATURE-CHALLENGE"] {
            // This is a challenge request
            let challengeResponse = handleChallengeRequest(challengeCode: challengeHeader)
            // In a real implementation, you would return this response to eBay
            print("Challenge Response: \(challengeResponse)")
            return
        }
        
        // Check for required headers
        guard let signatureHeader = headers["X-EBAY-SIGNATURE"] else {
            throw WebhookError.invalidRequest
        }
        
        // Verify the signature
        let isValid = try await notificationService.validateNotification(
            signature: signatureHeader,
            payload: data
        )
        
        if !isValid {
            throw WebhookError.signatureVerificationFailed
        }
        
        // Process the notification
        let notification = try notificationService.processNotification(payload: data)
        
        // Handle notification based on topic
        switch notification.topic {
        case "ITEM_PRICE_CHANGE":
            try await handlePriceChangeNotification(notification)
        case "ITEM_INVENTORY_CHANGE":
            try await handleInventoryChangeNotification(notification)
        case "ITEM_PROMOTION_STATUS_CHANGE":
            try await handlePromotionChangeNotification(notification)
        default:
            print("Received unhandled notification type: \(notification.topic)")
        }
    }
    
    // MARK: - Notification Type Handlers
    
    /// Handle price change notifications
    private func handlePriceChangeNotification(_ notification: EbayNotificationMessage) async throws {
        guard let notificationData = notification.notification as? [String: Any],
              let itemId = notificationData["itemId"] as? String,
              let oldPrice = notificationData["oldPrice"] as? [String: Any],
              let newPrice = notificationData["newPrice"] as? [String: Any],
              let oldPriceValue = oldPrice["value"] as? String,
              let newPriceValue = newPrice["value"] as? String,
              let oldPriceDouble = Double(oldPriceValue),
              let newPriceDouble = Double(newPriceValue) else {
            throw WebhookError.processingFailed
        }
        
        // Only create alert if price decreased
        if newPriceDouble < oldPriceDouble {
            // Get item details from UserDefaults
            if let itemData = UserDefaults.standard.dictionary(forKey: "ebay_item_\(itemId)"),
               let itemName = itemData["name"] as? String,
               let thumbnailUrl = itemData["thumbnailUrl"] as? String {
                
                // Calculate price drop percentage
                let priceDropPercent = Int((1 - (newPriceDouble / oldPriceDouble)) * 100)
                
                // Create an alert
                let alert = NotificationAlert(
                    productId: itemId,
                    productName: itemName,
                    source: "eBay",
                    alertType: .priceDropped,
                    date: Date(),
                    message: "Price dropped by \(priceDropPercent)% from $\(String(format: "%.2f", oldPriceDouble)) to $\(String(format: "%.2f", newPriceDouble))",
                    thumbnailUrl: thumbnailUrl,
                    isRead: false,
                    auctionEndTime: nil,
                    currentBid: newPriceDouble
                )
                
                // Add the alert to the notification manager
                Task { @MainActor in
                    notificationManager.addAlert(alert)
                    
                    // Schedule local notification
                    await notificationManager.scheduleNotification(for: .priceDropped(
                        itemId: itemId,
                        oldPrice: oldPriceDouble,
                        newPrice: newPriceDouble
                    ), itemName: itemName)
                }
                
                // Update stored price
                var updatedItemData = itemData
                updatedItemData["lastPrice"] = newPriceDouble
                updatedItemData["lastChecked"] = Date().timeIntervalSince1970
                UserDefaults.standard.set(updatedItemData, forKey: "ebay_item_\(itemId)")
            }
        }
    }
    
    /// Handle inventory change notifications
    private func handleInventoryChangeNotification(_ notification: EbayNotificationMessage) async throws {
        guard let notificationData = notification.notification as? [String: Any],
              let itemId = notificationData["itemId"] as? String,
              let oldQuantity = notificationData["oldQuantity"] as? Int,
              let newQuantity = notificationData["newQuantity"] as? Int else {
            throw WebhookError.processingFailed
        }
        
        // Get item details from UserDefaults
        if let itemData = UserDefaults.standard.dictionary(forKey: "ebay_item_\(itemId)"),
           let itemName = itemData["name"] as? String,
           let thumbnailUrl = itemData["thumbnailUrl"] as? String {
            
            // Handle inventory changes
            if oldQuantity > 0 && newQuantity == 0 {
                // Item sold out
                let alert = NotificationAlert(
                    productId: itemId,
                    productName: itemName,
                    source: "eBay",
                    alertType: .itemSold,
                    date: Date(),
                    message: "This item is now sold out",
                    thumbnailUrl: thumbnailUrl,
                    isRead: false,
                    auctionEndTime: nil,
                    currentBid: nil
                )
                
                Task { @MainActor in
                    notificationManager.addAlert(alert)
                    await notificationManager.scheduleNotification(for: .itemSold(itemId: itemId), itemName: itemName)
                }
            } else if oldQuantity == 0 && newQuantity > 0 {
                // Item back in stock
                let alert = NotificationAlert(
                    productId: itemId,
                    productName: itemName,
                    source: "eBay",
                    alertType: .backInStock,
                    date: Date(),
                    message: "Item is back in stock!",
                    thumbnailUrl: thumbnailUrl,
                    isRead: false,
                    auctionEndTime: nil,
                    currentBid: nil
                )
                
                Task { @MainActor in
                    notificationManager.addAlert(alert)
                    await notificationManager.scheduleNotification(for: .inventoryChange(itemId: itemId, newQuantity: newQuantity), itemName: itemName)
                }
            } else if newQuantity > 0 && newQuantity <= 3 {
                // Low stock
                let alert = NotificationAlert(
                    productId: itemId,
                    productName: itemName,
                    source: "eBay",
                    alertType: .backInStock,
                    date: Date(),
                    message: "Only \(newQuantity) left in stock!",
                    thumbnailUrl: thumbnailUrl,
                    isRead: false,
                    auctionEndTime: nil,
                    currentBid: nil
                )
                
                Task { @MainActor in
                    notificationManager.addAlert(alert)
                    await notificationManager.scheduleNotification(for: .inventoryChange(itemId: itemId, newQuantity: newQuantity), itemName: itemName)
                }
            }
            
            // Update stored quantity
            var updatedItemData = itemData
            updatedItemData["lastQuantity"] = newQuantity
            updatedItemData["lastChecked"] = Date().timeIntervalSince1970
            UserDefaults.standard.set(updatedItemData, forKey: "ebay_item_\(itemId)")
        }
    }
    
    /// Handle promotion change notifications
    private func handlePromotionChangeNotification(_ notification: EbayNotificationMessage) async throws {
        guard let notificationData = notification.notification as? [String: Any],
              let itemId = notificationData["itemId"] as? String,
              let promotionStatus = notificationData["promotionStatus"] as? String else {
            throw WebhookError.processingFailed
        }
        
        // Get item details from UserDefaults
        if let itemData = UserDefaults.standard.dictionary(forKey: "ebay_item_\(itemId)"),
           let itemName = itemData["name"] as? String,
           let thumbnailUrl = itemData["thumbnailUrl"] as? String {
            
            // Handle promotion status changes
            if promotionStatus == "PROMOTED" {
                // Item was added to a promotion
                let alert = NotificationAlert(
                    productId: itemId,
                    productName: itemName,
                    source: "eBay",
                    alertType: .priceChange,
                    date: Date(),
                    message: "This item has been added to a promotion!",
                    thumbnailUrl: thumbnailUrl,
                    isRead: false,
                    auctionEndTime: nil,
                    currentBid: nil
                )
                
                Task { @MainActor in
                    notificationManager.addAlert(alert)
                }
            }
            
            // Update stored promotion status
            var updatedItemData = itemData
            updatedItemData["promotionStatus"] = promotionStatus
            updatedItemData["lastChecked"] = Date().timeIntervalSince1970
            UserDefaults.standard.set(updatedItemData, forKey: "ebay_item_\(itemId)")
        }
    }
}

// Extension to compute SHA-256 hash
extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(count), &hash)
        }
        return Data(hash)
    }
}

