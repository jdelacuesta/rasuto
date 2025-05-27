//
//  WishlistItemCard.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import SwiftUI

struct WishlistItemCard: View {
    @ObservedObject var product: ProductItem
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
        VStack(alignment: .leading, spacing: 0) {
            // Product Image with overlays
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 200)
                            .clipped()
                    case .failure(_):
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 30))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Status indicators overlay
                VStack(spacing: 8) {
                    if product.isTracked {
                        // Tracking indicator
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
                    
                    if !product.isInStock {
                        // Out of stock indicator
                        Text("Out of Stock")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding(8)
            }
            .cornerRadius(8)
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)
                
                // Price with trend
                HStack(spacing: 4) {
                    Text("$\(product.currentPrice, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let change = priceChange {
                        HStack(spacing: 2) {
                            Image(systemName: change < 0 ? "arrow.down" : (change > 0 ? "arrow.up" : "minus"))
                                .font(.system(size: 8, weight: .bold))
                            Text("\(abs(Int(change)))%")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(priceChangeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priceChangeColor.opacity(0.15))
                        .cornerRadius(4)
                    }
                }
                
                // Store and actions
                HStack {
                    Label(product.store, systemImage: storeIcon(for: product.store))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Mini price chart if tracking
                    if product.isTracked && !priceHistory.isEmpty {
                        MiniPriceChart(priceHistory: priceHistory)
                            .frame(width: 40, height: 20)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 4)
        }
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                // Navigate to product detail
            }
        }
        .onLongPressGesture {
            showingTrackingMenu = true
        }
        .contextMenu {
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
        .onAppear {
            loadPriceHistory()
        }
    }
    
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

// Mini price chart component
struct MiniPriceChart: View {
    let priceHistory: [PricePoint]
    
    var body: some View {
        GeometryReader { geometry in
            if priceHistory.count > 1 {
                let minPrice = priceHistory.map { $0.price }.min() ?? 0
                let maxPrice = priceHistory.map { $0.price }.max() ?? 100
                let priceRange = maxPrice - minPrice
                
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
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        ForEach(ProductItem.sampleItems) { product in
            WishlistItemCard(product: product)
        }
    }
    .padding()
}