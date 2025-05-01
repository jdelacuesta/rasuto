//
//  NotificationsView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

struct AlertsView: View {
    @ObservedObject var notificationManager: EbayNotificationManager
    @State private var showUnreadOnly = false
    
    var filteredAlerts: [Alert] {
        if showUnreadOnly {
            return notificationManager.alerts.filter { !$0.isRead }
        } else {
            return notificationManager.alerts
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if notificationManager.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if filteredAlerts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                        
                        Text("No Alerts")
                            .font(.headline)
                        
                        Text("You don't have any\(showUnreadOnly ? " unread" : "") alerts at the moment.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    Section(header: Text("Alerts")) {
                        ForEach(filteredAlerts.sorted(by: { $0.date > $1.date })) { alert in
                            AlertRow(alert: alert, notificationManager: notificationManager)
                        }
                    }
                }
            }
            .refreshable {
                Task {
                    await notificationManager.refreshTrackedItems()
                }
            }
            .navigationTitle("Alerts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await notificationManager.refreshTrackedItems()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(notificationManager.isLoading)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Toggle(isOn: $showUnreadOnly) {
                        Image(systemName: showUnreadOnly ? "eye" : "eye.fill")
                    }
                    .toggleStyle(.button)
                }
            }
        }
    }
}

struct AlertRow: View {
    let alert: Alert
    @ObservedObject var notificationManager: EbayNotificationManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Alert icon based on type
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.productName)
                        .font(.headline)
                        .foregroundColor(alert.isRead ? .secondary : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(timeAgo(from: alert.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Additional info based on alert type
                if let auctionEndTime = alert.auctionEndTime {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        
                        Text("Ends \(formatDate(auctionEndTime))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 2)
                }
                
                if let currentBid = alert.currentBid {
                    Text("Current price: $\(String(format: "%.2f", currentBid))")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            
            if !alert.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !alert.isRead {
                notificationManager.markAsRead(alert.id)
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                notificationManager.clearAlert(alert.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            if alert.isRead {
                Button {
                    // Toggle read status by creating a new alert with isRead = false
                    let unreadAlert = Alert(
                        id: alert.id,
                        productId: alert.productId,
                        productName: alert.productName,
                        source: alert.source,
                        alertType: alert.alertType,
                        date: alert.date,
                        message: alert.message,
                        thumbnailUrl: alert.thumbnailUrl,
                        isRead: false,
                        auctionEndTime: alert.auctionEndTime,
                        currentBid: alert.currentBid
                    )
                    notificationManager.addAlert(unreadAlert)
                } label: {
                    Label("Mark Unread", systemImage: "envelope.badge")
                }
                .tint(.blue)
            } else {
                Button {
                    notificationManager.markAsRead(alert.id)
                } label: {
                    Label("Mark Read", systemImage: "envelope.open")
                }
                .tint(.green)
            }
        }
    }
    
    // Helper properties for alert styling
    private var iconName: String {
        switch alert.alertType {
        case .priceChange:
            return "tag"
        case .auctionEnding:
            return "clock"
        case .itemSold:
            return "cart"
        case .inventoryChange:
            return "box.truck"
        }
    }
    
    private var iconBackgroundColor: Color {
        switch alert.alertType {
        case .priceChange:
            return .green
        case .auctionEnding:
            return .orange
        case .itemSold:
            return .red
        case .inventoryChange:
            return .blue
        }
    }
    
    // Helper for time formatting
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper for date formatting
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AlertsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockEbayAPIService()
        let notificationManager = EbayNotificationManager(ebayService: mockService)
        
        // Add some sample alerts for preview
        let sampleAlerts = [
            Alert(
                productId: "123456789",
                productName: "Vintage Camera",
                source: "eBay",
                alertType: .priceChange,
                date: Date(),
                message: "Price dropped by 20% from $49.99 to $39.99",
                thumbnailUrl: URL(string: "https://example.com/thumbnail.jpg"),
                isRead: false,
                auctionEndTime: nil,
                currentBid: 39.99
            ),
            Alert(
                productId: "555555555",
                productName: "Collectible Action Figure",
                source: "eBay",
                alertType: .auctionEnding,
                date: Date().addingTimeInterval(-1800), // 30 minutes ago
                message: "Auction ending soon!",
                thumbnailUrl: URL(string: "https://example.com/figure.jpg"),
                isRead: true,
                auctionEndTime: Date().addingTimeInterval(1800), // 30 minutes from now
                currentBid: 175.50
            ),
            Alert(
                productId: "987654321",
                productName: "Limited Edition Book",
                source: "eBay",
                alertType: .inventoryChange,
                date: Date().addingTimeInterval(-3600), // 1 hour ago
                message: "Only 2 left in stock!",
                thumbnailUrl: URL(string: "https://example.com/book.jpg"),
                isRead: false,
                auctionEndTime: nil,
                currentBid: nil
            )
        ]
        
        // Add the sample alerts to the notification manager
        for alert in sampleAlerts {
            notificationManager.addAlert(alert)
        }
        
        return AlertsView(notificationManager: notificationManager)
    }
}
