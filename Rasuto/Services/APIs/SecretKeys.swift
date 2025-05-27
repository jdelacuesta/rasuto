//
//  SecretKeys.swift
//  Rasuto
//
//  Created by JC Dela Cuesta
//

import Foundation

struct SecretKeys {
    // eBay API Keys
    static let ebayApiKey: String = {
        return ProcessInfo.processInfo.environment["EBAY_API_KEY"] ?? "bd749366-baeb-489a-9c92-42a60d9b83b3"
    }()
    
    static let ebayClientId: String = {
        return ProcessInfo.processInfo.environment["EBAY_CLIENT_ID"] ?? "JohnDela-Rasuto-SBX-8a6bc0b4d-f64bb84a"
    }()
    
    static let ebayClientSecret: String = {
        return ProcessInfo.processInfo.environment["EBAY_CLIENT_SECRET"] ?? "SBX-a6bc0b4d6e5a-23ba-442a-bb44-d0ba"
    }()
    
    // Other API keys
    static let bestBuyApiKey: String = {
        return ProcessInfo.processInfo.environment["BEST_BUY_API_KEY"] ?? ""
    }()
    
    static let bestBuyRapidApiKey: String = {
        return ProcessInfo.processInfo.environment["BEST_BUY_RAPID_API_KEY"] ?? "71098ddf86msh32a198c44c7d555p12c439jsn99de5f11bc40"
    }()
    
    static let walmartApiKey: String = {
        return ProcessInfo.processInfo.environment["WALMART_API_KEY"] ?? ""
    }()
}
