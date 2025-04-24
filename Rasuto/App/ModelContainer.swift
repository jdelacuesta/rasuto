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
    
    lazy var container: ModelContainer? = {
        let schema = Schema([
            ProductItem.self,
            Collection.self,
            ProductSpecification.self,
            ProductVariant.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Failed to create ModelContainer: \(error)")
            return nil
        }
    }()
    
    private init() {}
}
