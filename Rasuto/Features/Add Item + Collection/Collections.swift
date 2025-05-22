//
//  Collections.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import Foundation
import SwiftData

@Model
final class Collection {
    var id: UUID
    var name: String
    var items: [ProductItem]
    var createdDate: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.items = []
        self.createdDate = Date()
    }
}
