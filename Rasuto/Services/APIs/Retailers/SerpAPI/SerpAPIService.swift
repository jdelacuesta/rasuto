//
//  SerpAPIService.swift
//  Rasuto
//
//  Created for SerpAPI integration on 6/2/25.
//

import Foundation

// MARK: - Main SerpAPI Service

class SerpAPIService: RetailerAPIService, ObservableObject {
    
    // MARK: - Configuration
    
    private let apiKey: String
    private let baseURL = "https://serpapi.com/search"
    private let engine: SerpAPIEngine
    
    // MARK: - Published Properties
    
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    @Published private(set) var requestCount = 0
    @Published private(set) var quotaRemaining = 100
    
    // MARK: - Infrastructure
    
    private lazy var urlSession: URLSession = {
        // Use ephemeral config to avoid connection reuse issues
        let configuration = URLSessionConfiguration.ephemeral
        
        // Shorter timeouts for faster failure/retry
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // Force IPv4 to avoid IPv6/QUIC issues
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        
        // Conservative connection settings
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpShouldUsePipelining = false
        configuration.httpShouldSetCookies = false
        
        // Minimal headers to avoid protocol negotiation issues
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            "Accept": "application/json",
            "Accept-Encoding": "gzip",
            "Connection": "close"
        ]
        
        // Create custom delegate to handle connection issues
        let delegate = SerpAPIURLSessionDelegate()
        
        return URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }()
    
    private let cacheManager = SerpAPICacheManager.shared
    private let rateLimiter: SerpAPIRateLimiter
    
    // MARK: - Initialization
    
    init(apiKey: String, engine: SerpAPIEngine, monthlyLimit: Int = 100) {
        self.apiKey = apiKey
        self.engine = engine
        self.rateLimiter = SerpAPIRateLimiter(monthlyLimit: monthlyLimit)
        
        print("✅ SerpAPI Service initialized for \(engine.displayName)")
        print("🔑 API Key: \(apiKey.prefix(8))...")
    }
    
    // MARK: - Factory Methods
    
    static func googleShopping(apiKey: String) -> SerpAPIService {
        return SerpAPIService(apiKey: apiKey, engine: .googleShopping)
    }
    
    static func ebayProduction(apiKey: String) -> SerpAPIService {
        return SerpAPIService(apiKey: apiKey, engine: .ebay)
    }
    
    static func walmartProduction(apiKey: String) -> SerpAPIService {
        return SerpAPIService(apiKey: apiKey, engine: .walmart)
    }
    
    static func homeDepot(apiKey: String) -> SerpAPIService {
        return SerpAPIService(apiKey: apiKey, engine: .homeDepot)
    }
    
    static func amazon(apiKey: String) -> SerpAPIService {
        return SerpAPIService(apiKey: apiKey, engine: .amazon)
    }
    
    // MARK: - RetailerAPIService Protocol Implementation
    
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        defer { 
            Task { @MainActor in
                isLoading = false 
            }
        }
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        print("🔍 SerpAPI Search: '\(query)' on \(engine.displayName)")
        
        // Generate cache key
        let cacheKey = await cacheManager.generateSearchKey(
            query: query, 
            engine: engine,
            options: SerpAPISearchOptions()
        )
        
        // Check cache first
        if let cachedResults = await cacheManager.getCachedSearchResults(for: cacheKey) {
            print("🔄 Using cached results for \(engine.displayName) search")
            return cachedResults
        }
        
        // Check global quota protection first
        if await shouldBlockAPIRequest(for: "serpapi_\(engine)") {
            print("🛡️ QUOTA PROTECTION: SerpAPI \(engine) request blocked")
            // Return cached results if available
            if let cachedResults = await cacheManager.getCachedSearchResults(for: cacheKey) {
                print("📦 Returning cached results for quota protection")
                return cachedResults
            }
            throw APIError.quotaExceeded
        } else {
            print("✅ QUOTA CHECK PASSED: SerpAPI \(engine) request allowed - proceeding with live API call")
        }
        
        // Check rate limits
        guard await rateLimiter.canMakeRequest() else {
            print("⚠️ Rate limit reached for \(engine.displayName)")
            throw APIError.rateLimitExceeded()
        }
        
        do {
            let products = try await performSearch(query: query)
            
            // Record successful request
            await rateLimiter.recordRequest()
            
            // Cache results
            await cacheManager.cacheSearchResults(products, for: cacheKey)
            
            // Update quota tracking
            await updateQuotaUsage()
            
            // Record in global quota protection
            await QuotaProtectionManager.shared.recordAPIRequest()
            
            print("✅ SerpAPI search completed: \(products.count) results from \(engine.displayName)")
            return products
            
        } catch {
            await MainActor.run {
                lastError = error
            }
            print("❌ SerpAPI search failed for \(engine.displayName): \(error)")
            throw error
        }
    }
    
    func getProductDetails(id: String) async throws -> ProductItemDTO {
        defer { 
            Task { @MainActor in
                isLoading = false 
            }
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        print("🔍 SerpAPI Product Details: \(id) on \(engine.displayName)")
        
        // Check cache first
        let cacheKey = await cacheManager.generateProductKey(productId: id, engine: engine)
        if let cachedProduct = await cacheManager.getCachedProduct(id: cacheKey) {
            return cachedProduct
        }
        
        // For SerpAPI, we search for the specific product ID or title
        let searchResults = try await searchProducts(query: id)
        
        if let product = searchResults.first {
            await cacheManager.cacheProduct(product)
            return product
        }
        
        throw APIError.noData
    }
    
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
        defer { 
            Task { @MainActor in
                isLoading = false 
            }
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        // Get the base product first
        let baseProduct = try await getProductDetails(id: id)
        
        // Extract search terms from product name
        let searchQuery = extractSearchTerms(from: baseProduct.name)
        let relatedResults = try await searchProducts(query: searchQuery)
        
        // Filter out the original product and limit results
        return Array(relatedResults.filter { $0.sourceId != id }.prefix(5))
    }
    
    // MARK: - Private Search Implementation
    
    private func performSearch(query: String) async throws -> [ProductItemDTO] {
        let url = try buildSearchURL(query: query)
        var request = buildRequest(url: url)
        
        // Mask the API key in logs for security
        var logURL = url.absoluteString
        if let range = logURL.range(of: "api_key=") {
            let keyStart = logURL.index(range.upperBound, offsetBy: 0)
            let keyEnd = logURL[keyStart...].firstIndex(of: "&") ?? logURL.endIndex
            let maskedKey = String(logURL[keyStart..<logURL.index(keyStart, offsetBy: min(8, logURL.distance(from: keyStart, to: keyEnd)))]) + "..."
            logURL = logURL.replacingCharacters(in: keyStart..<keyEnd, with: maskedKey)
        }
        print("🌐 SerpAPI Request: \(logURL)")
        
        // Retry logic for network errors
        let maxRetries = 2
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                // Add delay between retries
                if attempt > 0 {
                    let delay = Double(attempt) * 2.0 // 2s, 4s
                    print("🔄 Retry attempt \(attempt) after \(delay)s delay")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                // Set a custom timeout for this specific request
                request.timeoutInterval = 30.0
                
                // Use modern async/await with proper error handling
                let (data, response): (Data, URLResponse)
                
                do {
                    // Modern networking with waitsForConnectivity support
                    (data, response) = try await urlSession.data(for: request)
                    print("📡 SerpAPI received \(data.count) bytes")
                } catch {
                    // Handle specific network errors with modern error handling
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .timedOut:
                            print("⏰ Request timed out - will retry")
                            throw URLError(.timedOut)
                        case .networkConnectionLost:
                            print("📶 Network connection lost - will retry") 
                            throw URLError(.networkConnectionLost)
                        case .notConnectedToInternet:
                            print("🚫 No internet connection")
                            throw URLError(.notConnectedToInternet)
                        default:
                            print("🔧 Network error: \(urlError.localizedDescription)")
                            throw error
                        }
                    } else {
                        throw error
                    }
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                print("📡 SerpAPI Response: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200:
                    return try await parseSearchResponse(data)
                case 401:
                    throw APIError.authenticationFailed
                case 429:
                    // For rate limiting, wait longer before retry
                    if attempt < maxRetries {
                        print("⏳ Rate limited - waiting 10s before retry")
                        try await Task.sleep(nanoseconds: 10_000_000_000)
                    }
                    throw APIError.rateLimitExceeded()
                default:
                    // Log error details for debugging
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ SerpAPI Error Response: \(errorString)")
                    }
                    throw APIError.serverError(httpResponse.statusCode)
                }
                
            } catch let error as NSError {
                lastError = error
                
                // Check if it's a network error that we should retry
                if error.domain == NSURLErrorDomain {
                    switch error.code {
                    case NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost:
                        print("⚠️ Network error on attempt \(attempt): \(error.localizedDescription)")
                        if attempt < maxRetries {
                            continue // Retry
                        }
                    case NSURLErrorNotConnectedToInternet:
                        throw error // Don't retry if no internet
                    default:
                        break
                    }
                }
                
                // Don't retry for non-network errors
                throw error
            }
        }
        
        throw lastError ?? APIError.custom("Search failed after \(maxRetries) retries")
    }
    
    private func buildSearchURL(query: String) throws -> URL {
        var components = URLComponents(string: baseURL)!
        
        var queryItems = [
            URLQueryItem(name: "engine", value: engine.rawValue),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "q", value: query),
        ]
        
        // Add engine-specific parameters
        switch engine {
        case .googleShopping:
            queryItems.append(contentsOf: [
                URLQueryItem(name: "google_domain", value: "google.com"),
                URLQueryItem(name: "gl", value: "us"),
                URLQueryItem(name: "hl", value: "en"),
                URLQueryItem(name: "location", value: "United States"),
                URLQueryItem(name: "num", value: "20")
            ])
            
        case .ebay:
            queryItems.append(contentsOf: [
                URLQueryItem(name: "ebay_domain", value: "ebay.com"),
                URLQueryItem(name: "_nkw", value: query),
                URLQueryItem(name: "_sacat", value: "0") // All categories
            ])
            
        case .walmart:
            queryItems.append(contentsOf: [
                URLQueryItem(name: "query", value: query)
            ])
            
        case .homeDepot:
            queryItems.append(contentsOf: [
                URLQueryItem(name: "q", value: query)
            ])
            
        case .amazon:
            queryItems.append(contentsOf: [
                URLQueryItem(name: "k", value: query),
                URLQueryItem(name: "ref", value: "sr_pg_1")
            ])
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        return url
    }
    
    private func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Rasuto/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }
    
    private func parseSearchResponse(_ data: Data) async throws -> [ProductItemDTO] {
        let decoder = JSONDecoder()
        
        do {
            switch engine {
            case .googleShopping, .homeDepot, .amazon:
                let response = try decoder.decode(SerpAPIResponse.self, from: data)
                
                if let error = response.error {
                    throw APIError.custom("SerpAPI Error: \(error)")
                }
                
                guard let shoppingResults = response.shoppingResults else {
                    return []
                }
                
                // Cache metadata if available
                if let metadata = response.searchMetadata {
                    await cacheManager.cacheMetadata(metadata, for: "last_search_\(engine.rawValue)")
                }
                
                return shoppingResults.compactMap { mapShoppingResult($0) }
                
            case .ebay:
                let response = try decoder.decode(SerpEbaySearchResponse.self, from: data)
                
                if let error = response.error {
                    throw APIError.custom("SerpAPI Error: \(error)")
                }
                
                guard let ebayResults = response.ebayResults else {
                    return []
                }
                
                return ebayResults.compactMap { mapSerpEbayResult($0) }
                
            case .walmart:
                let response = try decoder.decode(WalmartSearchResponse.self, from: data)
                
                if let error = response.error {
                    throw APIError.custom("SerpAPI Error: \(error)")
                }
                
                guard let walmartResults = response.walmartResults else {
                    return []
                }
                
                return walmartResults.compactMap { mapWalmartResult($0) }
            }
            
        } catch {
            print("❌ SerpAPI Parse Error: \(error)")
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Raw Response: \(responseString.prefix(500))...")
            }
            
            throw APIError.decodingFailed(error)
        }
    }
    
    // MARK: - Result Mapping
    
    private func mapShoppingResult(_ result: ShoppingResult) -> ProductItemDTO? {
        guard let title = result.title else {
            return nil
        }
        
        let productId = result.productId ?? "\(engine.rawValue)_\(result.position ?? 0)"
        let price = result.extractedPrice ?? 0.0
        let source = result.source ?? engine.displayName
        
        // Extract category from product title using keywords
        let category = extractCategoryFromTitle(title)
        
        // Generate intelligent description from product name and category
        let smartDescription = generateSmartDescription(title: title, category: category, price: price)
        
        return ProductItemDTO(
            sourceId: productId,
            name: title,
            productDescription: smartDescription,
            price: price > 0 ? price : nil,
            currency: "USD",
            imageURL: result.thumbnail.flatMap { URL(string: $0) },
            imageUrls: result.thumbnail.map { [$0] },
            thumbnailUrl: result.thumbnail,
            brand: source,
            source: engine.displayName,
            category: category,
            isInStock: true,
            rating: result.rating,
            reviewCount: result.ratingCount,
            productUrl: result.link
        )
    }
    
    private func mapSerpEbayResult(_ result: SerpEbayResult) -> ProductItemDTO? {
        guard let title = result.title else {
            return nil
        }
        
        let productId = "ebay_\(result.position ?? 0)"
        let price = result.price?.extracted?.first ?? 0.0
        let category = extractCategoryFromTitle(title)
        
        // Generate smart description, combining condition with generated description
        var smartDescription = generateSmartDescription(title: title, category: category, price: price)
        if let condition = result.condition, !condition.isEmpty {
            smartDescription += " Condition: \(condition)."
        }
        
        return ProductItemDTO(
            sourceId: productId,
            name: title,
            productDescription: smartDescription,
            price: price > 0 ? price : nil,
            currency: "USD",
            imageURL: result.thumbnail.flatMap { URL(string: $0) },
            imageUrls: result.thumbnail.map { [$0] },
            thumbnailUrl: result.thumbnail,
            brand: result.seller?.name ?? "eBay Seller",
            source: "eBay",
            category: category,
            isInStock: true,
            rating: result.seller?.rating,
            reviewCount: result.ratingsCount,
            productUrl: result.link
        )
    }
    
    private func mapWalmartResult(_ result: WalmartResult) -> ProductItemDTO? {
        guard let title = result.title else {
            return nil
        }
        
        let productId = result.productId ?? "walmart_\(result.position ?? 0)"
        let price = result.price?.currentRaw ?? result.primaryOffer?.priceRaw ?? 0.0
        let category = extractCategoryFromTitle(title)
        
        // Generate smart description for Walmart products
        let smartDescription = generateSmartDescription(title: title, category: category, price: price)
        
        return ProductItemDTO(
            sourceId: productId,
            name: title,
            productDescription: smartDescription,
            price: price > 0 ? price : nil,
            currency: "USD",
            imageURL: result.thumbnail.flatMap { URL(string: $0) },
            imageUrls: result.thumbnail.map { [$0] },
            thumbnailUrl: result.thumbnail,
            brand: result.seller?.name ?? "Walmart",
            source: "Walmart",
            category: category,
            isInStock: true,
            rating: result.rating,
            reviewCount: result.ratingsCount,
            productUrl: result.link
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractSearchTerms(from productName: String) -> String {
        let words = productName.components(separatedBy: .whitespacesAndNewlines)
        let filteredWords = words.filter { word in
            word.count > 3 && !["with", "from", "that", "this", "for", "and"].contains(word.lowercased())
        }
        return Array(filteredWords.prefix(3)).joined(separator: " ")
    }
    
    private func extractCategoryFromTitle(_ title: String) -> String {
        let lowercaseTitle = title.lowercased()
        
        // Define category mappings based on keywords
        let categoryMappings: [(keywords: [String], category: String)] = [
            (["iphone", "ipad", "macbook", "airpods", "apple watch", "mac"], "Apple"),
            (["headphones", "earbuds", "speakers", "audio"], "Audio"),
            (["laptop", "computer", "desktop", "monitor"], "Computers"),
            (["phone", "smartphone", "mobile"], "Phones"),
            (["tv", "television", "roku", "streaming"], "Entertainment"),
            (["camera", "photography", "lens"], "Photography"),
            (["gaming", "playstation", "xbox", "nintendo"], "Gaming"),
            (["kitchen", "cooking", "instant pot", "coffee"], "Kitchen"),
            (["home", "smart home", "echo", "alexa"], "Smart Home"),
            (["clothing", "shirt", "dress", "shoes"], "Fashion"),
            (["book", "kindle", "reading"], "Books"),
            (["fitness", "exercise", "sports"], "Sports & Fitness"),
            (["beauty", "skincare", "makeup"], "Beauty"),
            (["tool", "hardware", "construction"], "Tools"),
            (["car", "automotive", "vehicle"], "Automotive")
        ]
        
        // Check each category mapping
        for mapping in categoryMappings {
            if mapping.keywords.contains(where: { lowercaseTitle.contains($0) }) {
                return mapping.category
            }
        }
        
        return "Electronics" // Default category
    }
    
    private func generateSmartDescription(title: String, category: String, price: Double) -> String {
        let lowercaseTitle = title.lowercased()
        
        // Extract key features from the title
        var features: [String] = []
        
        // Common feature patterns to look for
        let featurePatterns: [(pattern: [String], description: String)] = [
            (["wireless", "bluetooth"], "wireless connectivity"),
            (["4k", "ultra hd", "uhd"], "4K Ultra HD resolution"),
            (["smart", "wifi"], "smart features"),
            (["noise cancel", "anc"], "noise cancelling technology"),
            (["waterproof", "water resistant"], "water resistance"),
            (["fast charg", "quick charg", "rapid charg"], "fast charging"),
            (["oled", "led", "lcd"], "high-quality display"),
            (["portable", "compact"], "portable design"),
            (["professional", "pro"], "professional-grade performance"),
            (["gaming"], "gaming optimized"),
            (["hd", "high definition"], "high definition"),
            (["stereo", "surround"], "premium audio"),
            (["touch", "touchscreen"], "touch interface"),
            (["remote", "control"], "remote control functionality"),
            (["rechargeable", "battery"], "long-lasting battery"),
            (["stainless steel", "aluminum"], "premium materials"),
            (["digital", "electronic"], "digital technology")
        ]
        
        // Find matching features
        for pattern in featurePatterns {
            if pattern.pattern.contains(where: { lowercaseTitle.contains($0) }) {
                features.append(pattern.description)
            }
        }
        
        // Generate category-specific description templates
        let categoryDescriptions: [String: String] = [
            "Apple": "Premium Apple product designed for seamless integration with your Apple ecosystem.",
            "Audio": "High-quality audio device engineered for superior sound experience.",
            "Computers": "Powerful computing device built for productivity and performance.",
            "Phones": "Advanced smartphone featuring cutting-edge mobile technology.",
            "Entertainment": "Entertainment device designed to enhance your viewing experience.",
            "Photography": "Professional photography equipment for capturing stunning images.",
            "Gaming": "Gaming device optimized for immersive entertainment and performance.",
            "Kitchen": "Essential kitchen appliance designed to simplify your cooking experience.",
            "Smart Home": "Smart home device that brings convenience and automation to your living space.",
            "Fashion": "Stylish and comfortable fashion item crafted with attention to detail.",
            "Sports & Fitness": "Fitness equipment designed to support your active lifestyle.",
            "Beauty": "Beauty product formulated to enhance your daily routine.",
            "Tools": "Professional-grade tool built for durability and precision.",
            "Electronics": "Innovative electronic device featuring modern technology and design."
        ]
        
        // Start with category-specific description
        var description = categoryDescriptions[category] ?? categoryDescriptions["Electronics"]!
        
        // Add feature highlights if any were found
        if !features.isEmpty {
            let featureText = features.prefix(3).joined(separator: ", ")
            description += " Features \(featureText) for enhanced functionality."
        }
        
        // Add value proposition based on price
        if price > 0 {
            if price < 50 {
                description += " Great value for everyday use."
            } else if price < 200 {
                description += " Excellent balance of quality and affordability."
            } else if price < 500 {
                description += " Premium quality with professional-grade features."
            } else {
                description += " Top-tier luxury item with exceptional build quality."
            }
        }
        
        return description
    }
    
    private func updateQuotaUsage() async {
        let stats = await rateLimiter.getUsageStatistics()
        
        await MainActor.run {
            requestCount += 1
            quotaRemaining = stats.monthlyRemaining
        }
        
        print("📊 SerpAPI Usage: \(stats.monthlyUsed)/\(stats.monthlyLimit) (\(quotaRemaining) remaining)")
    }
    
    // MARK: - Public Usage Methods
    
    func getUsageStatistics() async -> SerpAPIRateLimiter.UsageStatistics {
        return await rateLimiter.getUsageStatistics()
    }
    
    func getCacheStatistics() async -> SerpAPICacheManager.CacheStatistics {
        return await cacheManager.getCacheStatistics()
    }
}

// MARK: - Modern URL Session Delegate

class SerpAPIURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            print("🔧 SerpAPI session invalidated: \(error.localizedDescription)")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("🔧 SerpAPI task error: \(error.localizedDescription)")
        } else {
            print("✅ SerpAPI task completed successfully")
        }
    }
}
