//
//  OxylabsScraperModels.swift
//  Rasuto
//
//  Created for Oxylabs Web Scraper API integration on 6/4/25.
//

import Foundation

// MARK: - Oxylabs Request Models

struct OxylabsScraperRequest: Codable {
    let source: String
    let url: String
    let location: String?
    let parseInstructions: ParseInstructions?
    let context: [ContextParameter]?
    
    private enum CodingKeys: String, CodingKey {
        case source, url, location
        case parseInstructions = "parse_instructions"
        case context
    }
    
    // Convenience initializers for different e-commerce platforms
    static func amazon(searchQuery: String, location: String = "United States") -> OxylabsScraperRequest {
        let amazonURL = "https://www.amazon.com/s?k=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return OxylabsScraperRequest(
            source: "amazon_search",
            url: amazonURL,
            location: location,
            parseInstructions: .ecommerce,
            context: [
                ContextParameter(key: "autoparse", value: "true"),
                ContextParameter(key: "results_language", value: "en")
            ]
        )
    }
    
    static func walmart(searchQuery: String, location: String = "United States") -> OxylabsScraperRequest {
        let walmartURL = "https://www.walmart.com/search?q=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return OxylabsScraperRequest(
            source: "universal_ecommerce",
            url: walmartURL,
            location: location,
            parseInstructions: .ecommerce,
            context: [
                ContextParameter(key: "autoparse", value: "true"),
                ContextParameter(key: "results_language", value: "en")
            ]
        )
    }
    
    static func target(searchQuery: String, location: String = "United States") -> OxylabsScraperRequest {
        let targetURL = "https://www.target.com/s?searchTerm=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return OxylabsScraperRequest(
            source: "universal_ecommerce",
            url: targetURL,
            location: location,
            parseInstructions: .ecommerce,
            context: [
                ContextParameter(key: "autoparse", value: "true"),
                ContextParameter(key: "results_language", value: "en")
            ]
        )
    }
    
    static func homedepot(searchQuery: String, location: String = "United States") -> OxylabsScraperRequest {
        let homedepotURL = "https://www.homedepot.com/s/\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return OxylabsScraperRequest(
            source: "universal_ecommerce",
            url: homedepotURL,
            location: location,
            parseInstructions: .ecommerce,
            context: [
                ContextParameter(key: "autoparse", value: "true"),
                ContextParameter(key: "results_language", value: "en")
            ]
        )
    }
}

struct ParseInstructions: Codable {
    let products: ProductParseConfig
    
    static let ecommerce = ParseInstructions(
        products: ProductParseConfig(
            _fns: [
                ParseFunction(name: "_parse_product", args: ProductParseArgs())
            ],
            _items: [
                ItemSelector(
                    _fns: [
                        ParseFunction(name: "_parse_product_item", args: ProductItemParseArgs())
                    ]
                )
            ]
        )
    )
    
    private enum CodingKeys: String, CodingKey {
        case products
    }
}

struct ProductParseConfig: Codable {
    let _fns: [ParseFunction]
    let _items: [ItemSelector]
}

struct ParseFunction: Codable {
    let name: String
    let args: Codable
    
    init(name: String, args: ProductParseArgs) {
        self.name = name
        self.args = args
    }
    
    init(name: String, args: ProductItemParseArgs) {
        self.name = name
        self.args = args
    }
    
    private enum CodingKeys: String, CodingKey {
        case name = "_fn"
        case args = "_args"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let parseArgs = args as? ProductParseArgs {
            try container.encode(parseArgs, forKey: .args)
        } else if let itemArgs = args as? ProductItemParseArgs {
            try container.encode(itemArgs, forKey: .args)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        
        // Try decoding as different arg types
        if let parseArgs = try? container.decode(ProductParseArgs.self, forKey: .args) {
            args = parseArgs
        } else if let itemArgs = try? container.decode(ProductItemParseArgs.self, forKey: .args) {
            args = itemArgs
        } else {
            throw DecodingError.dataCorruptedError(forKey: .args, in: container, debugDescription: "Unable to decode args")
        }
    }
}

struct ProductParseArgs: Codable {
    let extractFields: [String]
    
    init() {
        self.extractFields = ["title", "price", "image_url", "rating", "availability", "brand"]
    }
    
    private enum CodingKeys: String, CodingKey {
        case extractFields = "extract_fields"
    }
}

struct ProductItemParseArgs: Codable {
    let extractFields: [String]
    
    init() {
        self.extractFields = ["title", "price", "original_price", "image_url", "rating", "review_count", "availability", "brand", "url"]
    }
    
    private enum CodingKeys: String, CodingKey {
        case extractFields = "extract_fields"
    }
}

struct ItemSelector: Codable {
    let _fns: [ParseFunction]
}

struct ContextParameter: Codable {
    let key: String
    let value: String
}

// MARK: - Oxylabs Response Models

struct OxylabsScraperResponse: Codable {
    let results: [ScraperResult]
    let jobInfo: JobInfo?
    
    private enum CodingKeys: String, CodingKey {
        case results
        case jobInfo = "job_info"
    }
}

struct ScraperResult: Codable {
    let content: ScrapedContent?
    let statusCode: Int
    let url: String
    let taskId: String?
    
    private enum CodingKeys: String, CodingKey {
        case content
        case statusCode = "status_code"
        case url
        case taskId = "task_id"
    }
}

struct ScrapedContent: Codable {
    let results: ProductResults?
    let url: String?
    let lastUpdated: String?
    
    private enum CodingKeys: String, CodingKey {
        case results
        case url
        case lastUpdated = "last_updated"
    }
}

struct ProductResults: Codable {
    let products: [ScrapedProduct]?
    let totalResults: Int?
    let searchQuery: String?
    
    private enum CodingKeys: String, CodingKey {
        case products
        case totalResults = "total_results"
        case searchQuery = "search_query"
    }
}

struct ScrapedProduct: Codable {
    let title: String?
    let price: String?
    let originalPrice: String?
    let imageUrl: String?
    let rating: Double?
    let reviewCount: Int?
    let availability: String?
    let brand: String?
    let url: String?
    let description: String?
    
    private enum CodingKeys: String, CodingKey {
        case title
        case price
        case originalPrice = "original_price"
        case imageUrl = "image_url"
        case rating
        case reviewCount = "review_count"
        case availability
        case brand
        case url
        case description
    }
}

struct JobInfo: Codable {
    let jobId: String
    let status: String
    let createdAt: String
    let updatedAt: String?
    
    private enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Error Models

struct OxylabsErrorDetails: Codable, Error, LocalizedError {
    let code: String
    let message: String
    let details: String?
    
    var errorDescription: String? {
        return message
    }
    
    var failureReason: String? {
        return details
    }
}

// MARK: - API Response Wrapper

struct OxylabsAPIResponse: Codable {
    let success: Bool
    let data: OxylabsScraperResponse?
    let error: OxylabsErrorDetails?
    let requestId: String?
    
    private enum CodingKeys: String, CodingKey {
        case success
        case data
        case error
        case requestId = "request_id"
    }
}

// MARK: - Rate Limiting Support

struct OxylabsUsageInfo: Codable {
    let requestsUsed: Int
    let requestsLimit: Int
    let resetTime: Date
    
    private enum CodingKeys: String, CodingKey {
        case requestsUsed = "requests_used"
        case requestsLimit = "requests_limit"
        case resetTime = "reset_time"
    }
    
    var utilizationPercentage: Double {
        return Double(requestsUsed) / Double(requestsLimit) * 100
    }
    
    var isNearLimit: Bool {
        return utilizationPercentage > 80
    }
}