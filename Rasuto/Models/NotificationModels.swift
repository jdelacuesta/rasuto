//
//  NotificationModels.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import Foundation
import SwiftUI

// MARK: - Notification Alert

struct NotificationAlert: Identifiable {
    let id = UUID()
    let productName: String
    let message: String
    let source: String
    let date: Date
    let thumbnailUrl: String?
    let productId: String?
    
    init(productName: String, message: String, source: String, date: Date = Date(), thumbnailUrl: String? = nil, productId: String? = nil) {
        self.productName = productName
        self.message = message
        self.source = source
        self.date = date
        self.thumbnailUrl = thumbnailUrl
        self.productId = productId
    }
}

// MARK: - Notification Type UI

enum NotificationTypeUI {
    case priceDrop
    case backInStock
    case trackingUpdate
    case tariffChange
    
    var icon: String {
        switch self {
        case .priceDrop: return "arrow.down.circle.fill"
        case .backInStock: return "checkmark.circle.fill"
        case .trackingUpdate: return "bell.badge.fill"
        case .tariffChange: return "chart.line.uptrend.xyaxis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .priceDrop: return .green
        case .backInStock: return .blue
        case .tariffChange: return .orange
        case .trackingUpdate: return .orange
        }
    }
    
    static func from(_ notificationType: NotificationTypeAPI) -> NotificationTypeUI {
        switch notificationType {
        case .priceDropped, .priceChange:
            return .priceDrop
        case .backInStock, .inventoryChange:
            return .backInStock
        case .endingSoon, .itemSold, .auctionEnding:
            return .trackingUpdate
        }
    }
}

// MARK: - Notification Item

class NotificationItem: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationTypeUI
    let source: String
    let productId: String?
    let productName: String?
    let productImageUrl: String?
    let oldPrice: Double?
    let newPrice: Double?
    let timestamp: Date
    @Published var isRead: Bool
    
    init(title: String, message: String, type: NotificationTypeUI, source: String, productId: String? = nil, productName: String? = nil, productImageUrl: String? = nil, oldPrice: Double? = nil, newPrice: Double? = nil, isRead: Bool = false) {
        self.title = title
        self.message = message
        self.type = type
        self.source = source
        self.productId = productId
        self.productName = productName
        self.productImageUrl = productImageUrl
        self.oldPrice = oldPrice
        self.newPrice = newPrice
        self.timestamp = Date()
        self.isRead = isRead
    }
}