//
//  SearchResultsView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/21/25.
//

import SwiftUI

struct SearchResultsView: View {
    let searchQuery: String
    let searchResults: [SearchItem]
    var onToggleSaved: (SearchItem) -> Void
    
    @Environment(\.presentationMode) private var presentationMode
    @State private var sortOption: SortOption = .relevance
    
    enum SortOption {
        case relevance
        case priceLowToHigh
        case priceHighToLow
        case newest
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Sort options
                    Picker("Sort By", selection: $sortOption) {
                        Text("Relevance").tag(SortOption.relevance)
                        Text("Price: Low to High").tag(SortOption.priceLowToHigh)
                        Text("Price: High to Low").tag(SortOption.priceHighToLow)
                        Text("Newest").tag(SortOption.newest)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Results counter
                    HStack {
                        Text("\(searchResults.count) results")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    // Results list
                    ForEach(sortedResults) { item in
                        SearchResultRow(item: item, toggleSaved: {
                            onToggleSaved(item)
                        })
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.bottom)
            }
            .navigationTitle("Results for \"\(searchQuery)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
    }
    
    private var sortedResults: [SearchItem] {
        switch sortOption {
        case .relevance:
            return searchResults
        case .priceLowToHigh:
            return searchResults.sorted { $0.price < $1.price }
        case .priceHighToLow:
            return searchResults.sorted { $0.price > $1.price }
        case .newest:
            // In a real app, you would sort by date
            // For now, we'll just return the original results
            return searchResults
        }
    }
}

struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView(
            searchQuery: "camera",
            searchResults: [
                SearchItem(
                    name: "Leica Q3 Camera",
                    description: "Full-frame compact camera",
                    price: 5995.00,
                    source: .bestBuy,
                    category: .cameras
                ),
                SearchItem(
                    name: "Canon EOS R6 Camera",
                    description: "Mirrorless digital camera",
                    price: 2299.00,
                    source: .bestBuy,
                    category: .cameras
                ),
                SearchItem(
                    name: "Sony Alpha Camera",
                    description: "Full-frame mirrorless camera",
                    price: 1999.99,
                    source: .ebay,
                    category: .cameras
                )
            ],
            onToggleSaved: { _ in }
        )
    }
}
