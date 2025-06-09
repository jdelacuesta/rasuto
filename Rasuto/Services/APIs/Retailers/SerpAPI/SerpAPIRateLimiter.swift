//
//  SerpAPIRateLimiter.swift
//  Rasuto
//
//  Created for SerpAPI integration on 6/2/25.
//

import Foundation

// MARK: - SerpAPI Rate Limiter

actor SerpAPIRateLimiter {
    
    // MARK: - Rate Limiting Configuration
    
    private var requestCount = 0
    private var lastResetDate = Date()
    private let monthlyLimit: Int
    private let minimumInterval: TimeInterval = 5.0 // EMERGENCY: 5 seconds between requests (was 0.5)
    private var lastRequestTime: Date?
    
    // MARK: - Integration with Global Rate Limiter
    
    private let globalRateLimiter = GlobalRateLimiter.shared
    private let useGlobalRateLimiter = true // Feature flag for integration
    private let serviceName = "serpapi"
    
    // MARK: - Request Tracking
    
    private var requestHistory: [Date] = []
    private let historyRetentionDays = 30
    
    // MARK: - Initialization
    
    init(monthlyLimit: Int = 5000) { // Actual plan: 5k searches/month
        self.monthlyLimit = monthlyLimit
        loadPersistedState()
    }
    
    // MARK: - Rate Limit Checking
    
    func canMakeRequest() async -> Bool {
        let now = Date()
        
        // Check minimum interval between requests
        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = now.timeIntervalSince(lastTime)
            if timeSinceLastRequest < minimumInterval {
                print("⏱️ SerpAPI: Rate limit - too soon since last request (\(String(format: "%.1f", timeSinceLastRequest))s)")
                return false
            }
        }
        
        // Check monthly limit
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, equalTo: now, toGranularity: .month) {
            await resetMonthlyCounter()
        }
        
        if requestCount >= monthlyLimit {
            print("📊 SerpAPI: Monthly limit reached (\(requestCount)/\(monthlyLimit))")
            return false
        }
        
        // Check global rate limiter if enabled
        if useGlobalRateLimiter {
            do {
                try await globalRateLimiter.checkAndConsume(
                    service: serviceName,
                    priority: .normal
                )
            } catch {
                print("🚫 SerpAPI: Global rate limiter blocked request - \(error)")
                return false
            }
        }
        
        return true
    }
    
    func recordRequest() async {
        let now = Date()
        
        // Update counters
        requestCount += 1
        lastRequestTime = now
        
        // Add to history
        requestHistory.append(now)
        
        // Clean old history
        await cleanupRequestHistory()
        
        // Persist state
        await persistState()
        
        print("📊 SerpAPI Request \(requestCount)/\(monthlyLimit) - \(getRemainingQuota()) remaining")
    }
    
    // MARK: - Quota Management
    
    func getRemainingQuota() -> Int {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, equalTo: Date(), toGranularity: .month) {
            return monthlyLimit
        }
        return max(0, monthlyLimit - requestCount)
    }
    
    func getQuotaResetDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: lastResetDate) {
            return nextMonth
        }
        
        // Fallback: first day of next month
        let components = calendar.dateComponents([.year, .month], from: now)
        if let startOfMonth = calendar.date(from: components),
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) {
            return nextMonth
        }
        
        return now
    }
    
    func getUsageStatistics() async -> UsageStatistics {
        await cleanupRequestHistory()
        
        let now = Date()
        let calendar = Calendar.current
        
        // Requests in last 24 hours
        let last24Hours = requestHistory.filter {
            now.timeIntervalSince($0) <= 86400 // 24 hours in seconds
        }
        
        // Requests in last 7 days
        let last7Days = requestHistory.filter {
            now.timeIntervalSince($0) <= 604800 // 7 days in seconds
        }
        
        return UsageStatistics(
            monthlyUsed: requestCount,
            monthlyLimit: monthlyLimit,
            monthlyRemaining: getRemainingQuota(),
            last24Hours: last24Hours.count,
            last7Days: last7Days.count,
            resetDate: getQuotaResetDate(),
            averageRequestsPerDay: Double(last7Days.count) / 7.0
        )
    }
    
    struct UsageStatistics {
        let monthlyUsed: Int
        let monthlyLimit: Int
        let monthlyRemaining: Int
        let last24Hours: Int
        let last7Days: Int
        let resetDate: Date
        let averageRequestsPerDay: Double
        
        var utilizationPercentage: Double {
            return Double(monthlyUsed) / Double(monthlyLimit) * 100
        }
        
        var isNearLimit: Bool {
            return utilizationPercentage > 80
        }
    }
    
    // MARK: - Reset Management
    
    private func resetMonthlyCounter() async {
        let oldCount = requestCount
        requestCount = 0
        lastResetDate = Date()
        
        // Clean request history older than retention period
        await cleanupRequestHistory()
        
        await persistState()
        
        print("🔄 SerpAPI: Monthly quota reset - was \(oldCount), now 0/\(monthlyLimit)")
    }
    
    func forceReset() async {
        requestCount = 0
        lastResetDate = Date()
        lastRequestTime = nil
        requestHistory.removeAll()
        
        await persistState()
        
        print("🔄 SerpAPI: Force reset - quota reset to 0/\(monthlyLimit)")
    }
    
    // MARK: - Request History Management
    
    private func cleanupRequestHistory() async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -historyRetentionDays, to: Date()) ?? Date()
        let initialCount = requestHistory.count
        
        requestHistory = requestHistory.filter { $0 > cutoffDate }
        
        let removedCount = initialCount - requestHistory.count
        if removedCount > 0 {
            print("🧹 SerpAPI: Cleaned \(removedCount) old request history entries")
        }
    }
    
    // MARK: - State Persistence
    
    private func persistState() async {
        let state = RateLimiterState(
            requestCount: requestCount,
            lastResetDate: lastResetDate,
            lastRequestTime: lastRequestTime,
            requestHistory: requestHistory
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "serpapi_rate_limiter_state")
        }
    }
    
    private func loadPersistedState() {
        guard let data = UserDefaults.standard.data(forKey: "serpapi_rate_limiter_state"),
              let state = try? JSONDecoder().decode(RateLimiterState.self, from: data) else {
            return
        }
        
        requestCount = state.requestCount
        lastResetDate = state.lastResetDate
        lastRequestTime = state.lastRequestTime
        requestHistory = state.requestHistory
        
        print("📂 SerpAPI: Loaded rate limiter state - \(requestCount)/\(monthlyLimit) used")
    }
    
    private struct RateLimiterState: Codable {
        let requestCount: Int
        let lastResetDate: Date
        let lastRequestTime: Date?
        let requestHistory: [Date]
    }
    
    // MARK: - Retry Logic Support
    
    func getRetryDelay() -> TimeInterval {
        guard let lastTime = lastRequestTime else {
            return 0
        }
        
        let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
        if timeSinceLastRequest < minimumInterval {
            return minimumInterval - timeSinceLastRequest
        }
        
        return 0
    }
    
    func canRetryAfter(delay: TimeInterval) async -> Bool {
        let now = Date()
        
        if let retryTime = lastRequestTime?.addingTimeInterval(delay) {
            return now >= retryTime
        }
        
        return true
    }
    
    // MARK: - Burst Protection
    
    func getBurstStatus() async -> BurstStatus {
        let now = Date()
        let last5Minutes = requestHistory.filter {
            now.timeIntervalSince($0) <= 300 // 5 minutes
        }
        
        let burstThreshold = 5 // Max 5 requests per 5 minutes for free tier
        
        return BurstStatus(
            requestsInWindow: last5Minutes.count,
            windowLimit: burstThreshold,
            isNearBurst: last5Minutes.count >= burstThreshold - 1,
            isBurstProtected: last5Minutes.count >= burstThreshold
        )
    }
    
    struct BurstStatus {
        let requestsInWindow: Int
        let windowLimit: Int
        let isNearBurst: Bool
        let isBurstProtected: Bool
    }
}