//
//  WalmartPriceTracker.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation
import UserNotifications

// MARK: - Price Alert Models

struct WalmartProductInfo {
    let sourceId: String
    let name: String
    let regularPrice: Double
    let salePrice: Double?
    let onSale: Bool
    let image: String
    let url: String?
    let description: String
    let brand: String
    let category: String?
}

struct WalmartPriceAlert: Codable, Identifiable {
    let id: UUID
    let sourceId: String
    let name: String
    var currentPrice: Double
    let initialPrice: Double
    var thresholdPrice: Double?
    var thresholdPercentage: Double?
    var lastChecked: Date
    let imageUrl: String?
    let brand: String
    
    init(id: UUID = UUID(),
         sourceId: String,
         name: String,
         currentPrice: Double,
         initialPrice: Double,
         thresholdPrice: Double? = nil,
         thresholdPercentage: Double? = nil,
         lastChecked: Date = Date(),
         imageUrl: String? = nil,
         brand: String = "") {
        self.id = id
        self.sourceId = sourceId
        self.name = name
        self.currentPrice = currentPrice
        self.initialPrice = initialPrice
        self.thresholdPrice = thresholdPrice
        self.thresholdPercentage = thresholdPercentage
        self.lastChecked = lastChecked
        self.imageUrl = imageUrl
        self.brand = brand
    }
}

struct WalmartPriceUpdate: Codable, Identifiable {
    let id: UUID
    let sourceId: String
    let productName: String
    let oldPrice: Double
    let newPrice: Double
    let priceChange: Double
    let percentageChange: Double
    let timestamp: Date
    
    var isDecrease: Bool {
        return priceChange < 0
    }
    
    var formattedChange: String {
        let sign = isDecrease ? "-" : "+"
        return String(format: "%@$%.2f", sign, abs(priceChange))
    }
    
    var formattedPercentage: String {
        let sign = isDecrease ? "" : "+"
        return String(format: "%@%.1f%%", sign, percentageChange)
    }
}

// MARK: - Walmart Price Tracker

@MainActor
class WalmartPriceTracker: ObservableObject {
    // MARK: - Published Properties
    
    @Published var trackedItems: [WalmartPriceAlert] = []
    @Published var priceUpdates: [WalmartPriceUpdate] = []
    @Published var isLoading = false
    
    private var refreshTask: Task<Void, Never>? = nil
    private let walmartService: WalmartAPIService
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private let trackedItemsKey = "walmart_tracked_items"
    private let updatesCacheKey = "walmart_price_updates"
    
    private let priceDropThreshold = 5.0 // Default 5% threshold for price drop notifications
    
    // MARK: - Initialization
    
    init(walmartService: WalmartAPIService) {
        self.walmartService = walmartService
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
                print("Failed to request notification permissions: \(error)")
            } else if granted {
                print("Notification permissions granted for Walmart price tracking")
            }
        }
    }
    
    // MARK: - Item Tracking
    
    func addItem(_ product: ProductItemDTO, thresholdPrice: Double? = nil, thresholdPercentage: Double? = nil) {
        let alert = WalmartPriceAlert(
            sourceId: product.sourceId,
            name: product.name,
            currentPrice: product.price ?? 0.0,
            initialPrice: product.price ?? 0.0,
            thresholdPrice: thresholdPrice,
            thresholdPercentage: thresholdPercentage,
            imageUrl: product.imageURL?.absoluteString,
            brand: product.brand
        )
        
        trackedItems.append(alert)
        saveTrackedItems()
        
        print("Added Walmart item to price tracking: \(product.name)")
    }
    
    func removeItem(withId id: UUID) {
        trackedItems.removeAll { $0.id == id }
        saveTrackedItems()
        
        // Remove any scheduled notifications for this item
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
    
    func updateThreshold(for id: UUID, price: Double?, percentage: Double?) {
        if let index = trackedItems.firstIndex(where: { $0.id == id }) {
            trackedItems[index].thresholdPrice = price
            trackedItems[index].thresholdPercentage = percentage
            saveTrackedItems()
        }
    }
    
    // MARK: - Price Updates
    
    func checkForPriceUpdates() async {
        guard !trackedItems.isEmpty else { return }
        
        isLoading = true
        
        for (index, item) in trackedItems.enumerated() {
            do {
                // Get updated product information
                let updatedProduct = try await walmartService.getProductDetails(id: item.sourceId)
                let newPrice = updatedProduct.price ?? item.currentPrice
                
                if newPrice != item.currentPrice {
                    // Price has changed
                    let priceChange = newPrice - item.currentPrice
                    let percentageChange = (priceChange / item.currentPrice) * 100
                    
                    // Create price update record
                    let update = WalmartPriceUpdate(
                        id: UUID(),
                        sourceId: item.sourceId,
                        productName: item.name,
                        oldPrice: item.currentPrice,
                        newPrice: newPrice,
                        priceChange: priceChange,
                        percentageChange: percentageChange,
                        timestamp: Date()
                    )
                    
                    priceUpdates.insert(update, at: 0) // Insert at beginning for newest first
                    
                    // Update tracked item
                    trackedItems[index].currentPrice = newPrice
                    trackedItems[index].lastChecked = Date()
                    
                    // Check if we should send a notification
                    await checkForNotificationTriggers(item: trackedItems[index], update: update)
                }
                
                // Add small delay between requests to avoid rate limiting
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
            } catch {
                print("Failed to check price for Walmart item \(item.name): \(error)")
            }
        }
        
        saveTrackedItems()
        savePriceUpdates()
        isLoading = false
    }
    
    private func checkForNotificationTriggers(item: WalmartPriceAlert, update: WalmartPriceUpdate) async {
        var shouldNotify = false
        var notificationMessage = ""
        
        // Check threshold price
        if let thresholdPrice = item.thresholdPrice, update.newPrice <= thresholdPrice {
            shouldNotify = true
            notificationMessage = String(format: "%@ is now $%.2f (below your $%.2f threshold)", item.name, update.newPrice, thresholdPrice)
        }
        
        // Check threshold percentage
        if let thresholdPercentage = item.thresholdPercentage, update.percentageChange <= -thresholdPercentage {
            shouldNotify = true
            notificationMessage = String(format: "%@ dropped by %.1f%% to $%.2f", item.name, abs(update.percentageChange), update.newPrice)
        }
        
        // Check default price drop threshold
        if update.percentageChange <= -priceDropThreshold {
            shouldNotify = true
            if notificationMessage.isEmpty {
                notificationMessage = String(format: "%@ dropped by %.1f%% to $%.2f", item.name, abs(update.percentageChange), update.newPrice)
            }
        }
        
        if shouldNotify {
            await sendPriceNotification(message: notificationMessage, item: item)
        }
    }
    
    private func sendPriceNotification(message: String, item: WalmartPriceAlert) async {
        let content = UNMutableNotificationContent()
        content.title = "Walmart Price Drop!"
        content.body = message
        content.sound = .default
        content.badge = 1
        
        // Set category for actions
        content.categoryIdentifier = "WALMART_PRICE_ALERT"
        
        // Add user info for deep linking
        content.userInfo = [
            "sourceId": item.sourceId,
            "retailer": "walmart",
            "type": "price_drop"
        ]
        
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil // Send immediately
        )
        
        do {
            try await notificationCenter.add(request)
            print("Sent Walmart price notification for: \(item.name)")
        } catch {
            print("Failed to send Walmart price notification: \(error)")
        }
    }
    
    // MARK: - Timer Management
    
    private func startRefreshTimer() {
        refreshTask = Task {
            while !Task.isCancelled {
                do {
                    // Check for updates every 30 minutes
                    try await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                    
                    if !Task.isCancelled {
                        await checkForPriceUpdates()
                    }
                } catch {
                    break
                }
            }
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveTrackedItems() {
        do {
            let data = try JSONEncoder().encode(trackedItems)
            UserDefaults.standard.set(data, forKey: trackedItemsKey)
        } catch {
            print("Failed to save Walmart tracked items: \(error)")
        }
    }
    
    private func loadSavedItems() {
        guard let data = UserDefaults.standard.data(forKey: trackedItemsKey) else { return }
        
        do {
            trackedItems = try JSONDecoder().decode([WalmartPriceAlert].self, from: data)
        } catch {
            print("Failed to load Walmart tracked items: \(error)")
        }
    }
    
    private func savePriceUpdates() {
        do {
            // Keep only the most recent 100 updates
            let recentUpdates = Array(priceUpdates.prefix(100))
            let data = try JSONEncoder().encode(recentUpdates)
            UserDefaults.standard.set(data, forKey: updatesCacheKey)
        } catch {
            print("Failed to save Walmart price updates: \(error)")
        }
    }
    
    private func loadSavedUpdates() {
        guard let data = UserDefaults.standard.data(forKey: updatesCacheKey) else { return }
        
        do {
            priceUpdates = try JSONDecoder().decode([WalmartPriceUpdate].self, from: data)
        } catch {
            print("Failed to load Walmart price updates: \(error)")
        }
    }
    
    // MARK: - Convenience Methods
    
    func isTracking(_ product: ProductItemDTO) -> Bool {
        return trackedItems.contains { $0.sourceId == product.sourceId }
    }
    
    func getTrackedItem(for sourceId: String) -> WalmartPriceAlert? {
        return trackedItems.first { $0.sourceId == sourceId }
    }
    
    func getPriceHistory(for sourceId: String) -> [WalmartPriceUpdate] {
        return priceUpdates.filter { $0.sourceId == sourceId }.sorted { $0.timestamp > $1.timestamp }
    }
    
    func clearAllUpdates() {
        priceUpdates.removeAll()
        savePriceUpdates()
    }
    
    // MARK: - Analytics
    
    var totalSavings: Double {
        return priceUpdates
            .filter { $0.isDecrease }
            .reduce(0) { $0 + abs($1.priceChange) }
    }
    
    var averageSavingsPercentage: Double {
        let decreases = priceUpdates.filter { $0.isDecrease }
        guard !decreases.isEmpty else { return 0 }
        
        let totalPercentage = decreases.reduce(0) { $0 + abs($1.percentageChange) }
        return totalPercentage / Double(decreases.count)
    }
    
    var mostTrackedBrands: [String] {
        let brandCounts = Dictionary(grouping: trackedItems, by: { $0.brand })
            .mapValues { $0.count }
        
        return brandCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
}

// MARK: - Extensions

extension WalmartPriceTracker {
    // Create a preview instance for SwiftUI previews
    static func previewTracker() -> WalmartPriceTracker {
        let previewService = WalmartAPIService.createPreview()
        let tracker = WalmartPriceTracker(walmartService: previewService)
        
        // Add some mock tracked items
        tracker.trackedItems = [
            WalmartPriceAlert(
                sourceId: "123456789",
                name: "Apple AirPods Pro (2nd generation)",
                currentPrice: 249.99,
                initialPrice: 299.99,
                thresholdPrice: 200.00,
                thresholdPercentage: 10.0,
                imageUrl: "https://i5.walmartimages.com/seo/Apple-AirPods-Pro.jpg",
                brand: "Apple"
            ),
            WalmartPriceAlert(
                sourceId: "987654321",
                name: "Samsung 65-Inch Crystal UHD 4K Smart TV",
                currentPrice: 497.99,
                initialPrice: 649.99,
                thresholdPrice: 450.00,
                imageUrl: "https://i5.walmartimages.com/seo/Samsung-65-Class.jpg",
                brand: "Samsung"
            )
        ]
        
        // Add some mock price updates
        tracker.priceUpdates = [
            WalmartPriceUpdate(
                id: UUID(),
                sourceId: "123456789",
                productName: "Apple AirPods Pro (2nd generation)",
                oldPrice: 299.99,
                newPrice: 249.99,
                priceChange: -50.00,
                percentageChange: -16.7,
                timestamp: Date().addingTimeInterval(-3600)
            )
        ]
        
        return tracker
    }
}