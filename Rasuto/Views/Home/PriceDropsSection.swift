//
//  PriceDrops.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct PriceDropsSection: View {
    @State private var priceDropProducts: [ProductItem] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text("Price Drops & Alerts")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button("See All") {
                    // Navigate to price drops list
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .frame(height: 120)
                    Spacer()
                }
            } else if priceDropProducts.isEmpty {
                EmptyStateView(
                    icon: "arrow.down.circle",
                    title: "No Price Drops",
                    subtitle: "Track items to get notified of price changes"
                )
                .frame(height: 120)
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(priceDropProducts.prefix(3)) { product in
                        PriceDropItemCard(product: product)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            loadPriceDrops()
        }
    }
    
    private func loadPriceDrops() {
        // Simulate loading products with price drops
        withAnimation {
            priceDropProducts = ProductItem.sampleItems.filter { item in
                item.originalPrice != nil && item.currentPrice < item.originalPrice!
            }
        }
    }
}

struct PriceDropItemCard: View {
    @ObservedObject var product: ProductItem
    @State private var isAnimating = false
    
    var priceDropPercentage: Int {
        guard let originalPrice = product.originalPrice, originalPrice > 0 else { return 0 }
        let drop = ((originalPrice - product.currentPrice) / originalPrice) * 100
        return Int(drop)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(ProgressView().scaleEffect(0.5))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure(_):
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let originalPrice = product.originalPrice {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.system(size: 13))
                            .strikethrough()
                            .foregroundColor(.gray)
                    }
                    
                    Text("$\(product.currentPrice, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                    
                    if priceDropPercentage > 0 {
                        Text("-\(priceDropPercentage)%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: storeIcon(for: product.store))
                        .font(.system(size: 11))
                    Text(product.store)
                        .font(.system(size: 12))
                    
                    if product.isTracked {
                        Spacer()
                        Label("Tracking", systemImage: "bell.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        product.isFavorite.toggle()
                    }
                }) {
                    Image(systemName: product.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(product.isFavorite ? .red : .gray)
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        product.isTracked.toggle()
                    }
                }) {
                    Image(systemName: product.isTracked ? "bell.fill" : "bell")
                        .font(.system(size: 16))
                        .foregroundColor(product.isTracked ? .orange : .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            if priceDropPercentage > 0 {
                isAnimating = true
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
