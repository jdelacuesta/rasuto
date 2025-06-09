//
//  UnifiedCacheManager.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation

// MARK: - Unified Cache Manager Actor

actor UnifiedCacheManager {
    
    static let shared = UnifiedCacheManager()
    
    // MARK: - Properties
    
    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let diskCache: DiskCache
    private let cacheQueue = DispatchQueue(label: "cache.queue", qos: .utility)
    
    // MARK: - Configuration
    
    private let memoryLimitMB: Int = 50
    private let diskLimitMB: Int = 200
    private let defaultTTL: TimeInterval = 3600 // 1 hour
    
    // MARK: - Initialization
    
    private init() {
        self.diskCache = DiskCache()
        configureMemoryCache()
    }
    
    private func configureMemoryCache() {
        memoryCache.totalCostLimit = memoryLimitMB * 1024 * 1024 // Convert to bytes
        memoryCache.countLimit = 1000 // Maximum number of items
    }
    
    // MARK: - Cache Operations
    
    func get<T: Codable>(key: String, type: T.Type = T.self) async -> T? {
        let cacheKey = NSString(string: key)
        
        // Step 1: Check memory cache first
        if let entry = memoryCache.object(forKey: cacheKey) {
            if entry.isValid {
                if let object = try? JSONDecoder().decode(T.self, from: entry.data) {
                    print("🔥 Cache HIT (Memory): \(key)")
                    return object
                }
            } else {
                // Remove expired entry
                memoryCache.removeObject(forKey: cacheKey)
            }
        }
        
        // Step 2: Check disk cache
        if let diskEntry = await diskCache.get(key: key) {
            if diskEntry.isValid {
                if let object = try? JSONDecoder().decode(T.self, from: diskEntry.data) {
                    print("💽 Cache HIT (Disk): \(key)")
                    
                    // Promote to memory cache
                    let memoryCacheEntry = CacheEntry(
                        data: diskEntry.data,
                        expirationDate: diskEntry.expirationDate,
                        size: diskEntry.size
                    )
                    memoryCache.setObject(memoryCacheEntry, forKey: cacheKey, cost: diskEntry.size)
                    
                    return object
                }
            } else {
                // Remove expired disk entry
                await diskCache.remove(key: key)
            }
        }
        
        print("❌ Cache MISS: \(key)")
        return nil
    }
    
    func set<T: Codable>(key: String, value: T, ttl: TimeInterval? = nil) async {
        let actualTTL = ttl ?? defaultTTL
        let expirationDate = Date().addingTimeInterval(actualTTL)
        
        guard let data = try? JSONEncoder().encode(value) else {
            print("❌ Failed to encode cache value for key: \(key)")
            return
        }
        
        let entry = CacheEntry(
            data: data,
            expirationDate: expirationDate,
            size: data.count
        )
        
        // Store in memory cache
        let cacheKey = NSString(string: key)
        memoryCache.setObject(entry, forKey: cacheKey, cost: data.count)
        
        // Store in disk cache asynchronously
        await diskCache.set(key: key, entry: entry)
        
        print("💾 Cache SET: \(key) (TTL: \(actualTTL)s)")
    }
    
    func remove(key: String) async {
        let cacheKey = NSString(string: key)
        memoryCache.removeObject(forKey: cacheKey)
        await diskCache.remove(key: key)
        print("🗑️ Cache REMOVE: \(key)")
    }
    
    func removeExpired() async {
        // Clean memory cache
        memoryCache.removeAllObjects()
        
        // Clean disk cache
        await diskCache.removeExpired()
        
        print("🧹 Cleaned expired cache entries")
    }
    
    func clear() async {
        memoryCache.removeAllObjects()
        await diskCache.clear()
        print("🧹 Cache CLEARED")
    }
    
    // MARK: - Cache Statistics
    
    func getStats() async -> UnifiedCacheStats {
        let memoryCount = memoryCache.totalCostLimit
        let diskStats = await diskCache.getStats()
        
        return UnifiedCacheStats(
            memoryCount: memoryCount,
            diskCount: diskStats.entryCount,
            memorySize: memoryCache.totalCostLimit,
            diskSize: diskStats.totalSize
        )
    }
}

// MARK: - Cache Entry

class CacheEntry: NSObject {
    let data: Data
    let expirationDate: Date
    let size: Int
    
    init(data: Data, expirationDate: Date, size: Int) {
        self.data = data
        self.expirationDate = expirationDate
        self.size = size
        super.init()
    }
    
    var isValid: Bool {
        return Date() < expirationDate
    }
}

// MARK: - Disk Cache Actor

actor DiskCache {
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        // Create cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("RasutoAPICache")
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func set(key: String, entry: CacheEntry) async {
        let url = fileURL(for: key)
        
        do {
            let metadata = CacheMetadata(
                expirationDate: entry.expirationDate,
                size: entry.size
            )
            
            let container = CacheContainer(data: entry.data, metadata: metadata)
            let encodedData = try JSONEncoder().encode(container)
            
            try encodedData.write(to: url)
        } catch {
            print("❌ Failed to write cache to disk: \(error)")
        }
    }
    
    func get(key: String) async -> CacheEntry? {
        let url = fileURL(for: key)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let container = try JSONDecoder().decode(CacheContainer.self, from: data)
            
            return CacheEntry(
                data: container.data,
                expirationDate: container.metadata.expirationDate,
                size: container.metadata.size
            )
        } catch {
            // Remove corrupted file
            try? fileManager.removeItem(at: url)
            return nil
        }
    }
    
    func remove(key: String) async {
        let url = fileURL(for: key)
        try? fileManager.removeItem(at: url)
    }
    
    func removeExpired() async {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        let now = Date()
        
        for case let fileURL as URL in enumerator {
            if let entry = await get(key: keyFromURL(fileURL)) {
                if now >= entry.expirationDate {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }
    
    func clear() async {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    func getStats() async -> DiskCacheStats {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return DiskCacheStats(entryCount: 0, totalSize: 0)
        }
        
        var entryCount = 0
        var totalSize = 0
        
        for case let fileURL as URL in enumerator {
            entryCount += 1
            
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += fileSize
            }
        }
        
        return DiskCacheStats(entryCount: entryCount, totalSize: totalSize)
    }
    
    // MARK: - Private Helpers
    
    private func fileURL(for key: String) -> URL {
        let hashedKey = key.cacheKeySHA256
        return cacheDirectory.appendingPathComponent(hashedKey)
    }
    
    private func keyFromURL(_ url: URL) -> String {
        return url.lastPathComponent
    }
}

// MARK: - Supporting Types

struct CacheContainer: Codable {
    let data: Data
    let metadata: CacheMetadata
}

struct CacheMetadata: Codable {
    let expirationDate: Date
    let size: Int
}

struct UnifiedCacheStats {
    let memoryCount: Int
    let diskCount: Int
    let memorySize: Int
    let diskSize: Int
}

struct DiskCacheStats {
    let entryCount: Int
    let totalSize: Int
}

// MARK: - String Extension for Cache Keys

import CryptoKit

extension String {
    var cacheKeySHA256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}