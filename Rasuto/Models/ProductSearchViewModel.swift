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

    private let ebayService: EbayAPIService

    init(ebayService: EbayAPIService? = nil) {
        self.ebayService = ebayService ?? {
            do {
                return try APIConfig.createEbayService()
            } catch {
                print("Failed to create eBay service: \(error)")
                return EbayAPIService(apiKey: "mock_key")
            }
        }()
    }

    func searchProducts(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let ebayResults = try await ebayService.searchProducts(query: query)
            let taggedResults = ebayResults.map { product in
                product.source.isEmpty ? product.with(source: "eBay") : product
            }
            searchResults = taggedResults
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            print("Search error: \(error)")
        }

        isLoading = false
    }

    func getProductDetails(id: String, source: String) async -> ProductItemDTO? {
        isLoading = true
        errorMessage = nil

        do {
            switch source.lowercased() {
            case "ebay":
                let product = try await ebayService.getProductDetails(id: id)
                isLoading = false
                return product
            default:
                errorMessage = "Unsupported retailer: \(source)"
                isLoading = false
                return nil
            }
        } catch {
            errorMessage = "Failed to load product details: \(error.localizedDescription)"
            print("Product details error: \(error)")
            isLoading = false
            return nil
        }
    }

    func trackProduct(_ product: ProductItemDTO) async -> Bool {
        errorMessage = nil
        do {
            switch product.source.lowercased() {
            case "ebay":
                return try await ebayService.trackItem(id: product.sourceId)
            default:
                errorMessage = "Tracking not supported for \(product.source)"
                return false
            }
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
            switch product.source.lowercased() {
            case "ebay":
                let relatedProducts = try await ebayService.getRelatedProducts(id: product.sourceId)
                isLoading = false
                return relatedProducts
            default:
                errorMessage = "Related products not supported for \(product.source)"
                isLoading = false
                return []
            }
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
