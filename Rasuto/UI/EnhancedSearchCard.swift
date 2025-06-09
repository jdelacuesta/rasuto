//
//  EnhancedSearchCard.swift
//  Rasuto
//
//  Created for enhanced search modal experience on 6/4/25.
//

import SwiftUI

// MARK: - Enhanced Search Card with Retailer Selection

struct EnhancedSearchCard: View {
    @State private var searchText = ""
    @State private var selectedRetailer = RetailerType.all
    @State private var showRetailerPicker = false
    @State private var searchResults: [ProductItemDTO] = []
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var searchManager = UniversalSearchManager()
    @ObservedObject private var wishlistService = WishlistService.shared
    private let persistentCache = PersistentProductCache.shared
    
    let onProductSelected: (ProductItemDTO) -> Void
    
    var body: some View {
        ZStack {
            // Background to ensure full screen coverage
            Color(colorScheme == .dark ? UIColor.systemBackground : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top bar with exit button - matching AddItemView style
                HStack {
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Left-aligned header - matching SavedDashboardView title style
                        HStack {
                            Text("Search Products")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        
                        // Search Bar with Retailer Selection
                        VStack(spacing: 16) {
                            // Retailer Selection Pills
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(RetailerType.allCases, id: \.self) { retailer in
                                        RetailerPill(
                                            retailer: retailer,
                                            isSelected: selectedRetailer == retailer,
                                            onTap: {
                                                selectedRetailer = retailer
                                                if !searchText.isEmpty {
                                                    performFilteredSearch()
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // Search Input - matching AddItemView style
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Search products...", text: $searchText)
                                        .focused($isSearchFocused)
                                        .submitLabel(.search)
                                        .onSubmit {
                                            performFilteredSearch()
                                        }
                                        .onChange(of: searchText) { newValue in
                                            handleSearchTextChange(newValue)
                                        }
                                    
                                    if isSearching {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    } else if !searchText.isEmpty {
                                        Button(action: {
                                            searchText = ""
                                            searchResults = []
                                            searchManager.clearResults()
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSearchFocused = true
                            }
                        }
                        
                        // Divider line for consistency
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 1)
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                        
                        // Search Results or Empty State
                        if !searchText.isEmpty && !searchResults.isEmpty {
                            // Results displayed as horizontal cards
                            searchResultsSection
                        } else if isSearching {
                            // Loading State
                            loadingStateView
                        } else if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                            // No Results State
                            noResultsStateView
                        } else {
                            // Empty State with Trending Searches
                            trendingSearchesSection
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Retailer Selection Pill
    
    private struct RetailerPill: View {
        let retailer: RetailerType
        let isSelected: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    retailer.icon
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : retailer.color)
                    
                    Text(retailer.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? retailer.color : Color(.systemGray6))
                        .stroke(isSelected ? Color.clear : retailer.color.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Search Results Section with Horizontal Cards
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search Results")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(searchResults.count) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Vertical list of horizontal product cards
            LazyVStack(spacing: 12) {
                ForEach(searchResults, id: \.id) { product in
                    SearchResultHorizontalCard(
                        product: product,
                        isInWishlist: isProductInWishlist(product),
                        onTap: {
                            onProductSelected(product)
                            dismiss()
                        },
                        onToggleFavorite: {
                            toggleFavorite(product)
                        },
                        onToggleTracking: {
                            toggleTracking(product)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Search Result Horizontal Card
    
    private struct SearchResultHorizontalCard: View {
        let product: ProductItemDTO
        let isInWishlist: Bool
        let onTap: () -> Void
        let onToggleFavorite: () -> Void
        let onToggleTracking: () -> Void
        
        @State private var isHeartAnimating = false
        @State private var isTrackAnimating = false
        
        var body: some View {
            HStack(spacing: 12) {
                // Product Image
                AsyncImage(url: product.imageURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                            )
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
                                    .font(.system(size: 20))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .onTapGesture {
                    onTap()
                }
                
                // Product Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(product.source)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer(minLength: 0)
                    
                    HStack {
                        // Price
                        if let price = product.price {
                            Text("$\(price, specifier: "%.2f")")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
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
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 8) {
                    // Track Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isTrackAnimating.toggle()
                        }
                        onToggleTracking()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isTrackAnimating = false
                        }
                    }) {
                        Image(systemName: product.isTracked ? "bell.fill" : "bell")
                            .font(.system(size: 16))
                            .foregroundColor(product.isTracked ? .orange : .gray)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray6))
                            )
                            .scaleEffect(isTrackAnimating ? 1.2 : 1.0)
                    }
                    
                    // Heart Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isHeartAnimating.toggle()
                        }
                        onToggleFavorite()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isHeartAnimating = false
                        }
                    }) {
                        Image(systemName: isInWishlist ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(isInWishlist ? .red : .gray)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray6))
                            )
                            .scaleEffect(isHeartAnimating ? 1.2 : 1.0)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Search Result Card (ProductCardView style)
    
    private struct SearchResultCard: View {
        let product: ProductItemDTO
        let isInWishlist: Bool
        let onTap: () -> Void
        let onToggleFavorite: () -> Void
        let onToggleTracking: () -> Void
        
        @State private var isHeartAnimating = false
        @State private var isTrackAnimating = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Product Image with overlay buttons
                ZStack(alignment: .topTrailing) {
                    // Product Image
                    AsyncImage(url: product.imageURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 160, height: 160)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure(_):
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 160, height: 160)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 30))
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .onTapGesture {
                        onTap()
                    }
                    
                    // Action Buttons Overlay
                    HStack(spacing: 8) {
                        // Track Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                isTrackAnimating.toggle()
                            }
                            onToggleTracking()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isTrackAnimating = false
                            }
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
                        }
                        
                        // Heart Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                isHeartAnimating.toggle()
                            }
                            onToggleFavorite()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isHeartAnimating = false
                            }
                        }) {
                            Image(systemName: isInWishlist ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                                .foregroundColor(isInWishlist ? .red : .white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .blur(radius: 1)
                                )
                                .scaleEffect(isHeartAnimating ? 1.2 : 1.0)
                        }
                    }
                    .padding(8)
                }
                
                // Product Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .top)
                    
                    // Price and Availability
                    HStack {
                        if let price = product.price {
                            Text("$\(price, specifier: "%.2f")")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
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
                    
                    // Source
                    Text(product.source)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 160, height: 240)
        }
    }
    
    // MARK: - Trending Searches Section
    
    private var trendingSearchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Trending Searches - left-aligned like SavedDashboardView
            HStack {
                Text("Trending Searches")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            
            let trendingSearches = ["AirPods Pro", "Nintendo Switch", "iPhone 15", "MacBook Air", "Coffee Maker", "Wireless Mouse"]
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(trendingSearches, id: \.self) { search in
                    TrendingSearchPill(
                        text: search,
                        onTap: {
                            searchText = search
                            performFilteredSearch()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Trending Search Pill
    
    private struct TrendingSearchPill: View {
        let text: String
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - State Views
    
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching \(selectedRetailer.displayName.lowercased())...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private var noResultsStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Try a different search term or select a different retailer")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Clear Search") {
                searchText = ""
                searchResults = []
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.blue)
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Helper Functions
    
    private func isProductInWishlist(_ product: ProductItemDTO) -> Bool {
        return wishlistService.savedItems.contains { savedItem in
            savedItem.sourceId == product.sourceId && savedItem.source == product.source
        }
    }
    
    private func toggleFavorite(_ product: ProductItemDTO) {
        Task {
            let productItem = ProductItem.from(product)
            if isProductInWishlist(product) {
                await wishlistService.removeFromWishlist(productItem.id)
                print("🗑️ Removed from wishlist: \(product.name)")
            } else {
                await wishlistService.addToWishlist(productItem)
                print("💾 Added to wishlist: \(product.name)")
            }
            
            // Force immediate UI refresh
            await MainActor.run {
                wishlistService.objectWillChange.send()
            }
        }
    }
    
    private func toggleTracking(_ product: ProductItemDTO) {
        // TODO: Implement tracking functionality
        print("Toggle tracking for: \(product.name)")
    }
    
    // MARK: - Search Logic
    
    private func handleSearchTextChange(_ newValue: String) {
        guard !newValue.isEmpty, newValue.count >= 2 else {
            searchResults = []
            return
        }
        
        // Debounced search for live results
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            if searchText == newValue { // Check if search text is still the same
                await performLiveSearch(newValue)
            }
        }
    }
    
    private func performFilteredSearch() {
        guard !searchText.isEmpty else { return }
        
        Task {
            await performLiveSearch(searchText)
        }
    }
    
    @MainActor
    private func performLiveSearch(_ query: String) async {
        isSearching = true
        
        do {
            // Use the existing search manager but filter by selected retailer
            let retailers = selectedRetailer == .all ? [] : [selectedRetailer.rawValue]
            
            // Use the APICoordinator to perform search
            let coordinator = APICoordinator()
            let results = try await coordinator.search(query: query, retailers: retailers)
            
            searchResults = results.products
            
            // Add search results to persistent cache
            if !results.products.isEmpty {
                await persistentCache.addProducts(results.products)
                print("📱 EnhancedSearchCard: Added \(results.products.count) products to persistent cache")
            }
            
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }
        
        isSearching = false
    }
}

#Preview {
    EnhancedSearchCard { product in
        print("Selected: \(product.name)")
    }
}