//
//  SearchResultsView.swift
//  Rasuto
//
//  Created for Rasuto on 4/28/25.
//

import SwiftUI

struct SearchResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SearchCardViewModel()
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack {
                // Search field with cancel button
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("camera", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                }
                
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            // Filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    SearchFilterButton(title: "All", isSelected: true)
                    SearchFilterButton(title: "Saved", isSelected: false)
                    SearchFilterButton(title: "Collections", isSelected: false)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Content area - either recent searches or results
            if searchText.isEmpty {
                recentSearchesView
            } else {
                searchResultsListView
            }
        }
        .onAppear {
            isSearchFieldFocused = true
            viewModel.loadRecentSearches()
        }
    }
    
    // MARK: - Search Methods
    
    private func performSearch() {
        if !searchText.isEmpty {
            viewModel.addRecentSearch(searchText)
            viewModel.search(query: searchText)
        }
    }
    
    // MARK: - View Components
    
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT SEARCHES")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.top, 15)
                .padding(.bottom, 5)
            
            ForEach(viewModel.recentSearches, id: \.self) { search in
                Button(action: {
                    searchText = search
                    performSearch()
                }) {
                    HStack {
                        Text(search)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(viewModel.getFormattedDate(for: search))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.leading)
            }
            
            // Placeholder data if no recent searches
            if viewModel.recentSearches.isEmpty {
                Group {
                    RecentSearchRow(text: "dslr camera", date: "Yesterday")
                    RecentSearchRow(text: "leica", date: "Friday")
                    RecentSearchRow(text: "sony a7", date: "Last week")
                }
            }
            
            Spacer()
        }
    }
    
    private var searchResultsListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RESULTS FOR \"\(searchText.uppercased())\"")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.top, 15)
                .padding(.bottom, 10)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if viewModel.searchResults.isEmpty {
                // Show sample results based on Figma mockup
                VStack(spacing: 0) {
                    searchResultCard(
                        name: "Leica Q3 Camera",
                        price: "$5,995.00",
                        image: "placeholder"
                    )
                    
                    Divider()
                        .padding(.leading, 88)
                    
                    searchResultCard(
                        name: "Canon EOS R6 Camera",
                        price: "$2,299.00",
                        image: "placeholder"
                    )
                    
                    Divider()
                        .padding(.leading, 88)
                    
                    searchResultCard(
                        name: "Sony Alpha Camera",
                        price: "$1,999.99",
                        image: "placeholder"
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResults) { product in
                            searchResultCard(
                                name: product.name,
                                price: "$" + String(format: "%.2f", product.price ?? 0.0), // Format price manually
                                image: "placeholder" // Use placeholder until we handle URL conversion
                            )
                            
                            Divider()
                                .padding(.leading, 88)
                        }
                    }
                }
            }
            
            // Bottom info text
            Text("Tap results to see details")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
    
    private func searchResultCard(name: String, price: String, image: String) -> some View {
        HStack(spacing: 15) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .medium))
                
                Text(price)
                    .font(.system(size: 15, weight: .semibold))
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "plus")
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Helper Views

struct SearchFilterButton: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : .primary)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .cornerRadius(16)
    }
}

struct RecentSearchRow: View {
    let text: String
    let date: String
    
    var body: some View {
        HStack {
            Text(text)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(date)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        
        Divider()
            .padding(.leading)
    }
}

struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView()
    }
}
