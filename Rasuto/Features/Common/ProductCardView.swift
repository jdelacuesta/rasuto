//
//  ProductCardView.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import SwiftUI

struct ProductCardView: View {
    let product: ProductItem
    // @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker // REMOVED
    // @EnvironmentObject private var ebayManager: EbayNotificationManager // Commented out - EbayNotificationManager disabled
    @ObservedObject private var wishlistService = WishlistService.shared
    @StateObject private var trackingService = ProductTrackingService.shared
    
    @State private var isHeartAnimating = false
    @State private var isTrackAnimating = false
    @State private var showingTrackingAlert = false
    @State private var showingSaveAlert = false
    
    // FIX: Use local state for immediate UI updates, sync with service
    @State private var isProductSaved = false
    
    var cardWidth: CGFloat = 160
    var cardHeight: CGFloat = 240
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image with overlay buttons - Fixed height
            ZStack(alignment: .topTrailing) {
                // Product Image
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: cardWidth, height: cardWidth)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardWidth)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: cardWidth, height: cardWidth)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 30))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Action Buttons Overlay
                HStack(spacing: 8) {
                    // Track Button
                    Button(action: {
                        toggleTracking()
                    }) {
                        Image(systemName: trackingService.isTracking(product) ? "bell.fill" : "bell")
                            .font(.system(size: 16))
                            .foregroundColor(trackingService.isTracking(product) ? .orange : .white)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .blur(radius: 1)
                            )
                            .scaleEffect(isTrackAnimating ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTrackAnimating)
                    }
                    
                    // Heart Button
                    Button(action: {
                        toggleFavorite()
                    }) {
                        Image(systemName: isProductSaved ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(isProductSaved ? .red : .white)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .blur(radius: 1)
                            )
                            .scaleEffect(isHeartAnimating ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHeartAnimating)
                    }
                }
                .padding(8)
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(cleanProductTitle(product.name, brand: product.brand))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("$\(product.currentPrice, specifier: "%.2f")")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if let originalPrice = product.originalPrice,
                       originalPrice > product.currentPrice {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .strikethrough()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                
                // Store Info
                HStack(spacing: 4) {
                    Text(RetailerType.displayName(for: product.source))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if product.isTracked {
                        Spacer()
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .frame(width: cardWidth)
        .alert("Price Tracking", isPresented: $showingTrackingAlert) {
            Button("OK") { }
        } message: {
            Text(trackingService.isTracking(product) ? 
                 "You'll be notified when the price drops!" : 
                 "Price tracking has been disabled.")
        }
        .alert("Saved to Wishlist", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text("'\(product.name)' has been added to your saved items!")
        }
        .onAppear {
            // Initialize local state from service
            isProductSaved = wishlistService.savedItems.contains { savedItem in
                savedItem.sourceId == product.sourceId && savedItem.source == product.source
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleFavorite() {
        // FIX: Update local state immediately for instant UI response
        let wasCurrentlySaved = isProductSaved
        isProductSaved.toggle()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isHeartAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isHeartAnimating = false
        }
        
        // Then sync with service in background
        Task {
            print("🔄 HEART TAPPED: Product \(product.name), Was Saved: \(wasCurrentlySaved), Now: \(isProductSaved)")
            
            if wasCurrentlySaved {
                // Product was saved, so remove it
                if let savedProduct = wishlistService.savedItems.first(where: { 
                    $0.sourceId == product.sourceId && $0.source == product.source 
                }) {
                    print("🗑️ REMOVING: Found saved product with ID \(savedProduct.id)")
                    await wishlistService.removeFromWishlist(savedProduct.id)
                    print("✅ REMOVED: Product removed from wishlist")
                }
            } else {
                // Product was not saved, so add it
                print("💾 SAVING: Converting product to DTO for save...")
                let productDTO = ProductItemDTO.from(product)
                print("💾 SAVING: DTO created - Name: \(productDTO.name), Source: \(productDTO.source), SourceId: \(productDTO.sourceId)")
                
                await wishlistService.saveToWishlist(from: productDTO)
                print("✅ SAVED: Save operation completed")
                
                // Show success notification after a brief delay so heart turns red first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingSaveAlert = true
                }
            }
        }
    }
    
    private func toggleTracking() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isTrackAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTrackAnimating = false
        }
        
        // Use ProductTrackingService for universal tracking
        if trackingService.isTracking(product) {
            trackingService.stopTracking(product)
        } else {
            trackingService.startTracking(product)
        }
        
        showingTrackingAlert = true
    }
    
    private func cleanProductTitle(_ title: String, brand: String) -> String {
        // If brand exists and title is long, create a cleaner format
        if !brand.isEmpty && title.count > 40 {
            // Remove brand from title if it's already there
            var cleanTitle = title
            if title.lowercased().contains(brand.lowercased()) {
                cleanTitle = title.replacingOccurrences(of: brand, with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Truncate if still too long
            if cleanTitle.count > 35 {
                cleanTitle = String(cleanTitle.prefix(35)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            return "\(brand) \(cleanTitle)"
        }
        
        // For shorter titles or no brand, just return original (truncated if needed)
        if title.count > 50 {
            return String(title.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return title
    }
    
}

// MARK: - Horizontal Card Variant
struct ProductCardHorizontalView: View {
    let product: ProductItem
    // @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker // REMOVED
    // @EnvironmentObject private var ebayManager: EbayNotificationManager // Commented out - EbayNotificationManager disabled
    @ObservedObject private var wishlistService = WishlistService.shared
    @StateObject private var trackingService = ProductTrackingService.shared
    
    @State private var isHeartAnimating = false
    @State private var isTrackAnimating = false
    @State private var showingSaveAlert = false
    
    // FIX: Use local state for immediate UI updates, sync with service
    @State private var isProductSavedHorizontal = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Product Image with Discount Badge
            ZStack {
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Discount Badge - better positioned
                if let originalPrice = product.originalPrice,
                   originalPrice > product.currentPrice {
                    let discount = originalPrice - product.currentPrice
                    let discountPercent = Int((discount / originalPrice) * 100)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Text("-\(discountPercent)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    .padding(8)  // More inset from edges
                }
            }
            
            // Product Info - properly aligned
            VStack(alignment: .leading, spacing: 4) {
                Text(cleanProductTitle(product.name, brand: product.brand))
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 4) {
                    Text("$\(product.currentPrice, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if let originalPrice = product.originalPrice,
                       originalPrice > product.currentPrice {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .strikethrough()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    Text(RetailerType.displayName(for: product.source))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if product.isTracked {
                        Label("Tracking", systemImage: "bell.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: toggleTracking) {
                    Image(systemName: trackingService.isTracking(product) ? "bell.fill" : "bell")
                        .font(.system(size: 18))
                        .foregroundColor(trackingService.isTracking(product) ? .orange : .gray)
                        .scaleEffect(isTrackAnimating ? 1.2 : 1.0)
                }
                
                Button(action: toggleFavorite) {
                    Image(systemName: isProductSavedHorizontal ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(isProductSavedHorizontal ? .red : .gray)
                        .scaleEffect(isHeartAnimating ? 1.2 : 1.0)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .alert("Saved to Wishlist", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text("'\(product.name)' has been added to your saved items!")
        }
        .onAppear {
            // Initialize local state from service
            isProductSavedHorizontal = wishlistService.savedItems.contains { savedItem in
                savedItem.sourceId == product.sourceId && savedItem.source == product.source
            }
        }
    }
    
    private func toggleFavorite() {
        // FIX: Update local state immediately for instant UI response
        let wasCurrentlySaved = isProductSavedHorizontal
        isProductSavedHorizontal.toggle()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isHeartAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isHeartAnimating = false
        }
        
        // Then sync with service in background
        Task {
            print("🔄 HEART TAPPED (HORIZONTAL): Product \(product.name), Was Saved: \(wasCurrentlySaved), Now: \(isProductSavedHorizontal)")
            
            if wasCurrentlySaved {
                // Product was saved, so remove it
                if let savedProduct = wishlistService.savedItems.first(where: { 
                    $0.sourceId == product.sourceId && $0.source == product.source 
                }) {
                    print("🗑️ REMOVING (HORIZONTAL): Found saved product with ID \(savedProduct.id)")
                    await wishlistService.removeFromWishlist(savedProduct.id)
                    print("✅ REMOVED (HORIZONTAL): Product removed from wishlist")
                }
            } else {
                // Product was not saved, so add it
                print("💾 SAVING (HORIZONTAL): Converting product to DTO for save...")
                let productDTO = ProductItemDTO.from(product)
                print("💾 SAVING (HORIZONTAL): DTO created - Name: \(productDTO.name), Source: \(productDTO.source), SourceId: \(productDTO.sourceId)")
                
                await wishlistService.saveToWishlist(from: productDTO)
                print("✅ SAVED (HORIZONTAL): Save operation completed")
                
                // Show success notification after a brief delay so heart turns red first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingSaveAlert = true
                }
            }
        }
    }
    
    private func toggleTracking() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isTrackAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTrackAnimating = false
        }
        
        // Use ProductTrackingService for universal tracking
        if trackingService.isTracking(product) {
            trackingService.stopTracking(product)
        } else {
            trackingService.startTracking(product)
        }
    }
    
    private func cleanProductTitle(_ title: String, brand: String) -> String {
        // If brand exists and title is long, create a cleaner format
        if !brand.isEmpty && title.count > 40 {
            // Remove brand from title if it's already there
            var cleanTitle = title
            if title.lowercased().contains(brand.lowercased()) {
                cleanTitle = title.replacingOccurrences(of: brand, with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Truncate if still too long
            if cleanTitle.count > 35 {
                cleanTitle = String(cleanTitle.prefix(35)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            return "\(brand) \(cleanTitle)"
        }
        
        // For shorter titles or no brand, just return original (truncated if needed)
        if title.count > 50 {
            return String(title.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return title
    }
    
    private func storeIcon(for store: String) -> String {
        switch store.lowercased() {
        case "bestbuy":
            return "cart.fill"
        case "ebay":
            return "tag.fill"
        case "walmart":
            return "bag.fill"
        default:
            return "storefront.fill"
        }
    }
}

#Preview("Vertical Card") {
    ScrollView(.horizontal) {
        HStack {
            ProductCardView(product: ProductItem.sampleItem)
            ProductCardView(product: ProductItem.sampleItem2)
        }
        .padding()
    }
}

#Preview("Horizontal Card") {
    VStack {
        ProductCardHorizontalView(product: ProductItem.sampleItem)
        ProductCardHorizontalView(product: ProductItem.sampleItem2)
    }
    .padding()
}