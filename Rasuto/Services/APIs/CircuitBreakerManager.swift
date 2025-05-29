//
//  CircuitBreakerManager.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation

// MARK: - Circuit Breaker Manager Actor

actor CircuitBreakerManager {
    
    static let shared = CircuitBreakerManager()
    
    // MARK: - Properties
    
    private var circuitBreakers: [String: CircuitBreaker] = [:]
    
    // MARK: - Default Configurations
    
    private let defaultConfigs: [String: CircuitBreakerConfig] = [
        "bestbuy": CircuitBreakerConfig(
            failureThreshold: 5,
            recoveryTimeout: 30,
            halfOpenMaxRequests: 3
        ),
        "walmart": CircuitBreakerConfig(
            failureThreshold: 3,
            recoveryTimeout: 60,
            halfOpenMaxRequests: 2
        ),
        "ebay": CircuitBreakerConfig(
            failureThreshold: 4,
            recoveryTimeout: 45,
            halfOpenMaxRequests: 2
        )
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Initialize circuit breakers for known services
        for (service, config) in defaultConfigs {
            circuitBreakers[service] = CircuitBreaker(config: config, serviceName: service)
        }
    }
    
    // MARK: - Circuit Breaker Operations
    
    func canExecute(service: String) async -> Bool {
        let circuitBreaker = getOrCreateCircuitBreaker(for: service)
        return circuitBreaker.canExecute()
    }
    
    func recordSuccess(service: String) async {
        let circuitBreaker = getOrCreateCircuitBreaker(for: service)
        circuitBreaker.recordSuccess()
    }
    
    func recordFailure(service: String) async {
        let circuitBreaker = getOrCreateCircuitBreaker(for: service)
        circuitBreaker.recordFailure()
    }
    
    func getState(service: String) async -> CircuitBreakerState {
        let circuitBreaker = getOrCreateCircuitBreaker(for: service)
        return circuitBreaker.state
    }
    
    func getStats(service: String) async -> CircuitBreakerStats {
        let circuitBreaker = getOrCreateCircuitBreaker(for: service)
        return circuitBreaker.getStats()
    }
    
    func reset(service: String) async {
        let circuitBreaker = getOrCreateCircuitBreaker(for: service)
        circuitBreaker.reset()
        print("🔄 Circuit breaker reset for \(service)")
    }
    
    func updateConfig(service: String, config: CircuitBreakerConfig) async {
        circuitBreakers[service] = CircuitBreaker(config: config, serviceName: service)
        print("⚙️ Updated circuit breaker config for \(service)")
    }
    
    // MARK: - Private Methods
    
    private func getOrCreateCircuitBreaker(for service: String) -> CircuitBreaker {
        if let existingBreaker = circuitBreakers[service] {
            return existingBreaker
        }
        
        // Create new circuit breaker with default config
        let defaultConfig = CircuitBreakerConfig(
            failureThreshold: 5,
            recoveryTimeout: 30,
            halfOpenMaxRequests: 3
        )
        
        let newBreaker = CircuitBreaker(config: defaultConfig, serviceName: service)
        circuitBreakers[service] = newBreaker
        
        print("🆕 Created new circuit breaker for \(service)")
        return newBreaker
    }
}

// MARK: - Circuit Breaker

class CircuitBreaker {
    
    // MARK: - Properties
    
    private let config: CircuitBreakerConfig
    private let serviceName: String
    
    private var failureCount = 0
    private var lastFailureTime: Date?
    private var halfOpenSuccessCount = 0
    
    private(set) var state: CircuitBreakerState = .closed
    
    // MARK: - Initialization
    
    init(config: CircuitBreakerConfig, serviceName: String) {
        self.config = config
        self.serviceName = serviceName
    }
    
    // MARK: - Operations
    
    func canExecute() -> Bool {
        switch state {
        case .closed:
            return true
            
        case .open:
            // Check if we should transition to half-open
            if shouldTransitionToHalfOpen() {
                transitionToHalfOpen()
                return true
            }
            return false
            
        case .halfOpen:
            return halfOpenSuccessCount < config.halfOpenMaxRequests
        }
    }
    
    func recordSuccess() {
        switch state {
        case .closed:
            // Reset failure count on success
            if failureCount > 0 {
                failureCount = 0
                print("✅ Circuit breaker for \(serviceName): Failure count reset")
            }
            
        case .halfOpen:
            halfOpenSuccessCount += 1
            print("✅ Circuit breaker for \(serviceName): Half-open success \(halfOpenSuccessCount)/\(config.halfOpenMaxRequests)")
            
            if halfOpenSuccessCount >= config.halfOpenMaxRequests {
                transitionToClosed()
            }
            
        case .open:
            // Should not happen, but handle gracefully
            break
        }
    }
    
    func recordFailure() {
        switch state {
        case .closed:
            failureCount += 1
            lastFailureTime = Date()
            
            print("❌ Circuit breaker for \(serviceName): Failure \(failureCount)/\(config.failureThreshold)")
            
            if failureCount >= config.failureThreshold {
                transitionToOpen()
            }
            
        case .halfOpen:
            // Any failure in half-open state goes back to open
            transitionToOpen()
            
        case .open:
            // Already open, just update last failure time
            lastFailureTime = Date()
        }
    }
    
    func reset() {
        failureCount = 0
        lastFailureTime = nil
        halfOpenSuccessCount = 0
        state = .closed
    }
    
    func getStats() -> CircuitBreakerStats {
        return CircuitBreakerStats(
            state: state,
            failureCount: failureCount,
            lastFailureTime: lastFailureTime,
            halfOpenSuccessCount: halfOpenSuccessCount,
            config: config
        )
    }
    
    // MARK: - State Transitions
    
    private func shouldTransitionToHalfOpen() -> Bool {
        guard let lastFailure = lastFailureTime else { return false }
        let recoveryTime = lastFailure.addingTimeInterval(config.recoveryTimeout)
        return Date() >= recoveryTime
    }
    
    private func transitionToOpen() {
        state = .open
        lastFailureTime = Date()
        halfOpenSuccessCount = 0
        print("🔴 Circuit breaker OPEN for \(serviceName)")
    }
    
    private func transitionToHalfOpen() {
        state = .halfOpen
        halfOpenSuccessCount = 0
        print("🟡 Circuit breaker HALF-OPEN for \(serviceName)")
    }
    
    private func transitionToClosed() {
        state = .closed
        failureCount = 0
        lastFailureTime = nil
        halfOpenSuccessCount = 0
        print("🟢 Circuit breaker CLOSED for \(serviceName)")
    }
}

// MARK: - Supporting Types

struct CircuitBreakerConfig {
    let failureThreshold: Int
    let recoveryTimeout: TimeInterval
    let halfOpenMaxRequests: Int
}

enum CircuitBreakerState {
    case closed    // Normal operation
    case open      // Failing fast
    case halfOpen  // Testing recovery
}

struct CircuitBreakerStats {
    let state: CircuitBreakerState
    let failureCount: Int
    let lastFailureTime: Date?
    let halfOpenSuccessCount: Int
    let config: CircuitBreakerConfig
    
    var isHealthy: Bool {
        return state == .closed && failureCount == 0
    }
    
    var nextRetryTime: Date? {
        guard state == .open, let lastFailure = lastFailureTime else {
            return nil
        }
        return lastFailure.addingTimeInterval(config.recoveryTimeout)
    }
}

// MARK: - Circuit Breaker Extensions

extension CircuitBreakerState: CustomStringConvertible {
    var description: String {
        switch self {
        case .closed:
            return "CLOSED"
        case .open:
            return "OPEN"
        case .halfOpen:
            return "HALF-OPEN"
        }
    }
}