//
//  AxessoAmazonModels.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 6/3/25.
//

import Foundation

// MARK: - Search Response Models

struct AxessoAmazonSearchResponse: Codable {
    let responseStatus: String?
    let responseMessage: String?
    let foundProducts: [AxessoAmazonSearchResult]? // Back to full product objects
    let foundSponsoredProducts: [AxessoAmazonSearchResult]?
    let domainCode: String?
    let keyword: String?
    let numberOfProducts: Int?
    let lastPage: Int?
    let currentPage: Int?
    let nextPage: String?
    let sortStrategy: String?
    let resultCount: Int?
    let selectedCategory: String?
    
    enum CodingKeys: String, CodingKey {
        case responseStatus, responseMessage, foundProducts, foundSponsoredProducts
        case domainCode, keyword, numberOfProducts, lastPage, currentPage, nextPage
        case sortStrategy, resultCount, selectedCategory
    }
}

struct AxessoAmazonSearchResult: Codable {
    let asin: String?
    let productTitle: String?
    let manufacturer: String?
    let imageUrl: String?
    let productUrl: String?
    let price: Double?
    let originalPrice: Double?
    let currency: String?
    let availability: String?
    let productRating: String?
    let countReview: Int?
    let categoryPath: [String]?
    let prime: Bool?
    let bestseller: Bool?
    let amazonsChoice: Bool?
    
    enum CodingKeys: String, CodingKey {
        case asin, productTitle, manufacturer, imageUrl, productUrl
        case price, originalPrice, currency, availability, productRating
        case countReview, categoryPath, prime, bestseller, amazonsChoice
    }
}

// MARK: - Product Details Response Models

typealias AxessoAmazonProductDetails = AxessoAmazonProductDetailsResponse

struct AxessoAmazonProductDetailsResponse: Codable {
    let responseStatus: String?
    let responseMessage: String?
    let productTitle: String?
    let manufacturer: String?
    let countReview: Int?
    let answeredQuestions: Int?
    let productRating: String?
    let asin: String?
    let sizeSelection: [String]?
    let soldBy: String?
    let fulfilledBy: String?
    let sellerId: String?
    let warehouseAvailability: String?
    let retailPrice: Double?
    let price: Double?
    let priceRange: String?
    let shippingPrice: Double?
    let priceShippingInformation: String?
    let priceSaving: String?
    let features: [String]?
    let imageUrlList: [String]?
    let videoeUrlList: [String]?
    let productDescription: String?
    let productDetails: [AxessoAmazonProductDetail]?
    let minimalQuantity: String?
    let dealPrice: Double?
    let salePrice: Double?
    let reviews: [AxessoAmazonReview]?
    let variations: [AxessoAmazonProductVariation]?
    let productUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case responseStatus, responseMessage, productTitle, manufacturer
        case countReview, answeredQuestions, productRating, asin
        case sizeSelection, soldBy, fulfilledBy, sellerId
        case warehouseAvailability, retailPrice, price, priceRange
        case shippingPrice, priceShippingInformation, priceSaving
        case features, imageUrlList, videoeUrlList, productDescription
        case productDetails, minimalQuantity, dealPrice, salePrice
        case reviews, variations, productUrl
    }
}

struct AxessoAmazonProductDetail: Codable {
    let name: String?
    let value: String?
}

struct AxessoAmazonProductVariation: Codable {
    let asin: String?
    let value: String?
    let displayValue: String?
    let selected: Bool?
    let available: Bool?
}

// MARK: - Reviews Response Models

struct AxessoAmazonReviewsResponse: Codable {
    let responseStatus: String?
    let responseMessage: String?
    let domainCode: String?
    let asin: String?
    let currentPage: Int?
    let totalPages: Int?
    let reviews: [AxessoAmazonReview]?
    
    enum CodingKeys: String, CodingKey {
        case responseStatus, responseMessage, domainCode, asin
        case currentPage, totalPages, reviews
    }
}

struct AxessoAmazonReview: Codable {
    let text: String?
    let date: String?
    let rating: String?
    let title: String?
    let userName: String?
    let url: String?
    let imageUrlList: [String]?
    let variationList: [String]?
    let verified: Bool?
    let helpful: Int?
    
    enum CodingKeys: String, CodingKey {
        case text, date, rating, title, userName, url
        case imageUrlList, variationList, verified, helpful
    }
}

// MARK: - Prices Response Models

struct AxessoAmazonPricesResponse: Codable {
    let responseStatus: String?
    let responseMessage: String?
    let domainCode: String?
    let asin: String?
    let url: String?
    let priceHistory: [AxessoAmazonPriceHistory]?
    let currentPrice: Double?
    let currency: String?
    let availability: String?
    
    enum CodingKeys: String, CodingKey {
        case responseStatus, responseMessage, domainCode, asin, url
        case priceHistory, currentPrice, currency, availability
    }
}

struct AxessoAmazonPriceHistory: Codable {
    let date: String?
    let price: Double?
    let currency: String?
}

// MARK: - Seller Response Models

struct AxessoAmazonSellerResponse: Codable {
    let responseStatus: String?
    let responseMessage: String?
    let domainCode: String?
    let sellerId: String?
    let sellerName: String?
    let sellerRating: String?
    let sellerFeedback: Int?
    let businessName: String?
    let businessAddress: String?
    
    enum CodingKeys: String, CodingKey {
        case responseStatus, responseMessage, domainCode, sellerId
        case sellerName, sellerRating, sellerFeedback, businessName, businessAddress
    }
}

struct AxessoAmazonSellerProductsResponse: Codable {
    let responseStatus: String?
    let responseMessage: String?
    let domainCode: String?
    let sellerId: String?
    let sellerName: String?
    let products: [AxessoAmazonSearchResult]?
    let currentPage: Int?
    let totalPages: Int?
    
    enum CodingKeys: String, CodingKey {
        case responseStatus, responseMessage, domainCode, sellerId
        case sellerName, products, currentPage, totalPages
    }
}

// MARK: - Best Sellers Response Models

struct AxessoAmazonBestSellersResponse: Codable {
    let responseStatus: String?
    let responseMessage: String?
    let domainCode: String?
    let categoryName: String?
    let categoryId: String?
    let bestSellersList: [AxessoAmazonBestSeller]?
    
    enum CodingKeys: String, CodingKey {
        case responseStatus, responseMessage, domainCode, categoryName
        case categoryId, bestSellersList
    }
}

struct AxessoAmazonBestSeller: Codable {
    let rank: Int?
    let asin: String?
    let productTitle: String?
    let manufacturer: String?
    let imageUrl: String?
    let productUrl: String?
    let price: Double?
    let currency: String?
    let productRating: String?
    let countReview: Int?
    
    enum CodingKeys: String, CodingKey {
        case rank, asin, productTitle, manufacturer, imageUrl
        case productUrl, price, currency, productRating, countReview
    }
}

// MARK: - Deals Response Models

struct AxessoAmazonDealsResponse: Codable {
    let responseStatus: String?
    let responseMessage: String?
    let domainCode: String?
    let totalResults: Int?
    let currentPage: Int?
    let totalPages: Int?
    let deals: [AxessoAmazonDeal]?
    
    enum CodingKeys: String, CodingKey {
        case responseStatus, responseMessage, domainCode, totalResults
        case currentPage, totalPages, deals
    }
}

struct AxessoAmazonDeal: Codable {
    let asin: String?
    let productTitle: String?
    let manufacturer: String?
    let imageUrl: String?
    let productUrl: String?
    let dealPrice: Double?
    let originalPrice: Double?
    let savingsAmount: Double?
    let savingsPercentage: String?
    let currency: String?
    let dealType: String?
    let endTime: String?
    let productRating: String?
    let countReview: Int?
    
    enum CodingKeys: String, CodingKey {
        case asin, productTitle, manufacturer, imageUrl, productUrl
        case dealPrice, originalPrice, savingsAmount, savingsPercentage
        case currency, dealType, endTime, productRating, countReview
    }
}