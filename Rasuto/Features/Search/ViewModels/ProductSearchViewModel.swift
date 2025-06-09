//
//  ProductSearchViewModel.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/29/25.
//

import Foundation
import SwiftUI

@MainActor
class ProductSearchViewModel: ObservableObject {
    @Published var searchResults: [ProductItemDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let serpEbayService: SerpAPIService
    private let serpGoogleService: SerpAPIService
    private let axessoService: AxessoAmazonAPIService

    init() {
        let apiConfig = APIConfig()
        
        // Initialize services with fallback support
        do {
            self.serpEbayService = try apiConfig.createSerpAPIEbayService()
        } catch {
            print("Failed to create SerpAPI eBay service: \(error)")
            self.serpEbayService = SerpAPIService.ebayProduction(apiKey: DefaultKeys.serpApiKey)
        }
        
        do {
            self.serpGoogleService = try apiConfig.createSerpAPIGoogleShoppingService()
        } catch {
            print("Failed to create SerpAPI Google service: \(error)")
            self.serpGoogleService = SerpAPIService.googleShopping(apiKey: DefaultKeys.serpApiKey)
        }
        
        do {
            self.axessoService = try apiConfig.createAxessoAmazonService()
        } catch {
            print("Failed to create Axesso service: \(error)")
            self.axessoService = AxessoAmazonAPIService(apiKey: DefaultKeys.axessoApiKeyPrimary)
        }
    }

    func searchProducts(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        var allResults: [ProductItemDTO] = []
        
        // Search across multiple services concurrently
        await withTaskGroup(of: [ProductItemDTO].self) { group in
            // SerpAPI eBay
            group.addTask {
                do {
                    let results = try await self.serpEbayService.searchProducts(query: query)
                    return results.map { $0.source.isEmpty ? $0.with(source: "eBay") : $0 }
                } catch {
                    print("SerpAPI eBay search error: \(error)")
                    return []
                }
            }
            
            // SerpAPI Google Shopping
            group.addTask {
                do {
                    let results = try await self.serpGoogleService.searchProducts(query: query)
                    return results.map { $0.source.isEmpty ? $0.with(source: "Google Shopping") : $0 }
                } catch {
                    print("SerpAPI Google search error: \(error)")
                    return []
                }
            }
            
            // Axesso Amazon
            group.addTask {
                do {
                    let results = try await self.axessoService.searchProducts(query: query)
                    return results.map { $0.source.isEmpty ? $0.with(source: "Amazon") : $0 }
                } catch {
                    print("Axesso Amazon search error: \(error)")
                    return []
                }
            }
            
            // Collect all results
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }
        
        searchResults = allResults
        isLoading = false
    }

    func getProductDetails(id: String, source: String) async -> ProductItemDTO? {
        isLoading = true
        errorMessage = nil

        do {
            let product: ProductItemDTO
            switch source.lowercased() {
            case "ebay":
                product = try await serpEbayService.getProductDetails(id: id)
            case "amazon":
                product = try await axessoService.getProductDetails(id: id)
            case "google shopping":
                product = try await serpGoogleService.getProductDetails(id: id)
            default:
                errorMessage = "Unsupported retailer: \(source)"
                isLoading = false
                return nil
            }
            isLoading = false
            return product
        } catch {
            errorMessage = "Failed to load product details: \(error.localizedDescription)"
            print("Product details error: \(error)")
            isLoading = false
            return nil
        }
    }

    func trackProduct(_ product: ProductItemDTO) async -> Bool {
        errorMessage = nil
        // Note: Tracking functionality would need to be implemented per service
        // For now, we'll use a generic approach
        do {
            // Store in local tracking system (this would be implemented separately)
            print("Tracking product: \(product.name) from \(product.source)")
            return true
        } catch {
            errorMessage = "Failed to track product: \(error.localizedDescription)"
            print("Tracking error: \(error)")
            return false
        }
    }

    func getRelatedProducts(product: ProductItemDTO) async -> [ProductItemDTO] {
        isLoading = true
        errorMessage = nil

        do {
            let relatedProducts: [ProductItemDTO]
            switch product.source.lowercased() {
            case "ebay":
                relatedProducts = try await serpEbayService.getRelatedProducts(id: product.sourceId)
            case "amazon":
                relatedProducts = try await axessoService.getRelatedProducts(id: product.sourceId)
            case "google shopping":
                relatedProducts = try await serpGoogleService.getRelatedProducts(id: product.sourceId)
            default:
                errorMessage = "Related products not supported for \(product.source)"
                isLoading = false
                return []
            }
            isLoading = false
            return relatedProducts
        } catch {
            errorMessage = "Failed to load related products: \(error.localizedDescription)"
            print("Related products error: \(error)")
            isLoading = false
            return []
        }
    }
}

extension ProductItemDTO {
    func with(source: String) -> ProductItemDTO {
        return ProductItemDTO(
            sourceId: self.sourceId,
            name: self.name,
            productDescription: self.productDescription,
            price: self.price,
            originalPrice: self.originalPrice,
            currency: self.currency,
            imageURL: self.imageURL,
            imageUrls: self.imageUrls,
            thumbnailUrl: self.thumbnailUrl,
            brand: self.brand,
            source: source,
            category: self.category,
            isInStock: self.isInStock,
            rating: self.rating,
            reviewCount: self.reviewCount
        )
    }
}
