//
//  SearchItem.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/21/25.
//

import Foundation
import SwiftUI

/// Represents an item in the search results
struct SearchItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let price: Double
    let imageURL: URL?
    let source: ItemSource
    let category: ItemCategory
    let isSaved: Bool
    
    init(id: UUID = UUID(),
         name: String,
         description: String,
         price: Double,
         imageURL: URL? = nil,
         source: ItemSource = .internal,
         category: ItemCategory = .general,
         isSaved: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.imageURL = imageURL
        self.source = source
        self.category = category
        self.isSaved = isSaved
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SearchItem, rhs: SearchItem) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents the source of an item
enum ItemSource: String, Codable, CaseIterable {
    case bestBuy = "Best Buy"
    case walmart = "Walmart"
    case ebay = "eBay"
    case `internal` = "Rasuto"
    
    var color: Color {
        switch self {
        case .bestBuy:
            return Color.blue
        case .walmart:
            return Color.blue
        case .ebay:
            return Color.red
        case .internal:
            return Color.primary
        }
    }
    
    var icon: String {
        switch self {
        case .bestBuy:
            return "bolt.fill"
        case .walmart:
            return "cart.fill"
        case .ebay:
            return "tag.fill"
        case .internal:
            return "star.fill"
        }
    }
}

/// Represents a category for an item
enum ItemCategory: String, Codable, CaseIterable {
    case electronics = "Electronics"
    case cameras = "Cameras"
    case audio = "Audio"
    case computers = "Computers"
    case accessories = "Accessories"
    case general = "General"
    
    var icon: String {
        switch self {
        case .electronics:
            return "bolt.fill"
        case .cameras:
            return "camera.fill"
        case .audio:
            return "headphones"
        case .computers:
            return "desktop.computer"
        case .accessories:
            return "circles.hexagongrid.fill"
        case .general:
            return "square.grid.2x2.fill"
        }
    }
}

/// Represents a search filter
struct SearchFilter: Identifiable {
    let id = UUID()
    let name: String
    let isSelected: Bool
}

/// Represents a recent search entry
struct RecentSearch: Identifiable, Codable, Equatable {
    let id: UUID
    let query: String
    let timestamp: Date
    
    init(id: UUID = UUID(), query: String, timestamp: Date = Date()) {
        self.id = id
        self.query = query
        self.timestamp = timestamp
    }
    
    static func == (lhs: RecentSearch, rhs: RecentSearch) -> Bool {
        return lhs.id == rhs.id
    }
}
