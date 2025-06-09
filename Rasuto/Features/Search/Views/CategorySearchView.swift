//
//  CategorySearchView.swift
//  Rasuto
//
//  Created for capstone demo flow on 5/29/25.
//

import SwiftUI

struct CategorySearchView: View {
    let category: String
    let query: String
    
    @StateObject private var viewModel = MainSearchViewModel()
    @State private var products: [ProductItemDTO] = []
    @State private var isLoading = true
    @State private var selectedSortOption = "Relevance"
    
    private let sortOptions = ["Relevance", "Price: Low to High", "Price: High to Low", "Rating"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Sort options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sortOptions, id: \.self) { option in
                        Text(option)
                            .font(.subheadline)
                            .fontWeight(selectedSortOption == option ? .semibold : .regular)
                            .foregroundColor(selectedSortOption == option ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedSortOption == option ? Color.blue : Color(.systemGray5))
                            )
                            .onTapGesture {
                                selectedSortOption = option
                                sortProducts()
                            }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            
            Divider()
            
            // Products grid
            if isLoading {
                loadingView
            } else if products.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(products) { dto in
                            let product = ProductItem.from(dto)
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                ProductCardView(product: product, cardWidth: (UIScreen.main.bounds.width - 48) / 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadCategoryProducts()
        }
    }
    
    private var loadingView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(0..<6) { _ in
                    RecommendedItemPlaceholder()
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No products found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search or browse other categories")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
    
    private func loadCategoryProducts() {
        Task {
            isLoading = true
            products = await viewModel.searchByCategory(query)
            sortProducts()
            isLoading = false
        }
    }
    
    private func sortProducts() {
        switch selectedSortOption {
        case "Price: Low to High":
            products.sort { ($0.price ?? Double.infinity) < ($1.price ?? Double.infinity) }
        case "Price: High to Low":
            products.sort { ($0.price ?? 0) > ($1.price ?? 0) }
        case "Rating":
            products.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        default:
            // Keep original order for relevance
            break
        }
    }
}
