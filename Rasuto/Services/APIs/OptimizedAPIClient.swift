//
//  OptimizedAPIClient.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import Foundation
import Network
import Compression

// MARK: - Optimized API Client

actor OptimizedAPIClient {
    
    static let shared = OptimizedAPIClient()
    
    // MARK: - Properties
    
    private let urlSession: URLSession
    private let networkMonitor: NWPathMonitor
    private let requestCache: URLCache
    
    // MARK: - Network State
    
    private(set) var isConnected = true
    private(set) var connectionType: NWInterface.InterfaceType?
    private(set) var isExpensive = false
    
    // MARK: - Statistics
    
    private var requestStats = NetworkStats()
    
    // MARK: - Initialization
    
    private init() {
        // Configure advanced URLSessionConfiguration
        let config = URLSessionConfiguration.default
        
        // HTTP/2 and HTTP/3 optimizations
        config.httpMaximumConnectionsPerHost = 6
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        // Timeouts
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        
        // Connection improvements
        config.waitsForConnectivity = true
        config.networkServiceType = .responsiveData
        
        // Cache configuration
        let cacheMemoryCapacity = 50 * 1024 * 1024 // 50MB
        let cacheDiskCapacity = 200 * 1024 * 1024 // 200MB
        
        self.requestCache = URLCache(
            memoryCapacity: cacheMemoryCapacity,
            diskCapacity: cacheDiskCapacity,
            diskPath: "rasuto_network_cache"
        )
        config.urlCache = requestCache
        config.requestCachePolicy = .useProtocolCachePolicy
        
        // HTTP headers for compression and modern features
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate, br", // Brotli compression
            "Accept": "application/json",
            "Cache-Control": "no-cache",
            "User-Agent": "Rasuto/1.0 (iOS)",
            "Connection": "keep-alive"
        ]
        
        // Create session with custom delegate
        let delegate = OptimizedURLSessionDelegate()
        self.urlSession = URLSession(
            configuration: config,
            delegate: delegate,
            delegateQueue: nil
        )
        
        // Network monitoring
        self.networkMonitor = NWPathMonitor()
        
        // Start monitoring
        startNetworkMonitoring()
    }
    
    // MARK: - Network Request Methods
    
    func performRequest<T: Codable>(
        _ request: URLRequest,
        responseType: T.Type,
        priority: TaskPriority = .medium,
        enableDeduplication: Bool = true
    ) async throws -> T {
        
        let startTime = Date()
        
        // Check network connectivity
        guard isConnected else {
            throw NetworkError.noConnection
        }
        
        // Create optimized request
        var optimizedRequest = request
        optimizedRequest = addCompressionHeaders(to: optimizedRequest)
        optimizedRequest = addCachingHeaders(to: optimizedRequest)
        
        // Request deduplication
        if enableDeduplication {
            let requestKey = generateRequestKey(optimizedRequest)
            if let cachedResponse: T = await getCachedResponse(key: requestKey) {
                await recordRequestStats(duration: Date().timeIntervalSince(startTime), fromCache: true)
                return cachedResponse
            }
        }
        
        // Perform request with retry logic
        let (data, response) = try await performRequestWithRetry(optimizedRequest, priority: priority)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Handle different status codes
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 429:
            throw NetworkError.rateLimited
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }
        
        // Decompress if needed
        let decompressedData = try await decompressData(data, contentEncoding: httpResponse.allHeaderFields["Content-Encoding"] as? String)
        
        // Decode response
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(T.self, from: decompressedData)
            
            // Cache successful response
            if enableDeduplication {
                let requestKey = generateRequestKey(optimizedRequest)
                await cacheResponse(result, key: requestKey)
            }
            
            await recordRequestStats(duration: Date().timeIntervalSince(startTime), fromCache: false)
            return result
            
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    func downloadData(
        from url: URL,
        priority: TaskPriority = .medium
    ) async throws -> Data {
        
        let request = URLRequest(url: url)
        let (data, response) = try await performRequestWithRetry(request, priority: priority)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.updateNetworkStatus(path)
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func updateNetworkStatus(_ path: NWPath) async {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = nil
        }
        
        print("📡 Network status: Connected=\(isConnected), Type=\(connectionType?.description ?? "unknown"), Expensive=\(isExpensive)")
    }
    
    // MARK: - Request Optimization
    
    private func addCompressionHeaders(to request: URLRequest) -> URLRequest {
        var modifiedRequest = request
        
        // Add compression headers if not already present
        if modifiedRequest.value(forHTTPHeaderField: "Accept-Encoding") == nil {
            modifiedRequest.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        }
        
        return modifiedRequest
    }
    
    private func addCachingHeaders(to request: URLRequest) -> URLRequest {
        var modifiedRequest = request
        
        // Add appropriate caching headers based on connection type
        if isExpensive {
            // On expensive connections, prefer cached data
            modifiedRequest.cachePolicy = .returnCacheDataElseLoad
        } else {
            // On cheap connections, allow fresh data but with caching
            modifiedRequest.cachePolicy = .useProtocolCachePolicy
        }
        
        return modifiedRequest
    }
    
    private func performRequestWithRetry(
        _ request: URLRequest,
        priority: TaskPriority,
        maxRetries: Int = 3
    ) async throws -> (Data, URLResponse) {
        
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                // Perform request with priority
                let (data, response) = try await Task(priority: priority) {
                    try await urlSession.data(for: request)
                }.value
                return (data, response)
                
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cancelled, .badURL, .unsupportedURL:
                        throw error
                    default:
                        break
                    }
                }
                
                // Exponential backoff
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5 // 0.5s, 1s, 2s
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.maxRetriesExceeded
    }
    
    // MARK: - Data Decompression
    
    private func decompressData(_ data: Data, contentEncoding: String?) async throws -> Data {
        guard let encoding = contentEncoding?.lowercased() else {
            return data
        }
        
        switch encoding {
        case "gzip":
            return try data.decompressed(using: .gzip)
        case "deflate":
            return try data.decompressed(using: .zlib)
        case "br", "brotli":
            // Note: Brotli decompression requires additional implementation
            // For now, return data as-is
            print("⚠️ Brotli decompression not yet implemented")
            return data
        default:
            return data
        }
    }
    
    // MARK: - Response Caching
    
    private func generateRequestKey(_ request: URLRequest) -> String {
        let url = request.url?.absoluteString ?? ""
        let method = request.httpMethod ?? "GET"
        let headers = request.allHTTPHeaderFields?.description ?? ""
        return "\(method)_\(url)_\(headers)".data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    private func getCachedResponse<T: Codable>(key: String) async -> T? {
        return await UnifiedCacheManager.shared.get(key: "network_\(key)")
    }
    
    private func cacheResponse<T: Codable>(_ response: T, key: String) async {
        await UnifiedCacheManager.shared.set(key: "network_\(key)", value: response, ttl: 300)
    }
    
    // MARK: - Statistics
    
    private func recordRequestStats(duration: TimeInterval, fromCache: Bool) async {
        requestStats.totalRequests += 1
        requestStats.totalDuration += duration
        
        if fromCache {
            requestStats.cacheHits += 1
        }
        
        requestStats.averageResponseTime = requestStats.totalDuration / Double(requestStats.totalRequests)
    }
    
    func getNetworkStats() async -> NetworkStats {
        return requestStats
    }
    
    func resetStats() async {
        requestStats = NetworkStats()
    }
}

// MARK: - Optimized URL Session Delegate

class OptimizedURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            print("❌ Request failed: \(error.localizedDescription)")
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Allow redirects but log them
        print("🔄 HTTP Redirect: \(response.statusCode) -> \(request.url?.absoluteString ?? "unknown")")
        completionHandler(request)
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Handle SSL challenges appropriately
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Network Error Types

enum NetworkError: Error, LocalizedError {
    case noConnection
    case invalidResponse
    case httpError(Int, String?)
    case rateLimited
    case serverError(Int)
    case decodingFailed(Error)
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No network connection available"
        case .invalidResponse:
            return "Invalid response received"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message ?? "Unknown error")"
        case .rateLimited:
            return "Rate limit exceeded"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
}

// MARK: - Network Statistics

struct NetworkStats {
    var totalRequests: Int = 0
    var cacheHits: Int = 0
    var totalDuration: TimeInterval = 0
    var averageResponseTime: TimeInterval = 0
    
    var cacheHitRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(cacheHits) / Double(totalRequests)
    }
}

// MARK: - Data Compression Extension

extension Data {
    func decompressed(using algorithm: CompressionAlgorithm) throws -> Data {
        guard !self.isEmpty else { return self }
        
        return try self.withUnsafeBytes { bytes in
            let source = bytes.bindMemory(to: UInt8.self).baseAddress!
            let sourceSize = self.count
            
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sourceSize * 4)
            defer { destinationBuffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                destinationBuffer, sourceSize * 4,
                source, sourceSize,
                nil, algorithm.rawAlgorithm
            )
            
            guard decompressedSize > 0 else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
    }
}

enum CompressionAlgorithm {
    case gzip
    case zlib
    case lz4
    case lzma
    
    var rawAlgorithm: compression_algorithm {
        switch self {
        case .gzip, .zlib: return COMPRESSION_ZLIB
        case .lz4: return COMPRESSION_LZ4
        case .lzma: return COMPRESSION_LZMA
        }
    }
}

enum CompressionError: Error {
    case decompressionFailed
}

// MARK: - Interface Type Extension

extension NWInterface.InterfaceType {
    var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}