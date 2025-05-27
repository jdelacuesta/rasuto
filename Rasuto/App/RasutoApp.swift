//
//  RasutoApp.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI
import SwiftData
import CloudKit

// MARK: - Main App

@main
struct RasutoApp: App {
    
    // MARK: - Properties
    
    @State private var appDelegateInitialized = false
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var networkMonitorProxy = NetworkMonitorProxy()
    @StateObject private var ebayNotificationManager = EbayNotificationManager()
    @StateObject private var bestBuyPriceTracker = createBestBuyPriceTracker()
    @Environment(\.scenePhase) private var scenePhase
    
    // Dark mode support
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    // Splash screen control
    @State private var showSplashScreen = true
    
    // MARK: - Initialization
    
    init() {
        // Setup CloudKit
        setupCloudKit()
        
        // Initialize API keys during app launch
        let apiConfig = APIConfig()
        apiConfig.initializeAPIKeys()
        apiConfig.initializeBestBuyAPI()
        
        // Setup appearance
        setupAppearance()
        
        // Setup development environment in debug mode
        #if DEBUG
        setupDevelopmentEnvironment()
        #endif
    }
    
    // MARK: - App Scene
    
    var body: some Scene {
        WindowGroup {
            if showSplashScreen {
                SplashScreenWrapper(showSplashScreen: $showSplashScreen)
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            } else {
                HomeView()
                    .environmentObject(ebayNotificationManager)
                    .environmentObject(bestBuyPriceTracker)
                    .environmentObject(networkMonitorProxy)
                    .overlay {
                        if !NetworkMonitor.shared.isConnected {
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: "wifi.slash")
                                    Text("No internet connection")
                                }
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding()
                                Spacer().frame(height: 50)
                            }
                        }
                    }
                    .preferredColorScheme(isDarkMode ? .dark : .light)
                    .onAppear {
                        // Configure app theme on launch
                        configureAppTheme()
                        print("App launched with Home View")
                    }
                    .onChange(of: scenePhase) { newPhase in
                        if newPhase == .active {
                            // Check for credentials and prompt to set them up if needed
                            checkAPICredentials()
                        }
                    }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupAppearance() {
        // Configure global appearance settings
        UINavigationBar.appearance().tintColor = .systemBlue
    }
    
    // Helper method to create BestBuyPriceTracker
    private static func createBestBuyPriceTracker() -> BestBuyPriceTracker {
        do {
            let apiConfig = APIConfig()
            let service = try apiConfig.createBestBuyService()
            return BestBuyPriceTracker(bestBuyService: service)
        } catch {
            print("Failed to create BestBuyPriceTracker: \(error)")
            // Return a mock tracker for now
            let mockService = BestBuyAPIService(apiKey: "MOCK_API_KEY")
            return BestBuyPriceTracker(bestBuyService: mockService)
        }
    }
    
    // MARK: - CloudKit Setup
    
    private func setupCloudKit() {
        let container = CKContainer(identifier: "iCloud.com.Rasuto")
        container.privateCloudDatabase.fetchAllRecordZones { zones, error in
            if let error = error {
                print("CloudKit setup failed: \(error)")
            } else {
                print("CloudKit setup success. Zones: \(zones ?? [])")
            }
        }
    }
    
    // MARK: - Theme Configuration
    
    private func configureAppTheme() {
        Task { @MainActor in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                }
            }
        }
    }
    
    // MARK: - API Configuration
    
    private func setupDevelopmentEnvironment() {
        // Setup test API keys
        let apiConfig = APIConfig()
        apiConfig.setupTestKeys()
    }
    
    private func checkAPICredentials() {
        Task {
            // Check if eBay credentials are set up
            let hasEbayKey = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.ebay)
            let hasEbayClientID = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.ebayClientID)
            let hasEbayClientSecret = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.ebayClientSecret)
            
            if !hasEbayKey || !hasEbayClientID || !hasEbayClientSecret {
                // In a real app, you would show a settings screen where the user can enter their credentials
                print("eBay API credentials not found. Please set them up.")
            }
        }
    }
}

// MARK: - NetworkMonitorProxy

// This class acts as a proxy to observe the singleton NetworkMonitor
// and make it work with SwiftUI's environment
class NetworkMonitorProxy: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var connectionType: NetworkMonitor.ConnectionType = .unknown
    
    init() {
        // Observe changes from the singleton
        isConnected = NetworkMonitor.shared.isConnected
        connectionType = NetworkMonitor.shared.connectionType
        
        // Set up notification observer to update when network status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: .networkConnectionStatusChanged,
            object: nil
        )
    }
    
    @objc private func networkStatusChanged() {
        updateConnectionStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateConnectionStatus() {
        DispatchQueue.main.async {
            self.isConnected = NetworkMonitor.shared.isConnected
            self.connectionType = NetworkMonitor.shared.connectionType
        }
    }
}

// Add this extension to NetworkMonitor.swift
extension Notification.Name {
    static let networkConnectionStatusChanged = Notification.Name("networkConnectionStatusChanged")
}

// MARK: - Splash Screen Wrapper

struct SplashScreenWrapper: View {
    @Binding var showSplashScreen: Bool
    @State private var scale = 0.8
    @State private var opacity = 0.0
    @State private var showName = false
    @State private var showTagline = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 4) {
                if showName {
                    Text("RASUTO")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
                
                if showTagline {
                    Text("Never miss the last one.")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
        }
        .onAppear {
            // Show name with spring animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showName = true
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
            
            // Show tagline after name animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showTagline = true
                }
            }
            
            // Hide splash screen with fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    opacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showSplashScreen = false
                }
            }
        }
    }
}
