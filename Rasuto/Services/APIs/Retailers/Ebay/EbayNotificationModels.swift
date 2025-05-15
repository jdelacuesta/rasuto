//
//  EbayNotificationModels.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/30/25.
//

import Foundation

// MARK: - Notification API Models

// Configuration model
struct EbayConfig: Codable {
    let alertEmail: String
    
    enum CodingKeys: String, CodingKey {
        case alertEmail
    }
}

// Destination models
struct EbayDestination: Codable {
    let deliveryConfig: EbayDeliveryConfig
    let destinationId: String?
    let name: String
    let status: EbayDestinationStatus
    
    enum CodingKeys: String, CodingKey {
        case deliveryConfig, destinationId, name, status
    }
}

struct EbayDeliveryConfig: Codable {
    let endpoint: String
    let verificationToken: String
    
    enum CodingKeys: String, CodingKey {
        case endpoint, verificationToken
    }
}

enum EbayDestinationStatus: String, Codable {
    case ENABLED
    case DISABLED
    case MARKED_DOWN
}

struct EbayDestinationRequest: Codable {
    let deliveryConfig: EbayDeliveryConfig
    let name: String
    let status: EbayDestinationStatus
    
    enum CodingKeys: String, CodingKey {
        case deliveryConfig, name, status
    }
}

struct EbayDestinationSearchResponse: Codable {
    let destinations: [EbayDestination]?
    let href: String?
    let limit: Int?
    let next: String?
    let total: Int?
    
    enum CodingKeys: String, CodingKey {
        case destinations, href, limit, next, total
    }
}

// Subscription models
struct EbaySubscription: Codable {
    let creationDate: String?
    let destinationId: String
    let filterId: String?
    let payload: EbaySubscriptionPayloadDetail
    let status: EbaySubscriptionStatus
    let subscriptionId: String?
    let topicId: String
    
    enum CodingKeys: String, CodingKey {
        case creationDate, destinationId, filterId, payload, status, subscriptionId, topicId
    }
}

struct EbaySubscriptionPayloadDetail: Codable {
    let deliveryProtocol: EbayProtocolEnum
    let format: EbayFormatTypeEnum
    let schemaVersion: String
    
    enum CodingKeys: String, CodingKey {
        case deliveryProtocol, format, schemaVersion
    }
}

enum EbaySubscriptionStatus: String, Codable {
    case ENABLED
    case DISABLED
}

enum EbayProtocolEnum: String, Codable {
    case HTTPS
}

enum EbayFormatTypeEnum: String, Codable {
    case JSON
}

struct EbayCreateSubscriptionRequest: Codable {
    let destinationId: String
    let payload: EbaySubscriptionPayloadDetail
    let status: EbaySubscriptionStatus
    let topicId: String
    
    enum CodingKeys: String, CodingKey {
        case destinationId, payload, status, topicId
    }
}

struct EbayUpdateSubscriptionRequest: Codable {
    let destinationId: String
    let payload: EbaySubscriptionPayloadDetail
    let status: EbaySubscriptionStatus
    
    enum CodingKeys: String, CodingKey {
        case destinationId, payload, status
    }
}

struct EbaySubscriptionSearchResponse: Codable {
    let href: String?
    let limit: Int?
    let next: String?
    let subscriptions: [EbaySubscription]?
    let total: Int?
    
    enum CodingKeys: String, CodingKey {
        case href, limit, next, subscriptions, total
    }
}

// Topic models
struct EbayTopic: Codable {
    let authorizationScopes: [String]?
    let context: String?
    let description: String?
    let filterable: Bool?
    let scope: String?
    let status: String?
    let supportedPayloads: [EbayPayloadDetail]?
    let topicId: String
    
    enum CodingKeys: String, CodingKey {
        case authorizationScopes, context, description, filterable, scope, status, supportedPayloads, topicId
    }
}

struct EbayPayloadDetail: Codable {
    let deliveryProtocol: EbayProtocolEnum
    let deprecated: Bool?
    let format: [EbayFormatTypeEnum]?
    let schemaVersion: String
    
    enum CodingKeys: String, CodingKey {
        case deliveryProtocol, deprecated, format, schemaVersion
    }
}

struct EbayTopicSearchResponse: Codable {
    let href: String?
    let limit: Int?
    let next: String?
    let topics: [EbayTopic]?
    let total: Int?
    
    enum CodingKeys: String, CodingKey {
        case href, limit, next, topics, total
    }
}

// Subscription filter models
struct EbaySubscriptionFilter: Codable {
    let creationDate: String?
    let filterId: String?
    let filterSchema: [String: Any]
    let filterStatus: EbaySubscriptionFilterStatus
    let subscriptionId: String?
    
    enum CodingKeys: String, CodingKey {
        case creationDate, filterId, filterSchema, filterStatus, subscriptionId
    }
    
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

enum EbaySubscriptionFilterStatus: String, Codable {
    case ENABLED
    case DISABLED
    case PENDING
}

struct EbayCreateSubscriptionFilterRequest: Codable {
    let filterSchema: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case filterSchema
    }
    
    init(filterSchema: [String: Any]) {
        self.filterSchema = filterSchema
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle the filterSchema as a JSON object
        if let filterSchemaData = try? container.decode(Data.self, forKey: .filterSchema),
           let json = try? JSONSerialization.jsonObject(with: filterSchemaData) as? [String: Any] {
            filterSchema = json
        } else {
            filterSchema = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Convert filterSchema to Data
        if let filterSchemaData = try? JSONSerialization.data(withJSONObject: filterSchema) {
            try container.encode(filterSchemaData, forKey: .filterSchema)
        }
    }
}

// Public key model
struct EbayPublicKey: Codable {
    let algorithm: String?
    let digest: String?
    let key: String
    
    enum CodingKeys: String, CodingKey {
        case algorithm, digest, key
    }
}

// Notification message model
struct EbayNotificationMessage: Codable {
    let metadata: EbayNotificationMetadata
    let notification: [String: Any]
    let notificationId: String
    let publishDate: String
    let publisherId: String
    let topic: String
    
    enum CodingKeys: String, CodingKey {
        case metadata, notification, notificationId, publishDate, publisherId, topic
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decode(EbayNotificationMetadata.self, forKey: .metadata)
        notificationId = try container.decode(String.self, forKey: .notificationId)
        publishDate = try container.decode(String.self, forKey: .publishDate)
        publisherId = try container.decode(String.self, forKey: .publisherId)
        topic = try container.decode(String.self, forKey: .topic)
        
        // Handle the notification payload as a generic JSON object
        if let notificationData = try? container.decode(Data.self, forKey: .notification),
           let json = try? JSONSerialization.jsonObject(with: notificationData) as? [String: Any] {
            notification = json
        } else {
            notification = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(notificationId, forKey: .notificationId)
        try container.encode(publishDate, forKey: .publishDate)
        try container.encode(publisherId, forKey: .publisherId)
        try container.encode(topic, forKey: .topic)
        
        // Convert notification to Data
        if let notificationData = try? JSONSerialization.data(withJSONObject: notification) {
            try container.encode(notificationData, forKey: .notification)
        }
    }
}

struct EbayNotificationMetadata: Codable {
    let schemaVersion: String
    let topic: String
    
    enum CodingKeys: String, CodingKey {
        case schemaVersion, topic
    }
}
