import Foundation
import SwiftData

// MARK: - Main Product Model

@Model
final class ProductItem {
    
    // Core Product Information
    var id: UUID                  // Using UUID from original model
    var name: String              // Product name
    var productDescription: String // Renamed from description
    var price: Double?            // Made optional like in original model
    var originalPrice: Double?    // Original price (for discount calculation)
    var currency: String?         // Made optional like in original model
    var url: URL?                 // Using URL type from original model
    
    // Product Metadata
    var brand: String             // Brand name
    var source: String            // Source retailer (renamed from retailer)
    var sourceId: String          // ID used by the source API
    var category: String          // Product category
    var subcategory: String?      // Product subcategory
    
    // Media
    var imageUrls: [String]       // Array of image URLs
    var imageURL: URL?            // From original model
    var thumbnailUrl: String?     // Primary thumbnail image URL
    
    // Inventory Information
    var isInStock: Bool           // Using naming from original model
    var stockQuantity: Int?       // Available quantity if provided
    var availability: String?     // Availability status text
    
    // Specifications
    @Relationship(deleteRule: .cascade) var specifications: [ProductSpecification]? // Technical specs
    @Relationship(deleteRule: .cascade) var variants: [ProductVariant]?            // Color/size variants
    
    // Reviews and Ratings
    var rating: Double?           // Average star rating (e.g., 4.5)
    var reviewCount: Int?         // Number of reviews
    
    // Pricing and Tracking
    var priceHistory: [PricePoint]? // Historical price points
    var lastChecked: Date?        // From original model
    var addedDate: Date           // When product was added (from original model)
    var isFavorite: Bool = false  // User favorite flag
    var isTracked: Bool = false   // Price tracking flag
    
    // MARK: - Initialization
    
    init(
        name: String,
        productDescription: String = "",
        price: Double? = nil,
        currency: String? = "USD",
        url: URL? = nil,
        brand: String = "",
        source: String, // Required retailer name
        sourceId: String = "",
        category: String = "",
        imageURL: URL? = nil,
        isInStock: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.productDescription = productDescription
        self.price = price
        self.currency = currency
        self.url = url
        self.brand = brand
        self.source = source
        self.sourceId = sourceId
        self.category = category
        self.imageURL = imageURL
        self.isInStock = isInStock
        self.addedDate = Date()
        self.lastChecked = Date()
        self.imageUrls = []
    }
}

// MARK: - Product Specification Model

@Model

final class ProductSpecification {
    var name: String      // Specification name (e.g., "Screen Size", "Material")
    var value: String     // Specification value (e.g., "6.7 inches", "Cotton")
    
    // Relationship to parent
    @Relationship(inverse: \ProductItem.specifications) var product: ProductItem?
    
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
    @Relationship(inverse: \ProductItem.specifications) var product: ProductItem?
    
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
            ProductItem.self,
            ProductSpecification.self,
            ProductVariant.self
        ]))
        return schema
    }
}
