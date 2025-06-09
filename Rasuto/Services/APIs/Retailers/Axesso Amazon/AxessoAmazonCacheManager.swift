//
//  AxessoAmazonCacheManager.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 6/3/25.
//

import Foundation

// MARK: - Cache Manager for Axesso Amazon API

class AxessoAmazonCacheManager {
    
    // MARK: - Cache Configuration
    
    private let searchCacheExpiry: TimeInterval = 300 // 5 minutes
    private let productCacheExpiry: TimeInterval = 900 // 15 minutes
    private let reviewsCacheExpiry: TimeInterval = 1800 // 30 minutes
    private let pricesCacheExpiry: TimeInterval = 600 // 10 minutes
    
    // MARK: - Cache Storage
    
    private var searchCache = NSCache<NSString, CacheEntry<[ProductItemDTO]>>()
    private var productCache = NSCache<NSString, CacheEntry<ProductItemDTO>>()
    private var reviewsCache = NSCache<NSString, CacheEntry<AxessoAmazonReviewsResponse>>()
    private var pricesCache = NSCache<NSString, CacheEntry<AxessoAmazonPricesResponse>>()
    
    // MARK: - Cache Entry Wrapper
    
    private class CacheEntry<T> {
        let value: T
        let timestamp: Date
        
        init(value: T) {
            self.value = value
            self.timestamp = Date()
        }
        
        func isExpired(expiry: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > expiry
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupCacheConfiguration()
    }
    
    private func setupCacheConfiguration() {
        // Configure cache limits
        searchCache.countLimit = 100
        productCache.countLimit = 500
        reviewsCache.countLimit = 200
        pricesCache.countLimit = 300
        
        // Configure memory limits (in bytes)
        searchCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        productCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
        reviewsCache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
        pricesCache.totalCostLimit = 20 * 1024 * 1024 // 20 MB
    }
    
    // MARK: - Search Results Caching
    
    func getCachedSearchResults(for query: String) -> [ProductItemDTO]? {
        let key = NSString(string: "search_\(query.lowercased())")
        
        guard let entry = searchCache.object(forKey: key) else {
            return nil
        }
        
        if entry.isExpired(expiry: searchCacheExpiry) {
            searchCache.removeObject(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    func cacheSearchResults(_ products: [ProductItemDTO], for query: String) {
        let key = NSString(string: "search_\(query.lowercased())")
        let entry = CacheEntry(value: products)
        searchCache.setObject(entry, forKey: key)
    }
    
    // MARK: - Product Details Caching
    
    func getCachedProductDetails(for productId: String) -> ProductItemDTO? {
        let key = NSString(string: "product_\(productId)")
        
        guard let entry = productCache.object(forKey: key) else {
            return nil
        }
        
        if entry.isExpired(expiry: productCacheExpiry) {
            productCache.removeObject(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    func cacheProductDetails(_ product: ProductItemDTO, for productId: String) {
        let key = NSString(string: "product_\(productId)")
        let entry = CacheEntry(value: product)
        productCache.setObject(entry, forKey: key)
    }
    
    // MARK: - Reviews Caching
    
    func getCachedReviews(for productUrl: String, page: Int = 1) -> AxessoAmazonReviewsResponse? {
        let key = NSString(string: "reviews_\(productUrl)_page_\(page)")
        
        guard let entry = reviewsCache.object(forKey: key) else {
            return nil
        }
        
        if entry.isExpired(expiry: reviewsCacheExpiry) {
            reviewsCache.removeObject(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    func cacheReviews(_ reviews: AxessoAmazonReviewsResponse, for productUrl: String, page: Int = 1) {
        let key = NSString(string: "reviews_\(productUrl)_page_\(page)")
        let entry = CacheEntry(value: reviews)
        reviewsCache.setObject(entry, forKey: key)
    }
    
    // MARK: - Prices Caching
    
    func getCachedPrices(for productUrl: String) -> AxessoAmazonPricesResponse? {
        let key = NSString(string: "prices_\(productUrl)")
        
        guard let entry = pricesCache.object(forKey: key) else {
            return nil
        }
        
        if entry.isExpired(expiry: pricesCacheExpiry) {
            pricesCache.removeObject(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    func cachePrices(_ prices: AxessoAmazonPricesResponse, for productUrl: String) {
        let key = NSString(string: "prices_\(productUrl)")
        let entry = CacheEntry(value: prices)
        pricesCache.setObject(entry, forKey: key)
    }
    
    // MARK: - Cache Management
    
    func clearSearchCache() {
        searchCache.removeAllObjects()
    }
    
    func clearProductCache() {
        productCache.removeAllObjects()
    }
    
    func clearReviewsCache() {
        reviewsCache.removeAllObjects()
    }
    
    func clearPricesCache() {
        pricesCache.removeAllObjects()
    }
    
    func clearAllCache() {
        clearSearchCache()
        clearProductCache()
        clearReviewsCache()
        clearPricesCache()
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStats() -> AxessoAmazonCacheStats {
        return AxessoAmazonCacheStats(
            searchCacheCount: searchCache.countLimit,
            productCacheCount: productCache.countLimit,
            reviewsCacheCount: reviewsCache.countLimit,
            pricesCacheCount: pricesCache.countLimit
        )
    }
}

// MARK: - Cache Statistics Model

struct AxessoAmazonCacheStats {
    let searchCacheCount: Int
    let productCacheCount: Int
    let reviewsCacheCount: Int
    let pricesCacheCount: Int
    
    var totalCacheCount: Int {
        searchCacheCount + productCacheCount + reviewsCacheCount + pricesCacheCount
    }
}