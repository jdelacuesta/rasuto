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
    @State private var productURL: String = ""
    @State private var itemName: String = ""
    @State private var notes: String = ""
    @State private var selectedCollection: String = "Saved Items"
    @State private var showingCollectionDropdown: Bool = false
    @State private var priority: Priority = .medium
    
    // Sample collections - in a real app, this would come from your data model
    let collections = ["Saved Items", "Electronics", "Clothes", "Books", "Wishlist"]
    
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
                // Top bar with exit button only
                HStack {
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(0)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 24)
                }
                
                ScrollView {
                    VStack(alignment: .center, spacing: 24) {
                        // Centered "Add New Item" header with larger font
                        Text("Add New Item")
                            .font(.system(size: 24, weight: .bold))
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                        
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
                                    Text(selectedCollection)
                                        .foregroundColor(.primary)
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
                                    ForEach(collections, id: \.self) { collection in
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
                                        
                                        if collection != collections.last {
                                            Divider()
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
                        
                        // Priority - Centered and wider buttons
                        VStack(alignment: .leading, spacing: 12) {
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
                                // Save logic would go here
                                isPresented = false
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
                        .padding(.bottom, 30) // Better padding from bottom edge
                    }
                    .padding(.top, 8)
                }
            }
        }
        .transition(.opacity)
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
