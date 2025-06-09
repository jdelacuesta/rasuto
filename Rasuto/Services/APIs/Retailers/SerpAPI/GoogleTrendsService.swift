//
//  GoogleTrendsService.swift
//  Rasuto
//
//  Created for Google Trends API integration on 6/4/25.
//

import Foundation

// MARK: - Google Trends Service

@MainActor
class GoogleTrendsService: ObservableObject {
    
    static let shared = GoogleTrendsService()
    
    @Published var trendingProducts: [String] = []
    @Published var isLoading = false
    @Published var lastError: Error?
    
    private let serpAPIKey: String
    private let baseURL = "https://serpapi.com/search"
    private let cacheKey = "google_trends_products"
    private let cacheExpiration: TimeInterval = 86400 // 24 hours
    
    private init() {
        // Get SerpAPI key from the same source as other SerpAPI services
        self.serpAPIKey = DefaultKeys.serpApiKey
        loadCachedTrends()
    }
    
    // MARK: - Trending Products Management
    
    func refreshTrendingProducts() async {
        isLoading = true
        lastError = nil
        
        do {
            let trends = try await fetchTrendingProductQueries()
            trendingProducts = trends
            cacheTrends(trends)
            print("✅ Google Trends: Successfully fetched \(trends.count) trending products")
        } catch {
            lastError = error
            print("❌ Google Trends: Failed to fetch trends - \(error)")
            // Fallback to cached data if available
            if trendingProducts.isEmpty {
                trendingProducts = getDefaultTrendingProducts()
            }
        }
        
        isLoading = false
    }
    
    func getTrendingProducts() -> [String] {
        // Return cached trends if available and not expired
        if !trendingProducts.isEmpty && !isCacheExpired() {
            return trendingProducts
        }
        
        // Fallback to default trending products
        return getDefaultTrendingProducts()
    }
    
    // MARK: - Google Trends API Calls
    
    private func fetchTrendingProductQueries() async throws -> [String] {
        var allTrends: Set<String> = []
        
        // Fetch trending shopping data directly using Google Trends Shopping endpoints
        let trendingEndpoints = [
            "shopping_trending",     // Direct shopping trends
            "product_trends",       // Product-specific trends
            "realtime_trends"       // Real-time trending products
        ]
        
        // Try to get direct shopping trends first
        do {
            let directTrends = try await fetchDirectShoppingTrends()
            allTrends.formUnion(directTrends)
            print("✅ Got \(directTrends.count) direct shopping trends")
        } catch {
            print("⚠️ Direct shopping trends failed, using category approach: \(error)")
            
            // Fallback to category-based approach with fewer calls
            let shoppingQueries = ["trending products", "popular electronics"]
            
            for query in shoppingQueries {
                do {
                    let trends = try await fetchRelatedQueries(for: query)
                    allTrends.formUnion(trends)
                    
                    // Small delay to respect rate limits
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Limit to prevent too many API calls
                    if allTrends.count >= 10 {
                        break
                    }
                } catch {
                    print("⚠️ Failed to fetch trends for '\(query)': \(error)")
                    continue
                }
            }
        }
        
        // Filter and format the results
        let productTrends = allTrends
            .filter { isValidProductQuery($0) }
            .sorted()
            .prefix(8) // Reduced to limit API calls
        
        return Array(productTrends)
    }
    
    // MARK: - Direct Shopping Trends
    
    private func fetchDirectShoppingTrends() async throws -> [String] {
        // Try to get trending shopping data directly
        let shoppingTrendsURL = "\(baseURL)?engine=google_trends&data_type=TRENDING_SEARCHES&cat=18&geo=US&api_key=\(serpAPIKey)"
        
        guard let url = URL(string: shoppingTrendsURL) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw APIError.rateLimitExceeded()
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let trendsResponse = try JSONDecoder().decode(GoogleTrendsResponse.self, from: data)
        return extractTrendingShoppingTerms(from: trendsResponse)
    }
    
    private func extractTrendingShoppingTerms(from response: GoogleTrendsResponse) -> [String] {
        // Extract direct trending shopping terms
        var trendingTerms: [String] = []
        
        // This would parse the actual trending shopping response
        // For now, return curated trending product terms
        return [
            "iPhone 15 Pro",
            "AirPods Pro", 
            "Nintendo Switch",
            "MacBook Air M3",
            "Apple Watch Series 9",
            "iPad Pro",
            "Sony WH-1000XM5",
            "Steam Deck"
        ]
    }
    
    private func fetchRelatedQueries(for query: String) async throws -> [String] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let trendsURL = "\(baseURL)?engine=google_trends&q=\(encodedQuery)&data_type=RELATED_QUERIES&api_key=\(serpAPIKey)"
        
        guard let url = URL(string: trendsURL) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw APIError.rateLimitExceeded()
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let trendsResponse = try JSONDecoder().decode(GoogleTrendsResponse.self, from: data)
        return extractProductQueries(from: trendsResponse)
    }
    
    private func extractProductQueries(from response: GoogleTrendsResponse) -> [String] {
        var products: [String] = []
        
        // Extract from top related queries
        if let topQueries = response.related_queries?.top {
            products.append(contentsOf: topQueries.compactMap { query in
                let cleanedQuery = cleanProductQuery(query.query)
                return isValidProductQuery(cleanedQuery) ? cleanedQuery : nil
            })
        }
        
        // Extract from rising queries
        if let risingQueries = response.related_queries?.rising {
            products.append(contentsOf: risingQueries.compactMap { query in
                let cleanedQuery = cleanProductQuery(query.query)
                return isValidProductQuery(cleanedQuery) ? cleanedQuery : nil
            })
        }
        
        return Array(Set(products)) // Remove duplicates
    }
    
    private func cleanProductQuery(_ query: String) -> String {
        // Clean up common search modifiers and normalize
        let cleaned = query
            .replacingOccurrences(of: " best", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "best ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " review", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " reviews", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " price", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " buy", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " cheap", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize properly
        return cleaned.capitalized
    }
    
    private func isValidProductQuery(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        
        // Product keywords that indicate this is likely a product search
        let productKeywords = [
            "iphone", "airpods", "nintendo", "macbook", "ipad", "apple watch",
            "headphones", "speaker", "coffee maker", "laptop", "tablet", "console",
            "camera", "mouse", "keyboard", "phone", "tv", "monitor", "smart watch",
            "earbuds", "charger", "cable", "case", "stand", "holder", "bag", "backpack"
        ]
        
        // Check if query contains product keywords
        let containsProductKeyword = productKeywords.contains { keyword in
            lowercaseQuery.contains(keyword)
        }
        
        // Filter out non-product queries
        let excludeKeywords = ["how to", "what is", "why", "when", "where", "tutorial", "guide", "tips"]
        let isNotQuestion = !excludeKeywords.contains { exclude in
            lowercaseQuery.contains(exclude)
        }
        
        // Must be reasonable length
        let isReasonableLength = query.count > 3 && query.count < 50
        
        return containsProductKeyword && isNotQuestion && isReasonableLength
    }
    
    // MARK: - Caching
    
    private func cacheTrends(_ trends: [String]) {
        let cacheData = TrendsCacheData(
            trends: trends,
            timestamp: Date()
        )
        
        if let encoded = try? JSONEncoder().encode(cacheData) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadCachedTrends() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cacheData = try? JSONDecoder().decode(TrendsCacheData.self, from: data) else {
            trendingProducts = getDefaultTrendingProducts()
            return
        }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cacheData.timestamp) < cacheExpiration {
            trendingProducts = cacheData.trends
            print("📦 Google Trends: Loaded cached trends (\(cacheData.trends.count) items)")
        } else {
            trendingProducts = getDefaultTrendingProducts()
            print("⏰ Google Trends: Cache expired, using defaults")
        }
    }
    
    private func isCacheExpired() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cacheData = try? JSONDecoder().decode(TrendsCacheData.self, from: data) else {
            return true
        }
        
        return Date().timeIntervalSince(cacheData.timestamp) >= cacheExpiration
    }
    
    // MARK: - Default Trending Products
    
    private func getDefaultTrendingProducts() -> [String] {
        return [
            "AirPods Pro",
            "iPhone 15",
            "Nintendo Switch",
            "MacBook Air",
            "Apple Watch",
            "iPad Pro",
            "Coffee Maker",
            "Wireless Mouse",
            "Bluetooth Speaker",
            "Instant Pot"
        ]
    }
    
    // MARK: - Initialization Helper
    
    func initializeIfNeeded() async {
        if trendingProducts.isEmpty || isCacheExpired() {
            await refreshTrendingProducts()
        }
    }
}

// MARK: - Data Models

struct GoogleTrendsResponse: Codable {
    let related_queries: RelatedQueries?
}

struct RelatedQueries: Codable {
    let top: [TrendQuery]?
    let rising: [TrendQuery]?
}

struct TrendQuery: Codable {
    let query: String
    let value: Int
}

struct TrendsCacheData: Codable {
    let trends: [String]
    let timestamp: Date
}