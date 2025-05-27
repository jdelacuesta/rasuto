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

// MARK: - Computed Properties

extension ProductItem {
    var currentPrice: Double {
        return price ?? 0.0
    }
    
    var store: String {
        return source
    }
    
    var imageUrl: String {
        if let thumbnailUrl = thumbnailUrl {
            return thumbnailUrl
        }
        if let firstImage = imageUrls.first {
            return firstImage
        }
        return ""
    }
    
    var productUrl: String? {
        return url?.absoluteString
    }
    
    var description: String? {
        return productDescription
    }
    
    // String ID for API compatibility
    var idString: String {
        return self.id.uuidString
    }
}

// MARK: - Sample Data

extension ProductItem {
    static var sampleItem: ProductItem {
        let item = ProductItem(
            name: "Apple AirPods Pro (2nd Generation)",
            productDescription: "Active Noise Cancelling, Personalized Spatial Audio",
            price: 199.99,
            currency: "USD",
            url: URL(string: "https://www.bestbuy.com/airpods-pro"),
            brand: "Apple",
            source: "BestBuy",
            sourceId: "6447382",
            category: "Electronics",
            isInStock: true
        )
        item.originalPrice = 249.99
        item.rating = 4.8
        item.reviewCount = 12453
        item.thumbnailUrl = "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6447/6447382_sd.jpg"
        item.isFavorite = true
        item.isTracked = false
        return item
    }
    
    static var sampleItem2: ProductItem {
        let item = ProductItem(
            name: "Sony WH-1000XM5 Wireless Headphones",
            productDescription: "Industry Leading Noise Canceling with Auto Noise Canceling Optimizer",
            price: 329.99,
            currency: "USD",
            url: URL(string: "https://www.ebay.com/sony-headphones"),
            brand: "Sony",
            source: "eBay",
            sourceId: "394856273",
            category: "Electronics",
            isInStock: true
        )
        item.originalPrice = 399.99
        item.rating = 4.6
        item.reviewCount = 8934
        item.thumbnailUrl = "https://i.ebayimg.com/images/g/~48AAOSw2gNimNX3/s-l1600.jpg"
        item.isFavorite = false
        item.isTracked = true
        return item
    }
    
    static var sampleItems: [ProductItem] {
        return [
            sampleItem,
            sampleItem2,
            ProductItem(
                name: "Nintendo Switch OLED Model",
                productDescription: "7-inch OLED screen, 64 GB internal storage",
                price: 299.99,
                currency: "USD",
                url: URL(string: "https://www.bestbuy.com/nintendo-switch"),
                brand: "Nintendo",
                source: "BestBuy",
                sourceId: "6470923",
                category: "Gaming",
                isInStock: true
            ),
            ProductItem(
                name: "Apple Watch Series 9",
                productDescription: "GPS, 41mm Midnight Aluminum Case",
                price: 379.99,
                currency: "USD",
                url: URL(string: "https://www.ebay.com/apple-watch"),
                brand: "Apple", 
                source: "eBay",
                sourceId: "295847362",
                category: "Wearables",
                isInStock: false
            ),
            ProductItem(
                name: "Samsung 65\" OLED 4K Smart TV",
                productDescription: "Quantum HDR OLED, Object Tracking Sound+",
                price: 1799.99,
                currency: "USD",
                url: URL(string: "https://www.bestbuy.com/samsung-tv"),
                brand: "Samsung",
                source: "BestBuy",
                sourceId: "6525093",
                category: "TV & Home Theater",
                isInStock: true
            )
        ].map { item in
            // Add thumbnails to items that don't have them
            if item.thumbnailUrl == nil {
                switch item.category {
                case "Gaming":
                    item.thumbnailUrl = "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6470/6470923_sd.jpg"
                case "Wearables":
                    item.thumbnailUrl = "https://i.ebayimg.com/images/g/Kz4AAOSwjVVlFu~6/s-l1600.jpg"
                case "TV & Home Theater":
                    item.thumbnailUrl = "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6525/6525093_sd.jpg"
                default:
                    item.thumbnailUrl = ""
                }
            }
            item.originalPrice = item.price! * 1.2
            item.rating = Double.random(in: 4.0...5.0)
            item.reviewCount = Int.random(in: 100...10000)
            return item
        }
    }
}
