//
//  SearchViewModel.swift
//  Rasuto
//
//  Created for Rasuto on 4/28/25.
//

import Foundation
import SwiftUI

enum RasutoSearchFilter: Equatable {
    case all
    case saved
    case collections
    case category(String)
    
    static func == (lhs: RasutoSearchFilter, rhs: RasutoSearchFilter) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all),
             (.saved, .saved),
             (.collections, .collections):
            return true
        case (.category(let lhsCategory), .category(let rhsCategory)):
            return lhsCategory == rhsCategory
        default:
            return false
        }
    }
}

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [ProductItemDTO] = []
    @Published var recentSearches: [String] = []
    @Published var selectedFilter: RasutoSearchFilter = .all
    @Published var isLoading = false
    
    // Dictionary to store when each search was performed
    private var searchDates: [String: Date] = [:]
    
    // Sample categories
    let categories = ["Electronics", "Cameras", "Computers", "Phones", "Audio"]
    
    private var apiServices: [RetailerAPIService] = []
    
    init() {
        setupAPIServices()
        loadRecentSearches()
    }
    
    private func setupAPIServices() {
        // In a real app, these would be initialized with actual API keys
        do {
            let bestBuyService = BestBuyAPIService(apiKey: "placeholder")
            let walmartService = WalmartAPIService(apiKey: "placeholder")
            let ebayService = EbayAPIService(apiKey: "placeholder")
            
            apiServices = [bestBuyService, walmartService, ebayService]
        } catch {
            print("Failed to initialize API services: \(error)")
        }
    }
    
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        
        Task {
            await performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) async {
        var allResults: [ProductItemDTO] = []
        
        // Perform search concurrently on all services
        await withTaskGroup(of: [ProductItemDTO].self) { group in
            for service in apiServices {
                group.addTask {
                    do {
                        return try await service.searchProducts(query: query)
                    } catch {
                        print("Error searching \(service): \(error)")
                        return []
                    }
                }
            }
            
            // Collect results as they complete
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }
        
        // Apply filters if needed
        switch selectedFilter {
        case .saved:
            allResults = allResults.filter { $0.isFavorite }
        case .category(let category):
            allResults = allResults.filter { $0.category?.lowercased() == category.lowercased() }
        default:
            break
        }
        
        // Sort results (e.g., by price, relevance, etc.)
        allResults.sort { $0.price ?? 0 < $1.price ?? 0 }
        
        // Update UI
        self.searchResults = allResults
        self.isLoading = false
    }
    
    func addRecentSearch(_ query: String) {
        // Don't add if empty or already at the top
        guard !query.isEmpty, recentSearches.first != query else { return }
        
        // Remove if exists elsewhere in the list
        recentSearches.removeAll { $0 == query }
        
        // Add to the beginning
        recentSearches.insert(query, at: 0)
        
        // Limit to 10 recent searches
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        // Update the timestamp
        searchDates[query] = Date()
        
        // Save to user defaults
        saveRecentSearches()
    }
    
    func loadRecentSearches() {
        if let savedSearches = UserDefaults.standard.array(forKey: "recentSearches") as? [String] {
            recentSearches = savedSearches
        }
        
        if let savedDates = UserDefaults.standard.dictionary(forKey: "searchDates") as? [String: Date] {
            searchDates = savedDates
        }
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
        UserDefaults.standard.set(searchDates, forKey: "searchDates")
    }
    
    func getFormattedDate(for search: String) -> String {
        guard let date = searchDates[search] else { return "" }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            
            // If within last week
            if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date > weekAgo {
                formatter.dateFormat = "EEEE" // Day name
                return formatter.string(from: date)
            } else {
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: date)
            }
        }
    }
    
    func activateVoiceSearch() async {
        // This will be implemented using VoiceRecognitionService
        let voiceService = VoiceRecognitionService()
        
        do {
            let recognizedText = try await voiceService.recognizeSpeech()
            if !recognizedText.isEmpty {
                // Use the recognized text as search query
                addRecentSearch(recognizedText)
                search(query: recognizedText)
            }
        } catch {
            print("Voice recognition failed: \(error)")
            // Handle error - could show an alert to the user
        }
    }
}
