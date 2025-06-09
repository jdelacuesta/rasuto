//
//  OxylabsRateLimiter.swift
//  Rasuto
//
//  Created for Oxylabs Web Scraper API rate limiting on 6/4/25.
//

import Foundation

// MARK: - Oxylabs Rate Limiter

actor OxylabsRateLimiter {
    
    // MARK: - Rate Limiting Configuration
    
    private var requestCount = 0
    private var lastResetDate = Date()
    private let weeklyLimit = 5000 // 7-day trial: 5K requests
    private let dailyLimit = 714 // ~5K / 7 days
    private let minimumInterval: TimeInterval = 2.0 // 2 seconds between requests
    private var lastRequestTime: Date?
    
    // MARK: - Request Tracking
    
    private var requestHistory: [Date] = []
    private let historyRetentionDays = 7
    
    // MARK: - Integration with Global Rate Limiter
    
    private let globalRateLimiter = GlobalRateLimiter.shared
    private let useGlobalRateLimiter = true
    private let serviceName = "oxylabs"
    
    // MARK: - Initialization
    
    init() {
        loadPersistedState()
    }
    
    // MARK: - Rate Limit Checking
    
    func canMakeRequest() async -> Bool {
        let now = Date()
        
        // Check minimum interval between requests
        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = now.timeIntervalSince(lastTime)
            if timeSinceLastRequest < minimumInterval {
                print("⏱️ Oxylabs: Rate limit - too soon since last request (\(String(format: "%.1f", timeSinceLastRequest))s)")
                return false
            }
        }
        
        // Check weekly limit (7-day trial)
        let calendar = Calendar.current
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
            if lastResetDate < weekAgo {
                await resetWeeklyCounter()
            }
        }
        
        if requestCount >= weeklyLimit {
            print("📊 Oxylabs: Weekly limit reached (\(requestCount)/\(weeklyLimit))")
            return false
        }
        
        // Check daily limit
        let today = calendar.startOfDay(for: now)
        let todayRequests = requestHistory.filter { calendar.isDate($0, inSameDayAs: today) }
        
        if todayRequests.count >= dailyLimit {
            print("📊 Oxylabs: Daily limit reached (\(todayRequests.count)/\(dailyLimit))")
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
                print("🚫 Oxylabs: Global rate limiter blocked request - \(error)")
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
        
        print("📊 Oxylabs Request \(requestCount)/\(weeklyLimit) - \(getRemainingQuota()) remaining this week")
    }
    
    // MARK: - Quota Management
    
    func getRemainingQuota() -> Int {
        return max(0, weeklyLimit - requestCount)
    }
    
    func getDailyUsage() -> Int {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        
        return requestHistory.filter { calendar.isDate($0, inSameDayAs: today) }.count
    }
    
    func getDailyRemaining() -> Int {
        return max(0, dailyLimit - getDailyUsage())
    }
    
    func getUsageInfo() -> OxylabsUsageInfo {
        let now = Date()
        let calendar = Calendar.current
        
        // Calculate reset time (7 days from first request)
        let resetTime = calendar.date(byAdding: .day, value: 7, to: lastResetDate) ?? now
        
        return OxylabsUsageInfo(
            requestsUsed: requestCount,
            requestsLimit: weeklyLimit,
            resetTime: resetTime
        )
    }
    
    func getUsageStatistics() async -> UsageStatistics {
        await cleanupRequestHistory()
        
        let now = Date()
        let calendar = Calendar.current
        
        // Requests in last 24 hours
        let last24Hours = requestHistory.filter {
            now.timeIntervalSince($0) <= 86400
        }
        
        // Requests today
        let today = calendar.startOfDay(for: now)
        let todayRequests = requestHistory.filter { calendar.isDate($0, inSameDayAs: today) }
        
        return UsageStatistics(
            weeklyUsed: requestCount,
            weeklyLimit: weeklyLimit,
            weeklyRemaining: getRemainingQuota(),
            dailyUsed: todayRequests.count,
            dailyLimit: dailyLimit,
            dailyRemaining: getDailyRemaining(),
            last24Hours: last24Hours.count,
            averageRequestsPerDay: Double(requestHistory.count) / Double(min(7, requestHistory.count))
        )
    }
    
    struct UsageStatistics {
        let weeklyUsed: Int
        let weeklyLimit: Int
        let weeklyRemaining: Int
        let dailyUsed: Int
        let dailyLimit: Int
        let dailyRemaining: Int
        let last24Hours: Int
        let averageRequestsPerDay: Double
        
        var weeklyUtilizationPercentage: Double {
            return Double(weeklyUsed) / Double(weeklyLimit) * 100
        }
        
        var dailyUtilizationPercentage: Double {
            return Double(dailyUsed) / Double(dailyLimit) * 100
        }
        
        var isNearWeeklyLimit: Bool {
            return weeklyUtilizationPercentage > 80
        }
        
        var isNearDailyLimit: Bool {
            return dailyUtilizationPercentage > 80
        }
    }
    
    // MARK: - Reset Management
    
    private func resetWeeklyCounter() async {
        let oldCount = requestCount
        requestCount = 0
        lastResetDate = Date()
        
        // Clean old request history
        await cleanupRequestHistory()
        
        await persistState()
        
        print("🔄 Oxylabs: Weekly quota reset - was \(oldCount), now 0/\(weeklyLimit)")
    }
    
    func forceReset() async {
        requestCount = 0
        lastResetDate = Date()
        lastRequestTime = nil
        requestHistory.removeAll()
        
        await persistState()
        
        print("🔄 Oxylabs: Force reset - quota reset to 0/\(weeklyLimit)")
    }
    
    // MARK: - Request History Management
    
    private func cleanupRequestHistory() async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -historyRetentionDays, to: Date()) ?? Date()
        let initialCount = requestHistory.count
        
        requestHistory = requestHistory.filter { $0 > cutoffDate }
        
        let removedCount = initialCount - requestHistory.count
        if removedCount > 0 {
            print("🧹 Oxylabs: Cleaned \(removedCount) old request history entries")
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
            UserDefaults.standard.set(encoded, forKey: "oxylabs_rate_limiter_state")
        }
    }
    
    private func loadPersistedState() {
        guard let data = UserDefaults.standard.data(forKey: "oxylabs_rate_limiter_state"),
              let state = try? JSONDecoder().decode(RateLimiterState.self, from: data) else {
            return
        }
        
        requestCount = state.requestCount
        lastResetDate = state.lastResetDate
        lastRequestTime = state.lastRequestTime
        requestHistory = state.requestHistory
        
        print("📂 Oxylabs: Loaded rate limiter state - \(requestCount)/\(weeklyLimit) used this week")
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
    
    // MARK: - Trial Period Management
    
    func getTrialDaysRemaining() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        if let trialEnd = calendar.date(byAdding: .day, value: 7, to: lastResetDate) {
            let components = calendar.dateComponents([.day], from: now, to: trialEnd)
            return max(0, components.day ?? 0)
        }
        
        return 0
    }
    
    func isTrialExpired() -> Bool {
        return getTrialDaysRemaining() == 0
    }
    
    func getTrialStatus() -> TrialStatus {
        let daysRemaining = getTrialDaysRemaining()
        let usageStats = getUsageInfo()
        
        return TrialStatus(
            daysRemaining: daysRemaining,
            isExpired: daysRemaining == 0,
            utilizationPercentage: usageStats.utilizationPercentage,
            requestsRemaining: usageStats.requestsLimit - usageStats.requestsUsed
        )
    }
    
    struct TrialStatus {
        let daysRemaining: Int
        let isExpired: Bool
        let utilizationPercentage: Double
        let requestsRemaining: Int
        
        var statusMessage: String {
            if isExpired {
                return "Trial expired"
            } else if daysRemaining == 1 {
                return "Trial expires tomorrow"
            } else {
                return "\(daysRemaining) days remaining"
            }
        }
    }
}