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
    // eBay integration provided via SerpAPI
    // @StateObject private var bestBuyPriceTracker = createBestBuyPriceTracker() // DISABLED: Causing startup delays
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var appState: AppFlowState = .splash
    
    enum AppFlowState {
        case splash
        case onboarding
        case main
    }
    
    // Add immediate debug
    private let debugMessage = {
        print("🚀🚀🚀 RasutoApp struct is being initialized!")
        return "initialized"
    }()
    
    // MARK: - Initialization
    
    init() {
        print("🚀 RasutoApp init() called")
        print("🔧 Initial app state: \(appState)")
        
        // Only do essential UI setup in init() to avoid black screen
        setupAppearance()
        initializeDarkModeFromSystem()
        
        print("🔧 RasutoApp init() completed - UI ready")
        
        // Heavy initialization will be done on app appear
        Self.scheduleBackgroundInitialization()
    }
    
    // MARK: - Cache Warming
    
    private static func warmCacheForFirstLaunch() async {
        print("🔥 CACHE WARMING: Checking if first launch needs live data pre-population...")
        
        // Check if we have any cached products
        let persistentProducts = PersistentProductCache.shared.getAllProducts()
        
        if persistentProducts.isEmpty {
            print("🆕 FIRST LAUNCH DETECTED: No cached products found - warming cache with live data...")
            
            // Create a temporary search manager to populate cache
            let searchManager = UniversalSearchManager()
            await searchManager.warmCacheWithLiveData()
            
        } else {
            print("✅ CACHE ALREADY WARM: Found \(persistentProducts.count) cached products - no warming needed")
        }
    }
    
    // MARK: - Background Initialization
    
    private static func scheduleBackgroundInitialization() {
        // Schedule initialization without capturing self
        DispatchQueue.global(qos: .background).async {
            Task {
                await performBackgroundInitialization()
            }
        }
    }
    
    private static func performBackgroundInitialization() async {
        print("🔄 Starting lightweight background initialization...")
        
        // OPTIMIZED: Only essential initialization for faster startup
        // Defer heavy API setup until actually needed
        
        // Allow live data for development while protecting quota (lightweight)
        await QuotaProtectionManager.shared.disableDemoMode()
        print("🚀 Live data enabled for testing - quota protection still active for excessive usage")
        
        // Cache warming for first launch - ensure live data shows immediately
        await warmCacheForFirstLaunch()
        
        // Defer API initialization to when services are first accessed
        DispatchQueue.global(qos: .utility).async {
            let apiConfig = APIConfig()
            apiConfig.initializeAPIKeys()
            // Skip BestBuy API initialization - not needed
            // apiConfig.initializeBestBuyAPI() // DISABLED
            
            // Apply eBay OAuth bypass for network reliability
            // eBay OAuth bypass removed - using SerpAPI eBay integration
            print("✅ Deferred API initialization completed")
        }
        
        print("✅ Background initialization completed")
    }
    
    // MARK: - App Scene
    
    var body: some Scene {
        WindowGroup {
            Group {
                let _ = print("🚀 EVALUATING APP STATE: \(appState)")
                
                switch appState {
                case .splash:
                    let _ = print("✅ SHOWING SPLASH SCREEN")
                    SplashScreenWrapper(appState: $appState)
                    .onAppear {
                        print("🔧 Splash screen wrapper appeared")
                    }
                    
                case .onboarding:
                    let _ = print("✅ SHOWING ONBOARDING")
                    RasutoOnboardingView(isPresented: Binding(
                        get: { appState == .onboarding },
                        set: { isPresented in
                            if !isPresented {
                                print("🎬 Onboarding dismissed - transitioning to main")
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    appState = .main
                                }
                            }
                        }
                    ))
                    .onAppear {
                        print("🎬 Onboarding appeared!")
                    }
                    
                case .main:
                    let _ = print("✅ SHOWING SEARCH VIEW")
                    SearchView()
                        // All integrations via SerpAPI - no separate environment objects needed
                        .environmentObject(networkMonitorProxy)
                        .onAppear {
                            print("🏠 SearchView appeared - main app flow")
                            // Apply user's preferred color scheme
                            applyStoredColorScheme()
                        }
                }
            }
            .modelContainer(for: [ProductItem.self, Collection.self, ProductSpecification.self, ProductVariant.self, TrackedProductModel.self, NotificationPreferences.self])
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    print("📱 App became active - applying user preferences")
                    applyStoredColorScheme()
                case .inactive:
                    print("📱 App became inactive")
                case .background:
                    print("📱 App went to background")
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupAppearance() {
        // Configure global appearance settings
        UINavigationBar.appearance().tintColor = .systemBlue
    }
    
    private func initializeDarkModeFromSystem() {
        print("🌓 Detecting system color scheme preference...")
        
        // Check if user has already set a preference manually
        let hasExistingPreference = UserDefaults.standard.object(forKey: "isDarkMode") != nil
        
        if !hasExistingPreference {
            // First time launch - detect system preference
            let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
            print("🌓 System preference detected: \(systemIsDark ? "Dark" : "Light") mode")
            
            UserDefaults.standard.set(systemIsDark, forKey: "isDarkMode")
            isDarkMode = systemIsDark
        } else {
            // User has existing preference - respect it
            let userPreference = UserDefaults.standard.bool(forKey: "isDarkMode")
            isDarkMode = userPreference
            print("🌓 Using stored user preference: \(userPreference ? "Dark" : "Light") mode")
        }
        
        // Apply the determined color scheme
        applyColorScheme(isDark: isDarkMode)
    }
    
    private func applyStoredColorScheme() {
        let userDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        applyColorScheme(isDark: userDarkMode)
    }
    
    private func applyColorScheme(isDark: Bool) {
        Task { @MainActor in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = isDark ? .dark : .light
                    print("🌓 Applied \(isDark ? "dark" : "light") mode to window")
                }
            }
        }
    }
    
    // MARK: - API Configuration
    
    private func checkAPICredentials() {
        Task {
            // Check if essential API credentials are set up
            let hasSerpAPI = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.serpAPI)
            let hasAxesso = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.axessoAmazon)
            let hasOxylabs = APIKeyManager.shared.hasAPIKey(for: APIConfig.Service.oxylabs)
            
            if !hasSerpAPI {
                print("⚠️ SerpAPI credentials missing - primary search layer unavailable")
            }
            if !hasAxesso {
                print("⚠️ Axesso credentials missing - Amazon fallback unavailable")
            }
            if !hasOxylabs {
                print("⚠️ Oxylabs credentials missing - scraper fallback unavailable")
            }
            
            if hasSerpAPI && hasAxesso && hasOxylabs {
                print("✅ All API layers configured: SerpAPI (primary) + Axesso (Amazon) + Oxylabs (fallback)")
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
    @Binding var appState: RasutoApp.AppFlowState
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
            // Show name immediately with spring animation
            showName = true
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Show tagline after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showTagline = true
                }
            }
            
            // Hide splash screen - reduced timing for faster loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    opacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    print("🎬 Splash completed - transitioning to onboarding")
                    appState = .onboarding
                }
            }
        }
    }
}
