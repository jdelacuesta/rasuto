//
//  QuotaStatusBanner.swift
//  Rasuto
//
//  Created for displaying quota status in the UI on 6/3/25.
//

import SwiftUI

struct QuotaStatusBanner: View {
    @State private var status: QuotaProtectionStatus?
    
    var body: some View {
        if let quotaStatus = status {
            if quotaStatus.isDemoMode {
                demoBanner
            } else {
                quotaBanner(quotaStatus)
            }
        } else {
            EmptyView()
        }
    }
    
    private var demoBanner: some View {
        HStack {
            Image(systemName: "theatermasks.fill")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading) {
                Text("Demo Mode Active")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Using cached data - no API calls")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .task {
            await loadStatus()
        }
    }
    
    private func quotaBanner(_ quotaStatus: QuotaProtectionStatus) -> some View {
        HStack {
            Image(systemName: quotaStatus.canMakeRequests ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundColor(quotaStatus.canMakeRequests ? .green : .orange)
            
            VStack(alignment: .leading) {
                Text("API Quota Status")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(quotaStatus.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(quotaStatus.canMakeRequests ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .task {
            await loadStatus()
        }
    }
    
    private func loadStatus() async {
        status = await QuotaProtectionManager.shared.getStatus()
    }
}

// MARK: - Mini Banner Version

struct QuotaStatusMiniBanner: View {
    @State private var isDemoMode = false
    
    var body: some View {
        Group {
            if isDemoMode {
                HStack(spacing: 6) {
                    Image(systemName: "theatermasks.fill")
                        .font(.caption2)
                    Text("Demo Mode")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(6)
            }
        }
        .task {
            let status = await QuotaProtectionManager.shared.getStatus()
            isDemoMode = status.isDemoMode
        }
    }
}

#Preview {
    QuotaStatusBanner()
}
