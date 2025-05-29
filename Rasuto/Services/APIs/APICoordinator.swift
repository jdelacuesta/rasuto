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
    
    // MARK: - Configuration
    private let maxConcurrentRequests = 3
    private let defaultTimeout: TimeInterval = 30
    
    // MARK: - Initialization
    
    init() {
        Task {
            await initializeServices()
            await monitorAPIHealth()
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
        
        // Determine which services to use
        let activeRetailers = retailers.isEmpty ? Array(services.keys) : retailers
        let availableServices = activeRetailers.compactMap { retailer in
            services[retailer].map { (retailer, $0) }
        }
        
        // Check cache first
        let cacheKey = "coordinated_search_\(query)_\(activeRetailers.sorted().joined())"
        if let cachedResult: AggregatedSearchResult = await cache.get(key: cacheKey) {
            return cachedResult
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
        
        // Cache the result
        await cache.set(key: cacheKey, value: aggregatedResult, ttl: 300) // 5 minutes
        
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
        // Initialize all available services
        do {
            let apiConfig = APIConfig()
            
            // Register BestBuy service
            if let bestBuyService = try? await apiConfig.createBestBuyService() {
                await registerService(bestBuyService, for: "bestbuy")
            }
            
            // Register Walmart service
            if let walmartService = try? await apiConfig.createWalmartService() {
                await registerService(walmartService, for: "walmart")
            }
            
            // Register eBay service
            if let ebayService = try? await apiConfig.createEbayService() {
                await registerService(ebayService, for: "ebay")
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
                ProductMatcher.calculateSimilarity(
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