//
//  CloudKitSyncManager.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData
import CloudKit
import Network

// MARK: - CloudKit Sync Manager

actor CloudKitSyncManager {
    
    static let shared = CloudKitSyncManager()
    
    // MARK: - Properties
    
    private let container = CKContainer(identifier: "iCloud.com.Rasuto")
    private let privateDB: CKDatabase
    private let networkMonitor = NWPathMonitor()
    private var isConnected = true
    
    // MARK: - Sync Configuration
    
    private let syncBatchSize = 50
    private let maxRetryAttempts = 3
    
    // MARK: - Initialization
    
    private init() {
        self.privateDB = container.privateCloudDatabase
        startNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task {
                await self?.updateNetworkStatus(path.status == .satisfied)
            }
        }
        
        let queue = DispatchQueue(label: "CloudKitSyncNetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func updateNetworkStatus(_ connected: Bool) async {
        isConnected = connected
        print("🌐 CloudKit Sync - Network status: \(connected ? "Connected" : "Disconnected")")
        
        if connected {
            await performPendingSync()
        }
    }
    
    // MARK: - Sync Operations
    
    func syncPendingChanges() async {
        guard isConnected else {
            print("📴 CloudKit Sync - No network connection, queuing for later")
            return
        }
        
        await performPendingSync()
    }
    
    private func performPendingSync() async {
        guard let container = ModelContainerManager.shared.container else {
            print("❌ CloudKit Sync - No model container available")
            return
        }
        
        let context = ModelContext(container)
        
        do {
            // Fetch items that need syncing (pending = 0)
            var descriptor = FetchDescriptor<ProductItem>(
                predicate: #Predicate { item in item.syncStatus == 0 }
            )
            descriptor.fetchLimit = syncBatchSize
            
            let pendingItems = try context.fetch(descriptor)
            
            if !pendingItems.isEmpty {
                print("🔄 CloudKit Sync - Syncing \(pendingItems.count) items")
                await syncItems(pendingItems, context: context)
            }
            
        } catch {
            print("❌ CloudKit Sync - Failed to fetch pending items: \(error)")
        }
    }
    
    private func syncItems(_ items: [ProductItem], context: ModelContext) async {
        for item in items {
            await syncSingleItem(item, context: context)
        }
    }
    
    private func syncSingleItem(_ item: ProductItem, context: ModelContext) async {
        do {
            item.currentSyncStatus = .syncing
            
            // Create or update CloudKit record
            let record = try await createCloudKitRecord(from: item)
            let savedRecord = try await privateDB.save(record)
            
            // Update local item with CloudKit info
            item.cloudKitRecordID = savedRecord.recordID.recordName
            item.lastSyncDate = Date()
            item.currentSyncStatus = .synced
            
            try context.save()
            print("✅ CloudKit Sync - Successfully synced item: \(item.name)")
            
        } catch {
            item.currentSyncStatus = .failed
            try? context.save()
            print("❌ CloudKit Sync - Failed to sync item \(item.name): \(error)")
        }
    }
    
    private func createCloudKitRecord(from item: ProductItem) async throws -> CKRecord {
        let recordID: CKRecord.ID
        
        if let existingRecordIDString = item.cloudKitRecordID {
            recordID = CKRecord.ID(recordName: existingRecordIDString)
        } else {
            recordID = CKRecord.ID(recordName: UUID().uuidString)
        }
        
        let record = CKRecord(recordType: "ProductItem", recordID: recordID)
        
        // Map ProductItem properties to CloudKit record
        record["name"] = item.name
        record["productDescription"] = item.productDescription
        record["price"] = item.price
        record["currency"] = item.currency
        record["brand"] = item.brand
        record["source"] = item.source
        record["sourceId"] = item.sourceId
        record["category"] = item.category
        record["isInStock"] = item.isInStock
        record["isFavorite"] = item.isFavorite
        record["isTracked"] = item.isTracked
        record["addedDate"] = item.addedDate
        record["lastChecked"] = item.lastChecked
        record["rating"] = item.rating
        record["reviewCount"] = item.reviewCount
        
        // Handle optional fields
        if let url = item.url {
            record["url"] = url.absoluteString
        }
        if let imageURL = item.imageURL {
            record["imageURL"] = imageURL.absoluteString
        }
        if let thumbnailUrl = item.thumbnailUrl {
            record["thumbnailUrl"] = thumbnailUrl
        }
        
        // Handle arrays
        record["imageUrls"] = item.imageUrls
        
        return record
    }
    
    // MARK: - Fetch Remote Changes
    
    func fetchRemoteChanges(since date: Date) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "modificationDate > %@", date as NSDate)
        let query = CKQuery(recordType: "ProductItem", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        let (matchResults, _) = try await privateDB.records(matching: query)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("❌ CloudKit Sync - Failed to fetch record: \(error)")
            }
        }
        
        return records
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflicts() async {
        // Implement conflict resolution strategy
        // For now, server wins (last writer wins)
        print("🔄 CloudKit Sync - Resolving conflicts (server wins strategy)")
    }
    
    // MARK: - Sync Status
    
    func getSyncStats() async -> (pending: Int, synced: Int, failed: Int) {
        guard let container = ModelContainerManager.shared.container else {
            return (0, 0, 0)
        }
        
        let context = ModelContext(container)
        
        do {
            let pendingCount = try context.fetchCount(FetchDescriptor<ProductItem>(
                predicate: #Predicate { item in item.syncStatus == 0 }
            ))
            
            let syncedCount = try context.fetchCount(FetchDescriptor<ProductItem>(
                predicate: #Predicate { item in item.syncStatus == 2 }
            ))
            
            let failedCount = try context.fetchCount(FetchDescriptor<ProductItem>(
                predicate: #Predicate { item in item.syncStatus == 3 }
            ))
            
            return (pending: pendingCount, synced: syncedCount, failed: failedCount)
            
        } catch {
            print("❌ CloudKit Sync - Failed to get sync stats: \(error)")
            return (0, 0, 0)
        }
    }
    
    // MARK: - Manual Sync Trigger
    
    func forceSyncAll() async {
        guard let container = ModelContainerManager.shared.container else { return }
        
        let context = ModelContext(container)
        
        do {
            // Mark all items as pending sync
            let descriptor = FetchDescriptor<ProductItem>()
            let allItems = try context.fetch(descriptor)
            
            for item in allItems {
                item.currentSyncStatus = .pending
            }
            
            try context.save()
            await performPendingSync()
            
        } catch {
            print("❌ CloudKit Sync - Failed to force sync all: \(error)")
        }
    }
}

// MARK: - CloudKit Subscription Manager

extension CloudKitSyncManager {
    
    func setupPushNotifications() async {
        do {
            // Create subscription for ProductItem changes
            let subscription = CKQuerySubscription(
                recordType: "ProductItem",
                predicate: NSPredicate(value: true),
                subscriptionID: "ProductItemChanges"
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            _ = try await privateDB.save(subscription)
            print("✅ CloudKit Sync - Push notifications setup completed")
            
        } catch {
            print("❌ CloudKit Sync - Failed to setup push notifications: \(error)")
        }
    }
}