//
//  ProductCardView.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import SwiftUI

struct ProductCardView: View {
    let product: ProductItem
    @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker
    @EnvironmentObject private var ebayManager: EbayNotificationManager
    
    @State private var isHeartAnimating = false
    @State private var isTrackAnimating = false
    @State private var showingTrackingAlert = false
    
    var cardWidth: CGFloat = 160
    var cardHeight: CGFloat = 240
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image with overlay buttons
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
                        Image(systemName: product.isTracked ? "bell.fill" : "bell")
                            .font(.system(size: 16))
                            .foregroundColor(product.isTracked ? .orange : .white)
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
                        Image(systemName: product.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(product.isFavorite ? .red : .white)
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
                Text(product.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Text("$\(product.currentPrice, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let originalPrice = product.originalPrice,
                       originalPrice > product.currentPrice {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }
                }
                
                // Store Info
                HStack(spacing: 4) {
                    Image(systemName: storeIcon(for: product.store))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(product.store.capitalized)
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
            Text(product.isTracked ? 
                 "You'll be notified when the price drops!" : 
                 "Price tracking has been disabled.")
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            product.isFavorite.toggle()
            isHeartAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isHeartAnimating = false
        }
        
        // Save to wishlist if needed
        if product.isFavorite {
            // Add to wishlist logic here
        }
    }
    
    private func toggleTracking() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            product.isTracked.toggle()
            isTrackAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTrackAnimating = false
        }
        
        // Connect to tracking services
        if product.isTracked {
            startTracking()
        } else {
            stopTracking()
        }
        
        showingTrackingAlert = true
    }
    
    private func startTracking() {
        switch product.store.lowercased() {
        case "bestbuy":
            let productInfo = BestBuyProductInfo(
                sku: product.id,
                name: product.name,
                regularPrice: product.price ?? 0,
                salePrice: product.price,
                onSale: false,
                image: product.imageUrl,
                url: product.productUrl ?? "",
                description: product.description ?? ""
            )
            bestBuyTracker.startTracking(sku: product.id, productInfo: productInfo)
        case "ebay":
            Task {
                do {
                    _ = try await ebayManager.trackItem(
                        id: product.id,
                        name: product.name,
                        currentPrice: product.price,
                        thumbnailUrl: product.imageUrl
                    )
                } catch {
                    print("Failed to track eBay item: \(error)")
                }
            }
        default:
            break
        }
    }
    
    private func stopTracking() {
        switch product.store.lowercased() {
        case "bestbuy":
            bestBuyTracker.stopTracking(for: product.id)
        case "ebay":
            Task {
                do {
                    _ = try await ebayManager.untrackItem(id: product.id)
                } catch {
                    print("Failed to untrack eBay item: \(error)")
                }
            }
        default:
            break
        }
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

// MARK: - Horizontal Card Variant
struct ProductCardHorizontalView: View {
    let product: ProductItem
    @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker
    @EnvironmentObject private var ebayManager: EbayNotificationManager
    
    @State private var isHeartAnimating = false
    @State private var isTrackAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
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
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                
                HStack {
                    Text("$\(product.currentPrice, specifier: "%.2f")")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let originalPrice = product.originalPrice,
                       originalPrice > product.currentPrice {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }
                }
                
                HStack {
                    Label(product.store.capitalized, systemImage: storeIcon(for: product.store))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if product.isTracked {
                        Label("Tracking", systemImage: "bell.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: toggleTracking) {
                    Image(systemName: product.isTracked ? "bell.fill" : "bell")
                        .font(.system(size: 18))
                        .foregroundColor(product.isTracked ? .orange : .gray)
                        .scaleEffect(isTrackAnimating ? 1.2 : 1.0)
                }
                
                Button(action: toggleFavorite) {
                    Image(systemName: product.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(product.isFavorite ? .red : .gray)
                        .scaleEffect(isHeartAnimating ? 1.2 : 1.0)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func toggleFavorite() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            product.isFavorite.toggle()
            isHeartAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isHeartAnimating = false
        }
    }
    
    private func toggleTracking() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            product.isTracked.toggle()
            isTrackAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTrackAnimating = false
        }
        
        // Connect to tracking services
        if product.isTracked {
            switch product.store.lowercased() {
            case "bestbuy":
                let productInfo = BestBuyProductInfo(
                    sku: product.id,
                    name: product.name,
                    regularPrice: product.price ?? 0,
                    salePrice: product.price,
                    onSale: false,
                    image: product.imageUrl,
                    url: product.productUrl ?? "",
                    description: product.description ?? ""
                )
                bestBuyTracker.startTracking(sku: product.id, productInfo: productInfo)
            case "ebay":
                Task {
                    do {
                        _ = try await ebayManager.trackItem(
                            id: product.id,
                            name: product.name,
                            currentPrice: product.price,
                            thumbnailUrl: product.imageUrl
                        )
                    } catch {
                        print("Failed to track eBay item: \(error)")
                    }
                }
            default:
                break
            }
        }
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