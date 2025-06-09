//
//  WishlistDetailView.swift
//  Rasuto
//
//  Created for wishlist detail functionality.
//

import SwiftUI

struct WishlistDetailView: View {
    let wishlistName: String
    @ObservedObject var wishlistService: WishlistService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingWishlistAssignment = false
    @State private var searchText = ""
    @State private var selectedProduct: ProductItem?
    @State private var showingProductDetail = false
    @State private var showingShareSheet = false
    
    private var wishlistItems: [ProductItem] {
        wishlistService.getItemsForWishlist(wishlistName)
    }
    
    private var filteredItems: [ProductItem] {
        if searchText.isEmpty {
            return wishlistItems
        } else {
            return wishlistItems.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Ensure full background coverage
                Color(.systemGray6)
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header with stats
                    headerSection
                    
                    // Search bar (only show if there are items)
                    if !wishlistItems.isEmpty {
                        searchSection
                    }
                    
                    // Content area
                    if filteredItems.isEmpty && searchText.isEmpty {
                        emptyWishlistView
                    } else if filteredItems.isEmpty {
                        noSearchResultsView
                    } else {
                        VStack(spacing: 0) {
                            itemsListView
                            
                            // Add Item to Wishlist button
                            addItemButton
                        }
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingWishlistAssignment) {
            WishlistAssignmentView(
                wishlistName: wishlistName,
                wishlistService: wishlistService
            )
        }
        .onAppear {
            print("🔍 WishlistDetailView appeared - \(wishlistName) has \(wishlistItems.count) items")
        }
        .onChange(of: wishlistService.savedItems) { _ in
            print("🔄 WishlistDetailView: savedItems changed - \(wishlistName) now has \(wishlistItems.count) items")
        }
        .onChange(of: wishlistItems.count) { newCount in
            print("🔄 WishlistDetailView: \(wishlistName) item count changed to \(newCount)")
        }
        .fullScreenCover(isPresented: $showingProductDetail) {
            if let product = selectedProduct {
                ProductDetailView(product: product)
                    .onAppear {
                        print("🚀 ProductDetailView appeared for: \(product.name)")
                    }
            } else {
                // Fallback view in case product is nil
                VStack {
                    Text("Loading...")
                        .font(.title2)
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding()
                }
                .onAppear {
                    print("⚠️ ProductDetailView: selectedProduct is nil")
                    // Auto-dismiss if no product
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingProductDetail = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: generateShareContent())
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Custom title area with close button and item count
            HStack(alignment: .center, spacing: 16) {
                // Back button
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                .frame(minWidth: 80, alignment: .leading)
                
                Spacer()
                
                // Centered title
                Text(wishlistName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                // Right side buttons
                HStack(spacing: 12) {
                    if !wishlistItems.isEmpty {
                        Text("\(wishlistItems.count) item\(wishlistItems.count == 1 ? "" : "s")")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    // Share button
                    Button(action: {
                        shareWishlist()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .frame(minWidth: 80, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search wishlist items...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Items List
    
    private var itemsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    WishlistDetailItemRow(
                        item: item,
                        onTap: {
                            print("🔄 Item tapped: \(item.name)")
                            selectedProduct = item
                            print("🔄 Selected product set: \(selectedProduct?.name ?? "nil")")
                            showingProductDetail = true
                            print("🔄 Showing product detail: \(showingProductDetail)")
                        },
                        onRemove: {
                            removeItemFromWishlist(item.id)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Empty States
    
    private var emptyWishlistView: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("Empty Wishlist")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Add items from your saved collection to organize them in this wishlist.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Add Items") {
                        showingWishlistAssignment = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Add Item Button
    
    private var addItemButton: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 20)
            
            Button(action: {
                showingWishlistAssignment = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                                .background(Circle().fill(Color.blue.opacity(0.1)))
                        )
                    
                    Text("Add Item to \(wishlistName)")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Actions
    
    private func removeItemFromWishlist(_ itemId: UUID) {
        wishlistService.removeItemFromWishlist(itemId, wishlistName: wishlistName)
    }
    
    // MARK: - Share Functionality
    
    private func shareWishlist() {
        print("📤 Share wishlist requested: \(wishlistName)")
        // TODO: Implement share functionality tomorrow
        // This will include:
        // - Generate shareable wishlist link/content
        // - Format wishlist items for sharing
        // - Present iOS share sheet
        // - Handle different sharing options (link, text, image)
        
        showingShareSheet = true
    }
    
    private func generateShareContent() -> [Any] {
        // TODO: Implement tomorrow
        // Generate shareable content including:
        // - Wishlist name and item count
        // - List of items with names and prices
        // - Optional: Generated image/preview
        // - Deep link to wishlist (if implementing web version)
        
        let shareText = """
        Check out my wishlist "\(wishlistName)" with \(wishlistItems.count) amazing items!
        
        \(wishlistItems.prefix(3).map { "• \($0.name)" }.joined(separator: "\n"))
        \(wishlistItems.count > 3 ? "\nAnd \(wishlistItems.count - 3) more items..." : "")
        
        Created with Rasuto
        """
        
        return [shareText]
    }
}

// MARK: - Wishlist Detail Item Row

struct WishlistDetailItemRow: View {
    let item: ProductItem
    let onTap: () -> Void
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Product image
            AsyncImage(url: URL(string: item.imageUrl)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay(ProgressView().scaleEffect(0.7))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure(_):
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            // Product info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text("$\(item.price ?? 0, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(RetailerType.displayName(for: item.source))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
                
                if !item.brand.isEmpty {
                    Text(item.brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Remove button
            Button(action: {
                showingRemoveAlert = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            print("🔄 WishlistDetailItemRow tapped: \(item.name)")
            onTap()
        }
        .alert("Remove from Wishlist", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { onRemove() }
        } message: {
            Text("Are you sure you want to remove '\(item.name)' from this wishlist?")
        }
    }
}

// MARK: - Preview

#Preview {
    WishlistDetailView(
        wishlistName: "Holiday Gifts",
        wishlistService: WishlistService.shared
    )
}
