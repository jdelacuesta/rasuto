//
//  APIService.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/23/25.
//

import Foundation
import Combine
import SwiftData

// Main API Service protocol that all retailer-specific services will conform to
protocol RetailerAPIService {
    func searchProducts(query: String) -> AnyPublisher<[ProductItem], Error>
    func getProductDetails(id: String) -> AnyPublisher<ProductItem, Error>
    func getRelatedProducts(id: String) -> AnyPublisher<[ProductItem], Error>
}

// Shared API errors
enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case rateLimitExceeded
    case authenticationFailed
    case serverError(Int)
    case noData
    case custom(String)
}

// Base API Service with shared functionality
class BaseAPIService {
    let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetch<T: Decodable>(_ url: URL, headers: [String: String] = [:]) -> AnyPublisher<T, Error> {
        var request = URLRequest(url: url)
        
        // Add headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401, 403:
                    throw APIError.authenticationFailed
                case 429:
                    throw APIError.rateLimitExceeded
                case 500...599:
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    throw APIError.invalidResponse
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else if let decodingError = error as? DecodingError {
                    return APIError.decodingFailed(decodingError)
                } else {
                    return APIError.requestFailed(error)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - API Key Storage

// Secure API key management using the Keychain
class APIKeyManager {
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case unexpectedStatus(OSStatus)
    }
    
    static let shared = APIKeyManager()
    
    private init() {}
    
    func saveAPIKey(for service: String, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try updateAPIKey(for: service, key: key)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func updateAPIKey(for service: String, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: key.data(using: .utf8)!
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func getAPIKey(for service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        return key
    }
    
    func deleteAPIKey(for service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
