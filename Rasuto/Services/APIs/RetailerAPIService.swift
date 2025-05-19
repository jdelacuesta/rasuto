//
//  RetailerService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import Foundation

// Protocol that all retailer API services must conform to
protocol RetailerAPIService {
    func searchProducts(query: String) async throws -> [ProductItemDTO]
    func getProductDetails(id: String) async throws -> ProductItemDTO
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO]
}

// Shared API errors
enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case rateLimitExceeded
    case authenticationFailed
    case serverError(Int)
    case noData
    case custom(String)
}

// DTO for transferring product data between services and views
struct ProductItemDTO: Identifiable {
    let id: UUID
    let sourceId: String
    let name: String
    let productDescription: String?
    let price: Double?
    let originalPrice: Double?
    let currency: String?
    let imageURL: URL?
    let imageUrls: [String]?
    let thumbnailUrl: String?
    let brand: String
    let source: String
    let category: String?
    let isInStock: Bool
    let rating: Double?
    let reviewCount: Int?
    let isFavorite: Bool
    let isTracked: Bool
    
    init(id: UUID = UUID(),
         sourceId: String,
         name: String,
         productDescription: String? = nil,
         price: Double? = nil,
         originalPrice: Double? = nil,
         currency: String? = "USD",
         imageURL: URL? = nil,
         imageUrls: [String]? = nil,
         thumbnailUrl: String? = nil,
         brand: String,
         source: String,
         category: String? = nil,
         isInStock: Bool = true,
         rating: Double? = nil,
         reviewCount: Int? = nil,
         isFavorite: Bool = false,
         isTracked: Bool = false) {
        self.id = id
        self.sourceId = sourceId
        self.name = name
        self.productDescription = productDescription
        self.price = price
        self.originalPrice = originalPrice
        self.currency = currency
        self.imageURL = imageURL
        self.imageUrls = imageUrls
        self.thumbnailUrl = thumbnailUrl
        self.brand = brand
        self.source = source
        self.category = category
        self.isInStock = isInStock
        self.rating = rating
        self.reviewCount = reviewCount
        self.isFavorite = isFavorite
        self.isTracked = isTracked
    }
}

// Extension to convert between ProductItem and ProductItemDTO
extension ProductItem {
    func toDTO() -> ProductItemDTO {
        return ProductItemDTO(
            id: id,
            sourceId: sourceId,
            name: name,
            productDescription: productDescription,
            price: price,
            originalPrice: originalPrice,
            currency: currency,
            imageURL: imageURL,
            imageUrls: imageUrls,
            thumbnailUrl: thumbnailUrl,
            brand: brand,
            source: source,
            category: category,
            isInStock: isInStock,
            rating: rating,
            reviewCount: reviewCount,
            isFavorite: isFavorite,
            isTracked: isTracked
        )
    }
    
    static func from(_ dto: ProductItemDTO) -> ProductItem {
        let product = ProductItem(
            name: dto.name,
            productDescription: dto.productDescription ?? "",
            price: dto.price,
            currency: dto.currency,
            url: nil,
            brand: dto.brand,
            source: dto.source,
            sourceId: dto.sourceId,
            category: dto.category ?? "",
            imageURL: dto.imageURL,
            isInStock: dto.isInStock
        )
        
        // Set additional properties
        product.id = dto.id
        product.originalPrice = dto.originalPrice
        product.isFavorite = dto.isFavorite
        product.isTracked = dto.isTracked
        
        if let imageUrls = dto.imageUrls {
            product.imageUrls = imageUrls
        }
        
        product.thumbnailUrl = dto.thumbnailUrl
        product.rating = dto.rating
        product.reviewCount = dto.reviewCount
        
        return product
    }
}

