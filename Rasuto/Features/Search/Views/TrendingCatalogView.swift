//
//  TrendingCatalogView.swift
//  Rasuto
//
//  Created for full trending catalog display on 6/4/25.
//

import SwiftUI

// MARK: - Trending Catalog View

struct TrendingCatalogView: View {
    @ObservedObject var viewModel: MainSearchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredProducts: [ProductItemDTO] {
        if searchText.isEmpty {
            return viewModel.allTrendingProducts  // Show all cached products in "See All"
        } else {
            return viewModel.allTrendingProducts.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("Live data from Google Trends API")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search trending products...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button("Clear") {
                            searchText = ""
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Products Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(filteredProducts, id: \.id) { product in
                            TrendingProductCard(product: product)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .refreshable {
                    await viewModel.refreshTrendingWithLiveAPI()
                }
                
                if filteredProducts.isEmpty && !searchText.isEmpty {
                    // No search results
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No products found")
                            .font(.headline)
                        
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Trending Products")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        Task {
                            await viewModel.refreshTrendingWithLiveAPI()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(viewModel.isLoadingTrending ? 360 : 0))
                            .animation(viewModel.isLoadingTrending ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoadingTrending)
                    }
                    .disabled(viewModel.isLoadingTrending)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
    }
}

// MARK: - Trending Product Card

struct TrendingProductCard: View {
    let product: ProductItemDTO
    @ObservedObject private var wishlistService = WishlistService.shared
    
    var isInWishlist: Bool {
        wishlistService.savedItems.contains { savedItem in
            savedItem.sourceId == product.sourceId && savedItem.source == product.source
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 160)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure(_):
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 160)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.system(size: 30))
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .overlay(
                // Heart button overlay
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            toggleFavorite()
                        }) {
                            Image(systemName: isInWishlist ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                                .foregroundColor(isInWishlist ? .red : .white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                )
                        }
                    }
                    Spacer()
                }
                .padding(8)
            )
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .top)
                
                // Price and Source
                HStack {
                    if let price = product.price {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(product.source)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Availability Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(product.isInStock ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(product.isInStock ? "In Stock" : "Out of Stock")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(product.isInStock ? .green : .red)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func toggleFavorite() {
        Task {
            let productItem = ProductItem.from(product)
            if isInWishlist {
                await wishlistService.removeFromWishlist(productItem.id)
            } else {
                await wishlistService.addToWishlist(productItem)
            }
        }
    }
}

#Preview {
    let viewModel = MainSearchViewModel()
    return TrendingCatalogView(viewModel: viewModel)
}