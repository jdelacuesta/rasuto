//
//  AppLogoView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

// MARK: - App Logo View

struct AppLogoView: View {
    var size: CGFloat = 40
    
    var body: some View {
        // Exact replica of the app icon: Black background with white "R"
        ZStack {
            // Black background - exact match to app icon
            Rectangle()
                .fill(Color.black)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2237)) // iOS app icon corner radius (22.37%)
            
            // White "R" letter - exact match to app icon design
            Text("R")
                .font(.system(size: size * 0.585, weight: .bold, design: .default)) // Match SF Pro Display bold
                .foregroundColor(.white)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Different sizes to preview
        HStack(spacing: 20) {
            AppLogoView(size: 24)
            AppLogoView(size: 32)
            AppLogoView(size: 40)
            AppLogoView(size: 60)
        }
        
        Text("App Logo at Different Sizes")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
