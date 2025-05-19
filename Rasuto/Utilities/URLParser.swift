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
        } else {
            throw URLParserError.unsupportedRetailer
        }
    }
    
    static func extractProductId(from url: URL, retailerType: RetailerType) -> String? {
        // This is a placeholder - you'll need to implement proper extraction logic
        // Different retailers format their URLs differently
        let urlString = url.absoluteString
        
        switch retailerType {
        case .bestBuy:
            // Implement Best Buy ID extraction
            return nil
        case .walmart:
            // Implement Walmart ID extraction
            return nil
        case .ebay:
            // Implement eBay ID extraction
            return nil
        }
        
        return nil
    }
}
