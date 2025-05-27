//
//  TrackingDashboardView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

struct WishlistDashboardView: View {
    @State private var searchText = ""
    @State private var showingAddItemSheet = false
    @State private var collections = ["All Items", "Electronics", "Clothes", "Books", "Gaming", "TV & Home Theater", "Wearables"]
    @State private var selectedCollection = "All Items"
    @State private var showingNewCollectionSheet = false
    @State private var isRotating = false
    @State private var wishlistItems: [ProductItem] = []
    @State private var isLoading = false

    var filteredItems: [ProductItem] {
        if selectedCollection == "All Items" {
            return wishlistItems
        } else {
            return wishlistItems.filter { item in
                item.category.lowercased() == selectedCollection.lowercased()
            }
        }
    }
    
    var trackingStats: (total: Int, tracking: Int) {
        let total = wishlistItems.count
        let tracking = wishlistItems.filter { $0.isTracked }.count
        return (total, tracking)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)

                VStack(spacing: -4) {
                    TopNavBar(
                        isRotating: $isRotating,
                        onAddTapped: { showingAddItemSheet = true }
                    )
                    
                    // Stats bar
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(trackingStats.total)")
                                .font(.system(size: 24, weight: .bold))
                            Text("Saved Items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                                Text("\(trackingStats.tracking)")
                                    .font(.system(size: 24, weight: .bold))
                            }
                            Text("Tracking")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))

                    // Collection selector with animations
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(collections, id: \.self) { collection in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedCollection = collection
                                    }
                                }) {
                                    Text(collection)
                                        .font(.subheadline)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .foregroundColor(selectedCollection == collection ? .white : .primary)
                                        .background(selectedCollection == collection ? Color.black : Color(.systemGray5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(selectedCollection == collection ? Color.clear : Color(.systemGray3), lineWidth: 1)
                                        )
                                        .cornerRadius(20)
                                        .animation(.easeInOut(duration: 0.2), value: selectedCollection)
                                }
                            }
                        }
                        .padding()
                    }

                    // Wishlist items with loading and empty states
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Spacer()
                    } else if filteredItems.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: selectedCollection == "All Items" ? "heart" : "folder",
                            title: selectedCollection == "All Items" ? "No Saved Items" : "No \(selectedCollection)",
                            subtitle: selectedCollection == "All Items" ? 
                                "Items you save will appear here" : 
                                "No items in this collection yet"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(filteredItems) { item in
                                    WishlistItemCard(product: item)
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                }
                            }
                            .padding()
                            .padding(.bottom, 70) // space for the floating button
                        }
                    }
                }

                // Floating Add Collection button with animation
                VStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            showingNewCollectionSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.headline)
                                .rotationEffect(.degrees(isRotating ? 360 : 0))
                            Text("Add Collection")
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(showingNewCollectionSheet ? 0.95 : 1.0)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            // Use fullScreenCover for the Add Item sheet
            .fullScreenCover(isPresented: $showingAddItemSheet) {
                AddItemView(isPresented: $showingAddItemSheet)
            }
            .sheet(isPresented: $showingNewCollectionSheet) {
                NewCollectionView { newCollection in
                    if !newCollection.isEmpty && !collections.contains(newCollection) {
                        withAnimation {
                            collections.append(newCollection)
                        }
                    }
                }
            }
            .onAppear {
                loadWishlistItems()
            }
        }
    }
    
    private func loadWishlistItems() {
        isLoading = true
        // Simulate loading with sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                // Filter only favorite items for wishlist
                wishlistItems = ProductItem.sampleItems.filter { $0.isFavorite }
                // Set some items as tracked for demo
                if wishlistItems.count > 1 {
                    wishlistItems[0].isTracked = true
                    wishlistItems[1].isTracked = true
                }
                isLoading = false
            }
        }
    }
}
