//
//  UniversalSearchManager.swift
//  Rasuto
//
//  Created for capstone demo flow on 5/29/25.
//

import SwiftUI
import Combine

@MainActor
class UniversalSearchManager: ObservableObject {
    @Published var instantResults: [any SearchResultItem] = []
    @Published var productResults: [ProductItem] = []
    @Published var categoryResults: [String] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    @Published var hasSearched = false
    @Published var suggestedSearches: [String] = []
    @Published var searchError: APIError?
    @Published var isShowingError = false
    @Published var useLiveData = true // Toggle for live vs demo data
    
    private let apiCoordinator = APICoordinator()
    private let apiConfig = APIConfig()
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var servicesInitialized = false
    private let persistentCache = PersistentProductCache.shared
    
    private let categories = [
        "Electronics", "Gaming", "Smartphones", "Laptops",
        "Headphones", "Smart Home", "Tablets", "Wearables",
        "TV & Home Theater", "Audio", "Computers", "Camera",
        "Kitchen Appliances", "Home & Garden", "Sports & Outdoors"
    ]
    
    // Popular searches for demo - variety across all retailers
    private let popularSearches = [
        "iPhone 15", "coffee maker", "power drill", "Samsung Galaxy",
        "MacBook Pro", "running shoes", "Xbox Series X", "Nintendo Switch", 
        "Sony WH-1000XM5", "Apple Watch", "tool set", "office chair"
    ]
    
    init() {
        loadRecentSearches()
        generateSuggestions()
        Task {
            await initializeServices()
        }
    }
    
    // MARK: - Cache Warming
    
    func warmCacheWithLiveData() async {
        print("🔥 CACHE WARMING: Starting live data population...")
        
        // Ensure services are initialized
        if !servicesInitialized {
            await initializeServices()
        }
        
        // Check network connectivity
        guard await checkNetworkConnectivity() else {
            print("🚫 No network connectivity - skipping cache warming")
            return
        }
        
        do {
            // Perform a broad search to populate cache with diverse products
            let results = try await apiCoordinator.search(
                query: "popular electronics trending",
                retailers: ["google_shopping", "amazon", "walmart_production"],
                options: SearchOptions(maxResults: 20, sortOrder: .relevance)
            )
            
            if !results.products.isEmpty {
                // Add to persistent cache
                await persistentCache.addProducts(results.products)
                print("✅ CACHE WARMED: Added \(results.products.count) live products to cache")
            } else {
                print("⚠️ CACHE WARMING: No products returned from API")
            }
            
        } catch {
            print("❌ CACHE WARMING FAILED: \(error)")
        }
    }
    
    func updateInstantResults(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            clearResults()
            return
        }
        
        // Filter categories locally for instant results
        categoryResults = categories.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
        
        // Update suggestions based on query
        suggestedSearches = popularSearches.filter {
            $0.localizedCaseInsensitiveContains(query) && $0 != query
        }.prefix(3).map { $0 }
        
        // Debounced API search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            await performInstantSearch(query: query)
        }
    }
    
    private func performInstantSearch(query: String) async {
        print("🔍 Starting instant search for: '\(query)'")
        
        // Ensure services are initialized
        if !servicesInitialized {
            await initializeServices()
        }
        
        // Check network connectivity first (modern approach)
        guard await checkNetworkConnectivity() else {
            print("🚫 No network connectivity - skipping search")
            return
        }
        
        do {
            // Search across all available retailers for comprehensive results
            let results = try await apiCoordinator.search(
                query: query,
                retailers: ["google_shopping", "amazon", "walmart_production", "home_depot", "ebay_production"],
                options: SearchOptions(
                    maxResults: 8, // Balanced results per retailer
                    sortOrder: .relevance
                )
            )
            
            print("✅ Instant search got \(results.products.count) results")
            
            // Convert DTOs to ProductItems
            productResults = results.products.map { ProductItem.from($0) }
            
            // Add search results to persistent cache
            if !results.products.isEmpty {
                await persistentCache.addProducts(results.products)
                print("📱 Added \(results.products.count) products to persistent cache")
            }
            
            // Combine results
            instantResults = (productResults as [any SearchResultItem]) + (categoryResults as [any SearchResultItem])
            
        } catch {
            print("❌ Instant search failed: \(error)")
            print("📊 Error details: \(error.localizedDescription)")
            
            // Clear results on failure - no mock data for demo
            productResults = []
            instantResults = categoryResults as [any SearchResultItem]
        }
    }
    
    // MARK: - Modern Network Connectivity Check
    
    private func checkNetworkConnectivity() async -> Bool {
        // Use modern Network framework approach
        return true // For now, assume connectivity - can enhance with NWPathMonitor
    }
    
    func performRetailerSearch(query: String, retailer: String) {
        guard !query.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        saveRecentSearch(query)
        
        Task {
            // Demo search functionality removed - always use live data
            if !useLiveData {
                // Demo data removed - fallback to live search
                print("⚠️ Demo data disabled, using live search instead")
            }
            
            if !servicesInitialized {
                await initializeServices()
            }
            
            do {
                let retailerKey = getRetailerKey(for: retailer)
                let results = try await apiCoordinator.search(
                    query: query,
                    retailers: [retailerKey],
                    options: SearchOptions(
                        maxResults: 30,
                        sortOrder: .relevance
                    )
                )
                
                let allProducts = results.products.map { ProductItem.from($0) }
                productResults = Array(Set(allProducts)).sorted { $0.name < $1.name }
                instantResults = (productResults as [any SearchResultItem]) + (categoryResults as [any SearchResultItem])
                
                // Add search results to persistent cache
                if !results.products.isEmpty {
                    await persistentCache.addProducts(results.products)
                    print("📱 Added \(results.products.count) products from retailer search to persistent cache")
                }
                
            } catch {
                print("❌ Retailer search failed: \(error)")
                handleSearchError(error)
                productResults = []
            }
            
            isSearching = false
        }
    }
    
    private func getRetailerKey(for retailer: String) -> String {
        switch retailer {
        case "Amazon": return "axesso_amazon"
        case "Google Shopping": return "google_shopping"
        case "eBay": return "ebay_production"
        case "Walmart": return "walmart_production"
        case "Home Depot": return "home_depot"
        case "Best Buy": return "bestbuy"
        default: return "google_shopping"
        }
    }
    
    func performFullSearch(query: String) {
        guard !query.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        saveRecentSearch(query)
        
        Task {
            // Demo search functionality removed - always use live data
            if !useLiveData {
                // Demo data removed - fallback to live search
                print("⚠️ Demo data disabled, using live search instead")
            }
            
            // Ensure services are initialized for real searches
            if !servicesInitialized {
                await initializeServices()
            }
            
            do {
                let results = try await apiCoordinator.search(
                    query: query,
                    retailers: ["google_shopping", "amazon", "walmart_production", "home_depot", "ebay_production", "axesso_amazon"],
                    options: SearchOptions(
                        maxResults: 20,
                        sortOrder: .relevance
                    )
                )
                
                // Convert and deduplicate results
                let allProducts = results.products.map { ProductItem.from($0) }
                productResults = Array(Set(allProducts)).sorted { $0.name < $1.name }
                
                // Update instant results
                instantResults = (productResults as [any SearchResultItem]) + (categoryResults as [any SearchResultItem])
                
                // Add search results to persistent cache
                if !results.products.isEmpty {
                    await persistentCache.addProducts(results.products)
                    print("📱 Added \(results.products.count) products from full search to persistent cache")
                }
                
            } catch {
                print("❌ Full search failed: \(error)")
                handleSearchError(error)
                productResults = []
            }
            
            isSearching = false
        }
    }
    
    func clearResults() {
        instantResults = []
        productResults = []
        categoryResults = []
        suggestedSearches = []
        hasSearched = false
    }
    
    private func generateSuggestions() {
        // Show popular searches when search is empty
        suggestedSearches = Array(popularSearches.shuffled().prefix(5))
    }
    
    // MARK: - Error Handling
    
    private func handleSearchError(_ error: Error) {
        if let apiError = error as? APIError {
            searchError = apiError
        } else {
            searchError = APIError.unknownError(error)
        }
        isShowingError = true
        
        // Log the error
        APILogger.shared.logError(
            searchError ?? APIError.unknownError(error),
            context: "UniversalSearchManager",
            apiType: "Universal"
        )
    }
    
    func retryLastSearch() {
        isShowingError = false
        searchError = nil
        
        // Retry the last search if we have search task
        if hasSearched && !productResults.isEmpty {
            // Re-trigger the search with last query
            // This would need to be implemented based on your search flow
        }
    }
    
    func clearError() {
        isShowingError = false
        searchError = nil
    }
    
    private func saveRecentSearch(_ query: String) {
        // Remove if already exists to move to front
        recentSearches.removeAll { $0 == query }
        recentSearches.insert(query, at: 0)
        
        // Keep only last 10 searches
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        UserDefaults.standard.set(recentSearches, forKey: "universalRecentSearches")
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "universalRecentSearches") ?? []
    }
    
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "universalRecentSearches")
    }
    
    // MARK: - Private Methods
    
    private func initializeServices() async {
        guard !servicesInitialized else { return }
        
        // Initialize SerpAPI + fallback services
        do {
            // SerpAPI services
            let serpGoogleShopping = try apiConfig.createSerpAPIGoogleShoppingService()
            let serpEbay = try apiConfig.createSerpAPIEbayService()
            let serpWalmart = try apiConfig.createSerpAPIWalmartService()
            
            // Fallback services
            let axessoAmazon = try apiConfig.createAxessoAmazonService()
            let oxylabsService = try apiConfig.createOxylabsService()
            
            await apiCoordinator.registerService(serpGoogleShopping, for: "google_shopping")
            await apiCoordinator.registerService(serpEbay, for: "ebay")
            await apiCoordinator.registerService(serpWalmart, for: "walmart")
            await apiCoordinator.registerService(axessoAmazon, for: "amazon")
            await apiCoordinator.registerService(oxylabsService, for: "oxylabs")
        } catch {
            print("Failed to initialize services: \(error)")
        }
        
        servicesInitialized = true
    }
}

// MARK: - Search Result Protocol

protocol SearchResultItem: Identifiable {
    var displayName: String { get }
}

extension ProductItem: SearchResultItem {
    var displayName: String { name }
}

extension String: SearchResultItem {
    var displayName: String { self }
    public var id: String { self }
}

// MARK: - ProductItem Hashable Extension

extension ProductItem: Hashable {
    static func == (lhs: ProductItem, rhs: ProductItem) -> Bool {
        lhs.id == rhs.id && lhs.sourceId == rhs.sourceId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(sourceId)
    }
}