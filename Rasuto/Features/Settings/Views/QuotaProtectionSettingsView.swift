//
//  QuotaProtectionSettingsView.swift
//  Rasuto
//
//  Created for managing quota protection settings on 6/3/25.
//

import SwiftUI

struct QuotaProtectionSettingsView: View {
    @State private var protectionStatus: QuotaProtectionStatus?
    @State private var isLoading = true
    @State private var showingResetConfirmation = false
    @State private var demoModeEnabled = false
    @State private var protectionEnabled = true
    
    private let quotaManager = QuotaProtectionManager.shared
    
    var body: some View {
        List {
            // Status Section
            Section {
                if let status = protectionStatus {
                    VStack(alignment: .leading, spacing: 12) {
                        // Monthly Usage
                        HStack {
                            Text("Monthly SerpAPI Usage")
                            Spacer()
                            Text("\(Int(status.monthlyUtilization))%")
                                .foregroundColor(status.monthlyUtilization > 80 ? .red : .primary)
                                .fontWeight(.semibold)
                        }
                        
                        ProgressView(value: status.monthlyUtilization, total: 100)
                            .tint(status.monthlyUtilization > 80 ? .red : .blue)
                        
                        // Daily Usage
                        HStack {
                            Text("Daily Requests")
                            Spacer()
                            Text("\(status.dailyRequestsUsed)/\(status.dailyRequestLimit)")
                                .foregroundColor(status.dailyRequestsUsed >= status.dailyRequestLimit ? .red : .primary)
                        }
                        .font(.footnote)
                        
                        // Status Message
                        Label(status.statusMessage, systemImage: status.canMakeRequests ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(status.canMakeRequests ? .green : .orange)
                    }
                    .padding(.vertical, 4)
                } else {
                    ProgressView("Loading quota status...")
                }
            } header: {
                Text("API Quota Status")
            }
            
            // Protection Settings
            Section {
                Toggle("Quota Protection", isOn: $protectionEnabled)
                    .onChange(of: protectionEnabled) { _, newValue in
                        Task {
                            await quotaManager.setQuotaProtection(enabled: newValue)
                            await loadStatus()
                        }
                    }
                
                Toggle("Demo Mode", isOn: $demoModeEnabled)
                    .onChange(of: demoModeEnabled) { _, newValue in
                        Task {
                            if newValue {
                                await quotaManager.enableDemoMode()
                            } else {
                                await quotaManager.disableDemoMode()
                            }
                            await loadStatus()
                        }
                    }
            } header: {
                Text("Protection Settings")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quota Protection limits API requests to preserve your monthly quota.")
                    Text("Demo Mode uses cached data only - no API requests.")
                }
            }
            
            // Actions
            Section {
                Button(action: {
                    Task {
                        await quotaManager.resetDailyCounter()
                        await loadStatus()
                    }
                }) {
                    Label("Reset Daily Counter", systemImage: "arrow.clockwise")
                }
                
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    Label("Clear All Caches", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } header: {
                Text("Actions")
            }
            
            // Info Section
            Section {
                Link(destination: URL(string: "https://serpapi.com/manage-api-key")!) {
                    HStack {
                        Label("View SerpAPI Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://serpapi.com/pricing")!) {
                    HStack {
                        Label("Upgrade SerpAPI Plan", systemImage: "creditcard")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("SerpAPI Account")
            }
        }
        .navigationTitle("Quota Protection")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadStatus()
        }
        .task {
            await loadStatus()
        }
        .alert("Clear All Caches?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await UnifiedCacheManager.shared.clear()
                    await SerpAPICacheManager.shared.clearCache()
                }
            }
        } message: {
            Text("This will clear all cached search results and force new API requests.")
        }
    }
    
    private func loadStatus() async {
        protectionStatus = await quotaManager.getStatus()
        if let status = protectionStatus {
            demoModeEnabled = status.isDemoMode
            protectionEnabled = status.isProtectionEnabled
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        QuotaProtectionSettingsView()
    }
}