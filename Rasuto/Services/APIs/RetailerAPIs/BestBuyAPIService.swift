//
//  BestBuyAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/23/25.
//

import Foundation
import Combine
import SwiftData

// Best Buy API Response Models
struct BestBuyProductsResponse: Decodable {
    let from: Int
    let to: Int
    let total: Int
    let currentPage: Int
    let totalPages: Int
    let products: [BestBuyProduct]
}

struct BestBuyProduct: Decodable {
    let sku: String
    let name: String
    let regularPrice: Double
    let salePrice: Double
    let inStoreAvailability: Bool
    let onlineAvailability: Bool
    let thumbnailImage: String
    let largeImage: String?
    let manufacturer: String
    let modelNumber: String?
    let longDescription: String
    let longDescriptionHTML: String?
    let customerReviewAverage: Double?
    let customerReviewCount: Int?
    let categoryPath: [String]?
    let url: String
    let features: [BestBuyFeature]?
    let details: [BestBuyDetail]?
    
    struct BestBuyFeature: Decodable {
        let feature: String
    }
    
    struct BestBuyDetail: Decodable {
        let name: String
        let value: String
    }
}

class BestBuyAPIService: BaseAPIService, RetailerAPIService {
    private let apiKey: String
    private let baseURL = "https://api.bestbuy.com/v1"
    
    // Rate limiting constants
    private let requestsPerSecond = 5
    private let dailyRequestLimit = 50000
    
    // API service name for keychain storage
    static let serviceName = "BestBuyAPI"
    
    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }
    
    convenience init() throws {
        let apiKey = try APIKeyManager.shared.getAPIKey(for: BestBuyAPIService.serviceName)
        self.init(apiKey: apiKey)
    }
    
    // MARK: - API Methods
    
    func searchProducts(query: String) -> AnyPublisher<[ProductItem], Error> {
        var urlComponents = URLComponents(string: "\(baseURL)/products")
        
        // Clean up query for URL
        let sanitizedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "pageSize", value: "20"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sort", value: "bestSellingRank.asc"),
            URLQueryItem(name: "show", value: "sku,name,regularPrice,salePrice,inStoreAvailability,onlineAvailability,thumbnailImage,largeImage,manufacturer,modelNumber,longDescription,customerReviewAverage,customerReviewCount,categoryPath,url,features.feature,details"),
            URLQueryItem(name: "nameSearch", value: sanitizedQuery)
        ]
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetch(url)
            .map { (response: BestBuyProductsResponse) -> [ProductItem] in
                return response.products.map { self.mapToProductItem($0) }
            }
            .eraseToAnyPublisher()
    }
    
    func getProductDetails(id: String) -> AnyPublisher<ProductItem, Error> {
        var urlComponents = URLComponents(string: "\(baseURL)/products/\(id)")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "show", value: "sku,name,regularPrice,salePrice,inStoreAvailability,onlineAvailability,thumbnailImage,largeImage,manufacturer,modelNumber,longDescription,customerReviewAverage,customerReviewCount,categoryPath,url,features.feature,details")
        ]
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetch(url)
            .map { (product: BestBuyProduct) -> ProductItem in
                return self.mapToProductItem(product)
            }
            .eraseToAnyPublisher()
    }
    
    func getRelatedProducts(id: String) -> AnyPublisher<[ProductItem], Error> {
        var urlComponents = URLComponents(string: "\(baseURL)/products/\(id)/alsoViewed")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetch(url)
            .map { (response: BestBuyProductsResponse) -> [ProductItem] in
                return response.products.map { self.mapToProductItem($0) }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func mapToProductItem(_ bestBuyProduct: BestBuyProduct) -> ProductItem {
        // Create the main product item
        let product = ProductItem(
            name: bestBuyProduct.name,
            productDescription: bestBuyProduct.longDescription,
            price: bestBuyProduct.salePrice,
            currency: "USD",
            url: URL(string: bestBuyProduct.url),
            brand: bestBuyProduct.manufacturer,
            source: "Best Buy",
            sourceId: bestBuyProduct.sku,
            category: bestBuyProduct.categoryPath?.last ?? "Uncategorized",
            imageURL: URL(string: bestBuyProduct.largeImage ?? bestBuyProduct.thumbnailImage),
            isInStock: bestBuyProduct.onlineAvailability || bestBuyProduct.inStoreAvailability
        )
        
        // Set original price if different
        if bestBuyProduct.regularPrice > bestBuyProduct.salePrice {
            product.originalPrice = bestBuyProduct.regularPrice
        }
        
        // Set thumbnail URL
        product.thumbnailUrl = bestBuyProduct.thumbnailImage
        
        // Add image URLs
        product.imageUrls = []
        if !bestBuyProduct.thumbnailImage.isEmpty {
            product.imageUrls.append(bestBuyProduct.thumbnailImage)
        }
        if let largeImage = bestBuyProduct.largeImage, !largeImage.isEmpty {
            product.imageUrls.append(largeImage)
        }
        
        // Set ratings
        product.rating = bestBuyProduct.customerReviewAverage
        product.reviewCount = bestBuyProduct.customerReviewCount
        
        // Create and assign specifications
        var specs: [ProductSpecification] = []
        bestBuyProduct.details?.forEach { detail in
            let spec = ProductSpecification(name: detail.name, value: detail.value)
            spec.product = product
            specs.append(spec)
        }
        product.specifications = specs
        
        // Add features as specifications if available
        bestBuyProduct.features?.enumerated().forEach { index, feature in
            let spec = ProductSpecification(name: "Feature \(index + 1)", value: feature.feature)
            spec.product = product
            specs.append(spec)
        }
        
        return product
    }
}
