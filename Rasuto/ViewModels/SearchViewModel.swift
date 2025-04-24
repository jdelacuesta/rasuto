//
//  SearchViewModel.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/21/25.
//
import SwiftUI
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [SearchItem] = []
    @Published var recentSearches: [String] = ["dslr camera", "leica", "sony a7"]
    @Published var isSearching = false
    @Published var selectedCategory: SearchCategory = .all
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up search text debounce
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard !text.isEmpty else {
                    self?.searchResults = []
                    return
                }
                
                self?.performSearch(term: text)
            }
            .store(in: &cancellables)
    }
    
    func performSearch(term: String) {
        guard !term.isEmpty else { return }
        
        isSearching = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Mock search results - in a real app this would be from an API or database
            self.searchResults = [
                SearchItem(
                    name: "Leica Q3 Camera",
                    description: "Full-frame compact camera",
                    price: 5995.00,
                    source: .bestBuy,
                    category: .cameras
                ),
                SearchItem(
                    name: "Canon EOS R6 Camera",
                    description: "Mirrorless digital camera",
                    price: 2299.00,
                    source: .bestBuy,
                    category: .cameras
                ),
                SearchItem(
                    name: "Sony Alpha Camera",
                    description: "Full-frame mirrorless camera",
                    price: 1999.00,
                    source: .ebay,
                    category: .cameras
                )
            ]
            
            self.isSearching = false
            
            // Add to recent searches if not already there
            if !self.recentSearches.contains(term) {
                self.recentSearches.insert(term, at: 0)
                if self.recentSearches.count > 5 {
                    self.recentSearches.removeLast()
                }
            }
        }
    }
    
    func filterByCategory(_ category: SearchCategory) {
        // In a real app, this would filter the results based on category
        self.selectedCategory = category
    }
    
    func clearRecentSearches() {
        recentSearches = []
    }
    
    func removeRecentSearch(_ search: String) {
        recentSearches.removeAll { $0 == search }
    }
}
