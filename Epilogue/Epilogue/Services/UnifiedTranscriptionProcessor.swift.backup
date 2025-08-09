import Foundation
import SwiftUI
import Combine
import SwiftData

// MARK: - Processing State Machine
enum ProcessingState {
    case listening
    case detecting(content: String)
    case processing(type: ContentType, content: String)
    case saving(item: UnifiedProcessedContent)
    
    var description: String {
        switch self {
        case .listening: return "Listening"
        case .detecting: return "Detecting"
        case .processing(let type, _): return "Processing \(type)"
        case .saving: return "Saving"
        }
    }
}

// MARK: - Content Types with Priority
enum ContentType: Int, Comparable {
    case question = 0      // Highest priority - immediate AI response
    case quote = 1         // Medium priority - with reaction detection
    case insight = 2       // Medium priority - contextual analysis
    case reflection = 3    // Lower priority - personal thoughts
    case note = 4          // Lowest priority - general notes
    case unknown = 5       // Unknown content type
    
    static func < (lhs: ContentType, rhs: ContentType) -> Bool {
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

// MARK: - Unified Processed Content
struct UnifiedProcessedContent: Identifiable {
    let id = UUID()
    let type: ContentType
    let text: String
    let confidence: Double
    let timestamp: Date
    let bookContext: Book?
    let pageContext: Int?
    let aiResponse: String?
    let metadata: [String: Any]
    
    var requiresAction: Bool {
        type.requiresAIResponse && aiResponse == nil
    }
}

// MARK: - Context Window
class RollingContextWindow {
    private var recentDetections: [UnifiedProcessedContent] = []
    private let maxSize = 10
    private let duplicateWindow: TimeInterval = 10.0 // 10 seconds - increased to catch more duplicates
    
    func add(_ content: UnifiedProcessedContent) {
        recentDetections.append(content)
        if recentDetections.count > maxSize {
            recentDetections.removeFirst()
        }
    }
    
    func isDuplicate(_ text: String) -> Bool {
        let now = Date()
        let threshold = now.addingTimeInterval(-duplicateWindow)
        
        return recentDetections.contains { detection in
            detection.timestamp > threshold &&
            similarity(detection.text, text) > 0.85
        }
    }
    
    func getRecentContext(_ count: Int = 3) -> [UnifiedProcessedContent] {
        Array(recentDetections.suffix(count))
    }
    
    private func similarity(_ s1: String, _ s2: String) -> Double {
        let s1Lower = s1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let s2Lower = s2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if s1Lower == s2Lower { return 1.0 }
        
        // Check for substring containment (handles partial matches)
        if s1Lower.contains(s2Lower) || s2Lower.contains(s1Lower) {
            let lengthRatio = Double(min(s1Lower.count, s2Lower.count)) / Double(max(s1Lower.count, s2Lower.count))
            if lengthRatio > 0.7 { return 0.9 } // High similarity for substrings
        }
        
        // Enhanced Jaccard similarity
        let s1Words = Set(s1Lower.split(separator: " ").map(String.init))
        let s2Words = Set(s2Lower.split(separator: " ").map(String.init))
        
        let intersection = s1Words.intersection(s2Words).count
        let union = s1Words.union(s2Words).count
        
        let jaccardSimilarity = union > 0 ? Double(intersection) / Double(union) : 0.0
        
        // Boost similarity if most words match (handles reordering)
        if intersection > 0 && Double(intersection) / Double(min(s1Words.count, s2Words.count)) > 0.8 {
            return max(jaccardSimilarity, 0.85)
        }
        
        return jaccardSimilarity
    }
}

// MARK: - Main Processor
@MainActor
class UnifiedTranscriptionProcessor: ObservableObject {
    static let shared = UnifiedTranscriptionProcessor()
    
    @Published private(set) var currentState: ProcessingState = .listening
    @Published private(set) var processingQueue: [UnifiedProcessedContent] = []
    @Published private(set) var recentlySaved: [UnifiedProcessedContent] = []
    
    private let contextWindow = RollingContextWindow()
    private let contentIntelligence = ContentIntelligence.shared
    private var processingTask: Task<Void, Never>?
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.5
    
    // Confidence thresholds
    private let confidenceThresholds: [ContentType: Double] = [
        .question: 0.7,
        .quote: 0.75,
        .insight: 0.65,
        .reflection: 0.6,
        .note: 0.5
    ]
    
    // Current context
    var currentBook: Book?
    var currentPage: Int?
    
    private init() {
        startProcessingLoop()
    }
    
    // MARK: - Public Interface
    
    func processTranscription(_ text: String, immediate: Bool = false) {
        guard !text.isEmpty else { return }
        
        // Log incoming transcription
        print("🎤 UnifiedProcessor: Received transcription (\(text.count) chars)")
        
        if immediate {
            processImmediately(text)
        } else {
            debounceProcessing(text)
        }
    }
    
    // Enhanced processing with ContentIntelligence
    func processWithIntelligence(_ text: String) async -> UnifiedProcessedContent {
        // Set context
        contentIntelligence.setBookContext(currentBook)
        
        // Get intelligent detection
        let detection = contentIntelligence.detectContent(text, bookContext: currentBook)
        
        // Log detection for debugging
        print("🧠 ContentIntelligence Detection:")
        print("   Type: \(detection.type)")
        print("   Confidence: \(String(format: "%.2f", detection.confidence))")
        print("   Reasoning: \(detection.reasoning)")
        
        // Create processed content
        let content = UnifiedProcessedContent(
            type: detection.type,
            text: detection.extractedText,
            confidence: detection.confidence,
            timestamp: Date(),
            bookContext: currentBook,
            pageContext: currentPage,
            aiResponse: nil,
            metadata: detection.metadata
        )
        
        // Add to processing queue if confidence is high enough
        if detection.confidence >= confidenceThresholds[detection.type] ?? 0.5 {
            addToQueue(content)
        }
        
        return content
    }
    
    func setContext(book: Book?, page: Int? = nil) {
        currentBook = book
        currentPage = page
        print("📚 UnifiedProcessor: Context set - Book: \(book?.title ?? "None"), Page: \(page ?? 0)")
    }
    
    func clearQueue() {
        processingQueue.removeAll()
        currentState = .listening
    }
    
    // MARK: - Processing Pipeline
    
    private func debounceProcessing(_ text: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { _ in
            Task { @MainActor in
                self.processImmediately(text)
            }
        }
    }
    
    private func processImmediately(_ text: String) {
        // Update state
        currentState = .detecting(content: text)
        
        // Check for duplicates
        if contextWindow.isDuplicate(text) {
            print("⚠️ UnifiedProcessor: Duplicate detected, skipping")
            currentState = .listening
            return
        }
        
        // Use ContentIntelligence for smarter detection
        contentIntelligence.setBookContext(currentBook)
        let detection = contentIntelligence.detectContent(text, bookContext: currentBook)
        
        // Log the intelligent detection
        print("🧠 ContentIntelligence: Detected \(detection.type) with confidence \(String(format: "%.2f", detection.confidence))")
        print("   Reasoning: \(detection.reasoning)")
        
        // Create UnifiedProcessedContent from detection
        let content = UnifiedProcessedContent(
            type: detection.type,
            text: detection.extractedText,
            confidence: detection.confidence,
            timestamp: Date(),
            bookContext: currentBook,
            pageContext: currentPage,
            aiResponse: nil,
            metadata: detection.metadata
        )
        
        // Add to queue if confidence is sufficient
        if detection.confidence >= confidenceThresholds[detection.type] ?? 0.5 {
            print("✅ UnifiedProcessor: Processing \(detection.type)")
            addToQueue(content)
        }
        
        // Return to listening if nothing detected
        if processingQueue.isEmpty {
            currentState = .listening
        }
    }
    
    func detectContent(_ text: String) async -> UnifiedProcessedContent {
        // Use ContentIntelligence for smarter detection
        contentIntelligence.setBookContext(currentBook)
        let detection = contentIntelligence.detectContent(text, bookContext: currentBook)
        
        // Convert detection result to UnifiedProcessedContent
        return UnifiedProcessedContent(
            type: detection.type,
            text: detection.extractedText,
            confidence: detection.confidence,
            timestamp: Date(),
            bookContext: currentBook,
            pageContext: currentPage,
            aiResponse: nil,
            metadata: detection.metadata
        )
    }
    
    private func detectContentTypes(_ text: String) -> [UnifiedProcessedContent] {
        var detections: [UnifiedProcessedContent] = []
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmedText.lowercased()
        
        // Question detection
        if isQuestion(trimmedText) {
            detections.append(UnifiedProcessedContent(
                type: .question,
                text: trimmedText,
                confidence: calculateQuestionConfidence(trimmedText),
                timestamp: Date(),
                bookContext: currentBook,
                pageContext: currentPage,
                aiResponse: nil,
                metadata: [:]
            ))
        }
        
        // Quote detection
        if isQuote(trimmedText) {
            detections.append(UnifiedProcessedContent(
                type: .quote,
                text: extractQuoteText(trimmedText),
                confidence: calculateQuoteConfidence(trimmedText),
                timestamp: Date(),
                bookContext: currentBook,
                pageContext: currentPage,
                aiResponse: nil,
                metadata: ["reaction": detectQuoteReaction(trimmedText)]
            ))
        }
        
        // Insight detection
        if isInsight(trimmedText) {
            detections.append(UnifiedProcessedContent(
                type: .insight,
                text: trimmedText,
                confidence: calculateInsightConfidence(trimmedText),
                timestamp: Date(),
                bookContext: currentBook,
                pageContext: currentPage,
                aiResponse: nil,
                metadata: [:]
            ))
        }
        
        // Reflection detection
        if isReflection(trimmedText) {
            detections.append(UnifiedProcessedContent(
                type: .reflection,
                text: trimmedText,
                confidence: 0.7,
                timestamp: Date(),
                bookContext: currentBook,
                pageContext: currentPage,
                aiResponse: nil,
                metadata: [:]
            ))
        }
        
        // Default to note if long enough and no other type detected
        if detections.isEmpty && trimmedText.count > 20 {
            detections.append(UnifiedProcessedContent(
                type: .note,
                text: trimmedText,
                confidence: 0.6,
                timestamp: Date(),
                bookContext: currentBook,
                pageContext: currentPage,
                aiResponse: nil,
                metadata: [:]
            ))
        }
        
        return detections
    }
    
    // MARK: - Content Detection Helpers
    
    private func isQuestion(_ text: String) -> Bool {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct question mark
        if text.hasSuffix("?") { return true }
        
        // Question starters
        let questionStarters = [
            "what", "why", "how", "when", "where", "who", "which",
            "is it", "does", "do you", "can", "could", "would", "should",
            "will", "are", "was", "were", "did", "have", "has", "had"
        ]
        
        return questionStarters.contains { lowercased.hasPrefix($0) }
    }
    
    private func calculateQuestionConfidence(_ text: String) -> Double {
        var confidence = 0.5
        
        if text.hasSuffix("?") { confidence += 0.3 }
        if text.count > 10 { confidence += 0.1 }
        if text.contains(" ") { confidence += 0.1 } // Multi-word question
        
        return min(confidence, 1.0)
    }
    
    private func isQuote(_ text: String) -> Bool {
        let patterns = [
            "quote", "passage", "line", "favorite part", "love this",
            "beautiful", "powerful", "moving", "struck by"
        ]
        
        let lowercased = text.lowercased()
        
        // Check for quote indicators
        if text.contains("\"") || text.contains("'") { return true }
        
        // Check for quote introduction patterns
        return patterns.contains { lowercased.contains($0) }
    }
    
    private func extractQuoteText(_ text: String) -> String {
        // Extract text between quotes if present
        if let match = text.range(of: #""([^"]+)""#, options: .regularExpression) {
            return String(text[match]).replacingOccurrences(of: "\"", with: "")
        }
        
        // Remove quote indicators
        let cleanedText = text
            .replacingOccurrences(of: "quote", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "passage", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedText
    }
    
    private func calculateQuoteConfidence(_ text: String) -> Double {
        var confidence = 0.6
        
        if text.contains("\"") { confidence += 0.2 }
        if text.count > 20 { confidence += 0.1 }
        if detectQuoteReaction(text) != "neutral" { confidence += 0.1 }
        
        return min(confidence, 1.0)
    }
    
    private func detectQuoteReaction(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        let positive = ["love", "beautiful", "amazing", "wonderful", "brilliant", "perfect"]
        let negative = ["hate", "terrible", "awful", "disappointing", "boring"]
        let thoughtful = ["interesting", "thought-provoking", "makes me think", "curious"]
        
        if positive.contains(where: { lowercased.contains($0) }) { return "positive" }
        if negative.contains(where: { lowercased.contains($0) }) { return "negative" }
        if thoughtful.contains(where: { lowercased.contains($0) }) { return "thoughtful" }
        
        return "neutral"
    }
    
    private func isInsight(_ text: String) -> Bool {
        let patterns = [
            "realize", "understand", "notice", "see that", "think that",
            "interesting that", "funny how", "strange that", "reminds me",
            "makes me think", "connection", "similar to", "different from"
        ]
        
        let lowercased = text.lowercased()
        return patterns.contains { lowercased.contains($0) }
    }
    
    private func calculateInsightConfidence(_ text: String) -> Double {
        var confidence = 0.5
        
        if text.count > 30 { confidence += 0.2 }
        if text.contains("because") || text.contains("since") { confidence += 0.15 }
        if text.contains("I") || text.contains("me") || text.contains("my") { confidence += 0.15 }
        
        return min(confidence, 1.0)
    }
    
    private func isReflection(_ text: String) -> Bool {
        let patterns = [
            "i think", "i feel", "i believe", "in my opinion", "to me",
            "personally", "i wonder", "maybe", "perhaps", "it seems"
        ]
        
        let lowercased = text.lowercased()
        return patterns.contains { lowercased.contains($0) } && text.count > 30
    }
    
    // MARK: - Queue Management
    
    private func addToQueue(_ content: UnifiedProcessedContent) {
        // Enhanced deduplication check
        guard !contextWindow.isDuplicate(content.text) else {
            print("⚠️ UnifiedProcessor: Skipping duplicate content")
            return
        }
        
        processingQueue.append(content)
        contextWindow.add(content)
        currentState = .processing(type: content.type, content: content.text)
        
        // Notify observers
        NotificationCenter.default.post(
            name: Notification.Name("UnifiedProcessorDetection"),
            object: content
        )
    }
    
    private func startProcessingLoop() {
        processingTask = Task {
            while !Task.isCancelled {
                await processNextInQueue()
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    private func processNextInQueue() async {
        guard let content = processingQueue.first else { return }
        
        currentState = .saving(item: content)
        
        // Process based on type
        if content.requiresAction {
            await handleQuestionWithAI(content)
        }
        
        // Save to appropriate storage
        await saveContent(content)
        
        // Remove from queue and update state
        processingQueue.removeFirst()
        recentlySaved.append(content)
        
        // Keep only last 20 saved items
        if recentlySaved.count > 20 {
            recentlySaved.removeFirst()
        }
        
        currentState = processingQueue.isEmpty ? .listening : .processing(
            type: processingQueue.first!.type,
            content: processingQueue.first!.text
        )
    }
    
    private func handleQuestionWithAI(_ content: UnifiedProcessedContent) async {
        // Use OptimizedAIResponseService for questions
        await OptimizedAIResponseService.shared.processImmediateQuestion(
            content.text,
            bookContext: content.bookContext
        )
    }
    
    private func saveContent(_ content: UnifiedProcessedContent) async {
        // Save to SwiftData or appropriate storage
        // This would integrate with your existing models
        
        print("💾 UnifiedProcessor: Saved \(content.type) - \(content.text.prefix(50))...")
        
        // Post notification for UI updates
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("UnifiedProcessorSaved"),
                object: content
            )
        }
    }
    
    // MARK: - Debug Helpers
    
    func getDebugInfo() -> String {
        """
        State: \(currentState.description)
        Queue: \(processingQueue.count) items
        Recent: \(recentlySaved.count) saved
        Book: \(currentBook?.title ?? "None")
        Page: \(currentPage ?? 0)
        """
    }
}