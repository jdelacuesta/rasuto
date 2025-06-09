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
    static let shared = WishlistService()
    
    @Published var savedItems: [ProductItem] = []
    @Published var errorMessage: String?
    
    // We'll set this from the environment when views load
    var modelContext: ModelContext?
    
    // MOCK DATA for demo purposes - track saved items in memory
    private var mockSavedItems: Set<String> = []
    
    private init() {
        print("✅ WishlistService: Singleton initialized")
        // Don't load items yet - wait for context to be set
    }
    
    func setModelContext(_ context: ModelContext) {
        print("✅ WishlistService: ModelContext set from environment")
        self.modelContext = context
        loadSavedItems()
    }
    
    // MARK: - Core Wishlist Operations
    
    func saveToWishlist(from productDTO: ProductItemDTO) async {
        print("💾 WishlistService: Saving product \(productDTO.name) from \(productDTO.source)")
        
        // MOCK IMPLEMENTATION for demo
        let mockKey = "\(productDTO.source)_\(productDTO.sourceId)"
        
        if !mockSavedItems.contains(mockKey) {
            mockSavedItems.insert(mockKey)
            
            // Create ProductItem from DTO for UI display
            let newProduct = createProductItemForDisplay(from: productDTO)
            savedItems.append(newProduct)
            
            print("✅ MOCK: Added \(productDTO.name) to saved items")
            print("📊 MOCK: Total saved items: \(savedItems.count)")
            
            // Trigger UI update
            objectWillChange.send()
        } else {
            print("⚠️ MOCK: Product already saved")
        }
    }
    
    // Helper method to create ProductItem for display (not database)
    private func createProductItemForDisplay(from dto: ProductItemDTO) -> ProductItem {
        let product = ProductItem(
            name: dto.name,
            productDescription: dto.productDescription ?? "",
            price: dto.price,
            currency: dto.currency ?? "USD",
            url: dto.productUrl != nil ? URL(string: dto.productUrl!) : nil,
            brand: dto.brand,
            source: dto.source,
            sourceId: dto.sourceId,
            category: dto.category ?? "",
            imageURL: dto.imageURL,
            isInStock: dto.isInStock
        )
        
        // Set additional properties
        product.id = dto.id
        product.originalPrice = dto.originalPrice
        product.isFavorite = true
        product.isTracked = false
        
        if let imageUrls = dto.imageUrls {
            product.imageUrls = imageUrls
        }
        
        product.thumbnailUrl = dto.thumbnailUrl ?? dto.imageURL?.absoluteString
        
        if product.thumbnailUrl == nil && product.imageUrls.isEmpty,
           let imageURL = dto.imageURL {
            product.imageUrls = [imageURL.absoluteString]
        }
        
        product.rating = dto.rating
        product.reviewCount = dto.reviewCount
        
        return product
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
        print("💾 WishlistService: Adding product \(product.name) from \(product.source)")
        
        // MOCK IMPLEMENTATION for immediate demo functionality
        let mockKey = "\(product.source)_\(product.sourceId)"
        
        if !mockSavedItems.contains(mockKey) {
            mockSavedItems.insert(mockKey)
            
            // Create a display copy of the product
            let displayProduct = createProductItemForDisplay(from: ProductItemDTO.from(product))
            savedItems.append(displayProduct)
            
            print("✅ MOCK: Added \(product.name) to saved items")
            print("📊 MOCK: Total saved items: \(savedItems.count)")
            
            // Force immediate UI update
            await MainActor.run {
                objectWillChange.send()
            }
        } else {
            print("⚠️ MOCK: Product already saved")
        }
        
        // TODO: Implement real database persistence later
        /*
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        do {
            context.insert(product)
            product.isFavorite = true
            product.lastChecked = Date()
            try context.save()
            await loadSavedItems()
        } catch {
            errorMessage = "Failed to add to wishlist: \(error.localizedDescription)"
        }
        */
    }
    
    func removeFromWishlist(_ productId: UUID) async {
        // MOCK IMPLEMENTATION for demo
        if let index = savedItems.firstIndex(where: { $0.id == productId }) {
            let product = savedItems[index]
            let mockKey = "\(product.source)_\(product.sourceId)"
            
            mockSavedItems.remove(mockKey)
            savedItems.remove(at: index)
            
            print("✅ MOCK: Removed \(product.name) from saved items")
            print("📊 MOCK: Total saved items: \(savedItems.count)")
            
            // Trigger UI update
            objectWillChange.send()
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
        print("🔍 WishlistService: Loading saved items (MOCK mode)")
        print("📊 MOCK: Current saved items count: \(savedItems.count)")
        
        // Mock mode - items are already in savedItems array
        for (index, item) in savedItems.prefix(3).enumerated() {
            print("📦 MOCK Item \(index + 1): \(item.name) - isFavorite: \(item.isFavorite)")
        }
        
        errorMessage = nil
    }
    
    // MARK: - Collection Operations
    
    // Track wishlist assignments in memory for demo
    @Published private var wishlistAssignments: [String: Set<UUID>] = [:]
    
    func getItemCount(for wishlistName: String) -> Int {
        return wishlistAssignments[wishlistName]?.count ?? 0
    }
    
    func assignItemsToWishlist(_ itemIds: Set<UUID>, wishlistName: String) {
        if wishlistAssignments[wishlistName] == nil {
            wishlistAssignments[wishlistName] = Set<UUID>()
        }
        
        for itemId in itemIds {
            wishlistAssignments[wishlistName]?.insert(itemId)
        }
        
        print("✅ Assigned \(itemIds.count) items to wishlist: \(wishlistName)")
        print("📊 Wishlist \(wishlistName) now has \(getItemCount(for: wishlistName)) items")
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    func getItemsForWishlist(_ wishlistName: String) -> [ProductItem] {
        guard let assignedIds = wishlistAssignments[wishlistName] else { return [] }
        return savedItems.filter { assignedIds.contains($0.id) }
    }
    
    func getFirstItemImageURL(for wishlistName: String) -> String? {
        let items = getItemsForWishlist(wishlistName)
        return items.first?.imageUrl
    }
    
    func removeItemFromWishlist(_ itemId: UUID, wishlistName: String) {
        wishlistAssignments[wishlistName]?.remove(itemId)
        
        print("🗑️ Removed item from wishlist: \(wishlistName)")
        print("📊 Wishlist \(wishlistName) now has \(getItemCount(for: wishlistName)) items")
        
        // Trigger UI update
        objectWillChange.send()
    }
    
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