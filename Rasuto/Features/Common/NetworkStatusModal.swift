//
//  NetworkStatusModal.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 5/27/25.
//

import SwiftUI

struct NetworkStatusModal: View {
    @Binding var isPresented: Bool
    @ObservedObject var networkMonitor: NetworkMonitor
    let onTestRequest: () async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: networkIcon)
                    .foregroundColor(networkIconColor)
                    .font(.title2)
                
                Text("Network Status")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    isPresented = false
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            Divider()
            
            // Connection Status
            VStack(spacing: 12) {
                HStack {
                    Text("Connection:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(connectionStatusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(connectionStatusColor)
                }
                
                HStack {
                    Text("Type:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(connectionTypeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Divider()
            
            // Test Network Request Section
            VStack(spacing: 16) {
                Text("Test Network Request")
                    .font(.headline)
                
                Text("Test waitsForConnectivity by making a network request. The request will wait for connectivity if offline.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    Task {
                        await onTestRequest()
                    }
                }) {
                    HStack {
                        if networkMonitor.isWaitingForConnectivity {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                        }
                        
                        Text(networkMonitor.isWaitingForConnectivity ? "Testing..." : "Test Request")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        networkMonitor.isWaitingForConnectivity ? Color.gray : Color.blue
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(networkMonitor.isWaitingForConnectivity)
                
                // Status Message
                if !networkMonitor.networkStatusMessage.isEmpty {
                    Text(networkMonitor.networkStatusMessage)
                        .font(.caption)
                        .foregroundColor(statusMessageColor)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(statusMessageBackground)
                        .cornerRadius(8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 350)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isWaitingForConnectivity)
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.networkStatusMessage)
    }
    
    // MARK: - Computed Properties
    
    private var networkIcon: String {
        if networkMonitor.isWaitingForConnectivity {
            return "antenna.radiowaves.left.and.right"
        }
        return networkMonitor.isConnected ? "wifi" : "wifi.slash"
    }
    
    private var networkIconColor: Color {
        if networkMonitor.isWaitingForConnectivity {
            return .orange
        }
        return networkMonitor.isConnected ? .green : .red
    }
    
    private var connectionStatusText: String {
        if networkMonitor.isWaitingForConnectivity {
            return "Testing..."
        }
        return networkMonitor.isConnected ? "Connected" : "Disconnected"
    }
    
    private var connectionStatusColor: Color {
        if networkMonitor.isWaitingForConnectivity {
            return .orange
        }
        return networkMonitor.isConnected ? .green : .red
    }
    
    private var connectionTypeText: String {
        switch networkMonitor.connectionType {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "Unknown"
        }
    }
    
    private var statusMessageColor: Color {
        if networkMonitor.networkStatusMessage.contains("successfully") {
            return .green
        } else if networkMonitor.networkStatusMessage.contains("failed") {
            return .red
        } else {
            return .blue
        }
    }
    
    private var statusMessageBackground: Color {
        if networkMonitor.networkStatusMessage.contains("successfully") {
            return .green.opacity(0.1)
        } else if networkMonitor.networkStatusMessage.contains("failed") {
            return .red.opacity(0.1)
        } else {
            return .blue.opacity(0.1)
        }
    }
}

// MARK: - Preview
#Preview {
    NetworkStatusModal(
        isPresented: .constant(true),
        networkMonitor: NetworkMonitor.shared,
        onTestRequest: {
            // Preview test action
        }
    )
}