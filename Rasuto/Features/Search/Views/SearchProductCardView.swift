//
//  SearchProductCardView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 6/3/25.
//

import SwiftUI

struct SearchProductCardView: View {
    let product: ProductItem
    // @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker // REMOVED
    // @EnvironmentObject private var ebayManager: EbayNotificationManager // Commented out - EbayNotificationManager disabled
    
    var cardWidth: CGFloat = 160
    var cardHeight: CGFloat = 240
    
    var body: some View {
        NavigationLink(destination: ProductDetailView(product: product)) {
            ProductCardView(
                product: product,
                cardWidth: cardWidth,
                cardHeight: cardHeight
            )
            // .environmentObject(bestBuyTracker) // REMOVED
            // .environmentObject(ebayManager) // Commented out - EbayNotificationManager disabled
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// For horizontal search results
struct SearchProductHorizontalCardView: View {
    let product: ProductItem
    // @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker // REMOVED
    // @EnvironmentObject private var ebayManager: EbayNotificationManager // Commented out - EbayNotificationManager disabled
    
    var body: some View {
        NavigationLink(destination: ProductDetailView(product: product)) {
            ProductCardHorizontalView(product: product)
                // .environmentObject(bestBuyTracker) // REMOVED
                // .environmentObject(ebayManager) // Commented out - EbayNotificationManager disabled
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    let dto = ProductItemDTO(
        sourceId: "B08N5WRWNW",
        name: "iPhone 15 Pro",
        productDescription: "Latest iPhone with advanced features",
        price: 999.99,
        originalPrice: 1199.99,
        imageURL: URL(string: "https://example.com/iphone.jpg"),
        brand: "Apple",
        source: "Amazon",
        category: "Electronics",
        isInStock: true,
        rating: 4.5,
        reviewCount: 1250,
        productUrl: "https://amazon.com/dp/B08N5WRWNW"
    )
    let sampleProduct = ProductItem.from(dto)
    
    // Legacy API services removed - now using SerpAPI + fallback architecture
    // Services are initialized via APIConfig with proper service factories
    
    NavigationView {
        SearchProductCardView(product: sampleProduct)
            // .environmentObject(notificationManager) // Commented out - EbayNotificationManager disabled
            // .environmentObject(bestBuyPriceTracker) // DISABLED
    }
}