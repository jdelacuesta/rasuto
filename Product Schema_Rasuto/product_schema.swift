import Foundation
import SwiftData

// MARK: - Main Product Model

@Model
final class Product {
    // Core Product Information
    var id: String                // Unique identifier (could be from source API)
    var name: String              // Product name
    var description: String       // Product description
    var price: Double             // Current price
    var originalPrice: Double?    // Original price (for discount calculation)
    var currency: String          // Currency code (USD, EUR, etc.)
    var url: String               // Product URL on source website
    
    // Product Metadata
    var brand: String             // Brand name
    var source: String            // Source retailer (Amazon, Best Buy, etc.)
    var sourceId: String          // ID used by the source API
    var category: String          // Product category
    var subcategory: String?      // Product subcategory
    
    // Media
    var imageUrls: [String]       // Array of image URLs
    var thumbnailUrl: String?     // Primary thumbnail image URL
    
    // Inventory Information
    var inStock: Bool             // Whether product is in stock
    var stockQuantity: Int?       // Available quantity if provided
    var availability: String?     // Availability status text
    
    // Specifications
    @Relationship(deleteRule: .cascade) var specifications: [ProductSpecification]? // Technical specs
    @Relationship(deleteRule: .cascade) var variant0s: [ProductVariant]?            // Color/size variants
    
    // Reviews and Ratings
    var rating: Double?           // Average star rating (e.g., 4.5)
    var reviewCount: Int?         // Number of reviews
    
    // Pricing and Tracking
    var priceHistory: [PricePoint]? // Historical price points
    var lastUpdated: Date         // When product was last updated
    var dateAdded: Date           // When product was added to DB
    var isFavorite: Bool = false  // User favorite flag
    var isTracked: Bool = false   // Price tracking flag
    
    // MARK: - Initialization
    
    init(
        id: String,
        name: String,
        description: String,
        price: Double,
        currency: String,
        url: String,
        brand: String,
        source: String,
        sourceId: String,
        category: String,
        lastUpdated: Date = Date(),
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.currency = currency
        self.url = url
        self.brand = brand
        self.source = source
        self.sourceId = sourceId
        self.category = category
        self.lastUpdated = lastUpdated
        self.dateAdded = dateAdded
        self.inStock = true
    }
}

// MARK: - Product Specification Model

@Model
final class ProductSpecification {
    var name: String      // Specification name (e.g., "Screen Size", "Material")
    var value: String     // Specification value (e.g., "6.7 inches", "Cotton")
    
    // Relationship to parent
    @Relationship(inverse: \Product.specifications) var product: Product?
    
    init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

// MARK: - Product Variant Model
@Model
final class ProductVariant {
    var id: String           // Variant ID
    var name: String         // Variant name (e.g., "Red", "Medium")
    var type: String         // Variant type (e.g., "Color", "Size")
    var price: Double?       // Price difference or specific price
    var isAvailable: Bool    // Whether variant is available
    var imageUrl: String?    // Image URL for this variant
    
    // Relationship to parent
    @Relationship(inverse: \Product.variants) var product: Product?
    
    init(id: String, name: String, type: String, isAvailable: Bool = true) {
        self.id = id
        self.name = name
        self.type = type
        self.isAvailable = isAvailable
    }
}

// MARK: - Price History Point

struct PricePoint: Codable, Hashable {
    var date: Date
    var price: Double
    var currency: String
    
    init(date: Date = Date(), price: Double, currency: String = "USD") {
        self.date = date
        self.price = price
        self.currency = currency
    }
}

// MARK: - Schema Configuration

extension ModelConfiguration {
    static var productSchema: ModelConfiguration {
        let schema = ModelConfiguration(schema: Schema([
            Product.self,
            ProductSpecification.self,
            ProductVariant.self
        ]))
        return schema
    }
}
