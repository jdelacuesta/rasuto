//
//  AnalyticsDashboard.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import SwiftUI
import Charts

// MARK: - Analytics Dashboard View

struct AnalyticsDashboard: View {
    
    @StateObject private var userAnalytics = UserAnalytics.shared
    @State private var performanceReport: PerformanceReport?
    @State private var userInsights: UserBehaviorInsights?
    @State private var isLoading = true
    @State private var selectedTimeframe: Timeframe = .last24Hours
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    
                    // Header
                    headerSection
                    
                    // Performance Overview
                    if let report = performanceReport {
                        performanceOverviewSection(report)
                    }
                    
                    // User Behavior Insights
                    if let insights = userInsights {
                        userBehaviorSection(insights)
                    }
                    
                    // API Performance Charts
                    if let report = performanceReport {
                        apiPerformanceSection(report)
                    }
                    
                    // Memory Usage
                    if let report = performanceReport {
                        memoryUsageSection(report)
                    }
                    
                    // Session Information
                    sessionInfoSection
                    
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
        }
        .task {
            await loadAnalyticsData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Performance Dashboard")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.displayName).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading analytics data...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Performance Overview
    
    private func performanceOverviewSection(_ report: PerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Performance Overview", icon: "speedometer")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                
                MetricCard(
                    title: "API Success Rate",
                    value: "\(Int(report.apiMetrics.successRate * 100))%",
                    subtitle: "\(report.apiMetrics.totalCalls) calls",
                    color: report.apiMetrics.successRate > 0.95 ? .green : .orange,
                    icon: "checkmark.circle"
                )
                
                MetricCard(
                    title: "Avg Response Time",
                    value: "\(String(format: "%.2f", report.apiMetrics.averageResponseTime))s",
                    subtitle: "Last 24 hours",
                    color: report.apiMetrics.averageResponseTime < 2.0 ? .green : .red,
                    icon: "timer"
                )
                
                MetricCard(
                    title: "Memory Usage",
                    value: "\(Int(report.memoryMetrics.averageUsageMB))MB",
                    subtitle: "Peak: \(Int(report.memoryMetrics.peakUsageMB))MB",
                    color: report.memoryMetrics.averagePressure < 0.7 ? .green : .orange,
                    icon: "memorychip"
                )
            }
        }
    }
    
    // MARK: - User Behavior Section
    
    private func userBehaviorSection(_ insights: UserBehaviorInsights) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "User Behavior", icon: "person.3")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                
                MetricCard(
                    title: "Engagement Level",
                    value: insights.engagementLevel.displayName,
                    subtitle: "Current session",
                    color: insights.engagementLevel.color,
                    icon: "heart.fill"
                )
                
                MetricCard(
                    title: "Search Success",
                    value: "\(Int(insights.searchEffectiveness * 100))%",
                    subtitle: "Queries with results",
                    color: insights.searchEffectiveness > 0.8 ? .green : .orange,
                    icon: "magnifyingglass"
                )
            }
            
            // Conversion Funnel
            VStack(alignment: .leading, spacing: 8) {
                Text("Conversion Funnel")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    FunnelStep(
                        title: "Searches",
                        value: insights.conversionFunnel.searches,
                        isFirst: true
                    )
                    
                    FunnelArrow()
                    
                    FunnelStep(
                        title: "Product Views",
                        value: insights.conversionFunnel.productViews,
                        rate: insights.conversionFunnel.searchToViewRate
                    )
                    
                    FunnelArrow()
                    
                    FunnelStep(
                        title: "Wishlist Adds",
                        value: insights.conversionFunnel.wishlistAdds,
                        rate: insights.conversionFunnel.viewToWishlistRate
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    // MARK: - API Performance Section
    
    private func apiPerformanceSection(_ report: PerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "API Performance", icon: "network")
            
            if let slowestCall = report.apiMetrics.slowestCall {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Slowest API Call")
                            .font(.headline)
                        Text("\(slowestCall.service)/\(slowestCall.endpoint)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(String(format: "%.2f", slowestCall.duration))s")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
    }
    
    // MARK: - Memory Usage Section
    
    private func memoryUsageSection(_ report: PerformanceReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Memory Usage", icon: "memorychip")
            
            VStack(spacing: 12) {
                ProgressView(
                    "Memory Pressure",
                    value: report.memoryMetrics.averagePressure,
                    total: 1.0
                )
                .progressViewStyle(LinearProgressViewStyle(tint: memoryPressureColor(report.memoryMetrics.averagePressure)))
                
                HStack {
                    Text("Average: \(Int(report.memoryMetrics.averageUsageMB))MB")
                    Spacer()
                    Text("Peak: \(Int(report.memoryMetrics.peakUsageMB))MB")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    // MARK: - Session Info Section
    
    private var sessionInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Current Session", icon: "clock")
            
            let summary = userAnalytics.getSessionSummary()
            
            VStack(spacing: 12) {
                HStack {
                    Text("Session Duration")
                    Spacer()
                    Text(formatDuration(summary.duration))
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Screen Views")
                    Spacer()
                    Text("\(summary.screenCount)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("User Actions")
                    Spacer()
                    Text("\(summary.actionCount)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Search Queries")
                    Spacer()
                    Text("\(summary.searchCount)")
                        .fontWeight(.medium)
                }
                
                if let mostUsed = summary.mostUsedAction {
                    HStack {
                        Text("Most Used Feature")
                        Spacer()
                        Text(mostUsed.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    // MARK: - Refresh Button
    
    private var refreshButton: some View {
        Button {
            Task {
                await loadAnalyticsData()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAnalyticsData() async {
        isLoading = true
        
        do {
            async let performance = PerformanceMonitor.shared.getPerformanceReport()
            let insights = userAnalytics.getUserBehaviorInsights()
            
            performanceReport = await performance
            userInsights = insights
            
        } catch {
            print("Failed to load analytics data: \(error)")
        }
        
        isLoading = false
    }
    
    private func memoryPressureColor(_ pressure: Double) -> Color {
        switch pressure {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct FunnelStep: View {
    let title: String
    let value: Int
    let rate: Double?
    let isFirst: Bool
    
    init(title: String, value: Int, rate: Double? = nil, isFirst: Bool = false) {
        self.title = title
        self.value = value
        self.rate = rate
        self.isFirst = isFirst
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            if let rate = rate, !isFirst {
                Text("\(Int(rate * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FunnelArrow: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .foregroundColor(.secondary)
            .font(.caption)
    }
}

// MARK: - Supporting Types

enum Timeframe: CaseIterable {
    case lastHour
    case last24Hours
    case lastWeek
    case lastMonth
    
    var displayName: String {
        switch self {
        case .lastHour: return "1h"
        case .last24Hours: return "24h"
        case .lastWeek: return "7d"
        case .lastMonth: return "30d"
        }
    }
}

extension EngagementLevel {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        case .veryHigh: return .blue
        }
    }
}
