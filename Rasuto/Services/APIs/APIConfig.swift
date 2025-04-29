//
//  APIConfig.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import Foundation

enum APIConfig {
    // Store non-sensitive configuration
    static let requestTimeout: TimeInterval = 30
    static let maxRetries = 3
    static let userAgent = "Rasuto/1.0"
    
    // Note: Don't store API keys here - use a secure storage solution
    // This file should be tracked in git
}
