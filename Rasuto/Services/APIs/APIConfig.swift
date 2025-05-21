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
    
    //Initialization method
    static func initializeAPIKeys() {
        // First check if keys already exist in keychain
        let needsInitialization = !APIKeyManager.shared.hasAPIKey(for: Service.ebay) ||
                                 !APIKeyManager.shared.hasAPIKey(for: Service.ebayClientID) ||
                                 !APIKeyManager.shared.hasAPIKey(for: Service.ebayClientSecret) ||
                                 !APIKeyManager.shared.hasAPIKey(for: Service.bestBuy) ||
                                 !APIKeyManager.shared.hasAPIKey(for: Service.walmart)
        
        if needsInitialization {
            do {
                // Load keys from configuration
                #if DEBUG
                print("📝 Initializing API keys...")
                // Check if SecretKeys exists
                if (SecretKeys.self is Any.Type) {
                    // Try to use values from SecretKeys, fallback to DefaultKeys if needed
                    
                    // eBay API Key
                    let ebayApiKey = SecretKeys.ebayApiKey.isEmpty ? DefaultKeys.ebayApiKey : SecretKeys.ebayApiKey
                    try saveAPIKey(ebayApiKey, for: Service.ebay)
                    
                    // eBay Client ID
                    let ebayClientId = SecretKeys.ebayClientId.isEmpty ? DefaultKeys.ebayClientId : SecretKeys.ebayClientId
                    try saveAPIKey(ebayClientId, for: Service.ebayClientID)
                    
                    // eBay Client Secret
                    let ebayClientSecret = SecretKeys.ebayClientSecret.isEmpty ? DefaultKeys.ebayClientSecret : SecretKeys.ebayClientSecret
                    try saveAPIKey(ebayClientSecret, for: Service.ebayClientSecret)
                    
                    // Best Buy API Key
                    let bestBuyApiKey = SecretKeys.bestBuyApiKey.isEmpty ? DefaultKeys.bestBuyApiKey : SecretKeys.bestBuyApiKey
                    try saveAPIKey(bestBuyApiKey, for: Service.bestBuy)
                    
                    // Walmart API Key
                    let walmartApiKey = SecretKeys.walmartApiKey.isEmpty ? DefaultKeys.walmartApiKey : SecretKeys.walmartApiKey
                    try saveAPIKey(walmartApiKey, for: Service.walmart)
                    
                    print("✅ API keys initialized from SecretKeys/DefaultKeys")
                } else {
                    print("⚠️ SecretKeys not found, using default placeholder keys")
                    // Fallback for development - using placeholders
                    try saveAPIKey(DefaultKeys.ebayApiKey, for: Service.ebay)
                    try saveAPIKey(DefaultKeys.ebayClientId, for: Service.ebayClientID)
                    try saveAPIKey(DefaultKeys.ebayClientSecret, for: Service.ebayClientSecret)
                    try saveAPIKey(DefaultKeys.bestBuyApiKey, for: Service.bestBuy)
                    try saveAPIKey(DefaultKeys.walmartApiKey, for: Service.walmart)
                }
                #else
                // Production environment should get keys from a secure source
                // ...
                #endif
                
            } catch {
                print("❌ Failed to initialize API keys: \(error)")
            }
        } else {
            print("📝 Verifying existing API keys...")
            do {
                // Verify ebay keys are correct
                let ebayClientID = try getAPIKey(for: Service.ebayClientID)
                let ebayClientSecret = try getAPIKey(for: Service.ebayClientSecret)
                
                // Check if these are test keys that should be updated
                if ebayClientID.hasPrefix("placeholder_") || ebayClientSecret.hasPrefix("placeholder_") {
                    print("⚠️ Placeholder keys detected, updating with real credentials if available")
                    
                    // eBay API Key
                    let ebayApiKey = SecretKeys.ebayApiKey.isEmpty ? DefaultKeys.ebayApiKey : SecretKeys.ebayApiKey
                    try saveAPIKey(ebayApiKey, for: Service.ebay)
                    
                    // eBay Client ID
                    let ebayClientId = SecretKeys.ebayClientId.isEmpty ? DefaultKeys.ebayClientId : SecretKeys.ebayClientId
                    try saveAPIKey(ebayClientId, for: Service.ebayClientID)
                    
                    // eBay Client Secret
                    let ebayClientSecret = SecretKeys.ebayClientSecret.isEmpty ? DefaultKeys.ebayClientSecret : SecretKeys.ebayClientSecret
                    try saveAPIKey(ebayClientSecret, for: Service.ebayClientSecret)
                } else {
                    print("✅ API keys already exist in keychain")
                    print("✅ eBay Client ID: \(ebayClientID.prefix(4))...")
                    print("✅ eBay Client Secret: \(ebayClientSecret.prefix(4))...")
                }
            } catch {
                print("❌ Error verifying existing keys: \(error)")
            }
        }
    }
    
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
    
    static func saveAPIKey(_ key: String, for service: String) throws {
        try APIKeyManager.shared.saveAPIKey(for: service, key: key)
    }

    static func getAPIKey(for service: String) throws -> String {
        return try APIKeyManager.shared.getAPIKey(for: service)
    }
    
    static func deleteAPIKey(for service: String) throws {
        try APIKeyManager.shared.deleteAPIKey(for: service)
    }
    
    // MARK: - API Services Factory
    
    // BestBuy API service instance
    static func createBestBuyService() throws -> BestBuyAPIService {
        do {
            let apiKey = try getAPIKey(for: Service.bestBuy)
            return BestBuyAPIService(apiKey: apiKey)
        } catch {
            throw APIError.authenticationFailed
        }
    }
    
    // Walmart API service instance
    static func createWalmartService() throws -> WalmartAPIService {
        do {
            let apiKey = try getAPIKey(for: Service.walmart)
            return WalmartAPIService(apiKey: apiKey)
        } catch {
            throw APIError.authenticationFailed
        }
    }
    
    // Ebay API service instance
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
    // Reset API keys with the latest eBay sandbox credentials
    static func resetEbayKeys() {
        do {
            print("🔄 Resetting eBay keys to sandbox credentials...")
            
            // Delete existing keys first
            try? deleteAPIKey(for: Service.ebayClientID)
            try? deleteAPIKey(for: Service.ebayClientSecret)
            try? deleteAPIKey(for: Service.ebay)
            
            // Set the new sandbox keys
            // eBay API Key
            let ebayApiKey = SecretKeys.ebayApiKey.isEmpty ? DefaultKeys.ebayApiKey : SecretKeys.ebayApiKey
            try saveAPIKey(ebayApiKey, for: Service.ebay)
            
            // eBay Client ID
            let ebayClientId = SecretKeys.ebayClientId.isEmpty ? DefaultKeys.ebayClientId : SecretKeys.ebayClientId
            try saveAPIKey(ebayClientId, for: Service.ebayClientID)
            
            // eBay Client Secret
            let ebayClientSecret = SecretKeys.ebayClientSecret.isEmpty ? DefaultKeys.ebayClientSecret : SecretKeys.ebayClientSecret
            try saveAPIKey(ebayClientSecret, for: Service.ebayClientSecret)
            
            print("✅ eBay keys reset successfully")
        } catch {
            print("❌ Failed to reset eBay keys: \(error)")
        }
    }
    
    // Setup development test keys (never use in production)
    static func setupTestKeys() {
        do {
            // These would be placeholder/test API keys for development only
            try saveAPIKey(DefaultKeys.ebayApiKey, for: Service.ebay)
            try saveAPIKey(DefaultKeys.ebayClientId, for: Service.ebayClientID)
            try saveAPIKey(DefaultKeys.ebayClientSecret, for: Service.ebayClientSecret)
            try saveAPIKey(DefaultKeys.bestBuyApiKey, for: Service.bestBuy)
            try saveAPIKey(DefaultKeys.walmartApiKey, for: Service.walmart)
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
