//
//  TopNavigatorBar.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

// MARK: - Top Navigation Bar

struct TopNavBar: View {
    @Binding var isRotating: Bool
    @State private var showSearch = false
    @StateObject private var searchViewModel = SearchViewModel()
    var onAddTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Top row with logo and add button
            HStack {
                // Rasuto wordmark
                Text("Rasuto")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Add button
                Button(action: {
                    withAnimation(.linear(duration: 0.3)) {
                        isRotating = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onAddTapped()
                        isRotating = false
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                        .rotationEffect(.degrees(isRotating ? 90 : 0))
                }
            }
            .padding(.horizontal)
            
            // Search bar
            Button(action: {
                showSearch = true
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    Text("Search")
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: "mic")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(20)
                .padding(.horizontal)
            }
            .fullScreenCover(isPresented: $showSearch) {
                SearchView()
            }
        }
    }
}

#Preview {
    TopNavBar(isRotating: .constant(false), onAddTapped: {})
        .previewLayout(.sizeThatFits)
        .padding()
}
