//
//  AxessoAmazonAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 6/3/25.
//

import Foundation

// MARK: - Main Axesso Amazon API Service

class AxessoAmazonAPIService: RetailerAPIService, ObservableObject {
    
    // MARK: - Configuration
    
    private let apiKey: String
    private let baseURL = "https://api.axesso.de"
    
    // MARK: - Published Properties
    
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    @Published private(set) var requestCount = 0
    @Published private(set) var quotaRemaining = 1000
    
    // MARK: - Infrastructure
    
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpShouldUsePipelining = false
        configuration.httpShouldSetCookies = false
        
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        
        return URLSession(configuration: configuration)
    }()
    
    private let cacheManager = AxessoAmazonCacheManager()
    private let rateLimiter = AxessoAmazonRateLimiter()
    
    // MARK: - Initialization
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - RetailerAPIService Conformance
    
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        // Input validation and sanitization
        try InputSanitizer.shared.validateSearchQuery(query)
        let sanitizedQuery = InputSanitizer.shared.sanitizeSearchQuery(query)
        
        try await rateLimiter.checkRateLimit()
        
        if let cachedProducts = cacheManager.getCachedSearchResults(for: sanitizedQuery) {
            return cachedProducts
        }
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        do {
            let searchResults = try await performProductSearch(query: sanitizedQuery)
            let products = searchResults.compactMap { convertToProductItemDTO($0) }
            
            cacheManager.cacheSearchResults(products, for: sanitizedQuery)
            await updateRequestCount()
            
            return products
        } catch {
            await MainActor.run { 
                lastError = error
                APILogger.shared.logError(
                    error as? APIError ?? APIError.unknownError(error),
                    context: "searchProducts",
                    apiType: "Axesso"
                )
            }
            throw error
        }
    }
    
    func getProductDetails(id: String) async throws -> ProductItemDTO {
        try await rateLimiter.checkRateLimit()
        
        if let cachedProduct = cacheManager.getCachedProductDetails(for: id) {
            return cachedProduct
        }
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        do {
            let productDetails = try await performProductLookup(url: id)
            guard let product = convertProductDetailsToDTO(productDetails) else {
                throw APIError.noData
            }
            
            cacheManager.cacheProductDetails(product, for: id)
            await updateRequestCount()
            
            return product
        } catch {
            await MainActor.run { 
                lastError = error
                APILogger.shared.logError(
                    error as? APIError ?? APIError.unknownError(error),
                    context: "getProductDetails",
                    apiType: "Axesso"
                )
            }
            throw error
        }
    }
    
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
        return []
    }
    
    // MARK: - Helper Methods
    
    private func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "axesso-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        return request
    }
    
    // MARK: - Core API Methods
    
    func performProductSearch(query: String, page: Int = 1, sortBy: String = "relevanceblender") async throws -> [AxessoAmazonSearchResult] {
        // Correct Azure API endpoints from https://axesso.developer.azure-api.net/
        let possibleEndpoints = [
            "/amz/amazon-search-by-keyword-v2",  // Correct Azure API endpoint
            "/amz/amazon-search-by-keyword",     // Fallback v1
            "/amz/amazon-lookup-product",        // Alternative lookup
            "/amazon-search-by-keyword",         // Without /amz prefix
            "/v2/amazon-search-by-keyword"       // Version 2
        ]
        
        for endpoint in possibleEndpoints {
            do {
                print("🔍 Trying Axesso endpoint: \(baseURL)\(endpoint)")
                let results = try await attemptSearch(endpoint: endpoint, query: query, page: page, sortBy: sortBy)
                print("✅ Found working Axesso endpoint: \(endpoint)")
                return results
            } catch APIError.serverError(404) {
                print("❌ Endpoint \(endpoint) not found (404), trying next...")
                continue
            } catch {
                print("⚠️ Endpoint \(endpoint) failed with: \(error), trying next...")
                continue
            }
        }
        
        throw APIError.custom("No valid Axesso search endpoint found. Tried: \(possibleEndpoints.joined(separator: ", "))")
    }
    
    private func attemptSearch(endpoint: String, query: String, page: Int, sortBy: String) async throws -> [AxessoAmazonSearchResult] {
        var components = URLComponents(string: "\(baseURL)\(endpoint)")!
        
        components.queryItems = [
            URLQueryItem(name: "keyword", value: query),
            URLQueryItem(name: "domainCode", value: "com"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sortBy", value: sortBy)
        ]
        
        guard let url = components.url else {
            throw APIError.malformedRequest("Invalid URL components for Axesso search")
        }
        
        print("🔍 Axesso API Request URL: \(url)")
        print("🔗 Full URL with query: \(url.absoluteString)")
        
        let request = createRequest(url: url)
        print("🔑 Using API Key in header: \(apiKey.prefix(8))...")
        print("📋 Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📡 Axesso API Response Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ Axesso API Error Response (\(httpResponse.statusCode)): \(responseString)")
            print("❌ Response Headers: \(httpResponse.allHeaderFields)")
            
            if httpResponse.statusCode == 401 {
                throw APIError.authenticationFailed
            } else if httpResponse.statusCode == 404 {
                throw APIError.custom("API endpoint not found: \(url.absoluteString)")
            } else {
                throw APIError.serverError(httpResponse.statusCode)
            }
        }
        
        do {
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 Axesso API Raw Response: \(responseString.prefix(500))...")
            }
            
            let searchResponse = try JSONDecoder().decode(AxessoAmazonSearchResponse.self, from: data)
            
            print("✅ Axesso API Decoded Response Status: \(searchResponse.responseStatus ?? "nil")")
            print("📊 Found Products Count: \(searchResponse.foundProducts?.count ?? 0)")
            
            if searchResponse.responseStatus != "PRODUCT_FOUND_RESPONSE" {
                print("⚠️ Axesso API Message: \(searchResponse.responseMessage ?? "No message")")
                throw APIError.custom(searchResponse.responseMessage ?? "Search failed")
            }
            
            return searchResponse.foundProducts ?? []
        } catch {
            print("🚨 Axesso API Decoding Error: \(error)")
            throw APIError.decodingFailed(error)
        }
    }
    
    func performProductLookup(url: String) async throws -> AxessoAmazonProductDetails {
        var components = URLComponents(string: "\(baseURL)/amz/amazon-lookup-product")!
        
        components.queryItems = [
            URLQueryItem(name: "url", value: url)
        ]
        
        guard let requestURL = components.url else {
            throw APIError.malformedRequest("Invalid URL components")
        }
        
        let request = createRequest(url: requestURL)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            let productResponse = try JSONDecoder().decode(AxessoAmazonProductDetailsResponse.self, from: data)
            
            if productResponse.responseStatus != "PRODUCT_FOUND_RESPONSE" {
                throw APIError.custom(productResponse.responseMessage ?? "Product lookup failed")
            }
            
            return productResponse
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    func getProductReviews(url: String, page: Int = 1) async throws -> AxessoAmazonReviewsResponse {
        var components = URLComponents(string: "\(baseURL)/amz/amazon-lookup-reviews")!
        
        components.queryItems = [
            URLQueryItem(name: "url", value: url),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let requestURL = components.url else {
            throw APIError.malformedRequest("Invalid URL components")
        }
        
        let request = createRequest(url: requestURL)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(AxessoAmazonReviewsResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    func getProductPrices(url: String) async throws -> AxessoAmazonPricesResponse {
        var components = URLComponents(string: "\(baseURL)/amazon-lookup-prices")!
        
        components.queryItems = [
            URLQueryItem(name: "url", value: url)
        ]
        
        guard let requestURL = components.url else {
            throw APIError.malformedRequest("Invalid URL components")
        }
        
        let request = createRequest(url: requestURL)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(AxessoAmazonPricesResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    // MARK: - Advanced API Methods (Phase 4)
    
    func getSellerInfo(sellerId: String) async throws -> AxessoAmazonSellerResponse {
        var components = URLComponents(string: "\(baseURL)/amazon-lookup-seller")!
        
        components.queryItems = [
            URLQueryItem(name: "sellerId", value: sellerId),
            URLQueryItem(name: "domainCode", value: "com")
        ]
        
        guard let requestURL = components.url else {
            throw APIError.malformedRequest("Invalid URL components")
        }
        
        let request = createRequest(url: requestURL)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(AxessoAmazonSellerResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    func getSellerProducts(sellerId: String, page: Int = 1) async throws -> AxessoAmazonSellerProductsResponse {
        var components = URLComponents(string: "\(baseURL)/amazon-seller-products")!
        
        components.queryItems = [
            URLQueryItem(name: "sellerId", value: sellerId),
            URLQueryItem(name: "domainCode", value: "com"),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let requestURL = components.url else {
            throw APIError.malformedRequest("Invalid URL components")
        }
        
        let request = createRequest(url: requestURL)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(AxessoAmazonSellerProductsResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    func getBestSellers(categoryId: String? = nil) async throws -> AxessoAmazonBestSellersResponse {
        var components = URLComponents(string: "\(baseURL)/amz/amazon-best-sellers-list")!
        
        var queryItems = [
            URLQueryItem(name: "domainCode", value: "com")
        ]
        
        if let categoryId = categoryId {
            queryItems.append(URLQueryItem(name: "categoryId", value: categoryId))
        }
        
        components.queryItems = queryItems
        
        guard let requestURL = components.url else {
            throw APIError.malformedRequest("Invalid URL components")
        }
        
        let request = createRequest(url: requestURL)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(AxessoAmazonBestSellersResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    func searchDeals(keyword: String? = nil, page: Int = 1) async throws -> AxessoAmazonDealsResponse {
        // Correct Azure API endpoints for deals/best sellers
        let possibleEndpoints = [
            "/amz/amazon-best-seller",           // Best seller endpoint from Azure API
            "/amz/amazon-search-by-keyword-v2",  // Search with deals filter
            "/amz/amazon-deals-search",          // Legacy deals search
            "/amz/amazon-lookup-product",        // Product lookup
            "/amazon-deals"                      // Fallback
        ]
        
        for endpoint in possibleEndpoints {
            var components = URLComponents(string: "\(baseURL)\(endpoint)")!
            
            var queryItems = [
                URLQueryItem(name: "domainCode", value: "com"),
                URLQueryItem(name: "page", value: String(page))
            ]
            
            if let keyword = keyword {
                queryItems.append(URLQueryItem(name: "keyword", value: keyword))
            }
            
            components.queryItems = queryItems
            
            guard let requestURL = components.url else {
                continue
            }
            
            print("🔥 Trying deals endpoint: \(requestURL.absoluteString)")
            
            let request = createRequest(url: requestURL)
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                continue
            }
            
            print("📡 Deals API Response Status for \(endpoint): \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                do {
                    let dealsResponse = try JSONDecoder().decode(AxessoAmazonDealsResponse.self, from: data)
                    print("✅ Successfully found deals endpoint: \(endpoint)")
                    return dealsResponse
                } catch {
                    print("⚠️ Endpoint \(endpoint) returned 200 but decoding failed: \(error)")
                    continue
                }
            } else if httpResponse.statusCode == 404 {
                print("❌ Endpoint \(endpoint) not found (404)")
                continue
            } else {
                print("❌ Endpoint \(endpoint) returned error: \(httpResponse.statusCode)")
                continue
            }
        }
        
        // If all endpoints failed, throw error
        throw APIError.custom("No valid deals endpoint found. Tried: \(possibleEndpoints.joined(separator: ", "))")
    }
    
    func filterDeals(minPrice: Double? = nil, maxPrice: Double? = nil, discountPercent: Int? = nil) async throws -> AxessoAmazonDealsResponse {
        var components = URLComponents(string: "\(baseURL)/v2/amazon-deal-filter")!
        
        var queryItems = [
            URLQueryItem(name: "domainCode", value: "com")
        ]
        
        if let minPrice = minPrice {
            queryItems.append(URLQueryItem(name: "minPrice", value: String(minPrice)))
        }
        
        if let maxPrice = maxPrice {
            queryItems.append(URLQueryItem(name: "maxPrice", value: String(maxPrice)))
        }
        
        if let discountPercent = discountPercent {
            queryItems.append(URLQueryItem(name: "discountPercent", value: String(discountPercent)))
        }
        
        components.queryItems = queryItems
        
        guard let requestURL = components.url else {
            throw APIError.malformedRequest("Invalid URL components")
        }
        
        let request = createRequest(url: requestURL)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(AxessoAmazonDealsResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    // MARK: - Demo Mode Support
    
    func getReliableDemoProduct() async throws -> ProductItemDTO {
        // Use a well-known, stable Amazon product that should always be available
        // Amazon Echo Dot is consistently available with stable ASIN
        let reliableASINs = [
            "B09B8V1LZ3", // Echo Dot (5th Gen, 2022 release)
            "B07FZ8S74R", // Echo Dot (3rd Gen) - older but very stable
            "B08KJN3333", // Fire TV Stick 4K Max - popular streaming device
            "B0B7RXBJ8F"  // Ring Video Doorbell - popular smart home device
        ]
        
        for asin in reliableASINs {
            do {
                print("🎯 Trying reliable demo product ASIN: \(asin)")
                let productDetails = try await getProductDetails(id: "https://www.amazon.com/dp/\(asin)")
                print("✅ Successfully retrieved reliable demo product: \(productDetails.name)")
                return productDetails
            } catch {
                print("⚠️ Demo product ASIN \(asin) failed: \(error)")
                continue
            }
        }
        
        // Fallback to a hardcoded demo product if all ASINs fail
        return ProductItemDTO(
            sourceId: "demo_amazon_echo",
            name: "Amazon Echo Dot (5th Gen)",
            productDescription: "Smart speaker with Alexa - the most compact smart speaker that fits perfectly into small spaces",
            price: 49.99,
            originalPrice: 49.99,
            imageURL: URL(string: "https://m.media-amazon.com/images/I/714Rq4k05UL._AC_SL1000_.jpg"),
            brand: "Amazon",
            source: "axesso_amazon",
            isInStock: true,
            rating: 4.7,
            reviewCount: 234567,
            productUrl: "https://www.amazon.com/dp/B09B8V1LZ3"
        )
    }
    
    // MARK: - Conversion Helpers
    
    private func convertToProductItemDTO(_ searchResult: AxessoAmazonSearchResult) -> ProductItemDTO? {
        guard let asin = searchResult.asin else {
            return nil
        }
        
        // For basic search results from ASIN list, create simplified product
        let productTitle = searchResult.productTitle ?? "Amazon Product \(asin)"
        
        return ProductItemDTO(
            sourceId: asin,
            name: productTitle,
            productDescription: "Amazon product - ASIN: \(asin)",
            price: searchResult.price,
            originalPrice: searchResult.originalPrice,
            currency: searchResult.currency ?? "USD",
            imageURL: URL(string: searchResult.imageUrl ?? ""),
            thumbnailUrl: searchResult.imageUrl,
            brand: searchResult.manufacturer ?? "Amazon",
            source: "axesso_amazon",
            category: searchResult.categoryPath?.joined(separator: " > "),
            isInStock: searchResult.availability != "Out of Stock",
            rating: parseRating(searchResult.productRating),
            reviewCount: searchResult.countReview,
            productUrl: searchResult.productUrl
        )
    }
    
    private func convertProductDetailsToDTO(_ productDetails: AxessoAmazonProductDetails) -> ProductItemDTO? {
        guard let productTitle = productDetails.productTitle,
              let asin = productDetails.asin else {
            return nil
        }
        
        return ProductItemDTO(
            sourceId: asin,
            name: productTitle,
            productDescription: productDetails.productDescription,
            price: productDetails.price ?? 0,
            originalPrice: productDetails.retailPrice,
            currency: "USD",
            imageURL: URL(string: productDetails.imageUrlList?.first ?? ""),
            imageUrls: productDetails.imageUrlList,
            thumbnailUrl: productDetails.imageUrlList?.first,
            brand: productDetails.manufacturer ?? "Unknown",
            source: "Amazon",
            isInStock: productDetails.warehouseAvailability != nil,
            rating: parseRating(productDetails.productRating),
            reviewCount: productDetails.countReview,
            productUrl: productDetails.productUrl
        )
    }
    
    private func parseRating(_ ratingString: String?) -> Double? {
        guard let ratingString = ratingString else { return nil }
        let components = ratingString.components(separatedBy: " ")
        return Double(components.first ?? "")
    }
    
    @MainActor
    private func updateRequestCount() {
        requestCount += 1
        quotaRemaining = max(0, 1000 - requestCount)
    }
}