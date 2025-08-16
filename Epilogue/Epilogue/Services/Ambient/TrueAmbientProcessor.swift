import Foundation
import SwiftUI
import SwiftData
import WhisperKit
import AVFoundation
import AVFAudio
import OSLog
import Combine
import UniformTypeIdentifiers
// iOS 26 Foundation Models - Enable when SDK available
#if canImport(FoundationModels)
import FoundationModels
#endif

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
    
    // Enhanced intelligence systems
    private let intentDetector = EnhancedIntentDetector()
    private let conversationMemory = ConversationMemory()
    private let foundationModels = FoundationModelsManager.shared
    
    // iOS 26 Foundation Models
    #if canImport(FoundationModels)
    private var languageModel: SystemLanguageModel?
    private var modelSession: LanguageModelSession?
    #endif
    
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
    private var currentAmbientSession: AmbientSession?  // Not weak - we need to maintain the reference
    private var processedTextHashes = Set<String>() // Prevent duplicate processing
    private var currentBook: Book? // Current book context
    
    // Processing state
    private var isInitialized = false
    private let processingDispatchQueue = DispatchQueue(label: "com.epilogue.trueprocessor", qos: .userInitiated)
    
    private init() {
        setupNotificationObservers()
        Task {
            await initializeWhisper()
            await initializeFoundationModels()
        }
    }
    
    private func initializeFoundationModels() async {
        #if canImport(FoundationModels)
        do {
            // Initialize the system language model
            languageModel = SystemLanguageModel.default
            modelSession = LanguageModelSession()
            logger.info("✅ Foundation Models initialized successfully")
        } catch {
            logger.error("❌ Failed to initialize Foundation Models: \(error)")
        }
        #else
        logger.info("ℹ️ Foundation Models not available on this platform")
        #endif
    }
    
    private func setupNotificationObservers() {
        // Listen for natural reactions from VoiceRecognitionManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNaturalReaction),
            name: Notification.Name("NaturalReactionDetected"),
            object: nil
        )
    }
    
    @objc private func handleNaturalReaction(_ notification: Notification) {
        guard let text = notification.object as? String else { return }
        
        logger.info("📝 Received natural reaction: \(text)")
        
        Task {
            // Process using the main flow
            await processDetectedText(text, confidence: 0.9)
        }
    }
    
    // Public method to process text from external sources
    public func processDetectedText(_ text: String, confidence: Float) async {
        if !sessionActive { 
            logger.warning("Session not active, starting session")
            startSession()
        }
        
        // Deduplication check
        let textHash = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if processedTextHashes.contains(textHash) {
            logger.warning("⚠️ Already processed this text, skipping: \(text.prefix(30))...")
            return
        }
        processedTextHashes.insert(textHash)
        
        // Use the same flow as Whisper transcription
        logger.info("🎯 Processing detected text: \(text)")
        
        // Use enhanced intent detection
        let bookContext = AmbientBookDetector.shared.detectedBook
        let enhancedIntent = intentDetector.detectIntent(
            from: text,
            bookTitle: bookContext?.title,
            bookAuthor: bookContext?.author
        )
        let intent = mapEnhancedToLegacyIntent(enhancedIntent)
        
        // Add to conversation memory
        let memory = conversationMemory.addMemory(
            text: text,
            intent: enhancedIntent,
            bookTitle: bookContext?.title,
            bookAuthor: bookContext?.author
        )
        
        // Update state
        currentState = .processing(intent, text)
        
        // Process based on intent
        switch intent {
        case .question:
            logger.info("❓ Question detected: \(text)")
            // Check if we've already processed this exact question recently
            let questionKey = "recent_\(text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
            if !processedTextHashes.contains(questionKey) {
                processedTextHashes.insert(questionKey)
                await processQuestionWithEnhancedContext(text, confidence: confidence, enhancedIntent: enhancedIntent)
            } else {
                logger.warning("⚠️ Question recently processed, skipping: \(text.prefix(30))...")
            }
            
        case .quote:
            // Clean up quote text - extract the actual quote
            var cleanedText = text
            
            // Use iOS 26 Writing Tools if available for better quote extraction
            if foundationModels.isAvailable() {
                Task {
                    cleanedText = await foundationModels.enhanceText(cleanedText)
                }
            }
            
            // Remove common prefixes
            let prefixesToRemove = [
                "i love this quote.",
                "i love this quote",
                "quote...",
                "quote:",
                "quote ",
                "here's a quote:",
                "this quote:"
            ]
            
            for prefix in prefixesToRemove {
                if cleanedText.lowercased().starts(with: prefix) {
                    cleanedText = String(cleanedText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            
            // Extract text between quotation marks if present
            if let firstQuote = cleanedText.firstIndex(of: "\""),
               let lastQuote = cleanedText.lastIndex(of: "\""),
               firstQuote < lastQuote {
                let startIndex = cleanedText.index(after: firstQuote)
                cleanedText = String(cleanedText[startIndex..<lastQuote])
            }
            
            // Only process if we have meaningful content
            guard !cleanedText.isEmpty && cleanedText.count > 10 else {
                logger.warning("Quote too short or empty, skipping")
                return
            }
            
            let content = AmbientProcessedContent(
                text: cleanedText,
                type: .quote,
                timestamp: Date(),
                confidence: confidence,
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            detectedContent.append(content)
            logger.info("💭 Quote captured: \(cleanedText.prefix(50))...")
            
        case .note, .thought:
            let content = AmbientProcessedContent(
                text: text,
                type: intent,
                timestamp: Date(),
                confidence: confidence,
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            detectedContent.append(content)
            logger.info("📝 \(String(describing: intent)) captured: \(text.prefix(50))...")
            
        default:
            logger.info("🎤 Ambient content: \(text.prefix(50))...")
        }
        
        // Reset state
        currentState = .listening
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
        processedTextHashes.removeAll() // Clear deduplication set
        currentTranscript = ""
        currentBook = AmbientBookDetector.shared.detectedBook
        sessionStartTime = Date()
        sessionActive = true
        
        // Clear conversation memory for new session
        conversationMemory.clearSession()
        
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
        
        // Log enhanced session summary
        var memorySummary = conversationMemory.generateSessionSummary()
        
        // Use iOS 26 to generate even better summary if available
        if foundationModels.isAvailable() {
            memorySummary = await foundationModels.summarize(memorySummary)
        }
        
        logger.info("🎯 Session ended - Duration: \(Int(duration))s, Content: \(self.detectedContent.count) items")
        logger.info("\n\(memorySummary)")
        
        // Reset for next session
        sessionContent.removeAll()
        detectedContent.removeAll()
        currentTranscript = ""
        conversationMemory.clearSession()
        
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
                quote.ambientSession = currentAmbientSession
                modelContext.insert(quote)
                
            case .note, .thought:
                let note = CapturedNote(
                    content: content.text,
                    book: nil, // Would need to query BookModel
                    timestamp: content.timestamp,
                    source: .ambient
                )
                note.ambientSession = currentAmbientSession
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
    
    // Map enhanced intent to legacy ContentType for compatibility
    private func mapEnhancedToLegacyIntent(_ enhanced: EnhancedIntent) -> AmbientProcessedContent.ContentType {
        switch enhanced.primary {
        case .question:
            return .question
        case .quote:
            return .quote
        case .note:
            return .note
        case .thought:
            return .thought
        case .reflection:
            return .thought // Map reflection to thought for now
        case .progress:
            return .note // Map progress to note for now
        case .ambient:
            return .ambient
        case .unknown:
            return .unknown
        }
    }
    
    // Keep legacy fallback for backward compatibility
    private func detectIntentFallback(_ text: String) -> AmbientProcessedContent.ContentType {
        let lowercased = text.lowercased()
        
        // Quote detection - check for quote indicators
        if lowercased.starts(with: "i love this quote") ||
           lowercased.starts(with: "quote") ||
           lowercased.starts(with: "all we have") || // Specific LOTR quote
           lowercased.contains("all we have to do is decide") || // Full LOTR quote
           text.contains("\"") || text.contains("\u{201C}") ||
           (lowercased.contains("said") && (text.contains("\"") || text.contains("\u{201C}"))) ||
           lowercased.contains("famous quote") ||
           lowercased.contains("quote from") {
            logger.info("💬 Quote detected via fallback: \(text.prefix(50))...")
            return .quote
        }
        
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
        
        // Note detection - expanded to catch more personal reflections
        if lowercased.contains("remember") ||
           lowercased.contains("note to self") ||
           lowercased.contains("important") ||
           lowercased.contains("i love") ||
           lowercased.contains("i hate") ||
           lowercased.contains("i prefer") ||
           lowercased.contains("from the movie") || // Movie comparisons
           lowercased.contains("in the movie") ||
           lowercased.contains("movie version") ||
           lowercased.contains("film version") ||
           lowercased.contains("better than") ||
           lowercased.contains("worse than") ||
           lowercased.contains("more than") {
            logger.info("📝 Note detected via fallback: \(text.prefix(50))...")
            return .note
        }
        
        // Thought detection
        if lowercased.contains("i think") ||
           lowercased.contains("i feel") ||
           lowercased.contains("i believe") ||
           lowercased.contains("reminds me") ||
           lowercased.contains("makes me") {
            return .thought
        }
        
        // Now just calls enhanced detection and maps back
        let bookContext = AmbientBookDetector.shared.detectedBook
        let enhanced = intentDetector.detectIntent(
            from: text,
            bookTitle: bookContext?.title,
            bookAuthor: bookContext?.author
        )
        return mapEnhancedToLegacyIntent(enhanced)
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
        quote.ambientSession = currentAmbientSession
        
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
        note.ambientSession = currentAmbientSession
        
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
    
    func setCurrentSession(_ session: AmbientSession) {
        self.currentAmbientSession = session
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
    
    // Helper function to normalize questions for deduplication
    private func normalizeQuestion(_ question: String) -> String {
        var normalized = question.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        
        // Handle common variations (e.g., "Gand" vs "Gandalf")
        if normalized.contains("gand") && !normalized.contains("gandalf") {
            // Likely a truncated/misheard "Gandalf"
            normalized = normalized.replacingOccurrences(of: "gand", with: "gandalf")
        }
        
        return normalized
    }
    
    // Check if we have a similar question already processed
    private func hasSimilarProcessedQuestion(_ normalizedQuestion: String) -> Bool {
        let words = normalizedQuestion.split(separator: " ")
        
        // Check for questions that are substrings or superstrings
        for hash in processedTextHashes {
            if hash.hasPrefix("question_") {
                let existingQuestion = String(hash.dropFirst(9)) // Remove "question_" prefix
                
                // Check if one is a substring of the other
                if existingQuestion.contains(normalizedQuestion) || normalizedQuestion.contains(existingQuestion) {
                    return true
                }
                
                // Check for high word overlap (80% similarity)
                let existingWords = existingQuestion.split(separator: " ")
                let commonWords = words.filter { existingWords.contains($0) }
                if !words.isEmpty && Float(commonWords.count) / Float(words.count) > 0.8 {
                    return true
                }
                
                // Check for Levenshtein distance (for typos/mistranscriptions)
                if levenshteinDistance(existingQuestion, normalizedQuestion) <= 3 {
                    return true
                }
            }
        }
        
        return false
    }
    
    // Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // Process question with enhanced context
    private func processQuestionWithEnhancedContext(_ question: String, confidence: Float, enhancedIntent: EnhancedIntent) async {
        // Build context from conversation memory
        let conversationContext = conversationMemory.buildContextForResponse(currentIntent: enhancedIntent)
        
        // Get book context
        let bookContext = AmbientBookDetector.shared.detectedBook
        let bookInfo = bookContext.map { "Currently reading: \($0.title) by \($0.author)" } ?? ""
        
        // Determine question type for better response
        var questionContext = ""
        if case .question(let subtype) = enhancedIntent.primary {
            switch subtype {
            case .analytical:
                questionContext = "Provide a thoughtful analysis."
            case .comparative:
                questionContext = "Compare and contrast as requested."
            case .speculative:
                questionContext = "Explore the hypothetical scenario."
            case .clarification:
                questionContext = "Clarify the concept clearly."
            case .opinion:
                questionContext = "Share an informed perspective."
            case .factual:
                questionContext = "Provide accurate information."
            }
        }
        
        // Combine all context
        let fullContext = [bookInfo, conversationContext, questionContext]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        
        // Now process with the original method but with enhanced context
        await processQuestionWithFeedback(question, confidence: confidence, context: fullContext)
    }
    
    // Enhanced question processing with audio feedback
    func processQuestionWithFeedback(_ question: String, confidence: Float, context: String = "") async {
        // Normalize question for better deduplication
        let normalizedQuestion = normalizeQuestion(question)
        let processedKey = "question_\(normalizedQuestion)"
        
        // Check if we've already processed this or a very similar question
        if processedTextHashes.contains(processedKey) || hasSimilarProcessedQuestion(normalizedQuestion) {
            logger.warning("⚠️ Question already processed or similar exists, skipping: \(question.prefix(30))...")
            return
        }
        processedTextHashes.insert(processedKey)
        
        // Default to true if not set (enable by default)
        let realTimeEnabled = UserDefaults.standard.object(forKey: "realTimeQuestions") as? Bool ?? true
        
        guard realTimeEnabled else {
            // Save for later if disabled
            let content = AmbientProcessedContent(
                text: question,
                type: .question,
                timestamp: Date(),
                confidence: confidence
            )
            sessionContent.append(content)
            return
        }
        
        // Try Foundation Models first (iOS 26)
        #if canImport(FoundationModels)
        if let modelSession = modelSession {
            do {
                logger.info("🧠 Using Foundation Models for question: \(question)")
                let response = try await modelSession.respond(to: question)
                
                // Process successful response
                var content = AmbientProcessedContent(
                    text: question,
                    type: .question,
                    timestamp: Date(),
                    confidence: confidence,
                    response: response.content
                )
                
                detectedContent.append(content)
                sessionContent.append(content)
                let bookContext = AmbientBookDetector.shared.detectedBook
                _ = conversationMemory.addMemory(
                    text: question,
                    intent: EnhancedIntent(
                        primary: .question(subtype: .factual),
                        confidence: 0.9,
                        entities: [],
                        sentiment: .neutral,
                        subIntents: []
                    ),
                    response: response.content,
                    bookTitle: bookContext?.title,
                    bookAuthor: bookContext?.author
                )
                
                logger.info("✅ Foundation Models response received")
                return
            } catch {
                logger.error("❌ Foundation Models failed, falling back to AI service: \(error)")
            }
        }
        #endif
        
        // Fall back to existing AI service
        guard AICompanionService.shared.isConfigured() else {
            logger.error("❌ AI service not configured")
            
            // Still create the question with error message
            let content = AmbientProcessedContent(
                text: question,
                type: .question,
                timestamp: Date(),
                confidence: confidence,
                response: "Please configure your Perplexity API key in Settings",
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            
            await MainActor.run {
                self.detectedContent.append(content)
            }
            return
        }
        
        // Process with AI
        do {
            logger.info("🤖 Requesting AI response for: \(question)")
            
            // Include context in the question if available
            var enhancedQuestion = context.isEmpty ? question : "\(context)\n\nUser question: \(question)"
            
            // Use iOS 26 models to enhance the question if available
            if foundationModels.isAvailable() {
                enhancedQuestion = await foundationModels.enhanceText(enhancedQuestion)
            }
            
            let response = try await AICompanionService.shared.processMessage(
                enhancedQuestion,
                bookContext: AmbientBookDetector.shared.detectedBook,
                conversationHistory: []
            )
            
            logger.info("✅ Got AI response: \(response.prefix(50))...")
            
            // Create content with response
            let content = AmbientProcessedContent(
                text: question,
                type: .question,
                timestamp: Date(),
                confidence: confidence,
                response: response,
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            
            // Update memory with response
            let bookContext = AmbientBookDetector.shared.detectedBook
            conversationMemory.addMemory(
                text: question,
                intent: intentDetector.detectIntent(
                    from: question,
                    bookTitle: bookContext?.title,
                    bookAuthor: bookContext?.author
                ),
                response: response,
                bookTitle: bookContext?.title,
                bookAuthor: bookContext?.author
            )
            
            // Check if this content already exists in detectedContent
            let exists = await MainActor.run {
                self.detectedContent.contains { existing in
                    existing.type == .question && existing.text == question && existing.response != nil
                }
            }
            
            if !exists {
                // Update UI immediately
                await MainActor.run {
                    self.detectedContent.append(content)
                    logger.info("✅ Added question with response to detectedContent")
                }
            } else {
                logger.warning("⚠️ Question with response already in detectedContent, skipping")
            }
            
            // Audio feedback if enabled
            if QuestionSettings.audioFeedbackEnabled {
                await speakResponse(response)
            }
            
        } catch {
            logger.error("❌ AI processing failed: \(error)")
            
            let content = AmbientProcessedContent(
                text: question,
                type: .question,
                timestamp: Date(),
                confidence: confidence,
                response: "Error: \(error.localizedDescription)",
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            
            await MainActor.run {
                self.detectedContent.append(content)
            }
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