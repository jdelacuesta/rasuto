//
//  BestBuyAPIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/28/25.
//

import Foundation

// BestBuy API Response Models
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
    
    struct BestBuyFeature: Decodable {
        let feature: String
    }
    
    struct BestBuyDetail: Decodable {
        let name: String
        let value: String
    }
}

class BestBuyAPIService: RetailerAPIService {
    private let apiKey: String
    private let baseURL = "https://api.bestbuy.com/v1"
    
    // Rate limiting constants
    private let requestsPerSecond = 5
    private let dailyRequestLimit = 50000
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Mock Data
    
    private let mockProducts = [
        ProductItemDTO(
            sourceId: "6509928",
            name: "Apple - iPhone 15 Pro 128GB - Natural Titanium",
            productDescription: "iPhone 15 Pro. Titanium with a brushed finish. USB-C. A17 Pro chip. Action button. 48MP camera.",
            price: 999.99,
            currency: "USD",
            imageURL: URL(string: "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6509/6509928_sd.jpg"),
            imageUrls: [
                "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6509/6509928_sd.jpg"
            ],
            thumbnailUrl: "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6509/6509928_sd.jpg",
            brand: "Apple",
            source: "Best Buy",
            category: "Cell Phones",
            isInStock: true,
            rating: 4.8,
            reviewCount: 243
        ),
        ProductItemDTO(
            sourceId: "6538111",
            name: "Sony - Alpha a7 IV Full-frame Mirrorless Camera",
            productDescription: "33MP full-frame Exmor R CMOS sensor, 4K 60p video recording, 5-axis in-body image stabilization.",
            price: 2499.99,
            currency: "USD",
            imageURL: URL(string: "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6538/6538111_sd.jpg"),
            imageUrls: [
                "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6538/6538111_sd.jpg"
            ],
            thumbnailUrl: "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6538/6538111_sd.jpg",
            brand: "Sony",
            source: "Best Buy",
            category: "Digital Cameras",
            isInStock: true,
            rating: 4.9,
            reviewCount: 127
        )
    ]
    
    // MARK: - API Methods
    
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        // Note: When you have your API key, replace this with the actual implementation
        
        // Placeholder: Return mock data with a delay to simulate network call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Filter mock products based on query
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
        // Placeholder: Return mock data based on id
        if let product = mockProducts.first(where: { $0.sourceId == id }) {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
            return product
        }
        
        throw APIError.noData
    }
    
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
        // Placeholder: Return other mock products
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 second delay
        
        if let product = mockProducts.first(where: { $0.sourceId == id }) {
            // Return other products from the same category
            return mockProducts.filter { $0.sourceId != id && $0.category == product.category }
        }
        
        return []
    }
    
    // MARK: - Actual API implementation (commented out for now)
    
    /*
    func searchProducts(query: String) async throws -> [ProductItemDTO] {
        var urlComponents = URLComponents(string: "\(baseURL)/products")
        
        // Clean up query for URL
        let sanitizedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "pageSize", value: "20"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sort", value: "bestSellingRank.asc"),
            URLQueryItem(name: "show", value: "sku,name,regularPrice,salePrice,inStoreAvailability,onlineAvailability,thumbnailImage,largeImage,manufacturer,modelNumber,longDescription,customerReviewAverage,customerReviewCount,categoryPath,url"),
            URLQueryItem(name: "nameSearch", value: sanitizedQuery)
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
            do {
                let bestBuyResponse = try decoder.decode(BestBuyProductsResponse.self, from: data)
                return bestBuyResponse.products.map { mapToProductItem($0) }
            } catch {
                throw APIError.decodingFailed(error)
            }
        case 401, 403:
            throw APIError.authenticationFailed
        case 429:
            throw APIError.rateLimitExceeded
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.invalidResponse
        }
    }
    
    func getProductDetails(id: String) async throws -> ProductItemDTO {
        var urlComponents = URLComponents(string: "\(baseURL)/products/\(id)")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "format", value: "json")
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
            do {
                let product = try decoder.decode(BestBuyProduct.self, from: data)
                return mapToProductItem(product)
            } catch {
                throw APIError.decodingFailed(error)
            }
        case 401, 403:
            throw APIError.authenticationFailed
        case 429:
            throw APIError.rateLimitExceeded
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.invalidResponse
        }
    }
    
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
        var urlComponents = URLComponents(string: "\(baseURL)/products/\(id)/also-viewed")
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "format", value: "json")
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
            do {
                let bestBuyResponse = try decoder.decode(BestBuyProductsResponse.self, from: data)
                return bestBuyResponse.products.map { mapToProductItem($0) }
            } catch {
                throw APIError.decodingFailed(error)
            }
        case 401, 403:
            throw APIError.authenticationFailed
        case 429:
            throw APIError.rateLimitExceeded
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.invalidResponse
        }
    }
    
    private func mapToProductItem(_ bestBuyProduct: BestBuyProduct) -> ProductItemDTO {
        // Create image URLs array
        var imageUrls: [String] = []
        if !bestBuyProduct.thumbnailImage.isEmpty {
            imageUrls.append(bestBuyProduct.thumbnailImage)
        }
        if let largeImage = bestBuyProduct.largeImage, !largeImage.isEmpty {
            imageUrls.append(largeImage)
        }
        
        // Determine stock status
        let isInStock = bestBuyProduct.onlineAvailability || bestBuyProduct.inStoreAvailability
        
        // Extract category
        let category = bestBuyProduct.categoryPath?.last ?? "Uncategorized"
        
        return ProductItemDTO(
            sourceId: bestBuyProduct.sku,
            name: bestBuyProduct.name,
            productDescription: bestBuyProduct.longDescription,
            price: bestBuyProduct.salePrice,
            originalPrice: bestBuyProduct.regularPrice > bestBuyProduct.salePrice ? bestBuyProduct.regularPrice : nil,
            currency: "USD",
            imageURL: URL(string: bestBuyProduct.largeImage ?? bestBuyProduct.thumbnailImage),
            imageUrls: imageUrls,
            thumbnailUrl: bestBuyProduct.thumbnailImage,
            brand: bestBuyProduct.manufacturer,
            source: "Best Buy",
            category: category,
            isInStock: isInStock,
            rating: bestBuyProduct.customerReviewAverage,
            reviewCount: bestBuyProduct.customerReviewCount
        )
    }
    */
}
