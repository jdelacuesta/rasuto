//
//  BackgroundSyncManager.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import Foundation
import BackgroundTasks
import UserNotifications
import Combine
import SwiftUI

@MainActor
class BackgroundSyncManager: ObservableObject {
    static let shared = BackgroundSyncManager()
    
    // Background task identifiers
    private let priceCheckTaskIdentifier = "com.rasuto.pricecheck"
    private let notificationSyncTaskIdentifier = "com.rasuto.notificationsync"
    
    // Publishers for real-time updates
    let priceUpdatePublisher = PassthroughSubject<ProductItem, Never>()
    let notificationPublisher = PassthroughSubject<NotificationItem, Never>()
    
    // Services
    // private var bestBuyTracker: BestBuyPriceTracker // REMOVED
    // eBay integration provided via SerpAPI
    private let cloudKitSyncManager = CloudKitSyncManager.shared
    
    // Sync intervals
    private let priceCheckInterval: TimeInterval = 3600 // 1 hour
    private let notificationSyncInterval: TimeInterval = 1800 // 30 minutes
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initialize services - All BestBuy services removed for production
        
        // eBay integration provided via SerpAPI
        
        setupBackgroundTasks()
        setupNotificationObservers()
    }
    
    // MARK: - Setup
    
    private func setupBackgroundTasks() {
        // Register background tasks
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: priceCheckTaskIdentifier,
            using: nil
        ) { task in
            self.handlePriceCheckTask(task: task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: notificationSyncTaskIdentifier,
            using: nil
        ) { task in
            self.handleNotificationSyncTask(task: task as! BGAppRefreshTask)
        }
    }
    
    private func setupNotificationObservers() {
        // REMOVED: BestBuy price tracking functionality
        
        // Observe eBay notifications
        // This would connect to actual webhook events in production
    }
    
    // MARK: - Background Task Scheduling
    
    func schedulePriceCheckTask() {
        let request = BGProcessingTaskRequest(identifier: priceCheckTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: priceCheckInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Price check task scheduled")
        } catch {
            print("Failed to schedule price check task: \(error)")
        }
    }
    
    func scheduleNotificationSyncTask() {
        let request = BGAppRefreshTaskRequest(identifier: notificationSyncTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: notificationSyncInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Notification sync task scheduled")
        } catch {
            print("Failed to schedule notification sync task: \(error)")
        }
    }
    
    // MARK: - Background Task Handlers
    
    private func handlePriceCheckTask(task: BGProcessingTask) {
        // Schedule the next task
        schedulePriceCheckTask()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = BlockOperation {
            self.performPriceCheck()
        }
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        queue.addOperation(operation)
    }
    
    private func handleNotificationSyncTask(task: BGAppRefreshTask) {
        // Schedule the next task
        scheduleNotificationSyncTask()
        
        Task {
            do {
                await syncNotifications()
                // Also sync CloudKit changes
                await cloudKitSyncManager.syncPendingChanges()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func performPriceCheck() {
        Task {
            // QUOTA PROTECTION: Check if we can make API requests
            if await shouldBlockAPIRequest(for: "background_price_check") {
                print("🛡️ Background price check blocked by quota protection")
                return
            }
            
            // Check BestBuy prices
            // await bestBuyTracker.refreshPrices() // REMOVED
            
            // Check eBay prices  
            // await ebayManager?.refreshTrackedItems() // Commented out - EbayNotificationManager disabled
            
            // Record API usage
            await QuotaProtectionManager.shared.recordAPIRequest()
        }
    }
    
    func syncNotifications() async {
        // Fetch latest notifications from all sources
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.syncBestBuyNotifications()
            }
            
            group.addTask {
                await self.syncEbayNotifications()
            }
        }
    }
    
    private func syncBestBuyNotifications() async {
        // QUOTA PROTECTION: Disabled to preserve API quota
        // Simulate fetching notifications from BestBuy
        // In production, this would make actual API calls
        print("🛡️ BestBuy notification sync disabled for quota protection")
    }
    
    private func syncEbayNotifications() async {
        // QUOTA PROTECTION: Disabled to preserve API quota
        // Simulate fetching notifications from eBay
        // In production, this would check webhook events
        print("🛡️ eBay notification sync disabled for quota protection")
    }
    
    // MARK: - Price Change Detection
    
    private func checkForPriceChanges(items: [ProductItem]) {
        for item in items where item.isTracked {
            if let previousPrice = item.priceHistory?.last?.price,
               item.currentPrice != previousPrice {
                
                let priceChange = item.currentPrice - previousPrice
                let percentageChange = (priceChange / previousPrice) * 100
                
                // Create notification for significant price changes
                if abs(percentageChange) >= 5 {
                    createPriceChangeNotification(
                        for: item,
                        previousPrice: previousPrice,
                        percentageChange: percentageChange
                    )
                }
                
                // Publish update
                priceUpdatePublisher.send(item)
            }
        }
    }
    
    // MARK: - Local Notifications
    
    private func createPriceChangeNotification(
        for item: ProductItem,
        previousPrice: Double,
        percentageChange: Double
    ) {
        let content = UNMutableNotificationContent()
        
        if percentageChange < 0 {
            content.title = "Price Drop Alert! 🎉"
            content.body = "\(item.name) dropped from $\(String(format: "%.2f", previousPrice)) to $\(String(format: "%.2f", item.currentPrice)) - Save \(abs(Int(percentageChange)))%!"
        } else {
            content.title = "Price Increase Alert"
            content.body = "\(item.name) increased from $\(String(format: "%.2f", previousPrice)) to $\(String(format: "%.2f", item.currentPrice))"
        }
        
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "PRICE_CHANGE"
        content.userInfo = [
            "productId": item.id.uuidString,
            "productName": item.name,
            "store": item.store
        ]
        
        // Create trigger (immediate notification)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
        
        // Also create in-app notification
        let notification = NotificationItem(
            title: percentageChange < 0 ? "Price Drop Alert!" : "Price Increase",
            message: content.body,
            type: NotificationTypeUI.priceDrop,
            source: item.store,
            productId: item.idString
        )
        
        notificationPublisher.send(notification)
    }
    
    // MARK: - Manual Sync
    
    func triggerManualSync() async {
        await syncNotifications()
        performPriceCheck()
    }
    
    // MARK: - Notification Permissions
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                print("Notification permissions granted")
                self.setupNotificationCategories()
            } else if let error = error {
                print("Error requesting notifications: \(error)")
            }
        }
    }
    
    private func setupNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_PRODUCT",
            title: "View Product",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )
        
        let priceChangeCategory = UNNotificationCategory(
            identifier: "PRICE_CHANGE",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([priceChangeCategory])
    }
}

// MARK: - App Integration

extension BackgroundSyncManager {
    func startBackgroundSync() {
        schedulePriceCheckTask()
        scheduleNotificationSyncTask()
        requestNotificationPermissions()
    }
    
    func stopBackgroundSync() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
}