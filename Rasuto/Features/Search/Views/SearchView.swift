//
//  SearchView.swift
//  Rasuto
//
//  Created on 4/21/25.
//  Updated to support async SearchViewModel

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search header
                searchHeader
                
                // Filter tabs
                filterTabs
                
                // Recent searches or results
                if searchText.isEmpty {
                    recentSearchesView
                } else {
                    searchResultsView
                }
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .onAppear {
            isSearchFieldFocused = true
            viewModel.loadRecentSearches()
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search for products", text: $searchText)
                    .focused($isSearchFieldFocused)
                    .autocorrectionDisabled(true)
                    .onSubmit {
                        if !searchText.isEmpty {
                            viewModel.addRecentSearch(searchText)
                            viewModel.search(query: searchText)
                        }
                    }
                    .onChange(of: searchText) { _ in
                        if !searchText.isEmpty {
                            viewModel.search(query: searchText)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                Button {
                    Task {
                        await viewModel.activateVoiceSearch()
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.gray)
                }
                .padding(.leading, 4)
            }
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.trailing, 8)
            
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Filter Tabs
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterTab(title: "All", isSelected: viewModel.selectedFilter == .all)
                    .onTapGesture {
                        viewModel.selectedFilter = .all
                    }
                
                FilterTab(title: "Saved", isSelected: viewModel.selectedFilter == .saved)
                    .onTapGesture {
                        viewModel.selectedFilter = .saved
                    }
                
                FilterTab(title: "Collections", isSelected: viewModel.selectedFilter == .collections)
                    .onTapGesture {
                        viewModel.selectedFilter = .collections
                    }
                
                // Category filters
                ForEach(viewModel.categories, id: \.self) { category in
                    FilterTab(title: category, isSelected: isCategorySelected(category))
                        .onTapGesture {
                            viewModel.selectedFilter = .category(category)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // Helper method to fix key path type inference
    private func isCategorySelected(_ category: String) -> Bool {
        if case .category(let selectedCategory) = viewModel.selectedFilter {
            return category == selectedCategory
        }
        return false
    }
    
    // MARK: - Recent Searches
    
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.recentSearches.isEmpty {
                Text("RECENT SEARCHES")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 5)
                
                ForEach(viewModel.recentSearches, id: \.self) { search in
                    HStack {
                        Text(search)
                        
                        Spacer()
                        
                        Text(viewModel.getFormattedDate(for: search))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        searchText = search
                        viewModel.search(query: search)
                    }
                    
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.searchResults.isEmpty {
                    noResultsView
                } else {
                    Text("RESULTS FOR \"\(searchText.uppercased())\"")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                    
                    ForEach(viewModel.searchResults) { product in
                        // Use a simple placeholder instead of SearchResultRow
                        productRow(product)
                        Divider()
                            .padding(.leading)
                    }
                    
                    Text("Tap results to see details")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // Simple product row view
    private func productRow(_ product: ProductItemDTO) -> some View {
        HStack(spacing: 12) {
            // Product image placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .cornerRadius(6)
            
            // Product details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)
                
                Text(product.brand)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    if let price = product.price {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.system(size: 15, weight: .semibold))
                    } else {
                        Text("N/A")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    // Source tag
                    Text(product.source)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
            
            // Add button
            Button {
                // Add to collection/wishlist logic
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to product detail
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("Searching...")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var noResultsView: some View {
        VStack {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .padding()
            
            Text("No results found")
                .font(.headline)
            
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Filter Tab

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .black)
            .cornerRadius(20)
    }
}
