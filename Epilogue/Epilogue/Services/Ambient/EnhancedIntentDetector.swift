import Foundation
import NaturalLanguage
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "EnhancedIntentDetector")

// MARK: - Enhanced Intent Detection System
public struct EnhancedIntent {
    public let primary: IntentType
    public let confidence: Float
    public let entities: [EnhancedEntity]
    public let sentiment: Sentiment
    public let subIntents: [IntentType]
    
    public enum IntentType: Equatable {
        // Questions with subtypes
        case question(subtype: QuestionType)
        // Reflections with emotional context
        case reflection(emotion: EmotionType)
        // Quotes with attribution
        case quote(speaker: String?)
        // Notes with categories
        case note(category: NoteCategory)
        // Thoughts with depth
        case thought(depth: ThoughtDepth)
        // Progress updates
        case progress(type: ProgressType)
        // Ambient/unknown
        case ambient
        case unknown
        
        var baseType: String {
            switch self {
            case .question: return "question"
            case .reflection: return "reflection"
            case .quote: return "quote"
            case .note: return "note"
            case .thought: return "thought"
            case .progress: return "progress"
            case .ambient: return "ambient"
            case .unknown: return "unknown"
            }
        }
    }
    
    public enum QuestionType {
        case factual      // Who, what, where, when
        case analytical   // Why, how, themes
        case comparative  // Similar to, different from
        case speculative  // What if, imagine if
        case clarification // What does X mean
        case opinion      // What do you think about
    }
    
    public enum EmotionType {
        case joy
        case sadness
        case surprise
        case anger
        case fear
        case love
        case neutral
    }
    
    public enum NoteCategory {
        case character
        case plot
        case theme
        case writing
        case personal
        case comparison
    }
    
    public enum ThoughtDepth {
        case surface     // Initial reaction
        case analytical  // Deeper analysis
        case connecting  // Making connections
        case philosophical // Life reflections
    }
    
    public enum ProgressType {
        case chapter
        case page
        case percentage
        case finished
        case started
    }
    
    public enum Sentiment {
        case positive(strength: Float)
        case negative(strength: Float)
        case neutral
        case mixed
    }
}

// MARK: - Enhanced Entity
public struct EnhancedEntity {
    public let text: String
    public let type: EntityType
    public let confidence: Float
    public let range: Range<String.Index>
    
    public enum EntityType {
        case character
        case location
        case event
        case concept
        case book
        case author
        case chapter
        case quote
    }
}

// MARK: - Enhanced Intent Detector
public class EnhancedIntentDetector {
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .sentimentScore])
    private let sentimentClassifier: NLModel?
    private let foundationModels = FoundationModelsManager.shared
    
    // Pattern matchers
    private let questionPatterns = [
        "who": EnhancedIntent.QuestionType.factual,
        "what": EnhancedIntent.QuestionType.factual,
        "where": EnhancedIntent.QuestionType.factual,
        "when": EnhancedIntent.QuestionType.factual,
        "why": EnhancedIntent.QuestionType.analytical,
        "how": EnhancedIntent.QuestionType.analytical,
        "what if": EnhancedIntent.QuestionType.speculative,
        "imagine if": EnhancedIntent.QuestionType.speculative,
        "similar to": EnhancedIntent.QuestionType.comparative,
        "different from": EnhancedIntent.QuestionType.comparative,
        "what does": EnhancedIntent.QuestionType.clarification,
        "what do you think": EnhancedIntent.QuestionType.opinion
    ]
    
    private let emotionKeywords = [
        "love": EnhancedIntent.EmotionType.love,
        "hate": EnhancedIntent.EmotionType.anger,
        "sad": EnhancedIntent.EmotionType.sadness,
        "happy": EnhancedIntent.EmotionType.joy,
        "surprised": EnhancedIntent.EmotionType.surprise,
        "shocked": EnhancedIntent.EmotionType.surprise,
        "afraid": EnhancedIntent.EmotionType.fear,
        "scared": EnhancedIntent.EmotionType.fear
    ]
    
    public init() {
        // Try to load sentiment model if available
        if let modelURL = Bundle.main.url(forResource: "SentimentClassifier", withExtension: "mlmodelc") {
            sentimentClassifier = try? NLModel(contentsOf: modelURL)
        } else {
            sentimentClassifier = nil
        }
    }
    
    // MARK: - Main Detection Method
    public func detectIntent(from text: String, bookTitle: String? = nil, bookAuthor: String? = nil) -> EnhancedIntent {
        let lowercased = text.lowercased()
        
        // Use iOS 26 models if available for enhanced entity extraction
        let entities: [EnhancedEntity]
        if foundationModels.isAvailable() {
            entities = extractEntitiesWithFoundationModels(from: text)
        } else {
            entities = extractEntities(from: text)
        }
        
        // Detect sentiment
        let sentiment = detectSentiment(from: text)
        
        // Parallel intent detection
        var detectedIntents: [(EnhancedIntent.IntentType, Float)] = []
        
        // Check for question
        if let questionType = detectQuestionType(from: lowercased) {
            detectedIntents.append((.question(subtype: questionType), calculateQuestionConfidence(text, questionType)))
        }
        
        // Check for quote
        if let quoteInfo = detectQuote(from: text, entities: entities) {
            detectedIntents.append((.quote(speaker: quoteInfo.speaker), quoteInfo.confidence))
        }
        
        // Check for reflection
        let emotion = detectEmotion(from: lowercased)
        if emotion != .neutral {
            detectedIntents.append((.reflection(emotion: emotion), 0.7))
        }
        
        // Check for progress update
        if let progress = detectProgress(from: lowercased) {
            detectedIntents.append((.progress(type: progress), 0.8))
        }
        
        // Check for note
        if let category = detectNoteCategory(from: text, entities: entities) {
            detectedIntents.append((.note(category: category), 0.6))
        }
        
        // Check for thought
        let thoughtDepth = analyzeThoughtDepth(from: text)
        if thoughtDepth != .surface {
            detectedIntents.append((.thought(depth: thoughtDepth), 0.5))
        }
        
        // Sort by confidence and pick primary
        detectedIntents.sort { $0.1 > $1.1 }
        
        let primary = detectedIntents.first?.0 ?? .ambient
        let confidence = detectedIntents.first?.1 ?? 0.3
        let subIntents = detectedIntents.dropFirst().map { $0.0 }
        
        logger.info("🎯 Enhanced Intent: \(primary.baseType) (confidence: \(confidence))")
        if !subIntents.isEmpty {
            logger.info("   Sub-intents: \(subIntents.map { $0.baseType }.joined(separator: ", "))")
        }
        
        return EnhancedIntent(
            primary: primary,
            confidence: confidence,
            entities: entities,
            sentiment: sentiment,
            subIntents: Array(subIntents)
        )
    }
    
    // MARK: - Question Detection
    private func detectQuestionType(from text: String) -> EnhancedIntent.QuestionType? {
        // Check for question mark first
        guard text.contains("?") || text.starts(with: "what") || text.starts(with: "who") ||
              text.starts(with: "where") || text.starts(with: "when") || text.starts(with: "why") ||
              text.starts(with: "how") else {
            return nil
        }
        
        // Find specific question type
        for (pattern, type) in questionPatterns {
            if text.starts(with: pattern) {
                return type
            }
        }
        
        // Default to factual if has question mark
        return text.contains("?") ? .factual : nil
    }
    
    private func calculateQuestionConfidence(_ text: String, _ type: EnhancedIntent.QuestionType) -> Float {
        var confidence: Float = 0.5
        
        // Question mark adds confidence
        if text.contains("?") { confidence += 0.3 }
        
        // Clear question words add confidence
        if text.starts(with: "what") || text.starts(with: "who") || text.starts(with: "why") {
            confidence += 0.2
        }
        
        return min(confidence, 0.95)
    }
    
    // MARK: - Quote Detection
    private func detectQuote(from text: String, entities: [EnhancedEntity]) -> (speaker: String?, confidence: Float)? {
        let hasQuotationMarks = text.contains("\"") || text.contains("\u{201C}") || text.contains("\u{201D}")
        let hasQuoteKeyword = text.lowercased().contains("quote") || text.lowercased().contains("said")
        
        if hasQuotationMarks || hasQuoteKeyword {
            // Try to find speaker from entities
            let speaker = entities.first(where: { $0.type == .character })?.text
            let confidence: Float = hasQuotationMarks ? 0.9 : 0.7
            return (speaker, confidence)
        }
        
        return nil
    }
    
    // MARK: - Emotion Detection
    private func detectEmotion(from text: String) -> EnhancedIntent.EmotionType {
        for (keyword, emotion) in emotionKeywords {
            if text.contains(keyword) {
                return emotion
            }
        }
        return .neutral
    }
    
    // MARK: - Progress Detection
    private func detectProgress(from text: String) -> EnhancedIntent.ProgressType? {
        if text.contains("chapter") { return .chapter }
        if text.contains("page") { return .page }
        if text.contains("finished") || text.contains("done") { return .finished }
        if text.contains("started") || text.contains("beginning") { return .started }
        if text.contains("%") || text.contains("percent") { return .percentage }
        return nil
    }
    
    // MARK: - Note Category Detection
    private func detectNoteCategory(from text: String, entities: [EnhancedEntity]) -> EnhancedIntent.NoteCategory? {
        // Check entities for clues
        if entities.contains(where: { $0.type == .character }) { return .character }
        
        // Check keywords
        let lowercased = text.lowercased()
        if lowercased.contains("theme") || lowercased.contains("symbol") { return .theme }
        if lowercased.contains("plot") || lowercased.contains("story") { return .plot }
        if lowercased.contains("writing") || lowercased.contains("style") { return .writing }
        if lowercased.contains("reminds me") || lowercased.contains("i feel") { return .personal }
        if lowercased.contains("similar to") || lowercased.contains("like in") { return .comparison }
        
        return nil
    }
    
    // MARK: - Thought Depth Analysis
    private func analyzeThoughtDepth(from text: String) -> EnhancedIntent.ThoughtDepth {
        let wordCount = text.split(separator: " ").count
        let lowercased = text.lowercased()
        
        // Philosophical indicators
        if lowercased.contains("meaning of") || lowercased.contains("purpose") ||
           lowercased.contains("life") || lowercased.contains("existence") {
            return .philosophical
        }
        
        // Connection indicators
        if lowercased.contains("reminds me") || lowercased.contains("similar to") ||
           lowercased.contains("just like") {
            return .connecting
        }
        
        // Analytical indicators
        if lowercased.contains("because") || lowercased.contains("therefore") ||
           lowercased.contains("analysis") || wordCount > 30 {
            return .analytical
        }
        
        return .surface
    }
    
    // MARK: - iOS 26 Enhanced Entity Extraction
    private func extractEntitiesWithFoundationModels(from text: String) -> [EnhancedEntity] {
        // This will use iOS 26 models when available
        // For now, fall back to standard extraction
        return extractEntities(from: text)
    }
    
    // MARK: - Entity Extraction
    private func extractEntities(from text: String) -> [EnhancedEntity] {
        var entities: [EnhancedEntity] = []
        
        tagger.string = text
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                let entityText = String(text[tokenRange])
                let entityType: EnhancedEntity.EntityType
                
                switch tag {
                case .personalName:
                    entityType = .character
                case .placeName:
                    entityType = .location
                case .organizationName:
                    entityType = .event
                default:
                    return true // Continue enumeration
                }
                
                entities.append(EnhancedEntity(
                    text: entityText,
                    type: entityType,
                    confidence: 0.8,
                    range: tokenRange
                ))
            }
            return true
        }
        
        // Also check for book-specific entities
        entities.append(contentsOf: extractBookEntities(from: text))
        
        return entities
    }
    
    private func extractBookEntities(from text: String) -> [EnhancedEntity] {
        var entities: [EnhancedEntity] = []
        let lowercased = text.lowercased()
        
        // Check for chapter mentions
        if let range = lowercased.range(of: "chapter \\d+", options: .regularExpression) {
            entities.append(EnhancedEntity(
                text: String(text[range]),
                type: .chapter,
                confidence: 0.9,
                range: range
            ))
        }
        
        return entities
    }
    
    // MARK: - Sentiment Detection
    private func detectSentiment(from text: String) -> EnhancedIntent.Sentiment {
        // Use NaturalLanguage framework
        tagger.string = text
        
        var positiveScore: Float = 0
        var negativeScore: Float = 0
        var count: Float = 0
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .sentimentScore) { tag, _ in
            if let tag = tag,
               let score = Double(tag.rawValue) {
                if score > 0 {
                    positiveScore += Float(score)
                } else {
                    negativeScore += Float(abs(score))
                }
                count += 1
            }
            return true
        }
        
        guard count > 0 else { return .neutral }
        
        let avgPositive = positiveScore / count
        let avgNegative = negativeScore / count
        
        if avgPositive > 0.1 && avgNegative < 0.1 {
            return .positive(strength: avgPositive)
        } else if avgNegative > 0.1 && avgPositive < 0.1 {
            return .negative(strength: avgNegative)
        } else if avgPositive > 0.1 && avgNegative > 0.1 {
            return .mixed
        } else {
            return .neutral
        }
    }
}