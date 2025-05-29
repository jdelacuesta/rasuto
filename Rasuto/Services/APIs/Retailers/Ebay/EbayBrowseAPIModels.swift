//
//  EbayBrowseAPIModels.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/29/25.
//

import Foundation

// MARK: - eBay Browse API Response Models

struct EbaySearchResponse: Decodable {
    let href: String?
    let total: Int
    let next: String?
    let limit: Int
    let offset: Int
    let itemSummaries: [EbayItemSummary]?
    
    enum CodingKeys: String, CodingKey {
        case href, total, next, limit, offset, itemSummaries
    }
}

struct EbayItemSummary: Decodable {
    let itemId: String
    let title: String
    let itemHref: String?
    let image: EbayImage?
    let additionalImages: [EbayImage]?
    let price: EbayPrice?
    let marketingPrice: EbayMarketingPrice?
    let seller: EbaySeller?
    let condition: String?
    let conditionId: String?
    let thumbnailImages: [EbayImage]?
    let shippingOptions: [EbayShippingOption]?
    let buyingOptions: [String]?
    let itemWebUrl: String?
    let itemLocation: EbayItemLocation?
    let categories: [EbayCategory]?
    let primaryCategory: EbayCategory?
    let primaryCategoryId: String?
    let bidCount: Int?
    let currentBidPrice: EbayPrice?
    let estimatedEndTime: String?
    
    // Additional properties for inventory tracking
    let availabilityThresholdType: String?
    let availabilityThreshold: Int?
    let estimatedAvailableQuantity: Int?
    let itemEndDate: String?
    
    enum CodingKeys: String, CodingKey {
        case itemId, title, image, price, seller, condition, conditionId, thumbnailImages
        case itemHref, additionalImages, marketingPrice, shippingOptions, buyingOptions
        case itemWebUrl, itemLocation, categories, bidCount, currentBidPrice
        case estimatedEndTime, availabilityThresholdType, availabilityThreshold
        case estimatedAvailableQuantity, primaryCategory, itemEndDate, primaryCategoryId
    }
}

struct EbayImage: Decodable {
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case imageUrl
    }
}

struct EbayPrice: Codable {
    let value: String
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case value, currency
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(currency, forKey: .currency)
    }
}


struct EbayMarketingPrice: Decodable {
    let originalPrice: EbayPrice?
    let discountPercentage: String?
    let discountAmount: EbayPrice?
    
    enum CodingKeys: String, CodingKey {
        case originalPrice, discountPercentage, discountAmount
    }
}

struct EbaySeller: Decodable {
    let username: String?
    let feedbackPercentage: String?
    let feedbackScore: Int?
    
    enum CodingKeys: String, CodingKey {
        case username, feedbackPercentage, feedbackScore
    }
}

struct EbayShippingOption: Decodable {
    let shippingCostType: String?
    let shippingCost: EbayPrice?
    
    enum CodingKeys: String, CodingKey {
        case shippingCostType, shippingCost
    }
}

struct EbayItemLocation: Decodable {
    let postalCode: String?
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case postalCode, country
    }
}

struct EbayCategory: Decodable {
    let categoryId: String?
    let categoryName: String?
    
    enum CodingKeys: String, CodingKey {
        case categoryId, categoryName
    }
}

// MARK: - Notification Models

struct ItemNotification: Codable {
    let itemId: String
    let eventType: String
    let eventDate: String
    let oldPrice: EbayPrice?
    let newPrice: EbayPrice?
    let oldQuantity: Int?
    let newQuantity: Int?
    let endTime: String?
    
    enum CodingKeys: String, CodingKey {
        case itemId, eventType, eventDate, oldPrice, newPrice, oldQuantity, newQuantity, endTime
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(itemId, forKey: .itemId)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(eventDate, forKey: .eventDate)
        try container.encodeIfPresent(oldPrice, forKey: .oldPrice)
        try container.encodeIfPresent(newPrice, forKey: .newPrice)
        try container.encodeIfPresent(oldQuantity, forKey: .oldQuantity)
        try container.encodeIfPresent(newQuantity, forKey: .newQuantity)
        try container.encodeIfPresent(endTime, forKey: .endTime)
    }
}
