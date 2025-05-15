//
//  EbayFeedProcessor.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/29/25.
//

import Foundation
import Compression

class EbayFeedProcessor {
    enum ProcessingError: Error {
        case invalidData
        case decompressionFailed
        case parsingFailed
    }
    
    // MARK: - Feed Processing
    
    /// Process a downloaded feed file and extract product items
    static func processFeedFile(data: Data) async throws -> [ProductItemDTO] {
        // Step 1: Decompress the gzip file
        guard let decompressedData = try? decompressGzip(data: data) else {
            throw ProcessingError.decompressionFailed
        }
        
        // Step 2: Parse the TSV file
        guard let tsvString = String(data: decompressedData, encoding: .utf8) else {
            throw ProcessingError.invalidData
        }
        
        // Step 3: Process the TSV content into product items
        return try parseTSV(tsvString: tsvString)
    }
    
    /// Decompress gzip data
    private static func decompressGzip(data: Data) throws -> Data {
        let decompressed = NSMutableData()
        let bufferSize = 65536
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        // Create a compression stream
        var streamPointer = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPointer.deallocate() }
        var stream = streamPointer.pointee
        
        // Initialize the stream for decompression
        var status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw ProcessingError.decompressionFailed
        }
        
        defer { compression_stream_destroy(&stream) }
        
        let sourceBytes = (data as NSData).bytes
        
        // Set up the stream parameters
        stream.src_ptr = sourceBytes.bindMemory(to: UInt8.self, capacity: data.count)
        stream.src_size = data.count
        stream.dst_ptr = destinationBuffer
        stream.dst_size = bufferSize
        
        // Decompress the data
        repeat {
            status = compression_stream_process(&stream, 0)
            
            if stream.dst_size == 0 {
                let processedBytes = bufferSize - stream.dst_size
                decompressed.append(destinationBuffer, length: processedBytes)
                stream.dst_ptr = destinationBuffer
                stream.dst_size = bufferSize
            }
        } while status == COMPRESSION_STATUS_OK
        
        // Get the last chunk
        if status == COMPRESSION_STATUS_END {
            let processedBytes = bufferSize - stream.dst_size
            decompressed.append(destinationBuffer, length: processedBytes)
        } else {
            throw ProcessingError.decompressionFailed
        }
        
        return decompressed as Data
    }
    
    /// Parse TSV string into product items
    private static func parseTSV(tsvString: String) throws -> [ProductItemDTO] {
        var products: [ProductItemDTO] = []
        
        let rows = tsvString.components(separatedBy: .newlines)
        
        // Extract header row to determine column indexes
        guard let headerRow = rows.first, !headerRow.isEmpty else {
            throw ProcessingError.parsingFailed
        }
        
        let headers = headerRow.components(separatedBy: "\t")
        
        // Define column indices
        var idIndex = -1
        var titleIndex = -1
        var priceIndex = -1
        var currencyIndex = -1
        var sellerIndex = -1
        var categoryNameIndex = -1
        var categoryIdIndex = -1
        var imageUrlIndex = -1
        var conditionIndex = -1
        var quantityIndex = -1
        
        // Find column indices
        for (index, header) in headers.enumerated() {
            switch header {
            case "itemId": idIndex = index
            case "title": titleIndex = index
            case "priceValue": priceIndex = index
            case "priceCurrency": currencyIndex = index
            case "sellerUsername": sellerIndex = index
            case "categoryName", "category": categoryNameIndex = index
            case "categoryId": categoryIdIndex = index
            case "imageUrl", "defaultImageUrl": imageUrlIndex = index
            case "condition": conditionIndex = index
            case "estimatedAvailableQuantity": quantityIndex = index
            default: break
            }
        }
        
        // Process data rows
        for i in 1..<rows.count {
            let row = rows[i]
            guard !row.isEmpty else { continue }
            
            let columns = row.components(separatedBy: "\t")
            guard columns.count >= headers.count else { continue }
            
            // Extract data from columns
            let id = idIndex >= 0 && idIndex < columns.count ? columns[idIndex] : UUID().uuidString
            let title = titleIndex >= 0 && titleIndex < columns.count ? columns[titleIndex] : "Unknown Item"
            let priceString = priceIndex >= 0 && priceIndex < columns.count ? columns[priceIndex] : "0.0"
            let price = Double(priceString) ?? 0.0
            let currency = currencyIndex >= 0 && currencyIndex < columns.count ? columns[currencyIndex] : "USD"
            let seller = sellerIndex >= 0 && sellerIndex < columns.count ? columns[sellerIndex] : "Unknown Seller"
            let category = categoryNameIndex >= 0 && categoryNameIndex < columns.count ? columns[categoryNameIndex] :
                          (categoryIdIndex >= 0 && categoryIdIndex < columns.count ? columns[categoryIdIndex] : "Uncategorized")
            let imageUrl = imageUrlIndex >= 0 && imageUrlIndex < columns.count ? columns[imageUrlIndex] : nil
            let condition = conditionIndex >= 0 && conditionIndex < columns.count ? columns[conditionIndex] : nil
            let quantityString = quantityIndex >= 0 && quantityIndex < columns.count ? columns[quantityIndex] : "0"
            let quantity = Int(quantityString) ?? 0
            
            // Create ProductItemDTO
            let product = ProductItemDTO(
                sourceId: id,
                name: title,
                productDescription: condition,
                price: price,
                currency: currency,
                imageURL: imageUrl != nil ? URL(string: imageUrl!) : nil,
                imageUrls: imageUrl != nil ? [imageUrl!] : [],
                thumbnailUrl: imageUrl,
                brand: seller,
                source: "eBay",
                category: category,
                isInStock: quantity > 0,
                rating: nil,
                reviewCount: nil
            )
            
            products.append(product)
        }
        
        return products
    }
    
    // MARK: - Feed Management
    
    /// Schedule regular feed downloads (e.g., daily or hourly)
    static func scheduleRegularFeedDownloads(service: EbayAPIService, marketplace: String, feedType: String, interval: TimeInterval) {
        // Create a background task that runs at specified intervals
        DispatchQueue.global(qos: .background).async {
            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                Task {
                    do {
                        // Get available files
                        let filesResponse = try await service.getAvailableFiles(
                            feedTypeId: feedType,
                            marketplaceId: marketplace
                        )
                        
                        // Extract fileId of the latest file
                        if let fileMetadata = (filesResponse["fileMetadata"] as? [[String: Any]])?.first,
                           let fileId = fileMetadata["fileId"] as? String {
                            
                            // Download the file
                            let fileData = try await service.downloadFeedFile(
                                fileId: fileId,
                                marketplaceId: marketplace
                            )
                            
                            // Process the file
                            let products = try await processFeedFile(data: fileData)
                            
                            // Store products in database or perform other actions
                            try await storeProducts(products)
                        }
                    } catch {
                        print("Error in scheduled feed download: \(error)")
                    }
                }
            }
        }
    }
    
    /// Store products in your app's database
    private static func storeProducts(_ products: [ProductItemDTO]) async throws {
        // This would integrate with your app's data persistence layer
        // For example, using CoreData or SwiftData
        
        // Sample implementation:
        // For each product, check if it exists in the database
        // If it exists, update it; if not, create it
        
        // This is just a placeholder - you'll need to implement the actual storage logic
        print("Storing \(products.count) products...")
    }
}
