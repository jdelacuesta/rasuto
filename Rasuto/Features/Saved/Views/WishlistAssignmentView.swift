//
//  WishlistAssignmentView.swift
//  Rasuto
//
//  Created for wishlist item assignment functionality.
//

import SwiftUI

struct WishlistAssignmentView: View {
    let wishlistName: String
    @ObservedObject var wishlistService: WishlistService
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedItems: Set<UUID> = []
    
    // Filter saved items based on search
    private var filteredItems: [ProductItem] {
        if searchText.isEmpty {
            return wishlistService.savedItems
        } else {
            return wishlistService.savedItems.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with wishlist info
                headerSection
                
                // Search bar
                searchSection
                
                // Items list
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    itemsListView
                }
                
                Spacer()
                
                // Action buttons
                actionButtonsSection
            }
            .navigationTitle("Add to \(wishlistName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select All") {
                        if selectedItems.count == filteredItems.count {
                            selectedItems.removeAll()
                        } else {
                            selectedItems = Set(filteredItems.map { $0.id })
                        }
                    }
                    .disabled(filteredItems.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(wishlistName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("\(wishlistService.savedItems.count) saved items available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
            
            // Selection summary
            if !selectedItems.isEmpty {
                HStack {
                    Text("\(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Clear") {
                        selectedItems.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search saved items", text: $searchText)
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
        .padding(.top, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Items List
    
    private var itemsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    WishlistAssignmentItemRow(
                        item: item,
                        isSelected: selectedItems.contains(item.id),
                        onSelectionChanged: { isSelected in
                            if isSelected {
                                selectedItems.insert(item.id)
                            } else {
                                selectedItems.remove(item.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Saved Items" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty ? 
                 "Save items from search results to add them to wishlists" :
                 "Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Add to wishlist button
            Button(action: addItemsToWishlist) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add \(selectedItems.count) Item\(selectedItems.count == 1 ? "" : "s") to \(wishlistName)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedItems.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(selectedItems.isEmpty)
            
            // Cancel button
            Button(action: {
                dismiss()
            }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
    
    // MARK: - Actions
    
    private func addItemsToWishlist() {
        print("📝 Starting assignment of \(selectedItems.count) items to wishlist: \(wishlistName)")
        
        // Ensure we have items to assign
        guard !selectedItems.isEmpty else {
            print("⚠️ No items selected for assignment")
            return
        }
        
        // Actually assign items to the wishlist
        wishlistService.assignItemsToWishlist(selectedItems, wishlistName: wishlistName)
        
        for itemId in selectedItems {
            if let item = wishlistService.savedItems.first(where: { $0.id == itemId }) {
                print("   - Added: \(item.name)")
            }
        }
        
        print("✅ Assignment completed - wishlist now has \(wishlistService.getItemCount(for: wishlistName)) items")
        
        // Force an immediate update to the observable object
        DispatchQueue.main.async {
            wishlistService.objectWillChange.send()
            print("🔄 Forced UI update for wishlist service")
        }
        
        // Small delay to ensure the update propagates before dismissing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("📱 Dismissing assignment modal")
            dismiss()
        }
    }
}

// MARK: - Item Row Component

struct WishlistAssignmentItemRow: View {
    let item: ProductItem
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: {
                onSelectionChanged(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
            // Product image
            AsyncImage(url: URL(string: item.imageUrl)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(ProgressView().scaleEffect(0.7))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure(_):
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onSelectionChanged(!isSelected)
        }
    }
}

// MARK: - Preview

#Preview {
    WishlistAssignmentView(
        wishlistName: "Holiday Gifts",
        wishlistService: WishlistService.shared
    )
}