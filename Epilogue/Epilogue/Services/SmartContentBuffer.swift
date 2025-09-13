import Foundation
import NaturalLanguage
import Combine

// MARK: - Smart Content Buffer
/// Intelligently buffers and combines speech fragments into coherent thoughts
@MainActor
class SmartContentBuffer: ObservableObject {
    static let shared = SmartContentBuffer()
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var currentBuffer = ""
    @Published var confidence: Float = 0
    @Published var processingHint = ""
    
    // MARK: - Buffer Configuration
    private let minimumContentLength = 25 // Minimum characters for valid content (increased to prevent short fragments)
    private let pauseThreshold: TimeInterval = 1.8 // Pause to indicate thought completion (increased to wait for complete thoughts)
    private let maxBufferDuration: TimeInterval = 12.0 // Maximum time to buffer (increased for more complete thoughts)
    private let fragmentTimeout: TimeInterval = 0.5 // Time to wait for more fragments
    
    // MARK: - State Management
    private var textBuffer = ""
    private var fragmentBuffer: [Fragment] = []
    private var pauseTimer: Timer?
    private var bufferTimer: Timer?
    private var lastFragmentTime = Date()
    private var currentContext: ContentContext?
    private var recentSentences: [String] = []
    
    // MARK: - Types
    struct Fragment {
        let text: String
        let timestamp: Date
        let confidence: Float
        let isFinal: Bool
        
        var timeSincePrevious: TimeInterval? = nil
    }
    
    struct ContentContext {
        let book: Book?
        let previousContent: String?
        let contentType: ContentType
        let startTime: Date
        
        enum ContentType {
            case quote
            case reflection
            case question
            case unknown
        }
    }
    
    struct BufferedProcessedContent {
        let text: String
        let type: ContentType
        let confidence: Float
        let fragments: [Fragment]
        let processingTime: TimeInterval
        
        enum ContentType {
            case quote
            case note
            case question
            case insight
            case unknown
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupLanguageProcessing()
    }
    
    private func setupLanguageProcessing() {
        // Pre-warm NLP models
        _ = NLTagger(tagSchemes: [.lemma, .lexicalClass, .sentimentScore])
    }
    
    // MARK: - Public Interface
    
    /// Add a new speech fragment to the buffer
    func addFragment(_ text: String, confidence: Float = 0.8, isFinal: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Create fragment
        let fragment = Fragment(
            text: trimmed,
            timestamp: Date(),
            confidence: confidence,
            isFinal: isFinal
        )
        
        // Calculate time since previous fragment
        if let lastFragment = fragmentBuffer.last {
            var mutableFragment = fragment
            mutableFragment.timeSincePrevious = fragment.timestamp.timeIntervalSince(lastFragment.timestamp)
            fragmentBuffer.append(mutableFragment)
        } else {
            fragmentBuffer.append(fragment)
        }
        
        // Update buffer
        processFragment(fragment)
        
        // Update UI
        self.confidence = confidence
        updateProcessingHint()
        
        // Reset pause detection
        resetPauseTimer()
        
        // Start max duration timer if needed
        if bufferTimer == nil {
            startBufferTimer()
        }
    }
    
    /// Force process current buffer
    func forceProcess() async -> BufferedProcessedContent? {
        pauseTimer?.invalidate()
        bufferTimer?.invalidate()
        
        if !textBuffer.isEmpty {
            return await processBuffer()
        }
        return nil
    }
    
    /// Clear the buffer without processing
    func clear() {
        textBuffer = ""
        fragmentBuffer.removeAll()
        pauseTimer?.invalidate()
        bufferTimer?.invalidate()
        currentContext = nil
        processingHint = ""
        confidence = 0
    }
    
    // MARK: - Fragment Processing
    
    private func processFragment(_ fragment: Fragment) {
        // Check for sentence boundaries
        let shouldBreak = detectSentenceBoundary(fragment)
        
        if shouldBreak && !textBuffer.isEmpty {
            // Process current buffer as complete thought
            Task {
                await processBuffer()
            }
            
            // Start new buffer with current fragment
            textBuffer = fragment.text
        } else {
            // Intelligently combine fragments
            textBuffer = combineFragments(textBuffer, fragment.text)
        }
        
        lastFragmentTime = fragment.timestamp
    }
    
    private func combineFragments(_ existing: String, _ new: String) -> String {
        guard !existing.isEmpty else { return new }
        
        // Smart combination rules
        let existingTrimmed = existing.trimmingCharacters(in: .whitespaces)
        let newTrimmed = new.trimmingCharacters(in: .whitespaces)
        
        // Check if new fragment is punctuation
        if newTrimmed.count == 1 && ".,!?;:".contains(newTrimmed) {
            return existingTrimmed + newTrimmed
        }
        
        // Check if new fragment starts with lowercase (likely continuation)
        if let firstChar = newTrimmed.first, firstChar.isLowercase {
            // Check if existing ends with punctuation
            if let lastChar = existingTrimmed.last, ".,!?;:".contains(lastChar) {
                return existingTrimmed + " " + newTrimmed
            } else {
                // Direct continuation
                return existingTrimmed + " " + newTrimmed
            }
        }
        
        // Check for contractions and possessives
        if newTrimmed.hasPrefix("'") || newTrimmed.hasPrefix("'") {
            return existingTrimmed + newTrimmed
        }
        
        // Default: add with space
        return existingTrimmed + " " + newTrimmed
    }
    
    private func detectSentenceBoundary(_ fragment: Fragment) -> Bool {
        // Check for strong sentence endings
        let text = fragment.text.trimmingCharacters(in: .whitespaces)
        
        // Explicit sentence endings
        if text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?") {
            return true
        }
        
        // Check for sentence endings with quotes
        if text.hasSuffix(".\"") || text.hasSuffix("!\"") || text.hasSuffix("?\"") ||
           text.hasSuffix(".\u{201D}") || text.hasSuffix("!\u{201D}") || text.hasSuffix("?\u{201D}") {
            return true
        }
        
        // Long pause between fragments
        if let timeSince = fragment.timeSincePrevious, timeSince > pauseThreshold {
            return true
        }
        
        // Fragment marked as final AND buffer has meaningful content
        if fragment.isFinal && textBuffer.count >= minimumContentLength {
            return true
        }
        
        // Check if buffer has reached a reasonable size for a complete thought with a pause
        if textBuffer.split(separator: " ").count > 20 && fragment.timeSincePrevious ?? 0 > 1.0 {
            return true
        }
        
        return false
    }
    
    // MARK: - Buffer Processing
    
    private func processBuffer() async -> BufferedProcessedContent? {
        let bufferContent = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear state
        textBuffer = ""
        let fragments = fragmentBuffer
        fragmentBuffer.removeAll()
        
        // Clean up the content first
        let cleanedContent = cleanContent(bufferContent)
        guard !cleanedContent.isEmpty else { return nil }
        
        // Smart filtering: check if this content is worth saving
        guard shouldSaveContent(cleanedContent) else {
            return nil
        }
        
        // Final length check after cleaning
        guard cleanedContent.count >= minimumContentLength else {
            return nil
        }
        
        // Detect content type
        let contentType = await detectContentType(cleanedContent)
        
        // Calculate confidence
        let avgConfidence = fragments.isEmpty ? 0.8 : 
            fragments.map { $0.confidence }.reduce(0, +) / Float(fragments.count)
        
        // Calculate processing time
        let processingTime = fragments.isEmpty ? 0 :
            fragments.last!.timestamp.timeIntervalSince(fragments.first!.timestamp)
        
        // Add to recent sentences for context
        recentSentences.append(cleanedContent)
        if recentSentences.count > 5 {
            recentSentences.removeFirst()
        }
        
        let result = BufferedProcessedContent(
            text: cleanedContent,
            type: contentType,
            confidence: avgConfidence,
            fragments: fragments,
            processingTime: processingTime
        )
        
        
        // Send for saving
        await saveProcessedContent(result)
        
        return result
    }
    
    private func cleanContent(_ text: String) -> String {
        var cleaned = text
        
        // Fix common transcription issues
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
            // Only add period if it seems like a complete sentence
            if cleaned.split(separator: " ").count >= 3 {
                cleaned += "."
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Content Type Detection
    
    private func detectContentType(_ text: String) async -> BufferedProcessedContent.ContentType {
        let lowercased = text.lowercased()
        
        // Question detection
        if text.contains("?") || 
           lowercased.hasPrefix("what ") ||
           lowercased.hasPrefix("why ") ||
           lowercased.hasPrefix("how ") ||
           lowercased.hasPrefix("when ") ||
           lowercased.hasPrefix("where ") ||
           lowercased.hasPrefix("who ") {
            return .question
        }
        
        // Quote detection - look for quotation context
        if detectsQuoteContext(text) {
            return .quote
        }
        
        // Insight detection - deeper thoughts
        if lowercased.contains("realize") ||
           lowercased.contains("understand") ||
           lowercased.contains("means that") ||
           lowercased.contains("because") ||
           lowercased.contains("therefore") ||
           lowercased.contains("this reminds me") ||
           lowercased.contains("makes me think") {
            return .insight
        }
        
        return .note
    }
    
    // New function to determine if content is worth saving
    private func shouldSaveContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let words = text.split(separator: " ")
        
        // Always save questions
        if text.contains("?") {
            return true
        }
        
        // Always save quotes
        if detectsQuoteContext(text) {
            return true
        }
        
        // Save book switching/reading activity
        if lowercased.contains("reading") && (lowercased.contains("lord") || lowercased.contains("ring") || lowercased.contains("book")) {
            return true
        }
        
        // Save thoughtful reflections
        if lowercased.contains("i think") ||
           lowercased.contains("i feel") ||
           lowercased.contains("i love") ||
           lowercased.contains("this makes me") ||
           lowercased.contains("reminds me") {
            return true
        }
        
        // Save insights and realizations
        if lowercased.contains("realize") ||
           lowercased.contains("understand") ||
           lowercased.contains("interesting") ||
           lowercased.contains("fascinating") {
            return true
        }
        
        // Save emotional reactions
        if lowercased.contains("wow") ||
           lowercased.contains("amazing") ||
           lowercased.contains("beautiful") ||
           lowercased.contains("incredible") {
            return true
        }
        
        // Don't save if it's just stating what they're doing without context
        if lowercased == "i'm reading" || 
           lowercased.hasPrefix("i'm reading ") && words.count <= 4 {
            return false
        }
        
        // Don't save very short fragments
        if words.count < 3 {
            return false
        }
        
        // Don't save single book titles without context
        if (lowercased.contains("lord") || lowercased.contains("ring")) && words.count <= 5 && !lowercased.contains("reading") {
            return false
        }
        
        // Default: save if it has meaningful content (longer thoughts)
        return words.count >= 5
    }
    
    private func detectsQuoteContext(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Check for quote indicators
        let quoteIndicators = [
            "quote", "passage", "says", "writes", "wrote",
            "according to", "states", "mentions", "describes",
            "the author", "the book says", "i love this", 
            "this part", "this line", "favorite quote"
        ]
        
        for indicator in quoteIndicators {
            if lowercased.contains(indicator) {
                return true
            }
        }
        
        // Check for quotation marks
        if text.contains("\"") || text.contains("\u{201C}") || text.contains("\u{201D}") ||
           text.contains("\u{2018}") || text.contains("\u{2019}") {
            return true
        }
        
        // Check for reading-related reactions (often precede quotes)
        let reactionPatterns = [
            "oh wow", "amazing", "beautiful", "listen to this",
            "check this out", "this is great", "love this"
        ]
        
        for pattern in reactionPatterns {
            if lowercased.contains(pattern) {
                // Look ahead - user might be about to quote
                return true
            }
        }
        
        // Check recent context for quote setup
        for recent in recentSentences.suffix(2) {
            let recentLower = recent.lowercased()
            if recentLower.contains("quote") ||
               recentLower.contains("passage") ||
               recentLower.contains("listen to this") ||
               recentLower.contains("the book says") {
                return true
            }
        }
        
        // Check if text has book-like language (formal, literary)
        let literaryWords = ["thus", "hence", "wherefore", "thee", "thou", "shall", "midst"]
        for word in literaryWords {
            if lowercased.contains(word) {
                return true
            }
        }
        
        return false
    }
    
    private func mapToProcessedType(_ contextType: ContentContext.ContentType) -> BufferedProcessedContent.ContentType {
        switch contextType {
        case .quote: return .quote
        case .reflection: return .note
        case .question: return .question
        case .unknown: return .unknown
        }
    }
    
    // MARK: - Timer Management
    
    private func resetPauseTimer() {
        pauseTimer?.invalidate()
        
        pauseTimer = Timer.scheduledTimer(withTimeInterval: pauseThreshold, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                // Pause detected - process buffer
                if !self.textBuffer.isEmpty {
                    _ = await self.processBuffer()
                }
            }
        }
    }
    
    private func startBufferTimer() {
        bufferTimer = Timer.scheduledTimer(withTimeInterval: maxBufferDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                // Max duration reached - force process
                if !self.textBuffer.isEmpty {
                    _ = await self.processBuffer()
                }
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func updateProcessingHint() {
        let wordCount = textBuffer.split(separator: " ").count
        let lowercased = textBuffer.lowercased()
        
        // Provide context-aware hints
        if wordCount == 0 {
            processingHint = "Listening..."
        } else if detectsQuoteContext(textBuffer) {
            processingHint = "📖 Capturing quote..."
        } else if lowercased.contains("?") || lowercased.hasPrefix("what") || lowercased.hasPrefix("why") {
            processingHint = "🤔 Processing question..."
        } else if lowercased.contains("i think") || lowercased.contains("i feel") {
            processingHint = "💭 Saving your reflection..."
        } else if wordCount < 3 {
            processingHint = "Capturing..."
        } else if wordCount < 10 {
            processingHint = "Processing thought..."
        } else {
            processingHint = "Analyzing content..."
        }
        
        // Update published buffer for UI
        currentBuffer = textBuffer
    }
    
    // MARK: - Content Saving
    
    private func saveProcessedContent(_ content: BufferedProcessedContent) async {
        // Send to TrueAmbientProcessor for saving
        let processor = TrueAmbientProcessor.shared
        
        // Convert to AmbientProcessedContent and save
        let ambientContent = AmbientProcessedContent(
            text: content.text,
            type: mapToAmbientType(content.type),
            timestamp: Date(),
            confidence: content.confidence,
            response: nil,
            bookTitle: currentContext?.book?.title,
            bookAuthor: currentContext?.book?.author
        )
        
        // Add to processor's detected content
        await MainActor.run {
            processor.detectedContent.append(ambientContent)
        }
        
        // Post notification for UI update
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("SmartBufferProcessed"),
                object: content
            )
        }
    }
    
    private func mapToAmbientType(_ type: BufferedProcessedContent.ContentType) -> AmbientProcessedContent.ContentType {
        switch type {
        case .quote: return .quote
        case .note: return .note
        case .question: return .question
        case .insight: return .thought
        case .unknown: return .unknown
        }
    }
    
    // MARK: - Context Management
    
    func updateContext(book: Book?, contentType: ContentContext.ContentType? = nil) {
        let previousBook = currentContext?.book
        
        // If book changed, create a note about the switch
        if let newBook = book, let oldBook = previousBook, newBook.id != oldBook.id {
            // Create contextual book switching note
            let switchNote = BufferedProcessedContent(
                text: "Now reading \(newBook.title)", // More natural than "Started reading"
                type: .note,
                confidence: 0.9,
                fragments: [],
                processingTime: 0
            )
            
            // Save the book switch note immediately
            Task {
                await saveProcessedContent(switchNote)
            }
            
        } else if let newBook = book, previousBook == nil {
            // First book detection - only if we have meaningful context
            if !textBuffer.isEmpty && textBuffer.lowercased().contains("reading") {
                let switchNote = BufferedProcessedContent(
                    text: "Now reading \(newBook.title)",
                    type: .note,
                    confidence: 0.9,
                    fragments: [],
                    processingTime: 0
                )
                
                Task {
                    await saveProcessedContent(switchNote)
                }
                
            }
        }
        
        currentContext = ContentContext(
            book: book,
            previousContent: textBuffer,
            contentType: contentType ?? .unknown,
            startTime: Date()
        )
    }
}