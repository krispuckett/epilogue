import Foundation
import NaturalLanguage
import Combine

// MARK: - Intelligent Question Detection & Processing System

@MainActor
public class IntelligentQuestionSystem: ObservableObject {
    public static let shared = IntelligentQuestionSystem()
    
    // Published state
    @Published public var detectedQuestions: [DetectedQuestion] = []
    @Published public var isProcessing = false
    @Published public var currentContext: QuestionContext?
    
    // NLP components
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .sentimentScore])
    private let embedder = NLEmbedding.sentenceEmbedding(for: .english)
    
    // Question patterns
    private let questionPatterns = QuestionPatternMatcher()
    private let contextAnalyzer = ContextualAnalyzer()
    
    private init() {}
    
    // MARK: - Public Methods
    
    public func processText(_ text: String, bookContext: String? = nil) async -> [DetectedQuestion] {
        isProcessing = true
        defer { isProcessing = false }
        
        // Update context
        if let bookContext = bookContext {
            currentContext = QuestionContext(bookTitle: bookContext, timestamp: Date())
        }
        
        // Extract questions
        let questions = await extractQuestions(from: text)
        
        // Classify and enrich
        let enrichedQuestions = await enrichQuestions(questions)
        
        // Update state
        detectedQuestions = enrichedQuestions
        
        return enrichedQuestions
    }
    
    // MARK: - Question Extraction
    
    private func extractQuestions(from text: String) async -> [String] {
        var questions: [String] = []
        
        // 1. Direct question detection (sentences ending with ?)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix("?") || isImplicitQuestion(trimmed) {
                questions.append(trimmed)
            }
        }
        
        // 2. Implicit question detection
        let implicitQuestions = detectImplicitQuestions(in: text)
        questions.append(contentsOf: implicitQuestions)
        
        // 3. Rhetorical question detection
        let rhetoricalQuestions = detectRhetoricalQuestions(in: text)
        questions.append(contentsOf: rhetoricalQuestions)
        
        return questions.uniqued()
    }
    
    private func isImplicitQuestion(_ text: String) -> Bool {
        let implicitMarkers = [
            "i wonder", "i'm curious", "what if", "how come",
            "why does", "why do", "why is", "why are",
            "what about", "how about", "could it be",
            "is it possible", "do you think", "what do you think"
        ]
        
        let lowercased = text.lowercased()
        return implicitMarkers.contains { lowercased.contains($0) }
    }
    
    private func detectImplicitQuestions(in text: String) -> [String] {
        var questions: [String] = []
        
        // Pattern: "I wonder..." constructions
        let wonderPattern = try? NSRegularExpression(
            pattern: "(?i)(i wonder|i'm wondering|i've been wondering)\\s+(.+?)(?=[.!?]|$)",
            options: []
        )
        
        if let matches = wonderPattern?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let question = String(text[range]) + "?"
                    questions.append(question)
                }
            }
        }
        
        return questions
    }
    
    private func detectRhetoricalQuestions(in text: String) -> [String] {
        var questions: [String] = []
        
        // Pattern: Statements that are actually questions
        let rhetoricalPattern = try? NSRegularExpression(
            pattern: "(?i)(isn't it|doesn't it|won't it|can't we|shouldn't we)\\s+(.+?)(?=[.!?]|$)",
            options: []
        )
        
        if let matches = rhetoricalPattern?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text) {
                    questions.append(String(text[range]))
                }
            }
        }
        
        return questions
    }
    
    // MARK: - Question Enrichment
    
    private func enrichQuestions(_ questions: [String]) async -> [DetectedQuestion] {
        var enrichedQuestions: [DetectedQuestion] = []
        
        for question in questions {
            let type = classifyQuestion(question)
            let intent = detectIntent(question)
            let entities = extractEntities(from: question)
            let sentiment = analyzeSentiment(question)
            
            let detectedQuestion = DetectedQuestion(
                text: question,
                type: type,
                intent: intent,
                entities: entities,
                sentiment: sentiment,
                confidence: calculateConfidence(question),
                context: currentContext,
                timestamp: Date()
            )
            
            enrichedQuestions.append(detectedQuestion)
        }
        
        return enrichedQuestions
    }
    
    private func classifyQuestion(_ question: String) -> QuestionType {
        let lowercased = question.lowercased()
        
        if lowercased.starts(with: "what") { return .what }
        if lowercased.starts(with: "why") { return .why }
        if lowercased.starts(with: "how") { return .how }
        if lowercased.starts(with: "when") { return .when }
        if lowercased.starts(with: "where") { return .location }
        if lowercased.starts(with: "who") { return .who }
        if lowercased.starts(with: "which") { return .which }
        if lowercased.contains("?") { return .clarification }
        
        return .implicit
    }
    
    private func detectIntent(_ question: String) -> QuestionIntent {
        let lowercased = question.lowercased()
        
        if lowercased.contains("mean") || lowercased.contains("definition") {
            return .definition
        }
        if lowercased.contains("example") || lowercased.contains("instance") {
            return .example
        }
        if lowercased.contains("compare") || lowercased.contains("difference") {
            return .comparison
        }
        if lowercased.contains("explain") || lowercased.contains("understand") {
            return .explanation
        }
        if lowercased.contains("opinion") || lowercased.contains("think") {
            return .opinion
        }
        
        return .general
    }
    
    private func extractEntities(from text: String) -> [String] {
        var entities: [String] = []
        
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag {
                if tag == .noun || tag == .placeName || tag == .personalName || tag == .organizationName {
                    entities.append(String(text[tokenRange]))
                }
            }
            return true
        }
        
        return entities.uniqued()
    }
    
    private func analyzeSentiment(_ text: String) -> Double {
        tagger.string = text
        
        var totalScore: Double = 0
        var count = 0
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore, options: []) { tag, _ in
            if let tag = tag,
               let score = Double(tag.rawValue) {
                totalScore += score
                count += 1
            }
            return true
        }
        
        return count > 0 ? totalScore / Double(count) : 0
    }
    
    private func calculateConfidence(_ question: String) -> Double {
        var confidence = 0.5
        
        // Direct questions have higher confidence
        if question.contains("?") { confidence += 0.2 }
        
        // Question words increase confidence
        let questionWords = ["what", "why", "how", "when", "where", "who"]
        if questionWords.contains(where: { question.lowercased().starts(with: $0) }) {
            confidence += 0.2
        }
        
        // Length affects confidence
        if question.count > 20 { confidence += 0.1 }
        
        return min(confidence, 1.0)
    }
}

// MARK: - Models

public struct DetectedQuestion: Identifiable {
    public let id = UUID()
    public let text: String
    public let type: QuestionType
    public let intent: QuestionIntent
    public let entities: [String]
    public let sentiment: Double
    public let confidence: Double
    public let context: QuestionContext?
    public let timestamp: Date
}

public enum QuestionType {
    case what, why, how, when, location, who, which
    case clarification
    case implicit
    case rhetorical
}

public enum QuestionIntent {
    case definition
    case explanation
    case example
    case comparison
    case opinion
    case general
}

public struct QuestionContext {
    public let bookTitle: String
    public let timestamp: Date
}

// MARK: - Helper Classes

class QuestionPatternMatcher {
    private let patterns: [String: QuestionType] = [
        "what.*mean": .what,
        "why.*happen": .why,
        "how.*work": .how,
        "when.*occur": .when,
        "where.*find": .location,
        "who.*responsible": .who
    ]
    
    func matchPattern(in text: String) -> QuestionType? {
        for (pattern, type) in patterns {
            if let _ = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                .firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                return type
            }
        }
        return nil
    }
}

class ContextualAnalyzer {
    func analyzeContext(_ text: String, bookContext: String?) -> [String: Any] {
        var context: [String: Any] = [:]
        
        if let bookContext = bookContext {
            context["book"] = bookContext
        }
        
        context["timestamp"] = Date()
        context["length"] = text.count
        context["complexity"] = calculateComplexity(text)
        
        return context
    }
    
    private func calculateComplexity(_ text: String) -> Double {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let avgWordLength = words.reduce(0) { $0 + $1.count } / max(words.count, 1)
        return Double(avgWordLength) / 10.0
    }
}

// MARK: - Extensions

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}