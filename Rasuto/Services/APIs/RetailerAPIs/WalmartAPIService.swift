//
//  WalmartAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/23/25.
//

import Foundation
import Combine
import SwiftData

// Walmart API Response Models
struct WalmartSearchResponse: Decodable {
    let items: [WalmartProduct]
    let totalResults: Int
    let nextPage: String?
}

struct WalmartProduct: Decodable {
    let itemId: Int
    let name: String
    let salePrice: Double
    let msrp: Double?
    let shortDescription: String?
    let longDescription: String?
    let thumbnailImage: String
    let largeImage: String?
    let brandName: String?
    let stock: String
    let categoryPath: String
    let customerRating: Double?
    let numReviews: Int?
    let itemAttributes: [WalmartAttribute]?
    let productUrl: String
    let addToCartUrl: String?
    
    struct WalmartAttribute: Decodable {
        let name: String
        let value: String
    }
}

class WalmartAPIService: BaseAPIService, RetailerAPIService {
    private let apiKey: String
    private let baseURL = "https://api.walmartlabs.com/v1"
    
    // Rate limiting constants
    private let dailyRequestLimit = 5000
    
    // API service name for keychain storage
    static let serviceName = "WalmartAPI"
    
    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }
    
    convenience init() throws {
        let apiKey = try APIKeyManager.shared.getAPIKey(for: WalmartAPIService.serviceName)
        self.init(apiKey: apiKey)
    }
    
    // MARK: - API Methods
    
    func searchProducts(query: String) -> AnyPublisher<[ProductItem], Error> {
        var urlComponents = URLComponents(string: "\(baseURL)/search")
        
        // Clean up query for URL
        let sanitizedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "query", value: sanitizedQuery),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "numItems", value: "25")
        ]
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetch(url)
            .map { (response: WalmartSearchResponse) -> [ProductItem] in
                return response.items.map { self.mapToProductItem($0) }
            }
            .eraseToAnyPublisher()
    }
    
    func getProductDetails(id: String) -> AnyPublisher<ProductItem, Error> {
        var urlComponents = URLComponents(string: "\(baseURL)/items/\(id)")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetch(url)
            .map { (product: WalmartProduct) -> ProductItem in
                return self.mapToProductItem(product)
            }
            .eraseToAnyPublisher()
    }
    
    func getRelatedProducts(id: String) -> AnyPublisher<[ProductItem], Error> {
        var urlComponents = URLComponents(string: "\(baseURL)/nbp")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "itemId", value: id),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return fetch(url)
            .map { (response: WalmartSearchResponse) -> [ProductItem] in
                return response.items.map { self.mapToProductItem($0) }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func mapToProductItem(_ walmartProduct: WalmartProduct) -> ProductItem {
        // Create the main product item
        let product = ProductItem(
            name: walmartProduct.name,
            productDescription: walmartProduct.longDescription ?? walmartProduct.shortDescription ?? "",
            price: walmartProduct.salePrice,
            currency: "USD",
            url: URL(string: walmartProduct.productUrl),
            brand: walmartProduct.brandName ?? "Unknown",
            source: "Walmart",
            sourceId: String(walmartProduct.itemId),
            category: getCategory(from: walmartProduct.categoryPath),
            imageURL: URL(string: walmartProduct.largeImage ?? walmartProduct.thumbnailImage),
            isInStock: isProductInStock(stock: walmartProduct.stock)
        )
        
        // Set original price if available
        if let msrp = walmartProduct.msrp, msrp > walmartProduct.salePrice {
            product.originalPrice = msrp
        }
        
        // Set thumbnail URL
        product.thumbnailUrl = walmartProduct.thumbnailImage
        
        // Add image URLs
        product.imageUrls = []
        if !walmartProduct.thumbnailImage.isEmpty {
            product.imageUrls.append(walmartProduct.thumbnailImage)
        }
        if let largeImage = walmartProduct.largeImage, !largeImage.isEmpty {
            product.imageUrls.append(largeImage)
        }
        
        // Set rating and review count
        product.rating = walmartProduct.customerRating
        product.reviewCount = walmartProduct.numReviews
        
        // Set stock availability text
        product.availability = walmartProduct.stock
        
        // Create and assign specifications
        var specs: [ProductSpecification] = []
        walmartProduct.itemAttributes?.forEach { attribute in
            let spec = ProductSpecification(name: attribute.name, value: attribute.value)
            spec.product = product
            specs.append(spec)
        }
        product.specifications = specs
        
        return product
    }
    
    // Helper to determine if product is in stock
    private func isProductInStock(stock: String) -> Bool {
        switch stock.lowercased() {
        case "available", "in stock":
            return true
        case "limited":
            return true
        case "not available", "out of stock":
            return false
        default:
            return false
        }
    }
    
    // Helper to extract category name from path
    private func getCategory(from categoryPath: String) -> String {
        let categories = categoryPath.components(separatedBy: "/")
        let mainCategory = categories.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Uncategorized"
        let subCategory = categories.last?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return mainCategory
    }
}
