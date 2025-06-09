//
//  RetailerService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import Foundation
import Network

// Protocol that all retailer API services must conform to
protocol RetailerAPIService {
    func searchProducts(query: String) async throws -> [ProductItemDTO]
    func getProductDetails(id: String) async throws -> ProductItemDTO
    func getRelatedProducts(id: String) async throws -> [ProductItemDTO]
}

// Shared API errors - Enhanced for Phase 5
enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case rateLimitExceeded(retryAfter: TimeInterval? = nil)
    case authenticationFailed
    case serverError(Int)
    case noData
    case custom(String)
    case networkUnavailable
    case timeout
    case quotaExceeded
    case malformedRequest(String)
    case serpAPIError(String)
    case axessoError(String)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .rateLimitExceeded(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Try again in \(Int(retry)) seconds"
            }
            return "Rate limit exceeded. Please try again later"
        case .authenticationFailed:
            return "Authentication failed"
        case .serverError(let code):
            return "Server error (\(code))"
        case .noData:
            return "No data received from server"
        case .custom(let message):
            return message
        case .networkUnavailable:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .quotaExceeded:
            return "API quota exceeded for today"
        case .malformedRequest(let details):
            return "Invalid request: \(details)"
        case .serpAPIError(let message):
            return "Google Shopping search failed: \(message)"
        case .axessoError(let message):
            return "Amazon search failed: \(message)"
        case .unknownError(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .timeout:
            return true
        case .serverError(let code):
            return code >= 500 || code == 429
        case .rateLimitExceeded:
            return true
        case .serpAPIError, .axessoError:
            return true
        default:
            return false
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection"
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment"
        case .authenticationFailed:
            return "API authentication issue. Please try again"
        case .quotaExceeded:
            return "Daily search limit reached. Try again tomorrow"
        case .serpAPIError:
            return "Search temporarily unavailable. Please try again"
        case .axessoError:
            return "Amazon search temporarily unavailable"
        default:
            return "Something went wrong. Please try again"
        }
    }
}

// DTO for transferring product data between services and views
struct ProductItemDTO: Identifiable, Codable {
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
    let productUrl: String?
    
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
         isTracked: Bool = false,
         productUrl: String? = nil) {
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
        self.productUrl = productUrl
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
            url: dto.productUrl != nil ? URL(string: dto.productUrl!) : nil,
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
        
        // Set thumbnailUrl with fallback to imageURL
        product.thumbnailUrl = dto.thumbnailUrl ?? dto.imageURL?.absoluteString
        
        // If no thumbnailUrl and no imageUrls, populate imageUrls from imageURL
        if product.thumbnailUrl == nil && product.imageUrls.isEmpty,
           let imageURL = dto.imageURL {
            product.imageUrls = [imageURL.absoluteString]
        }
        
        product.rating = dto.rating
        product.reviewCount = dto.reviewCount
        
        return product
    }
}

extension ProductItemDTO {
    static func from(_ product: ProductItem) -> ProductItemDTO {
        let dto = ProductItemDTO(
            id: product.id,
            sourceId: product.sourceId,
            name: product.name,
            productDescription: product.productDescription,
            price: product.price,
            originalPrice: product.originalPrice,
            currency: product.currency,
            imageURL: product.imageURL,
            imageUrls: product.imageUrls,
            thumbnailUrl: product.thumbnailUrl,
            brand: product.brand,
            source: product.source,
            category: product.category,
            isInStock: product.isInStock,
            rating: product.rating,
            reviewCount: product.reviewCount,
            isFavorite: product.isFavorite,
            isTracked: product.isTracked,
            productUrl: product.productUrl
        )
        
        print("🔄 CONVERTING ProductItem to DTO:")
        print("   - Name: \(dto.name)")
        print("   - Source: \(dto.source)")
        print("   - SourceId: \(dto.sourceId)")
        print("   - ID: \(dto.id)")
        
        return dto
    }
}

// MARK: - Enhanced Error Handling Utilities

// Simple API Logger
class APILogger {
    static let shared = APILogger()
    
    private let isDebugMode: Bool
    
    private init() {
        #if DEBUG
        isDebugMode = true
        #else
        isDebugMode = false
        #endif
    }
    
    func logError(_ error: APIError, context: String, apiType: String = "Generic") {
        guard isDebugMode else { return }
        
        print("💥 \(apiType.uppercased()) ERROR in \(context)")
        print("Type: \(error)")
        print("Description: \(error.localizedDescription ?? "No description")")
        print("User Message: \(error.userFriendlyMessage)")
        print("Retryable: \(error.isRetryable)")
        print("---")
    }
}

// Input Sanitizer
class InputSanitizer {
    static let shared = InputSanitizer()
    
    private init() {}
    
    func sanitizeSearchQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove potentially harmful characters
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
            .subtracting(CharacterSet(charactersIn: "<>{}[]|\\"))
        
        let filtered = String(trimmed.unicodeScalars.filter { allowedCharacterSet.contains($0) })
        
        // Limit length
        let maxLength = 200
        let limited = filtered.count > maxLength ? String(filtered.prefix(maxLength)) : filtered
        
        return limited
    }
    
    func validateSearchQuery(_ query: String) throws {
        let sanitized = sanitizeSearchQuery(query)
        
        guard !sanitized.isEmpty else {
            throw APIError.malformedRequest("Search query cannot be empty")
        }
        
        guard sanitized.count >= 2 else {
            throw APIError.malformedRequest("Search query must be at least 2 characters")
        }
    }
}
