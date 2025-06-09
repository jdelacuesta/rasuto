//
//  DefaultKeys.swift
//  Rasuto
//
//  Created by JC Dela Cuesta
//

import Foundation

struct DefaultKeys {
    // SECURITY: API keys removed for GitHub security
    // For evaluation: See API_KEYS.md file for actual working keys
    
    // SerpAPI - Primary API layer providing 90% coverage for Google Shopping, Amazon, eBay, Walmart, and Home Depot
    static let serpApiKey = ""
    
    // eBay integration provided via SerpAPI - no separate keys needed
    
    // BestBuy integration provided via SerpAPI - no separate keys needed
    
    // Walmart integration provided via SerpAPI - no separate keys needed
    
    // Axesso Amazon API Keys - Direct Amazon data provider
    static let axessoApiKeyPrimary = ""
    static let axessoApiKeySecondary = ""
    
    // Oxylabs Web Scraper API - Universal fallback scraper
    static let oxylabsUsername = ""
    static let oxylabsPassword = ""
}
