//
//  RetailerType.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/28/25.
//

import Foundation
import SwiftUI

enum RetailerType: String, CaseIterable {
    case all = "all"
    case bestBuy = "bestbuy"
    case walmart = "walmart"
    case ebay = "ebay"
    case googleShopping = "google_shopping"
    case homeDepot = "home_depot"
    case amazon = "amazon"
    case axesso = "axesso_amazon"
    
    var displayName: String {
        switch self {
        case .all:
            return "All Stores"
        case .bestBuy:
            return "Best Buy"
        case .walmart:
            return "Walmart"
        case .ebay:
            return "eBay"
        case .googleShopping:
            return "Google Shopping"
        case .homeDepot:
            return "Home Depot"
        case .amazon:
            return "Amazon"
        case .axesso:
            return "Amazon Direct"
        }
    }
    
    var domain: String {
        switch self {
        case .all:
            return "all"
        case .bestBuy:
            return "bestbuy.com"
        case .walmart:
            return "walmart.com"
        case .ebay:
            return "ebay.com"
        case .googleShopping:
            return "shopping.google.com"
        case .homeDepot:
            return "homedepot.com"
        case .amazon:
            return "amazon.com"
        case .axesso:
            return "amazon.com"
        }
    }
    
    // UI-specific properties (consolidated from RetailerFilter)
    var icon: Image {
        switch self {
        case .all:
            return Image(systemName: "globe")
        case .googleShopping:
            return Image(systemName: "magnifyingglass")
        case .amazon:
            return Image(systemName: "shippingbox")
        case .walmart:
            return Image(systemName: "bag")
        case .ebay:
            return Image(systemName: "hammer")
        case .homeDepot:
            return Image(systemName: "house")
        case .bestBuy:
            return Image(systemName: "tv")
        case .axesso:
            return Image(systemName: "cube.box")
        }
    }
    
    var color: Color {
        switch self {
        case .all:
            return .blue
        case .googleShopping:
            return .green
        case .amazon:
            return .orange
        case .walmart:
            return .blue
        case .ebay:
            return .yellow
        case .homeDepot:
            return .orange
        case .bestBuy:
            return .blue
        case .axesso:
            return .purple
        }
    }
    
    // SerpAPI engine mapping
    var serpAPIEngine: SerpAPIEngine? {
        switch self {
        case .googleShopping:
            return .googleShopping
        case .ebay:
            return .ebay
        case .walmart:
            return .walmart
        case .homeDepot:
            return .homeDepot
        case .amazon:
            return .amazon
        case .bestBuy, .axesso, .all:
            return nil // BestBuy uses RapidAPI, Axesso is direct API, all is filter-only
        }
    }
    
    // API Coordinator service identifier mapping
    var coordinatorServiceId: String {
        switch self {
        case .all:
            return "all"
        case .bestBuy:
            return "bestbuy"
        case .walmart:
            return "walmart_production" // SerpAPI Walmart
        case .ebay:
            return "ebay_production" // SerpAPI eBay
        case .googleShopping:
            return "google_shopping"
        case .homeDepot:
            return "home_depot"
        case .amazon:
            return "amazon"
        case .axesso:
            return "axesso_amazon"
        }
    }
    
    // Primary API source indicator
    var usesSerpAPI: Bool {
        return serpAPIEngine != nil
    }
    
    // MARK: - Static Utility Functions
    
    /// Converts SerpAPI/API coordinator service identifiers to display names
    static func displayName(for serviceId: String) -> String {
        // Handle SerpAPI identifiers
        switch serviceId.lowercased() {
        case "google_shopping":
            return RetailerType.googleShopping.displayName
        case "walmart_production", "walmart":
            return RetailerType.walmart.displayName
        case "ebay_production", "ebay":
            return RetailerType.ebay.displayName
        case "home_depot":
            return RetailerType.homeDepot.displayName
        case "amazon":
            return RetailerType.amazon.displayName
        case "bestbuy":
            return RetailerType.bestBuy.displayName
        case let id where id.contains("axesso"):
            return "Axesso API"
        default:
            // Fallback: Convert underscores to spaces and capitalize
            return serviceId
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "_production", with: "")
                .capitalized
        }
    }
    
    /// Converts display names back to service identifiers
    static func serviceId(for displayName: String) -> String {
        for retailer in RetailerType.allCases {
            if retailer.displayName.lowercased() == displayName.lowercased() {
                return retailer.coordinatorServiceId
            }
        }
        // Fallback: Convert spaces to underscores
        return displayName.lowercased().replacingOccurrences(of: " ", with: "_")
    }
}
