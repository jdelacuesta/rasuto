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
    var onAddTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 36, height: 36)
                .overlay(
                    Text("R")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 35, height: 35)
                        .background(Color.black)
                        .clipShape(Circle())
                )
            
            // Search bar
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
            .padding(.leading, 4)
        }
        .padding(.horizontal)
    }
}

#Preview {
    TopNavBar(isRotating: .constant(false), onAddTapped: {})
        .previewLayout(.sizeThatFits)
        .padding()
}
