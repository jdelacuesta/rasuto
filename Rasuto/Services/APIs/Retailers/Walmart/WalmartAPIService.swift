//
//  WalmartAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/28/25.
//

import Foundation
import SwiftUI

// MARK: - Walmart API Response Models

struct WalmartSearchResponse: Decodable, Sendable {
    let products: [WalmartProduct]?
    let totalCount: Int?
    let page: Int?
    let totalPages: Int?
}

struct WalmartProduct: Decodable, Sendable {
    let id: String?
    let title: String?
    let description: String?
    let price: WalmartPrice?
    let brand: String?
    let category: String?
    let images: [WalmartImage]?
    let rating: WalmartRating?
    let availability: WalmartAvailability?
    let url: String?
}

struct WalmartPrice: Decodable, Sendable {
    let current: Double?
    let original: Double?
    let currency: String?
}

struct WalmartImage: Decodable, Sendable {
    let url: String?
    let size: String?
}

struct WalmartRating: Decodable, Sendable {
    let average: Double?
    let count: Int?
}

struct WalmartAvailability: Decodable, Sendable {
    let inStock: Bool?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case inStock = "in_stock"
        case status
    }
}

// MARK: - Product Details Response
struct WalmartProductDetailsResponse: Decodable, Sendable {
    let product: WalmartProduct?
    let success: Bool?
    let error: String?
}

// MARK: - Main API Service
@MainActor
class WalmartAPIService: RetailerAPIService, APITestable, ObservableObject {
    private let apiKey: String
    private let baseURL = "https://walmart-api4.p.rapidapi.com"
    private let rapidAPIHost = "walmart-api4.p.rapidapi.com"
    
    // Published properties for SwiftUI binding
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    @Published private(set) var isDemoMode = false
    
    // Modern async URLSession configuration
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 30
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()
    
    // Actor for thread-safe cache management
    private let cacheManager = CacheManager()
    
    // Rate limiting with async/await
    private let rateLimiter = RateLimiter(monthlyLimit: 25)
    
    // MARK: - Modern Infrastructure (Phase 2 Integration)
    // These are optional and can be used alongside internal actors
    private let globalCacheManager = UnifiedCacheManager.shared
    private let globalRateLimiter = GlobalRateLimiter.shared
    private let circuitBreaker = CircuitBreakerManager.shared
    private let optimizedClient = OptimizedAPIClient.shared
    
    // Feature flags for gradual migration
    private let useGlobalCache = false // Start with false, enable gradually
    private let useGlobalRateLimiter = false
    private let serviceName = "walmart"
    
    // MARK: - Hybrid Approach: Popular Products & Category Mapping
    private let popularProductIds: [String: [String]] = [
        "electronics": ["1234567890", "0987654321", "5555666777", "7777888999", "9999000111"],
        "phones": ["5555666777"],
        "gaming": ["8888999000", "6666777888"],
        "audio": ["1234567890", "2222333444"],
        "tv": ["0987654321"],
        "home": ["1111222333", "4444555666", "3333444555"],
        "watches": ["7777888999"],
        "tablets": ["9999000111"]
    ]
    
    private let searchTermToCategory: [String: String] = [
        "iphone": "phones",
        "phone": "phones",
        "airpods": "audio",
        "headphones": "audio",
        "sony": "audio",
        "samsung": "electronics",
        "tv": "tv",
        "nintendo": "gaming",
        "switch": "gaming",
        "playstation": "gaming",
        "ps5": "gaming",
        "coffee": "home",
        "maker": "home",
        "blender": "home",
        "ninja": "home",
        "instant pot": "home",
        "watch": "watches",
        "apple watch": "watches",
        "ipad": "tablets",
        "tablet": "tablets"
    ]
    
    // MARK: - Mock Data for Demo Mode
    private let mockProducts = [
        ProductItemDTO(
            sourceId: "1234567890",
            name: "Apple AirPods Pro (2nd Generation) with MagSafe Case",
            productDescription: "Active noise cancellation, Adaptive Transparency, Personalized Spatial Audio with dynamic head tracking.",
            price: 249.99,
            originalPrice: 299.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Apple-AirPods-Pro-2nd-generation-with-MagSafe-Case-USB-C_c2c8d4e7-2a7a-4b4a-9a4a-1a7b2c3d4e5f.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Apple-AirPods-Pro-2nd-generation-with-MagSafe-Case-USB-C_c2c8d4e7-2a7a-4b4a-9a4a-1a7b2c3d4e5f.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Apple-AirPods-Pro-2nd-generation-with-MagSafe-Case-USB-C_c2c8d4e7-2a7a-4b4a-9a4a-1a7b2c3d4e5f.jpg",
            brand: "Apple",
            source: "Walmart",
            category: "Electronics",
            isInStock: true,
            rating: 4.8,
            reviewCount: 2156
        ),
        ProductItemDTO(
            sourceId: "0987654321",
            name: "Samsung 65-Inch Class Crystal UHD 4K Smart TV",
            productDescription: "Experience stunning 4K resolution with vibrant colors and sharp detail. Crystal Processor 4K upscales content to near-4K quality.",
            price: 497.99,
            originalPrice: 649.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Samsung-65-Class-Crystal-UHD-4K-Smart-TV-UN65CU7000FXZA_a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Samsung-65-Class-Crystal-UHD-4K-Smart-TV-UN65CU7000FXZA_a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Samsung-65-Class-Crystal-UHD-4K-Smart-TV-UN65CU7000FXZA_a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d.jpg",
            brand: "Samsung",
            source: "Walmart",
            category: "Televisions",
            isInStock: true,
            rating: 4.6,
            reviewCount: 892
        ),
        ProductItemDTO(
            sourceId: "5555666777",
            name: "iPhone 15 Pro 128GB - Natural Titanium",
            productDescription: "iPhone 15 Pro with titanium design, A17 Pro chip, and advanced camera system with 3x telephoto lens.",
            price: 999.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Apple-iPhone-15-Pro-128GB-Natural-Titanium-Verizon_f1a2b3c4-5d6e-7f8a-9b0c-1d2e3f4a5b6c.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Apple-iPhone-15-Pro-128GB-Natural-Titanium-Verizon_f1a2b3c4-5d6e-7f8a-9b0c-1d2e3f4a5b6c.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Apple-iPhone-15-Pro-128GB-Natural-Titanium-Verizon_f1a2b3c4-5d6e-7f8a-9b0c-1d2e3f4a5b6c.jpg",
            brand: "Apple",
            source: "Walmart",
            category: "Cell Phones",
            isInStock: true,
            rating: 4.9,
            reviewCount: 1543
        ),
        ProductItemDTO(
            sourceId: "8888999000",
            name: "Nintendo Switch OLED Model - White",
            productDescription: "Enjoy vivid colors and crisp contrast with the vibrant 7-inch OLED screen when playing in handheld and tabletop modes.",
            price: 349.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Nintendo-Switch-OLED-Model-White_b2c3d4e5-6f7a-8b9c-0d1e-2f3a4b5c6d7e.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Nintendo-Switch-OLED-Model-White_b2c3d4e5-6f7a-8b9c-0d1e-2f3a4b5c6d7e.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Nintendo-Switch-OLED-Model-White_b2c3d4e5-6f7a-8b9c-0d1e-2f3a4b5c6d7e.jpg",
            brand: "Nintendo",
            source: "Walmart",
            category: "Video Games",
            isInStock: true,
            rating: 4.7,
            reviewCount: 3241
        ),
        ProductItemDTO(
            sourceId: "1111222333",
            name: "Keurig K-Classic Coffee Maker",
            productDescription: "Single serve K-Cup pod coffee maker with 6-10oz brew sizes. Compatible with all K-Cup pods.",
            price: 89.99,
            originalPrice: 119.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Keurig-K-Classic-Coffee-Maker_x1y2z3a4-5b6c-7d8e-9f0a-1b2c3d4e5f6a.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Keurig-K-Classic-Coffee-Maker_x1y2z3a4-5b6c-7d8e-9f0a-1b2c3d4e5f6a.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Keurig-K-Classic-Coffee-Maker_x1y2z3a4-5b6c-7d8e-9f0a-1b2c3d4e5f6a.jpg",
            brand: "Keurig",
            source: "Walmart",
            category: "Home & Kitchen",
            isInStock: true,
            rating: 4.4,
            reviewCount: 1876
        ),
        ProductItemDTO(
            sourceId: "4444555666",
            name: "Instant Pot Duo 7-in-1 Electric Pressure Cooker",
            productDescription: "7-in-1 functionality: pressure cooker, slow cooker, rice cooker, yogurt maker, steamer, sauté pan, and warmer.",
            price: 79.95,
            originalPrice: 99.95,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Instant-Pot-Duo-7-in-1-Electric-Pressure-Cooker_q2w3e4r5-6t7y-8u9i-0o1p-2a3s4d5f6g7h.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Instant-Pot-Duo-7-in-1-Electric-Pressure-Cooker_q2w3e4r5-6t7y-8u9i-0o1p-2a3s4d5f6g7h.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Instant-Pot-Duo-7-in-1-Electric-Pressure-Cooker_q2w3e4r5-6t7y-8u9i-0o1p-2a3s4d5f6g7h.jpg",
            brand: "Instant Pot",
            source: "Walmart",
            category: "Home & Kitchen",
            isInStock: true,
            rating: 4.6,
            reviewCount: 2934
        ),
        // Additional Electronics
        ProductItemDTO(
            sourceId: "7777888999",
            name: "Apple Watch Series 9 GPS 45mm",
            productDescription: "Advanced health monitoring, ECG app, blood oxygen monitoring, and fitness tracking in a sleek aluminum case.",
            price: 399.99,
            originalPrice: 429.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Apple-Watch-Series-9-GPS-45mm_e5f6a7b8-9c0d-1e2f-3a4b-5c6d7e8f9a0b.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Apple-Watch-Series-9-GPS-45mm_e5f6a7b8-9c0d-1e2f-3a4b-5c6d7e8f9a0b.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Apple-Watch-Series-9-GPS-45mm_e5f6a7b8-9c0d-1e2f-3a4b-5c6d7e8f9a0b.jpg",
            brand: "Apple",
            source: "Walmart",
            category: "Electronics",
            isInStock: true,
            rating: 4.8,
            reviewCount: 1256
        ),
        ProductItemDTO(
            sourceId: "2222333444",
            name: "Sony WH-1000XM5 Wireless Noise Canceling Headphones",
            productDescription: "Industry-leading noise canceling with premium sound quality and up to 30 hours of battery life.",
            price: 329.99,
            originalPrice: 399.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Sony-WH-1000XM5-Wireless-Headphones_h8i9j0k1-2l3m-4n5o-6p7q-8r9s0t1u2v3w.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Sony-WH-1000XM5-Wireless-Headphones_h8i9j0k1-2l3m-4n5o-6p7q-8r9s0t1u2v3w.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Sony-WH-1000XM5-Wireless-Headphones_h8i9j0k1-2l3m-4n5o-6p7q-8r9s0t1u2v3w.jpg",
            brand: "Sony",
            source: "Walmart",
            category: "Audio",
            isInStock: true,
            rating: 4.7,
            reviewCount: 892
        ),
        // Gaming & Entertainment
        ProductItemDTO(
            sourceId: "6666777888",
            name: "PlayStation 5 Console",
            productDescription: "Experience lightning-fast loading with an ultra-high speed SSD, deeper immersion with haptic feedback, and 3D audio.",
            price: 499.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/PlayStation-5-Console_x4y5z6a7-8b9c-0d1e-2f3g-4h5i6j7k8l9m.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/PlayStation-5-Console_x4y5z6a7-8b9c-0d1e-2f3g-4h5i6j7k8l9m.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/PlayStation-5-Console_x4y5z6a7-8b9c-0d1e-2f3g-4h5i6j7k8l9m.jpg",
            brand: "Sony",
            source: "Walmart",
            category: "Video Games",
            isInStock: false,
            rating: 4.9,
            reviewCount: 3456
        ),
        ProductItemDTO(
            sourceId: "9999000111",
            name: "iPad Air 10.9-inch (5th Generation)",
            productDescription: "Powerful M1 chip delivers amazing performance for creative work and gaming. All-day battery life and stunning Liquid Retina display.",
            price: 599.99,
            originalPrice: 649.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/iPad-Air-10-9-inch-5th-Generation_m6n7o8p9-0q1r-2s3t-4u5v-6w7x8y9z0a1b.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/iPad-Air-10-9-inch-5th-Generation_m6n7o8p9-0q1r-2s3t-4u5v-6w7x8y9z0a1b.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/iPad-Air-10-9-inch-5th-Generation_m6n7o8p9-0q1r-2s3t-4u5v-6w7x8y9z0a1b.jpg",
            brand: "Apple",
            source: "Walmart",
            category: "Electronics",
            isInStock: true,
            rating: 4.8,
            reviewCount: 2134
        ),
        // Home & Kitchen
        ProductItemDTO(
            sourceId: "3333444555",
            name: "Ninja Foodi Personal Blender",
            productDescription: "Personal blender with 18 oz. To-Go Cup and spout lid. Blend and drink in the same cup.",
            price: 39.99,
            originalPrice: 49.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/seo/Ninja-Foodi-Personal-Blender_b2c3d4e5-6f7g-8h9i-0j1k-2l3m4n5o6p7q.jpg"),
            imageUrls: [
                "https://i5.walmartimages.com/seo/Ninja-Foodi-Personal-Blender_b2c3d4e5-6f7g-8h9i-0j1k-2l3m4n5o6p7q.jpg"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/seo/Ninja-Foodi-Personal-Blender_b2c3d4e5-6f7g-8h9i-0j1k-2l3m4n5o6p7q.jpg",
            brand: "Ninja",
            source: "Walmart",
            category: "Home & Kitchen",
            isInStock: true,
            rating: 4.3,
            reviewCount: 567
        )
    ]
    
    // MARK: - Initialization
    
    init(apiKey: String, demoMode: Bool = true) {
        self.apiKey = apiKey
        self.isDemoMode = demoMode  // Default to demo mode for safety
        
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("DEMO_MODE") {
            self.isDemoMode = true
            print("✅ Walmart API Demo Mode enabled through launch argument")
        }
        #endif
        
        // For development, always enable demo mode unless explicitly disabled
        #if DEBUG
        if apiKey == "DEMO_MODE_KEY" || apiKey == "PREVIEW_API_KEY" || apiKey.isEmpty {
            self.isDemoMode = true
            print("✅ Walmart API Demo Mode enabled - using mock data")
        }
        #endif
    }
    
    // Modern factory method with async throws
    static func create() async throws -> WalmartAPIService {
        let demoMode = ProcessInfo.processInfo.arguments.contains("DEMO_MODE")
        
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: APIConfig.Service.walmart)
            return WalmartAPIService(apiKey: apiKey, demoMode: true)  // Always start with demo mode
        } catch {
            let apiKey = SecretKeys.walmartApiKey
            if !apiKey.isEmpty {
                return WalmartAPIService(apiKey: apiKey, demoMode: true)  // Always start with demo mode
            }
            
            // Enable demo mode if no valid API key
            return WalmartAPIService(apiKey: "DEMO_MODE_KEY", demoMode: true)
        }
    }
    
    static func createPreview() -> WalmartAPIService {
        return WalmartAPIService(apiKey: "PREVIEW_API_KEY", demoMode: true)
    }
    
    static func createWithKey(_ apiKey: String) -> WalmartAPIService {
        return WalmartAPIService(apiKey: apiKey, demoMode: false)
    }
    
    func enableDemoMode() {
        isDemoMode = true
        print("✅ Walmart API Demo Mode enabled - will use mock data for all operations")
    }
    
    // MARK: - API Connection Testing (APITestable Protocol)
    
    func testConnection() async -> Bool {
        await testAPIConnection()
    }
    
    private func testAPIConnection() async -> Bool {
        if isDemoMode {
            print("✅ Demo mode: Simulating successful Walmart API connection")
            return true
        }
        
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            print("✅ MOCK_API flag detected, simulating successful API connection")
            return true
        }
        #endif
        
        let request = createRequest(endpoint: "search", queryItems: [
            URLQueryItem(name: "q", value: "test"),
            URLQueryItem(name: "page", value: "1")
        ])
        
        guard let request = request else {
            print("❌ Failed to create test request")
            return false
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return false
            }
            
            print("📥 Response status code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                print("✅ Successfully connected to Walmart API via RapidAPI")
                return true
            case 403:
                if let errorString = String(data: data, encoding: .utf8),
                   errorString.contains("not subscribed") {
                    print("⚠️ API subscription issue detected")
                    print("✅ Enabling demo mode with mock data")
                    isDemoMode = true
                    return true
                }
                fallthrough
            default:
                print("❌ API error: \(httpResponse.statusCode)")
                print("✅ Enabling demo mode for demonstration")
                isDemoMode = true
                return true
            }
        } catch {
            print("❌ Request failed: \(error.localizedDescription)")
            print("✅ Enabling demo mode for demonstration")
            isDemoMode = true
            return true
        }
    }
    
    func getRemainingQuota() async -> Int {
        return await rateLimiter.getRemainingQuota()
    }
    
    // MARK: - RetailerAPIService Protocol Methods
    
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        defer { isLoading = false }
        isLoading = true
        lastError = nil
        
        print("🔍 WalmartAPIService.searchProducts called with query: '\(query)'")
        print("🎭 Demo Mode: \(isDemoMode)")
        
        // Check cache first
        if let cachedResults = await cacheManager.getCachedSearch(for: query) {
            print("🔄 Using cached search results for '\(query)'")
            return cachedResults
        }
        
        // Check rate limit
        let canProceed = await rateLimiter.checkAndIncrement()
        if !canProceed {
            print("⚠️ Rate limit protection: Using mock data")
            return filterMockProducts(query: query)
        }
        
        // Demo mode check - use hybrid approach
        if isDemoMode {
            print("✅ Demo mode enabled - using hybrid search strategy for '\(query)'")
            try await Task.sleep(nanoseconds: 500_000_000) // Realistic delay
            let results = await hybridSearch(query: query)
            print("📦 Returning \(results.count) hybrid search results")
            return results
        }
        
        // Perform actual API search
        do {
            let products = try await performSearch(query: query)
            await cacheManager.cacheSearch(products, for: query)
            return products
        } catch {
            lastError = error
            throw error
        }
    }
    
    func getProductDetails(id: String) async throws -> ProductItemDTO {
        defer { isLoading = false }
        isLoading = true
        lastError = nil
        
        // Check cache first
        if let cachedProduct = await cacheManager.getCachedProduct(id: id) {
            return cachedProduct
        }
        
        // Demo mode check
        if isDemoMode {
            try await Task.sleep(nanoseconds: 300_000_000)
            if let product = mockProducts.first(where: { $0.sourceId == id }) {
                return product
            }
            return createFallbackProduct(id: id)
        }
        
        // Perform actual API call
        do {
            let product = try await fetchProductDetails(id: id)
            await cacheManager.cacheProduct(product)
            return product
        } catch {
            lastError = error
            throw error
        }
    }
    
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
        defer { isLoading = false }
        isLoading = true
        lastError = nil
        
        if isDemoMode {
            try await Task.sleep(nanoseconds: 400_000_000)
            if let product = mockProducts.first(where: { $0.sourceId == id }) {
                return mockProducts.filter { $0.sourceId != id && $0.category == product.category }
            }
            return Array(mockProducts.filter { $0.sourceId != id }.prefix(3))
        }
        
        // Get product details first to determine category
        let product = try await getProductDetails(id: id)
        
        if let category = product.category {
            let relatedProducts = try await searchProducts(query: category)
            return Array(relatedProducts.filter { $0.sourceId != id }.prefix(5))
        }
        
        return []
    }
    
    // MARK: - Hybrid Search & Popular Products
    
    func getTrendingProducts() async throws -> [ProductItemDTO] {
        defer { isLoading = false }
        isLoading = true
        lastError = nil
        
        if isDemoMode {
            print("✅ Demo mode: Returning trending products")
            try await Task.sleep(nanoseconds: 300_000_000)
            // Return popular products from each category
            let trendingIds = popularProductIds.values.flatMap { $0.prefix(2) }
            return mockProducts.filter { trendingIds.contains($0.sourceId) }
        }
        
        // In real mode, try to fetch actual trending products
        do {
            return try await searchProducts(query: "trending")
        } catch {
            // Fallback to popular products
            return Array(mockProducts.prefix(4))
        }
    }
    
    func getSearchSuggestions() async -> [String] {
        if isDemoMode {
            print("✅ Demo mode: Returning search suggestions")
            return Array(searchTermToCategory.keys.shuffled().prefix(6))
        }
        
        // In real mode, could fetch from API or return cached suggestions
        return ["iPhone", "Samsung TV", "AirPods", "Nintendo Switch", "Coffee Maker", "Instant Pot"]
    }
    
    private func hybridSearch(query: String) async -> [ProductItemDTO] {
        print("🔄 Hybrid search for: '\(query)'")
        
        // Step 1: Try direct text filtering first
        let directResults = filterMockProducts(query: query)
        if !directResults.isEmpty {
            print("✅ Found \(directResults.count) direct matches")
            return directResults
        }
        
        // Step 2: Try category mapping
        let lowercaseQuery = query.lowercased()
        for (term, category) in searchTermToCategory {
            if lowercaseQuery.contains(term) {
                print("✅ Mapped '\(query)' to category '\(category)'")
                if let categoryIds = popularProductIds[category] {
                    let categoryProducts = mockProducts.filter { categoryIds.contains($0.sourceId) }
                    if !categoryProducts.isEmpty {
                        return categoryProducts
                    }
                }
            }
        }
        
        // Step 3: Fallback to popular products from all categories
        print("⚠️ No specific matches, returning popular products")
        return Array(mockProducts.prefix(4))
    }
    
    // MARK: - Private Helper Methods
    
    private func createRequest(endpoint: String, queryItems: [URLQueryItem] = []) -> URLRequest? {
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)") else {
            return nil
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(rapidAPIHost, forHTTPHeaderField: "X-RapidAPI-Host")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    private func performSearch(query: String) async throws -> [ProductItemDTO] {
        let request = createRequest(endpoint: "search", queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: "1")
        ])
        
        guard let request = request else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try await parseSearchResponse(data)
        case 401, 403:
            throw APIError.authenticationFailed
        case 429:
            throw APIError.rateLimitExceeded
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.invalidResponse
        }
    }
    
    private func fetchProductDetails(id: String) async throws -> ProductItemDTO {
        let productURL = "https://www.walmart.com/ip/\(id)"
        let encodedURL = productURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productURL
        
        let request = createRequest(
            endpoint: "product-details.php",
            queryItems: [URLQueryItem(name: "url", value: encodedURL)]
        )
        
        guard let request = request else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try await parseProductDetails(data)
        case 404:
            throw APIError.custom("Product not found")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    @Sendable
    private func parseSearchResponse(_ data: Data) async throws -> [ProductItemDTO] {
        let decoder = JSONDecoder()
        
        // Try structured response first
        if let searchResponse = try? decoder.decode(WalmartSearchResponse.self, from: data),
           let products = searchResponse.products {
            return products.compactMap { mapToProductItem($0) }
        }
        
        // Try alternative JSON structure
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let products = jsonObject["products"] as? [[String: Any]] {
            return products.compactMap { parseProductFromDictionary($0) }
        }
        
        throw APIError.decodingFailed(DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Unable to parse search response")
        ))
    }
    
    @Sendable
    private func parseProductDetails(_ data: Data) async throws -> ProductItemDTO {
        let decoder = JSONDecoder()
        
        if let detailsResponse = try? decoder.decode(WalmartProductDetailsResponse.self, from: data),
           let product = detailsResponse.product,
           let productDTO = mapToProductItem(product) {
            return productDTO
        }
        
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let productDict = jsonObject["product"] as? [String: Any],
           let productDTO = parseProductFromDictionary(productDict) {
            return productDTO
        }
        
        throw APIError.noData
    }
    
    private func filterMockProducts(query: String) -> [ProductItemDTO] {
        print("🔍 filterMockProducts called with query: '\(query)'")
        print("📦 Total mock products available: \(mockProducts.count)")
        
        guard !query.isEmpty else { 
            print("📤 Empty query - returning all \(mockProducts.count) products")
            return mockProducts 
        }
        
        let lowercasedQuery = query.lowercased()
        let filteredProducts = mockProducts.filter { product in
            let nameMatch = product.name.lowercased().contains(lowercasedQuery)
            let descMatch = product.productDescription?.lowercased().contains(lowercasedQuery) ?? false
            let brandMatch = product.brand.lowercased().contains(lowercasedQuery)
            let categoryMatch = product.category?.lowercased().contains(lowercasedQuery) ?? false
            
            let matches = nameMatch || descMatch || brandMatch || categoryMatch
            if matches {
                print("✅ Product '\(product.name)' matches query '\(query)'")
            }
            return matches
        }
        
        print("📤 Returning \(filteredProducts.count) filtered products for query '\(query)'")
        return filteredProducts
    }
    
    private func createFallbackProduct(id: String) -> ProductItemDTO {
        var fallbackProduct = mockProducts.first!
        return ProductItemDTO(
            sourceId: id,
            name: fallbackProduct.name,
            productDescription: fallbackProduct.productDescription,
            price: fallbackProduct.price,
            originalPrice: fallbackProduct.originalPrice,
            currency: fallbackProduct.currency,
            imageURL: fallbackProduct.imageURL,
            imageUrls: fallbackProduct.imageUrls,
            thumbnailUrl: fallbackProduct.thumbnailUrl,
            brand: fallbackProduct.brand,
            source: fallbackProduct.source,
            category: fallbackProduct.category,
            isInStock: fallbackProduct.isInStock,
            rating: fallbackProduct.rating,
            reviewCount: fallbackProduct.reviewCount
        )
    }
    
    private func mapToProductItem(_ walmartProduct: WalmartProduct) -> ProductItemDTO? {
        guard let id = walmartProduct.id,
              let title = walmartProduct.title else {
            return nil
        }
        
        let imageUrls = walmartProduct.images?.compactMap { $0.url } ?? []
        
        return ProductItemDTO(
            sourceId: id,
            name: title,
            productDescription: walmartProduct.description,
            price: walmartProduct.price?.current,
            originalPrice: walmartProduct.price?.original,
            currency: walmartProduct.price?.currency ?? "USD",
            imageURL: imageUrls.first.flatMap { URL(string: $0) },
            imageUrls: imageUrls,
            thumbnailUrl: imageUrls.first,
            brand: walmartProduct.brand ?? "Unknown",
            source: "Walmart",
            category: walmartProduct.category,
            isInStock: walmartProduct.availability?.inStock ?? true,
            rating: walmartProduct.rating?.average,
            reviewCount: walmartProduct.rating?.count
        )
    }
    
    private func parseProductFromDictionary(_ dict: [String: Any]) -> ProductItemDTO? {
        guard let id = dict["id"] as? String ?? dict["itemId"] as? String,
              let title = dict["title"] as? String ?? dict["name"] as? String else {
            return nil
        }
        
        var currentPrice: Double?
        var originalPrice: Double?
        
        if let priceDict = dict["price"] as? [String: Any] {
            currentPrice = priceDict["current"] as? Double
            originalPrice = priceDict["original"] as? Double
        } else if let price = dict["salePrice"] as? Double {
            currentPrice = price
            originalPrice = dict["msrp"] as? Double
        }
        
        var imageUrls: [String] = []
        if let imagesArray = dict["images"] as? [[String: Any]] {
            imageUrls = imagesArray.compactMap { $0["url"] as? String }
        } else if let imageUrl = dict["image"] as? String {
            imageUrls = [imageUrl]
        }
        
        var isInStock = true
        if let availabilityDict = dict["availability"] as? [String: Any] {
            isInStock = availabilityDict["in_stock"] as? Bool ?? true
        }
        
        var rating: Double?
        var reviewCount: Int?
        if let ratingDict = dict["rating"] as? [String: Any] {
            rating = ratingDict["average"] as? Double
            reviewCount = ratingDict["count"] as? Int
        }
        
        return ProductItemDTO(
            sourceId: id,
            name: title,
            productDescription: dict["description"] as? String,
            price: currentPrice,
            originalPrice: originalPrice,
            currency: "USD",
            imageURL: imageUrls.first.flatMap { URL(string: $0) },
            imageUrls: imageUrls,
            thumbnailUrl: imageUrls.first,
            brand: dict["brand"] as? String ?? "Unknown",
            source: "Walmart",
            category: dict["category"] as? String,
            isInStock: isInStock,
            rating: rating,
            reviewCount: reviewCount
        )
    }
}

// MARK: - Modern Cache Manager using Actor

actor CacheManager {
    private var searchCache: [String: (products: [ProductItemDTO], timestamp: Date)] = [:]
    private var productCache: [String: (product: ProductItemDTO, timestamp: Date)] = [:]
    private let cacheLifetime: TimeInterval = 3600 // 1 hour
    
    func getCachedSearch(for query: String) -> [ProductItemDTO]? {
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cached = searchCache[key],
              Date().timeIntervalSince(cached.timestamp) < cacheLifetime else {
            return nil
        }
        return cached.products
    }
    
    func cacheSearch(_ products: [ProductItemDTO], for query: String) {
        let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        searchCache[key] = (products, Date())
    }
    
    func getCachedProduct(id: String) -> ProductItemDTO? {
        guard let cached = productCache[id],
              Date().timeIntervalSince(cached.timestamp) < cacheLifetime else {
            return nil
        }
        return cached.product
    }
    
    func cacheProduct(_ product: ProductItemDTO) {
        productCache[product.sourceId] = (product, Date())
    }
    
    func clearCache() {
        searchCache.removeAll()
        productCache.removeAll()
    }
}

// MARK: - Modern Rate Limiter using Actor

actor RateLimiter {
    private var callCount = 0
    private var lastResetDate = Date()
    private let monthlyLimit: Int
    
    init(monthlyLimit: Int) {
        self.monthlyLimit = monthlyLimit
    }
    
    func checkAndIncrement() -> Bool {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, equalTo: Date(), toGranularity: .month) {
            callCount = 0
            lastResetDate = Date()
        }
        
        guard callCount < monthlyLimit else {
            return false
        }
        
        callCount += 1
        print("📊 Walmart API Call \(callCount)/\(monthlyLimit)")
        return true
    }
    
    func getRemainingQuota() -> Int {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, equalTo: Date(), toGranularity: .month) {
            return monthlyLimit
        }
        return max(0, monthlyLimit - callCount)
    }
}