//
//  PersistentProductCache.swift
//  Rasuto
//
//  Created by Claude on 6/5/25.
//

import Foundation

/// Persistent cache for products across app sessions
/// Stores all products we've encountered for instant trending display
class PersistentProductCache {
    static let shared = PersistentProductCache()
    
    private let fileManager = FileManager.default
    private let cacheFileName = "persistent_product_cache.json"
    private var cachedProducts: [ProductItem] = []
    private let maxCacheSize = 200 // Maximum products to keep
    
    private var cacheFileURL: URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(cacheFileName)
    }
    
    private init() {
        loadCacheFromDisk()
    }
    
    // MARK: - Public Interface
    
    /// Add new products to persistent cache (ProductItem array)
    func addProducts(_ products: [ProductItem]) async {
        await MainActor.run {
            // Add new products, avoiding duplicates
            for product in products {
                if !cachedProducts.contains(where: { $0.sourceId == product.sourceId && $0.source == product.source }) {
                    cachedProducts.append(product)
                }
            }
            
            // Keep only most recent products if cache gets too large
            if cachedProducts.count > maxCacheSize {
                cachedProducts = Array(cachedProducts.suffix(maxCacheSize))
            }
            
            // Save to disk
            saveCacheToDisk()
        }
    }
    
    /// Get random products from cache for instant display
    func getRandomProducts(count: Int = 4) -> [ProductItem] {
        guard !cachedProducts.isEmpty else { return [] }
        
        // Shuffle and return requested count
        let shuffled = cachedProducts.shuffled()
        return Array(shuffled.prefix(count))
    }
    
    /// Get all cached products
    func getAllProducts() -> [ProductItem] {
        return cachedProducts
    }
    
    /// Check if cache has products
    var hasProducts: Bool {
        return !cachedProducts.isEmpty
    }
    
    /// Get count of cached products
    var productCount: Int {
        return cachedProducts.count
    }
    
    // MARK: - Disk Persistence
    
    private func loadCacheFromDisk() {
        guard let cacheFileURL = cacheFileURL,
              fileManager.fileExists(atPath: cacheFileURL.path) else {
            print("📱 PersistentCache: No existing cache file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let cachedDTOs = try decoder.decode([ProductItemDTO].self, from: data)
            cachedProducts = cachedDTOs.map { ProductItem.from($0) }
            
            print("📱 PersistentCache: Loaded \(cachedProducts.count) products from disk")
        } catch {
            print("📱 PersistentCache: Failed to load cache: \(error)")
            cachedProducts = []
        }
    }
    
    private func saveCacheToDisk() {
        guard let cacheFileURL = cacheFileURL else {
            print("📱 PersistentCache: Cannot get cache file URL")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let dtos = cachedProducts.map { ProductItemDTO.from($0) }
            let data = try encoder.encode(dtos)
            
            try data.write(to: cacheFileURL)
            print("📱 PersistentCache: Saved \(cachedProducts.count) products to disk")
        } catch {
            print("📱 PersistentCache: Failed to save cache: \(error)")
        }
    }
    
    // MARK: - Management
    
    /// Clear all cached products
    func clearCache() {
        cachedProducts.removeAll()
        saveCacheToDisk()
        print("📱 PersistentCache: Cache cleared")
    }
    
    /// Add new products to persistent cache (ProductItemDTO array)
    func addProducts(_ productDTOs: [ProductItemDTO]) async {
        let products = productDTOs.map { ProductItem.from($0) }
        await addProducts(products)
    }
    
    /// Add single product to cache (for search results)
    func addProduct(_ product: ProductItem) async {
        await addProducts([product])
    }
}