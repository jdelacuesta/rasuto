//
//  RetailerType.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/28/25.
//

import Foundation

enum RetailerType: String, CaseIterable {
    case bestBuy
    case walmart
    case ebay
    
    var displayName: String {
        switch self {
        case .bestBuy:
            return "Best Buy"
        case .walmart:
            return "Walmart"
        case .ebay:
            return "eBay"
        }
    }
    
    var domain: String {
        switch self {
        case .bestBuy:
            return "bestbuy.com"
        case .walmart:
            return "walmart.com"
        case .ebay:
            return "ebay.com"
        }
    }
}
