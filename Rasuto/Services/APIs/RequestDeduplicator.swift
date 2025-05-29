//
//  RequestDeduplicator.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation

// MARK: - Request Deduplication Actor

actor RequestDeduplicator {
    
    // MARK: - Properties
    
    private var ongoingRequests: [String: Task<AggregatedSearchResult, Error>] = [:]
    private var requestTimestamps: [String: Date] = [:]
    
    // MARK: - Configuration
    
    private let maxCacheTime: TimeInterval = 300 // 5 minutes
    private let cleanupInterval: TimeInterval = 60 // 1 minute
    
    // MARK: - Initialization
    
    init() {
        // Start cleanup task
        Task {
            await startCleanupTask()
        }
    }
    
    // MARK: - Deduplication Operations
    
    func getOngoingRequest(key: String) async -> Task<AggregatedSearchResult, Error>? {
        // Check if we have an ongoing request for this key
        if let existingTask = ongoingRequests[key] {
            // Check if the request is still valid (not too old)
            if let timestamp = requestTimestamps[key],
               Date().timeIntervalSince(timestamp) < maxCacheTime {
                print("🔄 Request deduplication HIT: \(key)")
                return existingTask
            } else {
                // Remove expired request
                ongoingRequests.removeValue(forKey: key)
                requestTimestamps.removeValue(forKey: key)
            }
        }
        
        print("❌ Request deduplication MISS: \(key)")
        return nil
    }
    
    func addOngoingRequest(key: String, task: Task<AggregatedSearchResult, Error>) async {
        ongoingRequests[key] = task
        requestTimestamps[key] = Date()
        print("➕ Added ongoing request: \(key)")
    }
    
    func removeOngoingRequest(key: String) async {
        ongoingRequests.removeValue(forKey: key)
        requestTimestamps.removeValue(forKey: key)
        print("➖ Removed ongoing request: \(key)")
    }
    
    func getStats() async -> DeduplicationStats {
        return DeduplicationStats(
            ongoingRequestCount: ongoingRequests.count,
            oldestRequestAge: getOldestRequestAge()
        )
    }
    
    func clear() async {
        // Cancel all ongoing requests
        for (_, task) in ongoingRequests {
            task.cancel()
        }
        
        ongoingRequests.removeAll()
        requestTimestamps.removeAll()
        print("🧹 Cleared all ongoing requests")
    }
    
    // MARK: - Private Methods
    
    private func startCleanupTask() async {
        while true {
            await cleanupExpiredRequests()
            
            // Wait for cleanup interval
            try? await Task.sleep(nanoseconds: UInt64(cleanupInterval * 1_000_000_000))
        }
    }
    
    private func cleanupExpiredRequests() async {
        let now = Date()
        var keysToRemove: [String] = []
        
        for (key, timestamp) in requestTimestamps {
            if now.timeIntervalSince(timestamp) > maxCacheTime {
                keysToRemove.append(key)
            }
        }
        
        for key in keysToRemove {
            if let task = ongoingRequests[key] {
                task.cancel()
            }
            ongoingRequests.removeValue(forKey: key)
            requestTimestamps.removeValue(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Cleaned up \(keysToRemove.count) expired requests")
        }
    }
    
    private func getOldestRequestAge() -> TimeInterval? {
        guard let oldestTimestamp = requestTimestamps.values.min() else {
            return nil
        }
        return Date().timeIntervalSince(oldestTimestamp)
    }
}

// MARK: - Supporting Types

struct DeduplicationStats {
    let ongoingRequestCount: Int
    let oldestRequestAge: TimeInterval?
}

// MARK: - Aggregated Search Result

struct AggregatedSearchResult: Codable {
    let query: String
    let products: [ProductItemDTO]
    let retailerResults: [String: [ProductItemDTO]]
    let errors: [String: String] // Simplified for Codable
    let totalResults: Int
    let processingTime: TimeInterval
    
    init(
        query: String,
        products: [ProductItemDTO],
        retailerResults: [String: [ProductItemDTO]],
        errors: [String: Error],
        totalResults: Int,
        processingTime: TimeInterval
    ) {
        self.query = query
        self.products = products
        self.retailerResults = retailerResults
        self.errors = errors.mapValues { $0.localizedDescription }
        self.totalResults = totalResults
        self.processingTime = processingTime
    }
}

// MARK: - Enriched Product Details

struct EnrichedProductDetails: Codable {
    let baseProduct: ProductItemDTO
    var crossRetailerPrices: [CrossRetailerPrice]
    var relatedProducts: [ProductItemDTO]
    var priceHistory: [PriceHistoryEntry]
    var availability: [String: Bool]
}

struct PriceHistoryEntry: Codable {
    let date: Date
    let price: Double
    let retailer: String
}

// MARK: - Request Key Generation

extension RequestDeduplicator {
    
    static func generateSearchKey(query: String, retailers: [String], options: SearchOptions) -> String {
        let retailerString = retailers.sorted().joined(separator: ",")
        let optionsString = "\(options.maxResults)_\(options.sortOrder)_\(options.filters.count)"
        return "search_\(query)_\(retailerString)_\(optionsString)".requestKeySHA256
    }
    
    static func generateDetailsKey(id: String, retailer: String, options: DetailOptions) -> String {
        let optionsString = "\(options.includeCrossRetailerComparison)_\(options.includeRelatedProducts)_\(options.includePriceHistory)"
        return "details_\(retailer)_\(id)_\(optionsString)".requestKeySHA256
    }
}

// MARK: - String Extension for Hashing

import CryptoKit

extension String {
    var requestKeySHA256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}