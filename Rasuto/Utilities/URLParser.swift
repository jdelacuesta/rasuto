//
//  URLParser.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import Foundation

enum URLParserError: Error {
    case invalidURL
    case unsupportedRetailer
}

class URLParser {
    static func getRetailerType(from url: URL) throws -> RetailerType {
        let urlString = url.absoluteString.lowercased()
        
        if urlString.contains("bestbuy") {
            return .bestBuy
        } else if urlString.contains("walmart") {
            return .walmart
        } else if urlString.contains("ebay") {
            return .ebay
        } else if urlString.contains("shopping.google") || urlString.contains("google.com/shopping") {
            return .googleShopping
        } else if urlString.contains("homedepot") {
            return .homeDepot
        } else if urlString.contains("amazon") {
            return .amazon
        } else {
            throw URLParserError.unsupportedRetailer
        }
    }
    
    static func extractProductId(from url: URL, retailerType: RetailerType) -> String? {
        // This is a placeholder - you'll need to implement proper extraction logic
        // Different retailers format their URLs differently
        let urlString = url.absoluteString
        
        switch retailerType {
        case .all:
            // Cannot extract ID from "all" - not a specific retailer
            return nil
        case .bestBuy:
            // Implement Best Buy ID extraction
            return nil
        case .walmart:
            // Implement Walmart ID extraction
            return nil
        case .ebay:
            // Implement eBay ID extraction
            return nil
        case .googleShopping:
            // Implement Google Shopping ID extraction
            return nil
        case .homeDepot:
            // Implement Home Depot ID extraction
            return nil
        case .amazon:
            // Implement Amazon ID extraction
            return nil
        case .axesso:
            // Axesso uses Amazon URLs, so treat like Amazon
            return nil
        }
        
        return nil
    }
}
