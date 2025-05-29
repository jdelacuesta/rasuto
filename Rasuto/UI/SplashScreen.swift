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
    @State private var showAnimation = false
    @State private var progress = 0.0
    @State private var hasCompletedAnimation = false
    
    // To track when to navigate away
    @State private var navigateToMainView = false
    
    // Animation properties
    @State private var scale = 0.8
    @State private var opacity = 0.0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Background Color
            Color.black
                .ignoresSafeArea()

            VStack {
                // Top spacing - centered positioning
                Spacer()
                
                // Main content - clean wordmark animation
                VStack(spacing: 4) {
                    // Clean RASUTO wordmark
                    if showName {
                        Text("RASUTO")
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }

                    // Tagline - positioned below wordmark with minimal spacing
                    if showTagline {
                        Text("Never miss the last one.")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.gray.opacity(0.8))
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .move(edge: .bottom))
                            ))
                    }
                }
                
                // Bottom spacer to center content
                Spacer()
                
                // Loading Bar at the bottom
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(Color.green)
                        .frame(width: CGFloat(progress), height: 5)
                        .animation(.easeOut(duration: 4), value: progress) // Slower progress animation
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
        .onChange(of: hasCompletedAnimation) { completed in
            if completed {
                // Animation has finished, proceed to main app after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    navigateToMainView = true
                }
            }
        }
        // Use this to handle navigation to main app
        // Replace with your actual main view navigation logic
        .fullScreenCover(isPresented: $navigateToMainView) {
            // Your main view here, for example:
            // MainTabView() or HomeView()
            // For now, just showing a placeholder:
            Text("Main App View")
                .font(.largeTitle)
                .onAppear {
                    // Save that user has seen splash screen
                    UserDefaults.standard.set(true, forKey: "hasSeenSplash")
                }
        }
    }
    
    // Function to manage the animation sequence
    private func startAnimationSequence() {
        // Step 1: Show RASUTO wordmark with Apple-like spring animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.25)) {
                showName = true
                scale = 1.0
                opacity = 1.0
            }
        }
        
        // Step 2: Show tagline with subtle delay and smooth fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.6)) {
                showTagline = true
            }
        }
        
        // Step 3: Start progress bar with smooth easing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 2.2)) {
                progress = 300
            }
        }
        
        // Step 4: Set completion for navigation with perfect timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            hasCompletedAnimation = true
        }
    }
}

#Preview {
    SplashScreen()
        .onAppear {
            UserDefaults.standard.set(false, forKey: "hasSeenSplash")
        }
}
