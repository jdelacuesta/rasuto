//
//  HomeView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

// MARK: - Main HomeView

struct HomeView: View {
    @State private var searchText = ""
    @State private var showAddItemSheet = false
    @State private var isRotating = false
    @State private var selectedTab: Tab = .home
    @EnvironmentObject private var notificationManager: EbayNotificationManager
    
    // Animation states
    @State private var animateDiscover = false
    @State private var animateExploration = false
    @State private var animatePriceDrops = false
    @State private var animateRecentlySaved = false
    @State private var animateRecommended = false

    enum Tab: String, CaseIterable {
        case home = "house"
        case wishlist = "heart.fill"
        case search = "magnifyingglass"
        case notifications = "bell"
        case settings = "gear"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                currentTabView()
                Spacer(minLength: 0)
            }

            CustomTabBar(selectedTab: $selectedTab)
        }
        .edgesIgnoringSafeArea(.bottom)
        .fullScreenCover(isPresented: $showAddItemSheet) {
            AddItemView(isPresented: $showAddItemSheet)
        }
    }

    @ViewBuilder
    private func currentTabView() -> some View {
        switch selectedTab {
        case .home:
                homeContent
        case .wishlist:
                WishlistDashboardView()
        case .search:
                EbayAPITestView()
                    .navigationBarTitle("Search eBay", displayMode: .inline)
        case .notifications:
                NotificationsView()
        case .settings:
                SettingsView()
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                TopNavBar(isRotating: $isRotating, onAddTapped: {
                    showAddItemSheet = true
                })

                // Divider line for consistency
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
                    .padding(.top, 8)
                
                // SECTION 1: Trending Section
                trendingSection
                
                // SECTION 2: Discover Section
                discoverSection
                
                // SECTION 3: Price Drops Section
                priceDropsSection
                
                // SECTION 4: Recently Saved Section
                recentlySavedSection
                
                // SECTION 5: Recommended Section
                recommendedSection
                
                Spacer(minLength: 80) // Bottom padding for tab bar
            }
            //.padding(.top)
            .onAppear {
                startAnimationSequence()
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
            withAnimation { animateExploration = true }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { animatePriceDrops = true }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation { animateRecentlySaved = true }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { animateRecommended = true }
        }
    }
    
    // MARK: - Section Views
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trending")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {}
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)
            
            // Featured trending items in horizontal scrollview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        DiscoverItem(id: index)
                            .opacity(animateDiscover ? 1 : 0)
                            .offset(x: animateDiscover ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateDiscover)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 20)
    }
    
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Discover")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Categories in 3x3 grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(0..<6) { index in
                    CategoryItem(index: index)
                        .opacity(animateExploration ? 1 : 0)
                        .offset(y: animateExploration ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateExploration)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 20)
    }
    
    private var priceDropsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Price Drops")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: NotificationsView()) {
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
    private var priceDropsContent: some View {
        VStack(spacing: 12) {
            let alerts = notificationManager.getPriceDropAlerts()
            
            if alerts.isEmpty {
                EmptyPriceDropView()
                    .opacity(animatePriceDrops ? 1 : 0)
                    .offset(y: animatePriceDrops ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatePriceDrops)
            } else {
                ForEach(Array(alerts.prefix(2)), id: \.id) { alert in
                    PriceDropItemView(alert: alert, index: 0, isAnimated: animatePriceDrops) {
                        notificationManager.markAsRead(alert.id)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var recentlySavedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recently Saved")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { }) {
                    Text("See All")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Items Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    SavedItemCard(
                        imageName: getItemImageName(index),
                        title: getItemName(index),
                        category: getItemCategory(index)
                    )
                    .opacity(animateRecentlySaved ? 1 : 0)
                    .offset(y: animateRecentlySaved ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateRecentlySaved)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 20)
    }
    
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {}
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)
            
            featuredRecommendation
            
            recommendedGrid
        }
        .padding(.bottom, 30)
    }
    
    private var featuredRecommendation: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 180)
                    .cornerRadius(12)
                
                // Overlay with gradient and text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Featured For You")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(4)
                    
                    Text("Smart Home Devices")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Trending products that match your interests")
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
            .opacity(animateRecommended ? 1 : 0)
            .offset(y: animateRecommended ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateRecommended)
        }
        .padding(.horizontal)
    }
    
    private var recommendedGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(0..<4) { index in
                RecommendedItem(id: index)
                    .opacity(animateRecommended ? 1 : 0)
                    .offset(y: animateRecommended ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1 + 0.1), value: animateRecommended)
            }
        }
        .padding(.horizontal)
    }
    
    // Helper functions for Recently Saved items
    private func getItemImageName(_ index: Int) -> String {
        let images = ["desktopcomputer", "headphones", "tshirt", "iphone", "case", "book"]
        return images[index % images.count]
    }
    
    private func getItemName(_ index: Int) -> String {
        let names = ["Air Max", "Nextbit", "Beats", "White T-Shirt", "AirPods", "Kindle"]
        return names[index % names.count]
    }
    
    private func getItemCategory(_ index: Int) -> String {
        let categories = ["Sneakers", "Phone", "Headphones", "T-Shirt", "Earbuds", "E-Reader"]
        return categories[index % categories.count]
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

// MARK: - Custom Navigation Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: HomeView.Tab

    private let tabBarHeight: CGFloat = 90
    private let iconSize: CGFloat = 22
    private let verticalSpacing: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                ForEach(HomeView.Tab.allCases, id: \.self) { tab in
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

    private func tabTitle(_ tab: HomeView.Tab) -> String {
        switch tab {
        case .home: return "Home"
        case .wishlist: return "Wishlist"
        case .search: return "Search"
        case .notifications: return "Alerts"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Preview

#Preview {
    let ebayService = EbayAPIService(apiKey: "test_key")
    let notificationManager = EbayNotificationManager(ebayService: ebayService)
    
    // Add mock data for the preview
    notificationManager.addMockAlerts()
    
    return HomeView()
        .environmentObject(notificationManager)
}
