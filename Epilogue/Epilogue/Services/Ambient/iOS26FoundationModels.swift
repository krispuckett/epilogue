import Foundation
import NaturalLanguage
import CoreML
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(WritingTools)
import WritingTools
#endif

private let logger = Logger(subsystem: "com.epilogue", category: "iOS26FoundationModels")

// MARK: - iOS 26 Foundation Models Integration
@available(iOS 26.0, *)
public class iOS26FoundationModels {
    static let shared = iOS26FoundationModels()
    
    // Writing Tools integration for enhanced text processing
    #if canImport(WritingTools)
    private let writingAssistant = WritingAssistant()
    #endif
    
    // Enhanced NL models
    private var sentimentAnalyzer: NLModel?
    private var entityRecognizer: NLModel?
    private var intentClassifier: NLModel?
    
    // On-device ML models
    private var contextualUnderstanding: MLModel?
    private var semanticSearch: MLModel?
    
    private init() {
        loadModels()
    }
    
    // MARK: - Model Loading
    private func loadModels() {
        // Load enhanced sentiment analysis
        if let sentimentURL = Bundle.main.url(forResource: "EnhancedSentiment", withExtension: "mlmodelc") {
            sentimentAnalyzer = try? NLModel(contentsOf: sentimentURL)
            logger.info("✅ Loaded enhanced sentiment model")
        }
        
        // Load entity recognition
        if let entityURL = Bundle.main.url(forResource: "EntityRecognition", withExtension: "mlmodelc") {
            entityRecognizer = try? NLModel(contentsOf: entityURL)
            logger.info("✅ Loaded entity recognition model")
        }
        
        // Load intent classifier
        if let intentURL = Bundle.main.url(forResource: "IntentClassifier", withExtension: "mlmodelc") {
            intentClassifier = try? NLModel(contentsOf: intentURL)
            logger.info("✅ Loaded intent classifier model")
        }
        
        // Load contextual understanding model
        if let contextURL = Bundle.main.url(forResource: "ContextualUnderstanding", withExtension: "mlmodelc") {
            contextualUnderstanding = try? MLModel(contentsOf: contextURL)
            logger.info("✅ Loaded contextual understanding model")
        }
    }
    
    // MARK: - Writing Tools Integration
    public func enhanceText(_ text: String, style: TextStyle = .natural) async -> String {
        #if canImport(WritingTools)
        do {
            let enhanced = try await writingAssistant.enhance(
                text: text,
                style: style.writingToolsStyle,
                context: .reading
            )
            logger.info("📝 Enhanced text with Writing Tools")
            return enhanced
        } catch {
            logger.error("Failed to enhance text: \(error)")
            return text
        }
        #else
        return text
        #endif
    }
    
    public func extractKeyPoints(_ text: String) async -> [String] {
        #if canImport(WritingTools)
        do {
            let points = try await writingAssistant.extractKeyPoints(
                from: text,
                maxPoints: 5
            )
            logger.info("🔑 Extracted \(points.count) key points")
            return points
        } catch {
            logger.error("Failed to extract key points: \(error)")
            return []
        }
        #else
        // Fallback implementation
        return extractKeyPointsFallback(text)
        #endif
    }
    
    public func summarize(_ text: String, length: SummaryLength = .medium) async -> String {
        #if canImport(WritingTools)
        do {
            let summary = try await writingAssistant.summarize(
                text: text,
                length: length.writingToolsLength
            )
            logger.info("📄 Generated summary")
            return summary
        } catch {
            logger.error("Failed to summarize: \(error)")
            return text
        }
        #else
        return text
        #endif
    }
    
    // MARK: - Enhanced Natural Language Processing
    public func analyzeIntent(_ text: String) -> IntentAnalysis {
        guard let classifier = intentClassifier else {
            return IntentAnalysis(
                primaryIntent: .unknown,
                confidence: 0,
                subIntents: []
            )
        }
        
        // Use enhanced ML model for intent classification
        let prediction = classifier.predictedLabel(for: text)
        let probabilities = classifier.predictedLabelHypotheses(for: text, maximumCount: 3)
        
        return IntentAnalysis(
            primaryIntent: mapPredictionToIntent(prediction ?? "unknown"),
            confidence: probabilities.first?.value ?? 0,
            subIntents: probabilities.dropFirst().map { 
                (mapPredictionToIntent($0.key), $0.value) 
            }
        )
    }
    
    public func extractEntities(_ text: String) -> [FoundationEntity] {
        var entities: [FoundationEntity] = []
        
        // Use enhanced NL tagger with iOS 26 improvements
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .language, .script])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        // Extract named entities
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                let entityText = String(text[tokenRange])
                entities.append(FoundationEntity(
                    text: entityText,
                    type: mapTagToEntityType(tag),
                    range: tokenRange,
                    confidence: 0.95
                ))
            }
            return true
        }
        
        // Use custom entity recognizer if available
        if let recognizer = entityRecognizer {
            let customEntities = extractCustomEntities(text, with: recognizer)
            entities.append(contentsOf: customEntities)
        }
        
        return entities
    }
    
    public func analyzeSentiment(_ text: String) -> SentimentAnalysis {
        // Use enhanced sentiment analyzer
        if let analyzer = sentimentAnalyzer {
            let prediction = analyzer.predictedLabel(for: text) ?? "neutral"
            let scores = analyzer.predictedLabelHypotheses(for: text, maximumCount: 3)
            
            return SentimentAnalysis(
                sentiment: mapPredictionToSentiment(prediction),
                positiveScore: Float(scores["positive"] ?? 0),
                negativeScore: Float(scores["negative"] ?? 0),
                neutralScore: Float(scores["neutral"] ?? 0)
            )
        }
        
        // Fallback to built-in NL sentiment
        return analyzeSentimentFallback(text)
    }
    
    // MARK: - Contextual Understanding
    public func understandContext(_ text: String, history: [String]) -> ContextualInsight {
        guard let model = contextualUnderstanding else {
            return ContextualInsight(
                topic: "Unknown",
                relevantHistory: [],
                suggestedFollowUp: nil
            )
        }
        
        // Prepare input for contextual model
        let input = prepareContextualInput(text: text, history: history)
        
        do {
            let prediction = try model.prediction(from: input)
            return parseContextualOutput(prediction)
        } catch {
            logger.error("Contextual understanding failed: \(error)")
            return ContextualInsight(
                topic: extractTopicFallback(text),
                relevantHistory: findRelevantHistory(text, in: history),
                suggestedFollowUp: nil
            )
        }
    }
    
    // MARK: - Semantic Search
    public func findSimilar(_ query: String, in corpus: [String]) -> [(String, Float)] {
        guard let model = semanticSearch else {
            // Fallback to simple text similarity
            return findSimilarFallback(query, in: corpus)
        }
        
        do {
            // Generate embeddings for query and corpus
            let queryEmbedding = try generateEmbedding(query, with: model)
            let corpusEmbeddings = try corpus.map { try generateEmbedding($0, with: model) }
            
            // Calculate cosine similarity
            let similarities = corpusEmbeddings.enumerated().map { index, embedding in
                (corpus[index], cosineSimilarity(queryEmbedding, embedding))
            }
            
            // Sort by similarity and return top results
            return similarities.sorted { $0.1 > $1.1 }.prefix(5).map { ($0.0, $0.1) }
        } catch {
            logger.error("Semantic search failed: \(error)")
            return findSimilarFallback(query, in: corpus)
        }
    }
    
    // MARK: - Helper Methods
    private func mapPredictionToIntent(_ prediction: String) -> IntentType {
        switch prediction.lowercased() {
        case "question": return .question
        case "quote": return .quote
        case "note": return .note
        case "thought": return .thought
        case "reflection": return .reflection
        default: return .unknown
        }
    }
    
    private func mapTagToEntityType(_ tag: NLTag) -> FoundationEntityType {
        switch tag {
        case .personalName: return .character
        case .placeName: return .location
        case .organizationName: return .organization
        default: return .other
        }
    }
    
    private func mapPredictionToSentiment(_ prediction: String) -> Sentiment {
        switch prediction.lowercased() {
        case "positive": return .positive
        case "negative": return .negative
        case "mixed": return .mixed
        default: return .neutral
        }
    }
    
    private func extractCustomEntities(_ text: String, with model: NLModel) -> [FoundationEntity] {
        // Implementation for custom entity extraction
        var entities: [FoundationEntity] = []
        
        // Split text into tokens and classify each
        let tokens = text.split(separator: " ")
        for token in tokens {
            let tokenString = String(token)
            if let entityType = model.predictedLabel(for: tokenString),
               entityType != "O" { // Not "Other"
                entities.append(FoundationEntity(
                    text: tokenString,
                    type: .custom(entityType),
                    range: text.range(of: tokenString)!,
                    confidence: 0.85
                ))
            }
        }
        
        return entities
    }
    
    private func prepareContextualInput(text: String, history: [String]) -> MLFeatureProvider {
        // Prepare input features for contextual understanding model
        // This would be model-specific
        do {
            return try MLDictionaryFeatureProvider(dictionary: [
                "current_text": text,
                "history": history.joined(separator: " [SEP] ")
            ])
        } catch {
            // Return empty provider on error - this should be safe
            do {
                return try MLDictionaryFeatureProvider(dictionary: [:])
            } catch {
                // Log error and return nil or handle differently based on your needs
                os_log("Failed to create MLDictionaryFeatureProvider: %@", log: .default, type: .error, error.localizedDescription)
                // Create a minimal valid provider as fallback
                return MLDictionaryFeatureProvider()
            }
        }
    }
    
    private func parseContextualOutput(_ output: MLFeatureProvider) -> ContextualInsight {
        // Parse model output to contextual insight
        // This would be model-specific
        return ContextualInsight(
            topic: output.featureValue(for: "topic")?.stringValue ?? "Unknown",
            relevantHistory: [],
            suggestedFollowUp: output.featureValue(for: "followup")?.stringValue
        )
    }
    
    private func generateEmbedding(_ text: String, with model: MLModel) throws -> [Float] {
        // Generate text embeddings using the model
        let input = try MLDictionaryFeatureProvider(dictionary: ["text": text])
        let output = try model.prediction(from: input)
        
        if let embedding = output.featureValue(for: "embedding")?.multiArrayValue {
            return Array(UnsafeBufferPointer(start: embedding.dataPointer.assumingMemoryBound(to: Float.self),
                                            count: embedding.count))
        }
        
        return []
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    // MARK: - Fallback Methods
    private func extractKeyPointsFallback(_ text: String) -> [String] {
        // Simple sentence extraction as fallback
        let sentences = text.split(separator: ".")
        return Array(sentences.prefix(3).map { String($0).trimmingCharacters(in: .whitespaces) })
    }
    
    private func analyzeSentimentFallback(_ text: String) -> SentimentAnalysis {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        var score: Double = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag,
               let sentimentScore = Double(tag.rawValue) {
                score = sentimentScore
            }
            return true
        }
        
        return SentimentAnalysis(
            sentiment: score > 0 ? .positive : score < 0 ? .negative : .neutral,
            positiveScore: Float(max(0, score)),
            negativeScore: Float(abs(min(0, score))),
            neutralScore: Float(score == 0 ? 1 : 0)
        )
    }
    
    private func extractTopicFallback(_ text: String) -> String {
        // Extract most common noun as topic
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var nouns: [String: Int] = [:]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if tag == .noun {
                let noun = String(text[tokenRange])
                nouns[noun, default: 0] += 1
            }
            return true
        }
        
        return nouns.max { $0.value < $1.value }?.key ?? "General"
    }
    
    private func findRelevantHistory(_ text: String, in history: [String]) -> [String] {
        // Simple keyword matching for relevant history
        let keywords = text.split(separator: " ").map { String($0).lowercased() }
        return history.filter { item in
            keywords.contains { keyword in
                item.lowercased().contains(keyword)
            }
        }.prefix(3).map { String($0) }
    }
    
    private func findSimilarFallback(_ query: String, in corpus: [String]) -> [(String, Float)] {
        // Simple word overlap similarity
        let queryWords = Set(query.lowercased().split(separator: " ").map { String($0) })
        
        let similarities = corpus.map { text -> (String, Float) in
            let textWords = Set(text.lowercased().split(separator: " ").map { String($0) })
            let intersection = queryWords.intersection(textWords)
            let union = queryWords.union(textWords)
            let similarity = union.isEmpty ? 0 : Float(intersection.count) / Float(union.count)
            return (text, similarity)
        }
        
        return similarities.sorted { $0.1 > $1.1 }.prefix(5).map { ($0.0, $0.1) }
    }
}

// MARK: - Supporting Types
public enum TextStyle {
    case natural
    case concise
    case professional
    case creative
    
    #if canImport(WritingTools)
    var writingToolsStyle: WritingTools.Style {
        switch self {
        case .natural: return .natural
        case .concise: return .concise
        case .professional: return .professional
        case .creative: return .creative
        }
    }
    #endif
}

public enum SummaryLength {
    case brief
    case medium
    case detailed
    
    #if canImport(WritingTools)
    var writingToolsLength: WritingTools.SummaryLength {
        switch self {
        case .brief: return .brief
        case .medium: return .medium
        case .detailed: return .detailed
        }
    }
    #endif
}

public struct IntentAnalysis {
    public let primaryIntent: IntentType
    public let confidence: Double
    public let subIntents: [(IntentType, Double)]
}

public enum IntentType {
    case question
    case quote
    case note
    case thought
    case reflection
    case unknown
}

public struct FoundationEntity {
    public let text: String
    public let type: FoundationEntityType
    public let range: Range<String.Index>
    public let confidence: Float
}

public enum FoundationEntityType {
    case character
    case location
    case organization
    case custom(String)
    case other
}

public struct SentimentAnalysis {
    public let sentiment: Sentiment
    public let positiveScore: Float
    public let negativeScore: Float
    public let neutralScore: Float
}

public enum Sentiment {
    case positive
    case negative
    case neutral
    case mixed
}

public struct ContextualInsight {
    public let topic: String
    public let relevantHistory: [String]
    public let suggestedFollowUp: String?
}

// MARK: - iOS 26 Availability Wrapper
public class FoundationModelsManager {
    public static let shared = FoundationModelsManager()
    
    private var ios26Models: Any?
    
    private init() {
        if #available(iOS 26.0, *) {
            ios26Models = iOS26FoundationModels.shared
        }
    }
    
    public func enhanceText(_ text: String) async -> String {
        if #available(iOS 26.0, *),
           let models = ios26Models as? iOS26FoundationModels {
            return await models.enhanceText(text)
        }
        return text
    }
    
    public func extractKeyPoints(_ text: String) async -> [String] {
        if #available(iOS 26.0, *),
           let models = ios26Models as? iOS26FoundationModels {
            return await models.extractKeyPoints(text)
        }
        return []
    }
    
    public func summarize(_ text: String) async -> String {
        if #available(iOS 26.0, *),
           let models = ios26Models as? iOS26FoundationModels {
            return await models.summarize(text)
        }
        return text
    }
    
    public func isAvailable() -> Bool {
        if #available(iOS 26.0, *) {
            return ios26Models != nil
        }
        return false
    }
}