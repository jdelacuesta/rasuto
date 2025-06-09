//
//  PriceDrops.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

struct PriceDropsSection: View {
    // @EnvironmentObject private var notificationManager: EbayNotificationManager // Disabled due to sandbox OAuth issues
    @State private var animateItems = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Price Drops")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: TrackingView()) {
                    Text("See All")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                let alerts: [NotificationAlert] = [] // Empty since EbayNotificationManager is disabled
                
                if alerts.isEmpty {
                    EmptyPriceDropView()
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateItems)
                } else {
                    ForEach(Array(alerts.prefix(2).enumerated()), id: \.element.id) { index, alert in
                        PriceDropItem(alert: alert) // Ensure alert type matches expected input
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateItems)
                            .onTapGesture {
                                // notificationManager.markAsRead(alert.id) // Disabled
                            }
                    }
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

struct EmptyPriceDropView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Implement a simple animation to replace Lottie
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 80, height: 80)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                
                Image(systemName: "tag.slash")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
            }
            .onAppear {
                isAnimating = true
            }
            
            Text("No deals available")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Check back later for live deals")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PriceDropItem: View {
    let alert: NotificationAlert
    @State private var showingDiscount = false
    
    var body: some View {
        HStack {
            // Product thumbnail
            if let thumbnailUrl = alert.thumbnailUrl, let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                }
                .frame(width: 70, height: 70)
                .cornerRadius(10)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "tag")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(alert.productName)
                    .font(.headline)
                    .lineLimit(1)
                
                // Animated price drop
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(getPreviousPrice(from: alert.message))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .strikethrough()
                    
                    Text(getCurrentPrice(from: alert.message))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                    
                    // Discount percentage
                    Text(getDiscountPercentage(from: alert.message))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                        .opacity(showingDiscount ? 1 : 0)
                        .offset(x: showingDiscount ? 0 : 10)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.3), value: showingDiscount)
                        .onAppear {
                            showingDiscount = true
                        }
                }
                
                // Source label (eBay, Best Buy, etc.)
                HStack {
                    Text(RetailerType.displayName(for: alert.source))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor(alert.source).opacity(0.2))
                        .foregroundColor(sourceColor(alert.source))
                        .cornerRadius(4)
                    
                    Text(timeAgoString(from: alert.date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func sourceColor(_ source: String) -> Color {
        switch source.lowercased() {
        case "ebay": return .blue
        case "best buy": return .yellow
        case "walmart": return .blue
        default: return .gray
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
    
    // Helper functions to extract price information
    private func getPreviousPrice(from message: String) -> String {
        // Mock implementation - in a real app, you would parse the message
        return "$299.99"
    }
    
    private func getCurrentPrice(from message: String) -> String {
        // Mock implementation - in a real app, you would parse the message
        return "$249.99"
    }
    
    private func getDiscountPercentage(from message: String) -> String {
        // Mock implementation - in a real app, you would parse the message
        return "-17%"
    }
}

#Preview {
    // let ebayService = EbayAPIService(apiKey: "test_key")
    // let notificationManager = EbayNotificationManager(ebayService: ebayService)
    
    // Add mock data for the preview
    // notificationManager.addMockAlerts()
    
    return VStack {
        PriceDropsSection()
            // .environmentObject(notificationManager) // Commented out - EbayNotificationManager disabled
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
