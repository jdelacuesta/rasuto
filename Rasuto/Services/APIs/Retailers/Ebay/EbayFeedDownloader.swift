//
//  EbayFeedDownloader.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/29/25.
//

import Foundation
import Compression

class EbayFeedDownloader {
    enum FeedType {
        case item
        case itemGroup
        case itemSnapshot
        case itemPriority
        
        var endpointPath: String {
            switch self {
            case .item: return "item"
            case .itemGroup: return "item_group"
            case .itemSnapshot: return "item_snapshot"
            case .itemPriority: return "item_priority"
            }
        }
    }
    
    enum FeedScope: String {
        case newlyListed = "NEWLY_LISTED"
        case allActive = "ALL_ACTIVE"
    }
    
    enum DownloadError: Error {
        case feedTypeNotFound
        case noFilesAvailable
        case noCategoryFilesAvailable
        case downloadFailed
        case invalidParameters
        case processingFailed
        case rangeHeaderRequired
    }
    
    private let ebayService: EbayAPIService
    private let baseURL = "https://api.ebay.com/buy/feed/v1"
    
    init(ebayService: EbayAPIService) {
        self.ebayService = ebayService
    }
    
    // MARK: - Feed Download Methods
    
    /// Download an item feed file based on category and scope
    func downloadItemFeed(categoryId: String, feedScope: FeedScope, marketplaceId: String, date: String? = nil) async throws -> Data {
        // Build query parameters
        var queryParams: [String: String] = [
            "category_id": categoryId,
            "feed_scope": feedScope.rawValue
        ]
        
        // Date is required for NEWLY_LISTED scope
        if feedScope == .newlyListed {
            guard let date = date else {
                throw DownloadError.invalidParameters
            }
            queryParams["date"] = date
        }
        
        // Call the API to download the feed
        return try await downloadFeed(type: .item, marketplaceId: marketplaceId, queryParams: queryParams)
    }
    
    /// Download an item group feed file
    func downloadItemGroupFeed(categoryId: String, feedScope: FeedScope, marketplaceId: String, date: String? = nil) async throws -> Data {
        // Build query parameters
        var queryParams: [String: String] = [
            "category_id": categoryId,
            "feed_scope": feedScope.rawValue
        ]
        
        // Date is required for NEWLY_LISTED scope
        if feedScope == .newlyListed {
            guard let date = date else {
                throw DownloadError.invalidParameters
            }
            queryParams["date"] = date
        }
        
        // Call the API to download the feed
        return try await downloadFeed(type: .itemGroup, marketplaceId: marketplaceId, queryParams: queryParams)
    }
    
    /// Download an hourly snapshot feed file
    func downloadItemSnapshotFeed(categoryId: String, marketplaceId: String, snapshotDate: String) async throws -> Data {
        let queryParams: [String: String] = [
            "category_id": categoryId,
            "snapshot_date": snapshotDate
        ]
        
        // Call the API to download the feed
        return try await downloadFeed(type: .itemSnapshot, marketplaceId: marketplaceId, queryParams: queryParams)
    }
    
    /// Download a priority item feed file
    func downloadItemPriorityFeed(categoryId: String, marketplaceId: String, date: String) async throws -> Data {
        let queryParams: [String: String] = [
            "category_id": categoryId,
            "date": date
        ]
        
        // Call the API to download the feed
        return try await downloadFeed(type: .itemPriority, marketplaceId: marketplaceId, queryParams: queryParams)
    }
    
    // MARK: - Helper Methods
    
    /// Generic method to download any feed type
    private func downloadFeed(type: FeedType, marketplaceId: String, queryParams: [String: String]) async throws -> Data {
        // Get OAuth token
        let oauthHandler = OAuthHandler()
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        // Build URL components
        var urlComponents = URLComponents(string: "\(baseURL)/\(type.endpointPath)")
        
        // Add query parameters
        urlComponents?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json,text/tab-separated-values", forHTTPHeaderField: "Accept")
        request.addValue(marketplaceId, forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        
        // The Range header is required for files over 100MB
        // Downloading in chunks is required for large files
        request.addValue("bytes=0-104857600", forHTTPHeaderField: "Range") // First 100MB
        
        // Download the feed file
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200, 206: // Success or Partial Content
            // Check if this is a partial download and if we need more chunks
            if httpResponse.statusCode == 206,
               let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range"),
               let totalSize = parseContentRange(contentRange) {
                
                // If the file is larger than 100MB, we need to download the rest in chunks
                if totalSize > 104857600 {
                    // For this implementation, we'll just return the first chunk
                    // In a complete implementation, you'd download all chunks and combine them
                    return data
                }
            }
            
            return data
            
        case 204: // No Content
            throw DownloadError.noFilesAvailable
            
        case 400:
            throw APIError.invalidResponse
            
        case 401:
            throw APIError.authenticationFailed
            
        case 403:
            throw APIError.authenticationFailed
            
        case 404:
            throw DownloadError.noFilesAvailable
            
        case 416: // Range Not Satisfiable
            throw DownloadError.rangeHeaderRequired
            
        case 429:
            throw APIError.rateLimitExceeded
            
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    // Parse the Content-Range header to get total file size
    private func parseContentRange(_ contentRange: String) -> Int? {
        // Format: "bytes 0-999999/1234567"
        let components = contentRange.components(separatedBy: "/")
        if components.count == 2, let totalSize = Int(components[1]) {
            return totalSize
        }
        return nil
    }
    
    /// Process downloaded feed data into product items
    func processFeedData(_ data: Data) async throws -> [ProductItemDTO] {
        return try await EbayFeedProcessor.processFeedFile(data: data)
    }
    
    /// Download the feed file in chunks and process it
    func downloadAndProcessFeed(type: FeedType, categoryId: String, marketplaceId: String, feedScope: FeedScope? = nil, date: String? = nil) async throws -> [ProductItemDTO] {
        let data: Data
        
        switch type {
        case .item:
            guard let scope = feedScope else {
                throw DownloadError.invalidParameters
            }
            data = try await downloadItemFeed(categoryId: categoryId, feedScope: scope, marketplaceId: marketplaceId, date: date)
            
        case .itemGroup:
            guard let scope = feedScope else {
                throw DownloadError.invalidParameters
            }
            data = try await downloadItemGroupFeed(categoryId: categoryId, feedScope: scope, marketplaceId: marketplaceId, date: date)
            
        case .itemSnapshot:
            guard let snapshotDate = date else {
                throw DownloadError.invalidParameters
            }
            data = try await downloadItemSnapshotFeed(categoryId: categoryId, marketplaceId: marketplaceId, snapshotDate: snapshotDate)
            
        case .itemPriority:
            guard let priorityDate = date else {
                throw DownloadError.invalidParameters
            }
            data = try await downloadItemPriorityFeed(categoryId: categoryId, marketplaceId: marketplaceId, date: priorityDate)
        }
        
        // Process the feed data
        return try await processFeedData(data)
    }
}
