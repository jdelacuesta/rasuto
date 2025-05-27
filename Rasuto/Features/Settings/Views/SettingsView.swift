//
//  SettingsView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Account Section
                Section("Account") {
                    NavigationLink {
                        Text("Profile View")
                    } label: {
                        Label("Profile", systemImage: "person.fill")
                    }
                    
                    NavigationLink {
                        Text("Preferences View")
                    } label: {
                        Label("Preferences", systemImage: "gearshape.fill")
                    }
                }
                
                // MARK: - Notifications Section
                Section("Notifications") {
                    NavigationLink {
                        Text("Alert Settings View")
                    } label: {
                        Label("Alert Settings", systemImage: "bell.fill")
                    }
                    
                    NavigationLink {
                        Text("Frequency View")
                    } label: {
                        Label("Frequency", systemImage: "clock.fill")
                    }
                }
                
                // MARK: - Support Section
                Section("Support") {
                    NavigationLink {
                        Text("Contact View")
                    } label: {
                        Label("Contact", systemImage: "envelope.fill")
                    }
                    
                    NavigationLink {
                        Text("Rate Us View")
                    } label: {
                        Label("Rate Us", systemImage: "star.fill")
                    }
                    
                    // Version information
                    HStack {
                        Label("Version", systemImage: "info.circle.fill")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.gray)
                    }
                    
                    // Legal items moved here
                    NavigationLink {
                        Text("Privacy Policy View")
                    } label: {
                        Label("Privacy Policy", systemImage: "lock.shield.fill")
                    }
                    
                    NavigationLink {
                        Text("Terms of Service View")
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                }
                
                // MARK: - Dark Mode Toggle
                Section("Enable Dark Mode") {
                    Toggle(isOn: $isDarkMode) {
                        HStack {
                            Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(isDarkMode ? .purple : .orange)
                            Text("Dark Mode")
                        }
                    }
                    .onChange(of: isDarkMode) { newValue in
                        setAppearance(isDark: newValue)
                    }
                }
            }
            .navigationTitle("Settings")
            // Reduce spacing between sections
            .environment(\.defaultMinListRowHeight, 40) // Reduce default row height
            .environment(\.defaultMinListHeaderHeight, 25) // Reduce section header height
            .listStyle(InsetGroupedListStyle()) // More compact list style
            .onAppear {
                // Ensure the toggle is in sync with system
                isDarkMode = colorScheme == .dark
            }
        }
    }
    
    // Function to set the app's appearance mode
    private func setAppearance(isDark: Bool) {
        // Using async/await pattern for UI updates
        Task { @MainActor in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = isDark ? .dark : .light
                }
            }
        }
    }
}

// Create an extension to handle color scheme changes app-wide
extension View {
    // Apply the stored theme preference
    func applyStoredTheme() -> some View {
        self.onAppear {
            let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            
            Task { @MainActor in
                windowScene?.windows.forEach { window in
                    window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                }
            }
        }
    }
}

// AppDelegate code to set theme on launch (add this to your App file)
func configureAppTheme() {
    let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    let scenes = UIApplication.shared.connectedScenes
    let windowScene = scenes.first as? UIWindowScene
    
    Task { @MainActor in
        windowScene?.windows.forEach { window in
            window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}
