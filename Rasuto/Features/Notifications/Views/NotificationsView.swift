//
//  NotificationsView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import SwiftUI

struct NotificationsView: View {
    var body: some View {
        VStack {
            Text("Notifications")
                .font(Theme.Typography.titleFont)
            
            Text("You'll see your alerts and notifications here")
                .font(Theme.Typography.bodyFont)
        }
        .navigationTitle("Alerts")
    }
}

#Preview {
    NotificationsView()
}
