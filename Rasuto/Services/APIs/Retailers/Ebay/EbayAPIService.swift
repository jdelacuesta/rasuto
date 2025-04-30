//
//  EbayAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/28/25.
//

import Foundation

// eBay API Response Models
struct EbayProductsResponse: Decodable {
    let items: [EbayProduct]
}

struct EbayProduct: Decodable {
    let itemId: String
    let title: String
    let price: Double
    let condition: String
    let galleryURL: String?
    let viewItemURL: String
    let sellerInfo: SellerInfo?
    let categoryName: String?
    let listingType: String?
    let shippingInfo: ShippingInfo?
    
    struct SellerInfo: Decodable {
        let sellerUserName: String
        let feedbackScore: Int
    }
    
    struct ShippingInfo: Decodable {
        let shippingServiceCost: Double?
    }
}

class EbayAPIService: RetailerAPIService {
    private let apiKey: String
    private let baseURL = "https://api.ebay.com/buy/browse/v1"
    
    // Rate limiting constants
    private let requestsPerSecond = 20
    private let dailyRequestLimit = 5000
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Mock Data
    
    private let mockProducts = [
        ProductItemDTO(
            sourceId: "v1|12345|0",
            name: "Apple Watch Series 9 GPS 45mm Midnight Aluminum Case",
            productDescription: "Latest model, powerful S9 chip, Always-On Retina display.",
            price: 399.00,
            currency: "USD",
            imageURL: URL(string: "https://i.ebayimg.com/images/g/12345.jpg"),
            imageUrls: [
                "https://i.ebayimg.com/images/g/12345.jpg"
            ],
            thumbnailUrl: "https://i.ebayimg.com/images/g/12345.jpg",
            brand: "Apple",
            source: "eBay",
            category: "Smart Watches",
            isInStock: true,
            rating: 4.6,
            reviewCount: 654
        ),
        ProductItemDTO(
            sourceId: "v1|67890|0",
            name: "Nikon Z6 II FX-Format Mirrorless Camera Body",
            productDescription: "24.5MP BSI sensor, dual EXPEED 6 processors, 4K UHD video recording.",
            price: 1599.99,
            currency: "USD",
            imageURL: URL(string: "https://i.ebayimg.com/images/g/67890.jpg"),
            imageUrls: [
                "https://i.ebayimg.com/images/g/67890.jpg"
            ],
            thumbnailUrl: "https://i.ebayimg.com/images/g/67890.jpg",
            brand: "Nikon",
            source: "eBay",
            category: "Digital Cameras",
            isInStock: true,
            rating: 4.8,
            reviewCount: 290
        )
    ]
    
    // MARK: - API Methods
    
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        try await Task.sleep(nanoseconds: 500_000_000)
        
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
        var urlComponents = URLComponents(string: "\(baseURL)/item_summary/search")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "20")
        ]
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let ebayResponse = try decoder.decode(EbayProductsResponse.self, from: data)
            return ebayResponse.items.map { mapToProductItem($0) }
        default:
            throw APIError.invalidResponse
        }
    }
    */
    
    private func mapToProductItem(_ ebayProduct: EbayProduct) -> ProductItemDTO {
        return ProductItemDTO(
            sourceId: ebayProduct.itemId,
            name: ebayProduct.title,
            productDescription: ebayProduct.condition,
            price: ebayProduct.price,
            currency: "USD",
            imageURL: URL(string: ebayProduct.galleryURL ?? ""),
            imageUrls: ebayProduct.galleryURL != nil ? [ebayProduct.galleryURL!] : [],
            thumbnailUrl: ebayProduct.galleryURL,
            brand: ebayProduct.sellerInfo?.sellerUserName ?? "Unknown",
            source: "eBay",
            category: ebayProduct.categoryName ?? "Uncategorized",
            isInStock: ebayProduct.shippingInfo?.shippingServiceCost == 0,
            rating: 0.0,
            reviewCount: ebayProduct.sellerInfo?.feedbackScore ?? 0
        )
    }
}
