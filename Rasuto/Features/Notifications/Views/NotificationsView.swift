//
//  NotificationsView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

enum AlertType {
    case priceDropped
    case endingSoon
    case itemSold
    case backInStock
}

struct NotificationsView: View {
    @EnvironmentObject private var notificationManager: EbayNotificationManager

    var body: some View {
        NavigationStack {
            VStack {
                content
            }
            .navigationTitle("Alerts")
            .overlay(
                notificationManager.isLoading ?
                ProgressView("Refreshing...")
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(10)
                    .padding()
                : nil
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if notificationManager.alerts.isEmpty {
            EmptyStateView()
        } else {
            AlertListView(alerts: notificationManager.alerts)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Alerts")
                .font(Theme.Typography.titleFont)
            
            Text("You'll see your alerts and notifications here")
                .font(Theme.Typography.bodyFont)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct AlertListView: View {
    let alerts: [NotificationAlert]
    @EnvironmentObject private var notificationManager: EbayNotificationManager

    var body: some View {
        List {
            ForEach(alerts) { alert in
                AlertRow(alert: alert)
                    .onTapGesture {
                        notificationManager.markAsRead(alert.id)
                    }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            Task {
                await notificationManager.refreshTrackedItems()
            }
        }
    }
}

struct AlertRow: View {
    let alert: NotificationAlert

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .cornerRadius(8)

                let label = labelForAlertType(alert.alertType)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(backgroundColorForAlertType(alert.alertType))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(4)

                if let thumbnailUrl = alert.thumbnailUrl {
                    AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Color.gray
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 70, height: 70)
                    .cornerRadius(8)
                    .clipped()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.productName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                if let currentBid = alert.currentBid {
                    if (alert.alertType == .priceDropped || alert.alertType == .priceChange),
                       let originalPrice = getOriginalPriceFromMessage(alert.message) {
                        HStack(spacing: 6) {
                            Text("$\(String(format: "%.2f", currentBid))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)

                            Text("$\(String(format: "%.2f", originalPrice))")
                                .font(.caption)
                                .strikethrough()
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("$\(String(format: "%.2f", currentBid))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    Text(alert.source)
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(timeAgoString(from: alert.date))
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    if alert.alertType == .endingSoon, let endTime = alert.auctionEndTime {
                        Text(timeRemainingString(from: endTime))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .background(Color(.systemBackground))
        .opacity(alert.isRead ? 0.7 : 1.0)
    }

    private func getOriginalPriceFromMessage(_ message: String) -> Double? {
        let components = message.components(separatedBy: "from $")
        if components.count > 1 {
            let priceString = components[1].components(separatedBy: " to $").first
            return Double(priceString ?? "0")
        }
        return nil
    }

    func labelForAlertType(_ type: NotificationAlertType) -> String {
        switch type {
        case .priceDropped:
            return "Price Drop"
        case .priceChange:
            return "Price Change"
        case .endingSoon:
            return "Ending Soon"
        case .backInStock:
            return "Back In Stock"
        case .itemSold:
            return "Item Sold"
        }
    }

    func backgroundColorForAlertType(_ type: NotificationAlertType) -> Color {
        switch type {
        case .priceDropped:
            return .red
        case .priceChange:
            return .blue
        case .endingSoon:
            return .orange
        case .backInStock:
            return .green
        case .itemSold:
            return .gray
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

    private func timeRemainingString(from endTime: Date) -> String {
        let timeInterval = Date().distance(to: endTime)
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}

extension NotificationType {
    var toAlertType: NotificationType {
        switch self {
        case .priceDropped, .priceChange:
            return .priceDropped
        case .endingSoon, .auctionEnding:
            return .endingSoon
        case .itemSold:
            return .itemSold
        case .backInStock, .inventoryChange:
            return .backInStock
        }
    }
}

#Preview {
    NavigationView {
        let ebayService = EbayAPIService(apiKey: "test_key")
        let notificationManager = EbayNotificationManager(ebayService: ebayService)
        notificationManager.addMockAlerts()

        return NotificationsView()
            .environmentObject(notificationManager)
    }
}
