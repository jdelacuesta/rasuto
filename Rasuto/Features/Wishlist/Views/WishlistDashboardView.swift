//
//  WishlistDashboardView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI
import SwiftData

struct WishlistDashboardView: View {
    @State private var searchText = ""
    @State private var showingAddItemSheet = false
    @State private var showingAddWishlistSheet = false
    @State private var collections = ["Electronics", "Clothes", "Books", "Summer"]
    @State private var wishlists = ["Birthday", "Christmas", "Anniversary", "Graduation"]
    @State private var selectedCollection = "All Items"
    @State private var showingNewCollectionSheet = false
    @State private var isRotating = false
    @StateObject private var wishlistService = WishlistService()
    
    // For animations
    @State private var animateSaved = false
    @State private var animateWishlists = false
    @State private var animateCollections = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 14) {
                    // Top Navigation Bar
                    TopNavBar(isRotating: $isRotating, onAddTapped: {
                        showingAddItemSheet = true
                    })
                    
                    // Divider line for consistency
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)
                        .padding(.top, 8)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // SECTION 1: Saved - Primary user action, moved to top
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Saved")
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
                                
                                // Items Grid - Now using real saved items
                                SavedItemsGridView(
                                    savedItems: wishlistService.savedItems,
                                    wishlistService: wishlistService,
                                    animateSaved: animateSaved
                                )
                                .padding(.horizontal)
                            }
                            
                            // SECTION 2: Wishlists - Organization layer
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Wishlists")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    
                                    Spacer()
                                    
                                    Button(action: { showingAddWishlistSheet = true }) {
                                        Label("Add", systemImage: "plus")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Wishlists Horizontal Scroll
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(wishlists, id: \.self) { wishlist in
                                            WishlistCard(title: wishlist, itemCount: Int.random(in: 1...12))
                                                .frame(width: 160)
                                                .scaleEffect(animateWishlists ? 1 : 0.95)
                                                .opacity(animateWishlists ? 1 : 0)
                                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(wishlists.firstIndex(of: wishlist) ?? 0) * 0.1), value: animateWishlists)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            
                            // SECTION 3: Collections - Advanced organization
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Collections")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                // Collections List
                                VStack(spacing: 12) {
                                    ForEach(collections, id: \.self) { collection in
                                        CollectionRow(title: collection)
                                            .opacity(animateCollections ? 1 : 0)
                                            .offset(x: animateCollections ? 0 : 50)
                                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(collections.firstIndex(of: collection) ?? 0) * 0.1), value: animateCollections)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Centered Add New Collection button
                                HStack {
                                    Spacer()
                                    Button(action: { showingNewCollectionSheet = true }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.blue)
                                            Text("Add New Collection")
                                                .fontWeight(.medium)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.top, 12)
                            }
                            
                            Spacer(minLength: 80) // Bottom padding for tab bar
                        }
                        .padding(.vertical)
                    }
                }
                
                // Tab Bar
                VStack {
                    Spacer()
                }
            }
            //.navigationBarHidden(true)
            .onAppear {
                // Trigger animations when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        animateSaved = true
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation {
                        animateCollections = true
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation {
                        animateWishlists = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingAddItemSheet) {
                AddItemView(isPresented: $showingAddItemSheet)
            }
            .fullScreenCover(isPresented: $showingNewCollectionSheet) {
                NewCollectionView { newCollection in
                    if !newCollection.isEmpty {
                        collections.append(newCollection)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingAddWishlistSheet) {
                NewWishlistView { newWishlist in
                    if !newWishlist.isEmpty {
                        wishlists.append(newWishlist)
                    }
                }
            }
        }
    }
    
    // Helper functions for sample data
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

// Saved Item Card (for Saved section - formerly All Items)
struct WishlistSavedItemCard: View {
    var imageName: String
    var title: String
    var category: String
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(12)
                
                Image(systemName: imageName)
                    .font(.system(size: 32))
                    .foregroundColor(.black.opacity(0.7))
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
            
            Text(category)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

// Collection Row (for Collections section)
struct CollectionRow: View {
    var title: String
    
    var body: some View {
        HStack {
            Image(systemName: getCategoryIcon(for: title))
                .font(.system(size: 24))
                .foregroundColor(.black.opacity(0.7))
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    func getCategoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "electronics":
            return "desktopcomputer"
        case "clothes":
            return "tshirt"
        case "books":
            return "book"
        case "summer":
            return "sun.max"
        default:
            return "tag"
        }
    }
}

// Wishlist Card (for Wishlists section)
struct WishlistCard: View {
    var title: String
    var itemCount: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .aspectRatio(1.2, contentMode: .fit)
                    .cornerRadius(12)
                
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .padding(12)
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
            
            Text("\(itemCount) items")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

// Tab Bar Button (unchanged)
struct TabBarButton: View {
    var imageName: String
    var title: String
    var isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: imageName)
                .font(.system(size: 22))
                .foregroundColor(isSelected ? .blue : .gray)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}

// Placeholder views (unchanged)
struct NewWishlistView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var wishlistName = ""
    var onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wishlist Details")) {
                    TextField("Wishlist Name", text: $wishlistName)
                }
            }
            .navigationTitle("Add New Wishlist")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    onSave(wishlistName)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(wishlistName.isEmpty)
            )
        }
    }
}

// NewCollectionView is imported from Views/AddItem/NewCollectionView.swift

// Real Saved Item Card using actual ProductItem data
struct RealSavedItemCard: View {
    let product: ProductItem
    let wishlistService: WishlistService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product image
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                        
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                case .failure:
                    ZStack {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                        
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                @unknown default:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .cornerRadius(12)
            .overlay(
                HStack {
                    Spacer()
                    VStack {
                        Button(action: {
                            Task {
                                await wishlistService.removeFromWishlist(product.id)
                            }
                        }) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .padding(6)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                }
                .padding(8)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.black)
                
                if !product.brand.isEmpty {
                    Text(product.brand)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if let price = product.price {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                } else {
                    Text("Price unavailable")
                        .font(.callout)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// Separate view component to handle complex grid logic
struct SavedItemsGridView: View {
    let savedItems: [ProductItem]
    let wishlistService: WishlistService
    let animateSaved: Bool
    
    var body: some View {
        Group {
            if savedItems.isEmpty {
                WishlistEmptyStateView(animateSaved: animateSaved)
            } else {
                SavedItemsGrid(savedItems: savedItems, wishlistService: wishlistService, animateSaved: animateSaved)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: savedItems.isEmpty)
    }
}

// Empty state component for wishlist
struct WishlistEmptyStateView: View {
    let animateSaved: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No saved items yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Save products from Best Buy or eBay searches")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .opacity(animateSaved ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateSaved)
    }
}

// Grid component
struct SavedItemsGrid: View {
    let savedItems: [ProductItem]
    let wishlistService: WishlistService
    let animateSaved: Bool
    
    private var limitedItems: [ProductItem] {
        Array(savedItems.prefix(6))
    }
    
    private var columns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(limitedItems.indices, id: \.self) { index in
                RealSavedItemCard(
                    product: limitedItems[index],
                    wishlistService: wishlistService
                )
                .opacity(animateSaved ? 1 : 0)
                .offset(y: animateSaved ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateSaved)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: limitedItems.count)
    }
}

// Individual card component for wishlist moved to line 212

struct WishlistDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        WishlistDashboardView()
    }
}
