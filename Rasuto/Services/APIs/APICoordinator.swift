//
//  APICoordinator.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Modern API Coordinator

@MainActor
final class APICoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?
    @Published private(set) var apiHealth: [String: APIHealth] = [:]
    
    // MARK: - Private Properties
    private var services: [String: any RetailerAPIService] = [:]
    private let cache = UnifiedCacheManager.shared
    private let rateLimiter = GlobalRateLimiter.shared
    private let circuitBreaker = CircuitBreakerManager.shared
    private let requestDeduplicator = RequestDeduplicator()
    private let performanceMonitor = PerformanceMonitor.shared
    private let quotaProtection = QuotaProtectionManager.shared
    private let persistentCache = PersistentProductCache.shared
    
    // MARK: - Configuration
    private let maxConcurrentRequests = 3
    private let defaultTimeout: TimeInterval = 30
    
    // MARK: - Retailer Categories
    private let serpAPIRetailers = ["google_shopping", "walmart_production", "home_depot", "amazon"]
    private let secondaryRetailers = ["axesso_amazon"]
    
    // Live testing toggle - set to true to bypass quota protection for testing
    public var enableLiveTesting = true // FORCE ENABLED: Always use live API data for real product images
    
    // MARK: - Initialization
    
    init() {
        Task {
            await initializeServices()
            // DISABLED: Health monitoring to preserve SerpAPI quota
            // await monitorAPIHealth()
        }
    }
    
    // MARK: - Service Management
    
    func registerService(_ service: any RetailerAPIService, for retailer: String) async {
        services[retailer] = service
        await updateAPIHealth(for: retailer, status: .unknown)
    }
    
    func getService(for retailer: String) async -> (any RetailerAPIService)? {
        return services[retailer]
    }
    
    // MARK: - Coordinated Search Operations
    
    func search(
        query: String,
        retailers: [String] = [],
        options: SearchOptions = SearchOptions()
    ) async throws -> AggregatedSearchResult {
        
        // QUOTA PROTECTION: Check if we can make API requests (only when live testing is disabled)
        if !enableLiveTesting {
            let canMakeRequest = await quotaProtection.canMakeAPIRequest(service: "search")
            if !canMakeRequest {
                print("🛡️ QUOTA PROTECTION: Search blocked to preserve API quota")
                // Return cached results if available
                let cacheKey = "coordinated_search_\(query)_\(retailers.sorted().joined())"
                if let cachedResult: AggregatedSearchResult = await cache.get(key: cacheKey) {
                    print("📦 Returning cached results for quota protection")
                    return cachedResult
                }
                throw APIError.quotaExceeded
            }
        } else {
            print("🚀 LIVE TESTING: Quota protection bypassed - using live API data for REAL product images")
        }
        
        let searchKey = "search_\(query)_\(retailers.joined(separator: "_"))"
        
        // Check for ongoing request
        if let existingTask = await requestDeduplicator.getOngoingRequest(key: searchKey) {
            return try await existingTask.value
        }
        
        // Start new coordinated search
        let searchTask = Task<AggregatedSearchResult, Error> {
            try await performCoordinatedSearch(query: query, retailers: retailers, options: options)
        }
        
        await requestDeduplicator.addOngoingRequest(key: searchKey, task: searchTask)
        
        do {
            let result = try await searchTask.value
            await requestDeduplicator.removeOngoingRequest(key: searchKey)
            // Record successful API usage - Only count SerpAPI calls
            let serpAPICallCount = result.retailerResults.keys.filter { serpAPIRetailers.contains($0) }.count
            if serpAPICallCount > 0 {
                await quotaProtection.recordAPIRequest()
                print("📊 Quota: Recorded \(serpAPICallCount) SerpAPI calls out of \(result.retailerResults.count) total API calls")
            }
            return result
        } catch {
            await requestDeduplicator.removeOngoingRequest(key: searchKey)
            throw error
        }
    }
    
    private func performCoordinatedSearch(
        query: String,
        retailers: [String],
        options: SearchOptions
    ) async throws -> AggregatedSearchResult {
        
        isLoading = true
        defer { isLoading = false }
        
        // Determine which services to use - SerpAPI core + secondary layer
        let allRetailers = serpAPIRetailers + secondaryRetailers
        let activeRetailers = retailers.isEmpty ? allRetailers : retailers
        let availableServices = activeRetailers.compactMap { retailer in
            services[retailer].map { (retailer, $0) }
        }
        
        // Check cache first - but skip for trending queries to ensure fresh data
        let cacheKey = "coordinated_search_\(query)_\(activeRetailers.sorted().joined())"
        let forceFreshQueries = ["headphones", "coffee maker", "wireless mouse", "bluetooth speaker", "backpack", "watch", "tablet", "camera"]
        
        if !forceFreshQueries.contains(query.lowercased()) {
            if let cachedResult: AggregatedSearchResult = await cache.get(key: cacheKey) {
                print("📦 Using cached results for query: \(query)")
                return cachedResult
            }
        } else {
            print("🔥 Skipping cache for trending query: \(query) - forcing fresh API call")
        }
        
        // Perform parallel searches with error handling
        let results = await withTaskGroup(of: (String, Result<[ProductItemDTO], Error>).self) { group in
            var results: [(String, Result<[ProductItemDTO], Error>)] = []
            
            for (retailer, service) in availableServices {
                group.addTask {
                    do {
                        // Check circuit breaker
                        guard await self.circuitBreaker.canExecute(service: retailer) else {
                            throw APIError.serviceUnavailable(retailer)
                        }
                        
                        // Check rate limits
                        try await self.rateLimiter.checkAndConsume(service: retailer)
                        
                        // Perform search
                        let products = try await service.searchProducts(query: query)
                        await self.circuitBreaker.recordSuccess(service: retailer)
                        return (retailer, .success(products))
                        
                    } catch {
                        await self.circuitBreaker.recordFailure(service: retailer)
                        return (retailer, .failure(error))
                    }
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
        
        // Process and aggregate results
        let aggregatedResult = await processSearchResults(results, query: query, options: options)
        
        // Smart caching - longer cache for trending queries to save quota
        let trendsService = GoogleTrendsService.shared
        let trendingQueries = trendsService.getTrendingProducts().map { $0.lowercased() }
        let isTrendingQuery = trendingQueries.contains(query.lowercased())
        let cacheTTL: TimeInterval = isTrendingQuery ? 3600 : 300 // 1 hour for trending, 5 min for regular
        
        await cache.set(key: cacheKey, value: aggregatedResult, ttl: cacheTTL)
        print("📦 Cached results for '\(query)' with TTL: \(cacheTTL/60) minutes")
        
        return aggregatedResult
    }
    
    // MARK: - Product Details Coordination
    
    func getProductDetails(
        id: String,
        retailer: String,
        options: DetailOptions = DetailOptions()
    ) async throws -> EnrichedProductDetails {
        
        let cacheKey = "product_details_\(retailer)_\(id)"
        
        // Check cache first
        if let cachedDetails: EnrichedProductDetails = await cache.get(key: cacheKey) {
            return cachedDetails
        }
        
        guard let service = services[retailer] else {
            throw APIError.serviceNotFound(retailer)
        }
        
        // Get base product details
        let baseProduct = try await service.getProductDetails(id: id)
        
        // Enrich with cross-retailer data if requested
        var enrichedDetails = EnrichedProductDetails(
            baseProduct: baseProduct,
            crossRetailerPrices: [],
            relatedProducts: [],
            priceHistory: [],
            availability: [:]
        )
        
        if options.includeCrossRetailerComparison {
            enrichedDetails = await enrichWithCrossRetailerData(enrichedDetails, options: options)
        }
        
        // Cache the enriched result
        await cache.set(key: cacheKey, value: enrichedDetails, ttl: 600) // 10 minutes
        
        return enrichedDetails
    }
    
    // MARK: - Health Monitoring
    
    private func monitorAPIHealth() async {
        while true {
            for (retailer, service) in services {
                let health = await checkServiceHealth(service: service, retailer: retailer)
                await updateAPIHealth(for: retailer, status: health)
            }
            
            // Check every 5 minutes
            try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
        }
    }
    
    private func checkServiceHealth(service: any RetailerAPIService, retailer: String) async -> APIHealth {
        do {
            // Simple health check - try a minimal API call
            _ = try await service.searchProducts(query: "test")
            return .healthy
        } catch {
            return .unhealthy(error)
        }
    }
    
    private func updateAPIHealth(for retailer: String, status: APIHealth) {
        apiHealth[retailer] = status
    }
    
    // MARK: - Private Helper Methods
    
    private func initializeServices() async {
        // Initialize all available services with new layered architecture
        do {
            let apiConfig = APIConfig()
            
            // LAYER 1: SerpAPI (Primary Layer) - Developer Plan 100k searches/month
            // Provides comprehensive retailer coverage with structured data
            if let serpAPIGoogleService = try? apiConfig.createSerpAPIGoogleShoppingService() {
                await registerService(serpAPIGoogleService, for: "google_shopping")
            }
            
            if let serpAPIEbayService = try? apiConfig.createSerpAPIEbayService() {
                await registerService(serpAPIEbayService, for: "ebay_production")
            }
            
            if let serpAPIWalmartService = try? apiConfig.createSerpAPIWalmartService() {
                await registerService(serpAPIWalmartService, for: "walmart_production")
            }
            
            if let serpAPIHomeDepotService = try? apiConfig.createSerpAPIHomeDepotService() {
                await registerService(serpAPIHomeDepotService, for: "home_depot")
            }
            
            if let serpAPIAmazonService = try? apiConfig.createSerpAPIAmazonService() {
                await registerService(serpAPIAmazonService, for: "amazon")
            }
            
            
            // LAYER 2: Amazon Layer - Axesso for direct Amazon access
            // Enhanced Amazon data with price history capabilities
            let axessoService = AxessoAmazonAPIService(apiKey: DefaultKeys.axessoApiKeyPrimary)
            await registerService(axessoService, for: "axesso_amazon")
            
            // LAYER 3: Enhanced Amazon API - Axesso for detailed Amazon data
            // Provides enhanced Amazon product data and pricing
            if let axessoService = try? apiConfig.createAxessoAmazonService() {
                await registerService(axessoService, for: "axesso_amazon")
            }
            
            // LAYER 4: Fallback Scraper - Oxylabs for when APIs fail or lack data
            // 7-day trial with 5K requests for comprehensive fallback coverage
            let oxylabsService = OxylabsScraperService.shared
            await registerService(oxylabsService, for: "oxylabs_fallback")
            
            // LAYER 5: Additional SerpAPI eBay service for enhanced coverage
            // Provides auction and Buy It Now product data via SerpAPI
            if let serpEbayService = try? apiConfig.createSerpAPIEbayService() {
                await registerService(serpEbayService, for: "serpapi_ebay_fallback")
            }
            
        } catch {
            lastError = error
        }
    }
    
    private func processSearchResults(
        _ results: [(String, Result<[ProductItemDTO], Error>)],
        query: String,
        options: SearchOptions
    ) async -> AggregatedSearchResult {
        
        var allProducts: [ProductItemDTO] = []
        var errors: [String: Error] = [:]
        var retailerResults: [String: [ProductItemDTO]] = [:]
        
        // Process each retailer's results
        for (retailer, result) in results {
            switch result {
            case .success(let products):
                allProducts.append(contentsOf: products)
                retailerResults[retailer] = products
            case .failure(let error):
                errors[retailer] = error
            }
        }
        
        // Apply deduplication and merging
        let deduplicatedProducts = ProductAggregator.deduplicateAndMerge(allProducts)
        
        // Apply sorting and filtering
        let sortedProducts = ProductAggregator.sort(
            deduplicatedProducts,
            by: options.sortOrder,
            filters: options.filters
        )
        
        // Apply pagination
        let paginatedProducts = Array(sortedProducts.prefix(options.maxResults))
        
        // Add all search results to persistent cache (before pagination)
        if !deduplicatedProducts.isEmpty {
            Task {
                await persistentCache.addProducts(deduplicatedProducts)
                print("📱 APICoordinator: Added \(deduplicatedProducts.count) products to persistent cache")
            }
        }
        
        return AggregatedSearchResult(
            query: query,
            products: paginatedProducts,
            retailerResults: retailerResults,
            errors: errors,
            totalResults: sortedProducts.count,
            processingTime: Date().timeIntervalSinceReferenceDate
        )
    }
    
    private func enrichWithCrossRetailerData(
        _ details: EnrichedProductDetails,
        options: DetailOptions
    ) async -> EnrichedProductDetails {
        
        var enriched = details
        
        // Search for similar products across retailers
        let searchQuery = details.baseProduct.name
        
        do {
            let crossRetailerSearch = try await search(query: searchQuery)
            
            // Find matching products (by name similarity)
            let similarProducts = crossRetailerSearch.products.filter { product in
                calculateNameSimilarity(
                    details.baseProduct.name,
                    product.name
                ) > 0.8
            }
            
            enriched.crossRetailerPrices = similarProducts.compactMap { product in
                CrossRetailerPrice(
                    retailer: product.source,
                    price: product.price ?? 0,
                    url: product.productUrl,
                    availability: product.isInStock
                )
            }
            
        } catch {
            // Cross-retailer enrichment failed, but we still have base data
        }
        
        return enriched
    }
    
    // MARK: - Helper Methods
    
    private func calculateNameSimilarity(_ name1: String, _ name2: String) -> Double {
        let words1 = Set(name1.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let words2 = Set(name2.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }
}

// MARK: - Supporting Types

struct SearchOptions {
    let maxResults: Int
    let sortOrder: ProductSortOrder
    let filters: [ProductFilter]
    let includeCrossRetailerComparison: Bool
    
    init(
        maxResults: Int = 50,
        sortOrder: ProductSortOrder = .relevance,
        filters: [ProductFilter] = [],
        includeCrossRetailerComparison: Bool = false
    ) {
        self.maxResults = maxResults
        self.sortOrder = sortOrder
        self.filters = filters
        self.includeCrossRetailerComparison = includeCrossRetailerComparison
    }
}

struct DetailOptions {
    let includeCrossRetailerComparison: Bool
    let includeRelatedProducts: Bool
    let includePriceHistory: Bool
    
    init(
        includeCrossRetailerComparison: Bool = true,
        includeRelatedProducts: Bool = true,
        includePriceHistory: Bool = false
    ) {
        self.includeCrossRetailerComparison = includeCrossRetailerComparison
        self.includeRelatedProducts = includeRelatedProducts
        self.includePriceHistory = includePriceHistory
    }
}

enum APIHealth {
    case healthy
    case degraded(String)
    case unhealthy(Error)
    case unknown
}

enum ProductSortOrder {
    case relevance
    case priceLowToHigh
    case priceHighToLow
    case rating
    case newest
}

struct ProductFilter {
    let type: FilterType
    let value: String
    
    enum FilterType {
        case brand
        case category
        case priceRange
        case inStockOnly
    }
}

extension APIError {
    static func serviceUnavailable(_ service: String) -> APIError {
        return .custom("Service \(service) is currently unavailable")
    }
    
    static func serviceNotFound(_ service: String) -> APIError {
        return .custom("Service \(service) not found")
    }
}