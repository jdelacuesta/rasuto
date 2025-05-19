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
            
            // Create a configuration without CloudKit
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true  // Use in-memory storage to bypass persistence issues
            )
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("Successfully created ModelContainer in memory")
        } catch {
            print("Failed to create ModelContainer: \(error)")
            container = nil
        }
    }
}
