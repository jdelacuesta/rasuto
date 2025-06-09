//
//  AxessoAmazonRateLimiter.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 6/3/25.
//

import Foundation

// MARK: - Rate Limiter for Axesso Amazon API

actor AxessoAmazonRateLimiter {
    
    // MARK: - Rate Limiting Configuration
    
    private let maxRequestsPerMinute: Int = 60
    private let maxRequestsPerHour: Int = 1000
    private let maxRequestsPerDay: Int = 10000
    
    // MARK: - Request Tracking
    
    private var requestTimestamps: [Date] = []
    private var hourlyRequestCount = 0
    private var dailyRequestCount = 0
    private var lastHourReset = Date()
    private var lastDayReset = Date()
    
    // MARK: - Rate Limiting Logic
    
    func checkRateLimit() async throws {
        let now = Date()
        
        // Reset counters if needed
        await resetCountersIfNeeded(currentTime: now)
        
        // Clean old timestamps (older than 1 minute)
        requestTimestamps = requestTimestamps.filter { timestamp in
            now.timeIntervalSince(timestamp) < 60
        }
        
        // Check minute limit
        if requestTimestamps.count >= maxRequestsPerMinute {
            let waitTime = 60 - now.timeIntervalSince(requestTimestamps.first!)
            throw APIError.rateLimitExceeded()
        }
        
        // Check hourly limit
        if hourlyRequestCount >= maxRequestsPerHour {
            throw APIError.rateLimitExceeded()
        }
        
        // Check daily limit
        if dailyRequestCount >= maxRequestsPerDay {
            throw APIError.rateLimitExceeded()
        }
        
        // Record the request
        requestTimestamps.append(now)
        hourlyRequestCount += 1
        dailyRequestCount += 1
    }
    
    private func resetCountersIfNeeded(currentTime: Date) {
        // Reset hourly counter
        if currentTime.timeIntervalSince(lastHourReset) >= 3600 {
            hourlyRequestCount = 0
            lastHourReset = currentTime
        }
        
        // Reset daily counter
        if currentTime.timeIntervalSince(lastDayReset) >= 86400 {
            dailyRequestCount = 0
            lastDayReset = currentTime
        }
    }
    
    // MARK: - Rate Limit Status
    
    func getRateLimitStatus() -> RateLimitStatus {
        let now = Date()
        
        // Clean old timestamps
        let recentRequests = requestTimestamps.filter { timestamp in
            now.timeIntervalSince(timestamp) < 60
        }
        
        return RateLimitStatus(
            requestsThisMinute: recentRequests.count,
            requestsThisHour: hourlyRequestCount,
            requestsToday: dailyRequestCount,
            minuteLimit: maxRequestsPerMinute,
            hourlyLimit: maxRequestsPerHour,
            dailyLimit: maxRequestsPerDay
        )
    }
    
    // MARK: - Request Delay Calculation
    
    func getRecommendedDelay() -> TimeInterval {
        let now = Date()
        
        // If we're close to the minute limit, suggest waiting
        let recentRequests = requestTimestamps.filter { timestamp in
            now.timeIntervalSince(timestamp) < 60
        }
        
        if recentRequests.count >= maxRequestsPerMinute - 5 {
            return 60 - now.timeIntervalSince(recentRequests.first ?? now)
        }
        
        // If we're close to hourly limit, suggest longer wait
        if hourlyRequestCount >= maxRequestsPerHour - 50 {
            return 300 // 5 minutes
        }
        
        // Normal operation - small delay to be respectful
        return 0.1
    }
}

// MARK: - Rate Limit Status Model

struct RateLimitStatus {
    let requestsThisMinute: Int
    let requestsThisHour: Int
    let requestsToday: Int
    let minuteLimit: Int
    let hourlyLimit: Int
    let dailyLimit: Int
    
    var minuteRemaining: Int {
        max(0, minuteLimit - requestsThisMinute)
    }
    
    var hourlyRemaining: Int {
        max(0, hourlyLimit - requestsThisHour)
    }
    
    var dailyRemaining: Int {
        max(0, dailyLimit - requestsToday)
    }
    
    var isNearLimit: Bool {
        minuteRemaining <= 5 || hourlyRemaining <= 50 || dailyRemaining <= 100
    }
}