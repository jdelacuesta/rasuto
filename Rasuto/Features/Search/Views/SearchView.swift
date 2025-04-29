//
//  SearchView.swift
//  Rasuto
//
//  Created on 4/21/25.
//  Updated to support async SearchViewModel

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var isNLPActionsSheetPresented = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            
                        TextField("Search products...", text: $viewModel.searchQuery)
                            .submitLabel(.search)
                            .onSubmit {
                                Task {
                                    await viewModel.performSearch()
                                }
                            }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Voice search button
                    Button(action: {
                        isNLPActionsSheetPresented = true
                    }) {
                        Image(systemName: "mic")
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchCategory.allCases, id: \.self) { category in
                            Button(action: {
                                viewModel.filterByCategory(category)
                            }) {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                                    .background(viewModel.selectedCategory == category ? Color.blue : Color(.systemGray5))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Retailer selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.selectedRetailer = nil
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                Text("All Sources")
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(viewModel.selectedRetailer == nil ? Color.blue : Color(.systemGray5))
                            .foregroundColor(viewModel.selectedRetailer == nil ? .white : .primary)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            viewModel.selectedRetailer = .bestBuy
                        }) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Best Buy")
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(viewModel.selectedRetailer == .bestBuy ? Color.blue : Color(.systemGray5))
                            .foregroundColor(viewModel.selectedRetailer == .bestBuy ? .white : .primary)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            viewModel.selectedRetailer = .walmart
                        }) {
                            HStack {
                                Image(systemName: "cart.fill")
                                Text("Walmart")
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(viewModel.selectedRetailer == .walmart ? Color.blue : Color(.systemGray5))
                            .foregroundColor(viewModel.selectedRetailer == .walmart ? .white : .primary)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            viewModel.selectedRetailer = .ebay
                        }) {
                            HStack {
                                Image(systemName: "tag.fill")
                                Text("eBay")
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(viewModel.selectedRetailer == .ebay ? Color.blue : Color(.systemGray5))
                            .foregroundColor(viewModel.selectedRetailer == .ebay ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Search results or recent searches
                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                } else if !viewModel.searchResults.isEmpty {
                    // Search results list
                    List {
                        ForEach(viewModel.searchResults, id: \.id) { dto in
                            searchResultRowForDTO(dto)
                        }
                    }
                    .listStyle(PlainListStyle())
                } else if let errorMessage = viewModel.errorMessage {
                    // Error message
                    Spacer()
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if viewModel.searchQuery.isEmpty {
                    // Recent searches
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Searches")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.recentSearches, id: \.self) { search in
                            Button(action: {
                                viewModel.searchQuery = search
                                Task {
                                    await viewModel.performSearch()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.gray)
                                    
                                    Text(search)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(timestampForSearch(search))
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                } else {
                    // No results found
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No results found")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Try different search terms or retailers")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .task {
                // Preload data if needed
                if !viewModel.searchResults.isEmpty && viewModel.searchQuery.isEmpty {
                    await viewModel.performSearch()
                }
            }
        }
        .sheet(isPresented: $isNLPActionsSheetPresented) {
            NLPActionsSheet(onVoiceSearchComplete: { searchText in
                viewModel.searchQuery = searchText
                Task {
                    await viewModel.performSearch()
                }
                isNLPActionsSheetPresented = false
            })
        }
    }
    
    // Helper view to convert DTO to SearchItem format for existing UI components
    private func searchResultRowForDTO(_ dto: ProductItemDTO) -> some View {
        HStack(spacing: 16) {
            // Product image or placeholder
            if let imageURL = dto.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 70, height: 70)
                            .cornerRadius(8)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .cornerRadius(8)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 70, height: 70)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 70, height: 70)
                            .cornerRadius(8)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            // Product details
            VStack(alignment: .leading, spacing: 4) {
                Text(dto.name)
                    .font(.headline)
                    .lineLimit(2)
                
                if let price = dto.price, let currency = dto.currency {
                    Text(price, format: .currency(code: currency))
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text(dto.source)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    if let category = dto.category {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.saveToFavorites(dto)
                }) {
                    Image(systemName: "heart")
                        .foregroundColor(.pink)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    viewModel.startTracking(dto)
                }) {
                    Image(systemName: "bell")
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to detail view (to be implemented)
        }
    }
    
    // Helper for recent search timestamps
    private func timestampForSearch(_ search: String) -> String {
        switch search {
        case "dslr camera":
            return "Yesterday"
        case "leica":
            return "2 days ago"
        case "sony a7":
            return "Last week"
        default:
            return "Just now"
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var modelContext: ModelContext?
        
        var body: some View {
            VStack {
                if let context = modelContext {
                    SearchView(viewModel: SearchViewModel(modelContext: context))
                        .environment(\.modelContext, context)
                } else {
                    Text("Loading preview...")
                        .task {
                            do {
                                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                                let container = try ModelContainer(for: ProductItem.self, configurations: config)
                                modelContext = container.mainContext
                            } catch {
                                print("Preview error: \(error)")
                            }
                        }
                }
            }
        }
    }
    
    return PreviewWrapper()
}
