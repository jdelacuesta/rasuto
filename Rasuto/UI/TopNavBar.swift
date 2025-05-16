//
//  TopNavBar.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

// MARK: - Top Navigation Bar

struct TopNavBar: View {
    @Binding var isRotating: Bool
    @State private var showSearch = false
    @State private var showNLPActions = false
    
    var onAddTapped: () -> Void
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                // Only the R circle logo, slightly larger
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("R")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 39, height: 39)
                            .background(Color.black)
                            .clipShape(Circle())
                    )
                
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
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                        .rotationEffect(.degrees(isRotating ? 90 : 0))
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal)
            
            // Search bar
            Button(action: {
                showSearch = true
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    Text("Search for products")
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button(action: {
                        showNLPActions = true
                    }) {
                        Image(systemName: "mic")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray5))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView()
        }
        .fullScreenCover(isPresented: $showNLPActions) {
            NLPActionsSheet { searchQuery in
                // Handle search from voice/NLP
                showSearch = true
                // Pass the query to SearchView - in a real app, you would pass this query to the SearchView
            }
        }
    }
}

#Preview {
    TopNavBar(isRotating: .constant(false), onAddTapped: {})
        .previewLayout(.sizeThatFits)
        .padding()
}
