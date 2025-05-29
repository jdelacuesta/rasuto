//
//  EbayAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/28/25.
//


import Foundation

class EbayAPIService: RetailerAPIService {
    let apiKey: String
    
    // MARK: - Modern Infrastructure (Phase 1 Migration)
    private let optimizedClient = OptimizedAPIClient.shared
    private let modernCacheManager = UnifiedCacheManager.shared
    private let globalRateLimiter = GlobalRateLimiter.shared
    private let circuitBreaker = CircuitBreakerManager.shared
    
    // Feature flags for gradual migration
    private let useModernCache = true
    private let useModernRateLimiting = true
    private let serviceName = "ebay"
    
    // Base URLs - updated to support Sandbox mode
    private let isSandbox: Bool
    
    private var browseBaseURL: String {
        return isSandbox ? "https://api.sandbox.ebay.com/buy/browse/v1" : "https://api.ebay.com/buy/browse/v1"
    }
    
    private var feedBaseURL: String {
        return isSandbox ? "https://api.sandbox.ebay.com/buy/feed/v1" : "https://api.ebay.com/buy/feed/v1"
    }
    
    private var notificationBaseURL: String {
        return isSandbox ? "https://api.sandbox.ebay.com/commerce/notification/v1" : "https://api.ebay.com/commerce/notification/v1"
    }
    
    // Legacy rate limiting constants (kept for backward compatibility)
    private let requestsPerSecond = 5
    private let hourlyRequestLimit = 5000
    
    // MARK: - Notification Service for Ebay Push Notifications
    
    private lazy var notificationService = EbayNotificationService()
    
    // Server URL for receiving eBay webhook notifications
    // In a real app, this would point to your server endpoint
    // For testing, we use a service like ngrok to expose a local endpoint
    private let webhookServerURL = "https://0fb2-2600-8802-1806-1800-960-31e6-6029-46b2.ngrok-free.app"
    
    // Topic IDs for available notifications
    private let priceChangeTopicId = "ITEM_PRICE_CHANGE"
    private let inventoryChangeTopicId = "ITEM_INVENTORY_CHANGE"
    private let promotionChangeTopicId = "ITEM_PROMOTION_STATUS_CHANGE"
    
    // Cache for subscription IDs
    private var priceChangeSubscriptionId: String?
    private var inventoryChangeSubscriptionId: String?
    
    // Webhook handler for processing incoming notifications
    private lazy var webhookHandler: EbayWebhookHandler? = nil
    
    // MARK: - Helper Methods
    
    private func filterMockProducts(query: String) -> [ProductItemDTO] {
        guard !query.isEmpty else { return mockProducts }
        
        let lowercasedQuery = query.lowercased()
        return mockProducts.filter { product in
            product.name.lowercased().contains(lowercasedQuery) ||
            (product.productDescription?.lowercased().contains(lowercasedQuery) ?? false) ||
            product.brand.lowercased().contains(lowercasedQuery) ||
            (product.category?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    // MARK: - Mock Data
    
    private let mockProducts = [
        ProductItemDTO(
            sourceId: "v1|12345|0",
            name: "Apple Watch Series 9 GPS 45mm Midnight Aluminum Case",
            productDescription: "Latest model, powerful S9 chip, Always-On Retina display.",
            price: 399.00,
            currency: "USD",
            imageURL: URL(string: "https://i.ebayimg.com/images/g/12345.jpg"),
            imageUrls: [
                "https://i.ebayimg.com/images/g/12345.jpg"
            ],
            thumbnailUrl: "https://i.ebayimg.com/images/g/12345.jpg",
            brand: "Apple",
            source: "eBay",
            category: "Smart Watches",
            isInStock: true,
            rating: 4.6,
            reviewCount: 654
        ),
        ProductItemDTO(
            sourceId: "v1|67890|0",
            name: "Nikon Z6 II FX-Format Mirrorless Camera Body",
            productDescription: "24.5MP BSI sensor, dual EXPEED 6 processors, 4K UHD video recording.",
            price: 1599.99,
            currency: "USD",
            imageURL: URL(string: "https://i.ebayimg.com/images/g/67890.jpg"),
            imageUrls: [
                "https://i.ebayimg.com/images/g/67890.jpg"
            ],
            thumbnailUrl: "https://i.ebayimg.com/images/g/67890.jpg",
            brand: "Nikon",
            source: "eBay",
            category: "Digital Cameras",
            isInStock: true,
            rating: 4.8,
            reviewCount: 290
        ),
        ProductItemDTO(
            sourceId: "v1|54321|0",
            name: "Leica M7 35mm Rangefinder Film Camera Body",
            productDescription: "Excellent condition, mechanical rangefinder with electronic shutter control.",
            price: 2899.99,
            currency: "USD",
            imageURL: URL(string: "https://i.ebayimg.com/images/g/54321.jpg"),
            imageUrls: [
                "https://i.ebayimg.com/images/g/54321.jpg"
            ],
            thumbnailUrl: "https://i.ebayimg.com/images/g/54321.jpg",
            brand: "Leica",
            source: "eBay",
            category: "Film Cameras",
            isInStock: true,
            rating: 4.9,
            reviewCount: 45
        )
    ]
    
    // MARK: - Initialization
    
    init(apiKey: String, isSandbox: Bool = false) {
        self.apiKey = apiKey
        
        // Auto-detect sandbox mode from the API key or OAuth credentials
        var detectedSandbox = isSandbox || apiKey.contains("SBX") || apiKey.contains("sandbox")
        
        // Also check OAuth credentials for sandbox indicators
        if !detectedSandbox {
            do {
                let clientID = try APIKeyManager.shared.getAPIKey(for: APIConfig.Service.ebayClientID)
                let clientSecret = try APIKeyManager.shared.getAPIKey(for: APIConfig.Service.ebayClientSecret)
                detectedSandbox = clientID.contains("SBX") || clientSecret.contains("SBX")
            } catch {
                // If can't get OAuth credentials, stick with API key detection
            }
        }
        
        self.isSandbox = detectedSandbox
        
        if self.isSandbox {
            APILogger.log("Initialized in SANDBOX mode", type: .info)
        } else {
            APILogger.log("Initialized in PRODUCTION mode", type: .info)
        }
    }
    
    init(apiKey: String, notificationManager: EbayNotificationManager, isSandbox: Bool = false) {
        self.apiKey = apiKey
        
        // Auto-detect sandbox mode from the API key or OAuth credentials
        var detectedSandbox = isSandbox || apiKey.contains("SBX") || apiKey.contains("sandbox")
        
        // Also check OAuth credentials for sandbox indicators
        if !detectedSandbox {
            do {
                let clientID = try APIKeyManager.shared.getAPIKey(for: APIConfig.Service.ebayClientID)
                let clientSecret = try APIKeyManager.shared.getAPIKey(for: APIConfig.Service.ebayClientSecret)
                detectedSandbox = clientID.contains("SBX") || clientSecret.contains("SBX")
            } catch {
                // If can't get OAuth credentials, stick with API key detection
            }
        }
        
        self.isSandbox = detectedSandbox
        
        self.webhookHandler = EbayWebhookHandler(
            notificationService: notificationService,
            notificationManager: notificationManager
        )
        
        if self.isSandbox {
            APILogger.log("Initialized in SANDBOX mode with notification manager", type: .info)
        } else {
            APILogger.log("Initialized in PRODUCTION mode with notification manager", type: .info)
        }
    }
    
    // MARK: - API Methods

    // Protocol conformance method - this is what RetailerAPIService requires
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        // Call the internal implementation with no category
        return try await searchProductsWithCategory(query: query, categoryId: nil)
    }

    // Internal implementation with category support
    func searchProductsWithCategory(query: String, categoryId: String? = nil) async throws -> [ProductItemDTO] {
        // Modern cache key
        let cacheKey = "ebay_search_\(query.lowercased())_\(categoryId ?? "")"
        
        // Check modern cache if enabled
        if useModernCache {
            if let cachedResults: [ProductItemDTO] = await modernCacheManager.get(key: cacheKey) {
                APILogger.log("Modern cache hit for search: '\(query)'", type: .success)
                return cachedResults
            }
        }
        
        // Check modern rate limit if enabled
        if useModernRateLimiting {
            do {
                try await globalRateLimiter.checkAndConsume(
                    service: serviceName,
                    priority: .normal
                )
            } catch {
                APILogger.log("Rate limit exceeded, returning mock data", type: .warning)
                return filterMockProducts(query: query)
            }
        }
        
        // For testing without real API call, use mock data
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for search query: \"\(query)\"")
            try await Task.sleep(nanoseconds: 500_000_000)
            
            let filteredProducts = filterMockProducts(query: query)
            APILogger.log("Mock search returned \(filteredProducts.count) results", type: .success)
            return filteredProducts
        }
        #endif
        
        // Real API implementation
        do {
            APILogger.log("Searching for products with query: \"\(query)\"", type: .info)
            
            // Get OAuth token
            let oauthHandler = OAuthHandler()
            let accessToken = try await oauthHandler.authorize(for: "ebay")
            
            var urlComponents = URLComponents(string: "\(browseBaseURL)/item_summary/search")
            
            // Build query parameters
            var queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "filter", value: "buyingOptions:{FIXED_PRICE|AUCTION}"),
                URLQueryItem(name: "fieldgroups", value: "EXTENDED")
            ]
            
            // Add category filtering if provided
            if let categoryId = categoryId, !categoryId.isEmpty {
                queryItems.append(URLQueryItem(name: "category_ids", value: categoryId))
                APILogger.log("Added category filter: \(categoryId)", type: .info)
            }
            
            urlComponents?.queryItems = queryItems
            
            guard let url = urlComponents?.url else {
                APILogger.log("Failed to create URL for search query", type: .error)
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Log the request
            APILogger.logRequest(request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response
            APILogger.logResponse(data: data, response: response)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                APILogger.log("Invalid response type", type: .error)
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                do {
                    let ebayResponse = try decoder.decode(EbaySearchResponse.self, from: data)
                    
                    guard let itemSummaries = ebayResponse.itemSummaries else {
                        APILogger.log("No items found in search results", type: .warning)
                        return []
                    }
                    
                    let products = itemSummaries.map { mapToProductItemDTO($0) }
                    APILogger.log("Search successful: Found \(products.count) products", type: .success)
                    
                    // Save to modern cache if enabled
                    if useModernCache {
                        await modernCacheManager.set(
                            key: cacheKey,
                            value: products,
                            ttl: 3600 // 1 hour
                        )
                        APILogger.log("Cached search results in modern cache", type: .info)
                    }
                    
                    return products
                } catch {
                    APILogger.log("Failed to decode search response: \(error)", type: .error)
                    throw APIError.decodingFailed(error)
                }
                    
            case 401:
                APILogger.log("Authentication failed (401)", type: .error)
                throw APIError.authenticationFailed
                
            case 429:
                APILogger.log("Rate limit exceeded (429)", type: .error)
                throw APIError.rateLimitExceeded
                
            default:
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                APILogger.log("Error response (\(httpResponse.statusCode)): \(responseString.prefix(500))", type: .error)
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            APILogger.log("Search failed: \(error)", type: .error)
            throw error
        }
    }
    
    func getProductDetails(id: String) async throws -> ProductItemDTO {
        // Mock data for testing
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for product details: \"\(id)\"")
            if let product = mockProducts.first(where: { $0.sourceId == id }) {
                try await Task.sleep(nanoseconds: 300_000_000)
                APILogger.log("Mock product details retrieved successfully", type: .success)
                return product
            }
            APILogger.log("Mock product not found", type: .warning)
        }
        #endif
        
        // Real implementation
        do {
            APILogger.log("Getting details for item \(id)", type: .info)
            let oauthHandler = OAuthHandler()
            let accessToken = try await oauthHandler.authorize(for: "ebay")
            
            let urlString = "\(browseBaseURL)/item/\(id)"
            guard let url = URL(string: urlString) else {
                APILogger.log("Failed to create URL for item details", type: .error)
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            // Log the request
            APILogger.logRequest(request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response
            APILogger.logResponse(data: data, response: response)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                APILogger.log("Invalid response type", type: .error)
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                do {
                    let itemDetails = try decoder.decode(EbayItemSummary.self, from: data)
                    APILogger.log("Successfully retrieved details for \(itemDetails.title)", type: .success)
                    return mapToProductItemDTO(itemDetails)
                } catch {
                    APILogger.log("Failed to decode item details: \(error)", type: .error)
                    throw APIError.decodingFailed(error)
                }
                
            case 401:
                APILogger.log("Authentication failed (401)", type: .error)
                throw APIError.authenticationFailed
                
            case 429:
                APILogger.log("Rate limit exceeded (429)", type: .error)
                throw APIError.rateLimitExceeded
                
            default:
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                APILogger.log("Error response (\(httpResponse.statusCode)): \(responseString.prefix(500))", type: .error)
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            APILogger.log("Get product details failed: \(error)", type: .error)
            throw error
        }
    }
    
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
        // Mock data for testing
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for related products: \"\(id)\"")
            try await Task.sleep(nanoseconds: 400_000_000)
            
            if let product = mockProducts.first(where: { $0.sourceId == id }) {
                let relatedProducts = mockProducts.filter { $0.sourceId != id && $0.category == product.category }
                APILogger.log("Mock related products retrieved: \(relatedProducts.count) items", type: .success)
                return relatedProducts
            }
            return []
        }
        #endif
        
        // Real implementation using the eBay API to find related items
        do {
            APILogger.log("Getting related products for item \(id)", type: .info)
            let product = try await getProductDetails(id: id)
            
            guard let category = product.category else {
                APILogger.log("No category found for item, cannot fetch related products", type: .warning)
                return []
            }
            
            var urlComponents = URLComponents(string: "\(browseBaseURL)/item_summary/search")
            urlComponents?.queryItems = [
                URLQueryItem(name: "category_ids", value: category),
                URLQueryItem(name: "limit", value: "5")
            ]
            
            guard let url = urlComponents?.url else {
                APILogger.log("Failed to create URL for related products", type: .error)
                throw APIError.invalidURL
            }
            
            let oauthHandler = OAuthHandler()
            let accessToken = try await oauthHandler.authorize(for: "ebay")
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            // Log the request
            APILogger.logRequest(request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response
            APILogger.logResponse(data: data, response: response)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                APILogger.log("Invalid response type", type: .error)
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                do {
                    let ebayResponse = try decoder.decode(EbaySearchResponse.self, from: data)
                    
                    guard let itemSummaries = ebayResponse.itemSummaries else {
                        APILogger.log("No related items found", type: .warning)
                        return []
                    }
                    
                    // Filter out the original item
                    let relatedItems = itemSummaries
                        .filter { $0.itemId != id }
                        .map { mapToProductItemDTO($0) }
                    
                    APILogger.log("Found \(relatedItems.count) related items", type: .success)
                    return relatedItems
                } catch {
                    APILogger.log("Failed to decode related products: \(error)", type: .error)
                    throw APIError.decodingFailed(error)
                }
                
            default:
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                APILogger.log("Error response (\(httpResponse.statusCode)): \(responseString.prefix(500))", type: .error)
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            APILogger.log("Get related products failed: \(error)", type: .error)
            throw error
        }
    }
    
    // MARK: - Inventory Discovery and Refresh Methods
    
    /// Get available feed types with permissions
    func getAvailableFeedTypes() async throws -> [String: Any] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for feed types")
            try await Task.sleep(nanoseconds: 300_000_000)
            return ["feedTypes": ["mockType1", "mockType2"]]
        }
        #endif
        
        do {
            APILogger.log("Getting available feed types", type: .info)
            let oauthHandler = OAuthHandler()
            let accessToken = try await oauthHandler.authorize(for: "ebay")
            
            let urlString = "\(feedBaseURL)/feed_type"
            guard let url = URL(string: urlString) else {
                APILogger.log("Failed to create URL for feed types", type: .error)
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            // Log the request
            APILogger.logRequest(request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response
            APILogger.logResponse(data: data, response: response)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                APILogger.log("Invalid response type", type: .error)
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    APILogger.log("Failed to parse feed types JSON", type: .error)
                    throw APIError.decodingFailed(NSError(domain: "JSON Parsing", code: 0))
                }
                APILogger.log("Successfully retrieved feed types", type: .success)
                return json
                
            case 401:
                APILogger.log("Authentication failed (401)", type: .error)
                throw APIError.authenticationFailed
                
            case 429:
                APILogger.log("Rate limit exceeded (429)", type: .error)
                throw APIError.rateLimitExceeded
                
            default:
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                APILogger.log("Error response (\(httpResponse.statusCode)): \(responseString.prefix(500))", type: .error)
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            APILogger.log("Get feed types failed: \(error)", type: .error)
            throw error
        }
    }
    
    /// Get available feed files for a specific feed type
    func getAvailableFiles(feedTypeId: String, marketplaceId: String) async throws -> [String: Any] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for feed files")
            try await Task.sleep(nanoseconds: 300_000_000)
            return ["fileMetadata": [["fileId": "mock-file-1", "createDate": "2025-05-15T12:00:00.000Z"]]]
        }
        #endif
        
        do {
            APILogger.log("Getting available files for feed type \(feedTypeId)", type: .info)
            let oauthHandler = OAuthHandler()
            let accessToken = try await oauthHandler.authorize(for: "ebay")
            
            let urlString = "\(feedBaseURL)/file?feed_type_id=\(feedTypeId)"
            guard let url = URL(string: urlString) else {
                APILogger.log("Failed to create URL for feed files", type: .error)
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue(marketplaceId, forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
            
            // Log the request
            APILogger.logRequest(request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response
            APILogger.logResponse(data: data, response: response)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                APILogger.log("Invalid response type", type: .error)
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    APILogger.log("Failed to parse feed files JSON", type: .error)
                    throw APIError.decodingFailed(NSError(domain: "JSON Parsing", code: 0))
                }
                APILogger.log("Successfully retrieved available files", type: .success)
                return json
                
            case 401:
                APILogger.log("Authentication failed (401)", type: .error)
                throw APIError.authenticationFailed
                
            case 429:
                APILogger.log("Rate limit exceeded (429)", type: .error)
                throw APIError.rateLimitExceeded
                
            default:
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                APILogger.log("Error response (\(httpResponse.statusCode)): \(responseString.prefix(500))", type: .error)
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            APILogger.log("Get feed files failed: \(error)", type: .error)
            throw error
        }
    }
    
    /// Download a specific feed file by ID
    func downloadFeedFile(fileId: String, marketplaceId: String) async throws -> Data {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for feed file download")
            try await Task.sleep(nanoseconds: 500_000_000)
            return "Mock feed file content".data(using: .utf8)!
        }
        #endif
        
        do {
            APILogger.log("Downloading feed file \(fileId)", type: .info)
            let oauthHandler = OAuthHandler()
            let accessToken = try await oauthHandler.authorize(for: "ebay")
            
            let urlString = "\(feedBaseURL)/file/\(fileId)/download"
            guard let url = URL(string: urlString) else {
                APILogger.log("Failed to create URL for feed file download", type: .error)
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/octet-stream", forHTTPHeaderField: "Accept")
            request.addValue(marketplaceId, forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
            
            // Log the request
            APILogger.logRequest(request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response (but not the full data)
            if let httpResponse = response as? HTTPURLResponse {
                APILogger.log("Response Status: \(httpResponse.statusCode)",
                            type: httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 ? .success : .error)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                APILogger.log("Invalid response type", type: .error)
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                APILogger.log("Successfully downloaded feed file (\(data.count) bytes)", type: .success)
                return data
                
            case 401:
                APILogger.log("Authentication failed (401)", type: .error)
                throw APIError.authenticationFailed
                
            case 429:
                APILogger.log("Rate limit exceeded (429)", type: .error)
                throw APIError.rateLimitExceeded
                
            default:
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                APILogger.log("Error response (\(httpResponse.statusCode)): \(responseString.prefix(500))", type: .error)
                throw APIError.serverError(httpResponse.statusCode)
            }
        } catch {
            APILogger.log("Feed download failed: \(error)", type: .error)
            throw error
        }
    }
    
    // MARK: - Tracking & Notification Methods
    
    /// Track an item for price and inventory changes
    func trackItem(id: String) async throws -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for tracking item: \(id)")
            try await Task.sleep(nanoseconds: 200_000_000)
            return true
        }
        #endif
        
        // This is a simplified implementation since eBay's notification API is complex
        // In a real implementation, you would register a webhook endpoint with eBay
        APILogger.log("Tracking item \(id)", type: .info)
        let userDefaults = UserDefaults.standard
        var trackedItems = userDefaults.stringArray(forKey: "ebay_tracked_items") ?? []
        
        if !trackedItems.contains(id) {
            trackedItems.append(id)
            userDefaults.set(trackedItems, forKey: "ebay_tracked_items")
            
            // Store tracking date
            let trackingMetadata: [String: Any] = [
                "trackingDate": Date().timeIntervalSince1970,
                "lastChecked": Date().timeIntervalSince1970
            ]
            userDefaults.set(trackingMetadata, forKey: "ebay_tracking_\(id)")
        }
        
        APILogger.log("Successfully tracked item \(id)", type: .success)
        return true
    }
    
    /// Get updates for tracked items
    struct ItemUpdate {
        let itemId: String
        let eventType: String
        let oldPrice: Double?
        let newPrice: Double?
        let oldQuantity: Int?
        let newQuantity: Int?
        let endTime: Date?
    }
    
    func getItemUpdates() async throws -> [ItemUpdate] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for item updates")
            try await Task.sleep(nanoseconds: 400_000_000)
            
            // Return a mock update for the first mock product
            if let firstProduct = mockProducts.first {
                let update = ItemUpdate(
                    itemId: firstProduct.sourceId,
                    eventType: "PRICE_CHANGE",
                    oldPrice: firstProduct.price! + 50.0,
                    newPrice: firstProduct.price,
                    oldQuantity: nil,
                    newQuantity: nil,
                    endTime: nil
                )
                APILogger.log("Mock update generated for item: \(firstProduct.sourceId)", type: .success)
                return [update]
            }
            return []
        }
        #endif
        
        APILogger.log("Getting updates for tracked items", type: .info)
        let userDefaults = UserDefaults.standard
        let trackedItems = userDefaults.stringArray(forKey: "ebay_tracked_items") ?? []
        
        var updates: [ItemUpdate] = []
        
        for itemId in trackedItems {
            APILogger.log("Checking updates for item \(itemId)", type: .info)
            // Get current item state
            do {
                let item = try await getProductDetails(id: itemId)
                
                // Get previous state
                if let trackingMetadataDict = userDefaults.dictionary(forKey: "ebay_tracking_\(itemId)"),
                   let lastChecked = trackingMetadataDict["lastChecked"] as? TimeInterval,
                   let lastPrice = trackingMetadataDict["lastPrice"] as? Double {
                    
                    // Compare with current state
                    if let currentPrice = item.price, currentPrice < lastPrice {
                        // Price drop detected
                        APILogger.log("Price drop detected for item \(itemId): \(lastPrice) -> \(currentPrice)", type: .success)
                        updates.append(ItemUpdate(
                            itemId: itemId,
                            eventType: "PRICE_CHANGE",
                            oldPrice: lastPrice,
                            newPrice: currentPrice,
                            oldQuantity: nil,
                            newQuantity: nil,
                            endTime: nil
                        ))
                    }
                    
                    // Update tracking metadata
                    var updatedMetadata = trackingMetadataDict
                    updatedMetadata["lastChecked"] = Date().timeIntervalSince1970
                    updatedMetadata["lastPrice"] = item.price
                    userDefaults.set(updatedMetadata, forKey: "ebay_tracking_\(itemId)")
                } else {
                    // Initialize tracking metadata
                    APILogger.log("Initializing tracking data for item \(itemId)", type: .info)
                    let trackingMetadata: [String: Any] = [
                        "trackingDate": Date().timeIntervalSince1970,
                        "lastChecked": Date().timeIntervalSince1970,
                        "lastPrice": item.price ?? 0.0
                    ]
                    userDefaults.set(trackingMetadata, forKey: "ebay_tracking_\(itemId)")
                }
            } catch {
                APILogger.log("Error updating item \(itemId): \(error)", type: .error)
            }
        }
        
        APILogger.log("Found \(updates.count) updates for tracked items", type: .success)
        return updates
    }
    
    // Add untrackItem method
    func untrackItem(id: String) async throws -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock data for untracking item: \(id)")
            try await Task.sleep(nanoseconds: 200_000_000)
            return true
        }
        #endif
        
        APILogger.log("Untracking item \(id)", type: .info)
        let userDefaults = UserDefaults.standard
        var trackedItems = userDefaults.stringArray(forKey: "ebay_tracked_items") ?? []
        
        if trackedItems.contains(id) {
            trackedItems.removeAll { $0 == id }
            userDefaults.set(trackedItems, forKey: "ebay_tracked_items")
            APILogger.log("Successfully untracked item \(id)", type: .success)
            return true
        }
        
        APILogger.log("Item \(id) was not being tracked", type: .warning)
        return false
    }
    
    // MARK: - Notification System Methods
    
    func initializeNotificationSystem() async throws {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Using mock notification system initialization")
            try await Task.sleep(nanoseconds: 300_000_000)
            APILogger.log("Mock notification system initialized", type: .success)
            return
        }
        #endif
        
        APILogger.log("Initializing notification system", type: .info)
        
        // Get or create the verification token
        let verificationToken = UserDefaults.standard.string(forKey: "ebay_verification_token") ?? UUID().uuidString
        if UserDefaults.standard.string(forKey: "ebay_verification_token") == nil {
            UserDefaults.standard.set(verificationToken, forKey: "ebay_verification_token")
        }
        
        // Setup notification infrastructure
        do {
            let (destinationId, subscriptionIds) = try await notificationService.setupNotificationInfrastructure(
                serverURL: webhookServerURL,
                verificationToken: verificationToken
            )
            
            // Store destination ID
            UserDefaults.standard.set(destinationId, forKey: "ebay_notification_destination_id")
            
            // Store subscription IDs
            for subscriptionId in subscriptionIds {
                if let subscription = try? await notificationService.getSubscription(subscriptionId: subscriptionId) {
                    if subscription.topicId == priceChangeTopicId {
                        priceChangeSubscriptionId = subscriptionId
                        UserDefaults.standard.set(subscriptionId, forKey: "ebay_price_subscription_id")
                    } else if subscription.topicId == inventoryChangeTopicId {
                        inventoryChangeSubscriptionId = subscriptionId
                        UserDefaults.standard.set(subscriptionId, forKey: "ebay_inventory_subscription_id")
                    }
                }
            }
            
            APILogger.log("Notification system initialized successfully", type: .success)
        } catch {
            APILogger.log("Failed to initialize notification system: \(error)", type: .error)
            throw error
        }
    }
    
    func processWebhook(data: Data, headers: [String: String]) async throws {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("MOCK_API") {
            APILogger.log("Processing mock webhook")
            try await Task.sleep(nanoseconds: 200_000_000)
            APILogger.log("Mock webhook processed successfully", type: .success)
            return
        }
        #endif
        
        APILogger.log("Processing webhook", type: .info)
        guard let webhookHandler = webhookHandler else {
            APILogger.log("Webhook handler not initialized", type: .error)
            throw APIError.custom("Webhook handler not initialized")
        }
        
        try await webhookHandler.processWebhookRequest(data: data, headers: headers)
        APILogger.log("Webhook processed successfully", type: .success)
    }
    
    // MARK: - Helper Methods
    
    private func mapToProductItemDTO(_ ebayItem: EbayItemSummary) -> ProductItemDTO {
        // Extract price and currency
        let itemPrice = ebayItem.price?.value ?? ""
        let currency = ebayItem.price?.currency ?? "USD"
        let price = Double(itemPrice) ?? 0.0
        
        // Extract original price if there's a marketing price
        var originalPrice: Double? = nil
        if let marketingPrice = ebayItem.marketingPrice,
            let origPrice = marketingPrice.originalPrice?.value {
            originalPrice = Double(origPrice)
        }
        
        // Fix image URLs to ensure they're valid
        var fixedImageUrls: [String] = []
        if let mainImage = ebayItem.image?.imageUrl {
            // Ensure URL is HTTPS
            let secureUrl = mainImage.replacingOccurrences(of: "http://", with: "https://")
            fixedImageUrls.append(secureUrl)
        }
        
        if let additionalImages = ebayItem.additionalImages {
            let secureAdditionalUrls = additionalImages.compactMap {
                $0.imageUrl?.replacingOccurrences(of: "http://", with: "https://")
            }
            fixedImageUrls.append(contentsOf: secureAdditionalUrls)
        }
        
        // Extract image URLs
        var imageUrls: [String] = []
        if let mainImage = ebayItem.image?.imageUrl {
            imageUrls.append(mainImage)
        }
        
        if let additionalImages = ebayItem.additionalImages {
            imageUrls.append(contentsOf: additionalImages.compactMap { $0.imageUrl })
        }
        
        if fixedImageUrls.isEmpty {
            fixedImageUrls.append("https://placehold.co/400x400?text=Product+Image")
        }
        
        // Determine if item is in stock
        let isInStock = ebayItem.estimatedAvailableQuantity != 0
        
        // Get category name
        let categoryId = ebayItem.primaryCategoryId ?? ebayItem.categories?.first?.categoryId
        let categoryName = ebayItem.categories?.first?.categoryName
        
        // Create review rating - eBay doesn't provide this directly, so we'll use the seller feedback
        let rating = Double(ebayItem.seller?.feedbackPercentage ?? "0") ?? 0.0
        let reviewCount = ebayItem.seller?.feedbackScore ?? 0
        
        return ProductItemDTO(
            sourceId: ebayItem.itemId,
            name: ebayItem.title,
            productDescription: ebayItem.condition,
            price: price,
            originalPrice: originalPrice,
            currency: currency,
            imageURL: fixedImageUrls.first.flatMap { URL(string: $0) },
            imageUrls: imageUrls,
            thumbnailUrl: ebayItem.thumbnailImages?.first?.imageUrl?.replacingOccurrences(of: "http://", with: "https://") ?? ebayItem.image?.imageUrl?.replacingOccurrences(of: "http://", with: "https://") ?? "https://placehold.co/200x200?text=Product+Image",
            brand: ebayItem.seller?.username ?? "eBay Seller",
            source: "eBay",
            category: categoryName ?? categoryId,
            isInStock: isInStock,
            rating: rating / 20, // Convert percentage to 5-star scale
            reviewCount: reviewCount
        )
    }
    
    // MARK: - Debugging and Troubleshooting
    
    /// A structured API logger for better debug output
    struct APILogger {
        static var isEnabled = true
        static var verboseMode = false
        
        static func log(_ message: String, type: LogType = .info) {
            guard isEnabled else { return }
            
            let prefix: String
            switch type {
            case .info:
                prefix = "📘 eBay API"
            case .success:
                prefix = "✅ eBay API"
            case .error:
                prefix = "❌ eBay API"
            case .warning:
                prefix = "⚠️ eBay API"
            case .network:
                prefix = "🌐 eBay API"
            }
            
            print("\(prefix): \(message)")
        }
        
        static func logRequest(_ request: URLRequest) {
            guard isEnabled else { return }
            
            log("Request URL: \(request.url?.absoluteString ?? "nil")", type: .network)
            
            if verboseMode {
                if let headers = request.allHTTPHeaderFields {
                    // Filter out sensitive headers
                    let safeHeaders = headers.filter { key, _ in
                        !key.lowercased().contains("authorization")
                    }
                    log("Request Headers: \(safeHeaders)", type: .network)
                }
                
                if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                    log("Request Body: \(bodyString)", type: .network)
                }
            }
        }
        
        static func logResponse(data: Data, response: URLResponse) {
            guard isEnabled else { return }
            
            if let httpResponse = response as? HTTPURLResponse {
                log("Response Status: \(httpResponse.statusCode)",
                    type: httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 ? .success : .error)
            }
            
            if verboseMode {
                // Log response preview
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                let previewLength = min(500, responseString.count)
                let responsePreview = String(responseString.prefix(previewLength))
                log("Response Preview: \(responsePreview)...", type: .network)
            }
        }
        
        enum LogType {
            case info
            case success
            case error
            case warning
            case network
        }
    }
    
    // MARK: - Debugging Configuration Methods
    
    /// Enable or disable verbose debugging
    static func setVerboseDebugging(_ enabled: Bool) {
        APILogger.isEnabled = true
        APILogger.verboseMode = enabled
        APILogger.log("Verbose debugging \(enabled ? "enabled" : "disabled")")
    }
    
    /// Toggle debugging completely on or off
    static func setDebugging(_ enabled: Bool) {
        APILogger.isEnabled = enabled
        APILogger.log("API debugging \(enabled ? "enabled" : "disabled")")
    }
    
    /// Test connectivity to the eBay API
    static func testConnectivity() async -> Bool {
        do {
            APILogger.log("Testing connectivity to eBay API...", type: .network)
            
            // Try to get an OAuth token as a basic connectivity test
            let oauthHandler = OAuthHandler()
            _ = try await oauthHandler.authorize(for: "ebay")
            
            APILogger.log("Connectivity test successful", type: .success)
            return true
        } catch {
            APILogger.log("Connectivity test failed: \(error)", type: .error)
            return false
        }
    }
    
    /// Generate a debug report with API status
    func generateDebugReport() -> String {
        var report = "eBay API Debug Report\n"
        report += "====================\n"
        report += "Date: \(Date())\n"
        report += "Mode: \(isSandbox ? "SANDBOX" : "PRODUCTION")\n"
        report += "API Base URLs:\n"
        report += "- Browse: \(browseBaseURL)\n"
        report += "- Feed: \(feedBaseURL)\n"
        report += "- Notification: \(notificationBaseURL)\n"
        report += "Tracked Items: \(UserDefaults.standard.stringArray(forKey: "ebay_tracked_items")?.count ?? 0)\n"
        
        // Add notification subscription info
        if let priceSub = UserDefaults.standard.string(forKey: "ebay_price_subscription_id") {
            report += "Price Change Subscription: \(priceSub)\n"
        } else {
            report += "Price Change Subscription: None\n"
        }
        
        if let inventorySub = UserDefaults.standard.string(forKey: "ebay_inventory_subscription_id") {
            report += "Inventory Change Subscription: \(inventorySub)\n"
        } else {
            report += "Inventory Change Subscription: None\n"
        }
        
        return report
    }
 }

// MARK: - APITestable Conformance

extension EbayAPIService: APITestable {
    func testConnection() async -> Bool {
        // Implement a simple connection test
        do {
            // Use a simple endpoint like categories to test the connection
            // If you already have a testAPIConnection method with a different name,
            // you can just call that from here
            let availableCategories = try await getAvailableFeedTypes()
            // If we get categories without error, connection is working
            return !availableCategories.isEmpty
        } catch {
            print("eBay API Connection test failed: \(error)")
            return false
        }
    }
}
