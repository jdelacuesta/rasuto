//
//  PriceDrops.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct PriceDropsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Price Drops & Alerts")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    // Action
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Replace with actual price drop items instead of recursively calling self
                ForEach(0..<2) { index in
                    PriceDropItem(id: index)
                }
            }
            .padding(.horizontal)
        }
    }
}

// Add this helper view
struct PriceDropItem: View {
    var id: Int
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "tag")
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading) {
                Text("Item \(id + 1)")
                    .fontWeight(.semibold)
                HStack {
                    Text("$199.99")
                        .strikethrough()
                        .foregroundColor(.gray)
                    Text("$149.99")
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
