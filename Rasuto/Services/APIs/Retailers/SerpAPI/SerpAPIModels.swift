//
//  SerpAPIModels.swift
//  Rasuto
//
//  Created for SerpAPI integration on 6/2/25.
//

import Foundation

// MARK: - Base SerpAPI Response

struct SerpAPIResponse: Codable {
    let searchMetadata: SearchMetadata?
    let searchParameters: SearchParameters?
    let searchInformation: SearchInformation?
    let shoppingResults: [ShoppingResult]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case searchMetadata = "search_metadata"
        case searchParameters = "search_parameters"
        case searchInformation = "search_information"
        case shoppingResults = "shopping_results"
        case error
    }
}

// MARK: - Search Metadata

struct SearchMetadata: Codable {
    let id: String?
    let status: String?
    let jsonEndpoint: String?
    let createdAt: String?
    let processedAt: String?
    let googleUrl: String?
    let rawHtmlFile: String?
    let totalTimeTaken: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case jsonEndpoint = "json_endpoint"
        case createdAt = "created_at"
        case processedAt = "processed_at"
        case googleUrl = "google_url"
        case rawHtmlFile = "raw_html_file"
        case totalTimeTaken = "total_time_taken"
    }
}

// MARK: - Search Parameters

struct SearchParameters: Codable {
    let engine: String?
    let q: String?
    let location: String?
    let hl: String?
    let gl: String?
    let googleDomain: String?
    
    enum CodingKeys: String, CodingKey {
        case engine, q, location, hl, gl
        case googleDomain = "google_domain"
    }
}

// MARK: - Search Information

struct SearchInformation: Codable {
    let totalResults: Int?  // Changed from String to Int - SerpAPI returns numbers
    let timeTaken: Double?
    let queryDisplayed: String?
    
    enum CodingKeys: String, CodingKey {
        case totalResults = "total_results"
        case timeTaken = "time_taken"
        case queryDisplayed = "query_displayed"
    }
}

// MARK: - Google Shopping Result

struct ShoppingResult: Codable {
    let position: Int?
    let title: String?
    let link: String?
    let productLink: String?
    let productId: String?
    let serpApiProductApi: String?
    let number: String?
    let source: String?
    let price: String?
    let extractedPrice: Double?
    let rating: Double?
    let ratingCount: Int?
    let delivery: String?
    let thumbnail: String?
    let secondHandOptions: [SecondHandOption]?
    
    enum CodingKeys: String, CodingKey {
        case position, title, link
        case productLink = "product_link"
        case productId = "product_id"
        case serpApiProductApi = "serpapi_product_api"
        case number, source, price
        case extractedPrice = "extracted_price"
        case rating
        case ratingCount = "rating_count"
        case delivery, thumbnail
        case secondHandOptions = "second_hand_options"
    }
}

struct SecondHandOption: Codable {
    let source: String?
    let link: String?
    let price: String?
    let extractedPrice: Double?
    let condition: String?
    let thumbnail: String?
    
    enum CodingKeys: String, CodingKey {
        case source, link, price
        case extractedPrice = "extracted_price"
        case condition, thumbnail
    }
}

// MARK: - eBay Specific Models (SerpAPI)

struct SerpEbaySearchResponse: Codable {
    let searchMetadata: SearchMetadata?
    let searchParameters: SerpEbaySearchParameters?
    let ebayResults: [SerpEbayResult]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case searchMetadata = "search_metadata"
        case searchParameters = "search_parameters"
        case ebayResults = "ebay_results"
        case error
    }
}

struct SerpEbaySearchParameters: Codable {
    let engine: String?
    let ebayDomain: String?
    let q: String?
    let buyItNow: String?
    
    enum CodingKeys: String, CodingKey {
        case engine
        case ebayDomain = "ebay_domain"
        case q
        case buyItNow = "_nkw"
    }
}

struct SerpEbayResult: Codable {
    let position: Int?
    let title: String?
    let link: String?
    let thumbnail: String?
    let condition: String?
    let price: SerpEbayPrice?
    let shipping: SerpEbayShipping?
    let auction: SerpEbayAuction?
    let seller: SerpEbaySeller?
    let ratingsCount: Int?
    let extensions: [String]?
    
    enum CodingKeys: String, CodingKey {
        case position, title, link, thumbnail, condition, price, shipping, auction, seller, extensions
        case ratingsCount = "ratings_count"
    }
}

struct SerpEbayPrice: Codable {
    let from: String?
    let to: String?
    let extracted: [Double]?
}

struct SerpEbayShipping: Codable {
    let cost: String?
    let extractedCost: Double?
    
    enum CodingKeys: String, CodingKey {
        case cost
        case extractedCost = "extracted_cost"
    }
}

struct SerpEbayAuction: Codable {
    let timeLeft: String?
    let bidCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case timeLeft = "time_left"
        case bidCount = "bid_count"
    }
}

struct SerpEbaySeller: Codable {
    let name: String?
    let link: String?
    let rating: Double?
    let ratingsCount: Int?
    let topRated: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name, link, rating
        case ratingsCount = "ratings_count"
        case topRated = "top_rated"
    }
}

// MARK: - Walmart Specific Models

struct WalmartSearchResponse: Codable {
    let searchMetadata: SearchMetadata?
    let searchParameters: WalmartSearchParameters?
    let walmartResults: [WalmartResult]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case searchMetadata = "search_metadata"
        case searchParameters = "search_parameters"
        case walmartResults = "walmart_results"
        case error
    }
}

struct WalmartSearchParameters: Codable {
    let engine: String?
    let query: String?
}

struct WalmartResult: Codable {
    let position: Int?
    let title: String?
    let link: String?
    let thumbnail: String?
    let price: WalmartPrice?
    let rating: Double?
    let ratingsCount: Int?
    let primaryOffer: WalmartOffer?
    let seller: WalmartSeller?
    let productId: String?
    
    enum CodingKeys: String, CodingKey {
        case position, title, link, thumbnail, price, rating
        case ratingsCount = "ratings_count"
        case primaryOffer = "primary_offer"
        case seller
        case productId = "product_id"
    }
}

struct WalmartPrice: Codable {
    let current: String?
    let currentRaw: Double?
    let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case current
        case currentRaw = "current_raw"
        case currency
    }
}

struct WalmartOffer: Codable {
    let price: String?
    let priceRaw: Double?
    let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case price
        case priceRaw = "price_raw"
        case currency
    }
}

struct WalmartSeller: Codable {
    let name: String?
    let link: String?
}

// MARK: - Home Depot Models (similar to Google Shopping)

typealias HomeDepotSearchResponse = SerpAPIResponse
typealias HomeDepotResult = ShoppingResult

// MARK: - Amazon Models (similar to Google Shopping for now)

typealias AmazonSearchResponse = SerpAPIResponse
typealias AmazonResult = ShoppingResult

// MARK: - SerpAPI Error Models

struct SerpAPIError: Codable, Error {
    let error: String
    let code: Int?
    let message: String?
    
    var localizedDescription: String {
        return message ?? error
    }
}

// MARK: - Retailer Engine Types

enum SerpAPIEngine: String, CaseIterable {
    case googleShopping = "google_shopping"
    case ebay = "ebay"
    case walmart = "walmart"
    case homeDepot = "home_depot"
    case amazon = "amazon"
    
    var displayName: String {
        switch self {
        case .googleShopping: return "Google Shopping"
        case .ebay: return "eBay"
        case .walmart: return "Walmart"
        case .homeDepot: return "Home Depot"
        case .amazon: return "Amazon"
        }
    }
    
    var sourceName: String {
        return displayName
    }
}

// MARK: - Search Options

struct SerpAPISearchOptions {
    let location: String
    let language: String
    let country: String
    let maxResults: Int
    let includeSecondHand: Bool
    
    init(
        location: String = "United States",
        language: String = "en",
        country: String = "us",
        maxResults: Int = 20,
        includeSecondHand: Bool = false
    ) {
        self.location = location
        self.language = language
        self.country = country
        self.maxResults = maxResults
        self.includeSecondHand = includeSecondHand
    }
}