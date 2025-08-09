import Foundation
import NaturalLanguage
import OSLog
import Combine
import SwiftUI
import SwiftData

// MARK: - Single Source Content Processor
/// The ONLY processor for transcription content - replaces all competing systems
/// Consolidates the best logic from SmartContentBuffer, ContentIntelligence, and UnifiedTranscriptionProcessor
@MainActor
final class SingleSourceProcessor: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SingleSourceProcessor()
    
    // MARK: - Published Properties
    @Published private(set) var isProcessing = false
    @Published private(set) var currentState: ProcessingState = .idle
    @Published private(set) var lastResult: ProcessingResult?
    @Published private(set) var confidence: Double = 0
    @Published private(set) var currentBuffer = ""
    @Published private(set) var processingHint = ""
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.epilogue", category: "SingleSourceProcessor")
    private var processingHistory: [ProcessingResult] = []
    private let maxHistorySize = 50
    private var fragmentBuffer = FragmentBuffer()
    private let deduplicationService = DeduplicationService.shared
    
    // MARK: - Configuration
    private let minimumContentLength = 20
    private let pauseThreshold: TimeInterval = 0.8 // Reduced from SmartContentBuffer's 1.8s
    private let maxBufferDuration: TimeInterval = 8.0 // Reduced from 12s for quicker processing
    
    // MARK: - Types
    
    enum ProcessingState: String {
        case idle = "Idle"
        case buffering = "Buffering"
        case detecting = "Detecting"
        case processing = "Processing"
        case savingContent = "Saving"
        case complete = "Complete"
    }
    
    struct ProcessingResult: Identifiable {
        let id = UUID()
        let content: String
        let type: ContentType
        let confidence: Double
        let reasoning: String
        let metadata: ContentMetadata
        let timestamp = Date()
        let fragments: [TextFragment]
        let bookContext: Book?
        
        var requiresAIResponse: Bool {
            type == .question
        }
    }
    
    struct ContentMetadata {
        var isComplete: Bool
        var needsContinuation: Bool
        var entities: [String] = []
        var detectedPatterns: [String] = []
        var reactionType: String?
    }
    
    struct TextFragment {
        let text: String
        let timestamp: Date
        let confidence: Double
        let isFinal: Bool
    }
    
    // MARK: - Initialization
    
    private init() {
        logger.info("🚀 SingleSourceProcessor initialized - THE unified processing pipeline")
        setupLanguageProcessing()
    }
    
    private func setupLanguageProcessing() {
        // Pre-warm NLP models
        _ = NLTagger(tagSchemes: [.lemma, .lexicalClass, .sentimentScore])
    }
    
    // MARK: - Main Processing Method - THE SINGLE ENTRY POINT
    
    /// The ONLY method that processes transcription - all other processors are now disabled
    func process(
        _ text: String,
        confidence: Double = 0.8,
        isFinal: Bool = false,
        bookContext: Book? = nil
    ) async -> ProcessingResult? {
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.debug("Skipping empty text")
            return nil
        }
        
        // CRITICAL: Centralized deduplication check FIRST
        if deduplicationService.isDuplicate(trimmed, type: .unknown) {
            logger.info("⚠️ Duplicate detected, skipping: \(trimmed.prefix(30))...")
            return nil
        }
        
        // Update state
        currentState = .buffering
        isProcessing = true
        
        // Create fragment
        let fragment = TextFragment(
            text: trimmed,
            timestamp: Date(),
            confidence: confidence,
            isFinal: isFinal
        )
        
        // Add to buffer (using SmartContentBuffer's excellent fragment logic)
        fragmentBuffer.add(fragment)
        
        // Update UI buffer
        currentBuffer = fragmentBuffer.getCurrentText()
        updateProcessingHint(currentBuffer)
        
        // Check if we should process (using optimized timing)
        if shouldProcessBuffer(fragment: fragment) {
            return await processBuffer(bookContext: bookContext)
        }
        
        return nil
    }
    
    /// Process immediately for final results - used when stopping sessions
    func processImmediate(_ text: String, bookContext: Book? = nil) async -> ProcessingResult? {
        return await process(text, confidence: 0.9, isFinal: true, bookContext: bookContext)
    }
    
    // MARK: - Buffer Processing (Consolidated from SmartContentBuffer)
    
    private func shouldProcessBuffer(fragment: TextFragment) -> Bool {
        // Process if fragment is final
        if fragment.isFinal && fragmentBuffer.hasContent {
            return true
        }
        
        // Check for sentence boundaries (from SmartContentBuffer)
        if detectsSentenceBoundary(fragment) {
            return true
        }
        
        // Check for question marks (immediate processing)
        if fragment.text.contains("?") {
            return true
        }
        
        // Check for buffer timeout (optimized timing)
        return fragmentBuffer.shouldProcess(pauseThreshold: pauseThreshold)
    }
    
    private func processBuffer(bookContext: Book?) async -> ProcessingResult? {
        defer {
            currentState = .idle
            isProcessing = false
        }
        
        currentState = .detecting
        
        // Get assembled content (using SmartContentBuffer's assembly logic)
        let assembled = fragmentBuffer.assemble()
        guard !assembled.text.isEmpty else { return nil }
        
        // Clean content (using SmartContentBuffer's cleaning)
        let cleaned = cleanContent(assembled.text)
        guard cleaned.count >= minimumContentLength else {
            logger.debug("Content too short after cleaning: \(cleaned.count) chars")
            return nil
        }
        
        // Filter meaningful content (from SmartContentBuffer)
        guard shouldSaveContent(cleaned) else {
            logger.info("Content filtered out (not meaningful): \"\(cleaned)\"")
            return nil
        }
        
        currentState = .processing
        
        // Detect content type (using ContentIntelligence's sophisticated patterns)
        let detection = detectContentIntelligently(cleaned, bookContext: bookContext)
        
        // Build metadata
        let metadata = ContentMetadata(
            isComplete: isCompleteThought(cleaned),
            needsContinuation: needsContinuation(cleaned),
            entities: extractEntities(cleaned),
            detectedPatterns: detection.patterns,
            reactionType: detection.reactionType
        )
        
        // Calculate composite confidence
        let finalConfidence = calculateConfidence(
            text: cleaned,
            fragments: assembled.fragments,
            detectionConfidence: detection.confidence
        )
        
        // Build result
        let result = ProcessingResult(
            content: cleaned,
            type: detection.type,
            confidence: finalConfidence,
            reasoning: detection.reasoning,
            metadata: metadata,
            fragments: assembled.fragments,
            bookContext: bookContext
        )
        
        currentState = .savingContent
        
        // Register with deduplication service
        deduplicationService.addProcessed(cleaned, type: detection.type)
        
        // Update history
        processingHistory.append(result)
        if processingHistory.count > maxHistorySize {
            processingHistory.removeFirst()
        }
        
        // Clear buffer
        fragmentBuffer.clear()
        
        // Update state
        currentState = .complete
        lastResult = result
        confidence = finalConfidence
        currentBuffer = ""
        processingHint = ""
        
        logger.info("✅ Processed \(detection.type): \"\(cleaned.prefix(50))...\" (confidence: \(String(format: "%.2f", finalConfidence)))")
        
        // Handle AI response for questions DIRECTLY (no notifications)
        if result.requiresAIResponse {
            Task {
                await handleAIResponse(for: result)
            }
        }
        
        return result
    }
    
    // MARK: - Content Detection (Best of ContentIntelligence)
    
    private func detectContentIntelligently(_ text: String, bookContext: Book?) -> IntelligentDetection {
        let lowercased = text.lowercased()
        
        // Question detection (highest priority - from ContentIntelligence)
        if let questionDetection = detectQuestionIntelligently(text) {
            return questionDetection
        }
        
        // Quote detection (from ContentIntelligence's sophisticated patterns)
        if let quoteDetection = detectQuoteIntelligently(text) {
            return quoteDetection
        }
        
        // Insight detection
        if let insightDetection = detectInsightIntelligently(text) {
            return insightDetection
        }
        
        // Reflection detection
        if let reflectionDetection = detectReflectionIntelligently(text) {
            return reflectionDetection
        }
        
        // Default to note
        return IntelligentDetection(
            type: .note,
            confidence: 0.6,
            reasoning: "Default classification - general note",
            patterns: [],
            reactionType: nil
        )
    }
    
    private func detectQuestionIntelligently(_ text: String) -> IntelligentDetection? {
        let lowercased = text.lowercased()
        var confidence = 0.0
        var patterns: [String] = []
        var reasoning = "Question detection: "
        
        // Direct question mark
        if text.contains("?") {
            confidence += 0.4
            patterns.append("question_mark")
            reasoning += "Contains '?'. "
        }
        
        // Question starters (from ContentIntelligence)
        let questionStarters = [
            "what", "why", "how", "when", "where", "who", "which",
            "can", "could", "would", "should", "will", "shall",
            "is", "are", "was", "were", "do", "does", "did"
        ]
        
        for starter in questionStarters {
            if lowercased.hasPrefix("\(starter) ") {
                confidence += 0.3
                patterns.append("question_starter_\(starter)")
                reasoning += "Starts with '\(starter)'. "
                break
            }
        }
        
        // Rhetorical vs direct question detection
        let rhetoricalPatterns = ["i wonder", "what if", "isn't it"]
        for pattern in rhetoricalPatterns {
            if lowercased.contains(pattern) {
                confidence -= 0.1 // Lower confidence for rhetorical questions
                patterns.append("rhetorical_\(pattern.replacingOccurrences(of: " ", with: "_"))")
                reasoning += "Contains rhetorical pattern '\(pattern)'. "
            }
        }
        
        guard confidence >= 0.6 else { return nil }
        
        return IntelligentDetection(
            type: .question,
            confidence: min(confidence, 1.0),
            reasoning: reasoning,
            patterns: patterns,
            reactionType: nil
        )
    }
    
    private func detectQuoteIntelligently(_ text: String) -> IntelligentDetection? {
        let lowercased = text.lowercased()
        var confidence = 0.0
        var patterns: [String] = []
        var reasoning = "Quote detection: "
        var reactionType: String? = nil
        
        // Reaction patterns (from ContentIntelligence's excellent list)
        let reactionPatterns = [
            "i love this quote", "this is beautiful", "listen to this",
            "oh wow", "this is amazing", "here's a great line",
            "check this out", "this part", "the author says",
            "this is incredible", "this is perfect", "yes exactly",
            "this speaks to me", "this is so good", "love this",
            "wow listen to this", "oh my god", "oh my gosh",
            "this is powerful", "this is profound", "this is brilliant",
            "favorite quote", "best line", "memorable passage"
        ]
        
        for pattern in reactionPatterns {
            if lowercased.contains(pattern) {
                confidence += 0.35
                patterns.append("reaction_\(pattern.replacingOccurrences(of: " ", with: "_"))")
                reactionType = pattern
                reasoning += "Contains reaction '\(pattern)'. "
                break
            }
        }
        
        // Quotation marks
        if text.contains("\"") || text.contains("\u{201C}") || text.contains("\u{201D}") {
            confidence += 0.25
            patterns.append("quotation_marks")
            reasoning += "Contains quotation marks. "
        }
        
        // Attribution patterns
        let attributionPatterns = ["according to", "states", "mentions", "writes", "wrote", "says"]
        for pattern in attributionPatterns {
            if lowercased.contains(pattern) {
                confidence += 0.2
                patterns.append("attribution_\(pattern.replacingOccurrences(of: " ", with: "_"))")
                reasoning += "Contains attribution '\(pattern)'. "
            }
        }
        
        // Literary language patterns
        let literaryWords = ["thus", "hence", "wherefore", "thee", "thou", "shall", "midst"]
        for word in literaryWords {
            if lowercased.contains(word) {
                confidence += 0.15
                patterns.append("literary_\(word)")
                reasoning += "Contains literary word '\(word)'. "
            }
        }
        
        guard confidence >= 0.6 else { return nil }
        
        return IntelligentDetection(
            type: .quote,
            confidence: min(confidence, 1.0),
            reasoning: reasoning,
            patterns: patterns,
            reactionType: reactionType
        )
    }
    
    private func detectInsightIntelligently(_ text: String) -> IntelligentDetection? {
        let lowercased = text.lowercased()
        var confidence = 0.0
        var patterns: [String] = []
        var reasoning = "Insight detection: "
        
        let insightPatterns = [
            "realize", "understand", "means that", "because", "therefore",
            "this shows", "connects to", "similar to", "reminds me",
            "makes me think", "i see", "now i get it", "aha", "oh i see"
        ]
        
        for pattern in insightPatterns {
            if lowercased.contains(pattern) {
                confidence += 0.3
                patterns.append("insight_\(pattern.replacingOccurrences(of: " ", with: "_"))")
                reasoning += "Contains insight pattern '\(pattern)'. "
            }
        }
        
        // Boost confidence for longer, thoughtful content
        if text.count > 50 {
            confidence += 0.1
            patterns.append("thoughtful_length")
            reasoning += "Substantial length suggests insight. "
        }
        
        guard confidence >= 0.6 else { return nil }
        
        return IntelligentDetection(
            type: .insight,
            confidence: min(confidence, 1.0),
            reasoning: reasoning,
            patterns: patterns,
            reactionType: nil
        )
    }
    
    private func detectReflectionIntelligently(_ text: String) -> IntelligentDetection? {
        let lowercased = text.lowercased()
        var confidence = 0.0
        var patterns: [String] = []
        var reasoning = "Reflection detection: "
        
        let reflectionPatterns = [
            "i think", "i feel", "i believe", "in my opinion", "to me",
            "personally", "i wonder", "maybe", "perhaps", "it seems"
        ]
        
        for pattern in reflectionPatterns {
            if lowercased.contains(pattern) {
                confidence += 0.25
                patterns.append("reflection_\(pattern.replacingOccurrences(of: " ", with: "_"))")
                reasoning += "Contains reflection pattern '\(pattern)'. "
            }
        }
        
        // Require meaningful length for reflections
        guard text.count > 30 else { return nil }
        
        guard confidence >= 0.6 else { return nil }
        
        return IntelligentDetection(
            type: .reflection,
            confidence: min(confidence, 1.0),
            reasoning: reasoning,
            patterns: patterns,
            reactionType: nil
        )
    }
    
    // MARK: - Content Cleaning & Validation (From SmartContentBuffer)
    
    private func cleanContent(_ text: String) -> String {
        var cleaned = text
        
        // Fix punctuation spacing
        cleaned = cleaned.replacingOccurrences(of: " .", with: ".")
        cleaned = cleaned.replacingOccurrences(of: " ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: " ?", with: "?")
        cleaned = cleaned.replacingOccurrences(of: " !", with: "!")
        cleaned = cleaned.replacingOccurrences(of: " '", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "' ", with: "'")
        
        // Remove duplicate spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Capitalize first letter if needed
        if let firstChar = cleaned.first, firstChar.isLowercase {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }
        
        // Ensure ends with punctuation for complete thoughts
        let lastChar = cleaned.last
        if lastChar != "." && lastChar != "!" && lastChar != "?" {
            if cleaned.split(separator: " ").count >= 3 {
                cleaned += "."
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func shouldSaveContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let words = text.split(separator: " ")
        
        // Always save questions
        if text.contains("?") { return true }
        
        // Always save quotes (has quote patterns)
        if detectQuoteIntelligently(text) != nil { return true }
        
        // Save book activity
        if lowercased.contains("reading") && words.count >= 3 { return true }
        
        // Save thoughtful content
        let thoughtfulPatterns = ["i think", "i feel", "i love", "reminds me", "realize", "understand", "interesting", "fascinating", "wow", "amazing", "beautiful"]
        for pattern in thoughtfulPatterns {
            if lowercased.contains(pattern) { return true }
        }
        
        // Don't save very short or generic fragments
        if words.count < 3 { return false }
        if lowercased == "i'm reading" { return false }
        
        // Save if meaningful length
        return words.count >= 5
    }
    
    // MARK: - Helper Methods
    
    private func detectsSentenceBoundary(_ fragment: TextFragment) -> Bool {
        let text = fragment.text.trimmingCharacters(in: .whitespaces)
        
        // Explicit sentence endings
        if text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?") {
            return true
        }
        
        // Final fragment with meaningful content
        if fragment.isFinal && currentBuffer.count >= minimumContentLength {
            return true
        }
        
        return false
    }
    
    private func isCompleteThought(_ text: String) -> Bool {
        text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?")
    }
    
    private func needsContinuation(_ text: String) -> Bool {
        let words = text.lowercased().split(separator: " ")
        guard let lastWord = words.last else { return false }
        
        let continuationWords = ["and", "but", "or", "because", "so", "then", "when", "if"]
        return continuationWords.contains(String(lastWord))
    }
    
    private func extractEntities(_ text: String) -> [String] {
        let words = text.split(separator: " ")
        var entities: [String] = []
        
        for word in words {
            let cleaned = String(word).trimmingCharacters(in: .punctuationCharacters)
            if !cleaned.isEmpty && cleaned.first?.isUppercase == true {
                entities.append(cleaned)
            }
        }
        
        return entities
    }
    
    private func calculateConfidence(text: String, fragments: [TextFragment], detectionConfidence: Double) -> Double {
        let avgFragmentConfidence = fragments.isEmpty ? 0.8 : 
            fragments.map { $0.confidence }.reduce(0, +) / Double(fragments.count)
        
        var confidence = (detectionConfidence + avgFragmentConfidence) / 2
        
        if isCompleteThought(text) {
            confidence = min(confidence + 0.1, 1.0)
        }
        
        return confidence
    }
    
    private func updateProcessingHint(_ buffer: String) {
        let wordCount = buffer.split(separator: " ").count
        let lowercased = buffer.lowercased()
        
        if wordCount == 0 {
            processingHint = "Listening..."
        } else if lowercased.contains("?") {
            processingHint = "🤔 Processing question..."
        } else if detectQuoteIntelligently(buffer) != nil {
            processingHint = "📖 Capturing quote..."
        } else if lowercased.contains("i think") || lowercased.contains("i feel") {
            processingHint = "💭 Saving reflection..."
        } else if wordCount < 5 {
            processingHint = "Capturing..."
        } else {
            processingHint = "Processing..."
        }
    }
    
    // MARK: - AI Response Handling (DIRECT - No Notifications)
    
    private func handleAIResponse(for result: ProcessingResult) async {
        logger.info("🤖 Getting AI response for question: \(result.content)")
        
        // Use OptimizedAIResponseService directly - FIXED to get response back
        if let aiResponse = await OptimizedAIResponseService.shared.processImmediateQuestion(
            result.content,
            bookContext: result.bookContext
        ) {
            logger.info("✅ AI response received: \(aiResponse.answer.prefix(50))...")
            
            // TODO: Update UI with response directly instead of relying on notifications
            await showAIResponseInUI(aiResponse)
        } else {
            logger.warning("⚠️ No AI response received for: \(result.content)")
        }
    }
    
    // Direct UI update for AI responses - no notifications needed
    private func showAIResponseInUI(_ response: AIResponse) async {
        // Post notification for UnifiedChatView to show response immediately
        // This is temporary until we have direct binding
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("AIResponseReady"),
                object: response
            )
        }
        logger.info("📱 AI response posted for immediate display: \(response.question)")
    }
}

// MARK: - Supporting Types

private struct IntelligentDetection {
    let type: ContentType
    let confidence: Double
    let reasoning: String
    let patterns: [String]
    let reactionType: String?
}

// MARK: - Fragment Buffer (Optimized from SmartContentBuffer)

private class FragmentBuffer {
    private var fragments: [SingleSourceProcessor.TextFragment] = []
    private var lastAddTime = Date()
    
    var hasContent: Bool { !fragments.isEmpty }
    
    func add(_ fragment: SingleSourceProcessor.TextFragment) {
        fragments.append(fragment)
        lastAddTime = Date()
    }
    
    func assemble() -> (text: String, fragments: [SingleSourceProcessor.TextFragment]) {
        let text = fragments.map { $0.text }.joined(separator: " ")
        return (text, fragments)
    }
    
    func getCurrentText() -> String {
        fragments.map { $0.text }.joined(separator: " ")
    }
    
    func clear() {
        fragments.removeAll()
    }
    
    func shouldProcess(pauseThreshold: TimeInterval) -> Bool {
        guard hasContent else { return false }
        return Date().timeIntervalSince(lastAddTime) > pauseThreshold
    }
}

// MARK: - Centralized Deduplication Service

@MainActor
class DeduplicationService: ObservableObject {
    static let shared = DeduplicationService()
    
    private var recentContent: [ContentHash] = []
    private let timeWindow: TimeInterval = 60 // 1 minute window
    private let similarityThreshold: Double = 0.95 // Increased from 85% to 95%
    
    private struct ContentHash {
        let hash: Int
        let text: String
        let timestamp: Date
        let type: ContentType
    }
    
    private init() {}
    
    func isDuplicate(_ text: String, type: ContentType) -> Bool {
        cleanOldEntries()
        
        let normalized = normalizeText(text)
        let hash = normalized.hashValue
        
        // Exact hash match
        if recentContent.contains(where: { $0.hash == hash }) {
            return true
        }
        
        // High similarity check (95% threshold)
        for recent in recentContent {
            if similarity(recent.text, normalized) > similarityThreshold {
                return true
            }
        }
        
        return false
    }
    
    func addProcessed(_ text: String, type: ContentType) {
        let normalized = normalizeText(text)
        let contentHash = ContentHash(
            hash: normalized.hashValue,
            text: normalized,
            timestamp: Date(),
            type: type
        )
        recentContent.append(contentHash)
    }
    
    private func normalizeText(_ text: String) -> String {
        return text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private func similarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        
        // Enhanced Jaccard similarity
        let s1Words = Set(s1.split(separator: " ").map(String.init))
        let s2Words = Set(s2.split(separator: " ").map(String.init))
        
        let intersection = s1Words.intersection(s2Words).count
        let union = s1Words.union(s2Words).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
    
    private func cleanOldEntries() {
        let cutoff = Date().addingTimeInterval(-timeWindow)
        recentContent.removeAll { $0.timestamp < cutoff }
    }
}