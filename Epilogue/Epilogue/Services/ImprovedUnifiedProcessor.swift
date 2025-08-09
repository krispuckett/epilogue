import Foundation
import NaturalLanguage
import OSLog
import Combine
import SwiftUI

// MARK: - Improved Unified Content Processor
/// A consolidated, intelligent content processor that replaces the three existing systems
@MainActor
final class ImprovedUnifiedProcessor: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ImprovedUnifiedProcessor()
    
    // MARK: - Published Properties
    @Published private(set) var isProcessing = false
    @Published private(set) var currentState: ProcessingState = .idle
    @Published private(set) var lastResult: ProcessingResult?
    @Published private(set) var confidence: Double = 0
    @Published private(set) var processingQueue: [ProcessingResult] = []
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.epilogue", category: "ImprovedProcessor")
    private var processingHistory: [ProcessingResult] = []
    private let maxHistorySize = 50
    private var fragmentBuffer = FragmentBuffer()
    
    // Track recently processed to prevent duplicates
    private var recentHashes = Set<Int>()
    private var lastProcessTime = Date()
    private let deduplicationWindow: TimeInterval = 10.0
    
    // MARK: - Types
    
    enum ProcessingState: String {
        case idle = "Idle"
        case analyzing = "Analyzing"
        case assemblingQuote = "Assembling Quote"
        case processingQuestion = "Processing Question"
        case savingContent = "Saving"
        case complete = "Complete"
    }
    
    struct ProcessingResult: Identifiable {
        let id = UUID()
        let content: String
        let type: UnifiedContentType
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
    }
    
    struct TextFragment {
        let text: String
        let timestamp: Date
        let confidence: Double
        let isFinal: Bool
    }
    
    // MARK: - Main Processing Method
    
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
        
        // Deduplication check
        let textHash = trimmed.hashValue
        let timeSinceLastProcess = Date().timeIntervalSince(lastProcessTime)
        
        if recentHashes.contains(textHash) && timeSinceLastProcess < deduplicationWindow {
            logger.info("⚠️ Skipping duplicate: \(trimmed.prefix(50))...")
            return nil
        }
        
        // Update state
        currentState = .analyzing
        isProcessing = true
        
        // Create fragment
        let fragment = TextFragment(
            text: trimmed,
            timestamp: Date(),
            confidence: confidence,
            isFinal: isFinal
        )
        
        // Add to buffer
        fragmentBuffer.add(fragment)
        
        // Check if we should process
        if shouldProcessBuffer(fragment: fragment) {
            let result = await processBuffer(bookContext: bookContext)
            
            if let result = result {
                // Update deduplication tracking
                recentHashes.insert(textHash)
                lastProcessTime = Date()
                
                // Clean old hashes periodically
                if recentHashes.count > 100 {
                    recentHashes.removeAll()
                }
            }
            
            return result
        }
        
        return nil
    }
    
    // MARK: - Buffer Processing
    
    private func shouldProcessBuffer(fragment: TextFragment) -> Bool {
        // Process if fragment is final or we detect completion
        if fragment.isFinal && fragmentBuffer.hasContent {
            return true
        }
        
        // Check for sentence boundaries
        if fragment.text.contains(where: { ".!?".contains($0) }) {
            return true
        }
        
        // Check for pause/timeout
        return fragmentBuffer.shouldProcess()
    }
    
    private func processBuffer(bookContext: Book?) async -> ProcessingResult? {
        defer {
            currentState = .idle
            isProcessing = false
        }
        
        // Get assembled content
        let assembled = fragmentBuffer.assemble()
        guard !assembled.text.isEmpty else { return nil }
        
        // Clean and normalize
        let cleaned = cleanContent(assembled.text)
        
        // Detect content type
        let type = detectUnifiedContentType(cleaned)
        
        // Update state based on type
        currentState = stateForType(type)
        
        // Build metadata
        let metadata = ContentMetadata(
            isComplete: isCompleteThought(cleaned),
            needsContinuation: needsContinuation(cleaned),
            entities: extractEntities(cleaned)
        )
        
        // Calculate confidence
        let confidence = calculateConfidence(
            text: cleaned,
            fragments: assembled.fragments,
            type: type
        )
        
        // Build result
        let result = ProcessingResult(
            content: cleaned,
            type: type,
            confidence: confidence,
            reasoning: "Processed as \(type)",
            metadata: metadata,
            fragments: assembled.fragments,
            bookContext: bookContext
        )
        
        // Update history
        processingHistory.append(result)
        if processingHistory.count > maxHistorySize {
            processingHistory.removeFirst()
        }
        
        // Update queue
        processingQueue.append(result)
        
        // Clear buffer
        fragmentBuffer.clear()
        
        // Update state
        currentState = .complete
        lastResult = result
        
        return result
    }
    
    // MARK: - Content Type Detection
    
    private func detectUnifiedContentType(_ text: String) -> UnifiedContentType {
        let lowercased = text.lowercased()
        
        // Question detection (highest priority)
        if text.contains("?") || isQuestion(lowercased) {
            return .question
        }
        
        // Quote detection
        if text.contains("\"") || lowercased.contains("the author") || lowercased.contains("says") {
            return .quote
        }
        
        // Insight detection
        if lowercased.contains("i realize") || lowercased.contains("i understand") {
            return .insight
        }
        
        // Reflection detection
        if lowercased.contains("i think") || lowercased.contains("i feel") {
            return .reflection
        }
        
        // Default to note
        return .note
    }
    
    private func isQuestion(_ text: String) -> Bool {
        let questionWords = ["what", "why", "how", "when", "where", "who", "which", "could", "would", "should"]
        return questionWords.contains { text.starts(with: $0) }
    }
    
    // MARK: - Helper Methods
    
    private func cleanContent(_ text: String) -> String {
        // Remove extra whitespace and normalize
        let cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix common transcription errors
        return cleaned
            .replacingOccurrences(of: "gonna", with: "going to")
            .replacingOccurrences(of: "wanna", with: "want to")
    }
    
    private func isCompleteThought(_ text: String) -> Bool {
        // Check for sentence ending punctuation
        return text.last.map { ".!?".contains($0) } ?? false
    }
    
    private func needsContinuation(_ text: String) -> Bool {
        // Check for incomplete patterns
        let incompletePatterns = ["and", "but", "or", "because", "so", "then"]
        let words = text.split(separator: " ")
        guard let lastWord = words.last?.lowercased() else { return false }
        return incompletePatterns.contains(lastWord)
    }
    
    private func extractEntities(_ text: String) -> [String] {
        // Simple entity extraction (can be enhanced with NLP)
        var entities: [String] = []
        
        // Extract capitalized words (likely proper nouns)
        let words = text.split(separator: " ")
        for word in words {
            let cleaned = String(word).trimmingCharacters(in: .punctuationCharacters)
            if !cleaned.isEmpty && cleaned.first?.isUppercase == true {
                entities.append(cleaned)
            }
        }
        
        return entities
    }
    
    private func calculateConfidence(
        text: String,
        fragments: [TextFragment],
        type: UnifiedContentType
    ) -> Double {
        // Average fragment confidence
        let avgConfidence = fragments.reduce(0.0) { $0 + $1.confidence } / Double(max(fragments.count, 1))
        
        // Boost confidence for complete thoughts
        var confidence = avgConfidence
        if isCompleteThought(text) {
            confidence = min(confidence + 0.1, 1.0)
        }
        
        // Adjust based on content type
        switch type {
        case .question:
            confidence = min(confidence + 0.05, 1.0) // Questions are usually clear
        case .quote:
            confidence = min(confidence + 0.05, 1.0) // Quotes have clear markers
        default:
            break
        }
        
        return confidence
    }
    
    private func stateForType(_ type: UnifiedContentType) -> ProcessingState {
        switch type {
        case .question:
            return .processingQuestion
        case .quote:
            return .assemblingQuote
        default:
            return .savingContent
        }
    }
}

// MARK: - Fragment Buffer

private class FragmentBuffer {
    private var fragments: [ImprovedUnifiedProcessor.TextFragment] = []
    private var lastAddTime = Date()
    private let timeout: TimeInterval = 2.0
    
    var hasContent: Bool { !fragments.isEmpty }
    
    func add(_ fragment: ImprovedUnifiedProcessor.TextFragment) {
        fragments.append(fragment)
        lastAddTime = Date()
    }
    
    func shouldProcess() -> Bool {
        guard hasContent else { return false }
        return Date().timeIntervalSince(lastAddTime) > timeout
    }
    
    func assemble() -> (text: String, fragments: [ImprovedUnifiedProcessor.TextFragment]) {
        let text = fragments.map { $0.text }.joined(separator: " ")
        return (text, fragments)
    }
    
    func clear() {
        fragments.removeAll()
    }
}

// MARK: - Content Type (renamed to avoid conflicts)
enum UnifiedContentType: Int, Comparable {
    case question = 0
    case quote = 1
    case insight = 2
    case reflection = 3
    case note = 4
    case unknown = 5
    
    static func < (lhs: UnifiedContentType, rhs: UnifiedContentType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var requiresAIResponse: Bool {
        self == .question
    }
    
    var icon: String {
        switch self {
        case .question: return "questionmark.circle.fill"
        case .quote: return "quote.bubble.fill"
        case .insight: return "lightbulb.fill"
        case .reflection: return "brain.head.profile"
        case .note: return "note.text"
        case .unknown: return "questionmark"
        }
    }
    
    var color: Color {
        switch self {
        case .question: return .blue
        case .quote: return .green
        case .insight: return .orange
        case .reflection: return .purple
        case .note: return .gray
        case .unknown: return .gray
        }
    }
}