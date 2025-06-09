//
//  TrackedProductModel.swift
//  Rasuto
//
//  Created by Claude on 6/4/25.
//

import SwiftData
import Foundation

/// SwiftData model for persisting tracked products
@Model
class TrackedProductModel {
    var productId: String = ""
    var productName: String = ""
    var productSource: String = ""
    var lastKnownPrice: Double = 0.0
    var originalPrice: Double?
    var imageUrl: String = ""
    var productUrl: String?
    var lastChecked: Date = Foundation.Date()
    var isActive: Bool = true
    var dateAdded: Date = Foundation.Date()
    
    init(
        productId: String,
        productName: String,
        productSource: String,
        lastKnownPrice: Double,
        originalPrice: Double? = nil,
        imageUrl: String,
        productUrl: String? = nil,
        isActive: Bool = true
    ) {
        self.productId = productId
        self.productName = productName
        self.productSource = productSource
        self.lastKnownPrice = lastKnownPrice
        self.originalPrice = originalPrice
        self.imageUrl = imageUrl
        self.productUrl = productUrl
        self.lastChecked = Date()
        self.isActive = isActive
        self.dateAdded = Date()
    }
    
    /// Convert to ProductItem for use in tracking
    func toProductItem() -> ProductItem {
        let product = ProductItem(
            name: productName,
            productDescription: "",
            price: lastKnownPrice,
            currency: "USD",
            url: URL(string: productUrl ?? ""),
            brand: "",
            source: productSource,
            sourceId: productId,
            category: "",
            imageURL: URL(string: imageUrl),
            isInStock: true
        )
        
        // Set original price after initialization
        product.originalPrice = originalPrice
        
        return product
    }
    
    /// Create from ProductItem
    static func from(_ product: ProductItem) -> TrackedProductModel {
        return TrackedProductModel(
            productId: product.id.uuidString,
            productName: product.name,
            productSource: product.source,
            lastKnownPrice: product.price ?? 0.0,
            originalPrice: product.originalPrice,
            imageUrl: product.imageURL?.absoluteString ?? "",
            productUrl: product.url?.absoluteString,
            isActive: true
        )
    }
}

/// Notification preferences model
@Model
class NotificationPreferences {
    var enablePriceDropNotifications: Bool = true
    var enableBackInStockNotifications: Bool = true
    var enableTrackingUpdates: Bool = true
    var minimumPriceDropPercentage: Double = 5.0
    var minimumPriceDropAmount: Double = 1.0
    var notificationFrequency: NotificationFrequency = NotificationFrequency.immediate
    var lastUpdated: Date = Foundation.Date()
    
    init() {
        // Default values are now set in property declarations
    }
}

enum NotificationFrequency: String, CaseIterable, Codable {
    case immediate = "Immediate"
    case hourly = "Hourly"
    case daily = "Daily"
    case disabled = "Disabled"
    
    var displayName: String {
        return self.rawValue
    }
}