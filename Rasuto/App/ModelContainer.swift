//
//  ModelContainer.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import Foundation
import SwiftData

class ModelContainerManager {
    static let shared = ModelContainerManager()
    
    var container: ModelContainer?
    
    private init() {
        do {
            let schema = Schema([
                ProductItem.self,
                Collection.self,
                ProductSpecification.self,
                ProductVariant.self
            ])
            
            // Configuration with persistent storage and CloudKit sync
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .automatic
            )
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("Successfully created ModelContainer with CloudKit sync enabled")
        } catch {
            print("Failed to create ModelContainer: \(error)")
            container = nil
        }
    }
}
