//
//  PerformanceMonitor.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Performance Monitor Actor

actor PerformanceMonitor {
    
    static let shared = PerformanceMonitor()
    
    // MARK: - Performance Metrics
    
    private var metrics: [String: PerformanceMetric] = [:]
    private var sessionStartTime: Date = Date()
    private var apiCallMetrics: [APICallMetric] = []
    private var userInteractionMetrics: [UserInteractionMetric] = []
    private var memoryMetrics: [MemoryMetric] = []
    
    // MARK: - Configuration
    
    private let maxMetricsRetention = 1000
    private let metricsFlushInterval: TimeInterval = 60 // 1 minute
    private let logger = Logger(subsystem: "com.rasuto.analytics", category: "performance")
    
    // MARK: - Initialization
    
    private init() {
        startPerformanceTracking()
    }
    
    // MARK: - Performance Tracking
    
    func startOperation(_ operationName: String) async -> String {
        let operationId = UUID().uuidString
        let metric = PerformanceMetric(
            id: operationId,
            name: operationName,
            startTime: Date(),
            category: .operation
        )
        
        metrics[operationId] = metric
        logger.info("🏁 Started operation: \(operationName) (ID: \(operationId))")
        
        return operationId
    }
    
    func endOperation(_ operationId: String, success: Bool = true, metadata: [String: Any] = [:]) async {
        guard var metric = metrics[operationId] else {
            logger.warning("⚠️ Attempted to end unknown operation: \(operationId)")
            return
        }
        
        metric.endTime = Date()
        metric.duration = metric.endTime!.timeIntervalSince(metric.startTime)
        metric.success = success
        metric.metadata = metadata
        
        metrics[operationId] = metric
        
        logger.info("🏁 Ended operation: \(metric.name) in \(String(format: "%.3f", metric.duration))s (Success: \(success))")
        
        // Store completed metric
        await storeMetric(metric)
    }
    
    // MARK: - API Call Tracking
    
    func trackAPICall(
        service: String,
        endpoint: String,
        method: String = "GET",
        duration: TimeInterval,
        statusCode: Int? = nil,
        responseSize: Int? = nil,
        error: Error? = nil
    ) async {
        
        let metric = APICallMetric(
            timestamp: Date(),
            service: service,
            endpoint: endpoint,
            method: method,
            duration: duration,
            statusCode: statusCode,
            responseSize: responseSize,
            error: error?.localizedDescription,
            success: error == nil && (statusCode ?? 200) < 400
        )
        
        apiCallMetrics.append(metric)
        
        // Maintain retention limit
        if apiCallMetrics.count > maxMetricsRetention {
            apiCallMetrics.removeFirst(apiCallMetrics.count - maxMetricsRetention)
        }
        
        logger.info("📡 API Call: \(service)/\(endpoint) - \(String(format: "%.3f", duration))s (Status: \(statusCode ?? 0))")
        
        // Alert on slow API calls
        if duration > 5.0 {
            logger.warning("🐌 Slow API call detected: \(service)/\(endpoint) took \(String(format: "%.3f", duration))s")
        }
    }
    
    // MARK: - User Interaction Tracking
    
    func trackUserInteraction(
        action: String,
        screen: String,
        element: String? = nil,
        metadata: [String: Any] = [:]
    ) async {
        
        let metric = UserInteractionMetric(
            timestamp: Date(),
            action: action,
            screen: screen,
            element: element,
            metadata: metadata,
            sessionDuration: Date().timeIntervalSince(sessionStartTime)
        )
        
        userInteractionMetrics.append(metric)
        
        // Maintain retention limit
        if userInteractionMetrics.count > maxMetricsRetention {
            userInteractionMetrics.removeFirst(userInteractionMetrics.count - maxMetricsRetention)
        }
        
        logger.info("👆 User interaction: \(action) on \(screen) \(element != nil ? "(\(element!))" : "")")
    }
    
    // MARK: - Memory Tracking
    
    func trackMemoryUsage() async {
        let memoryInfo = getMemoryInfo()
        
        let metric = MemoryMetric(
            timestamp: Date(),
            usedMemoryMB: memoryInfo.used,
            availableMemoryMB: memoryInfo.available,
            totalMemoryMB: memoryInfo.total,
            memoryPressure: memoryInfo.pressure
        )
        
        memoryMetrics.append(metric)
        
        // Maintain retention limit
        if memoryMetrics.count > maxMetricsRetention {
            memoryMetrics.removeFirst(memoryMetrics.count - maxMetricsRetention)
        }
        
        // Alert on high memory usage
        if memoryInfo.pressure > 0.8 {
            logger.warning("🧠 High memory pressure detected: \(String(format: "%.1f", memoryInfo.pressure * 100))%")
        }
    }
    
    // MARK: - Analytics Data Retrieval
    
    func getPerformanceReport() async -> PerformanceReport {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-86400)
        
        // API Metrics Summary
        let recentAPICalls = apiCallMetrics.filter { $0.timestamp >= last24Hours }
        let apiSummary = APIMetricsSummary(
            totalCalls: recentAPICalls.count,
            successRate: calculateSuccessRate(recentAPICalls),
            averageResponseTime: calculateAverageResponseTime(recentAPICalls),
            slowestCall: findSlowestCall(recentAPICalls),
            errorRate: calculateErrorRate(recentAPICalls)
        )
        
        // User Interaction Summary
        let recentInteractions = userInteractionMetrics.filter { $0.timestamp >= last24Hours }
        let interactionSummary = UserInteractionSummary(
            totalInteractions: recentInteractions.count,
            uniqueScreens: Set(recentInteractions.map { $0.screen }).count,
            mostUsedFeature: findMostUsedFeature(recentInteractions),
            averageSessionDuration: calculateAverageSessionDuration(recentInteractions)
        )
        
        // Memory Summary
        let recentMemory = memoryMetrics.filter { $0.timestamp >= last24Hours }
        let memorySummary = MemorySummary(
            averageUsageMB: calculateAverageMemoryUsage(recentMemory),
            peakUsageMB: findPeakMemoryUsage(recentMemory),
            averagePressure: calculateAverageMemoryPressure(recentMemory)
        )
        
        return PerformanceReport(
            generatedAt: now,
            sessionDuration: now.timeIntervalSince(sessionStartTime),
            apiMetrics: apiSummary,
            userInteractions: interactionSummary,
            memoryMetrics: memorySummary
        )
    }
    
    // MARK: - Private Helpers
    
    private func startPerformanceTracking() {
        // Start periodic memory tracking
        Task {
            while true {
                await trackMemoryUsage()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
        
        // Start periodic metrics flush
        Task {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(metricsFlushInterval * 1_000_000_000))
                await flushMetrics()
            }
        }
    }
    
    private func storeMetric(_ metric: PerformanceMetric) async {
        // In a real implementation, you might store this to Core Data or send to analytics service
        logger.debug("💾 Stored performance metric: \(metric.name)")
    }
    
    private func flushMetrics() async {
        logger.info("🔄 Flushing metrics - API: \(self.apiCallMetrics.count), Interactions: \(self.userInteractionMetrics.count), Memory: \(self.memoryMetrics.count)")
        
        // In a real implementation, you might batch send to analytics service
        // For now, we just log the summary
        let report = await getPerformanceReport()
        logger.info("📊 Performance Summary - API Success: \(String(format: "%.1f", report.apiMetrics.successRate * 100))%, Avg Response: \(String(format: "%.3f", report.apiMetrics.averageResponseTime))s")
    }
    
    private func getMemoryInfo() -> (used: Double, available: Double, total: Double, pressure: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let usedMB = result == KERN_SUCCESS ? Double(info.resident_size) / 1024 / 1024 : 0
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
        let availableMB = totalMB - usedMB
        let pressure = usedMB / totalMB
        
        return (used: usedMB, available: availableMB, total: totalMB, pressure: pressure)
    }
    
    // MARK: - Analytics Calculations
    
    private func calculateSuccessRate(_ calls: [APICallMetric]) -> Double {
        guard !calls.isEmpty else { return 1.0 }
        let successCount = calls.filter { $0.success }.count
        return Double(successCount) / Double(calls.count)
    }
    
    private func calculateAverageResponseTime(_ calls: [APICallMetric]) -> Double {
        guard !calls.isEmpty else { return 0.0 }
        let totalTime = calls.reduce(0) { $0 + $1.duration }
        return totalTime / Double(calls.count)
    }
    
    private func findSlowestCall(_ calls: [APICallMetric]) -> APICallMetric? {
        return calls.max(by: { $0.duration < $1.duration })
    }
    
    private func calculateErrorRate(_ calls: [APICallMetric]) -> Double {
        guard !calls.isEmpty else { return 0.0 }
        let errorCount = calls.filter { !$0.success }.count
        return Double(errorCount) / Double(calls.count)
    }
    
    private func findMostUsedFeature(_ interactions: [UserInteractionMetric]) -> String? {
        let actionCounts = Dictionary(grouping: interactions, by: { $0.action })
            .mapValues { $0.count }
        
        return actionCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func calculateAverageSessionDuration(_ interactions: [UserInteractionMetric]) -> Double {
        guard !interactions.isEmpty else { return 0.0 }
        let totalDuration = interactions.reduce(0) { $0 + $1.sessionDuration }
        return totalDuration / Double(interactions.count)
    }
    
    private func calculateAverageMemoryUsage(_ metrics: [MemoryMetric]) -> Double {
        guard !metrics.isEmpty else { return 0.0 }
        let totalUsage = metrics.reduce(0) { $0 + $1.usedMemoryMB }
        return totalUsage / Double(metrics.count)
    }
    
    private func findPeakMemoryUsage(_ metrics: [MemoryMetric]) -> Double {
        return metrics.max(by: { $0.usedMemoryMB < $1.usedMemoryMB })?.usedMemoryMB ?? 0.0
    }
    
    private func calculateAverageMemoryPressure(_ metrics: [MemoryMetric]) -> Double {
        guard !metrics.isEmpty else { return 0.0 }
        let totalPressure = metrics.reduce(0) { $0 + $1.memoryPressure }
        return totalPressure / Double(metrics.count)
    }
}
