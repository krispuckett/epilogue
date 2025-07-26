import Foundation
import NaturalLanguage
import CoreML
import OSLog
import Combine

// Note: iOS 26 Foundation Models framework is not yet available in current SDK
// This implementation uses CoreML and NaturalLanguage as placeholders
// Replace with actual FoundationModels imports when available

private let logger = Logger(subsystem: "com.epilogue", category: "FoundationModelsProcessor")

// MARK: - Reading Intent Types
enum ReadingIntent: String, CaseIterable {
    case quoteCapture = "QUOTE_CAPTURE"
    case personalNote = "PERSONAL_NOTE"
    case question = "QUESTION"
    case emotionalReaction = "EMOTIONAL_REACTION"
    case bookmark = "BOOKMARK"
    case searchRequest = "SEARCH_REQUEST"
    case definition = "DEFINITION"
    case connection = "CONNECTION"
    
    var description: String {
        switch self {
        case .quoteCapture: return "Save quote from book"
        case .personalNote: return "Add personal thought"
        case .question: return "Needs clarification"
        case .emotionalReaction: return "Expressing emotion"
        case .bookmark: return "Mark current position"
        case .searchRequest: return "Search for information"
        case .definition: return "Define word or concept"
        case .connection: return "Making connection"
        }
    }
    
    var suggestedAction: String {
        switch self {
        case .quoteCapture: return "Highlight and save this passage?"
        case .personalNote: return "Save your thought as a note?"
        case .question: return "Would you like me to explain?"
        case .emotionalReaction: return "I sense your reaction. Want to explore?"
        case .bookmark: return "Bookmark this location?"
        case .searchRequest: return "Search for related content?"
        case .definition: return "Look up definition?"
        case .connection: return "Explore this connection?"
        }
    }
}

// MARK: - Foundation Models Processor
@MainActor
class FoundationModelsProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var lastIntent: ReadingIntent?
    @Published var confidence: Float = 0
    @Published var extractedEntities: [ExtractedEntity] = []
    @Published var sentiment: SentimentScore = SentimentScore()
    
    // Model placeholders (replace with actual Foundation Models when available)
    private var intentClassifier: NLModel?
    private var entityRecognizer: NLTagger?
    private var sentimentAnalyzer: NLModel?
    
    // Cache for performance
    private var modelCache: [String: Any] = [:]
    private var recentClassifications: [String: IntentResult] = [:]
    
    struct IntentResult {
        let intent: ReadingIntent
        let confidence: Float
        let timestamp: Date
    }
    
    struct ExtractedEntity {
        let text: String
        let type: EntityType
        let range: Range<String.Index>
        let confidence: Float
    }
    
    enum EntityType: String {
        case person = "PERSON"
        case location = "LOCATION"
        case quote = "QUOTE"
        case pageNumber = "PAGE"
        case concept = "CONCEPT"
        case bookTitle = "BOOK"
        case author = "AUTHOR"
        case time = "TIME"
    }
    
    struct SentimentScore {
        var positive: Float = 0
        var negative: Float = 0
        var neutral: Float = 0
        
        var dominant: String {
            if positive > negative && positive > neutral {
                return "positive"
            } else if negative > positive && negative > neutral {
                return "negative"
            } else {
                return "neutral"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await initializeModels()
        }
    }
    
    private func initializeModels() async {
        logger.info("Initializing Foundation Models...")
        
        // Initialize intent classifier
        if let modelURL = createIntentClassifierModel() {
            intentClassifier = try? NLModel(contentsOf: modelURL)
        }
        
        // Initialize entity recognizer
        entityRecognizer = NLTagger(tagSchemes: [.nameType, .lexicalClass, .lemma])
        
        // Initialize sentiment analyzer
        // Use built-in model as placeholder
        if let sentimentModel = createSentimentModel() {
            sentimentAnalyzer = try? NLModel(mlModel: sentimentModel)
        }
        
        logger.info("Foundation Models initialized")
    }
    
    // MARK: - Intent Classification
    
    func classifyIntent(
        from transcription: String,
        bookContext: BookContext? = nil
    ) async throws -> IntentResult {
        // Check cache first
        if let cached = recentClassifications[transcription],
           Date().timeIntervalSince(cached.timestamp) < 60 {
            return cached
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Build context-aware features
        let features = extractFeatures(from: transcription, context: bookContext)
        
        // Classify using patterns and ML
        let (intent, confidence) = await performIntentClassification(
            text: transcription,
            features: features,
            context: bookContext
        )
        
        // Cache result
        let result = IntentResult(
            intent: intent,
            confidence: confidence,
            timestamp: Date()
        )
        recentClassifications[transcription] = result
        
        // Update published properties
        lastIntent = intent
        self.confidence = confidence
        
        logger.info("Classified intent: \(intent.rawValue) with confidence: \(confidence)")
        
        return result
    }
    
    private func extractFeatures(from text: String, context: BookContext?) -> [String: Float] {
        var features: [String: Float] = [:]
        
        let lowercased = text.lowercased()
        
        // Quote indicators
        features["has_quote_marker"] = (lowercased.contains("quote") || lowercased.contains("passage")) ? 1.0 : 0.0
        features["has_save_word"] = (lowercased.contains("save") || lowercased.contains("remember")) ? 1.0 : 0.0
        
        // Question indicators
        features["is_question"] = text.contains("?") ? 1.0 : 0.0
        features["has_question_word"] = (lowercased.contains("what") || lowercased.contains("why") || lowercased.contains("how")) ? 1.0 : 0.0
        
        // Note indicators
        features["has_personal_pronoun"] = (lowercased.contains("i ") || lowercased.contains("my ") || lowercased.contains("me ")) ? 1.0 : 0.0
        features["has_think_word"] = (lowercased.contains("think") || lowercased.contains("believe") || lowercased.contains("feel")) ? 1.0 : 0.0
        
        // Emotion indicators
        features["has_emotion_word"] = detectEmotionWords(in: lowercased) ? 1.0 : 0.0
        features["has_exclamation"] = text.contains("!") ? 1.0 : 0.0
        
        // Context features
        if let context = context {
            features["is_fiction"] = context.genre.lowercased().contains("fiction") ? 1.0 : 0.0
            features["is_academic"] = context.genre.lowercased().contains("academic") ? 1.0 : 0.0
        }
        
        return features
    }
    
    private func performIntentClassification(
        text: String,
        features: [String: Float],
        context: BookContext?
    ) async -> (ReadingIntent, Float) {
        // Rule-based classification with confidence scores
        let patterns: [(ReadingIntent, [String], Float)] = [
            (.quoteCapture, ["save this", "remember this", "quote", "passage", "highlight"], 0.9),
            (.personalNote, ["i think", "i feel", "my thought", "reminds me"], 0.85),
            (.question, ["what does", "why does", "how does", "can you explain"], 0.9),
            (.emotionalReaction, ["wow", "amazing", "love this", "beautiful", "confused"], 0.8),
            (.bookmark, ["bookmark", "mark this", "save my place"], 0.95),
            (.searchRequest, ["search for", "find", "look up", "tell me about"], 0.9),
            (.definition, ["what is", "define", "meaning of"], 0.9),
            (.connection, ["reminds me of", "similar to", "just like", "connects to"], 0.85)
        ]
        
        let lowercased = text.lowercased()
        
        // Check patterns
        for (intent, keywords, baseConfidence) in patterns {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    // Adjust confidence based on features
                    var confidence = baseConfidence
                    
                    // Boost confidence for matching features
                    switch intent {
                    case .question:
                        if features["is_question"] == 1.0 { confidence += 0.05 }
                    case .emotionalReaction:
                        if features["has_emotion_word"] == 1.0 { confidence += 0.05 }
                    case .personalNote:
                        if features["has_personal_pronoun"] == 1.0 { confidence += 0.05 }
                    default:
                        break
                    }
                    
                    return (intent, min(confidence, 1.0))
                }
            }
        }
        
        // Fallback to ML model if available
        if let classifier = intentClassifier {
            let prediction = classifier.predictedLabel(for: text) ?? ReadingIntent.emotionalReaction.rawValue
            if let intent = ReadingIntent(rawValue: prediction) {
                return (intent, 0.7)
            }
        }
        
        // Default based on features
        if features["is_question"] == 1.0 {
            return (.question, 0.6)
        } else if features["has_emotion_word"] == 1.0 {
            return (.emotionalReaction, 0.6)
        } else {
            return (.personalNote, 0.5)
        }
    }
    
    // MARK: - Entity Extraction
    
    func extractEntities(from text: String) async -> [ExtractedEntity] {
        guard let tagger = entityRecognizer else { return [] }
        
        var entities: [ExtractedEntity] = []
        
        tagger.string = text
        
        // Extract named entities
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType
        ) { tag, tokenRange in
            if let tag = tag {
                let entityText = String(text[tokenRange])
                let entityType: EntityType
                
                switch tag {
                case .personalName:
                    entityType = .person
                case .placeName:
                    entityType = .location
                case .organizationName:
                    entityType = .concept
                default:
                    return true
                }
                
                entities.append(ExtractedEntity(
                    text: entityText,
                    type: entityType,
                    range: tokenRange,
                    confidence: 0.8
                ))
            }
            return true
        }
        
        // Extract quotes (text between quotation marks)
        let quotePattern = #"["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: quotePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    entities.append(ExtractedEntity(
                        text: String(text[range]),
                        type: .quote,
                        range: range,
                        confidence: 0.9
                    ))
                }
            }
        }
        
        // Extract page numbers
        let pagePattern = #"\b(page|p\.?)\s*(\d+)\b"#
        if let regex = try? NSRegularExpression(pattern: pagePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range, in: text) {
                    entities.append(ExtractedEntity(
                        text: String(text[range]),
                        type: .pageNumber,
                        range: range,
                        confidence: 0.95
                    ))
                }
            }
        }
        
        extractedEntities = entities
        return entities
    }
    
    // MARK: - Sentiment Analysis
    
    func analyzeSentiment(from text: String) async -> SentimentScore {
        var score = SentimentScore()
        
        // Use lexicon-based approach as fallback
        let positiveWords = ["love", "amazing", "beautiful", "wonderful", "excellent", "fantastic", "great"]
        let negativeWords = ["hate", "terrible", "awful", "bad", "horrible", "disgusting", "worst"]
        
        let words = text.lowercased().split(separator: " ")
        let wordCount = Float(words.count)
        
        var positiveCount: Float = 0
        var negativeCount: Float = 0
        
        for word in words {
            if positiveWords.contains(String(word)) {
                positiveCount += 1
            } else if negativeWords.contains(String(word)) {
                negativeCount += 1
            }
        }
        
        // Calculate scores
        score.positive = positiveCount / wordCount
        score.negative = negativeCount / wordCount
        score.neutral = 1.0 - score.positive - score.negative
        
        // Use ML model if available
        if let analyzer = sentimentAnalyzer {
            let prediction = analyzer.predictedLabel(for: text) ?? "neutral"
            
            switch prediction {
            case "positive":
                score.positive = 0.8
                score.neutral = 0.15
                score.negative = 0.05
            case "negative":
                score.negative = 0.8
                score.neutral = 0.15
                score.positive = 0.05
            default:
                score.neutral = 0.7
                score.positive = 0.15
                score.negative = 0.15
            }
        }
        
        sentiment = score
        return score
    }
    
    // MARK: - Helper Methods
    
    private func detectEmotionWords(in text: String) -> Bool {
        let emotionWords = [
            "love", "hate", "amazing", "wonderful", "terrible", "beautiful",
            "confused", "excited", "sad", "happy", "angry", "frustrated",
            "wow", "incredible", "fascinating", "boring", "interesting"
        ]
        
        return emotionWords.contains { text.contains($0) }
    }
    
    private func createIntentClassifierModel() -> URL? {
        // Placeholder for custom intent classifier model
        // In production, this would load a Core ML model trained on reading intents
        return nil
    }
    
    private func createSentimentModel() -> MLModel? {
        // Placeholder for sentiment analysis model
        // Use default NLModel for now
        return nil
    }
    
    // MARK: - Pre-warming
    
    func prewarmModels() async {
        // Pre-warm models with sample inputs
        let samples = [
            "I love this quote about consciousness",
            "What does quantum mechanics mean?",
            "Save this passage about free will"
        ]
        
        for sample in samples {
            _ = try? await classifyIntent(from: sample)
        }
        
        logger.info("Models pre-warmed and ready")
    }
}