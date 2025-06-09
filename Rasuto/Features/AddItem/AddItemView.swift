//
//  AddItemView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct AddItemView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var productURL: String = ""
    @State private var itemName: String = ""
    @State private var notes: String = ""
    @State private var selectedCollection: String = ""
    @State private var showingCollectionDropdown: Bool = false
    @State private var priority: Priority = .medium
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    
    // User's collections will be loaded dynamically
    @State private var userCollections: [String] = []
    
    enum Priority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
    
    var body: some View {
        ZStack {
            // Background to ensure full screen coverage
            Color(colorScheme == .dark ? UIColor.systemBackground : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top bar with exit button only - reduced top padding
                HStack {
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 12) // Reduced from 24
                }
                
                ScrollView {
                    VStack(alignment: .center, spacing: 20) { // Reduced spacing from 24
                        // Centered "Add New Item" header with adjusted padding
                        Text("Add New Item")
                            .font(.system(size: 24, weight: .bold))
                            .padding(.top, 8) // Reduced from 16
                            .padding(.bottom, 16) // Reduced from 24
                        
                        // Product Link
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Product Link")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Paste URL here", text: $productURL)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        // Item Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Item Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter product name", text: $itemName)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        // Notes - Updated background to match other fields
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ZStack(alignment: .topLeading) {
                                if notes.isEmpty {
                                    Text("Add reminder or notes")
                                        .foregroundColor(.gray)
                                        .padding(.top, 12)
                                        .padding(.leading, 12)
                                }
                                
                                TextEditor(text: $notes)
                                    .padding(4)
                                    .frame(height: 100)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                                    .opacity(notes.isEmpty ? 0.25 : 1)
                            }
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        // Add to Collection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add to Collection")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Button(action: {
                                showingCollectionDropdown.toggle()
                            }) {
                                HStack {
                                    Text(selectedCollection.isEmpty ? "Select a collection" : selectedCollection)
                                        .foregroundColor(selectedCollection.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                        .rotationEffect(.degrees(showingCollectionDropdown ? 180 : 0))
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            if showingCollectionDropdown {
                                VStack(alignment: .leading, spacing: 0) {
                                    if userCollections.isEmpty {
                                        Text("No collections available")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                        
                                        Text("Create collections first in your dashboard")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.horizontal)
                                            .padding(.bottom)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    } else {
                                        ForEach(userCollections, id: \.self) { collection in
                                            Button(action: {
                                                selectedCollection = collection
                                                showingCollectionDropdown = false
                                            }) {
                                                Text(collection)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding()
                                                    .background(selectedCollection == collection ? Color.blue.opacity(0.1) : Color.clear)
                                            }
                                            .foregroundColor(.primary)
                                            
                                            if collection != userCollections.last {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .padding(.top, -10)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Priority - Centered and wider buttons with reduced spacing
                        VStack(alignment: .leading, spacing: 8) { // Reduced from 12
                            Text("Priority")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal)
                            
                            HStack(spacing: 15) {
                                Spacer()
                                
                                ForEach(Priority.allCases, id: \.self) { priorityOption in
                                    Button(action: {
                                        priority = priorityOption
                                    }) {
                                        Text(priorityOption.rawValue)
                                            .font(.subheadline)
                                            .padding(.vertical, 10)
                                            .frame(width: 100)
                                            .foregroundColor(priority == priorityOption ? .white : .primary)
                                            .background(priority == priorityOption ? Color.blue : Color(UIColor.systemGray6))
                                            .cornerRadius(20)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        
                        // Further reduced space between priority and action buttons
                        Spacer().frame(height: 4) // Reduced from 10
                        
                        // Buttons grouped with minimal spacing
                        VStack(spacing: 10) {
                            // Cancel button
                            Button(action: {
                                isPresented = false
                            }) {
                                Text("Cancel")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 240, maxWidth: 280)
                                    .frame(height: 50)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(25)
                            }
                            
                            // Save button
                            Button(action: {
                                saveItem()
                            }) {
                                Text("Save")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(minWidth: 240, maxWidth: 280)
                                    .frame(height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.bottom, 20) // Reduced from 30
                    }
                    .padding(.top, 4) // Reduced from 8
                }
            }
        }
        .transition(.opacity)
        .onAppear {
            loadUserCollections()
        }
        .alert("Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveErrorMessage)
        }
    }
    
    private func loadUserCollections() {
        // For now, we'll use a simplified approach
        // In a full implementation, this would fetch from SwiftData
        // Excluding "Saved Items" as requested
        userCollections = []
    }
    
    private func saveItem() {
        // Validation
        guard !itemName.isEmpty else {
            saveErrorMessage = "Please enter an item name"
            showingSaveError = true
            return
        }
        
        guard !selectedCollection.isEmpty else {
            saveErrorMessage = "Please select a collection"
            showingSaveError = true
            return
        }
        
        // Create a ProductItem and save it
        Task {
            await saveToWishlist()
        }
    }
    
    @MainActor
    private func saveToWishlist() async {
        // Create ProductItemDTO for the manually added item
        let productDTO = ProductItemDTO(
            id: UUID(),
            sourceId: UUID().uuidString,
            name: itemName,
            productDescription: notes.isEmpty ? nil : notes,
            price: nil,
            currency: "USD",
            imageURL: nil,
            brand: "",
            source: "manual",
            category: selectedCollection,
            isInStock: true,
            productUrl: productURL.isEmpty ? nil : productURL
        )
        
        // Save using WishlistService
        await WishlistService.shared.saveToWishlist(from: productDTO)
        
        // If we have a specific collection selected (not "Saved Items"), assign it
        if selectedCollection != "Saved Items" && !selectedCollection.isEmpty {
            WishlistService.shared.assignItemsToWishlist([productDTO.id], wishlistName: selectedCollection)
        }
        
        // Close the view
        isPresented = false
    }
}

struct AddItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AddItemView(isPresented: .constant(true))
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            AddItemView(isPresented: .constant(true))
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
