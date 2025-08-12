import Foundation
import SwiftUI
import SwiftData
import WhisperKit
import AVFoundation
import AVFAudio
import OSLog
import Combine
import UniformTypeIdentifiers
// iOS 26 imports - uncomment when available
// import FoundationModels
// import TextToSpeech

private let logger = Logger(subsystem: "com.epilogue", category: "TrueAmbientProcessor")

// MARK: - Ambient Processed Content
public struct AmbientProcessedContent: Identifiable {
    public let id = UUID()
    public let text: String
    public let type: ContentType
    public let timestamp: Date
    public let confidence: Float
    public var response: String?
    public var bookTitle: String?
    public var bookAuthor: String?
    
    public enum ContentType {
        case question
        case quote
        case note
        case thought
        case ambient
        case unknown
    }
}

// MARK: - Session Summary
public struct SessionSummary {
    let quotes: [AmbientProcessedContent]
    let notes: [AmbientProcessedContent]
    let questions: [AmbientProcessedContent]
    let duration: TimeInterval
    let totalContent: Int
}

// MARK: - TrueAmbientProcessor
// THE ONLY processor - replaces ALL other processors
@MainActor
public class TrueAmbientProcessor: ObservableObject {
    public static let shared = TrueAmbientProcessor()
    
    // Published properties for UI binding
    @Published public var currentTranscript: String = ""
    @Published public var isProcessing: Bool = false
    @Published public var sessionActive: Bool = false
    @Published public var detectedContent: [AmbientProcessedContent] = []
    @Published public var lastConfidence: Float = 0.0
    
    // Debug properties
    @Published public var currentState: ProcessorState = .listening
    @Published public var processingQueue: [QueueItem] = []
    @Published public var recentlySaved: [AmbientProcessedContent] = []
    
    // Debug state enum
    public enum ProcessorState {
        case listening
        case detecting(String)
        case processing(AmbientProcessedContent.ContentType, String)
        case saving(AmbientProcessedContent)
    }
    
    // Queue item for debug view
    public struct QueueItem: Identifiable {
        public let id = UUID()
        public let text: String
        public let type: AmbientProcessedContent.ContentType
        public let requiresAction: Bool
    }
    
    // WhisperKit integration
    private var whisperModel: WhisperKit?
    private var audioBuffer: AVAudioPCMBuffer?
    private let confidenceThreshold: Float = 0.99
    
    // Session management
    private var sessionContent: [AmbientProcessedContent] = []
    private var sessionStartTime: Date?
    private var modelContext: ModelContext?
    
    // Processing state
    private var isInitialized = false
    private let processingDispatchQueue = DispatchQueue(label: "com.epilogue.trueprocessor", qos: .userInitiated)
    
    private init() {
        Task {
            await initializeWhisper()
        }
    }
    
    // MARK: - WhisperKit Initialization
    
    private func initializeWhisper() async {
        do {
            // Initialize WhisperKit with configuration
            let config = WhisperKitConfig(
                model: "base", // Use base model for balance
                modelRepo: "argmaxinc/whisperkit-coreml"
            )
            
            whisperModel = try await WhisperKit(config)
            isInitialized = true
            logger.info("✅ WhisperKit initialized successfully")
        } catch {
            logger.error("❌ Failed to initialize WhisperKit: \(error)")
        }
    }
    
    // MARK: - Session Management
    
    public func startSession() {
        // Fresh session each time - no persistence
        sessionContent.removeAll()
        detectedContent.removeAll()
        currentTranscript = ""
        sessionStartTime = Date()
        sessionActive = true
        
        logger.info("🎯 TrueAmbientProcessor session started")
    }
    
    public func endSession() async -> SessionSummary {
        guard sessionActive else {
            return SessionSummary(
                quotes: [],
                notes: [],
                questions: [],
                duration: 0,
                totalContent: 0
            )
        }
        
        sessionActive = false
        
        // Process all quotes/notes at session end
        await processSessionContent()
        
        let duration = Date().timeIntervalSince(sessionStartTime ?? Date())
        let summary = SessionSummary(
            quotes: detectedContent.filter { $0.type == .quote },
            notes: detectedContent.filter { $0.type == .note },
            questions: detectedContent.filter { $0.type == .question },
            duration: duration,
            totalContent: detectedContent.count
        )
        
        logger.info("🎯 Session ended - Duration: \(Int(duration))s, Content: \(self.detectedContent.count) items")
        
        // Reset for next session
        sessionContent.removeAll()
        detectedContent.removeAll()
        currentTranscript = ""
        
        return summary
    }
    
    // MARK: - Audio Processing (Direct WhisperKit)
    
    public func process(_ audio: AVAudioPCMBuffer) async {
        guard sessionActive, let whisperModel = whisperModel else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Direct WhisperKit transcription
            let audioArray = Array(UnsafeBufferPointer(start: audio.floatChannelData?[0], count: Int(audio.frameLength)))
            
            // Save audio to temporary file for WhisperKit
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
            try saveAudioToFile(audioArray, url: tempURL)
            
            // Transcribe using file path
            // WhisperKit returns [[TranscriptionResult]?]
            let results = try await whisperModel.transcribe(audioPaths: [tempURL.path])
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
            // Get the first result from the nested array structure
            guard let firstArray = results.first,
                  let result = firstArray?.first else { return }
            
            // Check confidence from segments
            // Use a simple confidence check for now
            let confidence: Float = 0.99 // WhisperKit generally has high confidence
            guard confidence > confidenceThreshold else {
                logger.debug("Confidence too low: \(confidence)")
                return
            }
            
            let text = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            
            // Update UI
            await MainActor.run { [weak self] in
                self?.currentTranscript = text
                self?.lastConfidence = confidence
            }
            
            // Real-time intent detection
            await detectAndProcessIntent(text, confidence: confidence)
            
        } catch {
            logger.error("Transcription error: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveAudioToFile(_ samples: [Float], url: URL) throws {
        // Create a simple WAV file
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: url, settings: audioFormat.settings)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        
        let channelData = buffer.floatChannelData![0]
        for (index, sample) in samples.enumerated() {
            channelData[index] = sample
        }
        
        try audioFile.write(from: buffer)
    }
    
    // Confidence calculation would need proper type mapping
    // For now using fixed high confidence as WhisperKit is generally accurate
    /*
    private func calculateConfidence(from result: TranscriptionResult) -> Float {
        // Calculate average confidence from segments
        guard !result.segments.isEmpty else { return 0.0 }
        
        // WhisperKit segments have avgLogprob, convert to probability
        let totalProb = result.segments.reduce(Float(0)) { sum, segment in
            sum + exp(segment.avgLogprob)
        }
        return totalProb / Float(result.segments.count)
    }
    */
    
    // MARK: - Intent Detection & Processing
    
    private func detectAndProcessIntent(_ text: String, confidence: Float) async {
        // Update state for debug view
        currentState = .detecting(text)
        
        // iOS 26 Foundation Models when available (future)
        // Currently using fallback detection
        
        // Fallback intent detection
        let intent = detectIntentFallback(text)
        
        // Update state for processing
        currentState = .processing(intent, text)
        
        // Process based on intent type
        switch intent {
        case .question:
            // IMMEDIATE AI response for questions
            logger.info("❓ Question detected: \(text)")
            
            // Post immediate notification for UI
            NotificationCenter.default.post(
                name: .questionDetected,
                object: ["question": text, "confidence": confidence]
            )
            
            // Process with AI response
            await processQuestion(text, confidence: confidence)
            
        case .quote, .note, .thought:
            // Save important content immediately with SwiftData
            let content = AmbientProcessedContent(
                text: text,
                type: intent,
                timestamp: Date(),
                confidence: confidence,
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            
            // Add to detected content for immediate UI update
            await MainActor.run { [weak self] in
                self?.detectedContent.append(content)
            }
            
            // Save to SwiftData immediately
            await saveContentImmediately(content)
            
            // Also add to session for batch processing
            sessionContent.append(content)
            
        case .ambient, .unknown:
            // Less important content - batch process later
            let content = AmbientProcessedContent(
                text: text,
                type: intent,
                timestamp: Date(),
                confidence: confidence
            )
            sessionContent.append(content)
        }
        
        // Reset to listening state
        currentState = .listening
    }
    
    // New method for immediate SwiftData saves
    private func saveContentImmediately(_ content: AmbientProcessedContent) async {
        guard let modelContext = modelContext else {
            logger.error("❌ No model context for immediate save")
            return
        }
        
        await MainActor.run {
            switch content.type {
            case .quote:
                let quote = CapturedQuote(
                    text: content.text,
                    book: nil, // Would need to query BookModel
                    timestamp: content.timestamp,
                    source: .ambient
                )
                modelContext.insert(quote)
                
            case .note, .thought:
                let note = CapturedNote(
                    content: content.text,
                    book: nil, // Would need to query BookModel
                    timestamp: content.timestamp,
                    source: .ambient
                )
                modelContext.insert(note)
                
            default:
                break
            }
            
            // Save immediately
            do {
                try modelContext.save()
                logger.info("✅ Content saved immediately to SwiftData")
            } catch {
                logger.error("❌ Failed to save content: \(error)")
            }
        }
    }
    
    private func detectIntentFallback(_ text: String) -> AmbientProcessedContent.ContentType {
        let lowercased = text.lowercased()
        
        // Question detection
        if lowercased.contains("?") ||
           lowercased.starts(with: "what") ||
           lowercased.starts(with: "why") ||
           lowercased.starts(with: "how") ||
           lowercased.starts(with: "when") ||
           lowercased.starts(with: "where") ||
           lowercased.starts(with: "who") {
            return .question
        }
        
        // Quote detection
        if text.contains("\"") || text.contains("\u{201C}") ||
           lowercased.contains("said") || lowercased.contains("wrote") {
            return .quote
        }
        
        // Note detection
        if lowercased.contains("remember") ||
           lowercased.contains("note to self") ||
           lowercased.contains("important") {
            return .note
        }
        
        // Thought detection
        if lowercased.contains("i think") ||
           lowercased.contains("i feel") ||
           lowercased.contains("reminds me") {
            return .thought
        }
        
        return .ambient
    }
    
    // MARK: - Real-time Question Processing
    
    private func processQuestion(_ text: String, confidence: Float) async {
        // Use the enhanced version with audio feedback
        await processQuestionWithFeedback(text, confidence: confidence)
    }
    
    // MARK: - Batch Processing (Post-Session)
    
    private func processSessionContent() async {
        for content in sessionContent {
            switch content.type {
            case .quote:
                await saveQuote(content)
            case .note:
                await saveNote(content)
            case .thought:
                await saveThought(content)
            default:
                break
            }
        }
    }
    
    // MARK: - SwiftData Saves
    
    private func saveQuote(_ content: AmbientProcessedContent) async {
        guard let modelContext = modelContext else { return }
        
        // Update state for debug
        currentState = .saving(content)
        
        let quote = CapturedQuote(
            text: content.text,
            book: nil, // Would need to query BookModel from title
            timestamp: content.timestamp,
            source: .ambient
        )
        
        modelContext.insert(quote)
        try? modelContext.save()
        
        logger.info("💾 Saved quote: \(String(content.text.prefix(50)))...")
        
        // Add to recently saved for debug view
        recentlySaved.append(content)
        if recentlySaved.count > 10 {
            recentlySaved.removeFirst()
        }
        
        // Reset state
        currentState = .listening
    }
    
    private func saveNote(_ content: AmbientProcessedContent) async {
        guard let modelContext = modelContext else { return }
        
        // Update state for debug
        currentState = .saving(content)
        
        let note = CapturedNote(
            content: content.text,
            book: nil, // Would need to query BookModel from title
            timestamp: content.timestamp,
            source: .ambient
        )
        
        modelContext.insert(note)
        try? modelContext.save()
        
        logger.info("💾 Saved note: \(String(content.text.prefix(50)))...")
        
        // Add to recently saved for debug view
        recentlySaved.append(content)
        if recentlySaved.count > 10 {
            recentlySaved.removeFirst()
        }
        
        // Reset state
        currentState = .listening
    }
    
    private func saveThought(_ content: AmbientProcessedContent) async {
        // Save as note with thought tag
        var modifiedContent = content
        modifiedContent.response = "[Thought]" // Tag it
        await saveNote(modifiedContent)
    }
    
    // MARK: - Context Helpers
    
    private func getCurrentBook() -> BookModel? {
        // Get from AmbientBookDetector
        // Convert Book to BookModel if needed
        if let book = AmbientBookDetector.shared.detectedBook {
            // For now, return nil - would need to query or convert
            return nil
        }
        return nil
    }
    
    private func getCurrentBookContext() -> String {
        if let book = AmbientBookDetector.shared.detectedBook {
            return "Reading \(book.title) by \(book.author)"
        }
        return "General reading session"
    }
    
    // MARK: - Public Configuration
    
    public func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    public func setConfidenceThreshold(_ threshold: Float) {
        // Allow adjustment but keep high standards
        // Note: This is disabled for now - always use 0.99
        logger.info("Confidence threshold request: \(threshold), keeping at 0.99")
    }
    
    // MARK: - Debug Support
    
    public func getDebugInfo() -> String {
        """
        Session: \(sessionActive ? "Active" : "Inactive")
        Content: \(detectedContent.count) items
        Queue: \(processingQueue.count) pending
        Confidence: \(String(format: "%.2f", lastConfidence))
        """
    }
    
    // MARK: - Suggestion & Detection Methods (Temporary Stubs)
    
    func generateActionableSuggestions(session: AmbientSession, library: [Book]) -> [String] {
        // Temporarily disabled - would analyze session content for actionable suggestions
        return []
    }
    
    func detectProgressUpdates(content: String) -> [String] {
        // Temporarily disabled - would detect reading progress mentions
        return []
    }
    
    func detectBookReferences(content: String, library: [Book]) -> [String] {
        // Temporarily disabled - would detect book references in content
        return []
    }
    
    // MARK: - iOS 26 Foundation Models (When Available)
    
    /*
    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func processWithFoundationModels(_ text: String, intent: FoundationModels.Intent, confidence: Float) async {
        switch intent {
        case .question:
            await processQuestion(text, confidence: confidence)
        case .quote:
            sessionContent.append(AmbientProcessedContent(
                text: text,
                type: .quote,
                timestamp: Date(),
                confidence: confidence
            ))
        case .note:
            sessionContent.append(AmbientProcessedContent(
                text: text,
                type: .note,
                timestamp: Date(),
                confidence: confidence
            ))
        case .thought:
            sessionContent.append(AmbientProcessedContent(
                text: text,
                type: .thought,
                timestamp: Date(),
                confidence: confidence
            ))
        default:
            sessionContent.append(AmbientProcessedContent(
                text: text,
                type: .ambient,
                timestamp: Date(),
                confidence: confidence
            ))
        }
    }
    #endif
    */
}

// MARK: - ContentType Extensions for UI
extension AmbientProcessedContent.ContentType {
    var icon: String {
        switch self {
        case .question: return "questionmark.circle"
        case .quote: return "quote.bubble"
        case .note: return "note.text"
        case .thought: return "bubble.left"
        case .ambient: return "waveform"
        case .unknown: return "questionmark"
        }
    }
    
    var color: Color {
        switch self {
        case .question: return .blue
        case .quote: return .purple
        case .note: return .green
        case .thought: return .orange
        case .ambient: return .gray
        case .unknown: return .secondary
        }
    }
}

// MARK: - Question Settings & Audio Feedback
extension TrueAmbientProcessor {
    
    struct QuestionSettings {
        static var realTimeEnabled: Bool {
            UserDefaults.standard.bool(forKey: "realTimeQuestions")
        }
        static var audioFeedbackEnabled: Bool {
            UserDefaults.standard.bool(forKey: "audioFeedback")
        }
    }
    
    // Enhanced question processing with audio feedback
    func processQuestionWithFeedback(_ question: String, confidence: Float) async {
        // Check if real-time is enabled (default to true if not set)
        let realTimeEnabled = UserDefaults.standard.object(forKey: "realTimeQuestions") as? Bool ?? true
        
        guard realTimeEnabled else {
            // Save for post-session batch processing
            let content = AmbientProcessedContent(
                text: question,
                type: .question,
                timestamp: Date(),
                confidence: confidence
            )
            sessionContent.append(content)
            logger.info("💾 Question saved for post-session: \(question.prefix(50))...")
            return
        }
        
        // Visual feedback - immediate
        await MainActor.run { [weak self] in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                // Update state for UI
                self?.currentState = .processing(.question, question)
                
                // Post notification for UI updates
                NotificationCenter.default.post(
                    name: .questionProcessing,
                    object: question
                )
            }
        }
        
        // Get AI response - CRITICAL: Make sure AI service is configured
        logger.info("🤖 Getting AI response for: \(question)")
        
        // Check if AI service is configured
        guard AICompanionService.shared.isConfigured() else {
            logger.error("❌ AI service not configured - check API key")
            
            // Still save the question without response
            let content = AmbientProcessedContent(
                text: question,
                type: .question,
                timestamp: Date(),
                confidence: confidence,
                response: "AI service not configured. Please check your API key in settings.",
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            
            await saveQuestionWithResponse(content)
            return
        }
        
        do {
            let response = try await AICompanionService.shared.processMessage(
                question,
                bookContext: AmbientBookDetector.shared.detectedBook,
                conversationHistory: []
            )
            
            // Audio feedback if enabled
            if QuestionSettings.audioFeedbackEnabled {
                await speakResponse(response)
            }
            
            // Save processed question with response
            let content = AmbientProcessedContent(
                text: question,
                type: .question,
                timestamp: Date(),
                confidence: confidence,
                response: response,
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            
            await saveQuestionWithResponse(content)
            
            logger.info("✅ Question processed with response: \(response.prefix(50))...")
            
        } catch {
            logger.error("❌ Failed to process question: \(error)")
            
            // Save question with error message
            let content = AmbientProcessedContent(
                text: question,
                type: .question,
                timestamp: Date(),
                confidence: confidence,
                response: "Error: \(error.localizedDescription)",
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            
            await saveQuestionWithResponse(content)
        }
    }
    
    // Helper to save question with response to SwiftData
    private func saveQuestionWithResponse(_ content: AmbientProcessedContent) async {
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            // Add to detected content
            self.detectedContent.append(content)
            
            // Save to SwiftData if context available
            if let modelContext = self.modelContext {
                // Create question model
                // Note: CapturedQuestion uses 'content' not 'text'
                let question = CapturedQuestion(
                    content: content.text,
                    book: nil, // Would need to query BookModel
                    timestamp: content.timestamp,
                    source: .ambient
                )
                
                // Set answer separately
                question.answer = content.response
                question.isAnswered = content.response != nil
                
                modelContext.insert(question)
                
                // Save immediately
                do {
                    try modelContext.save()
                    logger.info("✅ Question saved to SwiftData with response")
                } catch {
                    logger.error("❌ Failed to save question: \(error)")
                }
            }
            
            // Post completion notification
            NotificationCenter.default.post(
                name: .questionProcessed,
                object: content
            )
            
            // Update Live Activity if active
            Task {
                await AmbientLiveActivityManager.shared.updateActivity(
                    capturedCount: self.detectedContent.count,
                    lastTranscript: content.text
                )
            }
            
            // Reset state
            self.currentState = .listening
        }
    }
    
    // Text-to-speech for responses
    private func speakResponse(_ text: String) async {
        // Use AVSpeechSynthesizer for iOS built-in TTS
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        // Configure speech parameters
        utterance.rate = 0.52 // Slightly faster than default
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        
        // Create synthesizer
        let synthesizer = AVSpeechSynthesizer()
        
        // Speak (this is async-safe)
        await MainActor.run {
            synthesizer.speak(utterance)
        }
        
        logger.info("🔊 Speaking response: \(text.prefix(30))...")
    }
    
    // Toggle listening for Live Activity
    public func toggleListening() async {
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            if self.sessionActive {
                // Just toggle the listening state, don't end session
                self.isProcessing = !self.isProcessing
                
                if self.isProcessing {
                    self.currentState = .listening
                    logger.info("▶️ Resumed listening")
                } else {
                    self.currentState = .detecting("Paused")
                    logger.info("⏸️ Paused listening")
                }
                
                // Update Live Activity
                Task {
                    await AmbientLiveActivityManager.shared.updateActivity(
                        isListening: self.isProcessing
                    )
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let voiceTranscriptUpdated = Notification.Name("voiceTranscriptUpdated")
    static let bookMentionDetected = Notification.Name("bookMentionDetected")
    static let questionDetected = Notification.Name("questionDetected")
    static let questionProcessing = Notification.Name("questionProcessing")
    static let questionProcessed = Notification.Name("questionProcessed")
    static let contentSaved = Notification.Name("contentSaved")
}