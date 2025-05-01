//
//  WalmartAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/28/25.
//

import Foundation

// Walmart API Response Models
struct WalmartProductsResponse: Decodable {
    let items: [WalmartProduct]
}

struct WalmartProduct: Decodable {
    let itemId: Int
    let name: String
    let salePrice: Double?
    let msrp: Double?
    let stock: String
    let thumbnailImage: String?
    let mediumImage: String?
    let brandName: String?
    let longDescription: String?
    let customerRating: String?
    let numReviews: Int?
    let categoryPath: String?
    let productUrl: String
}

class WalmartAPIService: RetailerAPIService {
    private let apiKey: String
    private let baseURL = "https://api.walmartlabs.com/v1"
    
    // Rate limiting constants
    private let requestsPerSecond = 10
    private let dailyRequestLimit = 5000
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Mock Data
    
    private let mockProducts = [
        ProductItemDTO(
            sourceId: "12345678",
            name: "Apple AirPods Pro (2nd Generation)",
            productDescription: "Active noise cancellation, Adaptive Transparency, Personalized Spatial Audio.",
            price: 199.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/asr/12345.png"),
            imageUrls: [
                "https://i5.walmartimages.com/asr/12345.png"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/asr/12345.png",
            brand: "Apple",
            source: "Walmart",
            category: "Electronics",
            isInStock: true,
            rating: 4.7,
            reviewCount: 3215
        ),
        ProductItemDTO(
            sourceId: "87654321",
            name: "Samsung - 65\" Class 4K Crystal UHD Smart TV",
            productDescription: "Ultra-fast Crystal Processor 4K, PurColor, and HDR for a stunning 4K experience.",
            price: 497.99,
            currency: "USD",
            imageURL: URL(string: "https://i5.walmartimages.com/asr/67890.png"),
            imageUrls: [
                "https://i5.walmartimages.com/asr/67890.png"
            ],
            thumbnailUrl: "https://i5.walmartimages.com/asr/67890.png",
            brand: "Samsung",
            source: "Walmart",
            category: "Televisions",
            isInStock: true,
            rating: 4.5,
            reviewCount: 875
        )
    ]
    
    // MARK: - API Methods
    
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec delay
        
        if !query.isEmpty {
            return mockProducts.filter { product in
                product.name.lowercased().contains(query.lowercased()) ||
                (product.productDescription?.lowercased().contains(query.lowercased()) ?? false) ||
                product.brand.lowercased().contains(query.lowercased())
            }
        }
        return mockProducts
    }
    
    func getProductDetails(id: String) async throws -> ProductItemDTO {
        if let product = mockProducts.first(where: { $0.sourceId == id }) {
            try await Task.sleep(nanoseconds: 300_000_000)
            return product
        }
        throw APIError.noData
    }
    
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
        try await Task.sleep(nanoseconds: 400_000_000)
        
        if let product = mockProducts.first(where: { $0.sourceId == id }) {
            return mockProducts.filter { $0.sourceId != id && $0.category == product.category }
        }
        
        return []
    }
    
    // MARK: - Actual API Implementation (commented out)
    
    /*
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        var urlComponents = URLComponents(string: "\(baseURL)/search")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "query", value: query)
        ]
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let walmartResponse = try decoder.decode(WalmartProductsResponse.self, from: data)
            return walmartResponse.items.map { mapToProductItem($0) }
        default:
            throw APIError.invalidResponse
        }
    }
    */
    
    private func mapToProductItem(_ walmartProduct: WalmartProduct) -> ProductItemDTO {
        let imageUrls = [walmartProduct.thumbnailImage, walmartProduct.mediumImage].compactMap { $0 }
        let isInStock = walmartProduct.stock.lowercased() == "available"
        let rating = Double(walmartProduct.customerRating ?? "0") ?? 0.0
        
        return ProductItemDTO(
            sourceId: String(walmartProduct.itemId),
            name: walmartProduct.name,
            productDescription: walmartProduct.longDescription,
            price: walmartProduct.salePrice ?? walmartProduct.msrp ?? 0.0,
            currency: "USD",
            imageURL: URL(string: walmartProduct.thumbnailImage ?? ""),
            imageUrls: imageUrls,
            thumbnailUrl: walmartProduct.thumbnailImage,
            brand: walmartProduct.brandName ?? "Unknown",
            source: "Walmart",
            category: walmartProduct.categoryPath ?? "Uncategorized",
            isInStock: isInStock,
            rating: rating,
            reviewCount: walmartProduct.numReviews ?? 0
        )
    }
}
