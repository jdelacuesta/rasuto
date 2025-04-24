//
//  EbayAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/23/25.
//

import Foundation
import Combine
import SwiftData

// eBay API Response Models
struct EBaySearchResponse: Decodable {
    let itemSummaries: [EBayItem]
    let total: Int
    let limit: Int
    let offset: Int
    let href: String
    let next: String?
}

struct EBayItem: Decodable {
    let itemId: String
    let title: String
    let description: String?
    let price: EBayPrice
    let thumbnailImages: [EBayImage]?
    let image: EBayImage?
    let seller: EBaySeller?
    let condition: String?
    let conditionId: String?
    let itemWebUrl: String
    let brand: String?
    let categories: [EBayCategory]?
    let shippingOptions: [EBayShipping]?
    let availableCoupons: Bool?
    let itemLocation: EBayLocation?
    let buyingOptions: [String]?
    
    struct EBayPrice: Decodable {
        let value: String
        let currency: String
        
        var numericValue: Double {
            return Double(value) ?? 0.0
        }
    }
    
    struct EBayImage: Decodable {
        let imageUrl: String
    }
    
    struct EBaySeller: Decodable {
        let username: String
        let feedbackScore: Int?
        let feedbackPercentage: String?
    }
    
    struct EBayCategory: Decodable {
        let categoryId: String
        let categoryName: String
    }
    
    struct EBayShipping: Decodable {
        let shippingCost: EBayPrice?
        let shippingCostType: String?
        let type: String?
    }
    
    struct EBayLocation: Decodable {
        let city: String?
        let stateOrProvince: String?
        let country: String?
        let postalCode: String?
    }
}

class EBayAPIService: BaseAPIService, RetailerAPIService {
    private let apiKey: String
    private let baseURL = "https://api.ebay.com/buy/browse/v1"
    
    // API service name for keychain storage
    static let serviceName = "EBayAPI"
    
    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }
    
    convenience init() throws {
        let apiKey = try APIConfig.getAPIKey(for: APIConfig.Service.ebay)
        self.init(apiKey: apiKey)
    }
    
    // MARK: - RetailerAPIService Protocol Implementation
    
    func searchProducts(query: String) -> AnyPublisher<[ProductItem], Error> {
        // Placeholder implementation - in a real app, this would call the eBay API
        // For now, just return an empty array to satisfy the protocol
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getProductDetails(id: String) -> AnyPublisher<ProductItem, Error> {
        // Placeholder implementation that returns a dummy product
        let dummyProduct = ProductItem(
            name: "Sample eBay Product",
            productDescription: "This is a placeholder for eBay API integration",
            price: 99.99,
            currency: "USD",
            url: URL(string: "https://www.ebay.com"),
            brand: "Sample Brand",
            source: "eBay",
            sourceId: id,
            category: "Electronics",
            isInStock: true
        )
        
        return Just(dummyProduct)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRelatedProducts(id: String) -> AnyPublisher<[ProductItem], Error> {
        // Placeholder implementation
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func mapToProductItem(_ ebayItem: EBayItem) -> ProductItem {
        // Create the main product item
        let product = ProductItem(
            name: ebayItem.title,
            productDescription: ebayItem.description ?? "",
            price: ebayItem.price.numericValue,
            currency: ebayItem.price.currency,
            url: URL(string: ebayItem.itemWebUrl),
            brand: ebayItem.brand ?? "Unknown",
            source: "eBay",
            sourceId: ebayItem.itemId,
            category: ebayItem.categories?.first?.categoryName ?? "Uncategorized",
            imageURL: getImageURL(from: ebayItem),
            isInStock: true // eBay listings are typically in stock
        )
        
        // Set image URLs
        product.imageUrls = getImageURLStrings(from: ebayItem)
        
        // Set thumbnail URL if available
        if let firstImage = ebayItem.thumbnailImages?.first {
            product.thumbnailUrl = firstImage.imageUrl
        } else if let mainImage = ebayItem.image {
            product.thumbnailUrl = mainImage.imageUrl
        }
        
        // Create specifications
        var specs: [ProductSpecification] = []
        
        // Add condition as a specification
        if let condition = ebayItem.condition {
            let spec = ProductSpecification(name: "Condition", value: condition)
            spec.product = product
            specs.append(spec)
        }
        
        product.specifications = specs
        
        return product
    }
    
    private func getImageURL(from item: EBayItem) -> URL? {
        // Try to get the main image
        if let mainImage = item.image {
            return URL(string: mainImage.imageUrl)
        }
        
        // Fall back to the first thumbnail
        if let firstThumbnail = item.thumbnailImages?.first {
            return URL(string: firstThumbnail.imageUrl)
        }
        
        return nil
    }
    
    private func getImageURLStrings(from item: EBayItem) -> [String] {
        var urls: [String] = []
        
        // Add main image if available
        if let mainImage = item.image {
            urls.append(mainImage.imageUrl)
        }
        
        // Add thumbnail images
        if let thumbnails = item.thumbnailImages {
            urls.append(contentsOf: thumbnails.map { $0.imageUrl })
        }
        
        return urls
    }
}
