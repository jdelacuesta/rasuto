//
//  NotificationModels.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import Foundation
import SwiftUI

// MARK: - Notification Type UI

enum NotificationTypeUI {
    case priceDrop
    case backInStock
    case trackingUpdate
    
    var icon: String {
        switch self {
        case .priceDrop: return "arrow.down.circle.fill"
        case .backInStock: return "checkmark.circle.fill"
        case .trackingUpdate: return "bell.badge.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .priceDrop: return .green
        case .backInStock: return .blue
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
    let timestamp: Date
    @Published var isRead: Bool
    
    init(title: String, message: String, type: NotificationTypeUI, source: String, productId: String? = nil, isRead: Bool = false) {
        self.title = title
        self.message = message
        self.type = type
        self.source = source
        self.productId = productId
        self.timestamp = Date()
        self.isRead = isRead
    }
}