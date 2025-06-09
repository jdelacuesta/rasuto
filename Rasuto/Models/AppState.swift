//
//  AppState.swift
//  Rasuto
//
//  Created by demo mode implementation on 5/29/25.
//

import SwiftUI
import Combine

public enum AppMode {
    case demo
    case authenticated
}

public class AppState: ObservableObject {
    @Published public var appMode: AppMode = .demo
    @Published public var isOnboardingComplete: Bool = false
    @Published public var currentUser: User? = nil
    
    public static let shared = AppState()
    
    private init() {
        loadSavedState()
    }
    
    public func setDemoMode() {
        appMode = .demo
        isOnboardingComplete = true
        saveState()
    }
    
    public func setAuthenticatedMode(user: User) {
        appMode = .authenticated
        currentUser = user
        isOnboardingComplete = true
        saveState()
    }
    
    func resetToOnboarding() {
        appMode = .demo
        isOnboardingComplete = false
        currentUser = nil
        saveState()
    }
    
    private func saveState() {
        UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete")
        UserDefaults.standard.set(appMode == .demo, forKey: "isDemoMode")
    }
    
    private func loadSavedState() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        let isDemoMode = UserDefaults.standard.bool(forKey: "isDemoMode")
        appMode = isDemoMode ? .demo : .authenticated
    }
}

public struct User {
    public let id: String
    public let email: String
    public let name: String?
    
    public init(id: String, email: String, name: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
    }
}