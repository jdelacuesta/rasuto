//
//  SplashScreen.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

struct SplashScreen: View {
    @State private var showTagline = false
    @State private var showName = false
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            // Background Color
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 8) { // Reduced spacing between title and tagline
                // Rasuto Name - White, bold, and centered
                if showName {
                    Text("RASUTO")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .kerning(1.2)
                        .foregroundColor(.white)
                        .transition(.opacity)
                }

                // Tagline - Grey but readable, smaller text
                if showTagline {
                    Text("NEVER MISS THE LAST ONE.")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.gray)
                        .transition(.opacity)
                }

                Spacer().frame(height: 40)
            }

            // Loading Bar at the bottom
            VStack {
                Spacer()
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(Color.green)
                        .frame(width: CGFloat(progress), height: 5)
                        .animation(.easeOut(duration: 3), value: progress) // Slower green bar animation
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Trigger the animations
            withAnimation(Animation.easeInOut(duration: 1.5).delay(0.5)) { // Slightly longer animation for text
                showName = true
                showTagline = true
            }

            // Simulate the loading process
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    progress = 300 // Adjust this for how much of the bar you want to load
                }
            }

            // Move to HomeView after the loading is done
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { // Longer duration for the splash screen
                // Code to navigate to HomeView or perform next actions
            }
        }
    }
}
#Preview {
    SplashScreen()
        .onAppear {
            UserDefaults.standard.set(false, forKey: "hasSeenSplash")
        }
}
