//
//  NLPSearchService.swift
//  Rasuto
//
//  Created for Rasuto on 4/28/25.
//

import Foundation
import NaturalLanguage
import Combine

class NLPSearchService {
    // MARK: - Properties
    
    private let retailers: [RetailerAPIService]
    private var cancellables = Set<AnyCancellable>()
    
    // Language detection
    private let languageRecognizer = NLLanguageRecognizer()
    
    // MARK: - Initialization
    
    init() {
        // Initialize with available retailer services
        do {
            let apiConfig = APIConfig()
            let bestBuyService = try apiConfig.createBestBuyService()
            let walmartService = try apiConfig.createWalmartService()
            let ebayService = try apiConfig.createEbayService()
            
            self.retailers = [bestBuyService, walmartService, ebayService]
        } catch {
            print("Failed to initialize retailer services: \(error)")
            self.retailers = []
        }
    }
    
    // MARK: - Search Processing
    
    /// Process a natural language search query and return product results
    /// - Parameter query: The user's search query, which can be in any language
    /// - Returns: Array of product results
    func processSearch(query: String) async throws -> [ProductItemDTO] {
        // Detect language
        let language = detectLanguage(query)
        
        // Extract key terms and entities from the query
        let searchTerms = extractSearchTerms(from: query, language: language)
        
        // Process attributes and filters
        let (attributes, filters) = processAttributes(query: query, language: language)
        
        // Create enhanced search query
        let enhancedQuery = buildEnhancedQuery(
            terms: searchTerms,
            attributes: attributes,
            language: language
        )
        
        // Perform search with enhanced query
        return try await performSearch(query: enhancedQuery, filters: filters)
    }
    
    // MARK: - Language Detection
    
    private func detectLanguage(_ text: String) -> NLLanguage {
        languageRecognizer.processString(text)
        
        if let dominantLanguage = languageRecognizer.dominantLanguage {
            return dominantLanguage
        }
        
        // Default to English if detection failed
        return .english
    }
    
    // MARK: - Term Extraction
    
    private func extractSearchTerms(from query: String, language: NLLanguage) -> [String] {
        var searchTerms = [String]()
        
        // Create a tagger for the given language
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = query
        
        // Specify what we want to tag
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        // Tag for named entities (products, brands)
        tagger.setLanguage(language, range: query.startIndex..<query.endIndex)
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                if tag == .personalName || tag == .organizationName || tag.rawValue == "Product" {
                    let term = String(query[tokenRange])
                    searchTerms.append(term)
                }
            }
            return true
        }
        
        // Tag for nouns and adjectives (product characteristics)
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag {
                switch tag {
                case .noun, .adjective:
                    let term = String(query[tokenRange])
                    if !searchTerms.contains(term) {
                        searchTerms.append(term)
                    }
                default:
                    break
                }
            }
            return true
        }
        
        return searchTerms
    }
    
    // MARK: - Attribute Processing
    
    /// Extract product attributes and search filters from the query
    private func processAttributes(query: String, language: NLLanguage) -> (attributes: [String: String], filters: [String: Any]) {
        var attributes = [String: String]()
        var filters = [String: Any]()
        
        // Price range detection
        if let priceRange = extractPriceRange(from: query) {
            filters["minPrice"] = priceRange.min
            filters["maxPrice"] = priceRange.max
        }
        
        // Brand detection
        if let brand = extractBrand(from: query) {
            attributes["brand"] = brand
            filters["brand"] = brand
        }
        
        // Category detection
        if let category = extractCategory(from: query) {
            attributes["category"] = category
            filters["category"] = category
        }
        
        // Sort order
        if query.contains("cheap") || query.contains("lowest price") {
            filters["sortBy"] = "price"
            filters["sortOrder"] = "asc"
        } else if query.contains("expensive") || query.contains("highest price") {
            filters["sortBy"] = "price"
            filters["sortOrder"] = "desc"
        } else if query.contains("best rated") || query.contains("highest rated") {
            filters["sortBy"] = "rating"
            filters["sortOrder"] = "desc"
        } else if query.contains("newest") || query.contains("latest") {
            filters["sortBy"] = "releaseDate"
            filters["sortOrder"] = "desc"
        }
        
        return (attributes, filters)
    }
    
    /// Extract price range from the query
    private func extractPriceRange(from query: String) -> (min: Double, max: Double)? {
        // Simple regex pattern to find price ranges
        // This is a basic implementation - could be expanded with more patterns
        let patterns = [
            // "between $100 and $200"
            #"between\s*\$?(\d+(?:\.\d+)?)\s*and\s*\$?(\d+(?:\.\d+)?)"#,
            
            // "from $100 to $200"
            #"from\s*\$?(\d+(?:\.\d+)?)\s*to\s*\$?(\d+(?:\.\d+)?)"#,
            
            // "$100-$200" or "$100 - $200"
            #"\$?(\d+(?:\.\d+)?)\s*-\s*\$?(\d+(?:\.\d+)?)"#,
            
            // "under $200"
            #"under\s*\$?(\d+(?:\.\d+)?)"#,
            
            // "less than $200"
            #"less than\s*\$?(\d+(?:\.\d+)?)"#,
            
            // "over $100"
            #"over\s*\$?(\d+(?:\.\d+)?)"#,
            
            // "more than $100"
            #"more than\s*\$?(\d+(?:\.\d+)?)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(query.startIndex..<query.endIndex, in: query)
                if let match = regex.firstMatch(in: query, range: nsRange) {
                    // Check which pattern matched
                    if match.numberOfRanges == 3 {
                        // Range with min and max
                        if let minRange = Range(match.range(at: 1), in: query),
                           let maxRange = Range(match.range(at: 2), in: query),
                           let min = Double(query[minRange]),
                           let max = Double(query[maxRange]) {
                            return (min: min, max: max)
                        }
                    } else if match.numberOfRanges == 2 {
                        // Single value (under/over)
                        if let valueRange = Range(match.range(at: 1), in: query),
                           let value = Double(query[valueRange]) {
                            
                            if pattern.contains("under") || pattern.contains("less than") {
                                return (min: 0, max: value)
                            } else if pattern.contains("over") || pattern.contains("more than") {
                                return (min: value, max: Double.greatestFiniteMagnitude)
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Extract brand name from the query
    private func extractBrand(from query: String) -> String? {
        let commonBrands = [
            "apple", "samsung", "sony", "microsoft", "google", "amazon", "dyson",
            "lg", "bose", "canon", "nikon", "dell", "hp", "lenovo", "asus",
            "acer", "nintendo", "philips", "panasonic", "xbox", "playstation"
        ]
        
        let lowercasedQuery = query.lowercased()
        
        for brand in commonBrands {
            if lowercasedQuery.contains(brand) {
                return brand.capitalized
            }
        }
        
        return nil
    }
    
    /// Extract product category from the query
    private func extractCategory(from query: String) -> String? {
        let categoryMappings = [
            ["tv", "television", "smart tv"]: "Televisions",
            ["phone", "smartphone", "iphone", "android"]: "Cell Phones",
            ["laptop", "notebook", "macbook", "chromebook"]: "Computers",
            ["camera", "dslr", "mirrorless", "lens"]: "Cameras",
            ["tablet", "ipad"]: "Tablets",
            ["game", "console", "ps5", "xbox", "nintendo"]: "Video Games",
            ["headphone", "earphone", "earbud", "airpod"]: "Headphones",
            ["speaker", "soundbar", "sound system"]: "Speakers",
            ["watch", "smartwatch", "apple watch"]: "Watches"
        ]
        
        let lowercasedQuery = query.lowercased()
        
        for (keywords, category) in categoryMappings {
            for keyword in keywords {
                if lowercasedQuery.contains(keyword) {
                    return category
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Query Building
    
    private func buildEnhancedQuery(terms: [String], attributes: [String: String], language: NLLanguage) -> String {
        var queryComponents = terms
        
        // Add attribute values if not already in terms
        for (_, value) in attributes {
            if !queryComponents.contains(value) {
                queryComponents.append(value)
            }
        }
        
        // Join components into a search query
        let searchQuery = queryComponents.joined(separator: " ")
        
        // If needed, translate query to English for API compatibility
        if language != .english {
            // In a real app, this would use a translation service
            // For now, we'll just use the original query
            return searchQuery
        }
        
        return searchQuery
    }
    
    // MARK: - Search Execution
    
    private func performSearch(query: String, filters: [String: Any]) async throws -> [ProductItemDTO] {
        var allResults: [ProductItemDTO] = []
        
        // Search across all retailers
        for retailer in retailers {
            do {
                let results = try await retailer.searchProducts(query: query)
                allResults.append(contentsOf: results)
            } catch {
                print("Error searching \(retailer): \(error)")
                // Continue with other retailers even if one fails
            }
        }
        
        // Apply filters
        allResults = applyFilters(to: allResults, filters: filters)
        
        return allResults
    }
    
    private func applyFilters(to results: [ProductItemDTO], filters: [String: Any]) -> [ProductItemDTO] {
        var filteredResults = results
        
        // Apply price filters
        if let minPrice = filters["minPrice"] as? Double {
            filteredResults = filteredResults.filter { ($0.price ?? 0) >= minPrice }
        }
        
        if let maxPrice = filters["maxPrice"] as? Double {
            filteredResults = filteredResults.filter { ($0.price ?? 0) <= maxPrice }
        }
        
        // Apply brand filter
        if let brand = filters["brand"] as? String {
            filteredResults = filteredResults.filter {
                $0.brand.lowercased().contains(brand.lowercased())
            }
        }
        
        // Apply category filter
        if let category = filters["category"] as? String {
            filteredResults = filteredResults.filter {
                $0.category?.lowercased().contains(category.lowercased()) ?? false
            }
        }
        
        // Apply sorting
        if let sortBy = filters["sortBy"] as? String, let sortOrder = filters["sortOrder"] as? String {
            filteredResults = sortResults(filteredResults, by: sortBy, order: sortOrder)
        }
        
        return filteredResults
    }
    
    private func sortResults(_ results: [ProductItemDTO], by sortField: String, order: String) -> [ProductItemDTO] {
        let isAscending = order == "asc"
        
        switch sortField {
        case "price":
            return results.sorted {
                isAscending ? ($0.price ?? 0) < ($1.price ?? 0) : ($0.price ?? 0) > ($1.price ?? 0)
            }
            
        case "rating":
            return results.sorted {
                isAscending ? ($0.rating ?? 0) < ($1.rating ?? 0) : ($0.rating ?? 0) > ($1.rating ?? 0)
            }
            
        case "reviewCount":
            return results.sorted {
                isAscending ? ($0.reviewCount ?? 0) < ($1.reviewCount ?? 0) : ($0.reviewCount ?? 0) > ($1.reviewCount ?? 0)
            }
            
        default:
            return results
        }
    }
    
    // MARK: - Multi-language Support
    
    // Get available languages for the interface
    func availableLanguages() -> [Locale] {
        return Locale.preferredLanguages.map { Locale(identifier: $0) }
    }
    
    // Get display name for a language
    func displayName(for locale: Locale) -> String {
        if let languageName = locale.localizedString(forLanguageCode: locale.languageCode ?? "") {
            return languageName
        }
        return locale.identifier
    }
    
    // Detect if query contains accessibility-related terms
    func isAccessibilityQuery(_ query: String) -> Bool {
        let accessibilityTerms = [
            "accessibility", "accessible", "disability", "vision impaired",
            "hearing impaired", "motor impaired", "cognitive", "assistive"
        ]
        
        let lowercasedQuery = query.lowercased()
        return accessibilityTerms.contains { lowercasedQuery.contains($0) }
    }
}
