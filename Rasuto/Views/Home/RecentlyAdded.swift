//
//  RecentlyAddedItem.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct RecentlyAddedSection: View {
    @State private var products: [ProductItem] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recently Added")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    // Navigate to full list
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .frame(height: 240)
                    Spacer()
                }
            } else if products.isEmpty {
                EmptyStateView(
                    icon: "plus.circle",
                    title: "No Recent Items",
                    subtitle: "Start tracking products to see them here"
                )
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(products) { product in
                            ProductCardView(product: product)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadProducts()
        }
    }
    
    private func loadProducts() {
        // For now, use sample data
        // Later this will fetch from actual API
        withAnimation {
            products = Array(ProductItem.sampleItems.prefix(3))
        }
    }
}

// Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
