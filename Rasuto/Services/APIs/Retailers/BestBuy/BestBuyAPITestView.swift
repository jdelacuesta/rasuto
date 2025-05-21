//
//  BestBuyAPITestView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/19/25.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


// MARK: - Test View

struct BestBuyAPITestView: View {
    @State private var searchQuery = ""
    @State private var showAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var products: [ProductItemDTO] = []
    @State private var showDebugPanel = false
    @State private var debugMessages: [String] = []
    @State private var isShowingMockData = false
    @State private var showSearchSuggestions = false
    
    // Predefined search suggestions for demonstration
    private let searchSuggestions = ["headphones", "phone", "laptop", "tv", "camera", "gaming"]
    
    @EnvironmentObject var priceTracker: BestBuyPriceTracker
    
    // Service initialization
    @State private var service: BestBuyAPIService?
    
    var body: some View {
        NavigationView {
            VStack {
                // Enhanced search section
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        TextField("Search for: headphones, phone, laptop...", text: $searchQuery)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: searchQuery) { newValue in
                                showSearchSuggestions = newValue.isEmpty
                            }
                        
                        Button(action: {
                            searchProducts(query: searchQuery)
                        }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    
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
                    }
                    
                    // Hybrid approach indicator
                    if !products.isEmpty {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Using working Best Buy API endpoints (Hybrid approach)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                
                if isLoading {
                    // Loading indicator
                    ProgressView("Loading...")
                        .padding()
                } else if let errorMessage = errorMessage {
                    // Error message
                    VStack {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .foregroundColor(.red)
                        Button("Try Again") {
                            searchProducts(query: searchQuery)
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                    }
                } else {
                    // Product list
                    List(products, id: \.sourceId) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            ProductRow(product: product)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Best Buy Products")
            .alert("API Key Required", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please replace 'YOUR_BEST_BUY_API_KEY' in the BestBuyAPIService class with your actual Best Buy API key.")
            }
            .onAppear {
                initializeService()
                testAPIConnection()
                // Load some initial products for demo
                if searchQuery.isEmpty {
                    Task {
                        await loadInitialProducts()
                    }
                }
            }
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDebugPanel.toggle()
                    }) {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                }
                #endif
            }
            .overlay(
                debugPanelView
            )
        }
    }
    
    private func loadInitialProducts() async {
        addDebugMessage("🎯 Loading initial products using hybrid approach...")
        
        guard let service = service else {
            addDebugMessage("❌ Service not initialized for initial load")
            return
        }
        
        do {
            // Load trending/popular products for initial display
            let initialProducts = try await service.getTrendingProducts()
            
            await MainActor.run {
                self.products = initialProducts
                addDebugMessage("✅ Loaded \(initialProducts.count) initial products")
                
                if let first = initialProducts.first {
                    addDebugMessage("📝 Example: \(first.name)")
                }
            }
        } catch {
            addDebugMessage("⚠️ Failed to load initial products: \(error)")
        }
    }
    
    private func initializeService() {
        #if DEBUG
        if let previewFlag = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"], previewFlag == "1" {
            // We're in preview mode
            service = BestBuyAPIService.createPreview()
            // Instead of directly accessing mockProducts, load them through a method
            Task {
                do {
                    // Call getRecommendedProducts which returns the mock products in preview mode
                    let mockResults = try await service?.getRecommendedProducts()
                    await MainActor.run {
                        products = mockResults ?? []
                    }
                } catch {
                    print("Error loading mock products: \(error)")
                }
            }
        } else {
            do {
                // Try to get API key from SecretKeys first
                let secretKey = SecretKeys.bestBuyRapidApiKey
                
                // Try to add the key to keychain if it doesn't exist and SecretKeys has a valid key
                if !APIKeyManager.shared.hasAPIKey(for: "bestbuy.rapidapi_key") && !secretKey.isEmpty {
                    try APIKeyManager.shared.saveAPIKey(for: "bestbuy.rapidapi_key", key: secretKey)
                    addDebugMessage("Saved Best Buy API key from SecretKeys to keychain")
                }
                
                // Now create the service
                service = try BestBuyAPIService.create()
                
                // If we get here, service was initialized successfully
                addDebugMessage("Successfully initialized BestBuyAPIService")
            } catch {
                errorMessage = "Failed to initialize API service: \(error.localizedDescription)"
                showAlert = true
                addDebugMessage("Error initializing service: \(error)")
            }
        }
        #else
        do {
            // For production builds
            service = try BestBuyAPIService.create()
        } catch {
            errorMessage = "Failed to initialize API service: \(error.localizedDescription)"
            showAlert = true
        }
        #endif
    }
    
    private func testAPIConnection() {
        guard let service = service else {
            return
        }
        
        Task {
            addDebugMessage("🔍 Testing API connection...")
            let success = await service.testAPIConnection()
            if success {
                addDebugMessage("✅ Successfully connected to Best Buy API")
            } else {
                addDebugMessage("❌ Failed to connect to Best Buy API")
                await MainActor.run {
                    showAlert = true
                }
            }
        }
    }
    
    private func searchProducts(query: String) {
        guard let service = service else {
            errorMessage = "Service not initialized"
            return
        }
        
        guard !query.isEmpty else {
            errorMessage = "Search query cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                addDebugMessage("🔍 Searching for: \(query)")
                let results = try await service.searchProducts(query: query)
                await MainActor.run {
                    products = results
                    isLoading = false
                    addDebugMessage("✅ Found \(results.count) products")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                    addDebugMessage("❌ Search error: \(error)")
                }
            }
        }
    }
    
    private func trackItemFromSearch(_ product: ProductItemDTO) {
        Task {
            if let price = product.price {
                let success = await priceTracker.trackItem(
                    sku: product.sourceId,
                    name: product.name,
                    currentPrice: price,
                    imageUrl: product.thumbnailUrl
                )
                
                if success {
                    print("Successfully tracking \(product.name)")
                } else {
                    print("Failed to track \(product.name)")
                }
            }
        }
    }
    
    // MARK: - Debug Helpers
    
    private func addDebugMessage(_ message: String) {
        Task { @MainActor in
            debugMessages.append("\(Date().formatted(date: .omitted, time: .standard)): \(message)")
            // Keep only the most recent 50 messages
            if debugMessages.count > 50 {
                debugMessages.removeFirst(debugMessages.count - 50)
            }
        }
    }
    
    // MARK: - Debug Panel Views
    
    private var debugPanelView: some View {
        Group {
            #if DEBUG
            if showDebugPanel {
                VStack(spacing: 12) {
                    HStack {
                        Text("Debug Tools")
                            .font(.headline)
                            .padding(.top)
                        
                        Spacer()
                        
                        Button(action: {
                            showDebugPanel = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                    
                    authTestSection
                    
                    Divider()
                    
                    apiTestsSection
                    
                    Divider()
                    
                    debugLogsSection
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showDebugPanel = false
                        }
                )
                .transition(.opacity)
                .animation(.easeInOut, value: showDebugPanel)
            }
            #endif
        }
    }
    
    private var authTestSection: some View {
        Group {
            Text("API Authentication Test")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            Button("Test Best Buy API Connection") {
                Task {
                    await verifyAPICredentials()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Check API Key") {
                Task {
                    await checkAPIKey()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var apiTestsSection: some View {
        Group {
            Text("API Feature Tests")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            Button("Test Hybrid Search (headphones)") {
                Task {
                    await testHybridSearch("headphones")
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Test Popular Terms") {
                Task {
                    await testPopularTerms()
                }
            }
            .buttonStyle(.bordered)
            
            Button("Test Search Mapping") {
                Task {
                    await testSearchMapping()
                }
            }
            .buttonStyle(.bordered)
            
            Button("Test Categories") {
                Task {
                    await testCategories()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Test Product Details") {
                Task {
                    await testProductDetails()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Test Full Workflow") {
                Task {
                    await testFullWorkflow()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var debugLogsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Logs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Clear") {
                    debugMessages.removeAll()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(debugMessages.reversed(), id: \.self) { message in
                        Text(message)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: 200)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Debug Test Methods
    
    private func verifyAPICredentials() async {
        addDebugMessage("🔍 Checking Best Buy API credentials...")
        
        do {
            // Try to get the API key from APIKeyManager
            let apiKeyFromManager = try? APIKeyManager.shared.getAPIKey(for: "bestbuy.rapidapi_key")
            
            if let key = apiKeyFromManager {
                addDebugMessage("✅ Found API key in keychain: \(key.prefix(4))...")
            } else {
                addDebugMessage("⚠️ No API key found in keychain")
            }
            
            // Try to get the API key from SecretKeys
            let apiKeyFromSecrets = SecretKeys.bestBuyApiKey
            addDebugMessage("📝 API key from SecretKeys: \(apiKeyFromSecrets.prefix(4))...")
            
            // Test connection
            if let service = service {
                let success = await service.testAPIConnection()
                if success {
                    addDebugMessage("✅ API connection test successful")
                } else {
                    addDebugMessage("❌ API connection test failed")
                }
            } else {
                addDebugMessage("❌ Service not initialized")
            }
        } catch {
            addDebugMessage("❌ Verification failed: \(error)")
        }
    }
    
    private func checkAPIKey() async {
        addDebugMessage("🔍 Checking Best Buy API key...")
        
        do {
            let apiKey = try? APIKeyManager.shared.getAPIKey(for: "bestbuy.rapidapi_key")
            if let key = apiKey {
                addDebugMessage("✅ Found key: \(key.prefix(4))...")
                
                // Try to save the key to make sure it works
                try APIKeyManager.shared.saveAPIKey(for: "bestbuy.rapidapi_key", key: key)
                addDebugMessage("✅ Successfully saved key to keychain")
            } else {
                // Try getting key from SecretKeys
                let secretKey = SecretKeys.bestBuyRapidApiKey
                if !secretKey.isEmpty {
                    try APIKeyManager.shared.saveAPIKey(for: "bestbuy.rapidapi_key", key: secretKey)
                    addDebugMessage("✅ Saved key from SecretKeys to keychain")
                } else {
                    addDebugMessage("❌ No API key available in SecretKeys")
                }
            }
        } catch {
            addDebugMessage("❌ Failed to check/save API key: \(error)")
        }
    }
    
    private func testHybridSearch(_ query: String) async {
        addDebugMessage("🚀 Testing hybrid search approach for '\(query)'...")
        
        guard let service = service else {
            addDebugMessage("❌ Service not initialized")
            return
        }
        
        do {
            let results = try await service.searchProducts(query: query)
            addDebugMessage("✅ Hybrid search returned \(results.count) results")
            
            if let first = results.first {
                addDebugMessage("📝 First result: \(first.name) (SKU: \(first.sourceId))")
                addDebugMessage("💰 Price: $\(first.price ?? 0)")
                addDebugMessage("🏢 Brand: \(first.brand)")
            }
            
            // Update UI to show results
            await MainActor.run {
                self.products = results
                self.searchQuery = query
            }
        } catch {
            addDebugMessage("❌ Hybrid search failed: \(error)")
        }
    }
    
    private func testPopularTerms() async {
        addDebugMessage("🔥 Testing popular terms endpoint...")
        
        guard let service = service as? BestBuyAPIService else {
            addDebugMessage("❌ Service not initialized as BestBuyAPIService")
            return
        }
        
        do {
            let popularTerms = try await service.getPopularTerms()
            addDebugMessage("✅ Retrieved \(popularTerms.count) popular terms")
            
            for (index, term) in popularTerms.prefix(5).enumerated() {
                addDebugMessage("📝 \(index + 1). \(term.term) (popularity: \(term.popularity ?? 0))")
            }
        } catch {
            addDebugMessage("❌ Popular terms retrieval failed: \(error)")
        }
    }
    
    private func testSearchMapping() async {
        addDebugMessage("🗺️ Testing search term to SKU mapping...")
        
        guard let service = service as? BestBuyAPIService else {
            addDebugMessage("❌ Service not initialized as BestBuyAPIService")
            return
        }
        
        // Print the search mapping
        service.printSearchMapping()
        
        // Test a few specific mappings
        let testTerms = ["headphones", "phone", "laptop"]
        
        for term in testTerms {
            addDebugMessage("🎯 Testing mapping for '\(term)'...")
            
            do {
                let results = try await service.searchProducts(query: term)
                addDebugMessage("✅ '\(term)' mapped to \(results.count) products")
                
                if let first = results.first {
                    addDebugMessage("   📝 Example: \(first.name) (SKU: \(first.sourceId))")
                }
            } catch {
                addDebugMessage("❌ Mapping test for '\(term)' failed: \(error)")
            }
        }
    }
    
    private func testCategories() async {
        addDebugMessage("🔍 Testing categories API...")
        
        guard let service = service as? BestBuyAPIService else {
            addDebugMessage("❌ Service not initialized as BestBuyAPIService")
            return
        }
        
        do {
            let categories = try await service.getCategories()
            addDebugMessage("✅ Retrieved \(categories.count) top-level categories")
            
            if let first = categories.first {
                addDebugMessage("📝 First category: \(first.name)")
                
                if let subCategories = first.subCategories, !subCategories.isEmpty {
                    addDebugMessage("📝 Has \(subCategories.count) subcategories")
                }
            }
        } catch {
            addDebugMessage("❌ Categories retrieval failed: \(error)")
        }
    }
    
    private func testProductDetails() async {
        addDebugMessage("🔍 Testing hybrid product details API...")
        
        guard let service = service else {
            addDebugMessage("❌ Service not initialized")
            return
        }
        
        // Test with known working SKUs from our hybrid mapping
        let testSkus = ["6501022", "6509928", "6535147"] // Beats Solo 4, iPhone 15 Pro, Bose headphones
        
        for sku in testSkus {
            do {
                addDebugMessage("🎯 Testing SKU: \(sku)")
                let product = try await service.getProductDetails(id: sku)
                addDebugMessage("✅ \(sku): \(product.name)")
                
                if let price = product.price {
                    addDebugMessage("   💰 Price: $\(price)")
                }
                
                addDebugMessage("   🏢 Brand: \(product.brand)")
            } catch {
                addDebugMessage("❌ SKU \(sku) failed: \(error)")
            }
        }
    }
    
    private func testFullWorkflow() async {
        addDebugMessage("🚀 Testing enhanced hybrid Best Buy API workflow...")
        
        guard let service = service as? BestBuyAPIService else {
            addDebugMessage("❌ Service not initialized as BestBuyAPIService")
            return
        }
        
        // Step 1: Test connection
        let connectionSuccess = await service.testAPIConnection()
        addDebugMessage(connectionSuccess ? "✅ API connection successful" : "❌ API connection failed")
        
        if !connectionSuccess {
            return
        }
        
        // Step 2: Test popular terms endpoint
        do {
            let popularTerms = try await service.getPopularTerms()
            addDebugMessage("✅ Retrieved \(popularTerms.count) popular terms")
            
            // Step 3: Test hybrid search with a popular term
            if let firstTerm = popularTerms.first {
                addDebugMessage("🎯 Testing hybrid search with popular term: \(firstTerm.term)")
                
                let searchResults = try await service.searchProducts(query: firstTerm.term)
                addDebugMessage("✅ Hybrid search returned \(searchResults.count) products")
                
                // Step 4: Test product details for first result
                if let product = searchResults.first {
                    addDebugMessage("📝 Getting details for: \(product.name) (SKU: \(product.sourceId))")
                    
                    let details = try await service.getProductDetails(id: product.sourceId)
                    addDebugMessage("✅ Retrieved details: \(details.name) - $\(details.price ?? 0)")
                    
                    // Step 5: Test product pricing if available
                    do {
                        let pricing = try await service.getProductPricing(sku: product.sourceId)
                        addDebugMessage("✅ Retrieved pricing: $\(pricing.currentPrice) (regular: $\(pricing.regularPrice))")
                    } catch {
                        addDebugMessage("⚠️ Pricing test optional: \(error)")
                    }
                    
                    // Step 6: Test trending products
                    let trending = try await service.getTrendingProducts()
                    addDebugMessage("✅ Found \(trending.count) trending products")
                    
                    addDebugMessage("🎉 Enhanced hybrid workflow test completed successfully!")
                    
                    // Update UI with results
                    await MainActor.run {
                        self.products = searchResults
                        self.searchQuery = firstTerm.term
                    }
                }
            }
        } catch {
            addDebugMessage("❌ Enhanced workflow test failed: \(error)")
        }
    }
}

// MARK: - UI Components

struct ProductRow: View {
    let product: ProductItemDTO
    
    var body: some View {
        HStack {
            // Product image
            AsyncImage(url: getImageURL(product)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .foregroundColor(.gray)
                        .frame(width: 60, height: 60)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                case .failure:
                    Image(systemName: "photo")
                        .frame(width: 60, height: 60)
                @unknown default:
                    EmptyView()
                        .frame(width: 60, height: 60)
                }
            }
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .lineLimit(2)
                
                if let price = product.price {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                if let rating = product.rating {
                    HStack {
                        StarsView(rating: rating)
                        if let reviewCount = product.reviewCount {
                            Text("(\(reviewCount))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // Helper function inside the view to avoid extension conflicts
    private func getImageURL(_ product: ProductItemDTO) -> URL? {
        if let imageURL = product.imageURL {
            return imageURL
        } else if let imageUrls = product.imageUrls, let firstImageUrl = imageUrls.first,
                  let url = URL(string: firstImageUrl) {
            return url
        } else if let thumbnailUrl = product.thumbnailUrl, let url = URL(string: thumbnailUrl) {
            return url
        }
        return nil
    }
}

struct StarsView: View {
    let rating: Double
    let maxRating: Int = 5
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= Int(rating) ? "star.fill" : (star <= Int(rating) + 1 && star > Int(rating) && rating.truncatingRemainder(dividingBy: 1) > 0.3 ? "star.leadinghalf.fill" : "star"))
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
    }
}

struct ProductDetailView: View {
    let product: ProductItemDTO
    @EnvironmentObject var priceTracker: BestBuyPriceTracker
    @State private var showTrackingConfirmation = false
    @State private var trackingSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Product image
                AsyncImage(url: getImageURL(product)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .foregroundColor(.gray)
                            .aspectRatio(contentMode: .fit)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity, alignment: .center)
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Product info
                VStack(alignment: .leading, spacing: 8) {
                    Text(product.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let price = product.price {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    if let rating = product.rating {
                        HStack {
                            StarsView(rating: rating)
                            if let reviewCount = product.reviewCount {
                                Text("(\(reviewCount) reviews)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Divider()
                    
                    if let description = product.productDescription {
                        Text("Description")
                            .font(.headline)
                        
                        Text(description)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    // Action Buttons - Stack them vertically
                    VStack(spacing: 12) {
                        // Track Price Button
                        Button {
                            trackItem(product)
                        } label: {
                            HStack {
                                Image(systemName: "bell.fill")
                                Text("Track Price")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        
                        // View on Best Buy button
                        Button {
                            // Open URL if available
                            let urlString = "https://www.bestbuy.com/site/\(product.sourceId).p"
                            if let url = URL(string: urlString) {
                                #if os(iOS)
                                UIApplication.shared.open(url)
                                #elseif os(macOS)
                                NSWorkspace.shared.open(url)
                                #endif
                            }
                        } label: {
                            HStack {
                                Image(systemName: "safari.fill")
                                Text("View on Best Buy")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Price Tracking", isPresented: $showTrackingConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            if trackingSuccess {
                Text("You'll be notified when the price of \(product.name) drops.")
            } else {
                Text("Failed to track this item. Please try again later.")
            }
        }
    }
    
    // Helper function inside the view to avoid extension conflicts
    private func getImageURL(_ product: ProductItemDTO) -> URL? {
        if let imageURL = product.imageURL {
            return imageURL
        } else if let imageUrls = product.imageUrls, let firstImageUrl = imageUrls.first,
                  let url = URL(string: firstImageUrl) {
            return url
        } else if let thumbnailUrl = product.thumbnailUrl, let url = URL(string: thumbnailUrl) {
            return url
        }
        return nil
    }
    
    // Track price method
    private func trackItem(_ product: ProductItemDTO) {
        Task {
            do {
                // Make sure we have a price to track
                guard let currentPrice = product.price else {
                    trackingSuccess = false
                    showTrackingConfirmation = true
                    return
                }
                
                // Use priceTracker from environment to track the item
                let success = await priceTracker.trackItem(
                    sku: product.sourceId,
                    name: product.name,
                    currentPrice: currentPrice,
                    imageUrl: product.thumbnailUrl
                )
                
                // Update UI on main actor
                await MainActor.run {
                    trackingSuccess = success
                    showTrackingConfirmation = true
                    print(success ? "Successfully tracking price for \(product.name)" : "Failed to track price for \(product.name)")
                }
            } catch {
                // Handle any errors
                await MainActor.run {
                    trackingSuccess = false
                    showTrackingConfirmation = true
                    print("Error tracking price: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview Provider

#Preview {
    let mockService = BestBuyAPIService(apiKey: "PREVIEW_API_KEY")
    let mockTracker = BestBuyPriceTracker(bestBuyService: mockService)
    
    return NavigationView {
        BestBuyAPITestView()
            .environmentObject(mockTracker)
    }
}
