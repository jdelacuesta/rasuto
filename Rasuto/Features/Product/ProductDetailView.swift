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
    // @EnvironmentObject private var bestBuyTracker: BestBuyPriceTracker // DISABLED for faster startup
    // @EnvironmentObject private var ebayManager: EbayNotificationManager // Commented out - EbayNotificationManager disabled
    @Environment(\.dismiss) private var dismiss
    @StateObject private var axessoService = AxessoAmazonAPIService(apiKey: DefaultKeys.axessoApiKeyPrimary)
    @StateObject private var trackingService = ProductTrackingService.shared
    
    @State private var selectedImageIndex = 0
    @State private var isInWishlist = false
    @State private var isTracking = false
    @State private var showingShareSheet = false
    @State private var priceHistory: [PricePoint] = []
    @State private var reviews: AxessoAmazonReviewsResponse?
    @State private var amazonPriceHistory: AxessoAmazonPricesResponse?
    @State private var isLoadingReviews = false
    @State private var isLoadingPrices = false
    @State private var showingReviews = false
    @State private var showingPrices = false
    @State private var errorMessage = ""
    
    var body: some View {
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
                        
                        // Amazon Features (if Amazon product)
                        if product.source.lowercased().contains("amazon") {
                            Divider()
                                .padding(.vertical)
                            
                            amazonFeaturesSection
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
                        
                        // Price Trends (Premium Feature)
                        Divider()
                            .padding(.vertical)
                        
                        priceTrendsSection
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .sheet(isPresented: $showingReviews) {
                amazonReviewsSheet
            }
            .sheet(isPresented: $showingPrices) {
                amazonPricesSheet
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
                        .fill(Color.white)
                        .overlay(
                            ProgressView()
                        )
                }
                .tag(index)
            }
        }
        .frame(height: 300)
        .tabViewStyle(PageTabViewStyle())
        .background(Color.white)
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
            // Save Item Button
            Button(action: saveItem) {
                Label(
                    isInWishlist ? "Saved" : "Save Item",
                    systemImage: isInWishlist ? "heart.fill" : "heart"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isInWishlist ? .green : .blue)
            
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
                DetailRow(label: "Source", value: RetailerType.displayName(for: product.source))
                
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
        .padding(.bottom, 16)
    }
    
    // MARK: - Amazon Features Section
    
    private var amazonFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Amazon Features")
                .font(.headline)
            
            // Feature Buttons
            HStack(spacing: 12) {
                // Reviews Button
                Button(action: {
                    loadAmazonReviews()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "text.bubble")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("Reviews")
                            .font(.caption)
                            .fontWeight(.medium)
                        if isLoadingReviews {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(isLoadingReviews)
                
                // Price History Button
                Button(action: {
                    loadAmazonPriceHistory()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundColor(.green)
                        Text("Price History")
                            .font(.caption)
                            .fontWeight(.medium)
                        if isLoadingPrices {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(isLoadingPrices)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }
    
    private var priceTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Price Trends & Analytics")
                .font(.headline)
            
            ZStack {
                // Background chart (mock data)
                VStack(spacing: 12) {
                    // Chart area with multiple trend lines
                    ZStack {
                        // Grid background
                        GeometryReader { geometry in
                            // Horizontal grid lines
                            ForEach(0..<4) { i in
                                Path { path in
                                    let y = geometry.size.height * CGFloat(i) / 3
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                                }
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                            }
                            
                            // Main price trend line
                            Path { path in
                                let points: [CGPoint] = [
                                    CGPoint(x: 0, y: geometry.size.height * 0.6),
                                    CGPoint(x: geometry.size.width * 0.15, y: geometry.size.height * 0.45),
                                    CGPoint(x: geometry.size.width * 0.3, y: geometry.size.height * 0.7),
                                    CGPoint(x: geometry.size.width * 0.45, y: geometry.size.height * 0.35),
                                    CGPoint(x: geometry.size.width * 0.6, y: geometry.size.height * 0.5),
                                    CGPoint(x: geometry.size.width * 0.75, y: geometry.size.height * 0.25),
                                    CGPoint(x: geometry.size.width, y: geometry.size.height * 0.3)
                                ]
                                
                                for (index, point) in points.enumerated() {
                                    if index == 0 {
                                        path.move(to: point)
                                    } else {
                                        path.addLine(to: point)
                                    }
                                }
                            }
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2.5
                            )
                            
                            // Secondary trend line (lighter)
                            Path { path in
                                let points: [CGPoint] = [
                                    CGPoint(x: 0, y: geometry.size.height * 0.8),
                                    CGPoint(x: geometry.size.width * 0.2, y: geometry.size.height * 0.6),
                                    CGPoint(x: geometry.size.width * 0.4, y: geometry.size.height * 0.75),
                                    CGPoint(x: geometry.size.width * 0.6, y: geometry.size.height * 0.55),
                                    CGPoint(x: geometry.size.width * 0.8, y: geometry.size.height * 0.4),
                                    CGPoint(x: geometry.size.width, y: geometry.size.height * 0.45)
                                ]
                                
                                for (index, point) in points.enumerated() {
                                    if index == 0 {
                                        path.move(to: point)
                                    } else {
                                        path.addLine(to: point)
                                    }
                                }
                            }
                            .stroke(Color.green.opacity(0.6), lineWidth: 2)
                            
                            // Data points
                            ForEach(0..<5) { i in
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 4)
                                    .position(
                                        x: geometry.size.width * CGFloat(i) / 4,
                                        y: geometry.size.height * (0.3 + CGFloat.random(in: 0...0.4))
                                    )
                            }
                        }
                        .frame(height: 120)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Analytics stats with icons
                    HStack {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("Avg. Price")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("$\(product.currentPrice * 1.1, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text("Best Deal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("15% off")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text("Best Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("Nov-Dec")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Blur overlay with stock analytics background
                ZStack {
                    // Stock analytics background pattern
                    GeometryReader { geometry in
                        ZStack {
                            // Background gradient
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.1),
                                    Color.purple.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            // Multiple chart lines creating a stock image effect
                            Path { path in
                                let points: [(CGFloat, CGFloat)] = [
                                    (0.1, 0.7), (0.15, 0.5), (0.25, 0.6), (0.35, 0.3),
                                    (0.45, 0.4), (0.55, 0.2), (0.65, 0.35), (0.75, 0.15),
                                    (0.85, 0.25), (0.9, 0.1)
                                ]
                                
                                for (index, point) in points.enumerated() {
                                    let x = geometry.size.width * point.0
                                    let y = geometry.size.height * point.1
                                    
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                            
                            // Second trend line
                            Path { path in
                                let points: [(CGFloat, CGFloat)] = [
                                    (0.1, 0.8), (0.2, 0.6), (0.3, 0.75), (0.4, 0.5),
                                    (0.5, 0.65), (0.6, 0.4), (0.7, 0.55), (0.8, 0.3),
                                    (0.9, 0.45)
                                ]
                                
                                for (index, point) in points.enumerated() {
                                    let x = geometry.size.width * point.0
                                    let y = geometry.size.height * point.1
                                    
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(Color.green.opacity(0.15), lineWidth: 1.5)
                            
                            // Bar chart elements
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(0..<8) { i in
                                    Rectangle()
                                        .fill(Color.purple.opacity(0.1))
                                        .frame(width: 6, height: CGFloat.random(in: 10...40))
                                }
                            }
                            .position(x: geometry.size.width * 0.7, y: geometry.size.height * 0.7)
                        }
                    }
                    
                    // Blur overlay
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    // Content
                    VStack(spacing: 24) {
                        // Analytics icon with background
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            VStack(spacing: 6) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(.blue)
                                
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                    .offset(y: -8)
                            }
                        }
                        
                        VStack(spacing: 12) {
                            Text("Advanced Analytics")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Price predictions & market insights")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Coming Soon badge
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text("Coming Soon")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(20)
                        .padding(.top, 8)
                    }
                    .padding(40)
                }
                .frame(minHeight: 280)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
    
    // MARK: - Actions
    
    private func checkStatus() {
        isInWishlist = product.isFavorite
        isTracking = trackingService.isTracking(product)
    }
    
    private func saveItem() {
        withAnimation(.spring(response: 0.3)) {
            isInWishlist.toggle()
        }
        
        // Save to wishlist service
        Task {
            if isInWishlist {
                await wishlistService.addToWishlist(product)
                
                // Provide feedback that item was saved
                await MainActor.run {
                    print("✅ Item saved to collection: \(product.name)")
                    // Optionally dismiss after save or show success feedback
                }
            } else {
                await wishlistService.removeFromWishlist(product.id)
                
                await MainActor.run {
                    print("🗑️ Item removed from saved items: \(product.name)")
                }
            }
        }
    }
    
    private func toggleTracking() {
        withAnimation(.spring(response: 0.3)) {
            if isTracking {
                // Stop tracking
                trackingService.stopTracking(product)
                isTracking = false
            } else {
                // Start tracking
                trackingService.startTracking(product)
                isTracking = true
            }
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
    
    // MARK: - Amazon Reviews Sheet
    
    private var amazonReviewsSheet: some View {
        NavigationStack {
            ScrollView {
                if let reviews = reviews {
                    LazyVStack(spacing: 16) {
                        if let reviewsList = reviews.reviews {
                            ForEach(reviewsList.indices, id: \.self) { index in
                                let review = reviewsList[index]
                                AmazonReviewCardView(review: review)
                            }
                        } else {
                            Text("No reviews available")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                } else {
                    ProgressView("Loading reviews...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Product Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingReviews = false
                    }
                }
            }
        }
    }
    
    // MARK: - Amazon Prices Sheet
    
    private var amazonPricesSheet: some View {
        NavigationStack {
            ScrollView {
                if let prices = amazonPriceHistory {
                    VStack(spacing: 16) {
                        if let currentPrice = prices.currentPrice {
                            VStack {
                                Text("Current Price")
                                    .font(.headline)
                                Text("$\(currentPrice, specifier: "%.2f")")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        if let priceHistoryList = prices.priceHistory, !priceHistoryList.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Price History")
                                    .font(.headline)
                                    .padding(.bottom, 8)
                                
                                ForEach(priceHistoryList.indices, id: \.self) { index in
                                    let entry = priceHistoryList[index]
                                    HStack {
                                        Text(entry.date ?? "Unknown")
                                            .font(.caption)
                                        Spacer()
                                        if let price = entry.price {
                                            Text("$\(price, specifier: "%.2f")")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    ProgressView("Loading price history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Price History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingPrices = false
                    }
                }
            }
        }
    }
    
    // MARK: - Amazon API Methods
    
    private func loadAmazonReviews() {
        guard let productUrl = product.productUrl else {
            errorMessage = "Product URL not available for reviews"
            return
        }
        
        isLoadingReviews = true
        errorMessage = ""
        
        Task {
            do {
                let reviewsResponse = try await axessoService.getProductReviews(url: productUrl)
                await MainActor.run {
                    reviews = reviewsResponse
                    showingReviews = true
                    isLoadingReviews = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load reviews: \(error.localizedDescription)"
                    isLoadingReviews = false
                }
            }
        }
    }
    
    private func loadAmazonPriceHistory() {
        guard let productUrl = product.productUrl else {
            errorMessage = "Product URL not available for price history"
            return
        }
        
        isLoadingPrices = true
        errorMessage = ""
        
        Task {
            do {
                let pricesResponse = try await axessoService.getProductPrices(url: productUrl)
                await MainActor.run {
                    amazonPriceHistory = pricesResponse
                    showingPrices = true
                    isLoadingPrices = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load price history: \(error.localizedDescription)"
                    isLoadingPrices = false
                }
            }
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

struct AmazonReviewCardView: View {
    let review: AxessoAmazonReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.userName ?? "Anonymous")
                    .font(.headline)
                
                Spacer()
                
                if let rating = review.rating {
                    Text(rating)
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            
            if let title = review.title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            if let text = review.text {
                Text(text)
                    .font(.body)
            }
            
            if let date = review.date {
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
        .environmentObject(WishlistService.shared)
        // .environmentObject(BestBuyPriceTracker(bestBuyService: BestBuyAPIService(apiKey: "test"))) // DISABLED
        // .environmentObject(EbayNotificationManager()) // Commented out - EbayNotificationManager disabled
}