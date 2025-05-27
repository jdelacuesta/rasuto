//
//  SearchView.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var searchManager = SearchManager()
    @State private var searchText = ""
    @State private var selectedStore: StoreFilter = .all
    @State private var showingFilters = false
    @State private var isSearching = false
    
    @FocusState private var isSearchFieldFocused: Bool
    
    enum StoreFilter: String, CaseIterable {
        case all = "All Stores"
        case bestBuy = "Best Buy"
        case ebay = "eBay"
        case walmart = "Walmart"
        
        var icon: String {
            switch self {
            case .all: return "storefront.fill"
            case .bestBuy: return "cart.fill"
            case .ebay: return "tag.fill"
            case .walmart: return "bag.fill"
            }
        }
    }
    
    var filteredResults: [ProductItem] {
        if selectedStore == .all {
            return searchManager.searchResults
        } else {
            return searchManager.searchResults.filter { 
                $0.store.lowercased() == selectedStore.rawValue.lowercased().replacingOccurrences(of: " ", with: "")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Search Header
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // Search field
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                                
                                TextField("Search products...", text: $searchText)
                                    .focused($isSearchFieldFocused)
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
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            
                            // Filter button
                            Button(action: { showingFilters.toggle() }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .padding(10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                        
                        // Store filter pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(StoreFilter.allCases, id: \.self) { store in
                                    StoreFilterPill(
                                        store: store,
                                        isSelected: selectedStore == store
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedStore = store
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Search Results
                    if isSearching {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Searching...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else if searchManager.hasSearched && filteredResults.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Results Found",
                            subtitle: "Try adjusting your search or filters"
                        )
                        Spacer()
                    } else if !searchManager.hasSearched {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("Start Searching")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Find the best deals from multiple stores")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            // Recent searches
                            if !searchManager.recentSearches.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Recent Searches")
                                        .font(.headline)
                                        .padding(.top)
                                    
                                    ForEach(searchManager.recentSearches.prefix(5), id: \.self) { search in
                                        Button(action: {
                                            searchText = search
                                            performSearch()
                                        }) {
                                            HStack {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .font(.system(size: 14))
                                                Text(search)
                                                    .font(.system(size: 15))
                                                Spacer()
                                            }
                                            .foregroundColor(.primary)
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                                .padding(.horizontal, 40)
                            }
                        }
                        .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            // Results count
                            HStack {
                                Text("\(filteredResults.count) results")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Product grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(filteredResults) { product in
                                    ProductCardView(product: product)
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                isSearchFieldFocused = true
            }
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearchFieldFocused = false
        isSearching = true
        
        Task {
            await searchManager.search(query: searchText, store: selectedStore)
            withAnimation {
                isSearching = false
            }
        }
    }
}

// Store Filter Pill Component
struct StoreFilterPill: View {
    let store: SearchView.StoreFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: store.icon)
                    .font(.system(size: 12))
                Text(store.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.systemGray3), lineWidth: 1)
            )
        }
    }
}

// Search Manager
class SearchManager: ObservableObject {
    @Published var searchResults: [ProductItem] = []
    @Published var recentSearches: [String] = []
    @Published var hasSearched = false
    
    private let bestBuyService = BestBuyService()
    private let ebayService = EbayService()
    
    init() {
        loadRecentSearches()
    }
    
    func search(query: String, store: SearchView.StoreFilter) async {
        hasSearched = true
        saveRecentSearch(query)
        
        // Clear previous results
        await MainActor.run {
            searchResults = []
        }
        
        // Simulate API calls with sample data
        // In production, this would make actual API calls
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
        
        await MainActor.run {
            // For demo, return filtered sample items based on search
            let allItems = ProductItem.sampleItems
            
            // Simple search matching
            let filtered = allItems.filter { item in
                let matchesQuery = item.name.localizedCaseInsensitiveContains(query) ||
                                 item.category.localizedCaseInsensitiveContains(query) ||
                                 item.brand.localizedCaseInsensitiveContains(query)
                
                let matchesStore = store == .all || 
                                 item.store.lowercased() == store.rawValue.lowercased().replacingOccurrences(of: " ", with: "")
                
                return matchesQuery && matchesStore
            }
            
            // If no exact matches, return some random items for demo
            if filtered.isEmpty && query.count > 2 {
                searchResults = Array(allItems.shuffled().prefix(4))
            } else {
                searchResults = filtered
            }
            
            // Simulate some items being tracked
            if searchResults.count > 2 {
                searchResults[0].isTracked = true
                searchResults[1].isFavorite = true
            }
        }
    }
    
    func clearResults() {
        searchResults = []
        hasSearched = false
    }
    
    private func saveRecentSearch(_ query: String) {
        if !recentSearches.contains(query) {
            recentSearches.insert(query, at: 0)
            if recentSearches.count > 10 {
                recentSearches.removeLast()
            }
            UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
        }
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
    }
}

// Search Filters View
struct SearchFiltersView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Filters coming soon!")
                    .font(.headline)
                    .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SearchView()
}