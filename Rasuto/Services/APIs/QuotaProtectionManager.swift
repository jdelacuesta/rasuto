//
//  QuotaProtectionManager.swift
//  Rasuto
//
//  Created for critical SerpAPI quota protection on 6/3/25.
//

import Foundation

// MARK: - Quota Protection Manager

actor QuotaProtectionManager {
    
    static let shared = QuotaProtectionManager()
    
    // MARK: - Properties
    
    private var isQuotaProtectionEnabled = true
    private var isDemoModeEnabled = false
    private var dailyRequestCount = 0
    private var lastResetDate = Date()
    
    // Critical limits to prevent quota exhaustion - Actual Plan (5k/month)
    private let dailyLimit = 200 // Allows for development testing while staying within monthly limits
    private let hardStopPercentage = 90.0 // Allow usage up to 90% of monthly quota
    
    // MARK: - Initialization
    
    private init() {
        loadPersistedState()
        // ENSURE DEMO MODE IS DISABLED for real API data
        isDemoModeEnabled = false
        print("🎭 Demo mode DISABLED on initialization - API requests enabled")
    }
    
    // MARK: - Quota Protection
    
    func canMakeAPIRequest(service: String) async -> Bool {
        // Always block health check queries
        if service == "health_check" {
            print("🚫 BLOCKED: Health check requests are disabled to preserve quota")
            return false
        }
        
        // Demo mode uses cached data only
        if isDemoModeEnabled {
            print("🎭 Demo mode active - no API requests allowed")
            return false
        }
        
        // Check if protection is enabled
        guard isQuotaProtectionEnabled else { return true }
        
        // Reset daily counter if needed
        if !Calendar.current.isDateInToday(lastResetDate) {
            dailyRequestCount = 0
            lastResetDate = Date()
            await persistState()
        }
        
        // Check daily limit
        if dailyRequestCount >= dailyLimit {
            print("🛡️ QUOTA PROTECTION: Daily limit reached (\(dailyRequestCount)/\(dailyLimit))")
            return false
        }
        
        // Check SerpAPI monthly quota - Actual Plan 5k/month
        let serpAPIStats = await SerpAPIRateLimiter(monthlyLimit: 5000).getUsageStatistics()
        if serpAPIStats.utilizationPercentage >= hardStopPercentage {
            print("🛡️ QUOTA PROTECTION: Monthly quota at \(Int(serpAPIStats.utilizationPercentage))% - HARD STOP")
            return false
        }
        
        return true
    }
    
    func recordAPIRequest() async {
        dailyRequestCount += 1
        await persistState()
        print("📊 Quota Protection: Request \(dailyRequestCount)/\(dailyLimit) today")
    }
    
    func resetDailyQuota() async {
        dailyRequestCount = 0
        await persistState()
        print("🔄 Daily quota reset to 0/\(dailyLimit)")
    }
    
    // MARK: - Demo Mode
    
    func enableDemoMode() async {
        isDemoModeEnabled = true
        print("🎭 Demo mode ENABLED - all API requests will use cached data")
    }
    
    func disableDemoMode() async {
        isDemoModeEnabled = false
        print("🎭 Demo mode DISABLED - API requests allowed within limits")
    }
    
    func isDemoMode() async -> Bool {
        return isDemoModeEnabled
    }
    
    // MARK: - Configuration
    
    func setQuotaProtection(enabled: Bool) async {
        isQuotaProtectionEnabled = enabled
        print("🛡️ Quota protection \(enabled ? "ENABLED" : "DISABLED")")
    }
    
    func resetDailyCounter() async {
        dailyRequestCount = 0
        lastResetDate = Date()
        await persistState()
        print("🔄 Daily request counter reset")
    }
    
    func getStatus() async -> QuotaProtectionStatus {
        let serpAPIStats = await SerpAPIRateLimiter(monthlyLimit: 5000).getUsageStatistics()
        
        return QuotaProtectionStatus(
            isProtectionEnabled: isQuotaProtectionEnabled,
            isDemoMode: isDemoModeEnabled,
            dailyRequestsUsed: dailyRequestCount,
            dailyRequestLimit: dailyLimit,
            monthlyUtilization: serpAPIStats.utilizationPercentage,
            isNearMonthlyLimit: serpAPIStats.isNearLimit,
            canMakeRequests: dailyRequestCount < dailyLimit && serpAPIStats.utilizationPercentage < hardStopPercentage
        )
    }
    
    // MARK: - Persistence
    
    private func persistState() async {
        let state = ProtectionState(
            dailyRequestCount: dailyRequestCount,
            lastResetDate: lastResetDate,
            isDemoModeEnabled: isDemoModeEnabled,
            isQuotaProtectionEnabled: isQuotaProtectionEnabled
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "quota_protection_state")
        }
    }
    
    private func loadPersistedState() {
        guard let data = UserDefaults.standard.data(forKey: "quota_protection_state"),
              let state = try? JSONDecoder().decode(ProtectionState.self, from: data) else {
            return
        }
        
        dailyRequestCount = state.dailyRequestCount
        lastResetDate = state.lastResetDate
        isDemoModeEnabled = state.isDemoModeEnabled
        isQuotaProtectionEnabled = state.isQuotaProtectionEnabled
        
        // Reset daily counter if needed
        if !Calendar.current.isDateInToday(lastResetDate) {
            dailyRequestCount = 0
            lastResetDate = Date()
        }
    }
    
    private struct ProtectionState: Codable {
        let dailyRequestCount: Int
        let lastResetDate: Date
        let isDemoModeEnabled: Bool
        let isQuotaProtectionEnabled: Bool
    }
}

// MARK: - Supporting Types

struct QuotaProtectionStatus {
    let isProtectionEnabled: Bool
    let isDemoMode: Bool
    let dailyRequestsUsed: Int
    let dailyRequestLimit: Int
    let monthlyUtilization: Double
    let isNearMonthlyLimit: Bool
    let canMakeRequests: Bool
    
    var dailyUsagePercentage: Double {
        return Double(dailyRequestsUsed) / Double(dailyRequestLimit) * 100
    }
    
    var statusMessage: String {
        if isDemoMode {
            return "Demo mode active - using cached data"
        } else if !canMakeRequests {
            if dailyRequestsUsed >= dailyRequestLimit {
                return "Daily limit reached (\(dailyRequestsUsed)/\(dailyRequestLimit))"
            } else {
                return "Monthly quota at \(Int(monthlyUtilization))% - requests blocked"
            }
        } else {
            return "\(dailyRequestsUsed)/\(dailyRequestLimit) requests today, \(Int(monthlyUtilization))% monthly"
        }
    }
}

// MARK: - Global Functions

func shouldBlockAPIRequest(for service: String) async -> Bool {
    return !(await QuotaProtectionManager.shared.canMakeAPIRequest(service: service))
}