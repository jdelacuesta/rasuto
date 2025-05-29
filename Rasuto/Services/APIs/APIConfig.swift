
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
    
    enum Service {
        static let bestBuy = "com.rasuto.api.bestbuy"
        static let walmart = "com.rasuto.api.walmart"
        static let ebay = "com.rasuto.api.ebay"
        static let ebayClientID = "com.rasuto.api.ebay.clientid"
        static let ebayClientSecret = "com.rasuto.api.ebay.clientsecret"
        static let ebayAccessToken = "com.rasuto.api.ebay.accesstoken"
    }
    
    struct BestBuyKeys {
        static let rapidAPI = "com.rasuto.api.bestbuy.rapid"
        static let rapidAPIHost = "bestbuy-usa.p.rapidapi.com"
        // For direct Best Buy API (if we switch to it in the future)
        static let directAPI = "bestbuy.direct_api_key"
    }
    
    
    // Initialization method
    func initializeAPIKeys() {
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
                
                // eBay API Key
                let ebayApiKey = SecretKeys.ebayApiKey.isEmpty ? DefaultKeys.ebayApiKey : SecretKeys.ebayApiKey
                try APIKeyManager.shared.saveAPIKey(for: Service.ebay, key: ebayApiKey)
                
                // eBay Client ID
                let ebayClientId = SecretKeys.ebayClientId.isEmpty ? DefaultKeys.ebayClientId : SecretKeys.ebayClientId
                try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientID, key: ebayClientId)
                
                // eBay Client Secret
                let ebayClientSecret = SecretKeys.ebayClientSecret.isEmpty ? DefaultKeys.ebayClientSecret : SecretKeys.ebayClientSecret
                try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientSecret, key: ebayClientSecret)
                
                // Best Buy API Key
                let bestBuyApiKey = SecretKeys.bestBuyApiKey.isEmpty ? DefaultKeys.bestBuyRapidApiKeyValue : SecretKeys.bestBuyApiKey
                try APIKeyManager.shared.saveAPIKey(for: Service.bestBuy, key: bestBuyApiKey)
                
                // Walmart API Key
                let walmartApiKey = SecretKeys.walmartApiKey.isEmpty ? DefaultKeys.walmartApiKey : SecretKeys.walmartApiKey
                try APIKeyManager.shared.saveAPIKey(for: Service.walmart, key: walmartApiKey)
                
                // Add these lines to also store with alternate naming convention
                try APIKeyManager.shared.saveAPIKey(for: "ebay.api_key", key: ebayApiKey)
                try APIKeyManager.shared.saveAPIKey(for: "ebay.client_id", key: ebayClientId)
                try APIKeyManager.shared.saveAPIKey(for: "ebay.client_secret", key: ebayClientSecret)
                try APIKeyManager.shared.saveAPIKey(for: "bestbuy.api_key", key: bestBuyApiKey)
                try APIKeyManager.shared.saveAPIKey(for: "bestbuy.rapid_api_key", key: bestBuyApiKey)
                try APIKeyManager.shared.saveAPIKey(for: "walmart.api_key", key: walmartApiKey)
                
                print("✅ API keys initialized from SecretKeys/DefaultKeys")
                
#else
                
                print("⚠️ SecretKeys not found, using default placeholder keys")
                // Fallback for development - using placeholders
                try APIKeyManager.shared.saveAPIKey(for: Service.ebay, key: DefaultKeys.ebayApiKey)
                try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientID, key: DefaultKeys.ebayClientId)
                try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientSecret, key: DefaultKeys.ebayClientSecret)
                try APIKeyManager.shared.saveAPIKey(for: Service.bestBuy, key: DefaultKeys.bestBuyRapidApiKey)
                try APIKeyManager.shared.saveAPIKey(for: Service.walmart, key: DefaultKeys.walmartApiKey)
                
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
                let ebayClientID = try APIKeyManager.shared.getAPIKey(for: Service.ebayClientID)
                let ebayClientSecret = try APIKeyManager.shared.getAPIKey(for: Service.ebayClientSecret)
                
                // Check if these are test keys that should be updated
                if ebayClientID.hasPrefix("placeholder_") || ebayClientSecret.hasPrefix("placeholder_") {
                    print("⚠️ Placeholder keys detected, updating with real credentials if available")
                    
                    // eBay API Key
                    let ebayApiKey = SecretKeys.ebayApiKey.isEmpty ? DefaultKeys.ebayApiKey : SecretKeys.ebayApiKey
                    try APIKeyManager.shared.saveAPIKey(for: Service.ebay, key: ebayApiKey)
                    
                    // eBay Client ID
                    let ebayClientId = SecretKeys.ebayClientId.isEmpty ? DefaultKeys.ebayClientId : SecretKeys.ebayClientId
                    try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientID, key: ebayClientId)
                    
                    // eBay Client Secret
                    let ebayClientSecret = SecretKeys.ebayClientSecret.isEmpty ? DefaultKeys.ebayClientSecret : SecretKeys.ebayClientSecret
                    try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientSecret, key: ebayClientSecret)
                } else {
                    print("✅ API keys already exist in keychain")
                    print("✅ eBay Client ID: \(ebayClientID.prefix(4))...")
                    print("✅ eBay Client Secret: \(ebayClientSecret.prefix(4))...")
                }
                
                // Also verify the Best Buy key
                if let bestBuyKey = try? APIKeyManager.shared.getAPIKey(for: BestBuyKeys.rapidAPI) {
                    print("✅ Best Buy RapidAPI key: \(bestBuyKey.prefix(4))...")
                } else {
                    // Try to initialize the Best Buy key specifically
                    initializeBestBuyAPI()
                }
                
            } catch {
                print("❌ Error verifying existing keys: \(error)")
                
                // Try to re-initialize the keys
                forceReinitializeAllKeys()
            }
        }
    }
    
    
    // MARK: - Force reinitialization of all keys
    
    func forceReinitializeAllKeys() {
        print("🔄 Force reinitializing all API keys...")
        
        do {
            // Remove existing keys first
            try? APIKeyManager.shared.deleteAPIKey(for: Service.ebay)
            try? APIKeyManager.shared.deleteAPIKey(for: Service.ebayClientID)
            try? APIKeyManager.shared.deleteAPIKey(for: Service.ebayClientSecret)
            try? APIKeyManager.shared.deleteAPIKey(for: Service.bestBuy)
            try? APIKeyManager.shared.deleteAPIKey(for: BestBuyKeys.rapidAPI)
            try? APIKeyManager.shared.deleteAPIKey(for: Service.walmart)
            
            // eBay API Key
            let ebayApiKey = DefaultKeys.ebayApiKey // Always use default keys for testing
            try APIKeyManager.shared.saveAPIKey(for: Service.ebay, key: ebayApiKey)
            
            // eBay Client ID
            let ebayClientId = DefaultKeys.ebayClientId // Always use default keys for testing
            try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientID, key: ebayClientId)
            
            // eBay Client Secret
            let ebayClientSecret = DefaultKeys.ebayClientSecret // Always use default keys for testing
            try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientSecret, key: ebayClientSecret)
            
            // Best Buy API Key
            let bestBuyApiKey = DefaultKeys.bestBuyRapidApiKeyValue // Always use default keys for testing
            try APIKeyManager.shared.saveAPIKey(for: Service.bestBuy, key: bestBuyApiKey)
            try APIKeyManager.shared.saveAPIKey(for: BestBuyKeys.rapidAPI, key: bestBuyApiKey)
            
            // Walmart API Key
            let walmartApiKey = DefaultKeys.walmartApiKey
            try APIKeyManager.shared.saveAPIKey(for: Service.walmart, key: walmartApiKey)
            
            print("✅ All API keys forcefully reinitialized")
        } catch {
            print("❌ Failed to forcefully reinitialize API keys: \(error)")
        }
    }
    
    // MARK: - Initialize Best Buy API keys
    
    func initializeBestBuyAPI() {
        // Check if keys already exist in keychain
        let needsInitialization = !APIKeyManager.shared.hasAPIKey(for: BestBuyKeys.rapidAPI)
        
        if needsInitialization {
            do {
#if DEBUG
                print("📝 Initializing Best Buy API key...")
                
                // Direct hardcoded key for testing - ensures it always works in debug/demo mode
                let bestBuyAPIKey = "71098ddf86msh32a198c44c7d555p12c439jsn99de5f11bc40"
                try APIKeyManager.shared.saveAPIKey(for: BestBuyKeys.rapidAPI, key: bestBuyAPIKey)
                try APIKeyManager.shared.saveAPIKey(for: Service.bestBuy, key: bestBuyAPIKey)
                
                print("✅ Best Buy API key initialized successfully")
#else
                // Production environment should get keys from a secure source
                // ...
#endif
                
            } catch {
                print("❌ Failed to initialize Best Buy API key: \(error)")
            }
        } else {
            print("📝 Best Buy API key already exists in keychain")
        }
    }
    
    // MARK: - API Services Factory
    
    // BestBuy API service instance
    func createBestBuyService() throws -> BestBuyAPIService {
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: BestBuyKeys.rapidAPI)
            return BestBuyAPIService(apiKey: apiKey)
        } catch {
            // If we can't get the key from keychain, try the direct hardcoded key
            let apiKey = "71098ddf86msh32a198c44c7d555p12c439jsn99de5f11bc40"
            
            // Try to save it to keychain for future use
            try? APIKeyManager.shared.saveAPIKey(for: BestBuyKeys.rapidAPI, key: apiKey)
            
            return BestBuyAPIService(apiKey: apiKey)
        }
    }
    
    
    // MARK: - Best Buy Price Tracker Factory
    
    func createBestBuyPriceTracker() async throws -> BestBuyPriceTracker {
        do {
            let service = try createBestBuyService()
            return await BestBuyPriceTracker(bestBuyService: service)
        } catch {
            throw APIError.authenticationFailed
        }
    }
    
    // Walmart API service instance
    func createWalmartService() async throws -> WalmartAPIService {
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: Service.walmart)
            return await WalmartAPIService(apiKey: apiKey)
        } catch {
            throw APIError.authenticationFailed
        }
    }
    
    // MARK: - Walmart Price Tracker Factory
    
    func createWalmartPriceTracker() async throws -> WalmartPriceTracker {
        do {
            let service = try await createWalmartService()
            return await WalmartPriceTracker(walmartService: service)
        } catch {
            throw APIError.authenticationFailed
        }
    }
    
    // Ebay API service instance
    func createEbayService() throws -> EbayAPIService {
        do {
            // Try to get the key from keychain
            let apiKey = try APIKeyManager.shared.getAPIKey(for: Service.ebay)
            return EbayAPIService(apiKey: apiKey)
        } catch {
            // If keychain retrieval fails, try the default key
            print("⚠️ Using default key for eBay service: \(error)")
            return EbayAPIService(apiKey: DefaultKeys.ebayApiKey)
        }
    }
    
    // MARK: - Development/Testing Helpers
    
#if DEBUG
    // Reset API keys with the latest eBay sandbox credentials
    func resetEbayKeys() {
        do {
            print("🔄 Resetting eBay keys to sandbox credentials...")
            
            // Delete existing keys first
            try? APIKeyManager.shared.deleteAPIKey(for: Service.ebayClientID)
            try? APIKeyManager.shared.deleteAPIKey(for: Service.ebayClientSecret)
            try? APIKeyManager.shared.deleteAPIKey(for: Service.ebay)
            
            // Set the new sandbox keys
            // eBay API Key
            let ebayApiKey = DefaultKeys.ebayApiKey // Always use default keys for testing
            try APIKeyManager.shared.saveAPIKey(for: Service.ebay, key: ebayApiKey)
            
            // eBay Client ID
            let ebayClientId = DefaultKeys.ebayClientId // Always use default keys for testing
            try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientID, key: ebayClientId)
            
            // eBay Client Secret
            let ebayClientSecret = DefaultKeys.ebayClientSecret // Always use default keys for testing
            try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientSecret, key: ebayClientSecret)
            
            print("✅ eBay keys reset successfully")
        } catch {
            print("❌ Failed to reset eBay keys: \(error)")
        }
    }
    
    // Setup development test keys (never use in production)
    func setupTestKeys() {
        do {
            // These would be placeholder/test API keys for development only
            try APIKeyManager.shared.saveAPIKey(for: Service.ebay, key: DefaultKeys.ebayApiKey)
            try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientID, key: DefaultKeys.ebayClientId)
            try APIKeyManager.shared.saveAPIKey(for: Service.ebayClientSecret, key: DefaultKeys.ebayClientSecret)
            try APIKeyManager.shared.saveAPIKey(for: Service.bestBuy, key: DefaultKeys.bestBuyRapidApiKeyValue)
            try APIKeyManager.shared.saveAPIKey(for: BestBuyKeys.rapidAPI, key: DefaultKeys.bestBuyRapidApiKeyValue)
            try APIKeyManager.shared.saveAPIKey(for: Service.walmart, key: DefaultKeys.walmartApiKey)
            
            print("✅ Test API keys set up successfully")
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
    
    // extension SecretKeys {
    //     // Using a computed property to match the pattern in your existing SecretKeys file
    //     static var bestBuyRapidApiKey: String {
    //         return ProcessInfo.processInfo.environment["BEST_BUY_RAPID_API_KEY"] ?? DefaultKeys.bestBuyRapidApiKeyValue
    //     }
    // }
}
