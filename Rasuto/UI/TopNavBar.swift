//
//  TopNavigatorBar.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

// MARK: - Top Navigation Bar

struct TopNavBar: View {
    @Binding var isRotating: Bool
    var onAddTapped: () -> Void
    var onSearchTapped: (() -> Void)? = nil
    
    @State private var searchText = ""
    @State private var isSearchActive = false
    @StateObject private var searchManager = UniversalSearchManager()
    @State private var selectedProduct: ProductItem?
    @State private var showingProductDetail = false
    @FocusState private var isSearchFocused: Bool
    @ObservedObject private var wishlistService = WishlistService.shared
    // @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker // REMOVED
    // @EnvironmentObject private var ebayManager: EbayNotificationManager // Commented out - EbayNotificationManager disabled
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Logo - simple R design
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .frame(width: 36, height: 36)
                    
                    Text("R")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(isSearchActive ? 0.9 : 1.0)
                .animation(.spring(response: 0.3), value: isSearchActive)
                
                // Universal Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                    
                    if isSearchActive {
                        TextField("Search products, stores...", text: $searchText)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                searchManager.performFullSearch(query: searchText)
                            }
                            .onChange(of: searchText) { newValue in
                                searchManager.updateInstantResults(query: newValue)
                            }
                    } else {
                        Text("Search")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if isSearchActive && !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchManager.clearResults()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 15))
                        }
                    } else if !isSearchActive {
                        Image(systemName: "mic")
                            .foregroundColor(.gray)
                            .font(.system(size: 15))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .onTapGesture {
                    // Open search card
                    onSearchTapped?()
                }
                
                // Add button (hide when searching)
                if !isSearchActive {
                    Button(action: {
                        withAnimation(.linear(duration: 0.3)) {
                            isRotating = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAddTapped()
                            isRotating = false
                        }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                            .rotationEffect(.degrees(isRotating ? 90 : 0))
                    }
                    .padding(.leading, 4)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                } else {
                    // Cancel button when searching
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.3)) {
                            isSearchActive = false
                            isSearchFocused = false
                            searchText = ""
                            searchManager.clearResults()
                        }
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.blue)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal)
            
            // Search Results Overlay
            if isSearchActive && (searchManager.isSearching || !searchManager.instantResults.isEmpty || searchManager.hasSearched) {
                UniversalSearchResultsView(
                    searchManager: searchManager,
                    searchText: $searchText,
                    isSearchActive: $isSearchActive,
                    selectedProduct: $selectedProduct,
                    showingProductDetail: $showingProductDetail
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .sheet(isPresented: $showingProductDetail) {
            if let product = selectedProduct {
                ProductDetailView(product: product)
                    .environmentObject(wishlistService)
                    // .environmentObject(bestBuyTracker) // REMOVED
                    // .environmentObject(ebayManager) // Commented out - EbayNotificationManager disabled
            }
        }
        // Search view sheet removed - using search card approach
    }
}

// MARK: - Universal Search Results View

struct UniversalSearchResultsView: View {
    @ObservedObject var searchManager: UniversalSearchManager
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @Binding var selectedProduct: ProductItem?
    @Binding var showingProductDetail: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if searchManager.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 40)
                            Spacer()
                        }
                    } else if searchManager.instantResults.isEmpty && searchManager.hasSearched {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No results found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Instant results sections
                        if !searchManager.productResults.isEmpty {
                            SearchResultSection(
                                title: "Products",
                                icon: "bag.fill",
                                results: searchManager.productResults
                            ) { product in
                                // Handle product selection
                                selectedProduct = product
                                showingProductDetail = true
                                withAnimation {
                                    searchText = ""
                                    isSearchActive = false
                                    searchManager.clearResults()
                                }
                            }
                        }
                        
                        if !searchManager.categoryResults.isEmpty {
                            SearchResultSection(
                                title: "Categories",
                                icon: "square.grid.2x2.fill",
                                results: searchManager.categoryResults
                            ) { category in
                                // Handle category selection
                                searchText = category
                                searchManager.performFullSearch(query: category)
                            }
                        }
                        
                        // Show suggestions and recent searches when search is empty
                        if searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                // Suggested searches
                                if !searchManager.suggestedSearches.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Trending Searches", systemImage: "chart.line.uptrend.xyaxis")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        ForEach(searchManager.suggestedSearches, id: \.self) { suggestion in
                                            Button(action: {
                                                searchText = suggestion
                                                searchManager.performFullSearch(query: suggestion)
                                            }) {
                                                HStack {
                                                    Image(systemName: "sparkle")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                    Text(suggestion)
                                                        .foregroundColor(.primary)
                                                    Spacer()
                                                }
                                                .padding(.horizontal)
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                }
                                
                                // Recent searches
                                if !searchManager.recentSearches.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Label("Recent", systemImage: "clock")
                                                .font(.headline)
                                            Spacer()
                                            Button("Clear") {
                                                searchManager.clearRecentSearches()
                                            }
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        }
                                        .padding(.horizontal)
                                        
                                        ForEach(searchManager.recentSearches.prefix(5), id: \.self) { search in
                                            Button(action: {
                                                searchText = search
                                                searchManager.performFullSearch(query: search)
                                            }) {
                                                HStack {
                                                    Text(search)
                                                        .foregroundColor(.primary)
                                                    Spacer()
                                                    Image(systemName: "arrow.up.left")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                .padding(.horizontal)
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
            .background(Color(.systemBackground))
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Search Result Section

struct SearchResultSection<T: SearchResultItem>: View {
    let title: String
    let icon: String
    let results: [T]
    let onSelect: (T) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(results.prefix(5)) { result in
                Button(action: { onSelect(result) }) {
                    HStack {
                        if let product = result as? ProductItem {
                            // Product result row
                            AsyncImage(url: URL(string: product.imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                HStack(spacing: 4) {
                                    if let price = product.price {
                                        Text("$\(price, specifier: "%.2f")")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.green)
                                        
                                        Text("•")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text(RetailerType.displayName(for: product.source))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .textCase(.none)
                                }
                            }
                        } else {
                            // Category result row
                            Text(result.displayName)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                if result.id != results.prefix(5).last?.id {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
    }
}



// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    VStack {
        TopNavBar(isRotating: .constant(false), onAddTapped: {})
        Spacer()
    }
}
