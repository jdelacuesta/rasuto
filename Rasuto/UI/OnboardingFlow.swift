//
//  OnboardingFlow.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/28/25.
//

import SwiftUI

// MARK: - Main Onboarding View for Rasuto App

struct RasutoOnboardingView: View {
    @State private var currentPage = 0
    @State private var showSignUp = false
    @Binding var isPresented: Bool
    // @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentPage ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 3)
                            .animation(.easeInOut(duration: 0.4), value: currentPage)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                // Content area
                TabView(selection: $currentPage) {
                    RasutoWelcomeScreen()
                        .tag(0)
                    RasutoCoreActionsScreen()
                        .tag(1)
                    RasutoRetailerPowerScreen()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom navigation
                VStack(spacing: 16) {
                    if currentPage < 2 {
                        // Next/Continue button
                        Button(action: {
                            withAnimation(.spring(response: 0.6)) {
                                currentPage += 1
                            }
                        }) {
                            Text(currentPage == 0 ? "Show Me How" : "Tell Me More")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.blue)
                                .cornerRadius(16)
                                .scaleEffect(1.0)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Skip button
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.4)) {
                                isPresented = false
                            }
                        }) {
                            Text("Skip intro")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Final screen buttons - side by side layout
                        HStack(spacing: 12) {
                            // Demo button
                            Button(action: {
                                print("🎬 Demo button pressed - dismissing onboarding")
                                withAnimation(.easeOut(duration: 0.4)) {
                                    isPresented = false
                                }
                                print("🎬 isPresented set to false")
                            }) {
                                Text("Demo the app")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            // Sign up button - disabled for pre-launch
                            Button(action: {
                                // Disabled for pre-launch
                            }) {
                                VStack(spacing: 4) {
                                    Text("Create Account")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("Coming Soon")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(16)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(true)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showSignUp) {
            RasutoSignUpView(isPresented: $showSignUp, onComplete: {
                isPresented = false
            })
        }
    }
}

// MARK: - Screen 1: What is Rasuto?
struct RasutoWelcomeScreen: View {
    @State private var animateChart = false
    @State private var contentOpacity = 0.0
    @State private var iconScale = 0.8
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer() // Extra spacer to push content lower
            
            // Animated price tracking illustration - positioned lower
            VStack(spacing: 40) { // Increased spacing between icon and text
                ZStack {
                    // Background circle with subtle glow - reduced size
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 140, height: 140) // Reduced from 180
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .scaleEffect(iconScale)
                    
                    // Price tag icon
                    VStack(spacing: 10) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 36)) // Reduced from 44
                            .foregroundColor(.blue)
                        
                        // Animated price line
                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { index in
                                Capsule()
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 3, height: CGFloat([14, 24, 10, 28][index])) // Slightly smaller
                                    .scaleEffect(animateChart ? 1.2 : 0.8)
                                    .animation(
                                        .easeInOut(duration: 1.8)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.25),
                                        value: animateChart
                                    )
                            }
                        }
                    }
                }
                .onAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                        iconScale = 1.0
                    }
                    animateChart = true
                }
            }
            
            // Added spacing between icon and text
            Spacer()
                .frame(height: 50) // Explicit spacing between icon and text
            
            VStack(spacing: 18) {
                Text("Welcome to Rasuto")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Never overpay again. Track prices across multiple retailers and get notified when your favorite items go on sale.")
                    .font(.system(size: 16)) // Reduced from title3 (roughly 20pt) to 16pt
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 24)
            }
            .opacity(contentOpacity)
            .offset(y: contentOpacity == 1.0 ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    contentOpacity = 1.0
                }
            }
            
            Spacer()
            Spacer()
            Spacer() // Extra spacer to maintain lower positioning
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Screen 2: Core Actions
struct RasutoCoreActionsScreen: View {
    @State private var contentOpacity = 0.0
    @State private var stepsOffset: CGFloat = 30
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Spacer() // Extra spacer to push content lower for better centering
            
            VStack(spacing: 16) {
                Text("Three Simple Steps")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(contentOpacity)
                    .offset(y: contentOpacity == 1.0 ? 0 : -20)
                
                Text("Everything you need to become a smart shopper")
                    .font(.system(size: 16)) // Reduced by ~4pts from title3
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .opacity(contentOpacity)
                    .offset(y: contentOpacity == 1.0 ? 0 : -20)
            }
            
            VStack(spacing: 24) {
                ActionStep(
                    number: "1",
                    icon: "magnifyingglass.circle.fill",
                    title: "Search & Discover",
                    description: "Find any product across multiple retailers instantly",
                    accentColor: .blue,
                    index: 0
                )
                
                ActionStep(
                    number: "2",
                    icon: "heart.circle.fill",
                    title: "Save & Organize",
                    description: "Add items to your wishlists and collections for easy tracking",
                    accentColor: .blue,
                    index: 1
                )
                
                ActionStep(
                    number: "3",
                    icon: "bell.circle.fill",
                    title: "Track & Save Money",
                    description: "Get instant alerts when prices drop and never miss deals again",
                    accentColor: .blue,
                    index: 2
                )
            }
            .offset(y: stepsOffset)
            .opacity(contentOpacity)
            
            Spacer()
            Spacer()
            Spacer() // Extra spacer for better balance
        }
        .padding(.horizontal, 30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                contentOpacity = 1.0
                stepsOffset = 0
            }
        }
    }
}

// MARK: - Screen 3: Retailer Power & Expandability
struct RasutoRetailerPowerScreen: View {
    @State private var contentOpacity = 0.0
    @State private var iconOffset: CGFloat = -30 // Coming from above
    @State private var headerOffset: CGFloat = -30
    @State private var descriptionOffset: CGFloat = -30
    @State private var featuresOffset: CGFloat = -30
    @State private var iconScale = 0.8
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Spacer() // Extra spacer to push content lower for better centering
            
            // Retailer network visualization
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .scaleEffect(iconScale)
                
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("20+ Retailers")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue.opacity(0.8))
                }
            }
            .opacity(contentOpacity)
            .offset(y: iconOffset)
            
            // Header text
            Text("Endless Possibilities")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(contentOpacity)
                .offset(y: headerOffset)
            
            // Description text
            Text("We support 20+ major retailers out of the box, with the ability to expand to any retailer you need.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 20)
                .opacity(contentOpacity)
                .offset(y: descriptionOffset)
            
            // Feature highlights
            VStack(spacing: 16) {
                RetailerFeature(
                    icon: "checkmark.seal.fill",
                    text: "Amazon, eBay, Best Buy, Target & more",
                    color: .blue,
                    index: 0
                )
                
                RetailerFeature(
                    icon: "plus.circle.fill",
                    text: "Request new retailers anytime",
                    color: .blue,
                    index: 1
                )
                
                RetailerFeature(
                    icon: "gear.circle.fill",
                    text: "Advanced: Add your own API sources",
                    color: .blue,
                    index: 2
                )
            }
            .opacity(contentOpacity)
            .offset(y: featuresOffset)
            
            Spacer()
            Spacer()
            Spacer() // Extra spacer for better balance
        }
        .padding(.horizontal, 30)
        .onAppear {
            // Fine-tuned timing - slightly slower and longer
            withAnimation(.easeOut(duration: 1.2).delay(0.7)) {
                contentOpacity = 1.0
                iconOffset = 0
                iconScale = 1.0
            }
            
            withAnimation(.easeOut(duration: 1.2).delay(1.4)) {
                headerOffset = 0
            }
            
            withAnimation(.easeOut(duration: 1.2).delay(2.1)) {
                descriptionOffset = 0
            }
            
            withAnimation(.easeOut(duration: 1.2).delay(2.8)) {
                featuresOffset = 0
            }
        }
    }
}

// MARK: - Supporting Views
struct ActionStep: View {
    let number: String
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
    let index: Int
    @State private var stepOpacity = 0.0
    @State private var stepOffset: CGFloat = 20
    
    var body: some View {
        HStack(spacing: 16) {
            // Step number and icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                VStack(spacing: 1) {
                    Text(number)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(accentColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true) // Prevents truncation
                    .lineLimit(nil) // Allows multiple lines
            }
            
            Spacer()
        }
        .opacity(stepOpacity)
        .offset(x: stepOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(Double(index) * 0.15)) {
                stepOpacity = 1.0
                stepOffset = 0
            }
        }
    }
}

struct RetailerFeature: View {
    let icon: String
    let text: String
    let color: Color
    let index: Int
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color.opacity(0.8))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

// MARK: - Sign Up View
struct RasutoSignUpView: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreedToTerms = false
    @State private var contentOpacity = 0.0
    @State private var formOffset: CGFloat = 30
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        // App icon or logo placeholder
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            Image(systemName: "tag.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Join Rasuto")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Start tracking prices and never miss a deal")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .opacity(contentOpacity)
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        CustomTextField(
                            placeholder: "Email address",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        CustomSecureField(
                            placeholder: "Password",
                            text: $password
                        )
                        
                        CustomSecureField(
                            placeholder: "Confirm password",
                            text: $confirmPassword
                        )
                        
                        // Terms agreement
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    agreedToTerms.toggle()
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(agreedToTerms ? Color.white : Color.clear)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    if agreedToTerms {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                            
                            Text("I agree to the Terms of Service and Privacy Policy")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                    }
                    .opacity(contentOpacity)
                    .offset(y: formOffset)
                    
                    // Sign up button
                    Button(action: {
                        // Handle signup logic here
                        // TODO: Set authenticated mode when AppState is available
                        // In a real app, this would authenticate the user
                        // let mockUser = User(id: UUID().uuidString, email: email, name: nil)
                        // appState.setAuthenticatedMode(user: mockUser)
                        onComplete()
                    }) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.blue)
                            .cornerRadius(16)
                            .opacity(agreedToTerms && !email.isEmpty && !password.isEmpty ? 1.0 : 0.5)
                    }
                    .disabled(!agreedToTerms || email.isEmpty || password.isEmpty)
                    .buttonStyle(ScaleButtonStyle())
                    .opacity(contentOpacity)
                    
                    // Alternative options
                    VStack(spacing: 16) {
                        Text("Already have an account?")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Button("Sign In") {
                            // Navigate to sign in
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .opacity(contentOpacity)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 30)
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                contentOpacity = 1.0
                formOffset = 0
            }
        }
    }
}

// MARK: - Custom Text Fields
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
            )
            .keyboardType(keyboardType)
            .autocapitalization(.none)
            .focused($isFocused)
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        SecureField(placeholder, text: $text)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
            )
            .focused($isFocused)
    }
}

// MARK: - Button Styles
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Usage Example
struct ContentView: View {
    @State private var showOnboarding = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Text("Rasuto Price Tracker")
                    .font(.title)
                    .foregroundColor(.white)
                
                Button("Show Onboarding Again") {
                    showOnboarding = true
                }
                .foregroundColor(.gray)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            RasutoOnboardingView(isPresented: $showOnboarding)
        }
    }
}

#Preview {
    ContentView()
}
