//
//  EbayAPITestView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/15/25.
//

import SwiftUI

struct EbayAPITestView: View {
    @State private var searchQuery = ""
    @State private var products: [ProductItemDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProductId: String?
    @State private var detailProduct: ProductItemDTO?
    @State private var relatedProducts: [ProductItemDTO] = []
    @State private var isLoadingDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search eBay", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
                
                Button(action: searchProducts) {
                    Text("Search")
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(searchQuery.isEmpty || isLoading)
            }
            .padding()
            
            if isLoading {
                ProgressView("Searching...")
                    .padding()
            } else if let error = errorMessage {
                VStack {
                    Text("Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if let detailProduct = detailProduct {
                // Product details view
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {
                            self.detailProduct = nil
                            self.selectedProductId = nil
                        }) {
                            Label("Back to results", systemImage: "arrow.left")
                        }
                        .padding(.bottom, 8)
                        
                        if let imageURL = detailProduct.imageURL {
                            AsyncImage(url: imageURL) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 200)
                                } else if phase.error != nil {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 200)
                                } else {
                                    ProgressView()
                                        .frame(height: 200)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        Text(detailProduct.name)
                            .font(.title2)
                            .bold()
                        
                        if let price = detailProduct.price {
                            HStack {
                                Text("$\(price, specifier: "%.2f")")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                
                                if let originalPrice = detailProduct.originalPrice, originalPrice > price {
                                    Text("$\(originalPrice, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .strikethrough()
                                }
                            }
                        }
                        
                        Text("Brand: \(detailProduct.brand)")
                            .font(.subheadline)
                        
                        if let category = detailProduct.category {
                            Text("Category: \(category)")
                                .font(.subheadline)
                        }
                        
                        if let description = detailProduct.productDescription, !description.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Description")
                                    .font(.headline)
                                    .padding(.top, 8)
                                
                                Text(description)
                                    .font(.body)
                            }
                        }
                        
                        // Track/Untrack button
                        Button(action: {
                            trackProduct(detailProduct)
                        }) {
                            Label("Track This Item", systemImage: "bell")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                        
                        if !relatedProducts.isEmpty {
                            Text("Related Products")
                                .font(.headline)
                                .padding(.top, 16)
                            
                            ForEach(relatedProducts) { product in
                                Button(action: {
                                    selectProduct(product.sourceId)
                                }) {
                                    HStack {
                                        if let thumbnailUrl = product.thumbnailUrl,
                                           let url = URL(string: thumbnailUrl) {
                                            AsyncImage(url: url) { phase in
                                                if let image = phase.image {
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 60, height: 60)
                                                } else {
                                                    Image(systemName: "photo")
                                                        .frame(width: 60, height: 60)
                                                }
                                            }
                                            .frame(width: 60, height: 60)
                                        } else {
                                            Image(systemName: "photo")
                                                .frame(width: 60, height: 60)
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text(product.name)
                                                .font(.subheadline)
                                                .lineLimit(2)
                                            
                                            if let price = product.price {
                                                Text("$\(price, specifier: "%.2f")")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                }
            } else {
                // Search results
                List {
                    ForEach(products) { product in
                        Button(action: {
                            selectProduct(product.sourceId)
                        }) {
                            HStack {
                                if let thumbnailUrl = product.thumbnailUrl,
                                   let url = URL(string: thumbnailUrl) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 60, height: 60)
                                        } else {
                                            Image(systemName: "photo")
                                                .frame(width: 60, height: 60)
                                        }
                                    }
                                    .frame(width: 60, height: 60)
                                } else {
                                    Image(systemName: "photo")
                                        .frame(width: 60, height: 60)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(product.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                    
                                    if let price = product.price {
                                        Text("$\(price, specifier: "%.2f")")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    }
                                    
                                    Text("Source ID: \(product.sourceId)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .overlay(
                    Group {
                        if products.isEmpty && !isLoading && errorMessage == nil {
                            VStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .padding()
                                Text("Search for products on eBay")
                                    .font(.headline)
                            }
                        }
                    }
                )
            }
        }
        .navigationBarTitle("eBay API Test", displayMode: .inline)
        .overlay(
            isLoadingDetails ?
                ProgressView("Loading details...")
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                : nil
        )
    }
    
    private func searchProducts() {
        isLoading = true
        errorMessage = nil
        products = []
        
        Task {
            do {
                // Create a service instance using your API key
                let ebayService = try APIConfig.createEbayService()
                
                // Search for products
                let results = try await ebayService.searchProducts(query: searchQuery)
                
                // Update UI on main thread
                await MainActor.run {
                    products = results
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func selectProduct(_ id: String) {
        selectedProductId = id
        isLoadingDetails = true
        detailProduct = nil
        relatedProducts = []
        
        Task {
            do {
                let ebayService = try APIConfig.createEbayService()
                
                // Get product details
                let details = try await ebayService.getProductDetails(id: id)
                
                // Get related products
                let related = try await ebayService.getRelatedProducts(id: id)
                
                await MainActor.run {
                    detailProduct = details
                    relatedProducts = related
                    isLoadingDetails = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error loading details: \(error.localizedDescription)"
                    isLoadingDetails = false
                    selectedProductId = nil
                }
            }
        }
    }
    
    private func trackProduct(_ product: ProductItemDTO) {
        Task {
            do {
                let ebayService = try APIConfig.createEbayService()
                let success = try await ebayService.trackItem(id: product.sourceId)
                
                await MainActor.run {
                    if success {
                        // Show success message or update UI
                        print("Successfully tracked product: \(product.name)")
                    }
                }
            } catch {
                print("Error tracking product: \(error)")
            }
        }
    }
}

#Preview {
    NavigationView {
        EbayAPITestView()
    }
}
