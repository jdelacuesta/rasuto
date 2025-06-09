
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
        // BestBuy, Walmart, and eBay provided via SerpAPI
        static let serpAPI = "com.rasuto.api.serpapi"
        static let axessoAmazon = "com.rasuto.api.axesso.amazon"
        static let oxylabs = "com.rasuto.api.oxylabs"
    }
    // BestBuy integration provided via SerpAPI
    
    struct SerpAPIKeys {
        static let main = "com.rasuto.api.serpapi"
        static let googleShopping = "com.rasuto.api.serpapi.google_shopping"
        static let ebayProduction = "com.rasuto.api.serpapi.ebay"
        static let walmartProduction = "com.rasuto.api.serpapi.walmart"
        static let homeDepot = "com.rasuto.api.serpapi.home_depot"
        static let amazon = "com.rasuto.api.serpapi.amazon"
    }
    
    struct AxessoKeys {
        static let primary = "com.rasuto.api.axesso.primary"
        static let secondary = "com.rasuto.api.axesso.secondary"
        static let baseURL = "https://api.axesso.de/amz"
    }
    
    
    // Initialization method - Simplified for SerpAPI + fallbacks architecture
    func initializeAPIKeys() {
        // Check if keys already exist in keychain
        let needsInitialization = !APIKeyManager.shared.hasAPIKey(for: Service.serpAPI) ||
        !APIKeyManager.shared.hasAPIKey(for: Service.axessoAmazon) ||
        !APIKeyManager.shared.hasAPIKey(for: Service.oxylabs)
        
        if needsInitialization {
            do {
                // Load keys for SerpAPI + fallback services only
                print("📝 Initializing API keys for SerpAPI + fallbacks...")
                
                // SerpAPI Key - Primary API layer
                let serpApiKey = DefaultKeys.serpApiKey
                try APIKeyManager.shared.saveAPIKey(for: Service.serpAPI, key: serpApiKey)
                
                // Axesso Amazon API Key
                let axessoApiKey = DefaultKeys.axessoApiKeyPrimary
                try APIKeyManager.shared.saveAPIKey(for: Service.axessoAmazon, key: axessoApiKey)
                
                // Oxylabs API Credentials
                let oxylabsCredentials = "\(DefaultKeys.oxylabsUsername):\(DefaultKeys.oxylabsPassword)"
                try APIKeyManager.shared.saveAPIKey(for: Service.oxylabs, key: oxylabsCredentials)
                
                print("✅ API keys initialized for SerpAPI + fallbacks architecture")
                
            } catch {
                print("❌ Failed to initialize API keys: \(error)")
            }
        } else {
            print("✅ API keys already initialized - SerpAPI + fallbacks ready")
        }
    }
    
    // MARK: - API Services Factory
    
    func createAxessoAmazonService() throws -> AxessoAmazonAPIService {
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: Service.axessoAmazon)
            return AxessoAmazonAPIService(apiKey: apiKey)
        } catch {
            // Fallback to hardcoded key if keychain fails
            print("⚠️ Keychain failed, using fallback Axesso key: \(error)")
            let fallbackKey = DefaultKeys.axessoApiKeyPrimary
            return AxessoAmazonAPIService(apiKey: fallbackKey)
        }
    }
    
    // eBay integration provided via SerpAPI
    
    // MARK: - SerpAPI Services Factory
    
    // SerpAPI Google Shopping service instance
    func createSerpAPIGoogleShoppingService() throws -> SerpAPIService {
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: Service.serpAPI)
            return SerpAPIService.googleShopping(apiKey: apiKey)
        } catch {
            // If keychain retrieval fails, try the default key
            print("⚠️ Using default key for SerpAPI Google Shopping service: \(error)")
            return SerpAPIService.googleShopping(apiKey: DefaultKeys.serpApiKey)
        }
    }
    
    // SerpAPI eBay production service instance
    func createSerpAPIEbayService() throws -> SerpAPIService {
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: Service.serpAPI)
            return SerpAPIService.ebayProduction(apiKey: apiKey)
        } catch {
            // If keychain retrieval fails, try the default key
            print("⚠️ Using default key for SerpAPI eBay service: \(error)")
            return SerpAPIService.ebayProduction(apiKey: DefaultKeys.serpApiKey)
        }
    }
    
    // SerpAPI Walmart production service instance
    func createSerpAPIWalmartService() throws -> SerpAPIService {
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: Service.serpAPI)
            return SerpAPIService.walmartProduction(apiKey: apiKey)
        } catch {
            // If keychain retrieval fails, try the default key
            print("⚠️ Using default key for SerpAPI Walmart service: \(error)")
            return SerpAPIService.walmartProduction(apiKey: DefaultKeys.serpApiKey)
        }
    }
    
    // SerpAPI Home Depot service instance
    func createSerpAPIHomeDepotService() throws -> SerpAPIService {
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: Service.serpAPI)
            return SerpAPIService.homeDepot(apiKey: apiKey)
        } catch {
            // If keychain retrieval fails, try the default key
            print("⚠️ Using default key for SerpAPI Home Depot service: \(error)")
            return SerpAPIService.homeDepot(apiKey: DefaultKeys.serpApiKey)
        }
    }
    
    // SerpAPI Amazon service instance
    func createSerpAPIAmazonService() throws -> SerpAPIService {
        do {
            let apiKey = try APIKeyManager.shared.getAPIKey(for: Service.serpAPI)
            return SerpAPIService.amazon(apiKey: apiKey)
        } catch {
            // If keychain retrieval fails, try the default key
            print("⚠️ Using default key for SerpAPI Amazon service: \(error)")
            return SerpAPIService.amazon(apiKey: DefaultKeys.serpApiKey)
        }
    }
    
    // Oxylabs Scraper service instance
    func createOxylabsService() throws -> OxylabsScraperService {
        // Return the shared instance (credentials are loaded in init)
        return OxylabsScraperService.shared
    }
    
    // Generic SerpAPI service factory with engine selection
    func createSerpAPIService(engine: SerpAPIEngine) throws -> SerpAPIService {
        switch engine {
        case .googleShopping:
            return try createSerpAPIGoogleShoppingService()
        case .ebay:
            return try createSerpAPIEbayService()
        case .walmart:
            return try createSerpAPIWalmartService()
        case .homeDepot:
            return try createSerpAPIHomeDepotService()
        case .amazon:
            return try createSerpAPIAmazonService()
        }
    }
    
    // MARK: - Development/Testing Helpers
    
#if DEBUG
    // Setup development test keys for SerpAPI + fallback architecture
    func setupTestKeys() {
        do {
            // SerpAPI + fallback architecture only
            try APIKeyManager.shared.saveAPIKey(for: Service.serpAPI, key: DefaultKeys.serpApiKey)
            try APIKeyManager.shared.saveAPIKey(for: Service.axessoAmazon, key: DefaultKeys.axessoApiKeyPrimary)
            let oxylabsCredentials = "\(DefaultKeys.oxylabsUsername):\(DefaultKeys.oxylabsPassword)"
            try APIKeyManager.shared.saveAPIKey(for: Service.oxylabs, key: oxylabsCredentials)
            
            print("✅ Test API keys set up successfully for SerpAPI + fallbacks")
        } catch {
            print("Failed to set up test API keys: \(error)")
        }
    }
#endif
    
    // MARK: - Rate Limiting Info
    
    struct RateLimits {
        struct SerpAPI {
            static let monthlyFreeLimit = 100
            static let minimumInterval: TimeInterval = 1.0
            static let burstLimit = 5 // requests per 5 minutes for free tier
        }
        
        struct Axesso {
            static let requestsPerSecond = 1
            static let requestsPerDay = 100
        }
        
        struct Oxylabs {
            static let requestsPerSecond = 2
            static let requestsPerDay = 1000
        }
    }
    
}
