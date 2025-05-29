//
//  UserAnalytics.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftUI
import os.log

// MARK: - User Analytics Manager

@MainActor
class UserAnalytics: ObservableObject {
    
    static let shared = UserAnalytics()
    
    // MARK: - Properties
    
    @Published private(set) var isTrackingEnabled = true
    @Published private(set) var sessionMetrics: SessionMetrics
    
    private let sessionId = UUID().uuidString
    private let sessionStartTime = Date()
    private let logger = Logger(subsystem: "com.rasuto.analytics", category: "user")
    private let performanceMonitor = PerformanceMonitor.shared
    
    // MARK: - Initialization
    
    private init() {
        self.sessionMetrics = SessionMetrics(
            sessionId: self.sessionId,
            startTime: self.sessionStartTime,
            screenViews: [],
            actions: [],
            searchQueries: []
        )
        
        logger.info("📱 User analytics session started: \(self.sessionId)")
    }
    
    // MARK: - Event Tracking
    
    func track(_ action: UserAction, on screen: Screen, properties: [String: Any] = [:]) {
        guard isTrackingEnabled else { return }
        
        let event = AnalyticsEvent(
            timestamp: Date(),
            action: action,
            screen: screen,
            properties: properties,
            sessionId: self.sessionId,
            userId: nil // Could be set if user is logged in
        )
        
        // Update session metrics
        sessionMetrics.actions.append(event)
        
        // Track with performance monitor
        Task {
            await performanceMonitor.trackUserInteraction(
                action: action.rawValue,
                screen: screen.rawValue,
                element: properties["element"] as? String,
                metadata: properties
            )
        }
        
        logger.info("📊 User action: \(action.rawValue) on \(screen.rawValue)")
        
        // Special handling for certain actions
        handleSpecialActions(action, screen: screen, properties: properties)
    }
    
    func trackScreenView(_ screen: Screen, properties: [String: Any] = [:]) {
        guard isTrackingEnabled else { return }
        
        let screenView = ScreenView(
            screen: screen,
            timestamp: Date(),
            properties: properties,
            duration: nil // Will be calculated when leaving screen
        )
        
        // End previous screen view
        if var lastScreenView = sessionMetrics.screenViews.last {
            lastScreenView.duration = Date().timeIntervalSince(lastScreenView.timestamp)
            sessionMetrics.screenViews[sessionMetrics.screenViews.count - 1] = lastScreenView
        }
        
        sessionMetrics.screenViews.append(screenView)
        
        logger.info("📱 Screen view: \(screen.rawValue)")
        
        // Track with performance monitor
        Task {
            await performanceMonitor.trackUserInteraction(
                action: "screen_view",
                screen: screen.rawValue,
                metadata: properties
            )
        }
    }
    
    func trackSearch(query: String, resultCount: Int, retailer: String?) {
        guard isTrackingEnabled else { return }
        
        let searchQuery = SearchQuery(
            query: query,
            timestamp: Date(),
            resultCount: resultCount,
            retailer: retailer
        )
        
        sessionMetrics.searchQueries.append(searchQuery)
        
        track(.search, on: .search, properties: [
            "query": query,
            "result_count": resultCount,
            "retailer": retailer ?? "all"
        ])
        
        logger.info("🔍 Search: '\(query)' returned \(resultCount) results")
    }
    
    func trackPurchaseIntent(productId: String, price: Double, retailer: String) {
        track(.viewProduct, on: .productDetail, properties: [
            "product_id": productId,
            "price": price,
            "retailer": retailer,
            "intent": "purchase"
        ])
    }
    
    func trackError(_ error: Error, context: String) {
        logger.error("❌ Error tracked: \(error.localizedDescription) in \(context)")
        
        track(.search, on: .search, properties: [
            "error": error.localizedDescription,
            "context": context,
            "error_type": "user_facing"
        ])
    }
    
    // MARK: - Analytics Insights
    
    func getSessionSummary() -> SessionSummary {
        let now = Date()
        let sessionDuration = now.timeIntervalSince(self.sessionStartTime)
        
        return SessionSummary(
            sessionId: self.sessionId,
            duration: sessionDuration,
            screenCount: sessionMetrics.screenViews.count,
            actionCount: sessionMetrics.actions.count,
            searchCount: sessionMetrics.searchQueries.count,
            mostViewedScreen: findMostViewedScreen(),
            mostUsedAction: findMostUsedAction(),
            averageSearchResults: calculateAverageSearchResults()
        )
    }
    
    func getUserBehaviorInsights() -> UserBehaviorInsights {
        let summary = getSessionSummary()
        
        return UserBehaviorInsights(
            engagementLevel: calculateEngagementLevel(summary),
            searchEffectiveness: calculateSearchEffectiveness(),
            preferredRetailers: findPreferredRetailers(),
            conversionFunnel: analyzeConversionFunnel(),
            sessionQuality: calculateSessionQuality(summary)
        )
    }
    
    // MARK: - Privacy Controls
    
    func enableTracking() {
        isTrackingEnabled = true
        logger.info("✅ User analytics tracking enabled")
    }
    
    func disableTracking() {
        isTrackingEnabled = false
        logger.info("🚫 User analytics tracking disabled")
    }
    
    func clearAnalyticsData() {
        sessionMetrics = SessionMetrics(
            sessionId: UUID().uuidString,
            startTime: Date(),
            screenViews: [],
            actions: [],
            searchQueries: []
        )
        logger.info("🗑️ Analytics data cleared")
    }
    
    // MARK: - Private Helpers
    
    private func handleSpecialActions(_ action: UserAction, screen: Screen, properties: [String: Any]) {
        switch action {
        case .addToWishlist, .removeFromWishlist:
            // Track wishlist engagement
            let productId = properties["product_id"] as? String ?? "unknown"
            logger.info("❤️ Wishlist action: \(action.rawValue) for product \(productId)")
            
        case .priceTrack:
            // Track price tracking usage
            logger.info("💰 Price tracking enabled")
            
        case .shareProduct:
            // Track sharing behavior
            logger.info("📤 Product shared")
            
        default:
            break
        }
    }
    
    private func findMostViewedScreen() -> Screen? {
        let screenCounts = Dictionary(grouping: sessionMetrics.screenViews, by: { $0.screen })
            .mapValues { $0.count }
        
        return screenCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func findMostUsedAction() -> UserAction? {
        let actionCounts = Dictionary(grouping: sessionMetrics.actions, by: { $0.action })
            .mapValues { $0.count }
        
        return actionCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func calculateAverageSearchResults() -> Double {
        guard !sessionMetrics.searchQueries.isEmpty else { return 0.0 }
        
        let totalResults = sessionMetrics.searchQueries.reduce(0) { $0 + $1.resultCount }
        return Double(totalResults) / Double(sessionMetrics.searchQueries.count)
    }
    
    private func calculateEngagementLevel(_ summary: SessionSummary) -> EngagementLevel {
        let engagementScore = Double(summary.actionCount) / max(summary.duration / 60, 1) // actions per minute
        
        switch engagementScore {
        case 0..<1: return .low
        case 1..<3: return .medium
        case 3..<6: return .high
        default: return .veryHigh
        }
    }
    
    private func calculateSearchEffectiveness() -> Double {
        guard !sessionMetrics.searchQueries.isEmpty else { return 1.0 }
        
        let successfulSearches = sessionMetrics.searchQueries.filter { $0.resultCount > 0 }.count
        return Double(successfulSearches) / Double(sessionMetrics.searchQueries.count)
    }
    
    private func findPreferredRetailers() -> [String] {
        let retailerCounts = Dictionary(grouping: sessionMetrics.searchQueries.compactMap { $0.retailer }, by: { $0 })
            .mapValues { $0.count }
        
        return retailerCounts.sorted(by: { $0.value > $1.value }).map { $0.key }
    }
    
    private func analyzeConversionFunnel() -> ConversionFunnel {
        let searches = sessionMetrics.searchQueries.count
        let productViews = sessionMetrics.actions.filter { $0.action == .viewProduct }.count
        let wishlistAdds = sessionMetrics.actions.filter { $0.action == .addToWishlist }.count
        
        return ConversionFunnel(
            searches: searches,
            productViews: productViews,
            wishlistAdds: wishlistAdds,
            searchToViewRate: searches > 0 ? Double(productViews) / Double(searches) : 0,
            viewToWishlistRate: productViews > 0 ? Double(wishlistAdds) / Double(productViews) : 0
        )
    }
    
    private func calculateSessionQuality(_ summary: SessionSummary) -> SessionQuality {
        // Composite score based on various factors
        let durationScore = min(summary.duration / 300, 1.0) // 5 minutes = perfect
        let engagementScore = min(Double(summary.actionCount) / 10, 1.0) // 10 actions = perfect
        let searchScore = min(Double(summary.searchCount) / 3, 1.0) // 3 searches = perfect
        
        let overallScore = (durationScore + engagementScore + searchScore) / 3
        
        switch overallScore {
        case 0..<0.3: return .poor
        case 0.3..<0.6: return .fair
        case 0.6..<0.8: return .good
        default: return .excellent
        }
    }
}

// MARK: - Supporting Types

struct SessionMetrics {
    let sessionId: String
    let startTime: Date
    var screenViews: [ScreenView]
    var actions: [AnalyticsEvent]
    var searchQueries: [SearchQuery]
}

struct ScreenView {
    let screen: Screen
    let timestamp: Date
    let properties: [String: Any]
    var duration: TimeInterval?
}

struct SearchQuery {
    let query: String
    let timestamp: Date
    let resultCount: Int
    let retailer: String?
}

struct SessionSummary {
    let sessionId: String
    let duration: TimeInterval
    let screenCount: Int
    let actionCount: Int
    let searchCount: Int
    let mostViewedScreen: Screen?
    let mostUsedAction: UserAction?
    let averageSearchResults: Double
}

struct UserBehaviorInsights {
    let engagementLevel: EngagementLevel
    let searchEffectiveness: Double
    let preferredRetailers: [String]
    let conversionFunnel: ConversionFunnel
    let sessionQuality: SessionQuality
}

enum EngagementLevel {
    case low, medium, high, veryHigh
}

enum SessionQuality {
    case poor, fair, good, excellent
}

struct ConversionFunnel {
    let searches: Int
    let productViews: Int
    let wishlistAdds: Int
    let searchToViewRate: Double
    let viewToWishlistRate: Double
}