//
//  NLPActionsSheet.swift
//  Rasuto
//
//  Created for Rasuto on 4/28/25.
//

import SwiftUI
import NaturalLanguage
import Speech
import AVFoundation

struct NLPActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NLPActionsViewModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var onSearch: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with dismiss button
            HStack {
                Text("Voice & Text Search")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .background(Color(.systemBackground))
            
            // Input field
            VStack(spacing: 12) {
                // Text input
                TextField("Search for products...", text: $inputText)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .focused($isInputFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        if !inputText.isEmpty {
                            search(inputText)
                        }
                    }
                
                // Voice button
                Button(action: {
                    viewModel.startVoiceRecognition { recognizedText in
                        inputText = recognizedText
                        search(recognizedText)
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text(viewModel.isRecording ? "Listening..." : "Tap to speak")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
                }
            }
            .padding()
            
            // Divider
            Divider()
            
            // Suggestions
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SUGGESTED SEARCHES")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 15)
                    
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        SuggestionRow(suggestion: suggestion) {
                            inputText = suggestion
                            search(suggestion)
                        }
                    }
                    
                    Text("SEARCH TIPS")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 15)
                    
                    ForEach(viewModel.tips, id: \.self) { tip in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text(tip)
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                    }
                }
                .padding(.bottom, 20)
            }
            
            // Search button
            Button(action: {
                if !inputText.isEmpty {
                    search(inputText)
                }
            }) {
                Text("Search")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(inputText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(inputText.isEmpty)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            isInputFocused = true
            viewModel.generateSuggestions()
        }
    }
    
    private func search(_ query: String) {
        onSearch(query)
        dismiss()
    }
}

struct SuggestionRow: View {
    let suggestion: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(suggestion)
                    .font(.subheadline)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

class NLPActionsViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var suggestions: [String] = []
    
    let tips = [
        "Try using natural language like \"Show me cameras under $500\"",
        "You can specify brand names like \"Apple iPhone 15\"",
        "Filter by price range with \"between $100 and $300\"",
        "Ask for the \"newest\" or \"best rated\" products"
    ]
    
    private var voiceRecognitionService = VoiceRecognitionService()
    
    func startVoiceRecognition(completion: @escaping (String) -> Void) {
        isRecording = true
        
        Task {
            do {
                let recognizedText = try await voiceRecognitionService.recognizeSpeech()
                DispatchQueue.main.async {
                    self.isRecording = false
                    completion(recognizedText)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRecording = false
                    print("Voice recognition failed: \(error)")
                    // Show error to user if needed
                }
            }
        }
    }
    
    func generateSuggestions() {
        // In a real app, these might come from trending searches,
        // user history, or personalized recommendations
        suggestions = [
            "Apple iPhone 15 Pro",
            "4K TVs under $1000",
            "Best gaming laptops",
            "Noise-cancelling headphones",
            "Cameras for beginners",
            "Smart home devices"
        ]
    }
}

struct NLPActionsSheet_Previews: PreviewProvider {
    static var previews: some View {
        NLPActionsSheet(onSearch: { _ in })
    }
}
