//
//  ProductDetailView.swift
//  Rasuto
//
//  Created by Claude on 5/27/25.
//

import SwiftUI

struct ProductDetailView: View {
    let product: ProductItem
    @EnvironmentObject private var wishlistService: WishlistService
    @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker
    @EnvironmentObject private var ebayManager: EbayNotificationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImageIndex = 0
    @State private var isInWishlist = false
    @State private var isTracking = false
    @State private var showingShareSheet = false
    @State private var priceHistory: [PricePoint] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Product Images
                    productImageSection
                    
                    // Product Info
                    VStack(alignment: .leading, spacing: 16) {
                        // Title and Brand
                        VStack(alignment: .leading, spacing: 8) {
                            Text(product.brand)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(product.name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Price Section
                        priceSection
                        
                        // Action Buttons
                        actionButtons
                        
                        Divider()
                            .padding(.vertical)
                        
                        // Product Description
                        if let description = product.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Price History Chart (if tracking)
                        if isTracking && !priceHistory.isEmpty {
                            Divider()
                                .padding(.vertical)
                            
                            priceHistorySection
                        }
                        
                        // Product Details
                        Divider()
                            .padding(.vertical)
                        
                        productDetailsSection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = product.url {
                    ShareSheet(items: [url])
                }
            }
        }
        .onAppear {
            checkStatus()
            loadPriceHistory()
        }
    }
    
    // MARK: - Components
    
    private var productImageSection: some View {
        let imageUrls = product.imageUrls.isEmpty ? [product.imageUrl] : product.imageUrls
        
        return TabView(selection: $selectedImageIndex) {
            ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            ProgressView()
                        )
                }
                .tag(index)
            }
        }
        .frame(height: 300)
        .tabViewStyle(PageTabViewStyle())
        .background(Color(.systemGray6))
    }
    
    private var priceSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(product.currentPrice, specifier: "%.2f")")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let originalPrice = product.originalPrice, originalPrice > product.currentPrice {
                    HStack(spacing: 8) {
                        Text("$\(originalPrice, specifier: "%.2f")")
                            .font(.callout)
                            .strikethrough()
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(product.discountPercentage ?? 0))% OFF")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Stock Status
            HStack(spacing: 4) {
                Image(systemName: product.isInStock ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(product.isInStock ? .green : .red)
                Text(product.isInStock ? "In Stock" : "Out of Stock")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Add to Wishlist Button
            Button(action: toggleWishlist) {
                Label(
                    isInWishlist ? "In Wishlist" : "Add to Wishlist",
                    systemImage: isInWishlist ? "heart.fill" : "heart"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isInWishlist ? .pink : .blue)
            
            // Track Price Button
            Button(action: toggleTracking) {
                Label(
                    isTracking ? "Tracking" : "Track Price",
                    systemImage: isTracking ? "bell.fill" : "bell"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isTracking ? .orange : .blue)
        }
        .padding(.horizontal)
    }
    
    private var priceHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price History")
                .font(.headline)
                .padding(.horizontal)
            
            // Price chart
            PriceHistoryChart(priceHistory: priceHistory)
                .frame(height: 200)
                .padding(.horizontal)
            
            // Price stats
            HStack {
                VStack(alignment: .leading) {
                    Text("Lowest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(priceHistory.map { $0.price }.min() ?? 0, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(priceHistory.map { $0.price }.reduce(0, +) / Double(priceHistory.count), specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Highest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(priceHistory.map { $0.price }.max() ?? 0, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var productDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Product Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                DetailRow(label: "Brand", value: product.brand)
                DetailRow(label: "Category", value: product.category)
                DetailRow(label: "SKU", value: product.sourceId)
                DetailRow(label: "Source", value: product.store)
                
                if let rating = product.rating {
                    HStack {
                        Text("Rating")
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("\(rating, specifier: "%.1f")")
                                .fontWeight(.medium)
                            if let count = product.reviewCount {
                                Text("(\(count))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
    
    // MARK: - Actions
    
    private func checkStatus() {
        isInWishlist = product.isFavorite
        isTracking = product.isTracked
    }
    
    private func toggleWishlist() {
        withAnimation(.spring(response: 0.3)) {
            isInWishlist.toggle()
        }
        
        // Save to wishlist service
        Task {
            if isInWishlist {
                await wishlistService.addToWishlist(product)
            } else {
                await wishlistService.removeFromWishlist(product.id)
            }
        }
    }
    
    private func toggleTracking() {
        withAnimation(.spring(response: 0.3)) {
            isTracking.toggle()
        }
        
        // Start/stop tracking
        if isTracking {
            startTracking()
        } else {
            stopTracking()
        }
    }
    
    private func startTracking() {
        switch product.store.lowercased() {
        case "bestbuy":
            let productInfo = BestBuyProductInfo(
                sku: product.idString,
                name: product.name,
                regularPrice: product.originalPrice ?? product.currentPrice,
                salePrice: product.price,
                onSale: product.isOnSale,
                image: product.imageUrl,
                url: product.productUrl ?? "",
                description: product.description ?? ""
            )
            bestBuyTracker.startTracking(sku: product.idString, productInfo: productInfo)
        case "ebay":
            Task {
                do {
                    _ = try await ebayManager.trackItem(
                        id: product.idString,
                        name: product.name,
                        currentPrice: product.currentPrice,
                        thumbnailUrl: product.imageUrl
                    )
                } catch {
                    print("Failed to track eBay item: \(error)")
                }
            }
        default:
            break
        }
    }
    
    private func stopTracking() {
        switch product.store.lowercased() {
        case "bestbuy":
            bestBuyTracker.stopTracking(for: product.idString)
        case "ebay":
            Task {
                do {
                    _ = try await ebayManager.untrackItem(id: product.idString)
                } catch {
                    print("Failed to untrack eBay item: \(error)")
                }
            }
        default:
            break
        }
    }
    
    private func loadPriceHistory() {
        // Simulate price history for demo
        if product.isTracked {
            priceHistory = (0..<30).map { daysAgo in
                PricePoint(
                    date: Date().addingTimeInterval(-Double(daysAgo * 86400)),
                    price: product.currentPrice + Double.random(in: -50...50),
                    currency: product.currency ?? "USD"
                )
            }.reversed()
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct PriceHistoryChart: View {
    let priceHistory: [PricePoint]
    
    var body: some View {
        GeometryReader { geometry in
            if priceHistory.count > 1 {
                let minPrice = priceHistory.map { $0.price }.min() ?? 0
                let maxPrice = priceHistory.map { $0.price }.max() ?? 100
                let priceRange = max(maxPrice - minPrice, 1)
                
                ZStack {
                    // Grid lines
                    ForEach(0..<5) { i in
                        let y = geometry.size.height * CGFloat(i) / 4
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    }
                    
                    // Price line
                    Path { path in
                        for (index, point) in priceHistory.enumerated() {
                            let x = geometry.size.width * CGFloat(index) / CGFloat(priceHistory.count - 1)
                            let y = geometry.size.height * (1 - (point.price - minPrice) / priceRange)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    
                    // Fill area
                    Path { path in
                        for (index, point) in priceHistory.enumerated() {
                            let x = geometry.size.width * CGFloat(index) / CGFloat(priceHistory.count - 1)
                            let y = geometry.size.height * (1 - (point.price - minPrice) / priceRange)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ProductDetailView(product: ProductItem(
        name: "Sample Product",
        productDescription: "Sample product description",
        price: 99.99,
        currency: "USD",
        url: URL(string: "https://example.com"),
        brand: "Sample Brand",
        source: "BestBuy",
        sourceId: "12345",
        category: "Electronics",
        imageURL: URL(string: "https://example.com/image.jpg"),
        isInStock: true
    ))
        .environmentObject(WishlistService())
        .environmentObject(BestBuyPriceTracker(bestBuyService: BestBuyAPIService(apiKey: "test")))
        .environmentObject(EbayNotificationManager())
}