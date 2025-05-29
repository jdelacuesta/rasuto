//
//  ProductExtensions.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import Foundation

// MARK: - ProductItem Convenience Methods

extension ProductItem {
    /// Check if the product has a valid price
    var hasValidPrice: Bool {
        return price != nil && price! > 0
    }
    
    /// Get formatted price string
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: currentPrice)) ?? "$0.00"
    }
    
    /// Calculate discount percentage
    var discountPercentage: Double? {
        guard let original = originalPrice, original > 0, let current = price else { return nil }
        return ((original - current) / original) * 100
    }
    
    /// Check if product is on sale
    var isOnSale: Bool {
        guard let original = originalPrice, let current = price else { return false }
        return current < original
    }
}

// MARK: - Collection Extension for ProductItem

extension Array where Element == ProductItem {
    /// Filter products by store
    func byStore(_ store: String) -> [ProductItem] {
        return self.filter { $0.store.lowercased() == store.lowercased() }
    }
    
    /// Filter products that are tracked
    var tracked: [ProductItem] {
        return self.filter { $0.isTracked }
    }
    
    /// Filter products that are favorites
    var favorites: [ProductItem] {
        return self.filter { $0.isFavorite }
    }
    
    /// Sort by price (ascending)
    var sortedByPrice: [ProductItem] {
        return self.sorted { $0.currentPrice < $1.currentPrice }
    }
    
    /// Get products with price drops
    var withPriceDrops: [ProductItem] {
        return self.filter { $0.isOnSale }
    }
}