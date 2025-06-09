//
//  ProductAggregator.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation

// MARK: - Product Aggregation & Deduplication

struct ProductAggregator {
    
    // MARK: - Deduplication
    
    static func deduplicateAndMerge(_ products: [ProductItemDTO]) -> [ProductItemDTO] {
        var productGroups: [String: [ProductItemDTO]] = [:]
        
        // Group similar products
        for product in products {
            let key = generateProductKey(product)
            if productGroups[key] == nil {
                productGroups[key] = []
            }
            productGroups[key]?.append(product)
        }
        
        // Merge each group into a single product
        var mergedProducts: [ProductItemDTO] = []
        
        for (_, group) in productGroups {
            if group.count == 1 {
                mergedProducts.append(group[0])
            } else {
                let merged = mergeSimilarProducts(group)
                mergedProducts.append(merged)
            }
        }
        
        print("📊 Product aggregation: \(products.count) → \(mergedProducts.count) (removed \(products.count - mergedProducts.count) duplicates)")
        
        return mergedProducts
    }
    
    // MARK: - Sorting
    
    static func sort(
        _ products: [ProductItemDTO],
        by sortOrder: ProductSortOrder,
        filters: [ProductFilter]
    ) -> [ProductItemDTO] {
        
        // Apply filters first
        var filteredProducts = applyFilters(products, filters: filters)
        
        // Then sort
        switch sortOrder {
        case .relevance:
            filteredProducts = sortByRelevance(filteredProducts)
        case .priceLowToHigh:
            filteredProducts = filteredProducts.sorted { 
                ($0.price ?? Double.infinity) < ($1.price ?? Double.infinity)
            }
        case .priceHighToLow:
            filteredProducts = filteredProducts.sorted { 
                ($0.price ?? 0) > ($1.price ?? 0)
            }
        case .rating:
            filteredProducts = filteredProducts.sorted { 
                ($0.rating ?? 0) > ($1.rating ?? 0)
            }
        case .newest:
            // For now, sort by source (could be enhanced with actual date data)
            filteredProducts = filteredProducts.sorted { $0.source < $1.source }
        }
        
        return filteredProducts
    }
    
    // MARK: - Private Methods
    
    private static func generateProductKey(_ product: ProductItemDTO) -> String {
        let normalizedName = normalizeProductName(product.name)
        let brand = product.brand.lowercased()
        let priceRange = getPriceRange(product.price)
        
        return "\(brand)_\(normalizedName)_\(priceRange)"
    }
    
    private static func normalizeProductName(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
    }
    
    private static func getPriceRange(_ price: Double?) -> String {
        guard let price = price else { return "unknown" }
        
        switch price {
        case 0..<25: return "budget"
        case 25..<100: return "low"
        case 100..<300: return "mid"
        case 300..<1000: return "high"
        default: return "premium"
        }
    }
    
    private static func mergeSimilarProducts(_ products: [ProductItemDTO]) -> ProductItemDTO {
        guard let primary = products.first else {
            fatalError("Cannot merge empty product list")
        }
        
        // Use the product with the most complete information as the base
        let bestProduct = products.max { p1, p2 in
            let score1 = calculateCompletenessScore(p1)
            let score2 = calculateCompletenessScore(p2)
            return score1 < score2
        } ?? primary
        
        // Collect all cross-retailer information
        var crossRetailerPrices: [CrossRetailerPrice] = []
        var allImageUrls: [String] = []
        
        for product in products {
            // Add price from this retailer
            if let price = product.price {
                crossRetailerPrices.append(CrossRetailerPrice(
                    retailer: product.source,
                    price: price,
                    url: product.productUrl,
                    availability: product.isInStock
                ))
            }
            
            // Collect image URLs
            if let imageUrls = product.imageUrls {
                allImageUrls.append(contentsOf: imageUrls)
            }
            if let thumbnailUrl = product.thumbnailUrl {
                allImageUrls.append(thumbnailUrl)
            }
        }
        
        // Find best price
        let bestPrice = crossRetailerPrices.min { $0.price < $1.price }?.price
        
        // Create merged product
        return ProductItemDTO(
            sourceId: bestProduct.sourceId,
            name: bestProduct.name,
            productDescription: bestProduct.productDescription,
            price: bestPrice ?? bestProduct.price,
            originalPrice: bestProduct.originalPrice,
            currency: bestProduct.currency,
            imageURL: bestProduct.imageURL,
            imageUrls: Array(Set(allImageUrls)), // Remove duplicates
            thumbnailUrl: bestProduct.thumbnailUrl,
            brand: bestProduct.brand,
            source: "Multi-Retailer", // Indicate this is aggregated
            category: bestProduct.category,
            isInStock: products.contains { $0.isInStock }, // In stock if any retailer has it
            rating: bestProduct.rating,
            reviewCount: bestProduct.reviewCount,
            productUrl: bestProduct.productUrl
        )
    }
    
    private static func calculateCompletenessScore(_ product: ProductItemDTO) -> Int {
        var score = 0
        
        if !product.name.isEmpty { score += 1 }
        if product.productDescription?.isEmpty == false { score += 1 }
        if product.price != nil { score += 1 }
        if product.imageURL != nil { score += 1 }
        if !product.brand.isEmpty { score += 1 }
        if product.category?.isEmpty == false { score += 1 }
        if product.rating != nil { score += 1 }
        if product.reviewCount != nil { score += 1 }
        
        return score
    }
    
    private static func sortByRelevance(_ products: [ProductItemDTO]) -> [ProductItemDTO] {
        return products.sorted { p1, p2 in
            let score1 = calculateRelevanceScore(p1)
            let score2 = calculateRelevanceScore(p2)
            return score1 > score2
        }
    }
    
    private static func calculateRelevanceScore(_ product: ProductItemDTO) -> Double {
        var score: Double = 0
        
        // Rating weight (0-50 points)
        if let rating = product.rating {
            score += rating * 10
        }
        
        // Review count weight (0-20 points)
        if let reviewCount = product.reviewCount {
            score += min(20, Double(reviewCount) / 100)
        }
        
        // Stock availability (0-15 points)
        if product.isInStock {
            score += 15
        }
        
        // Price availability (0-10 points)
        if product.price != nil {
            score += 10
        }
        
        // Image availability (0-5 points)
        if product.imageURL != nil {
            score += 5
        }
        
        return score
    }
    
    private static func applyFilters(_ products: [ProductItemDTO], filters: [ProductFilter]) -> [ProductItemDTO] {
        var filtered = products
        
        for filter in filters {
            switch filter.type {
            case .brand:
                filtered = filtered.filter { $0.brand.lowercased().contains(filter.value.lowercased()) }
                
            case .category:
                filtered = filtered.filter { 
                    $0.category?.lowercased().contains(filter.value.lowercased()) == true
                }
                
            case .priceRange:
                if let range = parsePriceRange(filter.value) {
                    filtered = filtered.filter { 
                        guard let price = $0.price else { return false }
                        return price >= range.min && price <= range.max
                    }
                }
                
            case .inStockOnly:
                if filter.value.lowercased() == "true" {
                    filtered = filtered.filter { $0.isInStock }
                }
            }
        }
        
        return filtered
    }
    
    private static func parsePriceRange(_ value: String) -> (min: Double, max: Double)? {
        let components = value.split(separator: "-")
        guard components.count == 2,
              let min = Double(components[0]),
              let max = Double(components[1]) else {
            return nil
        }
        return (min: min, max: max)
    }
}

// MARK: - Product Matcher

struct ProductMatcher {
    
    static func calculateSimilarity(_ name1: String, _ name2: String) -> Double {
        let normalized1 = normalizeForComparison(name1)
        let normalized2 = normalizeForComparison(name2)
        
        // Use Jaccard similarity on word sets
        let words1 = Set(normalized1.split(separator: " ").map(String.init))
        let words2 = Set(normalized2.split(separator: " ").map(String.init))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0 }
        
        return Double(intersection.count) / Double(union.count)
    }
    
    private static func normalizeForComparison(_ text: String) -> String {
        return text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Supporting Types

struct CrossRetailerPrice: Codable {
    let retailer: String
    let price: Double
    let url: String?
    let availability: Bool
}

struct CrossRetailerData: Codable {
    let prices: [CrossRetailerPrice]
    let availability: [String: Bool]
}

// Note: CrossRetailerData would need to be added to ProductItemDTO
// or stored separately in a database/cache