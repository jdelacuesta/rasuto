//
//  EbayAPITestView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/15/25.
//

import SwiftUI

struct EbayAPITestView: View {
    @EnvironmentObject var notificationManager: EbayNotificationManager
    @State private var searchQuery = ""
    @State private var products: [ProductItemDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProductId: String?
    @State private var selectedCategory: String? = nil
    @State private var detailProduct: ProductItemDTO?
    @State private var relatedProducts: [ProductItemDTO] = []
    @State private var isLoadingDetails = false
    @State private var showDebugPanel = false
    @State private var isShowingMockData: Bool = false
    
    // Add focus state for handling keyboard
    @FocusState private var isSearchFieldFocused: Bool
    
    // ADD THIS FUNCTION HERE - between properties and body
    #if os(iOS)
    // Helper to explicitly force the keyboard to appear
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
        .navigationTitle("eBay Products")
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
            detailsLoadingOverlay
        )
        .overlay(
            debugPanelView
        )
        .onAppear {
            // This helps ensure the keyboard appears when needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                isSearchFieldFocused = true
                // ADD THIS LINE HERE to use the function
                #if os(iOS)
                forceKeyboardShow()
                #endif
                withAnimation {}
            }
        }
    }
    
    class APIConfig {
        enum Service {
            case ebay
            case ebayClientID
            case ebayClientSecret
            // Add other services as needed
        }
        
        static func getAPIKey(for service: Service) throws -> String {
            let serviceKey: String
            switch service {
            case .ebay:
                serviceKey = "com.rasuto.api.ebay"
            case .ebayClientID:
                serviceKey = "com.rasuto.api.ebay.clientid"
            case .ebayClientSecret:
                serviceKey = "com.rasuto.api.ebay.clientsecret"
            }
            
            return try APIKeyManager.shared.getAPIKey(for: serviceKey)
        }
        
        static func createEbayService() throws -> EbayAPIService {
            let apiKey = try getAPIKey(for: .ebay)
            return EbayAPIService(apiKey: apiKey)
        }
    }
    
    // MARK: - View Components
    
    private var searchBarView: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search eBay products", text: $searchQuery)
                    .font(Theme.Typography.bodyFont)
                    .onSubmit {
                        if !searchQuery.isEmpty {
                            searchProducts()
                        }
                    }
                    .submitLabel(.search)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isSearchFieldFocused)
                    .padding(.vertical, 8) // Add some padding for better touch target
                    .keyboardType(.default) // Explicitly set keyboard type
                    .onTapGesture { // Add this to ensure focus when tapped
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
                
                Button(action: searchProducts) {
                    Text("Search")
                        .font(Theme.Typography.bodyFont)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(searchQuery.isEmpty ? Color.gray.opacity(0.3) : Theme.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.Layout.standardCornerRadius)
                }
                .disabled(searchQuery.isEmpty || isLoading)
            }
            .padding(12)
            .background(Theme.secondaryBackgroundColor)
            .cornerRadius(Theme.Layout.standardCornerRadius)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
    
    private var contentView: some View {
        ZStack {
            Theme.backgroundColor.ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if let detailProduct = detailProduct {
                productDetailView(product: detailProduct)
            } else {
                productGridView
            }
        }
        .background(Theme.backgroundColor)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView("Searching...")
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error")
                .font(Theme.Typography.titleFont)
                .foregroundColor(.red)
            
            Text(message)
                .font(Theme.Typography.bodyFont)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var productGridView: some View {
        Group {
            if products.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(products) { product in
                            EbayProductCard(product: product)
                                .onTapGesture {
                                    selectProduct(product.sourceId)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Search for products")
                .font(Theme.Typography.titleFont)
            
            Text("Enter keywords to find products on eBay")
                .font(Theme.Typography.bodyFont)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func productDetailView(product: ProductItemDTO) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Back button
                backToResultsButton
                
                // Product image
                productImageView(product: product)
                
                // Product details
                productDetailsSection(product: product)
                
                // Related products section
                if !relatedProducts.isEmpty {
                    relatedProductsSection
                }
            }
        }
    }
    
    private var backToResultsButton: some View {
        Button(action: {
            detailProduct = nil
            selectedProductId = nil
        }) {
            HStack {
                Image(systemName: "arrow.left")
                Text("Back to results")
                    .font(Theme.Typography.bodyFont)
            }
            .foregroundColor(Theme.primaryColor)
        }
        .padding(.horizontal)
    }
    
    private func showMockResultsIfEmpty() {
        if products.isEmpty && errorMessage == nil {
            // Show mock results as a fallback
            let mockService = MockEbayAPIService()
            Task {
                let mockResults = try await mockService.searchProducts(query: searchQuery)
                await MainActor.run {
                    products = mockResults
                    isShowingMockData = true
                }
            }
        }
    }
    
    private func productImageView(product: ProductItemDTO) -> some View {
        ZStack {
            AsyncImage(url: product.getImageURL()) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                } else if phase.error != nil {
                    Image(systemName: "photo")
                        .font(.system(size: 70))
                        .foregroundColor(.gray)
                        .frame(height: 250)
                } else {
                    ProgressView()
                        .frame(height: 250)
                }
            }
        }
    }
    
    private func productDetailsSection(product: ProductItemDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(product.name)
                .font(Theme.Typography.titleFont)
                .foregroundColor(Theme.textColor)
            
            // Price
            priceView(price: product.price, originalPrice: product.originalPrice)
            
            // Metadata
            metadataView(product: product)
            
            // Description
            if let description = product.productDescription, !description.isEmpty {
                descriptionView(description: description)
            }
            
            // Track button
            trackItemButton(product: product)
        }
        .padding()
    }
    
    private func priceView(price: Double?, originalPrice: Double?) -> some View {
        Group {
            if let price = price {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("$\(String(format: "%.2f", price))")
                        .font(Theme.Typography.titleFont)
                        .foregroundColor(Theme.primaryColor)
                    
                    if let originalPrice = originalPrice, originalPrice > price {
                        Text("$\(String(format: "%.2f", originalPrice))")
                            .font(Theme.Typography.bodyFont)
                            .foregroundColor(.gray)
                            .strikethrough()
                    }
                }
            }
        }
    }
    
    private func metadataView(product: ProductItemDTO) -> some View {
        HStack {
            Label {
                Text("Brand: \(product.brand)")
            } icon: {
                Image(systemName: "tag")
            }
            
            Spacer()
            
            if let category = product.category {
                Label {
                    Text(category)
                } icon: {
                    Image(systemName: "folder")
                }
            }
        }
        .font(Theme.Typography.captionFont)
        .foregroundColor(.gray)
    }
    
    private func descriptionView(description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(Theme.Typography.headlineFont)
                .foregroundColor(Theme.textColor)
                .padding(.top, 8)
            
            Text(description)
                .font(Theme.Typography.bodyFont)
                .foregroundColor(Theme.secondaryTextColor)
        }
    }
    
    private func trackItemButton(product: ProductItemDTO) -> some View {
        Button(action: {
            trackItem(product)
        }) {
            HStack {
                Image(systemName: "bell")
                Text("Track This Item")
            }
            .font(Theme.Typography.bodyFont)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(Theme.Layout.largeCornerRadius)
        }
        .padding(.vertical, 8)
    }
    
    private var relatedProductsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Products")
                .font(Theme.Typography.headlineFont)
                .padding(.top, 8)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(relatedProducts) { product in
                        relatedProductCard(product: product)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func relatedProductCard(product: ProductItemDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product image
            if let thumbnailUrl = product.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Theme.secondaryBackgroundColor)
                            .frame(width: 120, height: 120)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
            } else {
                Rectangle()
                    .fill(Theme.secondaryBackgroundColor)
                    .frame(width: 120, height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            // Product name and price
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(Theme.Typography.captionFont)
                    .lineLimit(2)
                    .frame(width: 120)
                
                if let price = product.price {
                    Text("$\(String(format: "%.2f", price))")
                        .font(Theme.Typography.captionFont)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.primaryColor)
                }
            }
        }
        .frame(width: 120)
        .onTapGesture {
            selectProduct(product.sourceId)
        }
    }
    
    private var detailsLoadingOverlay: some View {
        Group {
            if isLoadingDetails {
                ProgressView("Loading details...")
                    .padding()
                    .background(Theme.secondaryBackgroundColor)
                    .cornerRadius(Theme.Layout.standardCornerRadius)
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Debug Panel
        
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
                    
                    webhookSimulationSection
                    
                    Divider()
                    
                    testWorkflowSection
                }
                .padding()
                .background(Theme.secondaryBackgroundColor)
                .cornerRadius(Theme.Layout.largeCornerRadius)
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
            
            Button("Test eBay Auth") {
                Task {
                    await verifyAPICredentials()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Check API Keys") {
                Task {
                    await checkAPIKeys()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var webhookSimulationSection: some View {
        Group {
            Text("Simulate Webhook Events")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            Button("Simulate Price Drop") {
                Task {
                    await simulatePriceDropWebhook()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Simulate Auction Ending") {
                Task {
                    await simulateAuctionEndingWebhook()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Simulate Item Sold") {
                Task {
                    await simulateItemSoldWebhook()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Simulate Low Stock") {
                Task {
                    await simulateInventoryChangeWebhook()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var testWorkflowSection: some View {
        Group {
            Text("Test Full API Workflow")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            Button("Test Full eBay Workflow") {
                Task {
                    await testFullEbayWorkflow()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Test Concurrency") {
                Task {
                    await demonstrateConcurrency()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // Add these helper functions

    private func verifyAPICredentials() async {
        print("🔍 Checking eBay credentials...")
        
        do {
            // Test OAuth directly
            let oauth = OAuthHandler()
            do {
                let token = try await oauth.authorize(for: "ebay")
                print("✅ Got token: \(token.prefix(10))...")
            } catch {
                print("❌ Auth failed: \(error)")
                
                if let oauthError = error as? OAuthError {
                    switch oauthError {
                    case .tokenExchangeFailed:
                        print("❌ Token exchange failed - Check credentials")
                    case .invalidCredentials:
                        print("❌ Invalid credentials")
                    case .missingConfiguration:
                        print("❌ Missing configuration")
                    default:
                        print("❌ Other error: \(oauthError)")
                    }
                }
            }
        } catch {
            print("❌ Verification failed: \(error)")
        }
    }

    private func checkAPIKeys() async {
        print("🔍 Checking API keys...")
        
        do {
            // Use the local APIConfig class's getAPIKey method instead of directly accessing APIKeyManager
            let clientID = try APIConfig.getAPIKey(for: .ebayClientID)
            let clientSecret = try APIConfig.getAPIKey(for: .ebayClientSecret)
            let apiKey = try APIConfig.getAPIKey(for: .ebay)
            
            print("✅ Found keys:")
            print("   ID: \(clientID.prefix(4))...")
            print("   Secret: \(clientSecret.prefix(4))...")
            print("   API Key: \(apiKey.prefix(4))...")
        } catch {
            print("❌ Failed to get API keys: \(error)")
        }
    }
    
    // MARK: - Business Logic Methods
    
    private func searchProducts() {
        isLoading = true
        errorMessage = nil
        products = []
        
        Task {
            do {
                let ebayService = try APIConfig.createEbayService()
                
                // Use the correct method based on whether we have a category
                let results: [ProductItemDTO]
                
                if let selectedCategory = selectedCategory, !selectedCategory.isEmpty {
                    // Use the extended method that supports categories
                    results = try await (ebayService as? EbayAPIService)?.searchProductsWithCategory(
                        query: searchQuery,
                        categoryId: selectedCategory
                    ) ?? []
                } else {
                    // Use the standard protocol method
                    results = try await ebayService.searchProducts(query: searchQuery)
                }
                
                await MainActor.run {
                    products = results
                    isLoading = false
                }
                if products.isEmpty {
                    showMockResultsIfEmpty()
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
    
    private func trackItem(_ product: ProductItemDTO) {
        Task {
            do {
                let ebayService = try APIConfig.createEbayService()
                
                // Track item with both eBay service and notification manager
                if let manager = notificationManager as? EbayNotificationManager {
                    let success = try await manager.trackItem(
                        id: product.sourceId,
                        name: product.name,
                        currentPrice: product.price,
                        thumbnailUrl: product.thumbnailUrl
                    )
                    
                    await MainActor.run {
                        if success {
                            // Show success message or update UI
                            print("Successfully tracked product: \(product.name)")
                        }
                    }
                } else {
                    // Fallback to just eBay service if notification manager is not available
                    let success = try await ebayService.trackItem(id: product.sourceId)
                    await MainActor.run {
                        if success {
                            print("Successfully tracked product: \(product.name)")
                        }
                    }
                }
            } catch {
                print("Error tracking product: \(error)")
            }
        }
    }
    
    
    // MARK: - Debug Methods
    
    func simulatePriceDropWebhook() async {
        let samplePayload = """
        {
            "notification": {
                "notificationId": "test-notification-id",
                "eventDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "publishDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "subscriptionId": "test-subscription",
                "topic": "ITEM_PRICE_CHANGE",
                "data": {
                    "itemId": "v1|123456789|0",
                    "price": {
                        "value": "199.99",
                        "currency": "USD"
                    },
                    "previousPrice": {
                        "value": "249.99",
                        "currency": "USD"
                    },
                    "title": "Test Product with Price Change"
                }
            }
        }
        """
        
        await processSimulatedWebhook(payload: samplePayload, type: "ITEM_PRICE_CHANGE")
    }
    
    func simulateAuctionEndingWebhook() async {
        let futureTime = ISO8601DateFormatter().string(from: Date().addingTimeInterval(1800)) // 30 minutes in future
        
        let samplePayload = """
        {
            "notification": {
                "notificationId": "test-notification-id",
                "eventDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "publishDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "subscriptionId": "test-subscription",
                "topic": "AUCTION_ENDING",
                "data": {
                    "itemId": "v1|987654321|0",
                    "endTime": "\(futureTime)",
                    "currentBid": {
                        "value": "350.00",
                        "currency": "USD"
                    },
                    "title": "Test Auction Ending Soon"
                }
            }
        }
        """
        
        await processSimulatedWebhook(payload: samplePayload, type: "AUCTION_ENDING")
    }
    
    func simulateItemSoldWebhook() async {
        let samplePayload = """
        {
            "notification": {
                "notificationId": "test-notification-id",
                "eventDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "publishDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "subscriptionId": "test-subscription",
                "topic": "ITEM_SOLD",
                "data": {
                    "itemId": "v1|555555555|0",
                    "title": "Test Product Sold Out"
                }
            }
        }
        """
        
        await processSimulatedWebhook(payload: samplePayload, type: "ITEM_SOLD")
    }
    
    func simulateInventoryChangeWebhook() async {
        let samplePayload = """
        {
            "notification": {
                "notificationId": "test-notification-id",
                "eventDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "publishDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "subscriptionId": "test-subscription",
                "topic": "INVENTORY_CHANGE",
                "data": {
                    "itemId": "v1|777777777|0",
                    "quantity": 2,
                    "title": "Test Product Low Stock"
                }
            }
        }
        """
        
        await processSimulatedWebhook(payload: samplePayload, type: "INVENTORY_CHANGE")
    }
    
    func processSimulatedWebhook(payload: String, type: String) async {
        guard let data = payload.data(using: .utf8) else {
            print("Failed to create payload data")
            return
        }
        
        let headers = [
            "X-EBAY-SIGNATURE": "test-signature",
            "X-EBAY-EVENT-TYPE": type
        ]
        
        do {
            try await notificationManager.processWebhook(data: data, headers: headers)
            print("Simulated webhook processed successfully: \(type)")
        } catch {
            print("Failed to process simulated webhook: \(error)")
        }
    }
    
    // MARK: - Test Workflow Methods
    
    func testFullEbayWorkflow() async {
        print("Testing full eBay workflow...")
        
        do {
            // 1. Search for products
            let ebayService = try APIConfig.createEbayService()
            let searchResults = try await ebayService.searchProducts(query: "vintage camera")
            
            print("1. Search results: \(searchResults.count) products found")
            
            guard let firstProduct = searchResults.first else {
                print("No products found")
                return
            }
            
            // 2. Get product details
            let productDetails = try await ebayService.getProductDetails(id: firstProduct.sourceId)
            print("2. Product details retrieved: \(productDetails.name)")
            
            // 3. Track the item for price changes
            let trackingSuccess = try await ebayService.trackItem(id: firstProduct.sourceId)
            print("3. Tracking successful: \(trackingSuccess)")
            
            // 4. Get related products
            let relatedProducts = try await ebayService.getRelatedProducts(id: firstProduct.sourceId)
            print("4. Found \(relatedProducts.count) related products")
            
            // 5. Get updates for tracked items
            let updates = try await ebayService.getItemUpdates()
            print("5. Found \(updates.count) updates for tracked items")
            
            // 6. Simulate a webhook notification
            await simulatePriceDropWebhook()
            print("6. Simulated webhook notification")
            
            print("Full eBay workflow test completed successfully")
        } catch {
            print("Error in workflow test: \(error)")
        }
    }
    
    func demonstrateConcurrency() async {
        print("Demonstrating concurrency with parallel API requests...")
        
        let startTime = Date()
        
        do {
            let ebayService = try APIConfig.createEbayService()
            
            // Perform multiple API operations concurrently
            async let searchTask = ebayService.searchProducts(query: "digital camera")
            async let feedTypesTask = ebayService.getAvailableFeedTypes()
            async let itemUpdatesTask = ebayService.getItemUpdates()
            
            // Await all results
            let (searchResults, feedTypes, updates) = await (
                try searchTask,
                try feedTypesTask,
                try itemUpdatesTask
            )
            
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime)
            
            print("Concurrent operations completed in \(elapsedTime) seconds")
            print("- Search results: \(searchResults.count) items")
            print("- Feed types available: \(feedTypes)")
            print("- Item updates: \(updates.count) updates")
            
            // Compare with sequential execution
            await demonstrateSequentialExecution()
        } catch {
            print("Error in concurrent operations: \(error)")
        }
    }
    
    func demonstrateSequentialExecution() async {
        print("\nNow demonstrating sequential execution for comparison...")
        
        let startTime = Date()
        
        do {
            let ebayService = try APIConfig.createEbayService()
            
            // Execute the same operations sequentially
            let searchResults = try await ebayService.searchProducts(query: "digital camera")
            print("1. Search complete")
            
            let feedTypes = try await ebayService.getAvailableFeedTypes()
            print("2. Feed types retrieved")
            
            let updates = try await ebayService.getItemUpdates()
            print("3. Updates retrieved")
            
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime)
            
            print("Sequential operations completed in \(elapsedTime) seconds")
            print("- Search results: \(searchResults.count) items")
            print("- Feed types retrieved")
            print("- Item updates: \(updates.count) updates")
            
            print("\nComparison demonstrates the benefit of Swift concurrency!")
        } catch {
            print("Error in sequential operations: \(error)")
        }
    }
    
    // Product Card View
    struct EbayProductCard: View {
        let product: ProductItemDTO
        
        var body: some View {
            VStack(alignment: .leading) {
                ZStack {
                    AsyncImage(url: product.getThumbnailURL()) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                        } else if phase.error != nil {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        } else {
                            ProgressView()
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(12)
                .clipped()
                
                // Product details
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let price = product.price {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("$\(String(format: "%.2f", price))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            if let originalPrice = product.originalPrice, originalPrice > price {
                                Text("$\(String(format: "%.2f", originalPrice))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .strikethrough()
                            }
                        }
                    }
                    
                    Text(product.brand)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
        }
    }
    
    // Mock eBay Service for Preview
    class MockEbayAPIService: EbayAPIService {
        init() {
            super.init(apiKey: "mock_key")
        }
        
        override func searchProducts(query: String) async throws -> [ProductItemDTO] {
            // Return mock products for preview
            return [
                ProductItemDTO(
                    sourceId: "v1|12345|0",
                    name: "Vintage Leica M6 Rangefinder Film Camera",
                    productDescription: "Excellent condition, mechanical rangefinder with electronic shutter control.",
                    price: 2999.99,
                    originalPrice: 3299.99,
                    currency: "USD",
                    imageURL: URL(string: "https://i.ebayimg.com/images/g/p-IAAOSwLI1kL28M/s-l1600.jpg"),
                    imageUrls: ["https://i.ebayimg.com/images/g/p-IAAOSwLI1kL28M/s-l1600.jpg"],
                    thumbnailUrl: "https://i.ebayimg.com/images/g/p-IAAOSwLI1kL28M/s-l1600.jpg",
                    brand: "Leica",
                    source: "eBay",
                    category: "Film Cameras",
                    isInStock: true,
                    rating: 4.9,
                    reviewCount: 45
                ),
                ProductItemDTO(
                    sourceId: "v1|67890|0",
                    name: "Sony Alpha a7 III Mirrorless Digital Camera (Body Only)",
                    productDescription: "24.2MP full-frame Exmor R BSI CMOS sensor, 4K video recording.",
                    price: 1799.99,
                    originalPrice: 1999.99,
                    currency: "USD",
                    imageURL: URL(string: "https://i.ebayimg.com/images/g/HnEAAOSwdGVkxhcP/s-l1600.jpg"),
                    imageUrls: ["https://i.ebayimg.com/images/g/HnEAAOSwdGVkxhcP/s-l1600.jpg"],
                    thumbnailUrl: "https://i.ebayimg.com/images/g/HnEAAOSwdGVkxhcP/s-l1600.jpg",
                    brand: "Sony",
                    source: "eBay",
                    category: "Digital Cameras",
                    isInStock: true,
                    rating: 4.8,
                    reviewCount: 290
                ),
                ProductItemDTO(
                    sourceId: "v1|24680|0",
                    name: "Canon EOS R5 Mirrorless Digital Camera",
                    productDescription: "45MP full-frame CMOS sensor, 8K video recording capability.",
                    price: 3599.99,
                    originalPrice: 3899.99,
                    currency: "USD",
                    imageURL: URL(string: "https://i.ebayimg.com/images/g/7SEAAOSwwz1kxk6h/s-l1600.jpg"),
                    imageUrls: ["https://i.ebayimg.com/images/g/7SEAAOSwwz1kxk6h/s-l1600.jpg"],
                    thumbnailUrl: "https://i.ebayimg.com/images/g/7SEAAOSwwz1kxk6h/s-l1600.jpg",
                    brand: "Canon",
                    source: "eBay",
                    category: "Digital Cameras",
                    isInStock: true,
                    rating: 4.7,
                    reviewCount: 210
                ),
                ProductItemDTO(
                    sourceId: "v1|13579|0",
                    name: "Nikon Z7 II Mirrorless Digital Camera",
                    productDescription: "45.7MP BSI CMOS sensor, 4K UHD video at 60p.",
                    price: 2996.95,
                    originalPrice: 3299.95,
                    currency: "USD",
                    imageURL: URL(string: "https://i.ebayimg.com/images/g/10gAAOSwBfVkxlAn/s-l1600.jpg"),
                    imageUrls: ["https://i.ebayimg.com/images/g/10gAAOSwBfVkxlAn/s-l1600.jpg"],
                    thumbnailUrl: "https://i.ebayimg.com/images/g/10gAAOSwBfVkxlAn/s-l1600.jpg",
                    brand: "Nikon",
                    source: "eBay",
                    category: "Digital Cameras",
                    isInStock: true,
                    rating: 4.8,
                    reviewCount: 175
                )
            ]
        }
        
        override func getProductDetails(id: String) async throws -> ProductItemDTO {
            // Return a mock product detail
            return ProductItemDTO(
                sourceId: id,
                name: "Vintage Leica M6 Rangefinder Film Camera",
                productDescription: "Excellent condition mechanical rangefinder with electronic shutter control. The Leica M6 is a 35 mm rangefinder camera manufactured by Leica from 1984 to 2002. The M6 combines the silhouette of the Leica M3 and Leica M4 with a modern, off-the-shutter light meter with no moving parts and LED arrows in the viewfinder. Informally it is referred to as the M6 \"Classic\" to distinguish it from the later M6 TTL model.",
                price: 2999.99,
                originalPrice: 3299.99,
                currency: "USD",
                imageURL: URL(string: "https://i.ebayimg.com/images/g/p-IAAOSwLI1kL28M/s-l1600.jpg"),
                imageUrls: [
                    "https://i.ebayimg.com/images/g/p-IAAOSwLI1kL28M/s-l1600.jpg",
                    "https://i.ebayimg.com/images/g/e10AAOSwE8BkL28Q/s-l1600.jpg",
                    "https://i.ebayimg.com/images/g/RKAAAOSwzSdkL28T/s-l1600.jpg"
                ],
                thumbnailUrl: "https://i.ebayimg.com/images/g/p-IAAOSwLI1kL28M/s-l1600.jpg",
                brand: "Leica",
                source: "eBay",
                category: "Film Cameras",
                isInStock: true,
                rating: 4.9,
                reviewCount: 45
            )
        }
        
        override func getRelatedProducts(id: String) async throws -> [ProductItemDTO] {
            // Return mock related products
            return [
                ProductItemDTO(
                    sourceId: "v1|13579|0",
                    name: "Leica M3 Vintage Rangefinder Camera",
                    productDescription: "Classic mechanical rangefinder camera.",
                    price: 1899.99,
                    currency: "USD",
                    imageURL: URL(string: "https://i.ebayimg.com/images/g/fQwAAOSwU8Nkwm5a/s-l1600.jpg"),
                    imageUrls: ["https://i.ebayimg.com/images/g/fQwAAOSwU8Nkwm5a/s-l1600.jpg"],
                    thumbnailUrl: "https://i.ebayimg.com/images/g/fQwAAOSwU8Nkwm5a/s-l1600.jpg",
                    brand: "Leica",
                    source: "eBay",
                    category: "Film Cameras",
                    isInStock: true,
                    rating: 4.7,
                    reviewCount: 32
                ),
                ProductItemDTO(
                    sourceId: "v1|24680|0",
                    name: "Leica MP 0.72 35mm Rangefinder Camera",
                    productDescription: "Premium mechanical rangefinder camera.",
                    price: 4499.99,
                    currency: "USD",
                    imageURL: URL(string: "https://i.ebayimg.com/images/g/UjIAAOSw~cZkwm6L/s-l1600.jpg"),
                    imageUrls: ["https://i.ebayimg.com/images/g/UjIAAOSw~cZkwm6L/s-l1600.jpg"],
                    thumbnailUrl: "https://i.ebayimg.com/images/g/UjIAAOSw~cZkwm6L/s-l1600.jpg",
                    brand: "Leica",
                    source: "eBay",
                    category: "Film Cameras",
                    isInStock: true,
                    rating: 5.0,
                    reviewCount: 18
                ),
                ProductItemDTO(
                    sourceId: "v1|11223|0",
                    name: "Leica Summicron-M 50mm f/2 Lens",
                    productDescription: "Premium manual focus lens for Leica M cameras.",
                    price: 2399.99,
                    currency: "USD",
                    imageURL: URL(string: "https://i.ebayimg.com/images/g/7qgAAOSwKD5kwm7N/s-l1600.jpg"),
                    imageUrls: ["https://i.ebayimg.com/images/g/7qgAAOSwKD5kwm7N/s-l1600.jpg"],
                    thumbnailUrl: "https://i.ebayimg.com/images/g/7qgAAOSwKD5kwm7N/s-l1600.jpg",
                    brand: "Leica",
                    source: "eBay",
                    category: "Camera Lenses",
                    isInStock: true,
                    rating: 4.9,
                    reviewCount: 27
                )
            ]
        }
    }
}

//MARK: - Extensions

extension EbayNotificationManager {
    static var previewMock: EbayNotificationManager {
        // Create a minimal instance just for UI preview purposes
        let service = EbayAPIService(apiKey: "preview_key")
        return EbayNotificationManager(ebayService: service)
    }
}
    
extension ProductItemDTO {
    // Define a method for accessing image URL safely
    func getImageURL() -> URL? {
        if let imageURL = imageURL {
            return imageURL
        } else if let firstImageUrl = imageUrls?.first, let url = URL(string: firstImageUrl) {
            return url
        } else if let thumbnailUrl = thumbnailUrl, let url = URL(string: thumbnailUrl) {
            return url
        }
        return nil
    }
    
    // Define a method for accessing thumbnail URL safely
    func getThumbnailURL() -> URL? {
        if let thumbnailUrl = thumbnailUrl, let url = URL(string: thumbnailUrl) {
            return url
        } else if let firstImageUrl = imageUrls?.first, let url = URL(string: firstImageUrl) {
            return url
        } else if let imageURL = imageURL {
            return imageURL
        }
        return nil
    }
}
    
    //MARK: - Preview
    
    #Preview {
        NavigationView {
            EbayAPITestView()
                .environmentObject(EbayNotificationManager.previewMock)
        }
    }
