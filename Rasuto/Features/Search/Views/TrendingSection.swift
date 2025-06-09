//
//  TrendingItems.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct TrendingSection: View {
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible())
    ]
    
    @State private var animateItems = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trending")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {}
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<4) { index in
                    TrendingItem(id: index)
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateItems)
                }
            }
            .padding(.horizontal)
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

struct TrendingItem: View {
    var id: Int
    
    private let productNames = ["AirPods Pro", "PlayStation 5", "iPhone 14 Pro", "MacBook Air"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 120)
                .overlay(
                    Image(systemName: getTrendingIcon(id))
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                )
            
            Text(productNames[id % productNames.count])
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
    
    private func getTrendingIcon(_ index: Int) -> String {
        let icons = ["airpodspro", "gamecontroller", "iphone", "laptopcomputer"]
        return icons[index % icons.count]
    }
}

#Preview {
    TrendingSection()
        .padding()
        .background(Color(.systemGroupedBackground))
}
