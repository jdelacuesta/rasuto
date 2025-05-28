//
//  VoiceRecognitionService.swift
//  Rasuto
//
//  Created for Rasuto on 4/28/25.
//

import Foundation
import Speech
import AVFoundation

enum VoiceRecognitionError: Error {
    case notAuthorized
    case recognitionFailed
    case audioEngineFailed
    case recognitionUnavailable
    case noRecognizedText
    case recognitionCancelled
}

class VoiceRecognitionService: NSObject, SFSpeechRecognizerDelegate {
    // MARK: - Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    override init() {
        // Initialize with the current locale
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
        self.speechRecognizer?.delegate = self
    }
    
    // Initialize with a specific locale
    init(locale: Locale) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
        self.speechRecognizer?.delegate = self
    }
    
    // MARK: - Recognition with async/await
    
    /// Recognize speech using async/await pattern
    /// - Returns: The recognized text
    /// - Throws: VoiceRecognitionError
    func recognizeSpeech() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            // Check authorization status first
            SFSpeechRecognizer.requestAuthorization { status in
                guard status == .authorized else {
                    continuation.resume(throwing: VoiceRecognitionError.notAuthorized)
                    return
                }
                
                // Proceed with recognition
                DispatchQueue.main.async {
                    do {
                        try self.startRecognition { result in
                            switch result {
                            case .success(let text):
                                continuation.resume(returning: text)
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }
                    } catch {
                        continuation.resume(throwing: VoiceRecognitionError.audioEngineFailed)
                    }
                }
            }
        }
    }
    
    // MARK: - Recognition Implementation
    
    private func startRecognition(completion: @escaping (Result<String, VoiceRecognitionError>) -> Void) throws {
        // Cancel any existing task
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw VoiceRecognitionError.audioEngineFailed
        }
        
        // Create and configure recognition request
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            throw VoiceRecognitionError.recognitionUnavailable
        }
        
        // Request on-device recognition if available
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // We want continuous recognition for a natural feel
        recognitionRequest.shouldReportPartialResults = true
        
        // Set up audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap for audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            throw VoiceRecognitionError.audioEngineFailed
        }
        
        // Create task to monitor speech recognition
        var finalText = ""
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            
            if let result = result {
                finalText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            // If we have an error or final result, stop audio processing
            if error != nil || isFinal {
                self?.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
                
                if let error = error as NSError? {
                    if error.code == 216 { // Timeout error
                        completion(.failure(.recognitionFailed))
                    } else if error.code == 301 { // Cancelled
                        completion(.failure(.recognitionCancelled))
                    } else {
                        completion(.failure(.recognitionFailed))
                    }
                } else if !finalText.isEmpty {
                    completion(.success(finalText))
                } else {
                    completion(.failure(.noRecognizedText))
                }
            }
        }
    }
    
    /// Stop the ongoing recognition
    func stopRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine.inputNode.removeTap(onBus: 0)
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            // Handle recognition becoming unavailable
            print("Speech recognition became unavailable")
        }
    }
}

// MARK: - Utility Extensions

extension VoiceRecognitionService {
    // Get all available locales for speech recognition
    static func availableLocales() -> [Locale] {
        return SFSpeechRecognizer.supportedLocales().map { $0 }
    }
    
    // Get the display name for a locale
    static func displayName(for locale: Locale) -> String {
        let identifier = locale.identifier
        if let language = locale.localizedString(forLanguageCode: locale.languageCode ?? "") {
            if let region = locale.localizedString(forRegionCode: locale.regionCode ?? "") {
                return "\(language) (\(region))"
            }
            return language
        }
        return identifier
    }
}
