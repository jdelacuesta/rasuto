//
//  AddItemView.swift
//  Rasuto
//
//  Created on 4/21/25.
//

import SwiftUI

struct AddItemView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var collectionManager: WishlistCollectionManager
    @State private var itemName: String = ""
    @State private var itemPrice: String = ""
    @State private var selectedCollection: WishlistCollection?
    @State private var showCollectionPicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $itemName)
                    
                    TextField("Price", text: $itemPrice)
                        .keyboardType(.decimalPad)
                    
                    Button(action: {
                        showCollectionPicker.toggle()
                    }) {
                        HStack {
                            Text("Collection")
                            Spacer()
                            Text(selectedCollection?.name ?? "Choose Collection")
                                .foregroundColor(selectedCollection == nil ? .secondary : .primary)
                        }
                    }
                }
                
                Section {
                    // Image placeholder
                    ZStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                        
                        Image(systemName: "camera")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        // For now just a placeholder
                    }
                    
                    Text("Tap to add an image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowInsets(EdgeInsets())
                .padding()
                
                Section {
                    Button(action: {
                        // Here you would add the item to the selected collection
                        isPresented = false
                    }) {
                        Text("Add to Wishlist")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(itemName.isEmpty || itemPrice.isEmpty)
                }
            }
            .navigationTitle("Add New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showCollectionPicker) {
                CollectionPickerView(selectedCollection: $selectedCollection)
            }
        }
    }
}

// Helper view for picking a collection
struct CollectionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var collectionManager: WishlistCollectionManager
    @Binding var selectedCollection: WishlistCollection?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Default Wishlists")) {
                    ForEach(collectionManager.defaultWishlists) { collection in
                        Button(action: {
                            selectedCollection = collection
                            dismiss()
                        }) {
                            HStack {
                                Text(collection.name)
                                Spacer()
                                if selectedCollection?.id == collection.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                if !collectionManager.collections.isEmpty {
                    Section(header: Text("Your Collections")) {
                        ForEach(collectionManager.collections) { collection in
                            Button(action: {
                                selectedCollection = collection
                                dismiss()
                            }) {
                                HStack {
                                    Text(collection.name)
                                    Spacer()
                                    if selectedCollection?.id == collection.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddItemView(isPresented: .constant(true))
            .environmentObject(WishlistCollectionManager())
    }
}
