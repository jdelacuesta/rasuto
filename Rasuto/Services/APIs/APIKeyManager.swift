//
//  APIKeyManager.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//
import Foundation
import Security

/// Manages secure storage and retrieval of API keys using the iOS Keychain
class APIKeyManager {
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case unexpectedStatus(OSStatus)
        case encodingError
        case decodingError
    }
    
    static let shared = APIKeyManager()
    
    // Private initializer to enforce singleton pattern
    private init() {}
    
    /// Sets an API key in the keychain (convenience method)
    /// - Parameters:
    ///   - key: The API key to save
    ///   - service: The service identifier
    /// - Returns: Boolean indicating success
    @discardableResult
    func setAPIKey(_ key: String, for service: String) -> Bool {
        do {
            try saveAPIKey(for: service, key: key)
            return true
        } catch {
            print("Error setting API key: \(error)")
            return false
        }
    }
    
    /// Saves an API key to the keychain
    /// - Parameters:
    ///   - key: The API key to save
    ///   - service: The service identifier (e.g., "com.rasuto.api.bestbuy")
    /// - Throws: KeychainError if the operation fails
    func saveAPIKey(for service: String, key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        
        // Query to check if item exists
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Attributes for the new item
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Add the new item
        let status = SecItemAdd(attributes as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Retrieves an API key from the keychain
    /// - Parameter service: The service identifier
    /// - Returns: The API key as a string
    /// - Throws: KeychainError if the operation fails
    func getAPIKey(for service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingError
        }
        
        return key
    }
    
    /// Updates an existing API key in the keychain
    /// - Parameters:
    ///   - key: The new API key
    ///   - service: The service identifier
    /// - Throws: KeychainError if the operation fails
    func updateAPIKey(_ key: String, for service: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Deletes all API keys managed by the app
    /// - Parameter services: An array of service identifiers
    /// - Throws: KeychainError if any operation fails
    func deleteAllAPIKeys(for services: [String]) throws {
        for service in services {
            try deleteAPIKey(for: service)
        }
    }
    
    /// Checks if an API key exists for a service
    /// - Parameter service: The service identifier
    /// - Returns: True if the key exists, false otherwise
    func hasAPIKey(for service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Deletes an API key from the keychain
    /// - Parameter service: The service identifier
    /// - Throws: KeychainError if the operation fails
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

