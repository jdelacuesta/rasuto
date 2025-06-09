//
//  TrackingView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI
import Combine

struct TrackingView: View {
    @StateObject private var notificationManager = UnifiedNotificationManager()
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingClearConfirmation = false
    @State private var refreshing = false
    @State private var lastRefreshTime = Date()
    
    enum NotificationFilter: String, CaseIterable {
        case all = "All"
        case priceDrops = "Price Drops"
        case backInStock = "Back in Stock"
        case tracking = "Tracking Updates"
        
        var icon: String {
            switch self {
            case .all: return "bell.fill"
            case .priceDrops: return "arrow.down.circle.fill"
            case .backInStock: return "checkmark.circle.fill"
            case .tracking: return "bell.badge.fill"
            }
        }
    }
    
    var filteredNotifications: [NotificationItem] {
        switch selectedFilter {
        case .all:
            return notificationManager.notifications
        case .priceDrops:
            return notificationManager.notifications.filter { $0.type == NotificationTypeUI.priceDrop }
        case .backInStock:
            return notificationManager.notifications.filter { $0.type == NotificationTypeUI.backInStock }
        case .tracking:
            return notificationManager.notifications.filter { $0.type == NotificationTypeUI.trackingUpdate }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Custom header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            if !notificationManager.notifications.isEmpty {
                                Text("\(notificationManager.unreadCount) new")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Last updated \(lastRefreshTime.relativeTime)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !notificationManager.notifications.isEmpty {
                            Menu {
                                Button(action: { notificationManager.markAllAsRead() }) {
                                    Label("Mark All as Read", systemImage: "checkmark.circle")
                                }
                                
                                Button(role: .destructive, action: { showingClearConfirmation = true }) {
                                    Label("Clear All", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding()
                    
                    // Filter tabs
                    if !notificationManager.notifications.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                                    FilterChip(
                                        title: filter.rawValue,
                                        icon: filter.icon,
                                        isSelected: selectedFilter == filter,
                                        count: countForFilter(filter)
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedFilter = filter
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Notifications list
                    if notificationManager.isLoading && notificationManager.notifications.isEmpty {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Spacer()
                    } else if filteredNotifications.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: selectedFilter == .all ? "bell.slash" : selectedFilter.icon,
                            title: selectedFilter == .all ? "No Notifications" : "No \(selectedFilter.rawValue)",
                            subtitle: selectedFilter == .all ? 
                                "Track items to receive price alerts" : 
                                "No \(selectedFilter.rawValue.lowercased()) at this time"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredNotifications) { notification in
                                    NotificationCard(
                                        notification: notification,
                                        onDismiss: {
                                            withAnimation {
                                                notificationManager.dismiss(notification)
                                            }
                                        }
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                            }
                            .padding()
                        }
                        .refreshable {
                            await refreshNotifications()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Clear All Notifications", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    withAnimation {
                        notificationManager.clearAll()
                    }
                }
            } message: {
                Text("This will remove all notifications. This action cannot be undone.")
            }
            .onAppear {
                notificationManager.startListening()
            }
            .onDisappear {
                notificationManager.stopListening()
            }
        }
    }
    
    private func countForFilter(_ filter: NotificationFilter) -> Int {
        switch filter {
        case .all:
            return notificationManager.notifications.count
        case .priceDrops:
            return notificationManager.notifications.filter { $0.type == NotificationTypeUI.priceDrop }.count
        case .backInStock:
            return notificationManager.notifications.filter { $0.type == NotificationTypeUI.backInStock }.count
        case .tracking:
            return notificationManager.notifications.filter { $0.type == NotificationTypeUI.trackingUpdate }.count
        }
    }
    
    private func refreshNotifications() async {
        refreshing = true
        await notificationManager.refresh()
        
        // Also refresh tracked items via ProductTrackingService
        await ProductTrackingService.shared.refreshAllTrackedItems()
        
        lastRefreshTime = Date()
        refreshing = false
    }
}

// Filter Chip Component
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : Color.primary)
                        .foregroundColor(isSelected ? .primary : .white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// Notification Card Component
struct NotificationCard: View {
    let notification: NotificationItem
    let onDismiss: () -> Void
    @State private var isExpanded = false
    @State private var offset: CGFloat = 0
    
    // Destination view for navigation
    @ViewBuilder
    private var destinationView: some View {
        if let productId = notification.productId {
            // Try to get the real product from tracking service
            let trackedProducts = ProductTrackingService.shared.getAllTrackedProducts()
            if let product = trackedProducts.first(where: { $0.id.uuidString == productId }) {
                ProductDetailView(product: product)
            } else {
                // Fallback: Create a minimal ProductItem from notification data
                let fallbackProduct = ProductItem(
                    name: notification.productName ?? "Product",
                    productDescription: notification.message,
                    price: notification.newPrice,
                    source: notification.source,
                    imageURL: URL(string: notification.productImageUrl ?? "")
                )
                ProductDetailView(product: fallbackProduct)
            }
        } else {
            EmptyView()
        }
    }
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 12) {
                // Product Image with Price Overlay
                ZStack {
                    if let imageUrl = notification.productImageUrl, !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                Image(systemName: notification.type.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(notification.type.color)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // Fallback to icon
                        RoundedRectangle(cornerRadius: 8)
                            .fill(notification.type.color.opacity(0.15))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: notification.type.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(notification.type.color)
                            }
                    }
                    
                    // Price Drop Overlay for price drop notifications
                    if notification.type == .priceDrop, let oldPrice = notification.oldPrice, let newPrice = notification.newPrice {
                        VStack(spacing: 2) {
                            Spacer()
                            HStack(spacing: 4) {
                                // Old price with strikethrough
                                Text("$\(String(format: "%.0f", oldPrice))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .strikethrough()
                                
                                // New price
                                Text("$\(String(format: "%.0f", newPrice))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.9))
                            .cornerRadius(4)
                        }
                        .padding(4)
                    }
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notification.title)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(isExpanded ? nil : 1)
                        
                        if let productName = notification.productName {
                            Text(productName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(isExpanded ? nil : 1)
                        }
                    }
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
                
                HStack {
                    Text(RetailerType.displayName(for: notification.source))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(notification.timestamp.relativeTime)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(notification.isRead ? Color(.systemGray6) : Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .offset(x: offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        offset = value.translation.width
                    }
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        if value.translation.width < -100 {
                            offset = -UIScreen.main.bounds.width
                            onDismiss()
                        } else {
                            offset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            if !notification.isRead {
                notification.isRead = true
            }
        }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
}

// Notification Models are now in Models/NotificationModels.swift

// Unified Notification Manager
class UnifiedNotificationManager: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var isLoading = false
    
    // private var bestBuyTracker: BestBuyPriceTracker? // REMOVED
    // private var ebayManager: EbayNotificationManager? // Commented out - EbayNotificationManager disabled
    private var cancellables = Set<AnyCancellable>()
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    init() {
        setupServices()
        loadDemoNotifications() // Keep some demo data for functionality showcase
        
        // Connect with ProductTrackingService
        ProductTrackingService.shared.setNotificationManager(self)
    }
    
    private func setupServices() {
        // Initialize services with proper API configurations
        Task { @MainActor in
            // All services disabled for production
        }
    }
    
    func startListening() {
        // REMOVED: BestBuy price drop listening functionality
        // Listen to eBay notifications
        // In real implementation, this would connect to webhook events
    }
    
    func stopListening() {
        cancellables.removeAll()
    }
    
    func refresh() async {
        isLoading = true
        // Refresh from actual tracking services + keep demo data
        await refreshTrackedItems()
        isLoading = false
    }
    
    func markAllAsRead() {
        notifications.forEach { $0.isRead = true }
    }
    
    func dismiss(_ notification: NotificationItem) {
        notifications.removeAll { $0.id == notification.id }
    }
    
    func clearAll() {
        notifications.removeAll()
    }
    
    private func checkForPriceDrops() {
        // Check tracked items for price changes
        // This would be connected to real price tracking logic
    }
    
    // MARK: - Real Tracking Functions
    
    private func refreshTrackedItems() async {
        // Get real tracked items
        var realNotifications: [NotificationItem] = []
        
        // Get notifications from actual tracked products
        let trackedProducts = ProductTrackingService.shared.getAllTrackedProducts()
        
        // Convert tracked products to tracking notifications if not already present
        for product in trackedProducts {
            // Check if we already have a tracking notification for this product
            let hasTrackingNotification = notifications.contains { notification in
                notification.productId == product.id.uuidString && notification.type == .trackingUpdate
            }
            
            if !hasTrackingNotification {
                let trackingNotification = NotificationItem(
                    title: "Currently Tracking",
                    message: "Monitoring \(product.name) for price changes",
                    type: .trackingUpdate,
                    source: product.source,
                    productId: product.id.uuidString,
                    productName: product.name,
                    productImageUrl: product.imageUrl,
                    isRead: true
                )
                realNotifications.append(trackingNotification)
            }
        }
        
        // Keep existing real notifications and add new ones
        await MainActor.run {
            // Filter out demo notifications and keep only real ones
            let existingRealNotifications = self.notifications.filter { notification in
                notification.productId != nil
            }
            
            // Add demo notifications for showcase (only a few)
            let limitedDemoNotifications = Array(getDemoNotifications().prefix(2))
            
            self.notifications = existingRealNotifications + realNotifications + limitedDemoNotifications
        }
    }
    
    // Add tracked item to notifications (called from ProductDetailView)
    func addTrackedItem(_ product: ProductItem) {
        let notification = NotificationItem(
            title: "Tracking Started",
            message: "You're now tracking \(product.name)",
            type: .trackingUpdate,
            source: product.source,
            productId: product.id.uuidString,
            productName: product.name,
            productImageUrl: product.imageUrl
        )
        
        notifications.insert(notification, at: 0) // Add to top
    }
    
    // Add price drop notification
    func addPriceDropNotification(for product: ProductItem, oldPrice: Double, newPrice: Double) {
        let savings = oldPrice - newPrice
        let notification = NotificationItem(
            title: "Price Drop Alert!",
            message: "\(product.name) dropped from $\(String(format: "%.2f", oldPrice)) to $\(String(format: "%.2f", newPrice)) - Save $\(String(format: "%.2f", savings))!",
            type: .priceDrop,
            source: product.source,
            productId: product.id.uuidString,
            productName: product.name,
            productImageUrl: product.imageUrl,
            oldPrice: oldPrice,
            newPrice: newPrice
        )
        
        notifications.insert(notification, at: 0) // Add to top
    }
    
    // Add back in stock notification
    func addBackInStockNotification(for product: ProductItem) {
        let notification = NotificationItem(
            title: "Back in Stock",
            message: "\(product.name) is now available",
            type: .backInStock,
            source: product.source,
            productId: product.id.uuidString,
            productName: product.name,
            productImageUrl: product.imageUrl
        )
        
        notifications.insert(notification, at: 0) // Add to top
    }
    
    // MARK: - Demo Data (for showcase)
    
    private func loadDemoNotifications() {
        // Load demo notifications and any existing real notifications
        Task {
            await refreshTrackedItems()
        }
    }
    
    private func getDemoNotifications() -> [NotificationItem] {
        return [
            NotificationItem(
                title: "Price Drop Alert!",
                message: "Apple AirPods Pro dropped from $249.99 to $199.99 - Save $50!",
                type: NotificationTypeUI.priceDrop,
                source: "BestBuy",
                productId: "demo-airpods",
                productName: "Apple AirPods Pro (2nd Generation)",
                productImageUrl: "https://pisces.bbystatic.com/image2/BestBuy_US/images/products/6447/6447382_sd.jpg",
                oldPrice: 249.99,
                newPrice: 199.99
            ),
            NotificationItem(
                title: "Back in Stock",
                message: "Sony WH-1000XM5 Wireless Headphones are now available",
                type: NotificationTypeUI.backInStock,
                source: "Amazon",
                productId: "demo-sony",
                productName: "Sony WH-1000XM5 Wireless Headphones",
                productImageUrl: "https://m.media-amazon.com/images/I/51QeS0jMIdL._AC_SL1500_.jpg",
                isRead: true
            )
        ]
    }
}

// Date Extension for relative time
extension Date {
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    TrackingView()
}
