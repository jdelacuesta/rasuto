//
//  OAuthHandler.swift
//  Rasuto
//
//  Created for Rasuto on 4/28/25.
//

import Foundation
import AuthenticationServices

enum OAuthError: Error {
    case authorizationFailed
    case tokenExchangeFailed
    case invalidState
    case missingConfiguration
    case tokenExpired
    case refreshFailed
    case userCancelled
    case invalidCredentials
}

class OAuthHandler: NSObject, ObservableObject {
    // MARK: - Properties
    
    @Published var isAuthenticated = false
    
    // OAuth configuration
    private struct OAuthConfig {
        let clientID: String
        let clientSecret: String
        let redirectURI: String
        let authorizationEndpoint: String
        let tokenEndpoint: String
        let scope: String
    }
    
    // Service configurations
    private var configurations: [String: OAuthConfig] = [:]
    
    // Token storage
    private struct TokenInfo: Codable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date
        let tokenType: String
    }
    
    private var tokens: [String: TokenInfo] = [:]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Load saved tokens
        loadTokens()
        
        // Setup service configurations
        setupServiceConfigs()
    }
    
    // MARK: - Configuration
    
    private func setupServiceConfigs() {
        // Setup eBay configuration
        do {
            let ebayClientID = try APIConfig.getAPIKey(for: APIConfig.Service.ebayClientID)
            let ebayClientSecret = try APIConfig.getAPIKey(for: APIConfig.Service.ebayClientSecret)
            
            configurations["ebay"] = OAuthConfig(
                clientID: ebayClientID,
                clientSecret: ebayClientSecret,
                redirectURI: "rasuto://oauth/callback",
                authorizationEndpoint: "https://auth.ebay.com/oauth2/authorize",
                tokenEndpoint: "https://api.ebay.com/identity/v1/oauth2/token",
                scope: "https://api.ebay.com/oauth/api_scope https://api.ebay.com/oauth/api_scope/commerce.notification.subscription"
            )
        } catch {
            print("Failed to load eBay OAuth configuration: \(error)")
        }
        
        // Add other service configurations as needed
    }
    
    // MARK: - Authentication
    
    /// Main method to get an access token - will use client credentials for app-only access
    /// or full OAuth flow for user-specific access depending on the service and needs
    /// 
    func authorize(for service: String) async throws -> String {
        // For eBay Browse/Feed APIs, we use client credentials flow (app-only)
        if service == "ebay" {
            return try await getClientCredentialsToken(for: service)
        } else {
            // For other services or user-specific operations, use authorization code flow
            return try await getAuthorizationCodeToken(for: service)
        }
    }
    
    /// Get access token using client credentials flow (app-only access)
    private func getClientCredentialsToken(for service: String) async throws -> String {
        print("OAuth: Getting client credentials token for service: \(service)")
        
        // Check if we have a valid token already
        if let tokenInfo = tokens[service], tokenInfo.expiresAt > Date().addingTimeInterval(60) {
            print("OAuth: Using existing token (expires: \(tokenInfo.expiresAt))")
            return tokenInfo.accessToken
        }
        
        guard let config = configurations[service] else {
            print("OAuth: Missing configuration for service: \(service)")
            throw OAuthError.missingConfiguration
        }
        
        // Create authorization header from client ID and secret
        let credentials = "\(config.clientID):\(config.clientSecret)"
            .data(using: .utf8)!
            .base64EncodedString()
        
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Set request body with appropriate scopes
        let body = "grant_type=client_credentials&scope=\(config.scope)"
        request.httpBody = body.data(using: .utf8)
        
        print("OAuth: Requesting token from \(config.tokenEndpoint)")
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("OAuth: Invalid response")
            throw OAuthError.tokenExchangeFailed
        }
        
        print("OAuth: Response status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("OAuth Error: \(responseString)")
            throw OAuthError.tokenExchangeFailed
        }
        
        // Parse response
        do {
            let tokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)
            
            // Calculate expiration date
            let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
            
            // Save token info
            let tokenInfo = TokenInfo(
                accessToken: tokenResponse.access_token,
                refreshToken: nil, // Client credentials flow doesn't use refresh tokens
                expiresAt: expiresAt,
                tokenType: tokenResponse.token_type
            )
            
            tokens[service] = tokenInfo
            saveTokens()
            
            print("OAuth: Successfully obtained new token (expires: \(expiresAt))")
            
            // Update authentication status
            DispatchQueue.main.async {
                self.isAuthenticated = true
            }
            
            return tokenResponse.access_token
        } catch {
            print("OAuth Error decoding response: \(error)")
            throw OAuthError.tokenExchangeFailed
        }
    }
    
    /// Get access token using authorization code flow (user-specific access)
    private func getAuthorizationCodeToken(for service: String) async throws -> String {
        guard let config = configurations[service] else {
            throw OAuthError.missingConfiguration
        }
        
        // Check if we already have a valid token
        if let tokenInfo = tokens[service], tokenInfo.expiresAt > Date() {
            return tokenInfo.accessToken
        }
        
        // Try to refresh if possible
        if let tokenInfo = tokens[service], let refreshToken = tokenInfo.refreshToken {
            do {
                return try await refreshAccessToken(for: service, refreshToken: refreshToken)
            } catch {
                // Continue with full auth if refresh fails
                print("Token refresh failed: \(error)")
            }
        }
        
        // Proceed with full authorization
        return try await performAuthorization(for: service, config: config)
    }
    
    private func performAuthorization(for service: String, config: OAuthConfig) async throws -> String {
        let state = UUID().uuidString
        
        // Build authorization URL
        var components = URLComponents(string: config.authorizationEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scope),
            URLQueryItem(name: "state", value: state)
        ]
        
        guard let authURL = components?.url else {
            throw OAuthError.authorizationFailed
        }
        
        // Create ASWebAuthenticationSession for OAuth flow
        return try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: URL(string: config.redirectURI)?.scheme
            ) { callbackURL, error in
                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: OAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuthError.authorizationFailed)
                    return
                }
                
                // Extract authorization code and validate state
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let queryItems = components.queryItems else {
                    continuation.resume(throwing: OAuthError.authorizationFailed)
                    return
                }
                
                // Check state to prevent CSRF
                guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
                      returnedState == state else {
                    continuation.resume(throwing: OAuthError.invalidState)
                    return
                }
                
                // Get authorization code
                guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: OAuthError.authorizationFailed)
                    return
                }
                
                // Exchange code for access token
                Task {
                    do {
                        let accessToken = try await self.exchangeCodeForToken(
                            service: service,
                            code: code,
                            config: config
                        )
                        continuation.resume(returning: accessToken)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Ensure the sheet is presented from the main thread
            DispatchQueue.main.async {
                authSession.presentationContextProvider = self
                authSession.prefersEphemeralWebBrowserSession = false
                
                if !authSession.start() {
                    continuation.resume(throwing: OAuthError.authorizationFailed)
                }
            }
        }
    }
    
    private func exchangeCodeForToken(service: String, code: String, config: OAuthConfig) async throws -> String {
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        
        // Create authorization header
        let credentials = "\(config.clientID):\(config.clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw OAuthError.tokenExchangeFailed
        }
        
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Set request body
        let requestBody = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI
        ]
        
        let bodyString = requestBody.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int,
              let tokenType = json["token_type"] as? String else {
            throw OAuthError.tokenExchangeFailed
        }
        
        let refreshToken = json["refresh_token"] as? String
        
        // Calculate expiration date
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        // Save token info
        let tokenInfo = TokenInfo(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            tokenType: tokenType
        )
        
        tokens[service] = tokenInfo
        saveTokens()
        
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        
        return accessToken
    }
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken(for service: String, refreshToken: String) async throws -> String {
        guard let config = configurations[service] else {
            throw OAuthError.missingConfiguration
        }
        
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        
        // Create authorization header
        let credentials = "\(config.clientID):\(config.clientSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw OAuthError.refreshFailed
        }
        
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Set request body
        let requestBody = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = requestBody.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.refreshFailed
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int,
              let tokenType = json["token_type"] as? String else {
            throw OAuthError.refreshFailed
        }
        
        // Get new refresh token if provided, otherwise keep the old one
        let newRefreshToken = json["refresh_token"] as? String ?? refreshToken
        
        // Calculate expiration date
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        // Save token info
        let tokenInfo = TokenInfo(
            accessToken: accessToken,
            refreshToken: newRefreshToken,
            expiresAt: expiresAt,
            tokenType: tokenType
        )
        
        tokens[service] = tokenInfo
        saveTokens()
        
        return accessToken
    }
    
    // MARK: - Token Storage
    
    private func saveTokens() {
        guard let encoded = try? JSONEncoder().encode(tokens) else {
            print("Failed to encode token data")
            return
        }
        
        let keychain = Keychain()
        do {
            try keychain.save(key: "rasuto.oauth.tokens", data: encoded)
        } catch {
            print("Failed to save tokens to keychain: \(error)")
        }
    }
    
    private func loadTokens() {
        let keychain = Keychain()
        do {
            let data = try keychain.retrieve(key: "rasuto.oauth.tokens")
            if let decoded = try? JSONDecoder().decode([String: TokenInfo].self, from: data) {
                tokens = decoded
                
                // Check if any service has a valid token
                DispatchQueue.main.async {
                    self.isAuthenticated = self.tokens.values.contains { $0.expiresAt > Date() }
                }
            }
        } catch {
            print("No saved tokens found or error loading tokens: \(error)")
        }
    }
    
    // MARK: - Logout
    
    func logout(for service: String? = nil) {
        if let service = service {
            tokens.removeValue(forKey: service)
        } else {
            tokens.removeAll()
        }
        
        saveTokens()
        
        DispatchQueue.main.async {
            self.isAuthenticated = !self.tokens.isEmpty
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthHandler: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Simple Keychain Wrapper

class Keychain {
    func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIKeyManager.KeychainError.unexpectedStatus(status)
        }
    }
    
    func retrieve(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            throw APIKeyManager.KeychainError.itemNotFound
        } else if status != errSecSuccess {
            throw APIKeyManager.KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data else {
            throw APIKeyManager.KeychainError.decodingError
        }
        
        return data
    }
}

// MARK: - Token Response Model

struct AccessTokenResponse: Decodable {
    let access_token: String
    let expires_in: Int
    let token_type: String
}
