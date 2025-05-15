//
//  APIConfig.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import Foundation

// This class provides a centralized way to manage API configuration
struct APIConfig {
    
    // Basic configuration
    static let requestTimeout: TimeInterval = 30
    static let maxRetries = 3
    static let userAgent = "Rasuto/1.0"
    
    // MARK: - API Service Identifiers
    struct Service {
        static let bestBuy = "com.rasuto.api.bestbuy"
        static let walmart = "com.rasuto.api.walmart"
        static let ebay = "com.rasuto.api.ebay"
        static let ebayClientID = "com.rasuto.api.ebay.clientid"
        static let ebayClientSecret = "com.rasuto.api.ebay.clientsecret"
        static let ebayAccessToken = "com.rasuto.api.ebay.accesstoken"
    }
    
    // MARK: - Keychain Access
    
    // Save an API key to the keychain
    static func saveAPIKey(_ key: String, for service: String) throws {
        try APIKeyManager.shared.saveAPIKey(for: service, key: key)
    }
    
    // Retrieve an API key from the keychain
    static func getAPIKey(for service: String) throws -> String {
        return try APIKeyManager.shared.getAPIKey(for: service)
    }
    
    // Delete an API key from the keychain
    static func deleteAPIKey(for service: String) throws {
        try APIKeyManager.shared.deleteAPIKey(for: service)
    }
    
    // MARK: - API Services Factory
    
    // Create a BestBuy API service instance
    static func createBestBuyService() throws -> BestBuyAPIService {
        do {
            let apiKey = try getAPIKey(for: Service.bestBuy)
            return BestBuyAPIService(apiKey: apiKey)
        } catch {
            throw APIError.authenticationFailed
        }
    }
    
    // Create a Walmart API service instance
    static func createWalmartService() throws -> WalmartAPIService {
        do {
            let apiKey = try getAPIKey(for: Service.walmart)
            return WalmartAPIService(apiKey: apiKey)
        } catch {
            throw APIError.authenticationFailed
        }
    }
    
    // Create an Ebay API service instance
    static func createEbayService() throws -> EbayAPIService {
        do {
            let apiKey = try getAPIKey(for: Service.ebay)
            return EbayAPIService(apiKey: apiKey)
        } catch {
            throw APIError.authenticationFailed
        }
    }
    
    // MARK: - Development/Testing Helpers
    
    #if DEBUG
    // Setup development test keys (never use in production)
    static func setupTestKeys() {
        do {
            // These would be placeholder/test API keys for development only
            try saveAPIKey("test_best_buy_key", for: Service.bestBuy)
            try saveAPIKey("test_walmart_key", for: Service.walmart)
            try saveAPIKey("test_ebay_key", for: Service.ebay)
            try saveAPIKey("test_ebay_client_id", for: Service.ebayClientID)
            try saveAPIKey("test_ebay_client_secret", for: Service.ebayClientSecret)
        } catch {
            print("Failed to set up test API keys: \(error)")
        }
    }
    #endif
    
    // MARK: - Rate Limiting Info
    
    struct RateLimits {
        struct BestBuy {
            static let requestsPerSecond = 5
            static let requestsPerDay = 50000
        }
        
        struct Walmart {
            static let requestsPerDay = 5000
        }
        
        struct Ebay {
            static let requestsPerSecond = 5
            static let requestsPerHour = 5000
        }
    }
}
