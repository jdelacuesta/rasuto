//
//  OxylabsCacheManager.swift
//  Rasuto
//
//  Created for Oxylabs Web Scraper API caching on 6/4/25.
//

import Foundation

// MARK: - Oxylabs Cache Manager

actor OxylabsCacheManager {
    
    // MARK: - Cache Configuration
    
    private var productCache: [String: CachedProductList] = [:]
    private var individualProductCache: [String: CachedProduct] = [:]
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    private let maxCacheSize = 100 // Maximum cached search results
    private let maxIndividualCacheSize = 500 // Maximum individual products
    
    // MARK: - Cache Statistics
    
    private var cacheHits = 0
    private var cacheMisses = 0
    private var totalRequests = 0
    
    // MARK: - Initialization
    
    init() {
        loadPersistedCache()
        
        // Schedule periodic cleanup
        Task {
            await schedulePeriodicCleanup()
        }
    }
    
    // MARK: - Product List Caching
    
    func getCachedProducts(for key: String) async -> [ProductItemDTO]? {
        totalRequests += 1
        
        guard let cachedList = productCache[key] else {
            cacheMisses += 1
            return nil
        }
        
        // Check expiration
        if Date().timeIntervalSince(cachedList.timestamp) > cacheExpirationInterval {
            productCache.removeValue(forKey: key)
            cacheMisses += 1
            await persistCache()
            return nil
        }
        
        cacheHits += 1
        print("🎯 Oxylabs Cache: Hit for key '\(key)' - \(cachedList.products.count) products")
        return cachedList.products
    }
    
    func cacheProducts(_ products: [ProductItemDTO], for key: String) async {
        // Enforce cache size limit
        if productCache.count >= maxCacheSize {
            await evictOldestEntries()
        }
        
        let cachedList = CachedProductList(
            products: products,
            timestamp: Date(),
            key: key
        )
        
        productCache[key] = cachedList
        await persistCache()
        
        print("💾 Oxylabs Cache: Stored \(products.count) products for key '\(key)'")
    }
    
    // MARK: - Individual Product Caching
    
    func getCachedProduct(for url: String) async -> ProductItemDTO? {
        totalRequests += 1
        
        guard let cachedProduct = individualProductCache[url] else {
            cacheMisses += 1
            return nil
        }
        
        // Check expiration
        if Date().timeIntervalSince(cachedProduct.timestamp) > cacheExpirationInterval {
            individualProductCache.removeValue(forKey: url)
            cacheMisses += 1
            await persistCache()
            return nil
        }
        
        cacheHits += 1
        print("🎯 Oxylabs Cache: Hit for product URL '\(url)'")
        return cachedProduct.product
    }
    
    func cacheProduct(_ product: ProductItemDTO, for url: String) async {
        // Enforce cache size limit
        if individualProductCache.count >= maxIndividualCacheSize {
            await evictOldestIndividualEntries()
        }
        
        let cachedProduct = CachedProduct(
            product: product,
            timestamp: Date(),
            url: url
        )
        
        individualProductCache[url] = cachedProduct
        await persistCache()
        
        print("💾 Oxylabs Cache: Stored product for URL '\(url)'")
    }
    
    // MARK: - Cache Management
    
    func clearCache() async {
        productCache.removeAll()
        individualProductCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
        totalRequests = 0
        
        await persistCache()
        print("🧹 Oxylabs Cache: Cleared all cache data")
    }
    
    func clearExpiredEntries() async {
        let now = Date()
        let initialProductCount = productCache.count
        let initialIndividualCount = individualProductCache.count
        
        // Clean product lists
        productCache = productCache.filter { _, cachedList in
            now.timeIntervalSince(cachedList.timestamp) <= cacheExpirationInterval
        }
        
        // Clean individual products
        individualProductCache = individualProductCache.filter { _, cachedProduct in
            now.timeIntervalSince(cachedProduct.timestamp) <= cacheExpirationInterval
        }
        
        let removedProductLists = initialProductCount - productCache.count
        let removedIndividualProducts = initialIndividualCount - individualProductCache.count
        
        if removedProductLists > 0 || removedIndividualProducts > 0 {
            await persistCache()
            print("🧹 Oxylabs Cache: Cleaned \(removedProductLists) product lists, \(removedIndividualProducts) individual products")
        }
    }
    
    private func evictOldestEntries() async {
        let sortedEntries = productCache.sorted { $0.value.timestamp < $1.value.timestamp }
        let entriesToRemove = sortedEntries.prefix(productCache.count - maxCacheSize + 1)
        
        for (key, _) in entriesToRemove {
            productCache.removeValue(forKey: key)
        }
        
        print("🧹 Oxylabs Cache: Evicted \(entriesToRemove.count) oldest product list entries")
    }
    
    private func evictOldestIndividualEntries() async {
        let sortedEntries = individualProductCache.sorted { $0.value.timestamp < $1.value.timestamp }
        let entriesToRemove = sortedEntries.prefix(individualProductCache.count - maxIndividualCacheSize + 1)
        
        for (key, _) in entriesToRemove {
            individualProductCache.removeValue(forKey: key)
        }
        
        print("🧹 Oxylabs Cache: Evicted \(entriesToRemove.count) oldest individual product entries")
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStatistics() async -> CacheStatistics {
        let hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) * 100 : 0
        
        return CacheStatistics(
            totalRequests: totalRequests,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            hitRate: hitRate,
            productListCacheSize: productCache.count,
            individualProductCacheSize: individualProductCache.count,
            maxProductListCacheSize: maxCacheSize,
            maxIndividualProductCacheSize: maxIndividualCacheSize
        )
    }
    
    struct CacheStatistics {
        let totalRequests: Int
        let cacheHits: Int
        let cacheMisses: Int
        let hitRate: Double
        let productListCacheSize: Int
        let individualProductCacheSize: Int
        let maxProductListCacheSize: Int
        let maxIndividualProductCacheSize: Int
        
        var summary: String {
            return "Hit Rate: \(String(format: "%.1f", hitRate))%, Lists: \(productListCacheSize)/\(maxProductListCacheSize), Products: \(individualProductCacheSize)/\(maxIndividualProductCacheSize)"
        }
    }
    
    // MARK: - Periodic Cleanup
    
    private func schedulePeriodicCleanup() async {
        while true {
            try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
            await clearExpiredEntries()
        }
    }
    
    // MARK: - Persistence
    
    private func persistCache() async {
        let cacheData = CacheData(
            productCache: productCache,
            individualProductCache: individualProductCache,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            totalRequests: totalRequests
        )
        
        if let encoded = try? JSONEncoder().encode(cacheData) {
            UserDefaults.standard.set(encoded, forKey: "oxylabs_cache_data")
        }
    }
    
    private func loadPersistedCache() {
        guard let data = UserDefaults.standard.data(forKey: "oxylabs_cache_data"),
              let cacheData = try? JSONDecoder().decode(CacheData.self, from: data) else {
            return
        }
        
        productCache = cacheData.productCache
        individualProductCache = cacheData.individualProductCache
        cacheHits = cacheData.cacheHits
        cacheMisses = cacheData.cacheMisses
        totalRequests = cacheData.totalRequests
        
        print("📂 Oxylabs Cache: Loaded cache data - \(productCache.count) product lists, \(individualProductCache.count) individual products")
        
        // Clean expired entries on load
        Task {
            await clearExpiredEntries()
        }
    }
    
    // MARK: - Cache Data Models
    
    private struct CachedProductList: Codable {
        let products: [ProductItemDTO]
        let timestamp: Date
        let key: String
    }
    
    private struct CachedProduct: Codable {
        let product: ProductItemDTO
        let timestamp: Date
        let url: String
    }
    
    private struct CacheData: Codable {
        let productCache: [String: CachedProductList]
        let individualProductCache: [String: CachedProduct]
        let cacheHits: Int
        let cacheMisses: Int
        let totalRequests: Int
    }
    
    // MARK: - Advanced Cache Operations
    
    func getCacheKeys() async -> [String] {
        return Array(productCache.keys)
    }
    
    func getCachedProductUrls() async -> [String] {
        return Array(individualProductCache.keys)
    }
    
    func removeCachedEntry(for key: String) async {
        productCache.removeValue(forKey: key)
        await persistCache()
        print("🗑️ Oxylabs Cache: Removed entry for key '\(key)'")
    }
    
    func removeCachedProduct(for url: String) async {
        individualProductCache.removeValue(forKey: url)
        await persistCache()
        print("🗑️ Oxylabs Cache: Removed product for URL '\(url)'")
    }
    
    func warmCache(with preloadData: [String: [ProductItemDTO]]) async {
        for (key, products) in preloadData {
            await cacheProducts(products, for: key)
        }
        print("🔥 Oxylabs Cache: Warmed cache with \(preloadData.count) entries")
    }
    
    func getCacheSize() async -> Int {
        let productListSize = productCache.values.reduce(0) { $0 + $1.products.count }
        let individualProductSize = individualProductCache.count
        return productListSize + individualProductSize
    }
}