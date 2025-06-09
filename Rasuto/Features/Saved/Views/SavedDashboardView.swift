//
//  SavedDashboardView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI
import SwiftData

struct SavedDashboardView: View {
    @State private var searchText = ""
    @State private var showingAddItemSheet = false
    @State private var showingAddWishlistSheet = false
    @State private var collections: [String] = []
    @State private var wishlists: [String] = []
    @State private var selectedCollection = "All Items"
    @State private var showingNewCollectionSheet = false
    @State private var isRotating = false
    @ObservedObject private var wishlistService = WishlistService.shared
    @Environment(\.modelContext) private var modelContext
    
    // Modal state for wishlist assignment
    @State private var showingWishlistAssignment = false
    @State private var selectedWishlistForAssignment: String = ""
    
    // Modal state for collection assignment  
    @State private var showingCollectionAssignment = false
    @State private var selectedCollectionForAssignment: String = ""
    
    // Navigation state for collection detail
    @State private var showingCollectionDetail = false
    @State private var selectedCollectionForDetail: String = ""
    
    // Navigation state for wishlist detail
    @State private var showingWishlistDetail = false
    @State private var selectedWishlistForDetail: String = ""
    
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
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 16) {
                                        Button(action: {
                                            print("🔄 SavedDashboardView: Manual refresh requested")
                                            wishlistService.loadSavedItems()
                                            print("🔄 SavedDashboardView: After refresh - \(wishlistService.savedItems.count) items")
                                        }) {
                                            Image(systemName: "arrow.clockwise")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        
                                        Button(action: { }) {
                                            Text("See All")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.blue)
                                        }
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
                                        .foregroundColor(.primary)
                                    
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
                                if wishlists.isEmpty {
                                    EmptyWishlistsView(onAddTapped: { showingAddWishlistSheet = true })
                                        .padding(.horizontal)
                                        .opacity(animateWishlists ? 1 : 0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateWishlists)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(wishlists, id: \.self) { wishlist in
                                                WishlistCard(
                                                    title: wishlist,
                                                    itemCount: wishlistService.getItemCount(for: wishlist),
                                                    imageURL: wishlistService.getFirstItemImageURL(for: wishlist),
                                                    onTap: {
                                                        selectedWishlistForDetail = wishlist
                                                        showingWishlistDetail = true
                                                    },
                                                    onDelete: {
                                                        deleteWishlist(wishlist)
                                                    }
                                                )
                                                .frame(width: 160)
                                                .scaleEffect(animateWishlists ? 1 : 0.95)
                                                .opacity(animateWishlists ? 1 : 0)
                                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(wishlists.firstIndex(of: wishlist) ?? 0) * 0.1), value: animateWishlists)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            
                            // SECTION 3: Collections - Advanced organization
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Collections")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button(action: { showingNewCollectionSheet = true }) {
                                        Label("Add", systemImage: "plus")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Collections Grid - matching Wishlists format
                                if collections.isEmpty {
                                    EmptyCollectionsView(onAddTapped: { showingNewCollectionSheet = true })
                                        .padding(.horizontal)
                                        .opacity(animateCollections ? 1 : 0)
                                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateCollections)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(collections, id: \.self) { collection in
                                                CollectionCard(
                                                    title: collection,
                                                    itemCount: wishlistService.getItemCount(for: collection),
                                                    onTap: {
                                                        selectedCollectionForDetail = collection
                                                        showingCollectionDetail = true
                                                    },
                                                    onDelete: {
                                                        deleteCollection(collection)
                                                    }
                                                )
                                                .frame(width: 160)
                                                .scaleEffect(animateCollections ? 1 : 0.95)
                                                .opacity(animateCollections ? 1 : 0)
                                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(collections.firstIndex(of: collection) ?? 0) * 0.1), value: animateCollections)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
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
                print("🏠 SavedDashboardView: View appeared")
                // Set the model context for the wishlist service
                wishlistService.setModelContext(modelContext)
                print("🏠 SavedDashboardView: Current saved items count: \(wishlistService.savedItems.count)")
                
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
            .sheet(isPresented: $showingWishlistAssignment) {
                WishlistAssignmentView(
                    wishlistName: selectedWishlistForAssignment,
                    wishlistService: wishlistService
                )
            }
            .sheet(isPresented: $showingCollectionAssignment) {
                WishlistAssignmentView(
                    wishlistName: selectedCollectionForAssignment,
                    wishlistService: wishlistService
                )
            }
            .fullScreenCover(isPresented: $showingWishlistDetail) {
                WishlistDetailView(
                    wishlistName: selectedWishlistForDetail,
                    wishlistService: wishlistService
                )
            }
            .fullScreenCover(isPresented: $showingCollectionDetail) {
                CollectionDetailView(
                    collectionName: selectedCollectionForDetail,
                    wishlistService: wishlistService
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func deleteWishlist(_ wishlist: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            wishlists.removeAll { $0 == wishlist }
        }
    }
    
    private func deleteCollection(_ collection: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            collections.removeAll { $0 == collection }
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
    var onTap: () -> Void
    var onDelete: () -> Void
    @State private var showingDeleteAlert = false
    
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
            
            HStack(spacing: 16) {
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onTapGesture {
            onTap()
        }
        .alert("Delete Collection", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete \"\(title)\"? This action cannot be undone.")
        }
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
    var imageURL: String?
    var onTap: () -> Void
    var onDelete: () -> Void
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .topTrailing) {
                // Background or product image
                if let imageURL = imageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .aspectRatio(1.2, contentMode: .fit)
                                .cornerRadius(12)
                                .overlay(ProgressView().scaleEffect(0.7))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(1.2, contentMode: .fill)
                                .cornerRadius(12)
                                .clipped()
                        case .failure(_):
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .aspectRatio(1.2, contentMode: .fit)
                                .cornerRadius(12)
                                .overlay(
                                    Image(systemName: "heart.text.square")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray.opacity(0.6))
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .aspectRatio(1.2, contentMode: .fit)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    // Default gray placeholder with wishlist icon
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .aspectRatio(1.2, contentMode: .fit)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 24))
                                .foregroundColor(.gray.opacity(0.6))
                        )
                }
                
                // Delete button
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .background(Circle().fill(Color.white))
                }
                .padding(8)
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("\(itemCount) items")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onTapGesture {
            onTap()
        }
        .alert("Delete Wishlist", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(title)'? This action cannot be undone.")
        }
    }
}

// Collection Card (for Collections section) - matches Wishlist format
struct CollectionCard: View {
    var title: String
    var itemCount: Int
    var onTap: () -> Void
    var onDelete: () -> Void
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .aspectRatio(1.2, contentMode: .fit)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: getCategoryIcon(for: title))
                            .font(.system(size: 32))
                            .foregroundColor(.blue.opacity(0.7))
                    )
                
                // Delete button
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .background(Circle().fill(Color.white))
                }
                .padding(8)
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("\(itemCount) items")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onTapGesture {
            onTap()
        }
        .alert("Delete Collection", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(title)'? This action cannot be undone.")
        }
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
            return "folder"
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
            
            Text("Your liked items will appear here")
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

// MARK: - Empty State Views

struct EmptyWishlistsView: View {
    var onAddTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Wishlists yet")
                .font(.headline)
            
            Text("Create wishlists to organize items for special occasions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onAddTapped) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Wishlist")
                }
                .foregroundColor(.blue)
                .font(.callout.weight(.medium))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EmptyCollectionsView: View {
    var onAddTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Collections yet")
                .font(.headline)
            
            Text("Collections help you organize items by category like Electronics, Tech, or Home")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onAddTapped) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Collection")
                }
                .foregroundColor(.blue)
                .font(.callout.weight(.medium))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Preview

struct SavedDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SavedDashboardView()
    }
}
