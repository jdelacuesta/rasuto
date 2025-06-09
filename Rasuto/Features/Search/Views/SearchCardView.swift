//
//  SearchCardView.swift
//  Rasuto
//
//  Created for search card functionality on 6/3/25.
//

import SwiftUI

struct SearchCardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchManager = UniversalSearchManager()
    @StateObject private var viewModel = SearchCardViewModel()
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @FocusState private var isSearchFieldFocused: Bool
    
    // Filter options with retailers
    private let filterOptions = ["All", "Saved", "Collections", "Google Shopping", "Amazon", "Walmart", "eBay", "Home Depot", "Best Buy"]
    
    // Suggested search categories (SerpAPI compatible)
    private let suggestedCategories = [
        "Electronics", "Fashion", "Home & Garden", "Sports", "Books", "Tech Gadgets",
        "Kitchen Appliances", "Power Tools", "Audio", "Gaming", "Office Supplies"
    ]
    
    // Demo search suggestions (fallback since DemoSearchManager removed)
    private let demoSearchSuggestions = ["iPhone 15", "MacBook Air", "AirPods Pro", "Apple Watch", "iPad Pro"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            searchHeader
            
            // Filter tabs with retailers
            filterTabs
            
            Divider()
            
            // Content area
            contentArea
        }
        .onAppear {
            isSearchFieldFocused = true
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                searchManager.updateInstantResults(query: newValue)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var searchHeader: some View {
        HStack {
            // Search field with magnifying glass
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search products across retailers...", text: $searchText)
                    .focused($isSearchFieldFocused)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchManager.clearResults()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // No cancel button needed - sheet has built-in dismiss
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Filter Tabs
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filterOptions, id: \.self) { filter in
                    FilterButton(
                        title: filter,
                        isSelected: selectedFilter == filter,
                        action: {
                            selectedFilter = filter
                            if filter != "All" && filter != "Saved" && filter != "Collections" {
                                // Filter by specific retailer
                                performRetailerSearch(retailer: filter)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        if searchText.isEmpty {
            emptySearchView
        } else {
            searchResultsView
        }
    }
    
    // MARK: - Empty Search View (Categories + Recent Searches)
    
    private var emptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Discover Categories Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("BROWSE CATEGORIES")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(suggestedCategories, id: \.self) { category in
                            CategorySearchButton(category: category) {
                                searchText = category
                                performSearch()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Demo Search Suggestions
                VStack(alignment: .leading, spacing: 12) {
                    Text("SUGGESTED SEARCHES")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(demoSearchSuggestions, id: \.self) { suggestion in
                            SuggestionButton(text: suggestion) {
                                searchText = suggestion
                                performSearch()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Recent Searches
                if !searchManager.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("RECENT SEARCHES")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Button("Clear") {
                                searchManager.clearRecentSearches()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        ForEach(searchManager.recentSearches, id: \.self) { search in
                            Button(action: {
                                searchText = search
                                performSearch()
                            }) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                    
                                    Text(search)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                
                Spacer(minLength: 50)
            }
        }
    }
    
    // MARK: - Search Results View
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Results header
            HStack {
                Text("RESULTS FOR \"\(searchText.uppercased())\"")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !searchManager.productResults.isEmpty {
                    Text("\(searchManager.productResults.count) products")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top, 15)
            .padding(.bottom, 10)
            
            // Search results list
            if searchManager.isSearching {
                SearchLoadingView(
                    query: searchText,
                    onCancel: {
                        searchManager.clearResults()
                    }
                )
            } else if searchManager.isShowingError, let error = searchManager.searchError {
                SearchErrorView(
                    error: error,
                    onRetry: {
                        searchManager.retryLastSearch()
                        performSearch()
                    }
                )
            } else if searchManager.productResults.isEmpty && searchManager.hasSearched {
                FallbackSearchView(
                    originalQuery: searchText,
                    onSearchSuggestion: { suggestion in
                        searchText = suggestion
                        performSearch()
                    }
                )
            } else if !searchManager.productResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchManager.productResults) { product in
                            SearchResultCard(product: product)
                            
                            if product.id != searchManager.productResults.last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                }
            } else {
                EmptySearchResults(query: searchText)
            }
        }
    }
    
    // MARK: - Search Actions
    
    private func performSearch() {
        if !searchText.isEmpty {
            if selectedFilter == "All" {
                searchManager.performFullSearch(query: searchText)
            } else if filterOptions.contains(selectedFilter) && selectedFilter != "Saved" && selectedFilter != "Collections" {
                searchManager.performRetailerSearch(query: searchText, retailer: selectedFilter)
            } else {
                searchManager.performFullSearch(query: searchText)
            }
        }
    }
    
    private func performRetailerSearch(retailer: String) {
        if !searchText.isEmpty {
            searchManager.performRetailerSearch(query: searchText, retailer: retailer)
        }
    }
}

// MARK: - Supporting Views

struct CategorySearchButton: View {
    let category: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                Text(category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Electronics": return "desktopcomputer"
        case "Fashion": return "tshirt"
        case "Home & Garden": return "house"
        case "Sports": return "figure.run"
        case "Books": return "book"
        case "Tech Gadgets": return "iphone"
        case "Kitchen Appliances": return "microwave"
        case "Power Tools": return "hammer"
        case "Audio": return "speaker.wave.2"
        case "Gaming": return "gamecontroller"
        case "Office Supplies": return "pencil"
        default: return "magnifyingglass"
        }
    }
}

struct SuggestionButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchResultCard: View {
    let product: ProductItem
    @ObservedObject private var wishlistService = WishlistService.shared
    @State private var isFavorited: Bool = false
    
    var body: some View {
        NavigationLink(destination: ProductDetailView(product: product)) {
            HStack(spacing: 12) {
                // Product image placeholder
                AsyncImage(url: product.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
            
            // Product details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(RetailerType.displayName(for: product.source))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                HStack {
                    if let price = product.price {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let originalPrice = product.originalPrice, originalPrice > price {
                            Text("$\(String(format: "%.2f", originalPrice))")
                                .font(.caption)
                                .strikethrough()
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            if isFavorited {
                                await wishlistService.removeFromWishlist(product.id)
                            } else {
                                let productDTO = ProductItemDTO.from(product)
                                await wishlistService.saveToWishlist(from: productDTO)
                            }
                            isFavorited.toggle()
                        }
                    }) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .foregroundColor(isFavorited ? .red : .gray)
                    }
                }
            }
        }
        .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.vertical, 12)
        .onAppear {
            // Set initial favorite state based on wishlist
            isFavorited = wishlistService.savedItems.contains { $0.id == product.id }
        }
    }
}

struct EmptySearchResults: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No results found")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Try searching for something else or check your spelling")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SearchCardView()
}