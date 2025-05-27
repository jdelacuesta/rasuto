//
//  WishlistItemCard.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import SwiftUI

struct WishlistItemCard: View {
    let product: ProductItem
    @State private var isPressed = false
    @State private var showingTrackingMenu = false
    @State private var priceHistory: [PricePoint] = []
    
    var priceChange: Double? {
        guard let originalPrice = product.originalPrice, originalPrice > 0 else { return nil }
        return ((product.currentPrice - originalPrice) / originalPrice) * 100
    }
    
    var priceChangeColor: Color {
        guard let change = priceChange else { return .primary }
        return change < 0 ? .green : (change > 0 ? .red : .primary)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            productImage
            productInfo
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(.spring(response: 0.3), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
        .contextMenu {
            contextMenuItems
        }
        .onAppear {
            loadPriceHistory()
        }
    }
    
    // MARK: - Components
    
    private var productImage: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.system(size: 30))
                    )
            }
            .frame(height: 200)
            .clipped()
            
            // Status indicators
            VStack(spacing: 8) {
                if product.isTracked {
                    trackingBadge
                }
                
                if !product.isInStock {
                    outOfStockBadge
                }
            }
            .padding(8)
        }
    }
    
    private var trackingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "bell.fill")
                .font(.system(size: 10))
            Text("Tracking")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange)
        .cornerRadius(12)
    }
    
    private var outOfStockBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text("Out of Stock")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red)
        .cornerRadius(12)
    }
    
    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Store badge
            HStack(spacing: 4) {
                Image(systemName: storeIcon(for: product.store))
                    .font(.system(size: 12))
                Text(product.store.capitalized)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.secondary)
            
            // Product name
            Text(product.name)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Price section
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("$\(String(format: "%.2f", product.currentPrice))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let change = priceChange, abs(change) > 0.01 {
                        HStack(spacing: 4) {
                            Image(systemName: change < 0 ? "arrow.down" : "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(String(format: "%.1f", abs(change)))%")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(priceChangeColor)
                    }
                }
                
                Spacer()
                
                // Mini price chart if tracking
                if product.isTracked && !priceHistory.isEmpty {
                    MiniPriceChart(priceHistory: priceHistory)
                        .frame(width: 40, height: 20)
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        if product.isTracked {
            Button(action: { /* Stop tracking */ }) {
                Label("Stop Tracking", systemImage: "bell.slash")
            }
            
            Button(action: { /* View price history */ }) {
                Label("View Price History", systemImage: "chart.line.uptrend.xyaxis")
            }
        } else {
            Button(action: { /* Start tracking */ }) {
                Label("Start Tracking", systemImage: "bell")
            }
        }
        
        Button(action: { /* Share */ }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Button(role: .destructive, action: { /* Remove from wishlist */ }) {
            Label("Remove from Wishlist", systemImage: "trash")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadPriceHistory() {
        // Simulate price history for demo
        if product.isTracked {
            priceHistory = (0..<7).map { daysAgo in
                PricePoint(
                    date: Date().addingTimeInterval(-Double(daysAgo * 86400)),
                    price: product.currentPrice + Double.random(in: -20...20),
                    currency: product.currency ?? "USD"
                )
            }.reversed()
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

// MARK: - Supporting Types

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
    let currency: String
}

// MARK: - Mini Price Chart

struct MiniPriceChart: View {
    let priceHistory: [PricePoint]
    
    var body: some View {
        GeometryReader { geometry in
            if priceHistory.count > 1 {
                let minPrice = priceHistory.map { $0.price }.min() ?? 0
                let maxPrice = priceHistory.map { $0.price }.max() ?? 100
                let priceRange = max(maxPrice - minPrice, 1) // Avoid division by zero
                
                Path { path in
                    for (index, point) in priceHistory.enumerated() {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(priceHistory.count - 1)
                        let y = geometry.size.height * (1 - (point.price - minPrice) / priceRange)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    priceHistory.last!.price < priceHistory.first!.price ? Color.green : Color.red,
                    lineWidth: 2
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WishlistItemCard(product: ProductItem.sampleItems[0])
        .padding()
}