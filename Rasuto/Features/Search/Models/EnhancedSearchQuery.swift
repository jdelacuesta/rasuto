//
//  EnhancedSearchQuery.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/28/25.
//

import Foundation

struct EnhancedSearchQuery {
    let originalQuery: String
    let processedQuery: String
    let keyTerms: [String]
    let relatedTerms: [String: [String]]
    let language: String?
    let filters: [String: Any]
    
    var expandedQueryString: String {
        var terms = Set<String>()
        terms.insert(processedQuery)
        
        for term in keyTerms {
            terms.insert(term)
            if let related = relatedTerms[term] {
                terms.formUnion(related.prefix(2))
            }
        }
        
        return terms.joined(separator: " OR ")
    }
}
