//
//  BestBuyPriceTracker.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/19/25.
//

import Foundation
import UserNotifications

// MARK: - Price Alert Models

struct BestBuyPriceAlert: Codable, Identifiable {
    let id: UUID
    let sku: String
    let name: String
    var currentPrice: Double
    let initialPrice: Double
    var thresholdPrice: Double?
    var thresholdPercentage: Double?
    var lastChecked: Date
    let imageUrl: String?
    
    init(id: UUID = UUID(),
         sku: String,
         name: String,
         currentPrice: Double,
         initialPrice: Double,
         thresholdPrice: Double? = nil,
         thresholdPercentage: Double? = nil,
         lastChecked: Date = Date(),
         imageUrl: String? = nil) {
        self.id = id
        self.sku = sku
        self.name = name
        self.currentPrice = currentPrice
        self.initialPrice = initialPrice
        self.thresholdPrice = thresholdPrice
        self.thresholdPercentage = thresholdPercentage
        self.lastChecked = lastChecked
        self.imageUrl = imageUrl
    }
}

struct BestBuyPriceUpdate: Codable {
    let sku: String
    let oldPrice: Double
    let newPrice: Double
    let name: String
    let thumbnailImage: String?
    let date: Date
    
    var percentageChange: Double {
        if oldPrice == 0 { return 0 }
        return ((newPrice - oldPrice) / oldPrice) * 100
    }
    
    var isDecrease: Bool {
        return newPrice < oldPrice
    }
}

// MARK: - Main Price Tracker

@MainActor
class BestBuyPriceTracker: ObservableObject {
    // MARK: - Properties
    
    @Published var trackedItems: [BestBuyPriceAlert] = []
    @Published var priceUpdates: [BestBuyPriceUpdate] = []
    @Published var isLoading = false
    
    private var refreshTask: Task<Void, Never>? = nil
    private let bestBuyService: BestBuyAPIService
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private let trackedItemsKey = "bestbuy_tracked_items"
    private let updatesCacheKey = "bestbuy_price_updates"
    
    private let priceDropThreshold = 5.0 // Default 5% threshold for price drop notifications
    
    // MARK: - Initialization
    
    init(bestBuyService: BestBuyAPIService) {
        self.bestBuyService = bestBuyService
        requestNotificationPermissions()
        loadSavedItems()
        loadSavedUpdates()
        
        // Start the refresh timer
        startRefreshTimer()
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    // MARK: - Notification Permissions
    
    private func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    // MARK: - Data Management
    
    private func loadSavedItems() {
        if let savedData = UserDefaults.standard.data(forKey: trackedItemsKey) {
            do {
                let decoder = JSONDecoder()
                trackedItems = try decoder.decode([BestBuyPriceAlert].self, from: savedData)
            } catch {
                print("Failed to decode tracked items: \(error)")
            }
        }
    }
    
    private func saveTrackedItems() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(trackedItems)
            UserDefaults.standard.set(data, forKey: trackedItemsKey)
        } catch {
            print("Failed to encode tracked items: \(error)")
        }
    }
    
    private func loadSavedUpdates() {
        if let savedData = UserDefaults.standard.data(forKey: updatesCacheKey) {
            do {
                let decoder = JSONDecoder()
                priceUpdates = try decoder.decode([BestBuyPriceUpdate].self, from: savedData)
            } catch {
                print("Failed to decode price updates: \(error)")
            }
        }
    }
    
    private func saveUpdates() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(priceUpdates)
            UserDefaults.standard.set(data, forKey: updatesCacheKey)
        } catch {
            print("Failed to encode price updates: \(error)")
        }
    }
    
    // MARK: - Item Tracking
    
    /// Track an item for price changes
    func trackItem(sku: String, name: String, currentPrice: Double, thresholdPercentage: Double? = nil, imageUrl: String? = nil) async -> Bool {
        // Check if item is already tracked
        if trackedItems.contains(where: { $0.sku == sku }) {
            return false
        }
        
        // Create a new tracking alert
        let alert = BestBuyPriceAlert(
            sku: sku,
            name: name,
            currentPrice: currentPrice,
            initialPrice: currentPrice,
            thresholdPercentage: thresholdPercentage ?? priceDropThreshold,
            imageUrl: imageUrl
        )
        
        // Add to tracked items
        trackedItems.append(alert)
        saveTrackedItems()
        
        return true
    }
    
    /// Stop tracking an item
    func untrackItem(sku: String) -> Bool {
        let initialCount = trackedItems.count
        trackedItems.removeAll { $0.sku == sku }
        
        // If an item was removed, save the changes
        if trackedItems.count < initialCount {
            saveTrackedItems()
            return true
        }
        
        return false
    }
    
    /// Check if an item is being tracked
    func isItemTracked(sku: String) -> Bool {
        return trackedItems.contains { $0.sku == sku }
    }
    
    /// Set a custom price alert threshold for a specific item
    func setAlertThreshold(sku: String, thresholdPrice: Double? = nil, thresholdPercentage: Double? = nil) -> Bool {
        // Find the item
        guard let index = trackedItems.firstIndex(where: { $0.sku == sku }) else {
            return false
        }
        
        // Update the threshold
        var updatedAlert = trackedItems[index]
        updatedAlert.thresholdPrice = thresholdPrice
        updatedAlert.thresholdPercentage = thresholdPercentage
        
        trackedItems[index] = updatedAlert
        saveTrackedItems()
        
        return true
    }
    
    // MARK: - Price Updates
    
    private func startRefreshTimer() {
        // Create a long-running task that refreshes tracked items periodically
        refreshTask = Task {
            while !Task.isCancelled {
                await refreshPrices()
                
                // Sleep for 1 hour (3600 seconds)
                try? await Task.sleep(nanoseconds: 3_600_000_000_000)
            }
        }
    }
    
    /// Manually trigger a price refresh
    func refreshPrices() async {
        guard !isLoading else { return }
        
        isLoading = true
        
        // Process each tracked item
        for (index, alert) in trackedItems.enumerated() {
            do {
                // Get the latest product details
                let product = try await bestBuyService.getProductDetails(id: alert.sku)
                
                // Check for price change
                if let newPrice = product.price, newPrice != alert.currentPrice {
                    // Create price update
                    let update = BestBuyPriceUpdate(
                        sku: alert.sku,
                        oldPrice: alert.currentPrice,
                        newPrice: newPrice,
                        name: product.name,
                        thumbnailImage: product.thumbnailUrl,
                        date: Date()
                    )
                    
                    // If price dropped and meets threshold, send notification
                    if update.isDecrease {
                        let percentChange = abs(update.percentageChange)
                        let thresholdMet = alert.thresholdPercentage.map { percentChange >= $0 } ?? false
                        let priceMet = alert.thresholdPrice.map { newPrice <= $0 } ?? false
                        
                        if thresholdMet || priceMet {
                            // Add to updates
                            priceUpdates.append(update)
                            
                            // Send notification
                            await sendPriceDropNotification(for: update)
                        }
                    }
                    
                    // Update the tracked item's current price
                    var updatedAlert = alert
                    updatedAlert.currentPrice = newPrice
                    updatedAlert.lastChecked = Date()
                    trackedItems[index] = updatedAlert
                }
            } catch {
                print("Failed to refresh price for \(alert.sku): \(error)")
            }
        }
        
        // Save changes
        saveTrackedItems()
        saveUpdates()
        
        isLoading = false
    }
    
    /// Send a price drop notification
    private func sendPriceDropNotification(for update: BestBuyPriceUpdate) async {
        let content = UNMutableNotificationContent()
        content.title = "Price Drop Alert: \(update.name)"
        
        let percentDrop = Int(abs(update.percentageChange))
        let oldPrice = String(format: "$%.2f", update.oldPrice)
        let newPrice = String(format: "$%.2f", update.newPrice)
        
        content.body = "Price dropped by \(percentDrop)% from \(oldPrice) to \(newPrice)"
        content.sound = .default
        
        // Create a unique identifier for this notification
        let requestIdentifier = "bestbuy-price-drop-\(update.sku)-\(Date().timeIntervalSince1970)"
        
        // Create the notification request
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        // Add the notification request
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clear old price updates (keeping only recent ones)
    func clearOldUpdates(olderThan date: Date) {
        priceUpdates.removeAll { $0.date < date }
        saveUpdates()
    }
    
    /// Get only price drops (not increases)
    func getPriceDrops() -> [BestBuyPriceUpdate] {
        return priceUpdates.filter { $0.isDecrease }
    }
    
    /// Get all tracked items with their current prices
    func getTrackedItemsWithPrices() -> [(item: BestBuyPriceAlert, priceDifference: Double)] {
        return trackedItems.map { item in
            let priceDifference = item.initialPrice - item.currentPrice
            return (item: item, priceDifference: priceDifference)
        }
    }
    
    /// Get the total savings across all tracked items
    func getTotalSavings() -> Double {
        return trackedItems.reduce(0) { total, item in
            let savings = item.initialPrice > item.currentPrice ? (item.initialPrice - item.currentPrice) : 0
            return total + savings
        }
    }
}
