//
//  MainView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

//MARK: - Main View

struct HomeView: View {
    @State private var searchText = ""
    @State private var showAddItemSheet = false
    @State private var isRotating = false
    @State private var selectedTab: Tab = .home

    enum Tab {
        case home
        case wishlist
        case notifications
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                // Home Tab Content
                homeContent
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(Tab.home)

            NavigationView {
                WishlistDashboardView()
            }
            .tabItem {
                Label("Wishlist", systemImage: "heart.fill")
            }
            .tag(Tab.wishlist)

            NavigationView {
                NotificationsView()
            }
            .tabItem {
                Label("Alerts", systemImage: "bell")
            }
            .tag(Tab.notifications)

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .fullScreenCover(isPresented: $showAddItemSheet) {
            AddItemView(isPresented: $showAddItemSheet)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 10)
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                TopNavBar(isRotating: $isRotating, onAddTapped: {
                    showAddItemSheet = true
                })

                Divider()

                RecentlyAddedSection()
                PriceDropsSection()
                TrendingSection()
            }
            .padding(.top)
        }
    }
}

//MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
