//
//  RasutoTests.swift
//  RasutoTests
//
//  Created by JC Dela Cuesta on 4/14/25.
//

import XCTest
@testable import Rasuto

final class URLParserTests: XCTestCase {
    func testAmazonURLDetection() throws {
        let amazonURL = URL(string: "https://www.amazon.com/product")!
        let retailerType = try URLParser.getRetailerType(from: amazonURL)
        XCTAssertEqual(retailerType, .amazon)
    }
    
    func testBestBuyURLDetection() throws {
        let bestBuyURL = URL(string: "https://www.bestbuy.com/product")!
        let retailerType = try URLParser.getRetailerType(from: bestBuyURL)
        XCTAssertEqual(retailerType, .bestBuy)
    }
    
    func testUnsupportedURLDetection() throws {
        let unsupportedURL = URL(string: "https://www.example.com/product")!
        
        XCTAssertThrowsError(try URLParser.getRetailerType(from: unsupportedURL)) { error in
            XCTAssertEqual(error as? URLParserError, .unsupportedRetailer)
        }
    }
}
