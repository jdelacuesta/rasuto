//
//  NotificationsView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI
import Combine

struct NotificationsView: View {
    @StateObject private var notificationManager = UnifiedNotificationManager()
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingClearConfirmation = false
    @State private var refreshing = false
    
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
            return notificationManager.notifications.filter { $0.type == .priceDrop }
        case .backInStock:
            return notificationManager.notifications.filter { $0.type == .backInStock }
        case .tracking:
            return notificationManager.notifications.filter { $0.type == .trackingUpdate }
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
            return notificationManager.notifications.filter { $0.type == .priceDrop }.count
        case .backInStock:
            return notificationManager.notifications.filter { $0.type == .backInStock }.count
        case .tracking:
            return notificationManager.notifications.filter { $0.type == .trackingUpdate }.count
        }
    }
    
    private func refreshNotifications() async {
        refreshing = true
        await notificationManager.refresh()
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: notification.type.icon)
                    .font(.system(size: 22))
                    .foregroundColor(notification.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(isExpanded ? nil : 1)
                    
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
                    Label(notification.source, systemImage: storeIcon(for: notification.source))
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
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
                if !notification.isRead {
                    notification.isRead = true
                }
            }
        }
    }
    
    private func storeIcon(for store: String) -> String {
        switch store.lowercased() {
        case "bestbuy":
            return "cart.fill"
        case "ebay":
            return "tag.fill"
        case "walmart":
            return "bag.fill"
        default:
            return "storefront.fill"
        }
    }
}

// Notification Models
class NotificationItem: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    let source: String
    let productId: String?
    let timestamp: Date
    @Published var isRead: Bool
    
    init(title: String, message: String, type: NotificationType, source: String, productId: String? = nil, isRead: Bool = false) {
        self.title = title
        self.message = message
        self.type = type
        self.source = source
        self.productId = productId
        self.timestamp = Date()
        self.isRead = isRead
    }
}

enum NotificationType {
    case priceDrop
    case backInStock
    case trackingUpdate
    
    var icon: String {
        switch self {
        case .priceDrop: return "arrow.down.circle.fill"
        case .backInStock: return "checkmark.circle.fill"
        case .trackingUpdate: return "bell.badge.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .priceDrop: return .green
        case .backInStock: return .blue
        case .trackingUpdate: return .orange
        }
    }
}

// Unified Notification Manager
class UnifiedNotificationManager: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var isLoading = false
    
    private var bestBuyTracker = BestBuyPriceTracker()
    private var ebayManager = EbayNotificationManager()
    private var cancellables = Set<AnyCancellable>()
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    init() {
        loadMockNotifications()
    }
    
    func startListening() {
        // Listen to BestBuy price drops
        bestBuyTracker.objectWillChange
            .sink { [weak self] _ in
                self?.checkForPriceDrops()
            }
            .store(in: &cancellables)
        
        // Listen to eBay notifications
        // In real implementation, this would connect to webhook events
    }
    
    func stopListening() {
        cancellables.removeAll()
    }
    
    func refresh() async {
        isLoading = true
        // Simulate API refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        loadMockNotifications()
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
    
    private func loadMockNotifications() {
        notifications = [
            NotificationItem(
                title: "Price Drop Alert!",
                message: "Apple AirPods Pro dropped from $249.99 to $199.99 - Save $50!",
                type: .priceDrop,
                source: "BestBuy"
            ),
            NotificationItem(
                title: "Back in Stock",
                message: "Sony WH-1000XM5 Wireless Headphones are now available",
                type: .backInStock,
                source: "eBay",
                isRead: true
            ),
            NotificationItem(
                title: "Tracking Started",
                message: "You're now tracking Nintendo Switch OLED Model",
                type: .trackingUpdate,
                source: "BestBuy"
            ),
            NotificationItem(
                title: "Price Increased",
                message: "Samsung 65\" OLED TV price went up by $200",
                type: .trackingUpdate,
                source: "BestBuy",
                isRead: true
            ),
            NotificationItem(
                title: "Flash Sale!",
                message: "Apple Watch Series 9 is 20% off for the next 2 hours",
                type: .priceDrop,
                source: "eBay"
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
    NotificationsView()
}
