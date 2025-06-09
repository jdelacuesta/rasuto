//
//  SearchView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//  Renamed from HomeView on 6/3/25.
//

import SwiftUI
import SwiftData

// MARK: - Main SearchView

struct SearchView: View {
    @State private var searchText = ""
    @State private var showAddItemSheet = false
    @State private var showSearchCard = false
    @State private var isRotating = false
    @State private var selectedTab: Tab = .search
    @StateObject private var viewModel = MainSearchViewModel()
    @StateObject private var trendsService = GoogleTrendsService.shared
    @StateObject private var trackingService = ProductTrackingService.shared
    @Environment(\.modelContext) private var modelContext

    // Animation states
    @State private var animateDiscover = false
    @State private var animatePriceDrops = false

    enum Tab: String, CaseIterable {
        case search = "magnifyingglass"
        case saved = "heart.fill"
        case tracking = "bell"
        case settings = "gear"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    currentTabView()
                    Spacer(minLength: 0)
                }

                CustomTabBar(selectedTab: $selectedTab)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .fullScreenCover(isPresented: $showAddItemSheet) {
            AddItemView(isPresented: $showAddItemSheet)
        }
        .sheet(isPresented: $showSearchCard) {
            EnhancedSearchCard { product in
                // Handle product selection - convert DTO to ProductItem
                let productItem = ProductItem.from(product)
                
                // Navigate to product detail or handle selection
                Task { @MainActor in
                    // Add to saved items or track, etc.
                    print("Selected product: \(product.name) from \(product.source)")
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func currentTabView() -> some View {
        switch selectedTab {
        case .search:
                searchContent
        case .saved:
                SavedDashboardView()
        case .tracking:
                TrackingView()
        case .settings:
                SettingsView()
        }
    }

    private var searchContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                TopNavBar(
                    isRotating: $isRotating,
                    onAddTapped: {
                        showAddItemSheet = true
                    },
                    onSearchTapped: {
                        showSearchCard = true
                    }
                )
                
                // Quota Status Banner
                QuotaStatusBanner()
                    .padding(.top, -8)
                

                // Divider line for consistency
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
                    .padding(.top, 8)
                
                // SECTION 1: Trending (moved to top with enhanced styling)
                trendingSection
                
                // SECTION 2: Price Drops Section
                priceDropsSection
                
                Spacer(minLength: 80) // Bottom padding for tab bar
            }
            .refreshable {
                await viewModel.refreshTrendingWithLiveAPI()
            }
            .onAppear {
                startAnimationSequence()
                
                // FORCE LIGHT MODE when main app appears
                Task { @MainActor in
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.windows.forEach { window in
                            window.overrideUserInterfaceStyle = .light
                        }
                    }
                }
                print("💡 SearchView: Forced light mode interface")
                
                // Set the model context for the wishlist service
                WishlistService.shared.setModelContext(modelContext)
                print("🔧 SearchView: Set model context for WishlistService")
                
                // Set the model context for the tracking service
                ProductTrackingService.shared.setModelContext(modelContext)
                print("🔧 SearchView: Set model context for ProductTrackingService")
                
                // Ensure data is loaded when view appears
                if viewModel.trendingProducts.isEmpty {
                    print("🔄 SearchView: Triggering data load on appear")
                    viewModel.loadInitialData()
                }
                
                // Initialize Google Trends data if needed
                Task {
                    await trendsService.initializeIfNeeded()
                }
            }
        }
    }
    
    // Animation sequence
    private func startAnimationSequence() {
        // Trigger animations when view appears in a sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { animateDiscover = true }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { animatePriceDrops = true }
        }
    }
    
    
    // MARK: - Section Views
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trending")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if viewModel.isLoadingTrending {
                        Text("Loading fresh products...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else if let lastRefresh = viewModel.lastTrendingRefresh {
                        Text("Updated \(timeAgoString(from: lastRefresh))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                NavigationLink(destination: TrendingCatalogView(viewModel: viewModel)) {
                    Text("See All")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            featuredTrendingBanner
            
            allTrendingProducts
        }
        .padding(.top, 20)
        .padding(.bottom, 30)
    }
    
    private var featuredTrendingBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                // Background image with gradient overlay
                AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1565843714144-d5a3292ae82d")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(height: 180)
                .clipped()
                .cornerRadius(12)
                
                // Overlay with gradient and text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Staff Picks")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(4)
                    
                    Text("Popular Products")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Curated from top retailers")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.3)]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(12)
            }
            .opacity(animateDiscover ? 1 : 0)
            .offset(y: animateDiscover ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateDiscover)
        }
        .padding(.horizontal)
    }
    
    private var allTrendingProducts: some View {
        VStack(spacing: 20) {
            if viewModel.isLoadingTrending {
                // Loading state with 2x3 grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<6) { _ in
                        RecommendedItemPlaceholder()
                    }
                }
                .padding(.horizontal)
            } else if viewModel.trendingProducts.isEmpty {
                // Clean empty state with refresh button
                VStack(spacing: 20) {
                    Text("No trending products yet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Tap the refresh button below to load live data from all retailers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button(action: {
                        Task {
                            await viewModel.refreshTrendingWithLiveAPI()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Load Trending Products")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .rotationEffect(.degrees(viewModel.isLoadingTrending ? 360 : 0))
                    .animation(viewModel.isLoadingTrending ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoadingTrending)
                    .disabled(viewModel.isLoadingTrending)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Products grid - 2x3 layout showing best 6 products (all available in "See All")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(viewModel.trendingProducts.prefix(6).enumerated()), id: \.element.id) { index, dto in
                        let product = ProductItem.from(dto)
                        SearchProductCardView(product: product, cardWidth: (UIScreen.main.bounds.width - 48) / 2)
                            .opacity(animateDiscover ? 1 : 0)
                            .offset(y: animateDiscover ? 0 : 20)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.7)
                                .delay(Double(index) * 0.05), 
                                value: animateDiscover
                            )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // REMOVED: Discover section - functionality moved to search
    
    private var priceDropsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Deals")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: TrackingView()) {
                    Text("See All")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal)
            
            priceDropsContent
        }
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    private var priceDropsContent: some View {
        VStack(spacing: 12) {
            if viewModel.isLoadingPriceDrops {
                ForEach(0..<2) { _ in
                    PriceDropPlaceholder()
                }
            } else if viewModel.priceDropProducts.isEmpty {
                EmptyPriceDropView()
                    .opacity(animatePriceDrops ? 1 : 0)
                    .offset(y: animatePriceDrops ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatePriceDrops)
            } else {
                ForEach(Array(viewModel.priceDropProducts.prefix(3))) { dto in
                    let product = ProductItem.from(dto)
                    SearchProductHorizontalCardView(product: product)
                        .opacity(animatePriceDrops ? 1 : 0)
                        .offset(y: animatePriceDrops ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatePriceDrops)
                }
            }
        }
        .padding(.horizontal)
    }
    
    
}
// MARK: - PriceDropItemView

struct PriceDropItemView: View {
    let alert: NotificationAlert
    let index: Int
    let isAnimated: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                // Alert content here
                Text(alert.productName)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(alert.message)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .opacity(isAnimated ? 1 : 0)
            .offset(y: isAnimated ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: isAnimated)
            .onTapGesture {
                onTap()
            }
        }
    }
}

// Components for HomeView sections

struct DiscoverItem: View {
    var id: Int
    
    // Sample data
    private let items = [
        (name: "PS5 Digital Edition", price: "$399.99", image: "gamecontroller"),
        (name: "AirPods Pro 2", price: "$249.99", image: "airpodspro"),
        (name: "Samsung Galaxy S24", price: "$899.99", image: "iphone"),
        (name: "MacBook Air M3", price: "$1199.99", image: "laptopcomputer"),
        (name: "Nike Air Max", price: "$179.99", image: "shoe")
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 180, height: 180)
                    .cornerRadius(12)
                
                Image(systemName: items[id % items.count].image)
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            
            Text(items[id % items.count].name)
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(items[id % items.count].price)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(width: 180)
    }
}

struct CategoryItem: View {
    var index: Int
    
    private let categories = [
        (name: "Electronics", icon: "desktopcomputer"),
        (name: "Fashion", icon: "tshirt"),
        (name: "Home", icon: "house"),
        (name: "Books", icon: "book"),
        (name: "Sports", icon: "figure.run"),
        (name: "Tech", icon: "laptopcomputer")
    ]
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: categories[index % categories.count].icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            Text(categories[index % categories.count].name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(height: 90)
    }
}

struct RecommendedItem: View {
    var id: Int
    
    private let recommendations = [
        (name: "Smart Watch", category: "Electronics", image: "applewatch"),
        (name: "Wireless Earbuds", category: "Audio", image: "airpodspro"),
        (name: "Digital Camera", category: "Photography", image: "camera"),
        (name: "Bluetooth Speaker", category: "Audio", image: "hifispeaker")
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(1.2, contentMode: .fit)
                    .cornerRadius(12)
                
                Image(systemName: recommendations[id % recommendations.count].image)
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
            }
            .frame(width: 160)
            
            Text(recommendations[id % recommendations.count].name)
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(recommendations[id % recommendations.count].category)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 160)
    }
}

struct RecommendedItemPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .aspectRatio(1.0, contentMode: .fit)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 16)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 14)
                .shimmering()
        }
    }
}

// MARK: - Custom Navigation Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: SearchView.Tab

    private let tabBarHeight: CGFloat = 90
    private let iconSize: CGFloat = 22
    private let verticalSpacing: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                ForEach(SearchView.Tab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: verticalSpacing) {
                            Image(systemName: tab.rawValue)
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundColor(selectedTab == tab ? .blue : .gray)

                            Text(tabTitle(tab))
                                .font(.caption2)
                                .foregroundColor(selectedTab == tab ? .blue : .gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }  
            }
            .padding(.top, 12)
            .padding(.bottom, 24) // more space below text
            .padding(.horizontal)
            .background(.ultraThinMaterial)
        }
        .frame(height: tabBarHeight)
        .frame(maxWidth: .infinity)
        .edgesIgnoringSafeArea(.bottom)
    }

    private func tabTitle(_ tab: SearchView.Tab) -> String {
        switch tab {
        case .search: return "Search"
        case .saved: return "Saved"
        case .tracking: return "Tracking"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Placeholder Views

struct DiscoverItemPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(width: 180, height: 180)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 140, height: 16)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 14)
                .shimmering()
        }
        .frame(width: 180)
    }
}

struct PriceDropPlaceholder: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
                .shimmering()
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 200, height: 16)
                    .shimmering()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 20)
                    .shimmering()
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct CategoryButton: View {
    let name: String
    let icon: String
    let query: String
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(destination: CategorySearchView(category: name, query: query)) {
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(height: 90)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// Shimmer effect for loading states
extension View {
    func shimmering() -> some View {
        self
            .redacted(reason: .placeholder)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.5),
                        Color.gray.opacity(0.3)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(self)
                .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false))
            )
    }
}

// MARK: - Preview

#Preview {
    // Clean preview without any disabled services
    return SearchView()
        .environmentObject(WishlistService.shared)
        .environmentObject(ProductTrackingService.shared)
}
