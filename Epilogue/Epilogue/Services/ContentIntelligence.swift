import Foundation
import SwiftUI
import NaturalLanguage

// MARK: - Content Intelligence Engine
@MainActor
class ContentIntelligence {
    static let shared = ContentIntelligence()
    
    // MARK: - Content Types
    enum ContentType {
        case quote
        case note
        case question
        case thought
        case ambient
        case unknown
        case reflection
        case insight
    }
    
    // MARK: - Detection Result
    struct DetectionResult {
        let type: ContentType
        let confidence: Double
        let extractedText: String
        let metadata: [String: Any]
        let reasoning: String // For debugging
    }
    
    // MARK: - Context State
    private var recentDetections: [DetectionResult] = []
    private var lastReactionTime: Date?
    private var awaitingQuoteAfterReaction = false
    private var currentBookContext: Book?
    
    // Confidence thresholds
    private let minConfidence: Double = 0.6
    private let highConfidence: Double = 0.85
    
    private init() {}
    
    // MARK: - Main Detection Method
    func detectContent(_ text: String, bookContext: Book? = nil) -> DetectionResult {
        self.currentBookContext = bookContext
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check each detection type and get the best match
        let detections = [
            detectQuote2_0(trimmed),
            detectQuestionVsReflection(trimmed),
            detectNoteType(trimmed)
        ].compactMap { $0 }
        
        // Return highest confidence detection
        if let best = detections.max(by: { $0.confidence < $1.confidence }),
           best.confidence >= minConfidence {
            
            // Update state
            recentDetections.append(best)
            if recentDetections.count > 10 {
                recentDetections.removeFirst()
            }
            
            return best
        }
        
        // Default to note with low confidence
        return DetectionResult(
            type: .note,
            confidence: 0.5,
            extractedText: trimmed,
            metadata: [:],
            reasoning: "Default classification"
        )
    }
    
    // MARK: - Quote Detection 2.0
    private func detectQuote2_0(_ text: String) -> DetectionResult? {
        var confidence: Double = 0.0
        var reasoning = "Quote detection: "
        let lowercased = text.lowercased()
        
        // 1. Reaction Pattern Detection
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
        
        var detectedReaction: String? = nil
        var quoteText = text
        
        // Check if this follows a recent reaction
        if awaitingQuoteAfterReaction,
           let lastReaction = lastReactionTime,
           Date().timeIntervalSince(lastReaction) < 5.0 {
            // This is likely the quote following a reaction
            confidence += 0.4
            reasoning += "Follows recent reaction. "
            awaitingQuoteAfterReaction = false
        }
        
        // Check for reaction patterns in current text
        for pattern in reactionPatterns {
            if lowercased.contains(pattern) {
                detectedReaction = pattern
                confidence += 0.35
                reasoning += "Contains reaction '\(pattern)'. "
                
                // Extract text after the reaction
                if let range = lowercased.range(of: pattern) {
                    let afterReaction = String(text[range.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Clean up separators
                    var cleanedQuote = afterReaction
                    let separators = [":", "...", "…", "--", "—", ".", ","]
                    for separator in separators {
                        if cleanedQuote.hasPrefix(separator) {
                            cleanedQuote = String(cleanedQuote.dropFirst(separator.count))
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                    
                    if !cleanedQuote.isEmpty {
                        quoteText = cleanedQuote
                        confidence += 0.15
                        reasoning += "Extracted quote after reaction. "
                    } else {
                        // Reaction without immediate quote - expect quote next
                        awaitingQuoteAfterReaction = true
                        lastReactionTime = Date()
                        reasoning += "Reaction detected, awaiting quote. "
                    }
                }
                break
            }
        }
        
        // 2. Quotation Mark Detection
        let hasQuotationMarks = text.contains("\"") || 
                                text.contains("\u{201C}") || 
                                text.contains("\u{201D}") ||
                                text.contains("'") ||
                                text.contains("\u{2019}")
        
        if hasQuotationMarks {
            confidence += 0.25
            reasoning += "Contains quotation marks. "
            
            // Extract quoted content
            if let quotedContent = extractQuotedContent(from: text) {
                quoteText = quotedContent
                confidence += 0.1
                reasoning += "Successfully extracted quoted text. "
            }
        }
        
        // 3. Length Heuristics (20-200 words typical for quotes)
        let wordCount = quoteText.split(separator: " ").count
        if wordCount >= 10 && wordCount <= 200 {
            confidence += 0.15
            reasoning += "Good quote length (\(wordCount) words). "
        } else if wordCount < 10 {
            confidence -= 0.1
            reasoning += "Too short for quote (\(wordCount) words). "
        } else if wordCount > 200 {
            confidence -= 0.05
            reasoning += "Too long for typical quote (\(wordCount) words). "
        }
        
        // 4. Literary Language Detection
        let literaryIndicators = [
            "beauty", "soul", "heart", "truth", "wisdom", "journey",
            "destiny", "fate", "love", "death", "life", "meaning",
            "purpose", "courage", "fear", "hope", "dream"
        ]
        
        let literaryCount = literaryIndicators.filter { lowercased.contains($0) }.count
        if literaryCount > 0 {
            confidence += Double(literaryCount) * 0.05
            reasoning += "Contains \(literaryCount) literary terms. "
        }
        
        // 5. Attribution Patterns
        let attributionPatterns = [
            "says", "writes", "wrote", "according to", "from",
            "chapter", "page", "paragraph", "line"
        ]
        
        if attributionPatterns.contains(where: { lowercased.contains($0) }) {
            confidence += 0.1
            reasoning += "Contains attribution pattern. "
        }
        
        // Clean the extracted quote
        quoteText = cleanQuoteText(quoteText)
        
        // Return if confidence is sufficient
        if confidence >= minConfidence {
            return DetectionResult(
                type: .quote,
                confidence: min(confidence, 1.0),
                extractedText: quoteText,
                metadata: [
                    "hasReaction": detectedReaction != nil,
                    "reaction": detectedReaction ?? "",
                    "hasQuotationMarks": hasQuotationMarks,
                    "wordCount": wordCount
                ],
                reasoning: reasoning
            )
        }
        
        return nil
    }
    
    // MARK: - Question vs Reflection Disambiguation
    private func detectQuestionVsReflection(_ text: String) -> DetectionResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        var reasoning = ""
        
        // Must have question mark for either
        guard trimmed.hasSuffix("?") else { return nil }
        
        var isReflection = false
        var isQuestion = false
        var confidence: Double = 0.7 // Base confidence for having question mark
        
        // Reflection Patterns (rhetorical/philosophical)
        let reflectionStarters = [
            "i wonder if", "i wonder whether", "i wonder why",
            "what if", "why do i", "why am i", "how come i",
            "isn't it strange", "isn't it interesting", "isn't it funny",
            "don't you think", "wouldn't it be", "shouldn't we",
            "could it be that", "might this mean", "perhaps"
        ]
        
        for pattern in reflectionStarters {
            if lowercased.hasPrefix(pattern) || lowercased.contains(" \(pattern)") {
                isReflection = true
                confidence += 0.2
                reasoning += "Starts with reflection pattern '\(pattern)'. "
                break
            }
        }
        
        // Direct Question Patterns (seeking information)
        let questionStarters = [
            "can you explain", "could you explain", "would you explain",
            "can you tell", "could you tell", "would you tell",
            "what does", "what is", "what are", "what was", "what were",
            "how does", "how do", "how is", "how are",
            "why does", "why do", "why is", "why are",
            "when does", "when do", "when is", "when are",
            "where does", "where do", "where is", "where are",
            "who is", "who are", "who was", "who were"
        ]
        
        for pattern in questionStarters {
            if lowercased.hasPrefix(pattern) {
                isQuestion = true
                confidence += 0.25
                reasoning += "Starts with question pattern '\(pattern)'. "
                break
            }
        }
        
        // Context Analysis
        if let lastDetection = recentDetections.last {
            if lastDetection.type == .quote {
                // After a quote, more likely to be reflection
                if !isQuestion {
                    isReflection = true
                    confidence += 0.15
                    reasoning += "Follows a quote (likely reflection). "
                }
            }
        }
        
        // Personal pronoun analysis
        let personalPronouns = ["i", "me", "my", "myself"]
        let personalCount = personalPronouns.filter { 
            lowercased.split(separator: " ").map(String.init).contains($0) 
        }.count
        
        if personalCount >= 2 {
            isReflection = true
            confidence += 0.1
            reasoning += "Multiple personal pronouns (\(personalCount)). "
        }
        
        // Determine final type
        let finalType: ContentType
        if isQuestion && !isReflection {
            finalType = .question
            reasoning = "Question: " + reasoning
        } else if isReflection && !isQuestion {
            finalType = .reflection
            reasoning = "Reflection: " + reasoning
        } else if isReflection && isQuestion {
            // Both patterns detected - use context and confidence
            if confidence >= 0.8 {
                finalType = .reflection
                reasoning = "Reflection (high confidence): " + reasoning
            } else {
                finalType = .question
                reasoning = "Question (ambiguous): " + reasoning
            }
        } else {
            // Generic question
            finalType = .question
            confidence = 0.6
            reasoning = "Question (default): " + reasoning
        }
        
        return DetectionResult(
            type: finalType,
            confidence: min(confidence, 1.0),
            extractedText: trimmed,
            metadata: [
                "isRhetorical": isReflection,
                "seekingAnswer": isQuestion,
                "personalPronouns": personalCount
            ],
            reasoning: reasoning
        )
    }
    
    // MARK: - Note Intelligence
    private func detectNoteType(_ text: String) -> DetectionResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        var confidence: Double = 0.5
        var reasoning = "Note detection: "
        var noteType: ContentType = .note
        
        // Skip if too short
        guard trimmed.count > 10 else { return nil }
        
        // Personal Note Detection
        let personalIndicators = [
            "i think", "i feel", "i believe", "i realize",
            "my opinion", "my thought", "my experience",
            "reminds me of", "makes me think", "i remember"
        ]
        
        let personalCount = personalIndicators.filter { lowercased.contains($0) }.count
        if personalCount > 0 {
            noteType = .reflection
            confidence += Double(personalCount) * 0.15
            reasoning += "\(personalCount) personal indicators. "
        }
        
        // Insight Detection
        let insightIndicators = [
            "realize", "understand", "notice", "discover",
            "interesting that", "funny how", "strange that",
            "connection between", "similar to", "different from",
            "pattern", "theme", "symbolism", "represents"
        ]
        
        let insightCount = insightIndicators.filter { lowercased.contains($0) }.count
        if insightCount > 0 {
            noteType = .insight
            confidence += Double(insightCount) * 0.2
            reasoning += "\(insightCount) insight indicators. "
        }
        
        // Connection Detection
        let connectionIndicators = [
            "relates to", "connects to", "similar to",
            "like when", "just like", "reminds me of",
            "same as", "different from", "contrast with",
            "parallel", "mirrors", "echoes"
        ]
        
        let connectionCount = connectionIndicators.filter { lowercased.contains($0) }.count
        if connectionCount > 0 {
            noteType = .insight // Using insight for connections
            confidence += Double(connectionCount) * 0.2
            reasoning += "\(connectionCount) connection indicators. "
        }
        
        // Emotional Response Detection
        let emotionalWords = [
            "love", "hate", "happy", "sad", "angry", "frustrated",
            "excited", "worried", "anxious", "peaceful", "calm",
            "beautiful", "ugly", "amazing", "terrible", "wonderful"
        ]
        
        let emotionalCount = emotionalWords.filter { lowercased.contains($0) }.count
        if emotionalCount >= 2 {
            noteType = .reflection // Using reflection for reactions
            confidence += 0.25
            reasoning += "Strong emotional content (\(emotionalCount) words). "
        }
        
        // Book Reference Detection
        let bookReferences = [
            "the author", "the book", "this chapter", "this section",
            "the character", "the protagonist", "the story",
            "the plot", "the theme", "the setting"
        ]
        
        let bookRefCount = bookReferences.filter { lowercased.contains($0) }.count
        if bookRefCount > 0 {
            confidence += 0.1
            reasoning += "Contains \(bookRefCount) book references. "
        }
        
        // Length bonus for substantial notes
        let wordCount = trimmed.split(separator: " ").count
        if wordCount >= 20 {
            confidence += 0.1
            reasoning += "Substantial length (\(wordCount) words). "
        }
        
        return DetectionResult(
            type: noteType,
            confidence: min(confidence, 1.0),
            extractedText: trimmed,
            metadata: [
                "personalIndicators": personalCount,
                "insightIndicators": insightCount,
                "connectionIndicators": connectionCount,
                "emotionalWords": emotionalCount,
                "bookReferences": bookRefCount,
                "wordCount": wordCount
            ],
            reasoning: reasoning
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractQuotedContent(from text: String) -> String? {
        // Try different quote patterns
        let patterns = [
            "\"([^\"]+)\"",           // Standard double quotes
            "\u{201C}([^\u{201D}]+)\u{201D}",               // Smart quotes
            "'([^']+)'",               // Single quotes
            "\u{2018}([^\u{2019}]+)\u{2019}"                // Smart single quotes
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        
        return nil
    }
    
    private func cleanQuoteText(_ text: String) -> String {
        var cleaned = text
        
        // Remove quotes if present
        let quoteChars = ["\"", "\u{201C}", "\u{201D}", "'", "\u{2018}", "\u{2019}"]
        for char in quoteChars {
            cleaned = cleaned.replacingOccurrences(of: char, with: "")
        }
        
        // Remove common prefixes
        let prefixes = [
            "quote:", "quote -", "he says", "she says", "it says",
            "the author says", "the book says", "listen to this"
        ]
        
        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Confidence Scoring
    
    func calculateCompositeConfidence(for detections: [DetectionResult]) -> Double {
        guard !detections.isEmpty else { return 0.0 }
        
        // Weight recent detections more heavily
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (index, detection) in detections.enumerated() {
            let weight = Double(index + 1) / Double(detections.count)
            weightedSum += detection.confidence * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0.0
    }
    
    // MARK: - Context Management
    
    func setBookContext(_ book: Book?) {
        currentBookContext = book
    }
    
    func clearContext() {
        recentDetections.removeAll()
        awaitingQuoteAfterReaction = false
        lastReactionTime = nil
        currentBookContext = nil
    }
    
    // MARK: - Debug Support
    
    func getDetectionHistory() -> [DetectionResult] {
        return recentDetections
    }
    
    func getLastDetection() -> DetectionResult? {
        return recentDetections.last
    }
}

// MARK: - ContentType Extension for Intelligence
extension ContentIntelligence.ContentType {
    var requiresContext: Bool {
        switch self {
        case .thought, .insight, .reflection:
            return true
        default:
            return false
        }
    }
    
    var priorityScore: Int {
        switch self {
        case .question: return 100
        case .quote: return 90
        case .insight: return 80
        case .reflection: return 70
        case .thought: return 60
        case .note: return 50
        case .ambient: return 30
        case .unknown: return 0
        }
    }
}