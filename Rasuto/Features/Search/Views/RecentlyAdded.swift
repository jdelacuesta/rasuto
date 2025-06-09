//
//  RecentlyAddedItem.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct RecentlyAddedSection: View {
    @State private var animateItems = false
    
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
                .fontWeight(.semibold)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        RecentItem(id: index)
                            .opacity(animateItems ? 1 : 0)
                            .offset(x: animateItems ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateItems)
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    animateItems = true
                }
            }
        }
    }
}

// Updated Recent Item with consistent styling
struct RecentItem: View {
    var id: Int
    
    private let productNames = ["Air Max Sneakers", "Nextbit Phone", "Beats Headphones", "White T-Shirt", "Kindle E-Reader"]
    private let prices = ["$199.99", "$299.99", "$349.99", "$24.99", "$129.99"]
    private let images = ["bag", "desktopcomputer", "headphones", "tshirt", "books"]
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 160)
                    .cornerRadius(12)
                
                Image(systemName: images[id % images.count])
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            
            Text(productNames[id % productNames.count])
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(prices[id % prices.count])
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 160)
    }
}

#Preview {
    VStack {
        RecentlyAddedSection()
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
