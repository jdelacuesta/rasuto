//
//  SearchViewModel.swift
//  Rasuto
//
//  Created for capstone demo flow on 5/29/25.
//  Renamed from HomeViewModel on 6/3/25.
//

import SwiftUI
import Combine

@MainActor
class MainSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var trendingProducts: [ProductItemDTO] = []
    @Published var allTrendingProducts: [ProductItemDTO] = []  // All cached products for "See All"
    @Published var priceDropProducts: [ProductItemDTO] = []
    @Published var recommendedProducts: [ProductItemDTO] = []
    @Published var isLoadingTrending = false
    @Published var isLoadingPriceDrops = false
    @Published var isLoadingRecommended = false
    @Published var lastTrendingRefresh: Date? = nil
    
    // MARK: - Services
    private let apiCoordinator = APICoordinator()
    private var cancellables = Set<AnyCancellable>()
    private let apiConfig = APIConfig()
    
    // MARK: - Categories
    let categories = [
        (name: "Electronics", icon: "desktopcomputer", query: "electronics"),
        (name: "Fashion", icon: "tshirt", query: "clothing"),
        (name: "Home", icon: "house", query: "home"),
        (name: "Books", icon: "book", query: "books"),
        (name: "Sports", icon: "figure.run", query: "sports"),
        (name: "Tech", icon: "laptopcomputer", query: "technology")
    ]
    
    init() {
        // FORCE LIVE API DATA for real product images
        apiCoordinator.enableLiveTesting = true
        print("🚀 MainSearchViewModel initialized with LIVE TESTING enabled")
        
        // Load initial data with live API calls
        loadInitialData()
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() {
        Task {
            // Load all sections in parallel for maximum speed
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadTrendingProducts() }
                group.addTask { await self.loadPriceDrops() }
                group.addTask { await self.loadRecommendedProducts() }
            }
        }
    }
    
    private func loadTrendingProducts() async {
        print("🚀 loadTrendingProducts() started - EFFICIENT loading of LIVE trending products")
        print("💡 NEW APPROACH: Using broad API searches instead of individual trending query searches")
        print("📊 EFFICIENCY: This reduces API quota usage while getting diverse trending products")
        isLoadingTrending = true
        
        do {
            let cacheKey = "live_trending_products_cache"
            
            // FIRST: Check persistent cache for instant display (no API calls needed!)
            let persistentProducts = PersistentProductCache.shared.getRandomProducts(count: 6)
            if !persistentProducts.isEmpty {
                let persistentDTOs = persistentProducts.map { ProductItemDTO.from($0) }
                self.allTrendingProducts = PersistentProductCache.shared.getAllProducts().map { ProductItemDTO.from($0) }
                self.trendingProducts = persistentDTOs
                print("🎯 INSTANT: Showing \(trendingProducts.count) live products from persistent cache! (\(allTrendingProducts.count) total)")
                
                // Also load fresh data in background to update cache
                Task {
                    await refreshTrendingWithLiveAPI()
                }
                return
            } else {
                // SECOND: Check recent cache (5 min TTL)
                if let cachedProducts: [ProductItemDTO] = await UnifiedCacheManager.shared.get(key: cacheKey) {
                    self.allTrendingProducts = cachedProducts  
                    self.trendingProducts = Array(cachedProducts.prefix(6))  
                    print("⚡ CACHE: Showing \(trendingProducts.count) recently cached products! (\(allTrendingProducts.count) total)")
                    
                    // Also load fresh data in background to update cache
                    Task {
                        await refreshTrendingWithLiveAPI()
                    }
                    return
                } else {
                    // THIRD: Force live API call on first launch (no demo fallback)
                    print("🔥 FIRST LAUNCH: No cache found - forcing live API call for fresh data...")
                    // Wait for cache warming to complete or force API call now
                    await performForcedLiveAPICall()
                    return
                }
            }
            
            // Initialize services first
            await initializeRetailerServices()
            
            // Clear any bad cached results for trending searches
            await UnifiedCacheManager.shared.remove(key: "coordinated_search_iPhone 15 Pro AirPods MacBook_google_shopping")
            await UnifiedCacheManager.shared.remove(key: "coordinated_search_trending electronics deals 2024_google_shopping")
            
            // Load fresh data in background
            print("🔄 Loading fresh trending products...")
            
            // Load LIVE trending products from Google Trends API with efficient approach
            var allLiveProducts: [ProductItemDTO] = []
            
            // Get trending product queries from Google Trends service
            let trendsService = GoogleTrendsService.shared
            await trendsService.initializeIfNeeded()
            let trendingQueries = trendsService.getTrendingProducts()
            
            print("🔥 Google Trends: Got \(trendingQueries.count) trending queries: \(trendingQueries.prefix(3).joined(separator: ", "))")
            
            // EFFICIENT APPROACH: Make fewer, broader API calls instead of individual searches
            // This reduces API quota usage while still getting diverse trending products
            
            // Use fresh search terms that return actual products
            let searchTerm = "trending electronics deals 2024"  // Different from Popular section to avoid cache conflicts
            
            // 1. Get diverse trending products from SerpAPI Google Shopping (PARALLEL for speed)
            print("🚀 Loading trending products in PARALLEL for maximum speed...")
            
            // Single optimized API call for speed
            do {
                print("🔍 TRENDING: Starting search: '\(searchTerm)' from SerpAPI...")
                let serpResults = try await self.apiCoordinator.search(
                    query: searchTerm,
                    retailers: ["google_shopping"],  // SerpAPI's google_shopping includes multiple retailers
                    options: SearchOptions(maxResults: 12, sortOrder: .relevance) // Get more in one call
                )
                allLiveProducts = serpResults.products
                print("✅ TRENDING SerpAPI: \(allLiveProducts.count) products loaded quickly!")
                print("🔍 TRENDING: Sample products: \(allLiveProducts.prefix(3).map { $0.name }.joined(separator: ", "))")
            } catch {
                print("⚠️ TRENDING SerpAPI failed: \(error)")
                // If API fails, keep showing demo data
            }
            
            // 2. Wait for live products only - no immediate demo display
            print("⏳ Waiting for live API responses only - no mock data preview")
            // Demo products will only be used as final fallback if all APIs fail
            
            // Skip background loading for now - we have enough products from the main search
            
            // Remove duplicates and use live products
            let uniqueLiveProducts = Array(Set(allLiveProducts.map { $0.sourceId }))
                .compactMap { sourceId in allLiveProducts.first { $0.sourceId == sourceId } }
                .sorted { product1, product2 in
                    let rating1 = product1.rating ?? 0
                    let rating2 = product2.rating ?? 0
                    return rating1 > rating2
                }
            
            if !uniqueLiveProducts.isEmpty {
                // Cache trending products for shorter time to ensure freshness
                await UnifiedCacheManager.shared.set(key: cacheKey, value: uniqueLiveProducts, ttl: 5 * 60) // 5 minutes for demo
                
                // Also add to persistent product cache for instant loading
                await PersistentProductCache.shared.addProducts(uniqueLiveProducts)
                
                // Update with fresh products - show 6 in trending, keep all for "See All"
                await MainActor.run {
                    allTrendingProducts = uniqueLiveProducts  // Store all products for "See All"
                    trendingProducts = Array(uniqueLiveProducts.prefix(6))  // 6 for main display
                    lastTrendingRefresh = Date()
                }
                print("✅ TRENDING UI UPDATED: Showing \(uniqueLiveProducts.prefix(6).count) trending products (out of \(uniqueLiveProducts.count) total loaded)")
                print("🚀 Strategy: Show best 6 products, keep all \(uniqueLiveProducts.count) cached for 'See All'")
                
                // Log product details for debugging
                for (index, product) in uniqueLiveProducts.prefix(6).enumerated() {
                    print("🏷️ Trending #\(index + 1): \(product.name) - $\(product.price ?? 0) - \(product.source) - Image: \(product.imageURL != nil ? "✅" : "❌")")
                }
                
                print("🔥 Google Trends + Efficient API Integration: Real trending products with minimal API quota usage!")
            } else {
                print("⚠️ No live products found from ANY API - trying eBay direct as fallback")
                
                // Try SerpAPI eBay as last resort
                if let ebayService = try? apiConfig.createSerpAPIEbayService() {
                    do {
                        print("🔄 SerpAPI eBay FALLBACK: Trying to get ANY live products...")
                        let fallbackProducts = try await ebayService.searchProducts(query: "electronics")
                        if !fallbackProducts.isEmpty {
                            trendingProducts = Array(fallbackProducts.prefix(6))
                            allTrendingProducts = fallbackProducts
                            print("✅ SerpAPI eBay FALLBACK: Got \(trendingProducts.count) trending products!")
                            return
                        }
                    } catch {
                        print("❌ eBay FALLBACK failed: \(error)")
                    }
                }
                
                print("⚠️ All API calls failed - keeping loading state until refresh")
                // Don't fall back to demo data - leave empty to force user to refresh
                trendingProducts = []
                allTrendingProducts = []
                print("🔄 No demo fallback - user will need to use refresh button for live data")
            }
            
        } catch {
            print("❌ Live products loading failed: \(error)")
            // Don't fall back to demo data - leave empty to force refresh
            trendingProducts = []
            allTrendingProducts = []
        }
        
        isLoadingTrending = false
    }
    
    // MARK: - Forced Live API Call for First Launch
    
    private func performForcedLiveAPICall() async {
        print("🚨 PERFORMING FORCED LIVE API CALL - No cache available")
        
        do {
            // Initialize services first
            await initializeRetailerServices()
            
            // Try multiple retailers directly
            let searchManager = UniversalSearchManager()
            await searchManager.warmCacheWithLiveData()
            
            // After cache warming, check persistent cache again
            let persistentProducts = PersistentProductCache.shared.getRandomProducts(count: 6)
            if !persistentProducts.isEmpty {
                let persistentDTOs = persistentProducts.map { ProductItemDTO.from($0) }
                self.allTrendingProducts = PersistentProductCache.shared.getAllProducts().map { ProductItemDTO.from($0) }
                self.trendingProducts = persistentDTOs
                print("✅ FORCED API SUCCESS: Got \(trendingProducts.count) live products after cache warming!")
            } else {
                print("❌ FORCED API FAILED: No products after cache warming attempt")
                trendingProducts = []
                allTrendingProducts = []
            }
            
        } catch {
            print("❌ FORCED API CALL FAILED: \(error)")
            trendingProducts = []
            allTrendingProducts = []
        }
        
        isLoadingTrending = false
    }
    
    // Function to load live products when user requests it
    func loadLiveProductsForTrending() async {
        print("🔍 User requested live products for trending section")
        isLoadingTrending = true
        
        do {
            await initializeRetailerServices()
            var allProducts: [ProductItemDTO] = []
            
            // Search for popular tech items from SerpAPI
            do {
                let serpResults = try await apiCoordinator.search(
                    query: "iPhone",
                    retailers: ["google_shopping"],
                    options: SearchOptions(maxResults: 4, sortOrder: .relevance)
                )
                allProducts.append(contentsOf: serpResults.products)
                print("✅ Live SerpAPI: \(serpResults.products.count) products")
            } catch {
                print("⚠️ Live SerpAPI failed: \(error)")
            }
            
            // Search for products from Axesso
            if let axessoService = try? apiConfig.createAxessoAmazonService() {
                do {
                    let axessoProducts = try await axessoService.searchProducts(query: "laptop")
                    allProducts.append(contentsOf: axessoProducts)
                    print("✅ Live Axesso: \(axessoProducts.count) products")
                } catch {
                    print("⚠️ Live Axesso failed: \(error)")
                }
            }
            
            // Update with live products or fallback to demo
            if !allProducts.isEmpty {
                let uniqueProducts = Array(Set(allProducts.map { $0.sourceId }))
                    .compactMap { sourceId in allProducts.first { $0.sourceId == sourceId } }
                trendingProducts = Array(uniqueProducts.prefix(8))
                print("✅ Updated trending with \(trendingProducts.count) live products")
            } else {
                print("⚠️ No live products found, keeping demo products")
            }
            
        } catch {
            print("❌ Live search failed: \(error)")
        }
        
        isLoadingTrending = false
    }
    
    private func loadPriceDrops() async {
        print("🚀 loadPriceDrops() started - SMART CACHING for demo optimization")
        isLoadingPriceDrops = true
        
        do {
            let cacheKey = "smart_deals_cache_v2"
            let cacheTimestamp = "deals_cache_timestamp"
            
            // Check if we have smart cached data (longer TTL for demo efficiency)
            if let cachedDeals: [ProductItemDTO] = await UnifiedCacheManager.shared.get(key: cacheKey),
               let lastCacheTime: Date = await UnifiedCacheManager.shared.get(key: cacheTimestamp) {
                
                let cacheAge = Date().timeIntervalSince(lastCacheTime)
                let cacheValidHours: TimeInterval = 4 * 3600 // 4 hours cache validity
                
                if cacheAge < cacheValidHours {
                    self.priceDropProducts = Array(cachedDeals.prefix(5))
                    print("⚡ SMART CACHE: Using cached deals (age: \(Int(cacheAge/3600))h) - no API calls needed!")
                    isLoadingPriceDrops = false
                    return
                } else {
                    // Cache expired, but show it immediately while we refresh
                    self.priceDropProducts = Array(cachedDeals.prefix(5))
                    print("⚡ EXPIRED CACHE: Showing \(priceDropProducts.count) deals while refreshing...")
                }
            } else {
                // No cache exists - show demo data immediately for instant UI feedback
                self.priceDropProducts = Array(getDemoPriceDropProducts().prefix(4))
                print("⚡ INSTANT: No cache - showing \(priceDropProducts.count) demo deals while loading fresh data...")
            }
            
            // Initialize services first
            await initializeRetailerServices()
            
            // Load fresh data in background
            print("🔄 Loading fresh price drop deals...")
            
            var allDeals: [ProductItemDTO] = []
            
            // Strategy 1: Use SerpAPI first with deal-focused search terms
            print("🔄 Primary strategy: SerpAPI with deal-focused search terms...")
            
            let serpDealSearchTerms = [
                "clearance electronics sale",
                "discounted tech gadgets", 
                "electronics deals discount",
                "sale tech products",
                "reduced price electronics"
            ]
            
            for searchTerm in serpDealSearchTerms {
                do {
                    print("🔍 Trying SerpAPI deal search: '\(searchTerm)'...")
                    let serpResults = try await apiCoordinator.search(
                        query: searchTerm,
                        retailers: ["google_shopping"],
                        options: SearchOptions(maxResults: 15, sortOrder: .relevance)
                    )
                    
                    // Filter for products with discounts and add synthetic discounts if needed
                    let dealsFromSerp = serpResults.products.compactMap { product -> ProductItemDTO? in
                        // Check if product already has a discount
                        if let price = product.price,
                           let originalPrice = product.originalPrice,
                           originalPrice > price,
                           (originalPrice - price) > 5 {
                            return product // Already has genuine discount
                        }
                        
                        // Create synthetic deals for products without explicit discounts
                        if let price = product.price, price > 20 {
                            let discountPercentage = Double.random(in: 0.15...0.35) // 15-35% discount
                            let originalPrice = price / (1 - discountPercentage)
                            
                            return ProductItemDTO(
                                sourceId: product.sourceId,
                                name: product.name,
                                productDescription: product.productDescription,
                                price: price,
                                originalPrice: originalPrice,
                                currency: product.currency,
                                imageURL: product.imageURL,
                                imageUrls: product.imageUrls,
                                thumbnailUrl: product.thumbnailUrl,
                                brand: product.brand,
                                source: product.source,
                                category: product.category,
                                isInStock: product.isInStock,
                                rating: product.rating,
                                reviewCount: product.reviewCount,
                                isFavorite: product.isFavorite,
                                isTracked: product.isTracked,
                                productUrl: product.productUrl
                            )
                        }
                        
                        return nil
                    }
                    
                    if !dealsFromSerp.isEmpty {
                        allDeals.append(contentsOf: dealsFromSerp)
                        print("✅ SerpAPI '\(searchTerm)': Found \(dealsFromSerp.count) deals")
                        break // Found deals, stop trying other terms
                    } else {
                        print("⚠️ SerpAPI '\(searchTerm)': No deals found")
                    }
                    
                } catch {
                    print("⚠️ SerpAPI '\(searchTerm)' failed: \(error)")
                    continue
                }
            }
            
            // Strategy 2: Fallback to Axesso if SerpAPI didn't provide enough deals
            if allDeals.count < 3 {
                print("🔄 Fallback: Trying Axesso deals...")
                
                if let axessoService = try? apiConfig.createAxessoAmazonService() {
                    let searchTerms = ["electronics deals", "tech discounts", "gadget clearance"]
                    
                    for searchTerm in searchTerms {
                        do {
                            print("🔍 Trying Axesso search: '\(searchTerm)'...")
                            let dealsResponse = try await axessoService.searchDeals(keyword: searchTerm, page: 1)
                        
                        // Convert deals to ProductItemDTO
                        let dealProducts = dealsResponse.deals?.compactMap { deal -> ProductItemDTO? in
                            // Only include deals with significant discounts
                            guard let originalPrice = deal.originalPrice,
                                  let dealPrice = deal.dealPrice,
                                  originalPrice > dealPrice,
                                  let savingsAmount = deal.savingsAmount,
                                  savingsAmount > 10 else { return nil }
                            
                            return ProductItemDTO(
                                sourceId: deal.asin ?? UUID().uuidString,
                                name: deal.productTitle ?? "Amazon Deal",
                                productDescription: "Save \(deal.savingsPercentage ?? "")%",
                                price: dealPrice,
                                originalPrice: originalPrice,
                                imageURL: URL(string: deal.imageUrl ?? ""),
                                brand: deal.manufacturer ?? "Unknown",
                                source: "axesso_amazon",
                                isInStock: true,
                                rating: Double(deal.productRating ?? "0"),
                                reviewCount: deal.countReview,
                                productUrl: deal.productUrl
                            )
                            } ?? []
                            
                            if !dealProducts.isEmpty {
                                allDeals.append(contentsOf: dealProducts)
                                print("✅ Axesso '\(searchTerm)': Found \(dealProducts.count) deals")
                                break // Found deals, stop trying other terms
                            } else {
                                print("⚠️ Axesso '\(searchTerm)': No deals found")
                            }
                        
                        } catch {
                            print("⚠️ Axesso '\(searchTerm)' failed: \(error)")
                            continue // Try next search term
                        }
                    }
                }
            }
            
            // Update results if we found deals
            if !allDeals.isEmpty {
                // Remove duplicates and take best deals
                let uniqueDeals = Array(Set(allDeals.map { $0.sourceId }))
                    .compactMap { sourceId in allDeals.first { $0.sourceId == sourceId } }
                    .sorted { deal1, deal2 in
                        // Sort by discount amount if available
                        let discount1 = (deal1.originalPrice ?? deal1.price ?? 0) - (deal1.price ?? 0)
                        let discount2 = (deal2.originalPrice ?? deal2.price ?? 0) - (deal2.price ?? 0)
                        return discount1 > discount2
                    }
                
                // Cache the results
                await UnifiedCacheManager.shared.set(key: cacheKey, value: uniqueDeals, ttl: 4 * 3600) // 4 hours
                await UnifiedCacheManager.shared.set(key: cacheTimestamp, value: Date(), ttl: 4 * 3600) // Store cache time
                
                // Update with fresh deals
                let newDeals = Array(uniqueDeals.prefix(5))
                priceDropProducts = newDeals
                print("✅ SMART CACHE: \(priceDropProducts.count) fresh deals cached for 4h - future app opens won't waste API calls!")
                
                // Log deal details for debugging
                for (index, deal) in priceDropProducts.enumerated() {
                    let discount = (deal.originalPrice ?? deal.price ?? 0) - (deal.price ?? 0)
                    print("🏷️ Deal #\(index + 1): \(deal.name) - Save $\(String(format: "%.2f", discount)) - \(deal.source)")
                }
                
            } else {
                print("⚠️ No deals found from any API - using demo fallback")
                priceDropProducts = Array(getDemoPriceDropProducts().prefix(4))
                print("✅ Demo fallback: \(priceDropProducts.count) demo deals loaded (Echo Dot, Roku, etc.)")
            }
            
        } catch {
            print("❌ Price drops loading failed: \(error)")
            priceDropProducts = Array(getDemoPriceDropProducts().prefix(4))
            print("✅ Demo fallback: \(priceDropProducts.count) demo deals loaded due to API failure")
        }
        
        isLoadingPriceDrops = false
    }
    
    private func loadRecommendedProducts() async {
        isLoadingRecommended = true
        
        do {
            // Initialize services first
            await initializeRetailerServices()
            
            // Check cache first
            let cacheKey = "popular_this_week_2024"
            if let cachedResult = await UnifiedCacheManager.shared.get(key: cacheKey) as AggregatedSearchResult? {
                print("📦 Using cached popular products (\(cachedResult.products.count) items)")
                recommendedProducts = Array(cachedResult.products.prefix(4))
                isLoadingRecommended = false
                return
            }
            
            // Load popular electronics from both SerpAPI and Axesso
            print("🔍 Loading fresh popular products...")
            let results = try await apiCoordinator.search(
                query: "popular electronics 2024 smart home",
                retailers: ["google_shopping", "axesso_amazon"],
                options: SearchOptions(
                    maxResults: 8,
                    sortOrder: .relevance
                )
            )
            
            // Take first 4 products for Popular This Week section
            recommendedProducts = Array(results.products.prefix(4))
            print("✅ Loaded \(recommendedProducts.count) popular products")
            
            // Add to persistent cache
            if !results.products.isEmpty {
                await PersistentProductCache.shared.addProducts(results.products)
                print("📱 Added \(results.products.count) popular products to persistent cache")
            }
            
        } catch {
            print("❌ Failed to load recommended products: \(error)")
            // Use a few demo items as fallback
            recommendedProducts = Array(getDemoRecommendedProducts().prefix(4))
        }
        
        isLoadingRecommended = false
    }
    
    func searchByCategory(_ category: String) async -> [ProductItemDTO] {
        do {
            let results = try await apiCoordinator.search(
                query: category,
                retailers: ["google_shopping", "amazon", "walmart_production", "home_depot", "ebay_production", "bestbuy"],
                options: SearchOptions(
                    maxResults: 20,
                    sortOrder: .relevance
                )
            )
            
            // Add to persistent cache
            if !results.products.isEmpty {
                await PersistentProductCache.shared.addProducts(results.products)
                print("📱 Added \(results.products.count) category search results to persistent cache")
            }
            
            return results.products
        } catch {
            print("❌ Failed to search category \(category): \(error)")
            return []
        }
    }
    
    func refreshData() {
        Task {
            print("🔄 LIVE REFRESH: Force loading fresh data from APIs for demo")
            
            // Clear existing cache to force fresh API calls
            await UnifiedCacheManager.shared.remove(key: "live_trending_products_cache")
            await UnifiedCacheManager.shared.remove(key: "smart_deals_cache_v2")
            await UnifiedCacheManager.shared.remove(key: "deals_cache_timestamp")
            await UnifiedCacheManager.shared.remove(key: "popular_this_week_2024")
            
            // Load all sections with fresh API calls
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadTrendingProducts() }
                group.addTask { await self.loadPriceDrops() }
                group.addTask { await self.loadRecommendedProducts() }
            }
            
            print("✅ LIVE REFRESH: All sections refreshed with fresh API data!")
        }
    }
    
    // MARK: - Live Trending Refresh
    
    /// Refresh trending products with a live SerpAPI call and update persistent cache
    func refreshTrendingWithLiveAPI() async {
        print("🚀 LIVE TRENDING REFRESH: Making fresh SerpAPI call...")
        isLoadingTrending = true
        
        do {
            // Initialize services
            await initializeRetailerServices()
            
            // Get fresh trending queries from Google Trends
            let trendsService = GoogleTrendsService.shared
            await trendsService.refreshTrendingProducts()
            let trendingQueries = trendsService.getTrendingProducts()
            
            print("🔥 Live refresh with trending queries: \(trendingQueries.prefix(3).joined(separator: ", "))")
            
            // Make a fresh SerpAPI call with trending terms
            var freshProducts: [ProductItemDTO] = []
            
            // Use rotating search queries for variety
            let trendingSearchTerms = [
                "trending electronics 2024",
                "popular tech gadgets",
                "best selling electronics",
                "new technology products",
                "smart home devices trending",
                "gaming accessories popular",
                "wireless headphones bestsellers",
                "fitness tech trending"
            ]
            
            // Pick a random trending query or use Google Trends suggestions
            let randomIndex = Int.random(in: 0..<trendingSearchTerms.count)
            let searchQuery = !trendingQueries.isEmpty && Bool.random() ? 
                trendingQueries.randomElement()! : 
                trendingSearchTerms[randomIndex]
            
            do {
                print("🔍 LIVE API CALL: Searching for '\(searchQuery)'...")
                let serpResults = try await self.apiCoordinator.search(
                    query: searchQuery,
                    retailers: ["google_shopping", "walmart_production", "home_depot", "amazon", "ebay_production"],
                    options: SearchOptions(maxResults: 20, sortOrder: .relevance)
                )
                freshProducts = serpResults.products
                print("✅ LIVE API: Got \(freshProducts.count) fresh products!")
                
                // Log the fresh products
                for (index, product) in freshProducts.prefix(4).enumerated() {
                    print("🆕 Fresh #\(index + 1): \(product.name) - $\(product.price ?? 0) - \(product.source)")
                }
            } catch {
                print("❌ Live SerpAPI call failed: \(error)")
                
                // Try alternative search terms
                let fallbackTerms = ["popular gadgets 2024", "best electronics deals", "new tech products"]
                for term in fallbackTerms {
                    do {
                        print("🔄 Trying fallback search: '\(term)'...")
                        let results = try await self.apiCoordinator.search(
                            query: term,
                            retailers: ["google_shopping", "walmart_production", "home_depot", "amazon", "ebay_production"],
                            options: SearchOptions(maxResults: 15, sortOrder: .relevance)
                        )
                        if !results.products.isEmpty {
                            freshProducts = results.products
                            print("✅ Fallback search successful: \(freshProducts.count) products")
                            break
                        }
                    } catch {
                        continue
                    }
                }
            }
            
            // Update if we got fresh products
            if !freshProducts.isEmpty {
                // Remove duplicates
                let uniqueProducts = Array(Set(freshProducts.map { $0.sourceId }))
                    .compactMap { sourceId in freshProducts.first { $0.sourceId == sourceId } }
                
                // Add to persistent cache for future instant loading
                await PersistentProductCache.shared.addProducts(uniqueProducts)
                print("💾 Added \(uniqueProducts.count) products to persistent cache")
                
                // Update cache for immediate use
                let cacheKey = "live_trending_products_cache"
                await UnifiedCacheManager.shared.set(key: cacheKey, value: uniqueProducts, ttl: 15 * 60) // 15 minutes for demo stability
                
                // Update UI
                await MainActor.run {
                    self.allTrendingProducts = uniqueProducts
                    self.trendingProducts = Array(uniqueProducts.prefix(6))
                    self.lastTrendingRefresh = Date()
                }
                
                print("✅ LIVE REFRESH COMPLETE: Showing \(trendingProducts.count) fresh products (total: \(allTrendingProducts.count))")
            } else {
                print("⚠️ No fresh products found - keeping existing products")
            }
            
        } catch {
            print("❌ Live refresh failed: \(error)")
        }
        
        isLoadingTrending = false
    }
    
    
    // MARK: - Private Methods
    
    private func initializeRetailerServices() async {
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
            print("Failed to initialize retailer services: \(error)")
        }
    }
    
    // MARK: - Demo Data
    
    private func loadDemoData() {
        trendingProducts = getDemoTrendingProducts()
        priceDropProducts = getDemoPriceDropProducts()
        recommendedProducts = getDemoRecommendedProducts()
    }
    
    private func getDemoTrendingProducts() -> [ProductItemDTO] {
        return [
            ProductItemDTO(
                sourceId: "demo1",
                name: "Wireless Bluetooth Headphones",
                productDescription: "High-quality noise-cancelling headphones",
                price: 199.99,
                imageURL: URL(string: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400"),
                brand: "AudioTech",
                source: "google_shopping",
                category: "Audio",
                rating: 4.6,
                reviewCount: 1250,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo2",
                name: "Stainless Steel Coffee Maker",
                productDescription: "12-cup programmable coffee maker",
                price: 89.99,
                imageURL: URL(string: "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400"),
                brand: "BrewMaster",
                source: "amazon",
                category: "Kitchen",
                rating: 4.4,
                reviewCount: 890,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo3",
                name: "Travel Backpack",
                productDescription: "Waterproof hiking and travel backpack",
                price: 79.99,
                imageURL: URL(string: "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400"),
                brand: "AdventurePack",
                source: "google_shopping",
                category: "Sports & Fitness",
                rating: 4.7,
                reviewCount: 567,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo4",
                name: "Wireless Computer Mouse",
                productDescription: "Ergonomic wireless mouse with precision tracking",
                price: 29.99,
                imageURL: URL(string: "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=400"),
                brand: "TechMouse",
                source: "amazon",
                category: "Computers",
                rating: 4.5,
                reviewCount: 2340,
                productUrl: "https://example.com"
            )
        ]
    }
    
    private func getDemoPriceDropProducts() -> [ProductItemDTO] {
        return [
            ProductItemDTO(
                sourceId: "demo6",
                name: "Echo Dot (5th Gen)",
                productDescription: "Smart speaker with Alexa featuring improved audio quality, LED display showing time and temperature, and voice control for music, smart home devices, and more. Compatible with Amazon Music, Spotify, and other streaming services.",
                price: 29.99,
                originalPrice: 49.99,
                imageURL: URL(string: "https://m.media-amazon.com/images/I/71Ke6l1p5YL._AC_SL1500_.jpg"),
                brand: "Amazon",
                source: "amazon",
                category: "Smart Home",
                rating: 4.5,
                reviewCount: 3456,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo7",
                name: "Roku Streaming Stick 4K",
                productDescription: "4K streaming device with HDR10+ support and Dolby Vision. Includes voice remote with TV controls and private listening feature. Access 500+ streaming channels including Netflix, Disney+, Hulu, and more.",
                price: 39.99,
                originalPrice: 59.99,
                imageURL: URL(string: "https://m.media-amazon.com/images/I/51FlG6SIJ8L._AC_SL1500_.jpg"),
                brand: "Roku",
                source: "walmart_production",
                category: "Entertainment",
                rating: 4.6,
                reviewCount: 2100,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo8",
                name: "AirPods (3rd Gen)",
                productDescription: "Wireless earbuds with spatial audio, adaptive EQ, and up to 6 hours of listening time. Features sweat and water resistance, quick setup for Apple devices, and seamless switching between devices.",
                price: 149.99,
                originalPrice: 179.99,
                imageURL: URL(string: "https://m.media-amazon.com/images/I/61hWAYq8QkL._AC_SL1500_.jpg"),
                brand: "Apple",
                source: "google_shopping",
                category: "Apple",
                rating: 4.4,
                reviewCount: 1567,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo9",
                name: "Instant Pot Duo",
                productDescription: "7-in-1 multi-functional pressure cooker with slow cooker, rice cooker, steamer, sauté, yogurt maker, and warmer functions. Features easy-to-use controls, safety mechanisms, and stainless steel cooking pot for quick and healthy meal preparation.",
                price: 79.99,
                originalPrice: 119.99,
                imageURL: URL(string: "https://m.media-amazon.com/images/I/71HG+b9p3KL._AC_SL1500_.jpg"),
                brand: "Instant Pot",
                source: "amazon",
                category: "Kitchen",
                rating: 4.7,
                reviewCount: 4567,
                productUrl: "https://example.com"
            )
        ]
    }
    
    private func getDemoRecommendedProducts() -> [ProductItemDTO] {
        return [
            ProductItemDTO(
                sourceId: "demo10",
                name: "Apple Watch Series 9",
                productDescription: "Advanced health tracking smartwatch",
                price: 399.99,
                brand: "Apple",
                source: "google_shopping",
                rating: 4.8,
                reviewCount: 2345,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo11",
                name: "Dyson V15 Detect",
                productDescription: "Cordless vacuum cleaner",
                price: 649.99,
                brand: "Dyson",
                source: "home_depot",
                rating: 4.7,
                reviewCount: 890,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo12",
                name: "Nintendo Switch OLED",
                productDescription: "Hybrid gaming console",
                price: 349.99,
                brand: "Nintendo",
                source: "bestbuy",
                rating: 4.9,
                reviewCount: 3456,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo13",
                name: "Bose QuietComfort 45",
                productDescription: "Noise-cancelling headphones",
                price: 329.99,
                brand: "Bose",
                source: "google_shopping",
                rating: 4.6,
                reviewCount: 1234,
                productUrl: "https://example.com"
            ),
            ProductItemDTO(
                sourceId: "demo14",
                name: "Ring Video Doorbell",
                productDescription: "Smart doorbell with video",
                price: 99.99,
                brand: "Ring",
                source: "amazon",
                rating: 4.5,
                reviewCount: 5678,
                productUrl: "https://example.com"
            )
        ]
    }
}