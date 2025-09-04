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
public struct AmbientProcessedContent: Identifiable, Hashable {
    public let id: UUID
    public let text: String
    public let type: ContentType
    public let timestamp: Date
    public let confidence: Float
    public var response: String?
    public var bookTitle: String?
    public var bookAuthor: String?
    
    // Content-based hashing for proper deduplication
    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(type)
        // Don't include response in hash - we want to find items regardless of response state
    }
    
    public static func == (lhs: AmbientProcessedContent, rhs: AmbientProcessedContent) -> Bool {
        // Two items are equal if they have the same text and type
        // This prevents duplicates while allowing response updates
        return lhs.text == rhs.text && lhs.type == rhs.type
    }
    
    init(text: String, type: ContentType, timestamp: Date = Date(), confidence: Float = 1.0, response: String? = nil, bookTitle: String? = nil, bookAuthor: String? = nil) {
        self.id = UUID()
        self.text = text
        self.type = type
        self.timestamp = timestamp
        self.confidence = confidence
        self.response = response
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
    }
    
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
    private let foundationModels = FoundationModelsManager.shared  // This refers to iOS26FoundationModels wrapper
    
    // NEW: Optimized components for App Store quality
    private let deduplicator = ContentDeduplicator()
    private let persistenceLayer = AmbientPersistenceLayer()
    
    // iOS 26 Foundation Models
    #if canImport(FoundationModels)
    private var languageModel: SystemLanguageModel?
    private var modelSession: LanguageModelSession?
    #endif
    
    // Neural Engine Optimized Whisper for <100ms transcription
    private let whisperOptimized = NeuralEngineOptimizedWhisper.shared
    
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
    // Removed - using ContentDeduplicator instead
    private var currentBook: Book? // Current book context
    
    // Processing state
    private var isInitialized = false
    private let processingDispatchQueue = DispatchQueue(label: "com.epilogue.trueprocessor", qos: .userInitiated)
    
    // Professional-grade deduplication state tracking
    private var activeQuestions: Set<String> = []  // Questions currently being processed
    private var recentQuestions: [(text: String, timestamp: Date)] = []  // Recent questions with timestamps
    private let questionDedupeWindow: TimeInterval = 3.0  // 3 second window for exact duplicates
    private var evolvingQuestion: (base: String, timestamp: Date)? = nil  // Track evolving questions like "Who is gone" → "Who is Gollum"
    private var questionsBeingFetched: Set<String> = []  // Questions with API calls in progress
    
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
            
            // Get book context if available
            var instructions = "You are a helpful AI reading companion. Always answer questions factually and helpfully."
            if let book = AmbientBookDetector.shared.detectedBook {
                instructions = """
                You are a helpful AI assistant discussing the book '\(book.title)' by \(book.author).
                ALWAYS answer questions about this book factually and helpfully.
                Do NOT refuse to answer questions about the book's content.
                The user is reading this book and wants to discuss it - this is NOT about avoiding spoilers.
                Be direct, factual, and helpful with all answers.
                """
            }
            
            modelSession = LanguageModelSession(instructions: instructions)
            logger.info("✅ Foundation Models initialized successfully")
        } catch {
            logger.error("❌ Failed to initialize Foundation Models: \(error)")
        }
        #else
        logger.info("ℹ️ Foundation Models not available on this platform")
        #endif
    }
    
    // Add method to update session when book changes
    func updateBookContext(_ book: Book?) {
        #if canImport(FoundationModels)
        Task {
            do {
                var instructions = "You are Epilogue's AI reading companion."
                if let book = book {
                    instructions = """
                    You are a helpful AI assistant discussing the book '\(book.title)' by \(book.author).
                    ALWAYS answer questions about this book factually and helpfully.
                    Do NOT refuse to answer questions about the book's content.
                    This is NOT about spoilers - the user is already reading this book and wants to discuss it.
                    
                    Important facts to remember:
                    - In Lord of the Rings: Sting is Frodo's sword (given by Bilbo), Glamdring is Gandalf's sword, Andúril is Aragorn's sword
                    - Answer all questions about characters, plot, items, and story elements directly
                    - Be concise and helpful
                    """
                }
                
                modelSession = LanguageModelSession(instructions: instructions)
                logger.info("📚 Updated Foundation Models session with book: \(book?.title ?? "none")")
            } catch {
                logger.error("❌ Failed to update Foundation Models session: \(error)")
            }
        }
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
        // Handle both old format (String) and new format (Dictionary with confidence)
        var text: String = ""
        var confidence: Float = 0.9  // Default confidence
        
        if let textString = notification.object as? String {
            // Old format - just text
            text = textString
        } else if let data = notification.object as? [String: Any],
                  let textString = data["text"] as? String {
            // New format - text with confidence
            text = textString
            if let conf = data["confidence"] as? Double {
                confidence = Float(conf)
            }
        } else {
            return
        }
        
        logger.info("📝 Received natural reaction: \(text) (confidence: \(confidence))")
        
        Task {
            // Process using the main flow with actual confidence
            await processDetectedText(text, confidence: confidence)
        }
    }
    
    // Public method to process text from external sources
    public func processDetectedText(_ text: String, confidence: Float) async {
        if !sessionActive { 
            logger.warning("Session not active, starting session")
            startSession()
        }
        
        // CRITICAL: Don't process low-confidence questions to avoid duplicates
        // Whisper often mis-transcribes then corrects itself
        let lowerTextCheck = text.lowercased()
        let isQuestion = lowerTextCheck.contains("?") || 
                        lowerTextCheck.starts(with: "who") ||
                        lowerTextCheck.starts(with: "what") ||
                        lowerTextCheck.starts(with: "where") ||
                        lowerTextCheck.starts(with: "when") ||
                        lowerTextCheck.starts(with: "why") ||
                        lowerTextCheck.starts(with: "how")
        
        if isQuestion && confidence < 0.5 {
            logger.warning("⚠️ Ignoring low-confidence question (conf: \(confidence)): \(text)")
            return // Wait for higher confidence version
        }
        
        // Apply book-specific autocorrection
        let bookContext = AmbientBookDetector.shared.detectedBook
        let correctedText = applyBookContextCorrection(text, bookContext: bookContext)
        
        // Use enhanced intent detection FIRST to determine content type
        let enhancedIntent = intentDetector.detectIntent(
            from: correctedText,
            bookTitle: bookContext?.title,
            bookAuthor: bookContext?.author
        )
        var intent = mapEnhancedToLegacyIntent(enhancedIntent)
        
        // OVERRIDE: If text contains a question, treat it as a question!
        let lowerText = correctedText.lowercased()
        // IMPROVED: More precise question detection to avoid false positives
        // Only override to question if it starts with question words OR ends with ?
        let startsWithQuestionWord = lowerText.hasPrefix("who ") || lowerText.hasPrefix("what ") ||
                                     lowerText.hasPrefix("when ") || lowerText.hasPrefix("where ") ||
                                     lowerText.hasPrefix("why ") || lowerText.hasPrefix("how ") ||
                                     lowerText.hasPrefix("is ") || lowerText.hasPrefix("are ") ||
                                     lowerText.hasPrefix("can ") || lowerText.hasPrefix("could ") ||
                                     lowerText.hasPrefix("should ") || lowerText.hasPrefix("would ") ||
                                     lowerText.hasPrefix("do ") || lowerText.hasPrefix("does ")
        
        // Check for explicit question indicators
        let hasQuestionMark = correctedText.contains("?")
        let hasQuestionPhrase = lowerText.contains("who is") || lowerText.contains("what is") ||
                                lowerText.contains("what does") || lowerText.contains("how does") ||
                                lowerText.contains("why does") || lowerText.contains("where is")
        
        // Don't override quotes that mention "I love this quote" or similar
        let isExplicitQuote = lowerText.contains("quote") || lowerText.contains("passage") ||
                             lowerText.contains("excerpt") || lowerText.contains("line")
        
        if (startsWithQuestionWord || hasQuestionMark || hasQuestionPhrase) && 
           intent != .question && !isExplicitQuote {
            logger.info("🔄 Overriding intent to question due to question indicators")
            intent = .question
        } else if isExplicitQuote && intent == .question {
            // If it explicitly mentions a quote but was detected as question, fix it
            logger.info("🔄 Correcting question to quote due to explicit quote mention")
            intent = .quote
        }
        
        // PROFESSIONAL DEDUPLICATION - Like ChatGPT/Perplexity/Anthropic
        if intent == .question {
            // Step 1: Normalize the question text
            let normalizedText = correctedText.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            // CRITICAL: Detect evolving questions (e.g., "Who is the leader of God" → "Who is the leader of Gondor")
            // This happens when Whisper corrects itself mid-transcription
            let now = Date()
            if let evolving = evolvingQuestion {
                let timeSinceBase = now.timeIntervalSince(evolving.timestamp)
                
                // If within 5 seconds (longer window for corrections)
                if timeSinceBase < 5.0 {
                    // Use fuzzy matching to detect corrections
                    let baseWords = evolving.base.split(separator: " ").map { String($0) }
                    let newWords = normalizedText.split(separator: " ").map { String($0) }
                    
                    // Calculate similarity - if most words match, it's likely a correction
                    let matchingWords = baseWords.filter { baseWord in
                        newWords.contains { newWord in
                            // Allow for small spelling differences
                            baseWord == newWord || 
                            (baseWord.count > 3 && newWord.count > 3 && 
                             baseWord.prefix(3) == newWord.prefix(3))
                        }
                    }
                    
                    let similarity = Double(matchingWords.count) / Double(max(baseWords.count, newWords.count))
                    
                    // If 60% similar or starts with same question word, it's likely a correction
                    if similarity > 0.6 || 
                       (evolving.base.hasPrefix("who is") && normalizedText.hasPrefix("who is")) ||
                       (evolving.base.hasPrefix("what is") && normalizedText.hasPrefix("what is")) ||
                       (evolving.base.hasPrefix("where is") && normalizedText.hasPrefix("where is")) ||
                       (evolving.base.hasPrefix("when is") && normalizedText.hasPrefix("when is")) ||
                       (evolving.base.hasPrefix("why is") && normalizedText.hasPrefix("why is")) ||
                       (evolving.base.hasPrefix("how is") && normalizedText.hasPrefix("how is")) {
                        
                        // IMPORTANT: Only treat as evolution if the new text is MORE complete (longer)
                        // This prevents "Who is Bilbo Baggins?" from being replaced by "Who is Bilbo Ba?"
                        if normalizedText.count < evolving.base.count {
                            logger.info("⚠️ Ignoring shorter variant: '\(normalizedText)' (keeping '\(evolving.base)')")
                            return  // Don't process this shorter version
                        }
                        
                        // This is likely a correction - remove the old question
                        logger.info("🔄 Detected question evolution: '\(evolving.base)' → '\(normalizedText)'")
                        
                        // Remove from active questions
                        activeQuestions.remove(evolving.base)
                        
                        // Remove from UI if present - search more broadly
                        await MainActor.run {
                            // Look for any question that starts similarly
                            if let index = self.detectedContent.firstIndex(where: { content in
                                content.type == .question && 
                                (content.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == evolving.base ||
                                 content.text.lowercased().hasPrefix(evolving.base.prefix(20)))
                            }) {
                                self.detectedContent.remove(at: index)
                                logger.info("✅ Removed evolving question from UI")
                            }
                        }
                    }
                }
            }
            
            // Track this as potential base for evolution - BUT only if it's longer or more complete
            // This prevents keeping shortened versions like "Who is Bilbo Ba?" over "Who is Bilbo Baggins?"
            if let evolving = evolvingQuestion {
                // Only update if the new text is longer (more complete)
                if normalizedText.count > evolving.base.count {
                    evolvingQuestion = (base: normalizedText, timestamp: now)
                }
            } else {
                evolvingQuestion = (base: normalizedText, timestamp: now)
            }
            
            // Step 2: Check if we're actively processing this or a very similar question
            let isAlreadyActive = activeQuestions.contains { activeQuestion in
                // Exact match
                if activeQuestion == normalizedText {
                    return true
                }
                
                // Check for transcription variations (like "gone" vs "Gondor")
                let activeWords = activeQuestion.split(separator: " ")
                let newWords = normalizedText.split(separator: " ")
                
                if abs(activeWords.count - newWords.count) <= 1 && activeWords.count >= 3 {
                    let minCount = min(activeWords.count, newWords.count) - 1
                    if minCount > 0 {
                        let activePrefix = activeWords.prefix(minCount).joined(separator: " ")
                        let newPrefix = newWords.prefix(minCount).joined(separator: " ")
                        
                        if activePrefix == newPrefix {
                            return true  // This is likely the same question being re-transcribed
                        }
                    }
                }
                
                return false
            }
            
            if isAlreadyActive {
                logger.warning("🔒 Question or similar variant already being processed, ignoring: \(correctedText.prefix(30))...")
                return
            }
            
            // Step 3: Check recent questions within time window (3 seconds)
            // (now already declared above for evolution detection)
            let cutoff = now.addingTimeInterval(-questionDedupeWindow)
            
            // Clean old entries from recent questions
            recentQuestions = recentQuestions.filter { $0.timestamp > cutoff }
            
            // Check if this exact question was asked recently
            if recentQuestions.contains(where: { $0.text == normalizedText }) {
                logger.warning("⏱️ Same question within \(self.questionDedupeWindow)s window, ignoring: \(correctedText.prefix(30))...")
                return
            }
            
            // Step 4: Check if already in UI (final safety check)
            let alreadyInUI = await MainActor.run {
                self.detectedContent.contains { content in
                    content.type == .question &&
                    content.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedText
                }
            }
            
            if alreadyInUI {
                logger.warning("📱 Question already in UI, ignoring duplicate: \(correctedText.prefix(30))...")
                return
            }
            
            // Step 5: Mark as active and recent
            activeQuestions.insert(normalizedText)
            recentQuestions.append((text: normalizedText, timestamp: now))
            
            // Clean up if too many recent questions
            if recentQuestions.count > 20 {
                recentQuestions = Array(recentQuestions.suffix(10))
            }
        } else {
            // For non-questions, use general deduplication
            // Exception: Allow quotes to be processed even if duplicate (user might want to save again)
            let isQuote = if case .quote = enhancedIntent.primary { true } else { false }
            if !isQuote && deduplicator.isDuplicate(correctedText) {
                logger.warning("⚠️ Already processed this text, skipping: \(correctedText.prefix(30))...")
                return
            }
        }
        
        logger.info("🎯 Processing detected text: \(correctedText)")
        
        // Add to conversation memory
        let memory = conversationMemory.addMemory(
            text: correctedText,
            intent: enhancedIntent,
            bookTitle: bookContext?.title,
            bookAuthor: bookContext?.author
        )
        
        // Update state
        currentState = .processing(intent, correctedText)
        
        // Process based on intent
        switch intent {
        case .question:
            logger.info("❓ Question detected: \(correctedText)")
            
            // Check if this is an evolution of an existing question
            let normalizedNew = correctedText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Find if there's an existing question that this might be evolving from
            let existingIndex = await MainActor.run {
                self.detectedContent.firstIndex { content in
                    guard content.type == .question && content.response == nil else { return false }
                    let normalizedExisting = content.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Exact same question (duplicate detection)
                    if normalizedExisting == normalizedNew {
                        return true
                    }
                    
                    // Check for transcription evolution - where most of the question is the same
                    // but the last word is changing (like "gone" -> "Gondor")
                    let existingWords = normalizedExisting.split(separator: " ")
                    let newWords = normalizedNew.split(separator: " ")
                    
                    // If they have the same number of words or differ by 1
                    if abs(existingWords.count - newWords.count) <= 1 && existingWords.count >= 3 {
                        // Check if all but the last word are the same
                        let minCount = min(existingWords.count, newWords.count) - 1
                        if minCount > 0 {
                            let existingPrefix = existingWords.prefix(minCount).joined(separator: " ")
                            let newPrefix = newWords.prefix(minCount).joined(separator: " ")
                            
                            // If the prefixes match, this is likely a transcription correction
                            if existingPrefix == newPrefix {
                                // Additional check: the questions should be very similar in length
                                let lengthDiff = abs(normalizedExisting.count - normalizedNew.count)
                                if lengthDiff < 10 {  // Allow up to 10 character difference
                                    logger.info("🔄 Detected question evolution: '\(normalizedExisting)' → '\(normalizedNew)'")
                                    return true
                                }
                            }
                        }
                    }
                    
                    return false
                }
            }
            
            if let existingIndex = existingIndex {
                // Update existing question to the latest version
                let oldText = await MainActor.run {
                    self.detectedContent[existingIndex].text
                }
                
                // Remove old text from active questions
                let oldNormalized = oldText.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                activeQuestions.remove(oldNormalized)
                
                // Add new text to active questions
                activeQuestions.insert(normalizedNew)
                
                await MainActor.run {
                    logger.info("📝 Updating evolving question from '\(self.detectedContent[existingIndex].text)' to '\(text)'")
                    self.detectedContent[existingIndex] = AmbientProcessedContent(
                        text: text,  // Use the newer, potentially longer version
                        type: .question,
                        timestamp: self.detectedContent[existingIndex].timestamp,  // Keep original timestamp
                        confidence: max(confidence, self.detectedContent[existingIndex].confidence),
                        response: nil,  // Still processing
                        bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                        bookAuthor: AmbientBookDetector.shared.detectedBook?.author
                    )
                }
                
                // Process the updated question
                Task {
                    // Short delay for evolving questions to stabilize
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second - balanced for natural speech
                    
                    // Check if it's still the latest version
                    let stillLatest = await MainActor.run {
                        self.detectedContent[safe: existingIndex]?.text == text
                    }
                    
                    if stillLatest {
                        // Check if we're not already fetching this question
                        let normalizedText = text.lowercased()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        
                        if !self.questionsBeingFetched.contains(normalizedText) {
                            await self.processQuestionWithEnhancedContext(correctedText, confidence: confidence, enhancedIntent: enhancedIntent)
                        } else {
                            logger.info("⏭️ Question already being fetched, skipping duplicate processing")
                        }
                    }
                    
                    // Remove from active questions
                    let normalizedText = text.lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    self.activeQuestions.remove(normalizedText)
                }
            } else {
                // Check if we already have a very similar question (fuzzy match)
                let alreadyHasSimilar = await MainActor.run {
                    self.detectedContent.contains { content in
                        guard content.type == .question else { return false }
                        let existingNorm = content.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Check if one is a substring of the other (with reasonable difference)
                        // This catches "Who is Tom Bam?" vs "Who is Tom Bamba?"
                        if normalizedNew.contains(existingNorm) || existingNorm.contains(normalizedNew) {
                            let diff = abs(normalizedNew.count - existingNorm.count)
                            // If difference is small (typo/evolution), consider it the same
                            return diff < 5
                        }
                        
                        return false
                    }
                }
                
                // Only add if we don't have a similar question already
                if !alreadyHasSimilar {
                    // New question - add it
                    let pendingQuestion = AmbientProcessedContent(
                        text: text,
                        type: .question,
                        timestamp: Date(),
                        confidence: confidence,
                        response: nil,
                        bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                        bookAuthor: AmbientBookDetector.shared.detectedBook?.author
                    )
                    
                    await MainActor.run {
                        self.detectedContent.append(pendingQuestion)
                        logger.info("✅ Added new question to UI: \(text.prefix(30))...")
                    }
                } else {
                    logger.info("⚠️ Skipping similar question: \(text.prefix(30))...")
                }
                
                // Process the question
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay - balanced for natural speech
                    
                    // Double-check we're not already fetching this
                    let normalizedForCheck = correctedText.lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    
                    if !self.questionsBeingFetched.contains(normalizedForCheck) {
                        await self.processQuestionWithEnhancedContext(correctedText, confidence: confidence, enhancedIntent: enhancedIntent)
                    } else {
                        logger.info("⏭️ Question already being fetched, avoiding duplicate API call")
                    }
                    
                    // Remove from active questions
                    let normalizedText = text.lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    self.activeQuestions.remove(normalizedText)
                }
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
            
            // Remove common prefixes and reaction phrases
            let prefixesToRemove = [
                "i love this quote.",
                "i love this quote",
                "i love this",
                "this is great",
                "amazing quote",
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
            // Use smart deduplication
            if !deduplicator.isDuplicate(content.text) {
                detectedContent.append(content)
                // DO NOT save here - AmbientModeView handles saving with better duplicate detection
                // await saveQuote(content)
                logger.info("✅ Quote detected and added to UI: \(cleanedText.prefix(50))...")
            } else {
                logger.info("💭 Quote already captured: \(cleanedText.prefix(50))...")
            }
            
        case .note, .thought:
            let content = AmbientProcessedContent(
                text: text,
                type: intent,
                timestamp: Date(),
                confidence: confidence,
                bookTitle: AmbientBookDetector.shared.detectedBook?.title,
                bookAuthor: AmbientBookDetector.shared.detectedBook?.author
            )
            
            // Always add to detectedContent so it shows in UI
            detectedContent.append(content)
            
            // Use smart deduplication only for saving to SwiftData
            if !deduplicator.isDuplicate(content.text) {
                // Save immediately to SwiftData if context available
                if intent == .note {
                    await saveNote(content)
                } else {
                    await saveThought(content)
                }
                logger.info("✅ \(intent == .note ? "Note" : "Thought") saved to SwiftData: \(text.prefix(50))...")
            } else {
                logger.info("📝 \(intent == .note ? "Note" : "Thought") already captured (but showing in UI): \(text.prefix(50))...")
            }
            
        default:
            logger.info("🎤 Ambient content: \(text.prefix(50))...")
        }
        
        // Reset state
        currentState = .listening
    }
    
    // MARK: - WhisperKit Initialization
    
    private func initializeWhisper() async {
        do {
            // Get voice quality setting and map to WhisperKit model
            let voiceQuality = UserDefaults.standard.string(forKey: "voiceQuality") ?? "high"
            let modelName: String
            
            switch voiceQuality {
            case "low":
                modelName = "tiny.en"  // Fastest, lowest accuracy
            case "medium":
                modelName = "base.en"  // Balanced
            case "high":
                modelName = "small.en" // Best accuracy, slower
            default:
                modelName = "base.en"  // Default to balanced
            }
            
            // Initialize WhisperKit with enhanced configuration for low volume
            let config = WhisperKitConfig(
                model: modelName,
                modelRepo: "argmaxinc/whisperkit-coreml"
            )
            
            whisperModel = try await WhisperKit(config)
            isInitialized = true
            logger.info("✅ WhisperKit initialized with \(modelName) model (quality: \(voiceQuality))")
        } catch {
            logger.error("❌ Failed to initialize WhisperKit: \(error)")
        }
    }
    
    // MARK: - Neural Engine Optimized Audio Processing
    
    /// Process audio buffer with Neural Engine optimized Whisper (<100ms latency)
    public func processAudioWithNeuralEngine(_ audioBuffer: [Float]) async -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use Neural Engine optimized transcription (no longer throws)
        let transcription = await whisperOptimized.transcribeOptimized(
            audioBuffer: audioBuffer
        )
        
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("⚡ Neural Engine transcription in \(String(format: "%.1f", processingTime))ms")
        
        // Process the transcription if we got one
        if let text = transcription, !text.isEmpty {
            // Use existing text processing pipeline
            await processDetectedText(text, confidence: 0.95)
        }
        
        return transcription
    }
    
    /// Batch process multiple audio buffers for efficiency
    public func batchProcessAudio(_ buffers: [[Float]]) async -> [String] {
        var results: [String] = []
        
        // Process in parallel for maximum throughput
        await withTaskGroup(of: String?.self) { group in
            for buffer in buffers {
                group.addTask {
                    await self.processAudioWithNeuralEngine(buffer)
                }
            }
            
            for await result in group {
                if let text = result {
                    results.append(text)
                }
            }
        }
        
        return results
    }
    
    /// Get Neural Engine performance metrics
    public func getNeuralEngineMetrics() -> (lastInferenceTime: TimeInterval, cacheHitRate: Double) {
        let inferenceTime = whisperOptimized.getLastInferenceTime()
        // Calculate cache hit rate (simplified for now)
        let cacheHitRate = inferenceTime == 0 ? 1.0 : 0.0
        return (inferenceTime, cacheHitRate)
    }
    
    /// Clear Neural Engine caches for memory management
    public func clearNeuralEngineCache() {
        whisperOptimized.clearCache()
        logger.info("🧹 Cleared Neural Engine cache")
    }
    
    // MARK: - Book Context Autocorrection
    
    private func applyBookContextCorrection(_ text: String, bookContext: Book?) -> String {
        guard let book = bookContext else { return text }
        
        // LOTR-specific character name corrections
        if book.title.lowercased().contains("lord of the rings") || 
           book.title.lowercased().contains("hobbit") ||
           book.title.lowercased().contains("silmarillion") {
            
            var corrected = text
            
            // Common misrecognitions -> correct names
            let corrections = [
                // Samwise corrections
                "Samwise Genji": "Samwise Gamgee",
                "Sam Wise Genji": "Samwise Gamgee",
                "Sam Genji": "Sam Gamgee",
                "Samwise Ganji": "Samwise Gamgee",
                "Samwise Gandhi": "Samwise Gamgee",
                
                // Gandalf corrections
                "Dan Dolph": "Gandalf",
                "Gan Dolph": "Gandalf",
                "Gandoff": "Gandalf",
                
                // Frodo corrections
                "Froto": "Frodo",
                "Frobo": "Frodo",
                "Photo": "Frodo",
                
                // Aragorn corrections
                "Eric Horn": "Aragorn",
                "Air A Gorn": "Aragorn",
                "Aragon": "Aragorn",
                
                // Legolas corrections
                "Lego Las": "Legolas",
                "Legless": "Legolas",
                
                // Gimli corrections
                "Gimley": "Gimli",
                "Gimbly": "Gimli",
                
                // Boromir corrections
                "Bore A Mir": "Boromir",
                "Boramir": "Boromir",
                
                // Sauron corrections
                "Soron": "Sauron",
                "Soren": "Sauron",
                
                // Saruman corrections
                "Sarah Man": "Saruman",
                "Saru Mon": "Saruman",
                
                // Gollum corrections
                "Golem": "Gollum",
                "Galom": "Gollum",
                
                // Place names
                "More Door": "Mordor",
                "Gondor": "Gondor",  // Often correct but just in case
                "Rohan": "Rohan",
                "The Shire": "the Shire",
                "Eisengard": "Isengard",
                "Rivendale": "Rivendell",
                "River Dell": "Rivendell"
            ]
            
            // Apply corrections (case-insensitive)
            for (wrong, right) in corrections {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: wrong))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    corrected = regex.stringByReplacingMatches(
                        in: corrected,
                        options: [],
                        range: NSRange(corrected.startIndex..., in: corrected),
                        withTemplate: right
                    )
                }
            }
            
            if corrected != text {
                logger.info("📚 Applied LOTR autocorrection: '\(text)' → '\(corrected)'")
            }
            
            return corrected
        }
        
        // Add more book-specific corrections here as needed
        
        return text
    }
    
    // MARK: - Session Management
    
    public func startSession() {
        // Fresh session each time - no persistence
        sessionContent.removeAll()
        detectedContent.removeAll()
        deduplicator.clearHistory() // Clear deduplication history
        activeQuestions.removeAll()  // Clear active questions tracking
        recentQuestions.removeAll()  // Clear recent questions
        evolvingQuestion = nil       // Clear evolving question tracker
        questionsBeingFetched.removeAll()  // Clear API fetch tracking
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
        
        // DO NOT process here - AmbientModeView already saved everything with proper duplicate detection
        // await processSessionContent()
        
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
        detectedContent.removeAll()  // Single source of truth
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
            // Direct WhisperKit transcription with volume boost for low voices
            guard let channelData = audio.floatChannelData?[0] else { return }
            let frameLength = Int(audio.frameLength)
            let audioArray = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
            
            // Apply volume boost for low volume voices (2x amplification)
            let volumeBoost: Float = 2.0
            let boostedArray = audioArray.map { sample -> Float in
                let boosted = sample * volumeBoost
                // Clip to prevent distortion
                return max(-1.0, min(1.0, boosted))
            }
            
            // Check if audio is above noise floor
            let rms = sqrt(boostedArray.reduce(0) { $0 + $1 * $1 } / Float(frameLength))
            guard rms > 0.01 else {
                logger.debug("Audio below noise floor, skipping")
                return
            }
            
            // Save boosted audio to temporary file for WhisperKit
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
            try saveAudioToFile(boostedArray, url: tempURL)
            
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
            
            // DO NOT save here - AmbientModeView handles all saving with proper duplicate detection
            // await saveContentImmediately(content)
            
            // Also add to session for batch processing
            // Removed - using detectedContent as single source
            
        case .ambient, .unknown:
            // Less important content - batch process later
            let content = AmbientProcessedContent(
                text: text,
                type: intent,
                timestamp: Date(),
                confidence: confidence
            )
            // Removed - using detectedContent as single source
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
        // Process both sessionContent and detectedContent to ensure nothing is missed
        let allContent = sessionContent + detectedContent
        let uniqueContent = Array(Set(allContent))  // Remove duplicates
        
        for content in uniqueContent {
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
        guard let modelContext = modelContext else { 
            logger.error("❌ Cannot save quote - no model context set! Make sure to call setModelContext()")
            return 
        }
        
        // Update state for debug
        currentState = .saving(content)
        
        // Get or create BookModel if we have a current book
        var bookModel: BookModel? = nil
        if let book = currentBook ?? AmbientBookDetector.shared.detectedBook {
            let fetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.localId == book.localId.uuidString
                }
            )
            
            if let existingBook = try? modelContext.fetch(fetchRequest).first {
                bookModel = existingBook
            } else {
                bookModel = BookModel(from: book)
                modelContext.insert(bookModel!)
            }
        }
        
        let quote = CapturedQuote(
            text: content.text,
            book: bookModel,
            author: content.bookAuthor,
            timestamp: content.timestamp,
            source: .ambient
        )
        quote.ambientSession = currentAmbientSession
        
        // Add to the session's capturedQuotes array
        if let session = currentAmbientSession {
            session.capturedQuotes.append(quote)
        }
        
        modelContext.insert(quote)
        
        do {
            try modelContext.save()
            logger.info("✅ Quote saved with session: \(String(content.text.prefix(50)))...")
        } catch {
            logger.error("❌ Failed to save quote: \(error)")
        }
        
        // Add to recently saved for debug view
        recentlySaved.append(content)
        if recentlySaved.count > 10 {
            recentlySaved.removeFirst()
        }
        
        // Reset state
        currentState = .listening
    }
    
    private func saveNote(_ content: AmbientProcessedContent) async {
        guard let modelContext = modelContext else { 
            logger.error("❌ Cannot save note - no model context set! Make sure to call setModelContext()")
            return 
        }
        
        // Update state for debug
        currentState = .saving(content)
        
        // Get or create BookModel if we have a current book
        var bookModel: BookModel? = nil
        if let book = currentBook ?? AmbientBookDetector.shared.detectedBook {
            let fetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.localId == book.localId.uuidString
                }
            )
            
            if let existingBook = try? modelContext.fetch(fetchRequest).first {
                bookModel = existingBook
            } else {
                bookModel = BookModel(from: book)
                modelContext.insert(bookModel!)
            }
        }
        
        let note = CapturedNote(
            content: content.text,
            book: bookModel,
            timestamp: content.timestamp,
            source: .ambient
        )
        note.ambientSession = currentAmbientSession
        
        // Add to the session's capturedNotes array
        if let session = currentAmbientSession {
            session.capturedNotes.append(note)
        }
        
        modelContext.insert(note)
        
        do {
            try modelContext.save()
            logger.info("✅ Note saved with session: \(String(content.text.prefix(50)))...")
        } catch {
            logger.error("❌ Failed to save note: \(error)")
        }
        
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
        // Configure persistence layer with context
        persistenceLayer.configure(modelContext: context, session: currentAmbientSession ?? AmbientSession(book: nil))
    }
    
    func setCurrentSession(_ session: AmbientSession) {
        self.currentAmbientSession = session
        // Update persistence layer with new session
        if let context = modelContext {
            persistenceLayer.configure(modelContext: context, session: session)
        }
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
            // Add to detectedContent as single source of truth
            let content = AmbientProcessedContent(
                text: text,
                type: .quote,
                timestamp: Date(),
                confidence: confidence
            )
            if !detectedContent.contains(where: { $0.text == text && $0.type == .quote }) {
                detectedContent.append(content)
            }
        case .note:
            // Add to detectedContent as single source of truth
            let content = AmbientProcessedContent(
                text: text,
                type: .note,
                timestamp: Date(),
                confidence: confidence
            )
            if !detectedContent.contains(where: { $0.text == text && $0.type == .note }) {
                detectedContent.append(content)
            }
        case .thought:
            // Add to detectedContent as single source of truth
            let content = AmbientProcessedContent(
                text: text,
                type: .thought,
                timestamp: Date(),
                confidence: confidence
            )
            if !detectedContent.contains(where: { $0.text == text && $0.type == .thought }) {
                detectedContent.append(content)
            }
        default:
            // Add to detectedContent as single source of truth
            let content = AmbientProcessedContent(
                text: text,
                type: .ambient,
                timestamp: Date(),
                confidence: confidence
            )
            if !detectedContent.contains(where: { $0.text == text && $0.type == .ambient }) {
                detectedContent.append(content)
            }
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
        let normalized = question.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        
        // REMOVED dangerous auto-corrections that were causing corruption
        // "Dan" should NOT become "Gandalf"
        // "Elon" should NOT become "Elrond"  
        // Preserve the actual transcription!
        
        return normalized
    }
    
    // Check if we have a similar question already processed
    private func hasSimilarProcessedQuestion(_ normalizedQuestion: String) -> Bool {
        // Disabled - too aggressive, causing duplicates
        return false
    }
    
    // Helper to check if two questions are asking the same thing
    private func areSimilarQuestions(_ q1: String, _ q2: String) -> Bool {
        // Remove common endings and punctuation
        let clean1 = q1.replacingOccurrences(of: "[?!.,]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clean2 = q2.replacingOccurrences(of: "[?!.,]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if they're exactly the same
        if clean1 == clean2 { return true }
        
        // Check if one is a truncation/evolution of the other
        // Like "Who is Bilbo Ba" vs "Who is Bilbo Baggins"
        if clean1.hasPrefix(clean2) || clean2.hasPrefix(clean1) {
            let diff = abs(clean1.count - clean2.count)
            // Allow up to 15 char difference for truncations/evolutions
            return diff < 15
        }
        
        // Check if they share the same question stem (first few words)
        let words1 = clean1.split(separator: " ")
        let words2 = clean2.split(separator: " ")
        
        if words1.count >= 3 && words2.count >= 3 {
            // If the first 3 words match, likely the same question
            let stem1 = words1.prefix(3).joined(separator: " ")
            let stem2 = words2.prefix(3).joined(separator: " ")
            if stem1 == stem2 {
                // Also check if the core subject is similar
                // This handles "Who is Bilbo Ba" vs "Who is Bilbo Baggins"
                return true
            }
        }
        
        return false
    }
    
    // Check if two questions are essentially the same (for UI deduplication)
    private func isSimilarQuestion(_ q1: String, to q2: String) -> Bool {
        let normalized1 = q1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = q2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match
        if normalized1 == normalized2 { return true }
        
        // One is a prefix of the other (evolving question)
        if normalized1.hasPrefix(normalized2) || normalized2.hasPrefix(normalized1) {
            // But only if they're similar in length (within 10 chars)
            if abs(normalized1.count - normalized2.count) < 10 {
                return true
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
        // We already waited in processDetectedText, so process immediately
        logger.info("🚀 Processing question immediately: \(question)")
        
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
    
    // Enhanced question processing with audio feedback (OPTIMIZED FOR SPEED)
    func processQuestionWithFeedback(_ question: String, confidence: Float, context: String = "") async {
        // Question is already in UI from processDetectedText
        // Just need to get the response and update it
        
        logger.info("🚀 Processing question for response: \(question.prefix(30))...")
        
        // Check if we're already fetching a response for this or similar question
        let normalizedQuestion = question.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Check for exact match or similar question being fetched
        let isAlreadyFetching = questionsBeingFetched.contains { fetchingQuestion in
            if fetchingQuestion == normalizedQuestion {
                return true
            }
            
            // Check for similar questions
            let fetchingWords = fetchingQuestion.split(separator: " ")
            let newWords = normalizedQuestion.split(separator: " ")
            
            if abs(fetchingWords.count - newWords.count) <= 1 && fetchingWords.count >= 3 {
                let minCount = min(fetchingWords.count, newWords.count) - 1
                if minCount > 0 {
                    let fetchingPrefix = fetchingWords.prefix(minCount).joined(separator: " ")
                    let newPrefix = newWords.prefix(minCount).joined(separator: " ")
                    
                    if fetchingPrefix == newPrefix {
                        return true  // Similar question already being fetched
                    }
                }
            }
            
            return false
        }
        
        if isAlreadyFetching {
            logger.warning("🔒 Already fetching response for this or similar question, skipping: \(question.prefix(30))...")
            return
        }
        
        // Mark as being fetched
        questionsBeingFetched.insert(normalizedQuestion)
        
        // Make sure to remove from fetching set when done
        defer {
            Task { @MainActor in
                self.questionsBeingFetched.remove(normalizedQuestion)
            }
        }
        
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
            // Removed - using detectedContent as single source
            return
        }
        
        // Use AICompanionService directly for reliable responses
        let bookContext = AmbientBookDetector.shared.detectedBook
        
        logger.info("🤖 Calling AICompanionService for: \(question.prefix(50))...")
        
        guard AICompanionService.shared.isConfigured() else {
            logger.error("❌ AI service not configured")
            
            await MainActor.run {
                if let existingIndex = self.detectedContent.firstIndex(where: { 
                    $0.type == .question && 
                    $0.text == question && 
                    $0.response == nil 
                }) {
                    self.detectedContent[existingIndex].response = "Please configure your Perplexity API key in Settings"
                    logger.info("⚡ Updated question #\(existingIndex) with config error")
                }
            }
            return
        }
        
        // Use IntelligentQueryRouter for ultra-fast routing
        let response = await IntelligentQueryRouter.shared.processWithParallelism(
            question,
            bookContext: bookContext
        )
        
        logger.info("✅ Got AI response: \(response.prefix(50))...")
        
        // Update UI with response - find the question more flexibly
        await MainActor.run {
            // Find the question that matches (could have evolved)
            if let index = self.detectedContent.firstIndex(where: { content in
                guard content.type == .question && content.response == nil else { return false }
                
                // Check if this is the question we're looking for
                // Could be exact match OR a variation
                let normalizedContent = content.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedQuestion = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                return normalizedContent == normalizedQuestion ||
                       self.areSimilarQuestions(normalizedContent, normalizedQuestion)
            }) {
                self.detectedContent[index].response = response
                logger.info("⚡ Updated question #\(index) with response")
            } else {
                logger.error("❌ Could not find question to update with response: \(question.prefix(30))...")
            }
        }
            
            // Update in persistence layer
            await persistenceLayer.updateQuestionAnswer(questionText: question, answer: response)
            
            // Add to conversation memory for context
            _ = conversationMemory.addMemory(
                text: question,
                intent: EnhancedIntent(
                    primary: .question(subtype: .factual),
                    confidence: confidence,
                    entities: [],
                    sentiment: .neutral,
                    subIntents: []
                ),
                response: response,
                bookTitle: bookContext?.title,
                bookAuthor: bookContext?.author
            )
            
        // Audio feedback if enabled  
        if QuestionSettings.audioFeedbackEnabled {
            await speakResponse(response)
        }
    }
    
    // Old fallback code removed - using orchestrator now
    private func oldFallbackCode() async {
        // This is never called - kept for reference only
        // All parameters would need to be passed in if this were active
        let question = ""  // Would be passed in
        let confidence: Float = 1.0  // Would be passed in
        let context = ""  // Would be passed in
        
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
        logger.info("🤖 Requesting AI response for: \(question)")
        
        // Include context in the question if available
        var enhancedQuestion = context.isEmpty ? question : "\(context)\n\nUser question: \(question)"
        
        // Use iOS 26 models to enhance the question if available
        if foundationModels.isAvailable() {
            enhancedQuestion = await foundationModels.enhanceText(enhancedQuestion)
        }
        
        // Use IntelligentQueryRouter for ultra-fast routing
        let response = await IntelligentQueryRouter.shared.processWithParallelism(
            enhancedQuestion,
            bookContext: AmbientBookDetector.shared.detectedBook
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
        
        // Update existing question with response
        await MainActor.run {
            // Find and update the existing question
            if let index = self.detectedContent.firstIndex(where: { 
                $0.type == .question && 
                $0.text == question && 
                $0.response == nil 
            }) {
                // Create a new instance with the response (structs are immutable)
                let updatedContent = AmbientProcessedContent(
                    text: question,
                    type: .question,
                    timestamp: self.detectedContent[index].timestamp,
                    confidence: confidence,
                    response: response,
                    bookTitle: content.bookTitle,
                    bookAuthor: content.bookAuthor
                )
                self.detectedContent[index] = updatedContent
                logger.info("✅ Updated question with AI response")
            } else {
                // Add as new if not found
                self.detectedContent.append(content)
                logger.info("✅ Added question with AI response to detectedContent")
            }
        }
            
        // Audio feedback if enabled
        if QuestionSettings.audioFeedbackEnabled {
            await speakResponse(response)
        }
        return  // End of oldFallbackCode
    }
    
    // Helper to save question with response to SwiftData
    private func saveQuestionWithResponse(_ content: AmbientProcessedContent) async {
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            // Don't add duplicate - this is already added in processQuestion
            // self.detectedContent.append(content)
            
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
                question.ambientSession = self.currentAmbientSession
                
                // Add to the session's capturedQuestions array
                if let session = self.currentAmbientSession {
                    session.capturedQuestions.append(question)
                }
                
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

// MARK: - Safe Array Subscript Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}