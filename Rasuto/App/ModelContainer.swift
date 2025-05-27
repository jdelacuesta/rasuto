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
            
            // Create a configuration with persistent storage
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false  // Enable persistent storage for wishlist functionality
            )
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("Successfully created ModelContainer in memory")
        } catch {
            print("Failed to create ModelContainer: \(error)")
            container = nil
        }
    }
}
