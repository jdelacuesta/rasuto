//
//  ErrorStateViews.swift
//  Rasuto
//
//  Created for Phase 5 error handling
//

import SwiftUI

// MARK: - Search Error States

struct SearchErrorView: View {
    let error: APIError
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            errorIcon
            
            VStack(spacing: 8) {
                Text(errorTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(error.userFriendlyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if error.isRetryable {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    @ViewBuilder
    private var errorIcon: some View {
        switch error {
            case .networkUnavailable:
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.black)
            case .rateLimitExceeded, .quotaExceeded:
                Image(systemName: "clock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
            case .authenticationFailed:
                Image(systemName: "key.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
            case .serpAPIError, .axessoError:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.yellow)
            default:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.black)
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .networkUnavailable:
            return "No Internet Connection"
        case .rateLimitExceeded:
            return "Rate Limit Exceeded"
        case .quotaExceeded:
            return "Daily Limit Reached"
        case .authenticationFailed:
            return "Authentication Error"
        case .serpAPIError:
            return "Search Temporarily Unavailable"
        case .axessoError:
            return "Amazon Search Unavailable"
        case .timeout:
            return "Request Timed Out"
        default:
            return "Something Went Wrong"
        }
    }
}

// MARK: - Network Error State

struct NetworkErrorView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.black)
            
            VStack(spacing: 8) {
                Text("No Internet Connection")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Please check your connection and try again")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .foregroundColor(.blue)
                .font(.callout.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - API Quota Error State

struct APIQuotaErrorView: View {
    let apiName: String
    let quotaResetTime: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Daily Search Limit Reached")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("You've reached the daily limit for \(apiName) searches")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let resetTime = quotaResetTime {
                    Text("Resets at \(resetTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            
            VStack(spacing: 12) {
                Text("Try these alternatives:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    AlternativeButton(
                        title: "Browse Saved Items",
                        systemImage: "heart.fill",
                        action: { /* Navigate to saved */ }
                    )
                    
                    AlternativeButton(
                        title: "View Trending Products",
                        systemImage: "chart.line.uptrend.xyaxis",
                        action: { /* Navigate to trending */ }
                    )
                }
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Rate Limit Error State

struct RateLimitErrorView: View {
    let retryAfter: TimeInterval?
    let onRetry: () -> Void
    
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundColor(.black)
            
            VStack(spacing: 8) {
                Text("Slow Down")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Too many requests. Please wait a moment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if timeRemaining > 0 {
                    Text("Try again in \(timeRemaining) seconds")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                } else if retryAfter != nil {
                    Text("You can try again now")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }
            }
            
            if timeRemaining == 0 {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .onAppear {
            if let retryAfter = retryAfter {
                timeRemaining = Int(retryAfter)
                startCountdown()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Supporting Views

struct AlternativeButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Loading State with Fallback

struct SearchLoadingView: View {
    let query: String
    let onCancel: () -> Void
    
    @State private var showFallback = false
    
    var body: some View {
        VStack(spacing: 20) {
            if showFallback {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Searching for \"\(query)\"")
                        .font(.headline)
                    
                    Text("This is taking longer than usual")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.blue)
                        .font(.callout)
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Searching for \"\(query)\"")
                        .font(.headline)
                    
                    Text("Finding the best deals...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Show fallback message after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                withAnimation {
                    showFallback = true
                }
            }
        }
    }
}

// MARK: - Fallback Search Results

struct FallbackSearchView: View {
    let originalQuery: String
    let onSearchSuggestion: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.black)
            
            VStack(spacing: 8) {
                Text("No results found for \"\(originalQuery)\"")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("Try adjusting your search or browse these suggestions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Text("Popular searches:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(popularSearches, id: \.self) { suggestion in
                        Button(action: { onSearchSuggestion(suggestion) }) {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 32)
    }
    
    private var popularSearches: [String] {
        return ["iPhone 15", "MacBook Air", "AirPods Pro", "Apple Watch", "iPad Pro", "Gaming Chair"]
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        SearchErrorView(
            error: .networkUnavailable,
            onRetry: {}
        )
        
        Divider()
        
        RateLimitErrorView(
            retryAfter: 30,
            onRetry: {}
        )
    }
    .padding()
}

