//
//  WalmartAPITestView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/28/25.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Test View

struct WalmartAPITestView: View {
    @State private var searchQuery = ""
    @State private var showAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var products: [ProductItemDTO] = []
    @State private var showDebugPanel = false
    @State private var debugMessages: [String] = []
    @State private var isShowingMockData = false
    @State private var showSearchSuggestions = false
    @State private var showNetworkStatusModal = false
    @State private var selectedProduct: ProductItemDTO?
    @State private var detailProduct: ProductItemDTO?
    @State private var relatedProducts: [ProductItemDTO] = []
    @State private var isLoadingDetails = false
    
    // Add focus state for handling keyboard
    @FocusState private var isSearchFieldFocused: Bool
    
    // Search suggestions - will be dynamically loaded
    @State private var searchSuggestions = ["iPhone", "Samsung TV", "AirPods", "Nintendo Switch", "Coffee Maker", "headphones"]
    
    @StateObject private var wishlistService = WishlistService()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // Service initialization
    @State private var service: WalmartAPIService?
    
    // Initializer with optional API key
    init(apiKey: String? = nil) {
        // Initialize service state - will be set up in setupService()
        _service = State(initialValue: nil)
    }
    
    // Helper to explicitly force the keyboard to appear
    #if os(iOS)
    private func forceKeyboardShow() {
        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar component
            searchBarView
            
            // Content area
            contentView
        }
        .navigationTitle("Walmart Products")
        .toolbar {
#if DEBUG
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showDebugPanel.toggle()
                    }) {
                        Label("Debug Panel", systemImage: "wrench.and.screwdriver")
                    }
                    
                    Button(action: {
                        showNetworkStatusModal.toggle()
                    }) {
                        Label("Network Test", systemImage: "network")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
#endif
        }
        .overlay(
            debugPanelView
        )
        .overlay(
            detailsLoadingOverlay
        )
        .overlay(
            // Network Status Modal
            Group {
                if showNetworkStatusModal {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showNetworkStatusModal = false
                            }
                        
                        NetworkStatusModal(
                            isPresented: $showNetworkStatusModal,
                            networkMonitor: networkMonitor,
                            onTestRequest: {
                                await networkMonitor.testConnectivity()
                            }
                        )
                    }
                }
            }
        )
        .onAppear {
            setupService()
            // This helps ensure the keyboard appears when needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                isSearchFieldFocused = true
                #if os(iOS)
                forceKeyboardShow()
                #endif
                withAnimation {}
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchBarView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search Walmart products...", text: $searchQuery)
                    .focused($isSearchFieldFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        searchProducts(query: searchQuery)
                    }
                    .onChange(of: isSearchFieldFocused) { _, isFocused in
                        showSearchSuggestions = isFocused && searchQuery.isEmpty
                    }
                    .onChange(of: searchQuery) { _, newValue in
                        showSearchSuggestions = isSearchFieldFocused && newValue.isEmpty
                        isSearchFieldFocused = true
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        isSearchFieldFocused = true // Keep focus after clearing
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {
                    searchProducts(query: searchQuery)
                }) {
                    Text("Search")
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(searchQuery.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(searchQuery.isEmpty || isLoading)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Search suggestions (only when search field is focused and empty)
            if showSearchSuggestions {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try searching for:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(searchSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                searchQuery = suggestion
                                showSearchSuggestions = false
                                searchProducts(query: suggestion)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                            .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    private var contentView: some View {
        ZStack {
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if products.isEmpty {
                emptyStateView
            } else {
                productListView
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Searching Walmart...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                if !searchQuery.isEmpty {
                    searchProducts(query: searchQuery)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var productListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(products) { product in
                    WalmartProductCard(
                        product: product,
                        wishlistService: wishlistService,
                        onTap: {
                            selectedProduct = product
                            loadProductDetails(for: product)
                        },
                        onSave: { product in
                            saveToWishlist(product)
                        },
                        onTrack: { product in
                            startTracking(product)
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 16) // Add spacing between search bar and cards
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Search Walmart Products")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enter a product name to start searching")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button("Search Popular Products") {
                    loadTrendingProducts()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Browse Categories") {
                    searchQuery = searchSuggestions.randomElement() ?? "iPhone"
                    searchProducts(query: searchQuery)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var detailsLoadingOverlay: some View {
        Group {
            if isLoadingDetails {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading details...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var debugPanelView: some View {
        Group {
            if showDebugPanel {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Walmart API Debug Panel")
                                .font(.headline)
                            Spacer()
                            Button("Close") {
                                showDebugPanel = false
                            }
                        }
                        
                        authTestSection
                        apiTestsSection
                        debugLogsSection
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding()
                }
                .background(Color.black.opacity(0.3))
                .ignoresSafeArea()
                .onTapGesture {
                    showDebugPanel = false
                }
            }
        }
    }
    
    private var authTestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Connection")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Button("Test Walmart API Connection") {
                testWalmartConnection()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
    
    private var apiTestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Tests")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack {
                Button("Search Test") {
                    searchProducts(query: "test product")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Mock Data") {
                    loadMockData()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Clear Results") {
                    products = []
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private var debugLogsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Logs")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Clear") {
                    debugMessages.removeAll()
                }
                .font(.caption)
            }
            
            if debugMessages.isEmpty {
                Text("No debug messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(debugMessages.reversed(), id: \.self) { message in
                            Text(message)
                                .font(.caption)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .frame(maxHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Actions
    
    private func setupService() {
        Task {
            do {
                let apiConfig = APIConfig()
                let walmartService = try await apiConfig.createWalmartService()
                await MainActor.run {
                    service = walmartService
                    addDebugMessage("✅ Walmart API service initialized")
                }
                // Load dynamic search suggestions
                await loadSearchSuggestions()
            } catch {
                await MainActor.run {
                    addDebugMessage("❌ Failed to initialize Walmart service: \(error)")
                    service = WalmartAPIService.createPreview()
                }
                // Still try to load search suggestions from the preview service
                await loadSearchSuggestions()
            }
        }
    }
    
    private func loadSearchSuggestions() async {
        guard let service = service else { return }
        
        let suggestions = await service.getSearchSuggestions()
        await MainActor.run {
            searchSuggestions = suggestions
            addDebugMessage("✅ Loaded \(suggestions.count) search suggestions")
        }
    }
    
    private func saveToWishlist(_ product: ProductItemDTO) {
        Task {
            await wishlistService.saveToWishlist(from: product)
            await MainActor.run {
                addDebugMessage("💾 Saved '\(product.name)' to wishlist")
            }
        }
    }
    
    private func startTracking(_ product: ProductItemDTO) {
        Task {
            // Create a WalmartPriceTracker if we have the service
            if let walmartService = service {
                let priceTracker = await WalmartPriceTracker(walmartService: walmartService)
                
                // Add item to price tracking with 10% threshold
                priceTracker.addItem(product, thresholdPrice: nil, thresholdPercentage: 10.0)
                
                await MainActor.run {
                    addDebugMessage("📊 Started tracking '\(product.name)' for price changes")
                }
            } else {
                await MainActor.run {
                    addDebugMessage("⚠️ Cannot start tracking - service not available")
                }
            }
        }
    }
    
    private func searchProducts(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        showSearchSuggestions = false
        isSearchFieldFocused = false
        
        addDebugMessage("🔍 Searching for: '\(query)'")
        
        Task {
            do {
                let results = try await service?.searchProducts(query: query) ?? []
                
                await MainActor.run {
                    self.products = results
                    self.isLoading = false
                    
                    if results.isEmpty {
                        addDebugMessage("⚠️ No products found for '\(query)'")
                    } else {
                        addDebugMessage("✅ Found \(results.count) products for '\(query)'")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    addDebugMessage("❌ Search failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadTrendingProducts() {
        isLoading = true
        errorMessage = nil
        searchQuery = ""
        showSearchSuggestions = false
        isSearchFieldFocused = false
        
        addDebugMessage("🔥 Loading trending products...")
        
        Task {
            do {
                let results = try await service?.getTrendingProducts() ?? []
                
                await MainActor.run {
                    self.products = results
                    self.isLoading = false
                    
                    if results.isEmpty {
                        addDebugMessage("⚠️ No trending products found")
                    } else {
                        addDebugMessage("✅ Found \(results.count) trending products")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load trending products: \(error.localizedDescription)"
                    addDebugMessage("❌ Trending products failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadProductDetails(for product: ProductItemDTO) {
        detailProduct = product
        isLoadingDetails = true
        
        addDebugMessage("📄 Loading details for: \(product.name)")
        
        Task {
            do {
                let details = try await service?.getProductDetails(id: product.sourceId)
                let related = try await service?.getRelatedProducts(id: product.sourceId) ?? []
                
                await MainActor.run {
                    if let details = details {
                        self.detailProduct = details
                        self.relatedProducts = related
                        addDebugMessage("✅ Loaded details and \(related.count) related products")
                    }
                    self.isLoadingDetails = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingDetails = false
                    addDebugMessage("❌ Failed to load details: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func testWalmartConnection() {
        addDebugMessage("🔗 Testing Walmart API connection...")
        
        Task {
            let success = await service?.testConnection() ?? false
            await MainActor.run {
                if success {
                    addDebugMessage("✅ Walmart API connection successful")
                } else {
                    addDebugMessage("❌ Walmart API connection failed")
                }
            }
        }
    }
    
    private func loadMockData() {
        addDebugMessage("🎭 Loading mock data...")
        
        products = [
            ProductItemDTO(
                sourceId: "123456789",
                name: "Apple AirPods Pro (2nd generation) with MagSafe Case (USB‑C)",
                productDescription: "AirPods Pro feature up to 2x more Active Noise Cancellation, plus Adaptive Transparency.",
                price: 249.99,
                originalPrice: 299.99,
                currency: "USD",
                imageURL: URL(string: "https://i5.walmartimages.com/seo/Apple-AirPods-Pro-2nd-generation.jpg"),
                brand: "Apple",
                source: "Walmart",
                category: "Electronics",
                isInStock: true,
                rating: 4.8,
                reviewCount: 2156
            ),
            ProductItemDTO(
                sourceId: "987654321",
                name: "Samsung 65-Inch Class Crystal UHD 4K Smart TV",
                productDescription: "Experience stunning 4K resolution with vibrant colors and sharp detail.",
                price: 497.99,
                originalPrice: 649.99,
                currency: "USD",
                imageURL: URL(string: "https://i5.walmartimages.com/seo/Samsung-65-Class-Crystal-UHD.jpg"),
                brand: "Samsung",
                source: "Walmart",
                category: "Televisions",
                isInStock: true,
                rating: 4.6,
                reviewCount: 892
            )
        ]
        
        addDebugMessage("✅ Loaded \(products.count) mock products")
    }
    
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.debugFormatter.string(from: Date())
        debugMessages.append("[\(timestamp)] \(message)")
        
        // Keep only the most recent 50 messages
        if debugMessages.count > 50 {
            debugMessages.removeFirst(debugMessages.count - 50)
        }
    }
}

// MARK: - Image Handling Functions

private func getWalmartImageURL(for product: ProductItemDTO) -> URL? {
    print("🖼️ Finding image for: \(product.name)")
    
    // Step 1: Try provided imageURL first
    if let imageURL = product.imageURL {
        print("✅ Using provided imageURL: \(imageURL)")
        return imageURL
    }
    
    // Step 2: Try imageUrls array
    if let imageUrls = product.imageUrls, let firstImageUrl = imageUrls.first, let url = URL(string: firstImageUrl) {
        print("✅ Using first imageUrl: \(url)")
        return url
    }
    
    // Step 3: Try thumbnailUrl
    if let thumbnailUrl = product.thumbnailUrl, let url = URL(string: thumbnailUrl) {
        print("✅ Using thumbnailUrl: \(url)")
        return url
    }
    
    // Step 4: Generate Walmart CDN URLs based on product info
    if let generatedURL = generateWalmartCDNURL(for: product) {
        print("✅ Using generated Walmart CDN URL: \(generatedURL)")
        return generatedURL
    }
    
    // Step 5: Brand-specific fallback URLs
    if let brandURL = getBrandFallbackURL(for: product) {
        print("✅ Using brand fallback URL: \(brandURL)")
        return brandURL
    }
    
    print("❌ No image URL found for: \(product.name)")
    return nil
}

private func generateWalmartCDNURL(for product: ProductItemDTO) -> URL? {
    let cleanName = product.name
        .lowercased()
        .replacingOccurrences(of: " ", with: "-")
        .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
    
    // Common Walmart image patterns
    let patterns = [
        "https://i5.walmartimages.com/seo/\(cleanName)_\(product.sourceId).jpg",
        "https://i5.walmartimages.com/asr/\(product.sourceId).jpg",
        "https://i5.walmartimages.com/dfw/\(product.sourceId)/k2-_\(product.sourceId).jpg",
        "https://images.walmartimages.com/images/large/\(product.sourceId).jpg"
    ]
    
    for pattern in patterns {
        if let url = URL(string: pattern) {
            return url
        }
    }
    
    return nil
}

private func getBrandFallbackURL(for product: ProductItemDTO) -> URL? {
    let brand = product.brand.lowercased()
    
    switch brand {
    case "apple":
        if product.name.lowercased().contains("iphone") {
            return URL(string: "https://i5.walmartimages.com/seo/Apple-iPhone-Generic_placeholder.jpg")
        } else if product.name.lowercased().contains("airpods") {
            return URL(string: "https://i5.walmartimages.com/seo/Apple-AirPods-Generic_placeholder.jpg")
        } else if product.name.lowercased().contains("watch") {
            return URL(string: "https://i5.walmartimages.com/seo/Apple-Watch-Generic_placeholder.jpg")
        } else if product.name.lowercased().contains("ipad") {
            return URL(string: "https://i5.walmartimages.com/seo/Apple-iPad-Generic_placeholder.jpg")
        }
    case "samsung":
        if product.name.lowercased().contains("tv") {
            return URL(string: "https://i5.walmartimages.com/seo/Samsung-TV-Generic_placeholder.jpg")
        }
    case "sony":
        if product.name.lowercased().contains("headphones") {
            return URL(string: "https://i5.walmartimages.com/seo/Sony-Headphones-Generic_placeholder.jpg")
        } else if product.name.lowercased().contains("playstation") {
            return URL(string: "https://i5.walmartimages.com/seo/PlayStation-5-Generic_placeholder.jpg")
        }
    case "nintendo":
        if product.name.lowercased().contains("switch") {
            return URL(string: "https://i5.walmartimages.com/seo/Nintendo-Switch-Generic_placeholder.jpg")
        }
    default:
        break
    }
    
    return nil
}

private func getCategoryPlaceholderImage(for product: ProductItemDTO) -> String {
    let category = product.category?.lowercased() ?? ""
    let name = product.name.lowercased()
    
    if category.contains("electronics") || name.contains("phone") || name.contains("tablet") {
        return "iphone"
    } else if category.contains("audio") || name.contains("headphones") || name.contains("airpods") {
        return "headphones"
    } else if category.contains("video games") || name.contains("nintendo") || name.contains("playstation") {
        return "gamecontroller"
    } else if category.contains("tv") || name.contains("tv") {
        return "tv"
    } else if category.contains("home") || name.contains("coffee") || name.contains("blender") {
        return "house"
    } else if name.contains("watch") {
        return "applewatch"
    } else {
        return "square.grid.2x2"
    }
}

// MARK: - Walmart Product Card Component

struct WalmartProductCard: View {
    let product: ProductItemDTO
    let wishlistService: WishlistService
    let onTap: () -> Void
    let onSave: (ProductItemDTO) -> Void
    let onTrack: (ProductItemDTO) -> Void
    
    @State private var isSaved: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image with Smart Fallback
            Button(action: onTap) {
                AsyncImage(url: getWalmartImageURL(for: product)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure(_):
                        // Show category-specific icon when image fails
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                Image(systemName: getCategoryPlaceholderImage(for: product))
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            )
                    case .empty:
                        // Show loading state
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    @unknown default:
                        // Fallback for future cases
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Product Info
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if !product.brand.isEmpty {
                        Text(product.brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if let price = product.price {
                            Text("$\(price, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        if let originalPrice = product.originalPrice,
                           originalPrice > (product.price ?? 0) {
                            Text("$\(originalPrice, specifier: "%.2f")")
                                .font(.caption)
                                .strikethrough()
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        if product.isInStock {
                            Label("In Stock", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("Out of Stock", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                    }
                    
                    if let rating = product.rating, let reviewCount = product.reviewCount {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(rating, specifier: "%.1f")")
                                .font(.caption)
                            Text("(\(reviewCount))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 8) {
                Button(action: {
                    onSave(product)
                    isSaved.toggle()
                }) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(isSaved ? .red : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    onTrack(product)
                }) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onTap) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            checkIfSaved()
        }
    }
    
    private func checkIfSaved() {
        Task {
            await MainActor.run {
                isSaved = wishlistService.savedItems.contains { $0.sourceId == product.sourceId && $0.source == product.source }
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let debugFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// MARK: - Preview

struct WalmartAPITestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WalmartAPITestView()
        }
    }
}
