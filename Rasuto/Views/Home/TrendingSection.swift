//
//  TrendingItems.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct TrendingSection: View {
    @State private var trendingProducts: [ProductItem] = []
    @State private var isLoading = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    Text("Trending")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button("See All") {
                    // Navigate to trending list
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .frame(height: 300)
                    Spacer()
                }
            } else if trendingProducts.isEmpty {
                EmptyStateView(
                    icon: "flame",
                    title: "No Trending Items",
                    subtitle: "Check back later for popular products"
                )
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(trendingProducts.prefix(4)) { product in
                        TrendingProductCard(product: product)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            loadTrendingProducts()
        }
    }
    
    private func loadTrendingProducts() {
        // Simulate loading trending products
        withAnimation(.spring()) {
            trendingProducts = Array(ProductItem.sampleItems.shuffled().prefix(4))
        }
    }
}

struct TrendingProductCard: View {
    @ObservedObject var product: ProductItem
    @State private var isPressed = false
    @State private var isHeartAnimating = false
    @State private var isTrackAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Product Image
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(height: 140)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(height: 140)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 30))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Action Buttons
                VStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            product.isTracked.toggle()
                            isTrackAnimating = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTrackAnimating = false
                        }
                    }) {
                        Image(systemName: product.isTracked ? "bell.fill" : "bell")
                            .font(.system(size: 14))
                            .foregroundColor(product.isTracked ? .orange : .white)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                            )
                            .scaleEffect(isTrackAnimating ? 1.2 : 1.0)
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            product.isFavorite.toggle()
                            isHeartAnimating = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isHeartAnimating = false
                        }
                    }) {
                        Image(systemName: product.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(product.isFavorite ? .red : .white)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                            )
                            .scaleEffect(isHeartAnimating ? 1.2 : 1.0)
                    }
                }
                .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Text("$\(product.currentPrice, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                    
                    if let originalPrice = product.originalPrice,
                       originalPrice > product.currentPrice {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: storeIcon(for: product.store))
                        .font(.system(size: 10))
                    Text(product.store)
                        .font(.system(size: 11))
                    
                    if let rating = product.rating {
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 11))
                        }
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            // Handle tap to view product details
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
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
