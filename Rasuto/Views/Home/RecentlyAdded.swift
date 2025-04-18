//
//  RecentlyAddedItem.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct RecentlyAddedSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recently Added")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    // Add action
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Replace with actual item views instead of recursively calling self
                    ForEach(0..<3) { index in
                        RecentItem(id: index)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// Add this helper view
struct RecentItem: View {
    var id: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(width: 160, height: 160)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                )
            
            Text("Product \(id + 1)")
                .fontWeight(.semibold)
            
            Text("$199.99")
                .foregroundColor(.secondary)
        }
        .frame(width: 160)
    }
}
