//
//  AnalyticsTypes.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation

// MARK: - Performance Metric Types

struct PerformanceMetric {
    let id: String
    let name: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    var success: Bool = true
    var metadata: [String: Any] = [:]
    let category: MetricCategory
}

enum MetricCategory {
    case operation
    case apiCall
    case userInteraction
    case memory
    case custom
}

struct APICallMetric {
    let timestamp: Date
    let service: String
    let endpoint: String
    let method: String
    let duration: TimeInterval
    let statusCode: Int?
    let responseSize: Int?
    let error: String?
    let success: Bool
}

struct UserInteractionMetric {
    let timestamp: Date
    let action: String
    let screen: String
    let element: String?
    let metadata: [String: Any]
    let sessionDuration: TimeInterval
}

struct MemoryMetric {
    let timestamp: Date
    let usedMemoryMB: Double
    let availableMemoryMB: Double
    let totalMemoryMB: Double
    let memoryPressure: Double
}

// MARK: - Performance Report Types

struct PerformanceReport {
    let generatedAt: Date
    let sessionDuration: TimeInterval
    let apiMetrics: APIMetricsSummary
    let userInteractions: UserInteractionSummary
    let memoryMetrics: MemorySummary
}

struct APIMetricsSummary {
    let totalCalls: Int
    let successRate: Double
    let averageResponseTime: Double
    let slowestCall: APICallMetric?
    let errorRate: Double
}

struct UserInteractionSummary {
    let totalInteractions: Int
    let uniqueScreens: Int
    let mostUsedFeature: String?
    let averageSessionDuration: Double
}

struct MemorySummary {
    let averageUsageMB: Double
    let peakUsageMB: Double
    let averagePressure: Double
}

// MARK: - User Analytics Types

enum UserAction: String, CaseIterable {
    case search = "search"
    case addToWishlist = "add_to_wishlist"
    case removeFromWishlist = "remove_from_wishlist"
    case viewProduct = "view_product"
    case priceTrack = "price_track"
    case shareProduct = "share_product"
    case filterProducts = "filter_products"
    case sortProducts = "sort_products"
    case viewWishlist = "view_wishlist"
    case openAPI = "open_api"
    case switchRetailer = "switch_retailer"
}

enum Screen: String, CaseIterable {
    case home = "home"
    case search = "search"
    case wishlist = "wishlist"
    case productDetail = "product_detail"
    case apiTest = "api_test"
    case settings = "settings"
    case onboarding = "onboarding"
}

// MARK: - Analytics Events

struct AnalyticsEvent {
    let timestamp: Date
    let action: UserAction
    let screen: Screen
    let properties: [String: Any]
    let sessionId: String
    let userId: String?
}

// MARK: - App Performance Insights

struct AppInsights {
    let performanceScore: Double // 0-100
    let topIssues: [PerformanceIssue]
    let recommendations: [String]
    let trends: PerformanceTrends
}

struct PerformanceIssue {
    let type: IssueType
    let severity: IssueSeverity
    let description: String
    let impact: String
    let suggestion: String
}

enum IssueType {
    case slowAPI
    case highMemory
    case frequentErrors
    case poorUserExperience
}

enum IssueSeverity {
    case low
    case medium
    case high
    case critical
}

struct PerformanceTrends {
    let apiResponseTimeChange: Double // percentage change
    let memoryUsageChange: Double
    let errorRateChange: Double
    let userEngagementChange: Double
}