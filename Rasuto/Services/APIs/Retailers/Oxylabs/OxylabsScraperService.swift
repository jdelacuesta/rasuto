//
//  OxylabsScraperService.swift
//  Rasuto
//
//  Created for Oxylabs Web Scraper API integration on 6/4/25.
//

import Foundation

// MARK: - Oxylabs Scraper Service

@MainActor
class OxylabsScraperService: ObservableObject, RetailerAPIService {
    
    // MARK: - Properties
    
    static let shared = OxylabsScraperService()
    
    @Published var isLoading = false
    @Published var lastError: Error?
    @Published var cachedProducts: [ProductItemDTO] = []
    
    // MARK: - Configuration
    
    private let baseURL = "https://realtime.oxylabs.io/v1/queries"
    private var apiUsername: String = ""
    private var apiPassword: String = ""
    private let rateLimiter = OxylabsRateLimiter()
    private let cacheManager = OxylabsCacheManager()
    
    // MARK: - Session Configuration
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    // MARK: - Initialization
    
    private init() {
        loadAPICredentials()
    }
    
    // MARK: - API Credential Management
    
    private func loadAPICredentials() {
        // Load from DefaultKeys (which checks environment first, then defaults)
        apiUsername = DefaultKeys.oxylabsUsername
        apiPassword = DefaultKeys.oxylabsPassword
        
        print("🔧 Oxylabs credentials loaded: \(apiUsername.isEmpty ? "MISSING" : "OK") username, \(apiPassword.isEmpty ? "MISSING" : "OK") password")
    }
    
    func updateCredentials(username: String, password: String) {
        apiUsername = username
        apiPassword = password
        
        // Store securely in development
        UserDefaults.standard.set(username, forKey: "oxylabs_username")
        UserDefaults.standard.set(password, forKey: "oxylabs_password")
    }
    
    // MARK: - RetailerAPIService Protocol Implementation
    
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        return try await searchProducts(query: query, retailer: "amazon")
    }
    
    func getProductDetails(id: String) async throws -> ProductItemDTO {
        // For Oxylabs, the id is typically a URL
        return try await scrapeProductDetails(url: id) ?? {
            throw APIError.noData
        }()
    }
    
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
        // Extract product name from URL or use basic search
        let searchQuery = extractProductNameFromURL(id) ?? "related products"
        return try await searchProducts(query: searchQuery)
    }
    
    // MARK: - Search Products with Retailer Selection
    
    func searchProducts(query: String, retailer: String = "amazon") async throws -> [ProductItemDTO] {
        // Check rate limiting
        guard await rateLimiter.canMakeRequest() else {
            throw APIError.rateLimitExceeded()
        }
        
        // Check cache first
        let cacheKey = "\(retailer)_\(query)"
        if let cachedResults = await cacheManager.getCachedProducts(for: cacheKey) {
            print("🎯 Oxylabs: Using cached results for \(query)")
            return cachedResults
        }
        
        // Check quota protection
        if await shouldBlockAPIRequest(for: "oxylabs") {
            print("🛡️ Oxylabs: API request blocked by quota protection")
            throw APIError.quotaExceeded
        }
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let request = createScraperRequest(query: query, retailer: retailer)
            let products = try await performScraperRequest(request)
            
            // Cache results
            await cacheManager.cacheProducts(products, for: cacheKey)
            
            // Record request for rate limiting
            await rateLimiter.recordRequest()
            
            // Record for quota protection
            await QuotaProtectionManager.shared.recordAPIRequest()
            
            await MainActor.run {
                cachedProducts = products
            }
            
            print("✅ Oxylabs: Successfully scraped \(products.count) products for \(query)")
            return products
            
        } catch {
            await MainActor.run {
                lastError = error
            }
            print("❌ Oxylabs: Search failed - \(error)")
            throw error
        }
    }
    
    // MARK: - Product Detail Scraping
    
    func scrapeProductDetails(url: String) async throws -> ProductItemDTO? {
        guard await rateLimiter.canMakeRequest() else {
            throw APIError.rateLimitExceeded()
        }
        
        // Check cache
        if let cachedProduct = await cacheManager.getCachedProduct(for: url) {
            return cachedProduct
        }
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let request = createProductDetailRequest(url: url)
            let products = try await performScraperRequest(request)
            let product = products.first
            
            // Cache result
            if let product = product {
                await cacheManager.cacheProduct(product, for: url)
            }
            
            await rateLimiter.recordRequest()
            await QuotaProtectionManager.shared.recordAPIRequest()
            
            return product
            
        } catch {
            await MainActor.run {
                lastError = error
            }
            throw error
        }
    }
    
    // MARK: - Request Creation
    
    private func createScraperRequest(query: String, retailer: String) -> OxylabsScraperRequest {
        switch retailer.lowercased() {
        case "amazon":
            return OxylabsScraperRequest.amazon(searchQuery: query)
        case "walmart":
            return OxylabsScraperRequest.walmart(searchQuery: query)
        case "target":
            return OxylabsScraperRequest.target(searchQuery: query)
        case "homedepot":
            return OxylabsScraperRequest.homedepot(searchQuery: query)
        default:
            return OxylabsScraperRequest.amazon(searchQuery: query)
        }
    }
    
    private func createProductDetailRequest(url: String) -> OxylabsScraperRequest {
        return OxylabsScraperRequest(
            source: "universal_ecommerce",
            url: url,
            location: "United States",
            parseInstructions: .ecommerce,
            context: [
                ContextParameter(key: "autoparse", value: "true"),
                ContextParameter(key: "extract_details", value: "true")
            ]
        )
    }
    
    // MARK: - API Request Execution
    
    private func performScraperRequest(_ request: OxylabsScraperRequest) async throws -> [ProductItemDTO] {
        guard !apiUsername.isEmpty && !apiPassword.isEmpty else {
            throw APIError.authenticationFailed
        }
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Basic authentication
        let credentials = "\(apiUsername):\(apiPassword)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        urlRequest.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Request body
        let requestBody = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestBody
        
        print("🚀 Oxylabs: Making scraper request to \(request.url)")
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.authenticationFailed
        case 429:
            throw APIError.rateLimitExceeded()
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.custom("HTTP error: \(httpResponse.statusCode)")
        }
        
        do {
            let scraperResponse = try JSONDecoder().decode(OxylabsScraperResponse.self, from: data)
            return try parseScraperResponse(scraperResponse)
            
        } catch let decodingError {
            print("❌ Oxylabs: Decoding error - \(decodingError)")
            throw APIError.decodingFailed(decodingError)
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseScraperResponse(_ response: OxylabsScraperResponse) throws -> [ProductItemDTO] {
        var products: [ProductItemDTO] = []
        
        for result in response.results {
            guard result.statusCode == 200,
                  let content = result.content,
                  let productResults = content.results,
                  let scrapedProducts = productResults.products else {
                continue
            }
            
            for scrapedProduct in scrapedProducts {
                if let productDTO = convertToProductDTO(scrapedProduct, sourceURL: result.url) {
                    products.append(productDTO)
                }
            }
        }
        
        return products
    }
    
    private func convertToProductDTO(_ scrapedProduct: ScrapedProduct, sourceURL: String) -> ProductItemDTO? {
        guard let title = scrapedProduct.title,
              !title.isEmpty else {
            return nil
        }
        
        // Parse price
        let price = parsePrice(from: scrapedProduct.price)
        let originalPrice = parsePrice(from: scrapedProduct.originalPrice)
        
        // Determine retailer from source URL
        let retailer = determineRetailer(from: sourceURL)
        
        return ProductItemDTO(
            id: UUID(),
            sourceId: UUID().uuidString,
            name: title,
            productDescription: scrapedProduct.description,
            price: price,
            originalPrice: originalPrice,
            currency: "USD",
            imageURL: scrapedProduct.imageUrl != nil ? URL(string: scrapedProduct.imageUrl!) : nil,
            imageUrls: scrapedProduct.imageUrl != nil ? [scrapedProduct.imageUrl!] : nil,
            thumbnailUrl: scrapedProduct.imageUrl,
            brand: scrapedProduct.brand ?? "Unknown",
            source: retailer,
            category: "General",
            isInStock: scrapedProduct.availability?.lowercased().contains("in stock") ?? true,
            rating: scrapedProduct.rating,
            reviewCount: scrapedProduct.reviewCount,
            isFavorite: false,
            isTracked: false,
            productUrl: scrapedProduct.url ?? sourceURL
        )
    }
    
    // MARK: - Utility Functions
    
    private func parsePrice(from priceString: String?) -> Double? {
        guard let priceString = priceString else { return nil }
        
        // Remove currency symbols and extract numeric value
        let cleanPrice = priceString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleanPrice)
    }
    
    private func determineRetailer(from url: String) -> String {
        let lowercaseURL = url.lowercased()
        
        if lowercaseURL.contains("amazon") {
            return "Amazon"
        } else if lowercaseURL.contains("walmart") {
            return "Walmart"
        } else if lowercaseURL.contains("target") {
            return "Target"
        } else if lowercaseURL.contains("homedepot") {
            return "Home Depot"
        } else {
            return "Oxylabs"
        }
    }
    
    private func extractProductNameFromURL(_ url: String) -> String? {
        // Simple extraction from URL path
        let components = url.components(separatedBy: "/")
        
        // Look for product names in URL segments
        for component in components {
            if component.count > 10 && component.contains("-") {
                // Clean up URL encoding and hyphens
                let cleaned = component
                    .replacingOccurrences(of: "-", with: " ")
                    .removingPercentEncoding ?? component
                
                if !cleaned.isEmpty && cleaned.count > 3 {
                    return cleaned
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Health Check
    
    func healthCheck() async -> Bool {
        do {
            let testRequest = OxylabsScraperRequest(
                source: "universal",
                url: "https://httpbin.org/status/200",
                location: nil,
                parseInstructions: nil,
                context: nil
            )
            
            _ = try await performScraperRequest(testRequest)
            return true
            
        } catch {
            print("❌ Oxylabs: Health check failed - \(error)")
            return false
        }
    }
    
    // MARK: - Usage Statistics
    
    func getUsageStatistics() async -> OxylabsUsageInfo? {
        return await rateLimiter.getUsageInfo()
    }
}

// MARK: - Supporting Types

enum OxylabsError: Error, LocalizedError {
    case invalidCredentials
    case quotaExceeded
    case rateLimitExceeded
    case invalidURL
    case noResults
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid Oxylabs credentials"
        case .quotaExceeded:
            return "Oxylabs quota exceeded"
        case .rateLimitExceeded:
            return "Oxylabs rate limit exceeded"
        case .invalidURL:
            return "Invalid URL for scraping"
        case .noResults:
            return "No results found"
        case .parsingError:
            return "Failed to parse scraper response"
        }
    }
}
