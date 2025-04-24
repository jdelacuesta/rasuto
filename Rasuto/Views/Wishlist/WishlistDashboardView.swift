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
    @State private var collections = ["All Items", "Electronics", "Clothes", "Books"]
    @State private var selectedCollection = "All Items"
    @State private var showingNewCollectionSheet = false
    @State private var isRotating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)

                VStack(spacing: -4) {
                    TopNavBar(
                        isRotating: $isRotating,
                        onAddTapped: { showingAddItemSheet = true }
                    )

                    // Collection selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(collections, id: \.self) { collection in
                                Button(action: { selectedCollection = collection }) {
                                    Text(collection)
                                        .font(.subheadline)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .foregroundColor(selectedCollection == collection ? .white : .black)
                                        .background(selectedCollection == collection ? Color.black : Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding()
                    }

                    // Wishlist items
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(0..<10) { _ in
                                WishlistItem()  // Now this references the separate WishlistItem
                            }
                        }
                        .padding()
                        .padding(.bottom, 70) // space for the floating button
                    }
                }

                // Floating Add Collection button
                VStack {
                    Spacer()
                    Button(action: { showingNewCollectionSheet = true }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.headline)
                            Text("Add Collection")
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            // Use fullScreenCover for the Add Item sheet
            .fullScreenCover(isPresented: $showingAddItemSheet) {
                AddItemView(isPresented: $showingAddItemSheet) // Make sure this view matches the one in HomeView
            }
            .sheet(isPresented: $showingNewCollectionSheet) {
                NewCollectionView { newCollection in
                    if !newCollection.isEmpty {
                        collections.append(newCollection)
                    }
                }
            }
        }
    }
}
