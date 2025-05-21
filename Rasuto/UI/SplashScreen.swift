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
                // Top spacing - reduced to move content higher
                Spacer()
                    .frame(height: 150)
                
                // Main content - positioned higher in the view
                VStack(spacing: 6) {
                    // Native SwiftUI animation instead of Lottie
                    if showAnimation {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 200, height: 200)
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .rotationEffect(.degrees(rotation))
                            .onAppear {
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                                    scale = 1.0
                                    opacity = 1.0
                                }
                                
                                withAnimation(.easeInOut(duration: 1.5)) {
                                    rotation = 360
                                }
                                
                                // Set completion after animation finishes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    hasCompletedAnimation = true
                                }
                            }
                            .transition(.opacity)
                    }
                    
                    // Rasuto Name - Using the same style as TopNavBar
                    if showName {
                        HStack(spacing: 0) {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text("R")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 49, height: 49)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                )
                            
                            Text("asuto")
                                .font(.system(size: 36, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .padding(.leading, 4)
                        }
                        .transition(.opacity)
                    }

                    // Tagline - Grey but readable, smaller text
                    if showTagline {
                        Text("Never miss the last one.")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                            .transition(.opacity)
                    }
                }
                
                // Increased bottom spacer to push content up
                Spacer(minLength: 300)
                
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
        // Start with loading animation - using longer delays throughout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Step 1: Show animation first
            withAnimation(.easeIn(duration: 1.0)) { // Slower animation
                showAnimation = true
            }
            
            // Step 2: Show the logo after animation starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 1.0)) { // Slower animation
                    showName = true
                }
                
                // Step 3: Show the tagline
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 1.0)) { // Slower animation
                        showTagline = true
                    }
                    
                    // Step 4: Start progress bar
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation {
                            progress = 300 // Adjust width based on your design
                        }
                    }
                }
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
