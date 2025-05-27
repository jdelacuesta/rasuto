//
//  NotificationsViewModel.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/29/25.
//

import Foundation

enum NotificationTypeAPI: String, Codable {
    case priceDropped = "priceDropped"
    case endingSoon = "endingSoon"
    case itemSold = "itemSold"
    case backInStock = "backInStock"
    case priceChange = "priceChange"
    case inventoryChange = "inventoryChange"
    case auctionEnding = "auctionEnding"
}

struct Alert: Identifiable, Codable {
    let id: UUID
    let productId: String
    let productName: String
    let source: String
    let alertType: NotificationTypeAPI
    let date: Date
    let message: String
    let thumbnailUrl: String?
    let isRead: Bool
    
    // For eBay auction specific data
    let auctionEndTime: Date?
    let currentBid: Double?
    
    // Codable implementation to handle UUID
    enum CodingKeys: String, CodingKey {
        case id, productId, productName, source, alertType, date, message, thumbnailUrl, isRead, auctionEndTime, currentBid
    }
    
    init(productId: String, productName: String, source: String, alertType: NotificationType, date: Date, message: String, thumbnailUrl: String?, isRead: Bool, auctionEndTime: Date?, currentBid: Double?) {
        self.id = UUID()
        self.productId = productId
        self.productName = productName
        self.source = source
        self.alertType = alertType
        self.date = date
        self.message = message
        self.thumbnailUrl = thumbnailUrl
        self.isRead = isRead
        self.auctionEndTime = auctionEndTime
        self.currentBid = currentBid
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        productId = try container.decode(String.self, forKey: .productId)
        productName = try container.decode(String.self, forKey: .productName)
        source = try container.decode(String.self, forKey: .source)
        alertType = try container.decode(NotificationType.self, forKey: .alertType)
        date = try container.decode(Date.self, forKey: .date)
        message = try container.decode(String.self, forKey: .message)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        auctionEndTime = try container.decodeIfPresent(Date.self, forKey: .auctionEndTime)
        currentBid = try container.decodeIfPresent(Double.self, forKey: .currentBid)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(productId, forKey: .productId)
        try container.encode(productName, forKey: .productName)
        try container.encode(source, forKey: .source)
        try container.encode(alertType, forKey: .alertType)
        try container.encode(date, forKey: .date)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encode(isRead, forKey: .isRead)
        try container.encodeIfPresent(auctionEndTime, forKey: .auctionEndTime)
        try container.encodeIfPresent(currentBid, forKey: .currentBid)
    }
}
