//
//  SettingsView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Account") {
                Text("Profile")
                Text("Preferences")
            }
            
            Section("Notifications") {
                Text("Alert Settings")
                Text("Frequency")
            }
            
            Section("About") {
                Text("Version 1.0")
                Text("Privacy Policy")
                Text("Terms of Service")
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
