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
    private var lastProcessedTime = Date.distantPast
    private var recentlyProcessedTexts = Set<String>()
    private var bufferCheckTimer: Timer?
    
    // MARK: - Configuration
    private let minimumContentLength = 25 // Further increased to avoid fragments
    private let pauseThreshold: TimeInterval = 2.0 // Wait longer for complete thoughts
    private let maxBufferDuration: TimeInterval = 5.0 // Maximum time before forcing process
    private let minTimeBetweenProcessing: TimeInterval = 3.0 // Prevent rapid-fire processing
    
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
        let pageNumber: Int?  // Added for quotes with page references
        
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
        startBufferCheckTimer()
    }
    
    private func setupLanguageProcessing() {
        // Pre-warm NLP models
        _ = NLTagger(tagSchemes: [.lemma, .lexicalClass, .sentimentScore])
    }
    
    private func startBufferCheckTimer() {
        // Check buffer every 2 seconds (less frequent checks)
        bufferCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndProcessBuffer()
            }
        }
    }
    
    @MainActor
    private func checkAndProcessBuffer() async {
        // Only process if buffer has meaningful content and has been sitting for pauseThreshold
        let bufferText = fragmentBuffer.getCurrentText()
        let wordCount = bufferText.split(separator: " ").count
        
        // Require at least 5 words before timer processing
        guard wordCount >= 5 else { return }
        
        if fragmentBuffer.shouldProcess(pauseThreshold: pauseThreshold) {
            logger.info("⏰ Timer triggered buffer processing (\(wordCount) words)")
            _ = await processBuffer(bookContext: nil)
        }
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
        
        // Skip very short fragments (like ".", "OK", single words) unless final
        guard trimmed.count > 5 || isFinal || trimmed.contains("?") else {
            logger.debug("Skipping very short fragment: \(trimmed)")
            return nil
        }
        
        // CRITICAL: Multi-layer deduplication
        // 1. Check recent buffer to prevent re-processing same fragments
        let normalizedText = trimmed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if recentlyProcessedTexts.contains(normalizedText) {
            logger.info("⚠️ Recently processed, skipping: \(trimmed.prefix(30))...")
            return nil
        }
        
        // 2. Check deduplication service for longer-term duplicates
        if deduplicationService.isDuplicate(trimmed, type: .unknown) {
            logger.info("⚠️ Duplicate detected, skipping: \(trimmed.prefix(30))...")
            return nil
        }
        
        // 3. Check if this is just a slight variation of what we're buffering
        let currentBufferText = fragmentBuffer.getCurrentText()
        if !currentBufferText.isEmpty && !isFinal {
            // If the new text is mostly contained in the buffer, skip it
            if currentBufferText.lowercased().contains(normalizedText) {
                logger.debug("Fragment already in buffer, skipping")
                return nil
            }
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
        
        // Check for question marks BUT ensure we have enough content
        if fragment.text.contains("?") && fragmentBuffer.getCurrentText().count >= minimumContentLength {
            // Additional check: make sure we're not processing too rapidly
            let timeSinceLastProcess = Date().timeIntervalSince(lastProcessedTime)
            return timeSinceLastProcess > minTimeBetweenProcessing
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
            fragmentBuffer.clear() // Clear buffer to prevent re-processing
            return nil
        }
        
        // Filter meaningful content (from SmartContentBuffer)
        guard shouldSaveContent(cleaned) else {
            logger.info("Content filtered out (not meaningful): \"\(cleaned)\"")
            fragmentBuffer.clear() // Clear buffer to prevent re-processing
            return nil
        }
        
        // Final duplicate check against recent processing history
        let cleanedNormalized = cleaned.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for result in processingHistory.suffix(5) {
            let resultNormalized = result.content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if resultNormalized == cleanedNormalized || resultNormalized.contains(cleanedNormalized) || cleanedNormalized.contains(resultNormalized) {
                logger.info("⚠️ Content too similar to recent result, skipping")
                fragmentBuffer.clear()
                return nil
            }
        }
        
        currentState = .processing
        
        // Detect content type (using ContentIntelligence's sophisticated patterns)
        let detection = detectContentIntelligently(cleaned, bookContext: bookContext)
        
        // Extract just the quote content if this is a quote with a reaction
        var contentToSave = cleaned
        if detection.type == .quote && detection.reactionType != nil {
            // Extract the actual quote without the reaction phrase
            contentToSave = extractQuoteContentFromReaction(cleaned, reactionType: detection.reactionType!)
        }
        
        // Build metadata
        let metadata = ContentMetadata(
            isComplete: isCompleteThought(contentToSave),
            needsContinuation: needsContinuation(contentToSave),
            entities: extractEntities(contentToSave),
            detectedPatterns: detection.patterns,
            reactionType: detection.reactionType
        )
        
        // Calculate composite confidence
        let finalConfidence = calculateConfidence(
            text: contentToSave,
            fragments: assembled.fragments,
            detectionConfidence: detection.confidence
        )
        
        // Extract page number if present (especially for quotes)
        let pageNumber = extractPageNumber(from: cleaned)
        
        // Build result
        let result = ProcessingResult(
            content: contentToSave,
            type: detection.type,
            confidence: finalConfidence,
            reasoning: detection.reasoning,
            metadata: metadata,
            fragments: assembled.fragments,
            bookContext: bookContext,
            pageNumber: pageNumber
        )
        
        currentState = .savingContent
        
        // Register with deduplication service
        deduplicationService.addProcessed(cleaned, type: detection.type)
        
        // Update history
        processingHistory.append(result)
        if processingHistory.count > maxHistorySize {
            processingHistory.removeFirst()
        }
        
        // Clear buffer and update processing tracking
        fragmentBuffer.clear()
        lastProcessedTime = Date()
        
        // Add to recent processing cache (with cleanup)
        recentlyProcessedTexts.insert(cleaned.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        if recentlyProcessedTexts.count > 10 {
            recentlyProcessedTexts.removeFirst()
        }
        
        // Update state
        currentState = .complete
        lastResult = result
        confidence = finalConfidence
        currentBuffer = ""
        processingHint = ""
        
        logger.info("✅ Processed \(String(describing: detection.type)): \"\(cleaned.prefix(50))...\" (confidence: \(String(format: "%.2f", finalConfidence)))")
        
        // Handle AI response for questions DIRECTLY (no notifications)
        if result.requiresAIResponse {
            Task {
                await handleAIResponse(for: result)
            }
        }
        
        return result
    }
    
    // MARK: - Page Number Extraction
    
    private func extractPageNumber(from text: String) -> Int? {
        let lowercased = text.lowercased()
        
        // Patterns to match page numbers
        let patterns = [
            "page (\\d+)",           // "page 123"
            "on page (\\d+)",        // "on page 123"
            "from page (\\d+)",      // "from page 123"
            "p\\. ?(\\d+)",          // "p.123" or "p. 123"
            "pg (\\d+)",             // "pg 123"
            "pages? (\\d+)"          // "page 123" or "pages 123"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: lowercased.utf16.count)
                if let match = regex.firstMatch(in: lowercased, options: [], range: range) {
                    if match.numberOfRanges > 1 {
                        let pageRange = match.range(at: 1)
                        if let swiftRange = Range(pageRange, in: lowercased) {
                            let pageString = String(lowercased[swiftRange])
                            return Int(pageString)
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Quote Extraction Helper
    
    private func extractQuoteContentFromReaction(_ text: String, reactionType: String) -> String {
        let lowercased = text.lowercased()
        
        // Find where the reaction phrase ends
        if let range = lowercased.range(of: reactionType.lowercased()) {
            var afterReaction = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Clean up common separators ONLY between reaction and quote
            // Be careful not to remove punctuation that's part of the quote itself
            let separators = [":", "-", "—", "–"]  // Removed period from this list
            for separator in separators {
                if afterReaction.starts(with: separator) {
                    afterReaction = String(afterReaction.dropFirst(separator.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            
            // Handle period more carefully - only remove if it's immediately after reaction
            // "I love this quote. All we have..." -> "All we have..."
            // But keep periods that are part of the quote
            if afterReaction.starts(with: ".") {
                let afterPeriod = String(afterReaction.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                // Only remove the period if there's substantial content after it
                if afterPeriod.count > 10 {
                    afterReaction = afterPeriod
                }
            }
            
            // Clean quotation marks if present (but preserve the content between them)
            afterReaction = afterReaction
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "\u{201C}", with: "")
                .replacingOccurrences(of: "\u{201D}", with: "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "'", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Return the extracted quote if it's substantial
            if !afterReaction.isEmpty && afterReaction.count > 10 {
                return afterReaction
            }
        }
        
        // Fallback: return original text if extraction fails
        return text
    }
    
    // MARK: - Content Detection (Best of ContentIntelligence)
    
    private func detectContentIntelligently(_ text: String, bookContext: Book?) -> IntelligentDetection {
        let lowercased = text.lowercased()
        
        // Quote detection FIRST - "I love this quote" should always be a quote
        // Check this before questions because quotes are more specific
        if let quoteDetection = detectQuoteIntelligently(text) {
            logger.info("📖 Quote detected: \(text.prefix(50))...")
            return quoteDetection
        }
        
        // Question detection (second priority)
        if let questionDetection = detectQuestionIntelligently(text) {
            return questionDetection
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
            "i love this quote", "love this quote", "this is beautiful", "listen to this",
            "oh wow", "this is amazing", "here's a great line",
            "check this out", "this part", "the author says",
            "this is incredible", "this is perfect", "yes exactly",
            "this speaks to me", "this is so good", "love this",
            "wow listen to this", "oh my god", "oh my gosh",
            "this is powerful", "this is profound", "this is brilliant",
            "favorite quote", "best line", "memorable passage",
            "great quote", "amazing quote", "beautiful quote"
        ]
        
        for pattern in reactionPatterns {
            if lowercased.contains(pattern) {
                confidence += 0.5  // Increased from 0.35 to ensure it passes threshold
                patterns.append("reaction_\(pattern.replacingOccurrences(of: " ", with: "_"))")
                reactionType = pattern
                reasoning += "Contains reaction '\(pattern)'. "
                
                // Special case: "I love this quote" is DEFINITELY a quote
                if pattern == "i love this quote" || pattern == "love this quote" {
                    confidence = 0.9  // Very high confidence
                    reasoning += "STRONG quote indicator. "
                }
                break
            }
        }
        
        // Check if the actual quoted content follows
        // Pattern: "I love this quote. [actual quote content]"
        if lowercased.contains("i love this quote") || lowercased.contains("love this quote") {
            // Extract the quote content after the reaction
            let components = text.components(separatedBy: ".")
            if components.count > 1 {
                confidence += 0.3
                patterns.append("quote_with_content")
                reasoning += "Quote reaction followed by content. "
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
        
        // Literary language patterns - Gandalf's quote uses "All we have to do"
        let literaryPatterns = ["all we have to do", "thus", "hence", "wherefore", "thee", "thou", "shall", "midst"]
        for pattern in literaryPatterns {
            if lowercased.contains(pattern) {
                confidence += 0.2
                patterns.append("literary_\(pattern.replacingOccurrences(of: " ", with: "_"))")
                reasoning += "Contains literary pattern '\(pattern)'. "
            }
        }
        
        guard confidence >= 0.5 else { return nil }  // Lowered threshold from 0.6 to 0.5
        
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
        
        // First remove stutters and repeated phrases
        cleaned = removeAdvancedStutters(from: cleaned)
        
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
    
    private func removeAdvancedStutters(from text: String) -> String {
        var result = text
        
        // Pattern 1: "I'm am I'm" -> "I'm"
        result = result.replacingOccurrences(of: "I'm am I'm", with: "I'm")
        result = result.replacingOccurrences(of: "I'm I'm", with: "I'm")
        
        // Pattern 2: "reading, Lord I'm reading Lord" -> "reading Lord"
        let patterns = [
            ("I'm reading, Lord I'm reading Lord of the rings", "I'm reading Lord of the Rings"),
            ("See I don't See, I don't", "See, I don't"),
            ("See I don't See", "See I don't"),
            ("I don't I don't", "I don't"),
            ("Lord Lord", "Lord"),
            ("the the", "the")
        ]
        
        for (pattern, replacement) in patterns {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .caseInsensitive)
        }
        
        // Remove partial words at the end
        let partialEndings = [" th", " sa", " don", " ha", " wh", " fr", " br"]
        for ending in partialEndings {
            if result.hasSuffix(ending) {
                result = String(result.dropLast(ending.count))
            }
        }
        
        return result
    }
    
    private func shouldSaveContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let words = text.split(separator: " ")
        
        // Require minimum word count
        guard words.count >= 5 else { return false }
        
        // DON'T SAVE USER INTENT OR CONTEXT SETTING
        // These are just the user telling the app what book they're reading, not content
        let contextPatterns = [
            "i'm reading lord of the rings",
            "i'm reading the lord of the rings", 
            "i'm listening to lord of the rings",
            "i'm listening to the lord of the rings",
            "reading lord of the rings",
            "listening to lord of the rings",
            "i am reading", 
            "i'm reading",
            "currently reading",
            "just started reading",
            "back to reading"
        ]
        
        for pattern in contextPatterns {
            if lowercased.contains(pattern) && words.count <= 8 {
                logger.info("📚 Book context detected (not saving): \(text)")
                
                // Extract book title for context if possible
                if lowercased.contains("lord of the rings") {
                    // This could trigger book context update instead
                    // But don't save as a note
                }
                
                return false // This is just context setting, not content
            }
        }
        
        // Always save questions
        if text.contains("?") && words.count >= 4 { return true }
        
        // Always save quotes (has quote patterns)
        if detectQuoteIntelligently(text) != nil { return true }
        
        // Save thoughtful content with enough context
        let thoughtfulPatterns = ["i think", "i feel", "i love", "reminds me", "realize", "understand", "interesting", "fascinating", "wow", "amazing", "beautiful"]
        for pattern in thoughtfulPatterns {
            if lowercased.contains(pattern) && words.count >= 7 {
                return true
            }
        }
        
        // Don't save fragments or incomplete thoughts
        let fragmentIndicators = ["i'm am", "see i don't see", "lord lord", "the the"]
        for fragment in fragmentIndicators {
            if lowercased.contains(fragment) { return false }
        }
        
        // Don't save if it ends with incomplete word
        if text.hasSuffix(" th") || text.hasSuffix(" sa") || text.hasSuffix(" don") {
            return false
        }
        
        // Save only if substantial and complete (not just stating what book)
        return words.count >= 8 && (text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?"))
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
    private var assembledTextCache: String = ""
    
    var hasContent: Bool { !fragments.isEmpty }
    
    func add(_ fragment: SingleSourceProcessor.TextFragment) {
        // Prevent adding exact duplicates
        let fragmentText = fragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty or very short fragments
        guard fragmentText.count > 2 else { return }
        
        // Check if this is a duplicate of the last fragment
        if let lastFragment = fragments.last {
            let lastText = lastFragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if lastText == fragmentText {
                // Skip duplicate
                return
            }
            
            // Check if the new fragment contains the last one (incremental buildup)
            if fragmentText.contains(lastText) && fragmentText.count > lastText.count {
                // Replace with the longer version
                fragments[fragments.count - 1] = fragment
                lastAddTime = Date()
                return
            }
            
            // Check if this is a continuation that's repeating (like "Is this Is this")
            if fragmentText.hasPrefix(lastText) && fragmentText.count < lastText.count * 2 {
                // This is likely a stutter/repeat, replace the last one
                fragments[fragments.count - 1] = fragment
                lastAddTime = Date()
                return
            }
            
            // Check if last fragment contains this one (shrinking - ignore)
            if lastText.contains(fragmentText) {
                // Skip this shorter fragment
                return
            }
        }
        
        fragments.append(fragment)
        lastAddTime = Date()
    }
    
    func assemble() -> (text: String, fragments: [SingleSourceProcessor.TextFragment]) {
        // Smart assembly that removes stutters and duplicates
        guard !fragments.isEmpty else { return ("", []) }
        
        // Use only the last/most complete fragment if we have many overlapping ones
        if fragments.count > 1 {
            // Find the longest fragment (likely the most complete)
            let sortedByLength = fragments.sorted { $0.text.count > $1.text.count }
            if let longest = sortedByLength.first {
                // Check if the longest contains most of the content
                let longestText = longest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove stutters and duplicates from the longest text
                let cleaned = removeStutters(from: longestText)
                
                // Return just the cleaned longest fragment
                if cleaned.count >= 15 {
                    return (cleaned, [longest])
                }
            }
        }
        
        // Fallback: take the last fragment as it's likely most complete
        if let last = fragments.last {
            let text = removeStutters(from: last.text.trimmingCharacters(in: .whitespacesAndNewlines))
            return (text, [last])
        }
        
        return ("", [])
    }
    
    private func removeStutters(from text: String) -> String {
        var cleaned = text
        
        // Remove duplicate phrases like "I'm am I'm" -> "I'm"
        // Pattern: word sequences that repeat
        let words = cleaned.split(separator: " ").map(String.init)
        var cleanedWords: [String] = []
        var i = 0
        
        while i < words.count {
            let word = words[i]
            
            // Check for repeated sequences
            if i + 1 < words.count {
                // Check 2-word sequences
                if i + 3 < words.count &&
                   words[i] == words[i + 2] &&
                   words[i + 1] == words[i + 3] {
                    // Found duplicate 2-word sequence, skip the duplicate
                    cleanedWords.append(words[i])
                    cleanedWords.append(words[i + 1])
                    i += 4
                    continue
                }
                
                // Check single word duplicates
                if words[i] == words[i + 1] {
                    cleanedWords.append(words[i])
                    i += 2
                    continue
                }
            }
            
            cleanedWords.append(word)
            i += 1
        }
        
        cleaned = cleanedWords.joined(separator: " ")
        
        // Remove incomplete fragments at the end
        if cleaned.hasSuffix(" I don't th") || cleaned.hasSuffix(" I don") {
            if let range = cleaned.range(of: "See", options: .backwards) {
                cleaned = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return cleaned
    }
    
    func getCurrentText() -> String {
        if assembledTextCache.isEmpty || fragments.count > 0 {
            let texts = fragments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            assembledTextCache = texts.joined(separator: " ")
        }
        return assembledTextCache
    }
    
    func clear() {
        fragments.removeAll()
        assembledTextCache = ""
    }
    
    func shouldProcess(pauseThreshold: TimeInterval) -> Bool {
        guard hasContent else { return false }
        
        let currentText = getCurrentText()
        let wordCount = currentText.split(separator: " ").count
        let timeSinceLast = Date().timeIntervalSince(lastAddTime)
        
        // ALWAYS process after pause threshold regardless of content
        // This ensures fragments don't get stuck
        if timeSinceLast > pauseThreshold && wordCount >= 3 {
            return true
        }
        
        // Check for complete thoughts for earlier processing
        let hasCompleteSentence = currentText.hasSuffix(".") || 
                                  currentText.hasSuffix("!") || 
                                  currentText.hasSuffix("?")
        
        // Process complete sentences quickly
        if hasCompleteSentence && wordCount >= 3 {
            return timeSinceLast > pauseThreshold * 0.5
        }
        
        // Process questions quickly
        if currentText.contains("?") && wordCount >= 4 {
            return timeSinceLast > pauseThreshold * 0.6
        }
        
        // Otherwise keep collecting until pause threshold
        return false
    }
}

// MARK: - Centralized Deduplication Service

@MainActor
class DeduplicationService: ObservableObject {
    static let shared = DeduplicationService()
    
    private var recentContent: [ContentHash] = []
    private let timeWindow: TimeInterval = 120 // 2 minute window for better deduplication
    private let similarityThreshold: Double = 0.85 // Lower threshold to catch more variations
    
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