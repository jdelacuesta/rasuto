//
//  CollectionDropdownView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct NewCollectionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var collectionName = ""
    var onSave: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Collection Name", text: $collectionName)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )

                Button("Create Collection") {
                    onSave(collectionName)
                    dismiss()
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(8)
                .disabled(collectionName.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("New Collection")
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
