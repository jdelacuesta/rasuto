//
//  RasutoApp.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//
import SwiftUI
import SwiftData
import CloudKit

@main
struct RasutoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let container = CKContainer(identifier: "iCloud.com.Rasuto")
        container.privateCloudDatabase.fetchAllRecordZones { zones, error in
            if let error = error {
                print("CloudKit setup failed: \(error)")
            } else {
                print("CloudKit setup success. Zones: \(zones ?? [])")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container = ModelContainerManager.shared.container {
                SplashScreen()
                    .modelContainer(container)
            } else {
                Text("Failed to load data container.")
            }
        }
    }
}
