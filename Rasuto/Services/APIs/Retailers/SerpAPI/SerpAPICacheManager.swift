//
//  SerpAPICacheManager.swift
//  Rasuto
//
//  Created for SerpAPI integration on 6/2/25.
//

import Foundation

// MARK: - SerpAPI Cache Manager

actor SerpAPICacheManager {
    
    static let shared = SerpAPICacheManager()
    
    // MARK: - Cache Storage
    
    private var searchCache: [String: CacheEntry<[ProductItemDTO]>] = [:]
    private var productCache: [String: CacheEntry<ProductItemDTO>] = [:]
    private var metadataCache: [String: CacheEntry<SearchMetadata>] = [:]
    
    // MARK: - Cache Configuration
    
    private let defaultTTL: TimeInterval = 1800 // 30 minutes
    private let searchTTL: TimeInterval = 900   // 15 minutes for search results
    private let productTTL: TimeInterval = 3600 // 1 hour for product details
    private let maxCacheSize = 1000 // Maximum number of entries per cache
    
    // MARK: - Integration with Unified Cache Manager
    
    private let unifiedCacheManager = UnifiedCacheManager.shared
    private let useUnifiedCache = true // Feature flag for gradual migration
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Cache Entry Model
    
    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let ttl: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
        
        init(value: T, ttl: TimeInterval) {
            self.value = value
            self.timestamp = Date()
            self.ttl = ttl
        }
    }
    
    // MARK: - Search Results Caching
    
    func getCachedSearchResults(for key: String) async -> [ProductItemDTO]? {
        // Try unified cache first if enabled
        if useUnifiedCache {
            let unifiedKey = "serpapi_search_\(key)"
            if let cachedResults: [ProductItemDTO] = await unifiedCacheManager.get(key: unifiedKey) {
                return cachedResults
            }
        }
        
        // Check local cache
        if let entry = searchCache[key], !entry.isExpired {
            return entry.value
        }
        
        // Clean up expired entry
        searchCache.removeValue(forKey: key)
        return nil
    }
    
    func cacheSearchResults(_ results: [ProductItemDTO], for key: String) async {
        let cacheKey = key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Cache in unified manager if enabled
        if useUnifiedCache {
            let unifiedKey = "serpapi_search_\(cacheKey)"
            await unifiedCacheManager.set(key: unifiedKey, value: results, ttl: searchTTL)
        }
        
        // Cache locally
        searchCache[cacheKey] = CacheEntry(value: results, ttl: searchTTL)
        
        // Manage cache size
        await cleanupCacheIfNeeded()
    }
    
    // MARK: - Product Details Caching
    
    func getCachedProduct(id: String) async -> ProductItemDTO? {
        // Try unified cache first if enabled
        if useUnifiedCache {
            let unifiedKey = "serpapi_product_\(id)"
            if let cachedProduct: ProductItemDTO = await unifiedCacheManager.get(key: unifiedKey) {
                return cachedProduct
            }
        }
        
        // Check local cache
        if let entry = productCache[id], !entry.isExpired {
            return entry.value
        }
        
        // Clean up expired entry
        productCache.removeValue(forKey: id)
        return nil
    }
    
    func cacheProduct(_ product: ProductItemDTO) async {
        let productId = product.sourceId
        
        // Cache in unified manager if enabled
        if useUnifiedCache {
            let unifiedKey = "serpapi_product_\(productId)"
            await unifiedCacheManager.set(key: unifiedKey, value: product, ttl: productTTL)
        }
        
        // Cache locally
        productCache[productId] = CacheEntry(value: product, ttl: productTTL)
        
        // Manage cache size
        await cleanupCacheIfNeeded()
    }
    
    // MARK: - Metadata Caching
    
    func getCachedMetadata(for key: String) async -> SearchMetadata? {
        if let entry = metadataCache[key], !entry.isExpired {
            return entry.value
        }
        
        // Clean up expired entry
        metadataCache.removeValue(forKey: key)
        return nil
    }
    
    func cacheMetadata(_ metadata: SearchMetadata, for key: String) async {
        metadataCache[key] = CacheEntry(value: metadata, ttl: defaultTTL)
        await cleanupCacheIfNeeded()
    }
    
    // MARK: - Cache Management
    
    func clearCache() async {
        searchCache.removeAll()
        productCache.removeAll()
        metadataCache.removeAll()
        
        print("🗑️ SerpAPI cache cleared")
    }
    
    func clearExpiredEntries() async {
        let initialSearchCount = searchCache.count
        let initialProductCount = productCache.count
        let initialMetadataCount = metadataCache.count
        
        // Remove expired search results
        searchCache = searchCache.filter { !$0.value.isExpired }
        
        // Remove expired products
        productCache = productCache.filter { !$0.value.isExpired }
        
        // Remove expired metadata
        metadataCache = metadataCache.filter { !$0.value.isExpired }
        
        let removedSearchCount = initialSearchCount - searchCache.count
        let removedProductCount = initialProductCount - productCache.count
        let removedMetadataCount = initialMetadataCount - metadataCache.count
        
        if removedSearchCount > 0 || removedProductCount > 0 || removedMetadataCount > 0 {
            print("🧹 SerpAPI cache cleanup: removed \(removedSearchCount) search, \(removedProductCount) product, \(removedMetadataCount) metadata entries")
        }
    }
    
    private func cleanupCacheIfNeeded() async {
        // Clean expired entries first
        await clearExpiredEntries()
        
        // If still over limit, remove oldest entries
        if searchCache.count > maxCacheSize {
            let sortedEntries = searchCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(searchCache.count - maxCacheSize)
            
            for (key, _) in entriesToRemove {
                searchCache.removeValue(forKey: key)
            }
        }
        
        if productCache.count > maxCacheSize {
            let sortedEntries = productCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(productCache.count - maxCacheSize)
            
            for (key, _) in entriesToRemove {
                productCache.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStatistics() async -> CacheStatistics {
        await clearExpiredEntries() // Clean before reporting stats
        
        return CacheStatistics(
            searchEntries: searchCache.count,
            productEntries: productCache.count,
            metadataEntries: metadataCache.count,
            totalEntries: searchCache.count + productCache.count + metadataCache.count,
            maxCacheSize: maxCacheSize
        )
    }
    
    struct CacheStatistics {
        let searchEntries: Int
        let productEntries: Int
        let metadataEntries: Int
        let totalEntries: Int
        let maxCacheSize: Int
        
        var utilizationPercentage: Double {
            return Double(totalEntries) / Double(maxCacheSize) * 100
        }
    }
    
    // MARK: - Retailer-Specific Cache Keys
    
    func generateSearchKey(query: String, engine: SerpAPIEngine, options: SerpAPISearchOptions? = nil) -> String {
        var key = "\(engine.rawValue)_\(query.lowercased())"
        
        if let options = options {
            key += "_\(options.location)_\(options.language)_\(options.country)"
        }
        
        return key.replacingOccurrences(of: " ", with: "_")
    }
    
    func generateProductKey(productId: String, engine: SerpAPIEngine) -> String {
        return "\(engine.rawValue)_\(productId)"
    }
    
    // MARK: - Preemptive Cache Warming
    
    func warmCache(with popularQueries: [String], engines: [SerpAPIEngine]) async {
        print("🔥 Warming SerpAPI cache with popular queries...")
        
        for query in popularQueries {
            for engine in engines {
                let key = generateSearchKey(query: query, engine: engine)
                
                // Only warm if not already cached
                if await getCachedSearchResults(for: key) == nil {
                    // This would trigger actual API calls in a real implementation
                    // For now, we just create placeholder entries to reserve space
                    print("📝 Cache key reserved: \(key)")
                }
            }
        }
    }
}