//
//  WishlistService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/21/25.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class WishlistService: ObservableObject {
    private var modelContext: ModelContext?
    @Published var savedItems: [ProductItem] = []
    @Published var errorMessage: String?
    
    init() {
        setupModelContext()
        loadSavedItems()
    }
    
    private func setupModelContext() {
        guard let container = ModelContainerManager.shared.container else {
            errorMessage = "Database not available"
            return
        }
        modelContext = ModelContext(container)
    }
    
    // MARK: - Core Wishlist Operations
    
    func saveToWishlist(from productDTO: ProductItemDTO) async {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        do {
            // Simple approach: fetch all ProductItems and filter in memory
            let allProducts = try context.fetch(FetchDescriptor<ProductItem>())
            let existingProduct = allProducts.first { product in
                product.sourceId == productDTO.sourceId && product.source == productDTO.source
            }
            
            if let existing = existingProduct {
                // Update existing product
                existing.isFavorite = true
                existing.lastChecked = Date()
            } else {
                // Create new product
                let newProduct = createProductItem(from: productDTO)
                context.insert(newProduct)
            }
            
            try context.save()
            await loadSavedItems()
            
        } catch {
            errorMessage = "Failed to save item: \(error.localizedDescription)"
        }
    }
    
    private func createProductItem(from dto: ProductItemDTO) -> ProductItem {
        let product = ProductItem(
            name: dto.name,
            productDescription: dto.productDescription ?? "",
            price: dto.price,
            currency: dto.currency ?? "USD",
            brand: dto.brand,
            source: dto.source,
            sourceId: dto.sourceId,
            category: dto.category ?? "",
            imageURL: dto.imageURL,
            isInStock: dto.isInStock
        )
        
        // Set additional properties
        product.originalPrice = dto.originalPrice
        product.rating = dto.rating
        product.reviewCount = dto.reviewCount
        product.isFavorite = true
        product.isTracked = false
        product.currentSyncStatus = .pending // Mark for CloudKit sync
        
        // Set image URLs
        if let imageUrls = dto.imageUrls {
            product.imageUrls = imageUrls
        }
        product.thumbnailUrl = dto.thumbnailUrl
        
        return product
    }
    
    func addToWishlist(_ product: ProductItem) async {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        do {
            product.isFavorite = true
            product.lastChecked = Date()
            try context.save()
            loadSavedItems()
        } catch {
            errorMessage = "Failed to add to wishlist: \(error.localizedDescription)"
        }
    }
    
    func removeFromWishlist(_ productId: UUID) async {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        do {
            // Optimized query to find specific product
            let descriptor = FetchDescriptor<ProductItem>(
                predicate: #Predicate { item in item.id == productId }
            )
            
            if let product = try context.fetch(descriptor).first {
                if product.isTracked {
                    // Keep item but remove from favorites
                    product.isFavorite = false
                } else {
                    // Delete completely if not tracked
                    context.delete(product)
                }
                try context.save()
                await loadSavedItems()
            }
        } catch {
            errorMessage = "Failed to remove item: \(error.localizedDescription)"
        }
    }
    
    func toggleFavorite(productId: UUID) async {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        do {
            // Optimized query to find specific product
            let descriptor = FetchDescriptor<ProductItem>(
                predicate: #Predicate { item in item.id == productId }
            )
            
            if let product = try context.fetch(descriptor).first {
                product.isFavorite.toggle()
                product.lastChecked = Date()
                product.currentSyncStatus = .pending // Mark for CloudKit sync
                try context.save()
                await loadSavedItems()
            }
        } catch {
            errorMessage = "Failed to toggle favorite: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Batch Operations
    
    func batchInsertProducts(_ products: [ProductItemDTO]) async {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        do {
            // Disable auto-save for batch operations
            context.autosaveEnabled = false
            defer { context.autosaveEnabled = true }
            
            for productDTO in products {
                // Check if product already exists
                let descriptor = FetchDescriptor<ProductItem>(
                    predicate: #Predicate { item in
                        item.sourceId == productDTO.sourceId && item.source == productDTO.source
                    }
                )
                
                let existingProducts = try context.fetch(descriptor)
                if existingProducts.isEmpty {
                    let product = createProductItem(from: productDTO)
                    context.insert(product)
                }
            }
            
            try context.save()
            loadSavedItems()
        } catch {
            errorMessage = "Failed to batch insert products: \(error.localizedDescription)"
        }
    }
    
    func loadProductsByCategory(_ category: String) -> [ProductItem] {
        guard let context = modelContext else { return [] }
        
        do {
            var descriptor = FetchDescriptor<ProductItem>(
                predicate: #Predicate { item in item.category == category },
                sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
            )
            descriptor.fetchLimit = 50
            
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }
    
    // MARK: - Data Loading
    
    func loadSavedItems() {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        do {
            // Optimized query with predicate and sorting
            var descriptor = FetchDescriptor<ProductItem>(
                predicate: #Predicate { item in item.isFavorite == true },
                sortBy: [SortDescriptor(\.lastChecked, order: .reverse)]
            )
            descriptor.fetchLimit = 100 // Limit for performance
            
            savedItems = try context.fetch(descriptor)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load saved items: \(error.localizedDescription)"
            savedItems = []
        }
    }
    
    // MARK: - Collection Operations
    
    func addToCollection(productId: UUID, collectionId: UUID) async {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        do {
            // Simple approach: fetch all and filter
            let allProducts = try context.fetch(FetchDescriptor<ProductItem>())
            let allCollections = try context.fetch(FetchDescriptor<Collection>())
            
            if let product = allProducts.first(where: { $0.id == productId }),
               let collection = allCollections.first(where: { $0.id == collectionId }) {
                if collection.productItem == nil {
                    collection.productItem = []
                }
                collection.productItem?.append(product)
                try context.save()
            }
        } catch {
            errorMessage = "Failed to add to collection: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Search and Filter
    
    func searchSavedItems(query: String) -> [ProductItem] {
        if query.isEmpty {
            return savedItems
        }
        
        return savedItems.filter { item in
            item.name.localizedCaseInsensitiveContains(query) ||
            item.brand.localizedCaseInsensitiveContains(query) ||
            item.productDescription.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getSavedItemsBySource(_ source: String) -> [ProductItem] {
        return savedItems.filter { $0.source == source }
    }
    
    // MARK: - Statistics
    
    var totalSavedItems: Int {
        savedItems.count
    }
    
    var averagePrice: Double {
        guard !savedItems.isEmpty else { return 0 }
        let itemsWithPrices = savedItems.compactMap { $0.price }
        guard !itemsWithPrices.isEmpty else { return 0 }
        let total = itemsWithPrices.reduce(0, +)
        return total / Double(itemsWithPrices.count)
    }
    
    func itemsBySource() -> [String: Int] {
        Dictionary(grouping: savedItems, by: \.source)
            .mapValues { $0.count }
    }
}