//
//  GlobalRateLimiter.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation

// MARK: - Global Rate Limiter Actor

actor GlobalRateLimiter {
    
    static let shared = GlobalRateLimiter()
    
    // MARK: - Properties
    
    private var serviceLimits: [String: ServiceRateLimit] = [:]
    private var requestQueues: [String: RequestQueue] = [:]
    
    // MARK: - Default Configurations
    
    private let defaultConfigs: [String: RateLimitConfig] = [
        "bestbuy": RateLimitConfig(
            requestsPerSecond: 5,
            requestsPerMinute: 100,
            requestsPerHour: 1000,
            burstLimit: 10
        ),
        "walmart": RateLimitConfig(
            requestsPerSecond: 2,
            requestsPerMinute: 25,
            requestsPerHour: 500,
            burstLimit: 5
        ),
        "ebay": RateLimitConfig(
            requestsPerSecond: 3,
            requestsPerMinute: 50,
            requestsPerHour: 800,
            burstLimit: 8
        ),
        "serpapi": RateLimitConfig(
            requestsPerSecond: 1,
            requestsPerMinute: 10,
            requestsPerHour: 100,
            burstLimit: 2
        )
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Initialize service limits with default configurations
        for (service, config) in defaultConfigs {
            serviceLimits[service] = ServiceRateLimit(config: config)
            requestQueues[service] = RequestQueue(maxSize: 100)
        }
        
        // Start cleanup task
        Task {
            await startCleanupTask()
        }
    }
    
    // MARK: - Rate Limiting Operations
    
    func checkAndConsume(service: String, priority: RequestPriority = .normal) async throws {
        guard let serviceLimit = serviceLimits[service] else {
            // Unknown service, create default limit
            let defaultConfig = RateLimitConfig(
                requestsPerSecond: 1,
                requestsPerMinute: 10,
                requestsPerHour: 100,
                burstLimit: 2
            )
            serviceLimits[service] = ServiceRateLimit(config: defaultConfig)
            requestQueues[service] = RequestQueue(maxSize: 50)
            return
        }
        
        // Check if we can proceed immediately
        if serviceLimit.canConsume() {
            serviceLimit.consume()
            print("✅ Rate limit OK for \(service) - immediate execution")
            return
        }
        
        // Add to queue if rate limited
        guard let queue = requestQueues[service] else {
            throw RateLimitError.serviceNotFound(service)
        }
        
        if queue.isFull {
            throw RateLimitError.queueFull(service)
        }
        
        print("⏳ Rate limited for \(service) - adding to queue (priority: \(priority))")
        
        // Wait for our turn in the queue
        return try await withCheckedThrowingContinuation { continuation in
            let request = QueuedRequest(
                priority: priority,
                continuation: continuation,
                timestamp: Date()
            )
            
            queue.enqueue(request)
        }
    }
    
    func updateLimits(service: String, config: RateLimitConfig) async {
        serviceLimits[service] = ServiceRateLimit(config: config)
        print("📊 Updated rate limits for \(service): \(config)")
    }
    
    func getRemainingQuota(service: String) async -> RateLimitQuota? {
        guard let serviceLimit = serviceLimits[service] else {
            return nil
        }
        
        return RateLimitQuota(
            remainingPerSecond: serviceLimit.remainingPerSecond,
            remainingPerMinute: serviceLimit.remainingPerMinute,
            remainingPerHour: serviceLimit.remainingPerHour,
            resetTimes: serviceLimit.resetTimes
        )
    }
    
    func getQueueStatus(service: String) async -> QueueStatus? {
        guard let queue = requestQueues[service] else {
            return nil
        }
        
        return QueueStatus(
            size: queue.size,
            maxSize: queue.maxSize,
            highPriorityCount: queue.highPriorityCount,
            normalPriorityCount: queue.normalPriorityCount,
            lowPriorityCount: queue.lowPriorityCount
        )
    }
    
    // MARK: - Queue Processing
    
    private func processQueues() async {
        for (service, queue) in requestQueues {
            guard let serviceLimit = serviceLimits[service],
                  !queue.isEmpty,
                  serviceLimit.canConsume() else {
                continue
            }
            
            if let request = queue.dequeue() {
                serviceLimit.consume()
                request.continuation.resume()
                print("▶️ Processed queued request for \(service)")
            }
        }
    }
    
    private func startCleanupTask() async {
        while true {
            // Process queues every 100ms
            await processQueues()
            
            // Clean up expired requests every 10 seconds
            await cleanupExpiredRequests()
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    private func cleanupExpiredRequests() async {
        let expirationThreshold = Date().addingTimeInterval(-60) // 1 minute timeout
        
        for (service, queue) in requestQueues {
            queue.removeExpired(before: expirationThreshold)
        }
    }
}

// MARK: - Service Rate Limit

class ServiceRateLimit {
    private let config: RateLimitConfig
    private var secondWindow: TimeWindow
    private var minuteWindow: TimeWindow
    private var hourWindow: TimeWindow
    
    init(config: RateLimitConfig) {
        self.config = config
        self.secondWindow = TimeWindow(duration: 1, maxRequests: config.requestsPerSecond)
        self.minuteWindow = TimeWindow(duration: 60, maxRequests: config.requestsPerMinute)
        self.hourWindow = TimeWindow(duration: 3600, maxRequests: config.requestsPerHour)
    }
    
    func canConsume() -> Bool {
        let now = Date()
        secondWindow.cleanup(at: now)
        minuteWindow.cleanup(at: now)
        hourWindow.cleanup(at: now)
        
        return secondWindow.canAdd() && minuteWindow.canAdd() && hourWindow.canAdd()
    }
    
    func consume() {
        let now = Date()
        secondWindow.add(at: now)
        minuteWindow.add(at: now)
        hourWindow.add(at: now)
    }
    
    var remainingPerSecond: Int {
        secondWindow.remaining
    }
    
    var remainingPerMinute: Int {
        minuteWindow.remaining
    }
    
    var remainingPerHour: Int {
        hourWindow.remaining
    }
    
    var resetTimes: ResetTimes {
        ResetTimes(
            secondReset: secondWindow.nextReset,
            minuteReset: minuteWindow.nextReset,
            hourReset: hourWindow.nextReset
        )
    }
}

// MARK: - Time Window

class TimeWindow {
    private let duration: TimeInterval
    private let maxRequests: Int
    private var requests: [Date] = []
    
    init(duration: TimeInterval, maxRequests: Int) {
        self.duration = duration
        self.maxRequests = maxRequests
    }
    
    func cleanup(at currentTime: Date) {
        let cutoff = currentTime.addingTimeInterval(-duration)
        requests.removeAll { $0 < cutoff }
    }
    
    func canAdd() -> Bool {
        return requests.count < maxRequests
    }
    
    func add(at time: Date) {
        requests.append(time)
    }
    
    var remaining: Int {
        return max(0, maxRequests - requests.count)
    }
    
    var nextReset: Date {
        guard let earliest = requests.first else {
            return Date()
        }
        return earliest.addingTimeInterval(duration)
    }
}

// MARK: - Request Queue

class RequestQueue {
    private var highPriorityQueue: [QueuedRequest] = []
    private var normalPriorityQueue: [QueuedRequest] = []
    private var lowPriorityQueue: [QueuedRequest] = []
    
    let maxSize: Int
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    var size: Int {
        return highPriorityQueue.count + normalPriorityQueue.count + lowPriorityQueue.count
    }
    
    var isEmpty: Bool {
        return size == 0
    }
    
    var isFull: Bool {
        return size >= maxSize
    }
    
    var highPriorityCount: Int { highPriorityQueue.count }
    var normalPriorityCount: Int { normalPriorityQueue.count }
    var lowPriorityCount: Int { lowPriorityQueue.count }
    
    func enqueue(_ request: QueuedRequest) {
        switch request.priority {
        case .high:
            highPriorityQueue.append(request)
        case .normal:
            normalPriorityQueue.append(request)
        case .low:
            lowPriorityQueue.append(request)
        }
    }
    
    func dequeue() -> QueuedRequest? {
        // Serve high priority first, then normal, then low
        if !highPriorityQueue.isEmpty {
            return highPriorityQueue.removeFirst()
        } else if !normalPriorityQueue.isEmpty {
            return normalPriorityQueue.removeFirst()
        } else if !lowPriorityQueue.isEmpty {
            return lowPriorityQueue.removeFirst()
        }
        return nil
    }
    
    func removeExpired(before date: Date) {
        highPriorityQueue.removeAll { request in
            if request.timestamp < date {
                request.continuation.resume(throwing: RateLimitError.requestTimeout)
                return true
            }
            return false
        }
        
        normalPriorityQueue.removeAll { request in
            if request.timestamp < date {
                request.continuation.resume(throwing: RateLimitError.requestTimeout)
                return true
            }
            return false
        }
        
        lowPriorityQueue.removeAll { request in
            if request.timestamp < date {
                request.continuation.resume(throwing: RateLimitError.requestTimeout)
                return true
            }
            return false
        }
    }
}

// MARK: - Supporting Types

struct RateLimitConfig {
    let requestsPerSecond: Int
    let requestsPerMinute: Int
    let requestsPerHour: Int
    let burstLimit: Int
}

struct QueuedRequest {
    let priority: RequestPriority
    let continuation: CheckedContinuation<Void, Error>
    let timestamp: Date
}

enum RequestPriority {
    case high
    case normal
    case low
}

struct RateLimitQuota {
    let remainingPerSecond: Int
    let remainingPerMinute: Int
    let remainingPerHour: Int
    let resetTimes: ResetTimes
}

struct ResetTimes {
    let secondReset: Date
    let minuteReset: Date
    let hourReset: Date
}

struct QueueStatus {
    let size: Int
    let maxSize: Int
    let highPriorityCount: Int
    let normalPriorityCount: Int
    let lowPriorityCount: Int
}

enum RateLimitError: Error, LocalizedError {
    case serviceNotFound(String)
    case queueFull(String)
    case requestTimeout
    
    var errorDescription: String? {
        switch self {
        case .serviceNotFound(let service):
            return "Rate limit service not found: \(service)"
        case .queueFull(let service):
            return "Request queue is full for service: \(service)"
        case .requestTimeout:
            return "Request timed out in queue"
        }
    }
}