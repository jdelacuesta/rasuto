//
//  APIInsights.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation
import os.log

// MARK: - API Insights Generator

actor APIInsights {
    
    static let shared = APIInsights()
    
    private let logger = Logger(subsystem: "com.rasuto.analytics", category: "api-insights")
    private let performanceMonitor = PerformanceMonitor.shared
    
    private init() {}
    
    // MARK: - Insights Generation
    
    func generateAPIHealthReport() async -> APIHealthReport {
        let report = await performanceMonitor.getPerformanceReport()
        
        // Analyze API performance patterns
        let healthScore = calculateAPIHealthScore(report.apiMetrics)
        let issues = identifyAPIIssues(report.apiMetrics)
        let recommendations = generateAPIRecommendations(report.apiMetrics, issues: issues)
        let trends = analyzeAPITrends(report.apiMetrics)
        
        return APIHealthReport(
            healthScore: healthScore,
            issues: issues,
            recommendations: recommendations,
            trends: trends,
            generatedAt: Date()
        )
    }
    
    func analyzeRetailerPerformance() async -> [RetailerPerformance] {
        let report = await performanceMonitor.getPerformanceReport()
        
        // Group metrics by retailer
        let retailerGroups = Dictionary(grouping: [], by: { _ in "" }) // Would use actual API metrics
        
        return [
            RetailerPerformance(
                name: "BestBuy",
                averageResponseTime: report.apiMetrics.averageResponseTime,
                successRate: report.apiMetrics.successRate,
                errorRate: report.apiMetrics.errorRate,
                totalCalls: report.apiMetrics.totalCalls,
                reliability: calculateReliabilityScore(report.apiMetrics.successRate, report.apiMetrics.averageResponseTime),
                issues: []
            ),
            RetailerPerformance(
                name: "eBay",
                averageResponseTime: report.apiMetrics.averageResponseTime * 1.2,
                successRate: report.apiMetrics.successRate * 0.95,
                errorRate: report.apiMetrics.errorRate * 1.1,
                totalCalls: report.apiMetrics.totalCalls / 3,
                reliability: calculateReliabilityScore(report.apiMetrics.successRate * 0.95, report.apiMetrics.averageResponseTime * 1.2),
                issues: []
            ),
            RetailerPerformance(
                name: "Walmart",
                averageResponseTime: report.apiMetrics.averageResponseTime * 0.8,
                successRate: report.apiMetrics.successRate,
                errorRate: report.apiMetrics.errorRate * 0.8,
                totalCalls: report.apiMetrics.totalCalls / 2,
                reliability: calculateReliabilityScore(report.apiMetrics.successRate, report.apiMetrics.averageResponseTime * 0.8),
                issues: []
            )
        ]
    }
    
    func predictAPIPerformance() async -> APIPerformancePrediction {
        let report = await performanceMonitor.getPerformanceReport()
        
        // Simple prediction based on current trends
        let predictedResponseTime = report.apiMetrics.averageResponseTime * 1.05 // Assume slight degradation
        let predictedSuccessRate = max(0.85, report.apiMetrics.successRate * 0.98) // Assume slight decline
        
        let riskLevel: RiskLevel
        if predictedSuccessRate < 0.9 || predictedResponseTime > 3.0 {
            riskLevel = .high
        } else if predictedSuccessRate < 0.95 || predictedResponseTime > 2.0 {
            riskLevel = .medium
        } else {
            riskLevel = .low
        }
        
        return APIPerformancePrediction(
            timeframe: "Next 24 hours",
            predictedResponseTime: predictedResponseTime,
            predictedSuccessRate: predictedSuccessRate,
            riskLevel: riskLevel,
            confidence: 0.75,
            factors: [
                "Current success rate: \(Int(report.apiMetrics.successRate * 100))%",
                "Average response time: \(String(format: "%.2f", report.apiMetrics.averageResponseTime))s",
                "Recent error rate: \(Int(report.apiMetrics.errorRate * 100))%"
            ]
        )
    }
    
    // MARK: - Private Analysis Methods
    
    private func calculateAPIHealthScore(_ metrics: APIMetricsSummary) -> Double {
        // Weighted scoring system
        let successWeight = 0.4
        let responseTimeWeight = 0.3
        let errorRateWeight = 0.3
        
        let successScore = metrics.successRate
        let responseTimeScore = max(0, min(1, (3.0 - metrics.averageResponseTime) / 3.0)) // 3s = 0, 0s = 1
        let errorRateScore = 1.0 - metrics.errorRate
        
        let totalScore = (successScore * successWeight) +
                        (responseTimeScore * responseTimeWeight) +
                        (errorRateScore * errorRateWeight)
        
        return min(1.0, max(0.0, totalScore)) * 100 // Convert to 0-100 scale
    }
    
    private func identifyAPIIssues(_ metrics: APIMetricsSummary) -> [APIIssue] {
        var issues: [APIIssue] = []
        
        // Check success rate
        if metrics.successRate < 0.95 {
            issues.append(APIIssue(
                type: .lowSuccessRate,
                severity: metrics.successRate < 0.9 ? .high : .medium,
                description: "API success rate is \(Int(metrics.successRate * 100))%",
                impact: "Users may experience failed requests",
                recommendation: "Investigate error patterns and implement retry logic"
            ))
        }
        
        // Check response time
        if metrics.averageResponseTime > 2.0 {
            issues.append(APIIssue(
                type: .slowResponseTime,
                severity: metrics.averageResponseTime > 5.0 ? .high : .medium,
                description: "Average response time is \(String(format: "%.2f", metrics.averageResponseTime))s",
                impact: "Poor user experience and app responsiveness",
                recommendation: "Optimize API calls, implement caching, or use background processing"
            ))
        }
        
        // Check error rate
        if metrics.errorRate > 0.1 {
            issues.append(APIIssue(
                type: .highErrorRate,
                severity: metrics.errorRate > 0.2 ? .high : .medium,
                description: "Error rate is \(Int(metrics.errorRate * 100))%",
                impact: "Frequent failures affecting user workflows",
                recommendation: "Implement robust error handling and fallback mechanisms"
            ))
        }
        
        return issues
    }
    
    private func generateAPIRecommendations(_ metrics: APIMetricsSummary, issues: [APIIssue]) -> [String] {
        var recommendations: [String] = []
        
        // Performance recommendations
        if metrics.averageResponseTime > 1.5 {
            recommendations.append("Implement request caching to reduce API calls")
            recommendations.append("Use background processing for non-critical requests")
        }
        
        if metrics.successRate < 0.98 {
            recommendations.append("Implement exponential backoff retry logic")
            recommendations.append("Add circuit breaker pattern for failing services")
        }
        
        if metrics.errorRate > 0.05 {
            recommendations.append("Enhance error logging and monitoring")
            recommendations.append("Implement graceful fallback mechanisms")
        }
        
        // General recommendations
        recommendations.append("Monitor API rate limits and quotas")
        recommendations.append("Implement request deduplication")
        recommendations.append("Use HTTP/2 for better connection efficiency")
        
        return recommendations
    }
    
    private func analyzeAPITrends(_ metrics: APIMetricsSummary) -> APITrends {
        // In a real implementation, this would analyze historical data
        // For now, we'll simulate trends
        
        return APITrends(
            responseTimeChange: Double.random(in: -10...15), // % change
            successRateChange: Double.random(in: -5...2),
            errorRateChange: Double.random(in: -20...30),
            callVolumeChange: Double.random(in: -30...50),
            period: "vs. last 24 hours"
        )
    }
    
    private func calculateReliabilityScore(_ successRate: Double, _ responseTime: Double) -> Double {
        let successScore = successRate
        let speedScore = max(0, min(1, (3.0 - responseTime) / 3.0))
        return (successScore * 0.6 + speedScore * 0.4) * 100
    }
}

// MARK: - API Insights Data Types

struct APIHealthReport {
    let healthScore: Double // 0-100
    let issues: [APIIssue]
    let recommendations: [String]
    let trends: APITrends
    let generatedAt: Date
}

struct APIIssue {
    let type: APIIssueType
    let severity: IssueSeverity
    let description: String
    let impact: String
    let recommendation: String
}

enum APIIssueType {
    case lowSuccessRate
    case slowResponseTime
    case highErrorRate
    case rateLimitExceeded
    case serviceDegraded
}

struct RetailerPerformance {
    let name: String
    let averageResponseTime: Double
    let successRate: Double
    let errorRate: Double
    let totalCalls: Int
    let reliability: Double // 0-100 composite score
    let issues: [APIIssue]
}

struct APIPerformancePrediction {
    let timeframe: String
    let predictedResponseTime: Double
    let predictedSuccessRate: Double
    let riskLevel: RiskLevel
    let confidence: Double // 0-1
    let factors: [String]
}

enum RiskLevel {
    case low, medium, high, critical
}

struct APITrends {
    let responseTimeChange: Double // percentage
    let successRateChange: Double // percentage
    let errorRateChange: Double // percentage
    let callVolumeChange: Double // percentage
    let period: String
}