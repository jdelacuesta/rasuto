//
//  EbayNotificationManager.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/30/25.
//

import Foundation
import UserNotifications

// MARK: - Notification Types

enum EbayNotificationType {
    case priceDropped(itemId: String, oldPrice: Double, newPrice: Double)
    case auctionEnding(itemId: String, endTime: Date)
    case itemSold(itemId: String)
    case inventoryChange(itemId: String, newQuantity: Int)
}

// MARK: - Alert Type Enum

enum NotificationAlertType: String, Codable {
    case priceDropped
    case priceChange
    case endingSoon
    case itemSold
    case backInStock
}

// MARK: - Alert Model

struct NotificationAlert: Identifiable, Codable {
    let id: UUID
    let productId: String
    let productName: String
    let source: String
    let alertType: NotificationAlertType
    let date: Date
    let message: String
    let thumbnailUrl: String?
    let isRead: Bool
    let auctionEndTime: Date?
    let currentBid: Double?
    
    init(id: UUID = UUID(), productId: String, productName: String, source: String, alertType: NotificationAlertType, date: Date, message: String, thumbnailUrl: String?, isRead: Bool, auctionEndTime: Date?, currentBid: Double?) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.source = source
        self.alertType = alertType
        self.date = date
        self.message = message
        self.thumbnailUrl = thumbnailUrl
        self.isRead = isRead
        self.auctionEndTime = auctionEndTime
        self.currentBid = currentBid
    }
}

@MainActor
class EbayNotificationManager: ObservableObject {
    @Published var pendingNotifications: [String: [EbayNotificationType]] = [:]
    @Published var alerts: [NotificationAlert] = []
    @Published var isLoading = false
    static let shared = EbayNotificationManager()
    private var refreshTask: Task<Void, Never>? = nil
    private let ebayService: EbayAPIService
    private let notificationCenter = UNUserNotificationCenter.current()
    
    init(ebayService: EbayAPIService? = nil) {
        // If a service is provided, use it; otherwise create one
        self.ebayService = ebayService ?? {
            do {
                return try APIConfig.createEbayService()
            } catch {
                print("Failed to create eBay API service: \(error)")
                fatalError("Cannot initialize EbayNotificationManager without a valid EbayAPIService")
            }
        }()
        
        requestNotificationPermissions()
        loadSavedAlerts()
        
        // Start the periodic refresh timer for fallback
        startRefreshTimer()
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    // MARK: - Notification System
    
    /// Initializes the eBay notification system, setting up webhook endpoints
    func initializeNotificationSystem() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await ebayService.initializeNotificationSystem()
            print("eBay notification system initialized successfully")
        } catch {
            print("Failed to initialize eBay notification system: \(error)")
            throw error
        }
    }
    
    func setupWebhookHandling() {
        // This method should be added to handle webhook initialization
        print("Setting up eBay webhook handling")
        
        // Register for webhook notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWebhookNotification(_:)),
            name: .ebayWebhookReceived,
            object: nil
        )
    }

    @objc private func handleWebhookNotification(_ notification: Notification) {
        // Handle webhook notifications
        if let userInfo = notification.userInfo,
           let data = userInfo["data"] as? Data,
           let headers = userInfo["headers"] as? [String: String] {
            
            Task {
                do {
                    try await processWebhook(data: data, headers: headers)
                } catch {
                    print("Error processing webhook notification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Notification Permissions
    
    private func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    // MARK: - Alert Management
    
    private func loadSavedAlerts() {
        if let savedAlertsData = UserDefaults.standard.data(forKey: "ebay_saved_alerts") {
            do {
                let decoder = JSONDecoder()
                let savedAlerts = try decoder.decode([NotificationAlert].self, from: savedAlertsData)
                alerts = savedAlerts
            } catch {
                print("Failed to decode saved alerts: \(error)")
            }
        }
    }
    
    private func saveAlerts() {
        do {
            let encoder = JSONEncoder()
            let alertsData = try encoder.encode(alerts)
            UserDefaults.standard.set(alertsData, forKey: "ebay_saved_alerts")
        } catch {
            print("Failed to encode alerts: \(error)")
        }
    }
    
    func addAlert(_ alert: NotificationAlert) {
        alerts.append(alert)
        saveAlerts()
    }
    
    func markAsRead(_ alertId: UUID) {
        if let index = alerts.firstIndex(where: { $0.id == alertId }) {
            var updatedAlert = alerts[index]
            let newAlert = NotificationAlert(
                productId: updatedAlert.productId,
                productName: updatedAlert.productName,
                source: updatedAlert.source,
                alertType: updatedAlert.alertType,
                date: updatedAlert.date,
                message: updatedAlert.message,
                thumbnailUrl: updatedAlert.thumbnailUrl,
                isRead: true,
                auctionEndTime: updatedAlert.auctionEndTime,
                currentBid: updatedAlert.currentBid
            )
            
            alerts[index] = newAlert
            saveAlerts()
        }
    }
    
    func clearAlert(_ alertId: UUID) {
        alerts.removeAll { $0.id == alertId }
        saveAlerts()
    }
    
    // MARK: - Item Tracking
    
    func trackItem(id: String, name: String, currentPrice: Double?, thumbnailUrl: String?) async throws -> Bool {
        do {
            let success = try await ebayService.trackItem(id: id)
            
            if success {
                // Add to locally tracked items
                let defaults = UserDefaults.standard
                var trackedItems = defaults.stringArray(forKey: "ebay_tracked_items") ?? []
                
                if !trackedItems.contains(id) {
                    trackedItems.append(id)
                    defaults.set(trackedItems, forKey: "ebay_tracked_items")
                    
                    // Store item metadata for notifications
                    let itemKey = "ebay_item_\(id)"
                    let itemData: [String: Any] = [
                        "name": name,
                        "lastPrice": currentPrice ?? 0.0,
                        "lastChecked": Date().timeIntervalSince1970,
                        "thumbnailUrl": thumbnailUrl ?? ""
                    ]
                    defaults.set(itemData, forKey: itemKey)
                }
                
                return true
            }
            return false
        } catch {
            print("Failed to track item: \(error)")
            throw error
        }
    }
    
    // MARK: - Refresh & Update
    
    private func startRefreshTimer() {
        refreshTask = Task {
            while !Task.isCancelled {
                await refreshTrackedItems()
                
                // Sleep for 30 minutes
                try? await Task.sleep(nanoseconds: 1_800_000_000_000)
            }
        }
    }
    
    func refreshTrackedItems() async {
        isLoading = true
        
        do {
            let updates = try await ebayService.getItemUpdates()
            
            for update in updates {
                let defaults = UserDefaults.standard
                let itemKey = "ebay_item_\(update.itemId)"
                
                guard let itemData = defaults.dictionary(forKey: itemKey),
                      let itemName = itemData["name"] as? String else {
                    continue
                }
                
                let thumbnailUrl = itemData["thumbnailUrl"] as? String
                
                switch update.eventType {
                case "PRICE_CHANGE":
                    if let oldPrice = update.oldPrice, let newPrice = update.newPrice, newPrice < oldPrice {
                        let priceDropPercent = Int((1 - (newPrice / oldPrice)) * 100)
                        
                        let alert = NotificationAlert(
                            productId: update.itemId,
                            productName: itemName,
                            source: "eBay",
                            alertType: .priceDropped,
                            date: Date(),
                            message: "Price dropped by \(priceDropPercent)% from $\(String(format: "%.2f", oldPrice)) to $\(String(format: "%.2f", newPrice))",
                            thumbnailUrl: thumbnailUrl,
                            isRead: false,
                            auctionEndTime: nil,
                            currentBid: newPrice
                        )
                        
                        addAlert(alert)
                        await scheduleNotification(for: .priceDropped(itemId: update.itemId, oldPrice: oldPrice, newPrice: newPrice), itemName: itemName)
                        
                        // Update stored price
                        var updatedItemData = itemData
                        updatedItemData["lastPrice"] = newPrice
                        updatedItemData["lastChecked"] = Date().timeIntervalSince1970
                        defaults.set(updatedItemData, forKey: itemKey)
                    }
                    
                case "INVENTORY_CHANGE":
                    if let newQuantity = update.newQuantity, newQuantity <= 3 && newQuantity > 0 {
                        let alert = NotificationAlert(
                            productId: update.itemId,
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
                        
                        addAlert(alert)
                        await scheduleNotification(for: .inventoryChange(itemId: update.itemId, newQuantity: newQuantity), itemName: itemName)
                    } else if let newQuantity = update.newQuantity, newQuantity == 0 {
                        let alert = NotificationAlert(
                            productId: update.itemId,
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
                        
                        addAlert(alert)
                        await scheduleNotification(for: .itemSold(itemId: update.itemId), itemName: itemName)
                    }
                    
                case "AUCTION_ENDING":
                    if let endTime = update.endTime, Date().distance(to: endTime) < 3600 { // Less than 1 hour remaining
                        let alert = NotificationAlert(
                            productId: update.itemId,
                            productName: itemName,
                            source: "eBay",
                            alertType: .endingSoon,
                            date: Date(),
                            message: "Auction ending soon!",
                            thumbnailUrl: thumbnailUrl,
                            isRead: false,
                            auctionEndTime: endTime,
                            currentBid: update.newPrice
                        )
                        
                        addAlert(alert)
                        await scheduleNotification(for: .auctionEnding(itemId: update.itemId, endTime: endTime), itemName: itemName)
                    }
                    
                default:
                    break
                }
            }
            
            isLoading = false
        } catch {
            print("Failed to refresh tracked items: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - Notifications
    
    func scheduleNotification(for notificationType: EbayNotificationType, itemName: String) async {
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        switch notificationType {
        case .priceDropped(let itemId, let oldPrice, let newPrice):
            let priceDropPercent = Int((1 - (newPrice / oldPrice)) * 100)
            content.title = "Price Drop Alert: \(itemName)"
            content.body = "Price dropped by \(priceDropPercent)% from $\(String(format: "%.2f", oldPrice)) to $\(String(format: "%.2f", newPrice))"
            content.userInfo = ["itemId": itemId, "type": "price_drop"]
            
        case .auctionEnding(let itemId, let endTime):
            let timeRemaining = Int(Date().distance(to: endTime) / 60) // In minutes
            content.title = "Auction Ending Soon: \(itemName)"
            content.body = "Only \(timeRemaining) minutes remaining in this auction!"
            content.userInfo = ["itemId": itemId, "type": "auction_ending"]
            
        case .itemSold(let itemId):
            content.title = "Item Sold Out: \(itemName)"
            content.body = "This item is now sold out on eBay"
            content.userInfo = ["itemId": itemId, "type": "item_sold"]
            
        case .inventoryChange(let itemId, let newQuantity):
            content.title = "Low Stock Alert: \(itemName)"
            content.body = "Only \(newQuantity) left in stock!"
            content.userInfo = ["itemId": itemId, "type": "inventory_change"]
        }
        
        let notificationId = UUID().uuidString
        
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    // MARK: - Untracking Items
    
    func untrackItem(id: String) async throws -> Bool {
        do {
            let success = try await ebayService.untrackItem(id: id)
            
            if success {
                let defaults = UserDefaults.standard
                var trackedItems = defaults.stringArray(forKey: "ebay_tracked_items") ?? []
                
                trackedItems.removeAll { $0 == id }
                defaults.set(trackedItems, forKey: "ebay_tracked_items")
                
                let itemKey = "ebay_item_\(id)"
                defaults.removeObject(forKey: itemKey)
                
                return true
            }
            return false
        } catch {
            print("Failed to untrack item: \(error)")
            throw error
        }
    }
    
    // MARK: - Process Webhook
    
    // Process an incoming webhook notification
    func processWebhook(data: Data, headers: [String: String]) async throws {
        try await ebayService.processWebhook(data: data, headers: headers)
    }
    
    // Webhook simulation
    func simulateWebhookEvent() {
        // Create a sample notification payload
        let samplePayload = """
        {
            "notification": {
                "notificationId": "test-notification-id",
                "eventDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "publishDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "subscriptionId": "test-subscription",
                "topic": "ITEM_PRICE_CHANGE",
                "data": {
                    "itemId": "v1|123456789|0",
                    "price": {
                        "value": "199.99",
                        "currency": "USD"
                    },
                    "previousPrice": {
                        "value": "249.99",
                        "currency": "USD"
                    },
                    "title": "Test Product with Price Change"
                }
            }
        }
        """
        
        // Convert to Data
        guard let data = samplePayload.data(using: .utf8) else {
            print("Failed to create payload data")
            return
        }
        
        // Create sample headers
        let headers = [
            "X-EBAY-SIGNATURE": "test-signature",
            "X-EBAY-EVENT-TYPE": "ITEM_PRICE_CHANGE"
        ]
        
        // Process the webhook
        Task {
            do {
                try await processWebhook(data: data, headers: headers)
                print("Simulated webhook processed successfully")
            } catch {
                print("Failed to process simulated webhook: \(error)")
            }
        }
    }
    
    
    // MARK: - Utility Functions
    
    func getPriceDropAlerts() -> [NotificationAlert] {
        return alerts.filter { $0.alertType == .priceDropped || $0.alertType == .priceChange }
    }
    
    func getTrackedItemIDs() -> [String] {
        let defaults = UserDefaults.standard
        return defaults.stringArray(forKey: "ebay_tracked_items") ?? []
    }
    
    func isItemTracked(id: String) -> Bool {
        let trackedItems = getTrackedItemIDs()
        return trackedItems.contains(id)
    }
}

// MARK: - Preview Support

extension EbayNotificationManager {
    // Method to add mock data for preview and testing
    func addMockAlerts() {
        // Clear existing alerts
        alerts.removeAll()
        
        // Add mock alerts
        let alerts = [
            NotificationAlert(
                productId: "v1|12345|0",
                productName: "Keith Haring Art Print Framed",
                source: "eBay",
                alertType: .priceDropped,
                date: Date().addingTimeInterval(-3600),
                message: "Price dropped by 30% from $149.99 to $99.99",
                thumbnailUrl: "https://i.ebayimg.com/images/g/YY4AAOSwt8Fk8r6s/s-l500.jpg",
                isRead: false,
                auctionEndTime: nil,
                currentBid: 99.99
            ),
            NotificationAlert(
                productId: "v1|13579|0",
                productName: "Coffee Maker Premium Espresso Machine",
                source: "eBay",
                alertType: .priceDropped,
                date: Date().addingTimeInterval(-7200),
                message: "Price dropped by 22% from $89.99 to $54.99",
                thumbnailUrl: "https://i.ebayimg.com/images/g/DEFAAOSwt8Fk8r6v/s-l500.jpg",
                isRead: false,
                auctionEndTime: nil,
                currentBid: 54.99
            ),
            NotificationAlert(
                productId: "v1|67890|0",
                productName: "Vintage Leica M6 Rangefinder Camera",
                source: "eBay",
                alertType: .endingSoon,
                date: Date().addingTimeInterval(-1800),
                message: "Auction ending soon",
                thumbnailUrl: "https://i.ebayimg.com/images/g/XYZAAOSwt8Fk8r6t/s-l500.jpg",
                isRead: false,
                auctionEndTime: Date().addingTimeInterval(2700),
                currentBid: 1850.00
            ),
            NotificationAlert(
                productId: "v1|54321|0",
                productName: "PlayStation 5 Slim Digital Edition",
                source: "eBay",
                alertType: .itemSold,
                date: Date().addingTimeInterval(-86400),
                message: "This item is now sold out",
                thumbnailUrl: "https://i.ebayimg.com/images/g/ABCAAOSwt8Fk8r6u/s-l500.jpg",
                isRead: true,
                auctionEndTime: nil,
                currentBid: 399.99
            ),
            NotificationAlert(
                productId: "v1|24680|0",
                productName: "Nike Air Max 90 - Black/White - Size 10",
                source: "eBay",
                alertType: .backInStock,
                date: Date().addingTimeInterval(-10800),
                message: "Item is back in stock!",
                thumbnailUrl: "https://i.ebayimg.com/images/g/GHIAAOSwt8Fk8r6w/s-l500.jpg",
                isRead: false,
                auctionEndTime: nil,
                currentBid: 129.99
            )
        ]
        
        self.alerts.append(contentsOf: alerts)
    }
}

extension Notification.Name {
    static let ebayWebhookReceived = Notification.Name("ebayWebhookReceived")
}
