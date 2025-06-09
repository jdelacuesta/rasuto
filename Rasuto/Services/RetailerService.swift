//
//  RetailerService.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftUI

// MARK: - Retailer Information Model
struct RetailerInfo: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let isActive: Bool
    let tier: RetailerTier
    let apiType: APIType
    let rateLimit: RateLimitInfo?
    
    enum RetailerTier: String, Codable {
        case core = "Core"      // Tier 1: 15-20 maintained by Rasuto
        case community = "Community"  // Tier 2: Community requested
        case userAdded = "User"       // Tier 3: User-added APIs (future)
    }
    
    enum APIType: String, Codable {
        case rest = "REST"
        case graphql = "GraphQL"
        case webhook = "Webhook"
        case feed = "Feed"
    }
}

// MARK: - Rate Limit Information
struct RateLimitInfo: Codable {
    let callsPerMonth: Int
    let callsPerSecond: Int?
    let resetDate: Date?
}

// MARK: - Retailer Service Manager
@MainActor
final class RetailerServiceManager: ObservableObject {
    static let shared = RetailerServiceManager()
    
    @Published private(set) var activeRetailers: [RetailerInfo] = []
    @Published private(set) var availableRetailers: [RetailerInfo] = []
    @Published private(set) var isLoading = false
    
    private var apiServices: [String: any RetailerAPIService] = [:]
    private let apiConfig = APIConfig()
    
    // Core retailers (Tier 1)
    private let coreRetailers: [RetailerInfo] = [
        RetailerInfo(
            id: "bestbuy",
            name: "Best Buy",
            icon: "tag.fill",
            description: "Electronics and appliances retailer",
            isActive: true,
            tier: .core,
            apiType: .rest,
            rateLimit: RateLimitInfo(callsPerMonth: 1000, callsPerSecond: 5, resetDate: nil)
        ),
        RetailerInfo(
            id: "walmart",
            name: "Walmart",
            icon: "bag.fill",
            description: "General merchandise and grocery retailer",
            isActive: true,
            tier: .core,
            apiType: .rest,
            rateLimit: RateLimitInfo(callsPerMonth: 25, callsPerSecond: 1, resetDate: nil)
        ),
        RetailerInfo(
            id: "ebay",
            name: "eBay",
            icon: "cart.fill",
            description: "Online marketplace and auction site",
            isActive: true,
            tier: .core,
            apiType: .feed,
            rateLimit: RateLimitInfo(callsPerMonth: 5000, callsPerSecond: nil, resetDate: nil)
        ),
        RetailerInfo(
            id: "target",
            name: "Target",
            icon: "target",
            description: "General merchandise retailer",
            isActive: false,
            tier: .core,
            apiType: .rest,
            rateLimit: nil
        ),
        RetailerInfo(
            id: "amazon",
            name: "Amazon",
            icon: "shippingbox.fill",
            description: "E-commerce and cloud computing",
            isActive: false,
            tier: .core,
            apiType: .rest,
            rateLimit: nil
        ),
        RetailerInfo(
            id: "costco",
            name: "Costco",
            icon: "building.2.fill",
            description: "Membership warehouse club",
            isActive: false,
            tier: .core,
            apiType: .rest,
            rateLimit: nil
        ),
        RetailerInfo(
            id: "homedepot",
            name: "Home Depot",
            icon: "hammer.fill",
            description: "Home improvement retailer",
            isActive: false,
            tier: .core,
            apiType: .rest,
            rateLimit: nil
        ),
        RetailerInfo(
            id: "lowes",
            name: "Lowe's",
            icon: "wrench.fill",
            description: "Home improvement retailer",
            isActive: false,
            tier: .core,
            apiType: .rest,
            rateLimit: nil
        ),
        RetailerInfo(
            id: "macys",
            name: "Macy's",
            icon: "star.fill",
            description: "Department store chain",
            isActive: false,
            tier: .core,
            apiType: .rest,
            rateLimit: nil
        ),
        RetailerInfo(
            id: "nordstrom",
            name: "Nordstrom",
            icon: "bag.circle.fill",
            description: "Luxury department store",
            isActive: false,
            tier: .core,
            apiType: .rest,
            rateLimit: nil
        )
    ]
    
    private init() {
        Task {
            await loadRetailers()
        }
    }
    
    // MARK: - Public Methods
    
    func loadRetailers() async {
        isLoading = true
        
        // Load core retailers
        availableRetailers = coreRetailers
        
        // Filter active retailers
        activeRetailers = coreRetailers.filter { $0.isActive }
        
        // Initialize API services for active retailers
        await initializeAPIServices()
        
        isLoading = false
    }
    
    func getAPIService(for retailerId: String) -> (any RetailerAPIService)? {
        return apiServices[retailerId]
    }
    
    func searchProducts(query: String, retailerId: String? = nil) async throws -> [ProductItemDTO] {
        var allProducts: [ProductItemDTO] = []
        
        let retailersToSearch = retailerId != nil 
            ? activeRetailers.filter { $0.id == retailerId }
            : activeRetailers
        
        await withTaskGroup(of: [ProductItemDTO]?.self) { group in
            for retailer in retailersToSearch {
                if let service = apiServices[retailer.id] {
                    group.addTask {
                        do {
                            return try await service.searchProducts(query: query)
                        } catch {
                            print("Error searching \(retailer.name): \(error)")
                            return nil
                        }
                    }
                }
            }
            
            for await products in group {
                if let products = products {
                    allProducts.append(contentsOf: products)
                }
            }
        }
        
        return allProducts
    }
    
    func getProductDetails(productId: String, retailerId: String) async throws -> ProductItemDTO? {
        guard let service = apiServices[retailerId] else {
            throw RetailerServiceError.serviceNotFound(retailerId)
        }
        
        return try await service.getProductDetails(id: productId)
    }
    
    // MARK: - Private Methods
    
    private func initializeAPIServices() async {
        for retailer in activeRetailers {
            switch retailer.id {
            case "bestbuy":
                // BestBuy service removed - now provided via SerpAPI
                break
                
            case "ebay":
                do {
                    let service = try apiConfig.createSerpAPIEbayService()
                    apiServices[retailer.id] = service
                } catch {
                    print("Failed to initialize eBay SerpAPI service: \(error)")
                }
                
            default:
                print("No implementation for \(retailer.name) yet")
            }
        }
    }
    
    // MARK: - Memory Management
    
    func releaseInactiveServices() {
        // Release services for inactive retailers to save memory
        let activeIds = Set(activeRetailers.map { $0.id })
        apiServices = apiServices.filter { activeIds.contains($0.key) }
    }
    
    func preloadService(for retailerId: String) async {
        guard apiServices[retailerId] == nil,
              let retailer = availableRetailers.first(where: { $0.id == retailerId }) else {
            return
        }
        
        // Initialize the service if not already loaded
        switch retailerId {
        case "bestbuy":
            // BestBuy service removed - now provided via SerpAPI
            break
            
        case "ebay":
            do {
                let service = try apiConfig.createSerpAPIEbayService()
                apiServices[retailer.id] = service
            } catch {
                print("Failed to preload eBay SerpAPI service: \(error)")
            }
            
        default:
            break
        }
    }
}

// MARK: - Errors
enum RetailerServiceError: LocalizedError {
    case serviceNotFound(String)
    case apiNotImplemented(String)
    case rateLimitExceeded(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotFound(let retailerId):
            return "API service not found for retailer: \(retailerId)"
        case .apiNotImplemented(let retailerId):
            return "API not yet implemented for retailer: \(retailerId)"
        case .rateLimitExceeded(let retailerId):
            return "Rate limit exceeded for retailer: \(retailerId)"
        }
    }
}

// MARK: - Retailer Service Protocol Extension
extension RetailerAPIService {
    // Default implementations for optional protocol methods
    func trackProduct(product: ProductItemDTO) async throws {
        // Default: No tracking
        print("Tracking not implemented for \(type(of: self))")
    }
    
    func getTrackedProducts() async throws -> [ProductItemDTO] {
        // Default: Return empty array
        return []
    }
}