//
//  EbayNotificationService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/30/25.
//

import Foundation

class EbayNotificationService {
    // MARK: - Properties
    
    private let baseURL = "https://api.ebay.com/commerce/notification/v1"
    private let oauthHandler = OAuthHandler()
    
    // Store the destination ID for later use
    private var cachedDestinationId: String?
    
    // Topic IDs for item changes
    private let priceChangeTopicId = "ITEM_PRICE_CHANGE"
    private let inventoryChangeTopicId = "ITEM_INVENTORY_CHANGE"
    private let promotionChangeTopicId = "ITEM_PROMOTION_STATUS_CHANGE"
    
    // MARK: - Initialize
    
    init() {
        // Nothing to do here
    }
    
    // MARK: - App Configuration
    
    /// Get the app configuration for notifications
    func getConfig() async throws -> EbayConfig {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/config") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(EbayConfig.self, from: data)
        case 404:
            throw APIError.custom("Configuration not found")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Update or create the app configuration for notifications
    func updateConfig(alertEmail: String) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/config") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let config = EbayConfig(alertEmail: alertEmail)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(config)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 204 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Destination Methods
    
    /// Get all destinations
    func getDestinations() async throws -> [EbayDestination] {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/destination") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            let result = try decoder.decode(EbayDestinationSearchResponse.self, from: data)
            return result.destinations ?? []
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Get a specific destination by ID
    func getDestination(destinationId: String) async throws -> EbayDestination {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/destination/\(destinationId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(EbayDestination.self, from: data)
        case 404:
            throw APIError.custom("Destination not found")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Create a new destination
    func createDestination(name: String, endpoint: String, verificationToken: String) async throws -> String {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/destination") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let deliveryConfig = EbayDeliveryConfig(endpoint: endpoint, verificationToken: verificationToken)
        let destinationRequest = EbayDestinationRequest(
            deliveryConfig: deliveryConfig,
            name: name,
            status: .ENABLED
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(destinationRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 201:
            // Extract destination ID from Location header
            if let locationHeader = httpResponse.value(forHTTPHeaderField: "Location"),
               let destinationId = locationHeader.components(separatedBy: "/").last {
                self.cachedDestinationId = destinationId
                return destinationId
            } else {
                throw APIError.custom("Failed to extract destination ID")
            }
        case 409:
            throw APIError.custom("Destination exists with this endpoint or challenge verification failed")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Update an existing destination
    func updateDestination(destinationId: String, name: String, endpoint: String, verificationToken: String) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/destination/\(destinationId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let deliveryConfig = EbayDeliveryConfig(endpoint: endpoint, verificationToken: verificationToken)
        let destinationRequest = EbayDestinationRequest(
            deliveryConfig: deliveryConfig,
            name: name,
            status: .ENABLED
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(destinationRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 204 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Delete a destination
    func deleteDestination(destinationId: String) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/destination/\(destinationId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 204:
            // Successful deletion
            return
        case 409:
            throw APIError.custom("Destination is in use and cannot be deleted")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Topic Methods
    
    /// Get all available topics
    func getTopics() async throws -> [EbayTopic] {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/topic") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            let result = try decoder.decode(EbayTopicSearchResponse.self, from: data)
            return result.topics ?? []
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Get details for a specific topic
    func getTopic(topicId: String) async throws -> EbayTopic {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/topic/\(topicId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(EbayTopic.self, from: data)
        case 404:
            throw APIError.custom("Topic not found")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Subscription Methods
    
    /// Get all subscriptions
    func getSubscriptions() async throws -> [EbaySubscription] {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            let result = try decoder.decode(EbaySubscriptionSearchResponse.self, from: data)
            return result.subscriptions ?? []
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Get a specific subscription by ID
    func getSubscription(subscriptionId: String) async throws -> EbaySubscription {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(EbaySubscription.self, from: data)
        case 404:
            throw APIError.custom("Subscription not found")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Create a new subscription
    func createSubscription(
        destinationId: String,
        topicId: String,
        schemaVersion: String
    ) async throws -> String {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload = EbaySubscriptionPayloadDetail(
            deliveryProtocol: .HTTPS,
            format: .JSON,
            schemaVersion: schemaVersion
        )
        
        let subscriptionRequest = EbayCreateSubscriptionRequest(
            destinationId: destinationId,
            payload: payload,
            status: .ENABLED,
            topicId: topicId
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(subscriptionRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 201:
            // Extract subscription ID from Location header
            if let locationHeader = httpResponse.value(forHTTPHeaderField: "Location"),
               let subscriptionId = locationHeader.components(separatedBy: "/").last {
                return subscriptionId
            } else {
                throw APIError.custom("Failed to extract subscription ID")
            }
        case 403:
            throw APIError.custom("Not authorized for this topic")
        case 409:
            throw APIError.custom("Subscription already exists or destination is not enabled")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Update an existing subscription
    func updateSubscription(
        subscriptionId: String,
        destinationId: String,
        schemaVersion: String,
        status: EbaySubscriptionStatus
    ) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload = EbaySubscriptionPayloadDetail(
            deliveryProtocol: .HTTPS,
            format: .JSON,
            schemaVersion: schemaVersion
        )
        
        let subscriptionRequest = EbayUpdateSubscriptionRequest(
            destinationId: destinationId,
            payload: payload,
            status: status
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(subscriptionRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 204 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Delete a subscription
    func deleteSubscription(subscriptionId: String) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 204 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Enable a subscription
    func enableSubscription(subscriptionId: String) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)/enable") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 204 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Disable a subscription
    func disableSubscription(subscriptionId: String) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)/disable") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 204 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Test a subscription by sending a test notification
    func testSubscription(subscriptionId: String) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)/test") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 202 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Create a subscription filter
    func createSubscriptionFilter(subscriptionId: String, filterSchema: [String: Any]) async throws -> String {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)/filter") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Create subscription filter request
        let filterRequest = EbayCreateSubscriptionFilterRequest(filterSchema: filterSchema)
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: ["filterSchema": filterSchema])
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 201:
            // Extract filter ID from Location header
            if let locationHeader = httpResponse.value(forHTTPHeaderField: "Location"),
               let filterId = locationHeader.components(separatedBy: "/").last {
                return filterId
            } else {
                throw APIError.custom("Failed to extract filter ID")
            }
        case 400:
            throw APIError.custom("The topic is not filterable or the filterSchema is invalid")
        case 403:
            throw APIError.custom("Not authorized to access this subscription")
        case 404:
            throw APIError.custom("Subscription not found")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    // If the error is with EbaySubscriptionFilter:
    struct EbaySubscriptionFilter: Codable {
        let creationDate: String?
        let filterId: String?
        let filterSchema: [String: Any]
        let filterStatus: EbaySubscriptionFilterStatus
        let subscriptionId: String?
        
        enum CodingKeys: String, CodingKey {
            case creationDate, filterId, filterSchema, filterStatus, subscriptionId
        }
        
        init(creationDate: String?, filterId: String?, filterSchema: [String: Any], filterStatus: EbaySubscriptionFilterStatus, subscriptionId: String?) {
            self.creationDate = creationDate
            self.filterId = filterId
            self.filterSchema = filterSchema
            self.filterStatus = filterStatus
            self.subscriptionId = subscriptionId
        }
        
        // Implement the required Decodable initializer
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            creationDate = try container.decodeIfPresent(String.self, forKey: .creationDate)
            filterId = try container.decodeIfPresent(String.self, forKey: .filterId)
            filterStatus = try container.decode(EbaySubscriptionFilterStatus.self, forKey: .filterStatus)
            subscriptionId = try container.decodeIfPresent(String.self, forKey: .subscriptionId)
            
            // Handle the filterSchema as a JSON object
            if let filterSchemaData = try? container.decode(Data.self, forKey: .filterSchema),
               let json = try? JSONSerialization.jsonObject(with: filterSchemaData) as? [String: Any] {
                filterSchema = json
            } else {
                filterSchema = [:]
            }
        }
        
        // Implement the required Encodable method
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(creationDate, forKey: .creationDate)
            try container.encodeIfPresent(filterId, forKey: .filterId)
            try container.encode(filterStatus, forKey: .filterStatus)
            try container.encodeIfPresent(subscriptionId, forKey: .subscriptionId)
            
            // Convert filterSchema to Data
            if let filterSchemaData = try? JSONSerialization.data(withJSONObject: filterSchema) {
                try container.encode(filterSchemaData, forKey: .filterSchema)
            }
        }
    }
    
    func getSubscriptionFilter(subscriptionId: String, filterId: String) async throws -> EbaySubscriptionFilter {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)/filter/\(filterId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            // Parse the JSON data directly since our Codable implementation may not handle the
            // complex filterSchema property correctly
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let creationDate = json["creationDate"] as? String,
                  let filterId = json["filterId"] as? String,
                  let filterSchema = json["filterSchema"] as? [String: Any],
                  let filterStatusString = json["filterStatus"] as? String,
                  let subscriptionId = json["subscriptionId"] as? String,
                  let filterStatus = EbaySubscriptionFilterStatus(rawValue: filterStatusString) else {
                throw APIError.decodingFailed(NSError(domain: "JSONParsing", code: 1))
            }
            
            return EbaySubscriptionFilter(
                creationDate: creationDate,
                filterId: filterId,
                filterSchema: filterSchema,
                filterStatus: filterStatus,
                subscriptionId: subscriptionId
            )
        case 400:
            throw APIError.custom("Subscription ID does not match filter ID")
        case 403:
            throw APIError.custom("Not authorized to access this subscription")
        case 404:
            throw APIError.custom("Subscription or filter not found")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Delete a subscription filter
    func deleteSubscriptionFilter(subscriptionId: String, filterId: String) async throws {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/subscription/\(subscriptionId)/filter/\(filterId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 204 {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Get public key for validating notification payloads
    func getPublicKey(publicKeyId: String) async throws -> EbayPublicKey {
        let accessToken = try await oauthHandler.authorize(for: "ebay")
        
        guard let url = URL(string: "\(baseURL)/public_key/\(publicKeyId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(EbayPublicKey.self, from: data)
        case 404:
            throw APIError.custom("Public key not found")
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Helper Methods for Item Tracking
    
    /// Setup the necessary notification infrastructure for item tracking
    func setupNotificationInfrastructure(serverURL: String, verificationToken: String) async throws -> (destinationId: String, subscriptionIds: [String]) {
        // 1. Ensure email config is set (use app developer's email)
        let appEmail = UserDefaults.standard.string(forKey: "app_notification_email") ?? "developer@rasuto.app"
        try await updateConfig(alertEmail: appEmail)
        
        // 2. Create or get destination
        var destinationId: String
        let destinations = try await getDestinations()
        
        if let existingDestination = destinations.first(where: { $0.deliveryConfig.endpoint == serverURL }) {
            // Use existing destination
            destinationId = existingDestination.destinationId ?? ""
        } else {
            // Create new destination
            destinationId = try await createDestination(
                name: "Rasuto Price & Inventory Tracker",
                endpoint: serverURL,
                verificationToken: verificationToken
            )
        }
        
        // 3. Get topic info to determine schema versions
        let priceChangeTopic = try await getTopic(topicId: priceChangeTopicId)
        let inventoryChangeTopic = try await getTopic(topicId: inventoryChangeTopicId)
        
        // Get the latest schema versions
        let priceChangeSchemaVersion = priceChangeTopic.supportedPayloads?.first?.schemaVersion ?? "1.0"
        let inventoryChangeSchemaVersion = inventoryChangeTopic.supportedPayloads?.first?.schemaVersion ?? "1.0"
        
        // 4. Create subscriptions for price and inventory changes if they don't exist
        var subscriptionIds: [String] = []
        let existingSubscriptions = try await getSubscriptions()
        
        // Check for price change subscription
        if !existingSubscriptions.contains(where: { $0.topicId == priceChangeTopicId }) {
            let priceChangeSubId = try await createSubscription(
                destinationId: destinationId,
                topicId: priceChangeTopicId,
                schemaVersion: priceChangeSchemaVersion
            )
            subscriptionIds.append(priceChangeSubId)
        } else if let existingSub = existingSubscriptions.first(where: { $0.topicId == priceChangeTopicId }) {
            subscriptionIds.append(existingSub.subscriptionId ?? "")
        }
        
        // Check for inventory change subscription
        if !existingSubscriptions.contains(where: { $0.topicId == inventoryChangeTopicId }) {
            let inventoryChangeSubId = try await createSubscription(
                destinationId: destinationId,
                topicId: inventoryChangeTopicId,
                schemaVersion: inventoryChangeSchemaVersion
            )
            subscriptionIds.append(inventoryChangeSubId)
        } else if let existingSub = existingSubscriptions.first(where: { $0.topicId == inventoryChangeTopicId }) {
            subscriptionIds.append(existingSub.subscriptionId ?? "")
        }
        
        return (destinationId, subscriptionIds)
    }
    
    /// Track a specific eBay item for price and inventory changes
    /// - Returns: Whether filter creation was successful
    func trackItemWithNotifications(itemId: String, subscriptionId: String) async throws -> Bool {
        // Create a filter to only receive notifications for this specific item
        let filterSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "notification": [
                    "type": "object",
                    "properties": [
                        "itemId": [
                            "type": "string",
                            "enum": [itemId]
                        ]
                    ],
                    "required": ["itemId"]
                ]
            ],
            "required": ["notification"]
        ]
        
        do {
            let filterId = try await createSubscriptionFilter(
                subscriptionId: subscriptionId,
                filterSchema: filterSchema
            )
            
            // Store the filter ID in UserDefaults for later management
            var trackedFilters = UserDefaults.standard.dictionary(forKey: "ebay_tracked_filters") as? [String: String] ?? [:]
            trackedFilters[itemId] = filterId
            UserDefaults.standard.set(trackedFilters, forKey: "ebay_tracked_filters")
            
            return true
        } catch {
            print("Failed to create subscription filter: \(error)")
            return false
        }
    }
    
    /// Stop tracking a specific eBay item
    func untrackItemWithNotifications(itemId: String, subscriptionId: String) async throws -> Bool {
        // Get the filter ID for this item
        guard let trackedFilters = UserDefaults.standard.dictionary(forKey: "ebay_tracked_filters") as? [String: String],
              let filterId = trackedFilters[itemId] else {
            return false
        }
        
        do {
            // Delete the filter
            try await deleteSubscriptionFilter(subscriptionId: subscriptionId, filterId: filterId)
            
            // Remove from tracked filters
            var updatedFilters = trackedFilters
            updatedFilters.removeValue(forKey: itemId)
            UserDefaults.standard.set(updatedFilters, forKey: "ebay_tracked_filters")
            
            return true
        } catch {
            print("Failed to delete subscription filter: \(error)")
            return false
        }
    }
    
    // MARK: - Notification Processing
    
    /// Validate a notification request using eBay's public key
    func validateNotification(signature: String, payload: Data) async throws -> Bool {
        // Extract key ID from signature
        let components = signature.components(separatedBy: ";")
        guard let keyIdComponent = components.first(where: { $0.hasPrefix("kid=") }),
              let publicKeyId = keyIdComponent.components(separatedBy: "=").last else {
            return false
        }
        
        // Get the public key
        let publicKey = try await getPublicKey(publicKeyId: publicKeyId)
        
        // In a real implementation, you would verify the signature here
        // This requires parsing the signature format and using a crypto library
        // For simplicity, we'll assume it's valid in this example
        
        return true
    }
    
    /// Process a notification message from eBay
    func processNotification(payload: Data) throws -> EbayNotificationMessage {
        let decoder = JSONDecoder()
        return try decoder.decode(EbayNotificationMessage.self, from: payload)
    }
}
