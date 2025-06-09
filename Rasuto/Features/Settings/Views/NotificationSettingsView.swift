//
//  NotificationSettingsView.swift
//  Rasuto
//
//  Created by Claude on 6/4/25.
//

import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Query private var preferences: [NotificationPreferences]
    @Environment(\.modelContext) private var modelContext
    
    private var notificationPrefs: NotificationPreferences {
        if let existing = preferences.first {
            return existing
        } else {
            // Create default preferences if none exist
            let newPrefs = NotificationPreferences()
            modelContext.insert(newPrefs)
            try? modelContext.save()
            return newPrefs
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Notification Types
                Section("Notification Types") {
                    Toggle("Price Drop Alerts", isOn: .constant(notificationPrefs.enablePriceDropNotifications))
                        .onChange(of: notificationPrefs.enablePriceDropNotifications) { _, newValue in
                            updatePreference { $0.enablePriceDropNotifications = newValue }
                        }
                    
                    Toggle("Back in Stock", isOn: .constant(notificationPrefs.enableBackInStockNotifications))
                        .onChange(of: notificationPrefs.enableBackInStockNotifications) { _, newValue in
                            updatePreference { $0.enableBackInStockNotifications = newValue }
                        }
                    
                    Toggle("Tracking Updates", isOn: .constant(notificationPrefs.enableTrackingUpdates))
                        .onChange(of: notificationPrefs.enableTrackingUpdates) { _, newValue in
                            updatePreference { $0.enableTrackingUpdates = newValue }
                        }
                }
                
                // MARK: - Price Drop Thresholds
                Section("Price Drop Sensitivity") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Price Drop")
                            Spacer()
                            Text("$\(notificationPrefs.minimumPriceDropAmount, specifier: "%.0f")")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: .constant(notificationPrefs.minimumPriceDropAmount),
                            in: 1...50,
                            step: 1
                        ) {
                            Text("Minimum Price Drop")
                        } onEditingChanged: { _ in
                            // Update when slider changes
                        }
                        .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Percentage Drop")
                            Spacer()
                            Text("\(notificationPrefs.minimumPriceDropPercentage, specifier: "%.0f")%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: .constant(notificationPrefs.minimumPriceDropPercentage),
                            in: 1...25,
                            step: 1
                        ) {
                            Text("Minimum Percentage Drop")
                        } onEditingChanged: { _ in
                            // Update when slider changes
                        }
                        .accentColor(.blue)
                    }
                }
                
                // MARK: - Frequency Settings
                Section("Notification Frequency") {
                    Picker("Frequency", selection: .constant(notificationPrefs.notificationFrequency)) {
                        ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: notificationPrefs.notificationFrequency) { _, newValue in
                        updatePreference { $0.notificationFrequency = newValue }
                    }
                }
                
                // MARK: - Demo Section
                #if DEBUG
                Section("Demo & Testing") {
                    Button("Simulate Price Drop") {
                        ProductTrackingService.shared.simulatePriceDropForDemo()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Test Notification") {
                        // This would trigger a test notification
                        print("🔔 Test notification triggered")
                    }
                    .foregroundColor(.blue)
                }
                #endif
                
                // MARK: - Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Notifications")
                            .font(.headline)
                        
                        Text("Price drop alerts will only notify you when both the dollar amount and percentage thresholds are met. This helps reduce notification spam while ensuring you don't miss significant deals.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func updatePreference(_ update: (inout NotificationPreferences) -> Void) {
        var prefs = notificationPrefs
        update(&prefs)
        prefs.lastUpdated = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save notification preferences: \(error)")
        }
    }
}

// MARK: - Frequency Settings View

struct FrequencySettingsView: View {
    @Query private var preferences: [NotificationPreferences]
    @Environment(\.modelContext) private var modelContext
    
    private var notificationPrefs: NotificationPreferences {
        preferences.first ?? NotificationPreferences()
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("How often would you like to receive notifications?") {
                    ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                        HStack {
                            Text(frequency.displayName)
                            
                            Spacer()
                            
                            if notificationPrefs.notificationFrequency == frequency {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            updateFrequency(frequency)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Frequency Options")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Immediate: Get notified as soon as changes are detected")
                            Text("• Hourly: Receive a summary of changes every hour")
                            Text("• Daily: Get a daily digest of all price changes")
                            Text("• Disabled: Turn off all notifications")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Notification Frequency")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func updateFrequency(_ frequency: NotificationFrequency) {
        // Update the preference
        var prefs = notificationPrefs
        prefs.notificationFrequency = frequency
        prefs.lastUpdated = Date()
        
        if preferences.isEmpty {
            modelContext.insert(prefs)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save frequency preference: \(error)")
        }
    }
}

#Preview {
    NotificationSettingsView()
}

#Preview {
    FrequencySettingsView()
}