//
//  ProductTrackingService.swift
//  Rasuto
//
//  Created by Claude on 6/4/25.
//

import SwiftUI
import Combine
import SwiftData

/// Universal tracking service that coordinates tracking across all APIs
/// and connects ProductDetailView actions to TrackingView notifications
class ProductTrackingService: ObservableObject {
    static let shared = ProductTrackingService()
    
    @Published var trackedProducts: [UUID: ProductItem] = [:]
    
    // private var bestBuyTracker: BestBuyPriceTracker? // Removed for production
    // eBay integration provided via SerpAPI
    private var serpAPITracker: SerpAPITracker?
    private var axessoTracker: AxessoTracker?
    
    // Reference to unified notification manager for adding notifications
    weak var notificationManager: UnifiedNotificationManager?
    
    // SwiftData context for persistence
    private var modelContext: ModelContext?
    
    private init() {
        setupServices()
    }
    
    /// Set SwiftData context for persistence
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadPersistedTrackedItems()
    }
    
    private func setupServices() {
        Task { @MainActor in
            do {
                let apiConfig = APIConfig()
                
                // BestBuy service removed for production
                
                // Initialize eBay service
                // self.ebayManager = EbayNotificationManager() // Commented out - EbayNotificationManager disabled
                
                // Initialize SerpAPI tracker (to be created)
                self.serpAPITracker = SerpAPITracker()
                
                // Initialize Axesso tracker (to be created)
                self.axessoTracker = AxessoTracker()
                
            } catch {
                print("Failed to initialize tracking services: \(error)")
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Start tracking a product from ProductDetailView
    func startTracking(_ product: ProductItem) {
        // Store tracked product
        trackedProducts[product.id] = product
        
        // Persist to SwiftData
        persistTrackedProduct(product)
        
        // Route to appropriate service based on source
        switch product.source.lowercased() {
        case "bestbuy":
            // BestBuy tracking removed for production
            break
        case "ebay":
            startEbayTracking(product)
        case "amazon":
            startAxessoTracking(product)
        default:
            // Use SerpAPI for general products
            startSerpAPITracking(product)
        }
        
        // Add tracking notification to TrackingView
        notificationManager?.addTrackedItem(product)
    }
    
    /// Stop tracking a product
    func stopTracking(_ product: ProductItem) {
        trackedProducts.removeValue(forKey: product.id)
        
        // Remove from SwiftData
        removePersistedTrackedProduct(product.id.uuidString)
        
        switch product.source.lowercased() {
        case "bestbuy":
            Task { @MainActor in
                // bestBuyTracker?.stopTracking(for: product.idString) // Removed for production
            }
        case "ebay":
            Task {
                // try? await ebayManager?.untrackItem(id: product.idString) // Commented out - EbayNotificationManager disabled
            }
        case "amazon":
            axessoTracker?.stopTracking(product)
        default:
            serpAPITracker?.stopTracking(product)
        }
    }
    
    /// Check if a product is being tracked
    func isTracking(_ product: ProductItem) -> Bool {
        return trackedProducts[product.id] != nil
    }
    
    /// Get all tracked products
    func getAllTrackedProducts() -> [ProductItem] {
        return Array(trackedProducts.values)
    }
    
    /// Manual refresh for demo purposes
    func refreshAllTrackedItems() async {
        print("🔄 Manual refresh initiated for all tracked items...")
        
        // Check SerpAPI products immediately
        await serpAPITracker?.checkNow()
        
        // BestBuy tracking removed for production
        
        print("✅ Manual refresh completed")
    }
    
    /// Demo feature: Simulate price drop for any tracked product
    func simulatePriceDropForDemo() {
        guard let randomProduct = trackedProducts.values.randomElement() else {
            print("No tracked products available for demo simulation")
            return
        }
        
        print("🎬 Simulating price drop for demo...")
        
        // Use SerpAPI tracker for simulation since it has the demo method
        serpAPITracker?.simulatePriceDrop(for: randomProduct.id.uuidString)
    }
    
    // MARK: - Service-Specific Tracking
    
    /*
    private func startBestBuyTracking(_ product: ProductItem) {
        let productInfo = BestBuyProductInfo(
            sku: product.idString,
            name: product.name,
            regularPrice: product.originalPrice ?? product.currentPrice,
            salePrice: product.price ?? product.currentPrice,
            onSale: product.isOnSale,
            image: product.imageUrl,
            url: product.productUrl ?? "",
            description: product.description ?? ""
        )
        Task {
            await MainActor.run {
                bestBuyTracker?.startTracking(sku: product.idString, productInfo: productInfo)
            }
        }
    }
    */ // BestBuy tracking removed for production
    
    private func startEbayTracking(_ product: ProductItem) {
        Task {
            do {
                // _ = try await ebayManager?.trackItem(
                //     id: product.idString,
                //     name: product.name,
                //     currentPrice: product.currentPrice,
                //     thumbnailUrl: product.imageUrl
                // ) // Commented out - EbayNotificationManager disabled
            } catch {
                print("Failed to track eBay item: \(error)")
            }
        }
    }
    
    private func startSerpAPITracking(_ product: ProductItem) {
        serpAPITracker?.startTracking(product)
    }
    
    private func startAxessoTracking(_ product: ProductItem) {
        axessoTracker?.startTracking(product)
    }
    
    // MARK: - Price Drop Detection
    
    /// Called when a price drop is detected by any service
    func handlePriceDropDetected(for productId: String, oldPrice: Double, newPrice: Double) {
        // Find product by UUID string
        guard let productUUID = UUID(uuidString: productId),
              let product = trackedProducts[productUUID] else { return }
        
        // Update stored product price
        product.price = newPrice
        
        // Add notification to TrackingView
        notificationManager?.addPriceDropNotification(for: product, oldPrice: oldPrice, newPrice: newPrice)
    }
    
    /// Called when an item comes back in stock
    func handleBackInStock(for productId: String) {
        // Find product by UUID string
        guard let productUUID = UUID(uuidString: productId),
              let product = trackedProducts[productUUID] else { return }
        
        // Update stock status
        product.isInStock = true
        
        // Add notification to TrackingView
        notificationManager?.addBackInStockNotification(for: product)
    }
    
    // MARK: - Integration with UnifiedNotificationManager
    
    func setNotificationManager(_ manager: UnifiedNotificationManager) {
        self.notificationManager = manager
    }
    
    // MARK: - SwiftData Persistence
    
    private func persistTrackedProduct(_ product: ProductItem) {
        guard let context = modelContext else {
            print("⚠️ ModelContext not available - tracked product not persisted")
            return
        }
        
        // Check if already persisted
        let productIdString = product.id.uuidString
        let descriptor = FetchDescriptor<TrackedProductModel>(
            predicate: #Predicate { $0.productId == productIdString }
        )
        
        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let trackedProduct = TrackedProductModel.from(product)
                context.insert(trackedProduct)
                try context.save()
                print("✅ Persisted tracked product: \(product.name)")
            }
        } catch {
            print("❌ Failed to persist tracked product: \(error)")
        }
    }
    
    private func removePersistedTrackedProduct(_ productId: String) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<TrackedProductModel>(
            predicate: #Predicate { $0.productId == productId }
        )
        
        do {
            let products = try context.fetch(descriptor)
            for product in products {
                context.delete(product)
            }
            try context.save()
            print("✅ Removed persisted tracked product: \(productId)")
        } catch {
            print("❌ Failed to remove persisted tracked product: \(error)")
        }
    }
    
    private func loadPersistedTrackedItems() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<TrackedProductModel>(
            predicate: #Predicate { $0.isActive == true }
        )
        
        do {
            let persistedProducts = try context.fetch(descriptor)
            
            for persistedProduct in persistedProducts {
                let product = persistedProduct.toProductItem()
                trackedProducts[product.id] = product
                
                // Restart tracking for this product
                switch product.source.lowercased() {
                case "bestbuy":
                    // BestBuy tracking removed for production
                    break
                case "ebay":
                    startEbayTracking(product)
                case "amazon":
                    startAxessoTracking(product)
                default:
                    startSerpAPITracking(product)
                }
            }
            
            print("✅ Loaded \(persistedProducts.count) persisted tracked products")
        } catch {
            print("❌ Failed to load persisted tracked products: \(error)")
        }
    }
}

// MARK: - SerpAPI Tracker (Placeholder)

class SerpAPITracker {
    private var trackedProducts: [String: ProductItem] = [:]
    private var timer: Timer?
    private let checkInterval: TimeInterval = 14400 // 4 hours = API-efficient
    
    func startTracking(_ product: ProductItem) {
        trackedProducts[product.id.uuidString] = product
        
        // Only start timer if we have products to track
        startPeriodicChecking()
        
        print("Started SerpAPI tracking for: \(product.name) (checks every 4 hours)")
    }
    
    func stopTracking(_ product: ProductItem) {
        trackedProducts.removeValue(forKey: product.id.uuidString)
        
        // Stop timer if no products left to track
        if trackedProducts.isEmpty {
            timer?.invalidate()
            timer = nil
            print("Stopped all SerpAPI tracking - timer disabled")
        }
        
        print("Stopped SerpAPI tracking for: \(product.name)")
    }
    
    func checkNow() async {
        // Manual refresh for demo purposes
        print("Manual SerpAPI price check initiated...")
        await checkPricesForAllProducts()
    }
    
    private func startPeriodicChecking() {
        guard timer == nil else { return }
        
        // 4-hour intervals to be API cost-efficient
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            Task {
                await self.checkPricesForAllProducts()
            }
        }
        print("SerpAPI periodic checking started (every 4 hours)")
    }
    
    private func checkPricesForAllProducts() async {
        guard !trackedProducts.isEmpty else { return }
        
        print("Checking prices for \(trackedProducts.count) SerpAPI tracked products...")
        
        for product in trackedProducts.values {
            await checkPriceForProduct(product)
            
            // Small delay between requests to be API-friendly
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        }
    }
    
    private func checkPriceForProduct(_ product: ProductItem) async {
        // TODO: Implement actual SerpAPI price checking
        // This would make a new SerpAPI request for the specific product
        
        // For demo: Simulate occasional price drops (10% chance)
        if Bool.random() && Double.random(in: 0...1) < 0.1 {
            let oldPrice = product.price ?? 0.0
            let newPrice = oldPrice * Double.random(in: 0.85...0.95) // 5-15% drop
            
            print("🎯 DEMO: Price drop detected for \(product.name): $\(oldPrice) → $\(newPrice)")
            
            ProductTrackingService.shared.handlePriceDropDetected(
                for: product.id.uuidString,
                oldPrice: oldPrice,
                newPrice: newPrice
            )
        }
    }
    
    // Demo feature: Force a price drop for testing
    func simulatePriceDrop(for productId: String) {
        // Find product by string ID
        guard let product = trackedProducts[productId] else { return }
        
        let oldPrice = product.price ?? 0.0
        let newPrice = oldPrice * 0.85 // 15% drop for demo
        
        print("🎬 DEMO SIMULATION: Price drop for \(product.name): $\(oldPrice) → $\(newPrice)")
        
        ProductTrackingService.shared.handlePriceDropDetected(
            for: productId,
            oldPrice: oldPrice,
            newPrice: newPrice
        )
    }
}

// MARK: - Axesso Tracker (Placeholder)

class AxessoTracker {
    private var trackedProducts: [String: ProductItem] = [:]
    
    func startTracking(_ product: ProductItem) {
        trackedProducts[product.id.uuidString] = product
        print("Started Axesso tracking for: \(product.name)")
        
        // TODO: Implement Axesso price monitoring
        // This would use the existing AxessoAmazonAPIService
    }
    
    func stopTracking(_ product: ProductItem) {
        trackedProducts.removeValue(forKey: product.id.uuidString)
        print("Stopped Axesso tracking for: \(product.name)")
    }
}