//
//  CloudKitHelper.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import Foundation
import CloudKit

class CloudKitService {
    static let shared = CloudKitService()
    
    private let container: CKContainer
    private let publicDB: CKDatabase
    private let privateDB: CKDatabase
    
    private init() {
        container = CKContainer.default()
        publicDB = container.publicCloudDatabase
        privateDB = container.privateCloudDatabase
    }
    
    // Placeholder methods for CloudKit operations
    func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        try await privateDB.save(record)
    }
    
    func fetchRecord(withID id: CKRecord.ID) async throws -> CKRecord {
        try await privateDB.record(for: id)
    }
    
    func deleteRecord(withID id: CKRecord.ID) async throws {
        try await privateDB.deleteRecord(withID: id)
    }
}
