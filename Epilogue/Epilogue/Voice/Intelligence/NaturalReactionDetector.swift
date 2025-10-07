import Foundation
import NaturalLanguage
import OSLog
import Combine

private let logger = Logger(subsystem: "com.epilogue", category: "NaturalReactionDetector")

// MARK: - Reaction Types
enum ReactionType: String, CaseIterable {
    case excitement = "excitement"
    case wonder = "wonder"
    case confusion = "confusion"
    case discovery = "discovery"
    case connection = "connection"
    case reflection = "reflection"
    case agreement = "agreement"
    case disagreement = "disagreement"
    case surprise = "surprise"
    case understanding = "understanding"
    
    var color: String {
        switch self {
        case .excitement: return "#FFD700" // Gold
        case .wonder: return "#87CEEB" // Sky blue
        case .confusion: return "#DDA0DD" // Plum
        case .discovery: return "#90EE90" // Light green
        case .connection: return "#FF69B4" // Hot pink
        case .reflection: return "#B0C4DE" // Light steel blue
        case .agreement: return "#98FB98" // Pale green
        case .disagreement: return "#FFA07A" // Light salmon
        case .surprise: return "#FF1493" // Deep pink
        case .understanding: return "#20B2AA" // Light sea green
        }
    }
    
    var description: String {
        switch self {
        case .excitement: return "Feeling excited about the content"
        case .wonder: return "Curious and wondering"
        case .confusion: return "Confused or uncertain"
        case .discovery: return "Made a discovery or realization"
        case .connection: return "Making connections to other ideas"
        case .reflection: return "Reflecting on the content"
        case .agreement: return "Agreeing with the content"
        case .disagreement: return "Disagreeing or questioning"
        case .surprise: return "Surprised by the content"
        case .understanding: return "Understanding something new"
        }
    }
}

// MARK: - Detected Reaction
struct DetectedReaction {
    let type: ReactionType
    let confidence: Float
    let utterance: String
    let timestamp: Date
    let sentiment: Float // -1.0 to 1.0
    let context: String? // Previous utterance for context
}

// MARK: - Natural Reaction Detector
@MainActor
class NaturalReactionDetector: ObservableObject {
    @Published var lastDetectedReaction: DetectedReaction?
    @Published var reactionHistory: [DetectedReaction] = []
    @Published var isProcessing = false
    @Published var sensitivityLevel: Float = 0.7 // 0.0 to 1.0
    
    // Pattern definitions for each reaction type
    private let reactionPatterns: [ReactionType: [String]] = [
        .excitement: [
            "oh wow", "wow", "amazing", "incredible", "that's incredible",
            "oh my god", "omg", "holy", "fantastic", "brilliant",
            "that's amazing", "no way", "seriously", "awesome",
            "this is great", "love this", "yes!", "finally"
        ],
        .wonder: [
            "i wonder", "what if", "could this mean", "maybe",
            "perhaps", "possibly", "might be", "curious about",
            "makes me wonder", "wondering if", "what about",
            "how about", "suppose", "imagine if"
        ],
        .confusion: [
            "wait what", "huh", "i don't understand", "confused",
            "doesn't make sense", "what does this mean", "lost me",
            "not sure", "unclear", "wait a minute", "hold on",
            "but why", "how come", "strange", "weird"
        ],
        .discovery: [
            "aha", "oh i see", "i get it", "that explains",
            "now i understand", "makes sense now", "eureka",
            "lightbulb", "click", "got it", "of course",
            "that's why", "so that's how", "realized"
        ],
        .connection: [
            "reminds me of", "just like", "similar to", "relates to",
            "connection to", "links to", "ties to", "same as",
            "recalls", "brings to mind", "parallels", "echoes",
            "mirrors", "corresponds"
        ],
        .reflection: [
            "thinking about", "contemplating", "considering",
            "reflecting on", "pondering", "musing", "mulling over",
            "meditating on", "dwelling on", "thoughts on"
        ],
        .agreement: [
            "exactly", "right", "absolutely", "yes exactly",
            "totally agree", "spot on", "correct", "true",
            "definitely", "indeed", "precisely", "for sure"
        ],
        .disagreement: [
            "not sure about", "disagree", "but actually",
            "however", "on the other hand", "counter", "argue",
            "don't think so", "not really", "doubt", "question"
        ],
        .surprise: [
            "what", "really", "seriously", "no way", "surprised",
            "shocking", "unexpected", "didn't expect", "caught off guard",
            "wow really", "can't believe", "astonishing"
        ],
        .understanding: [
            "i understand", "clear now", "comprehend", "grasp",
            "follow", "see what you mean", "get the picture",
            "making sense", "coming together", "falling into place"
        ]
    ]
    
    // Sentiment analyzer
    private var sentimentPredictor: NLModel? {
        if let modelURL = Bundle.main.url(forResource: "SentimentPolarity", withExtension: "mlmodelc"),
           let mlModel = try? NLModel(contentsOf: modelURL) {
            return mlModel
        }
        return nil
    }
    
    // Context tracking
    private var previousUtterance: String?
    private var conversationContext: [String] = []
    private let maxContextSize = 5
    
    // MARK: - Public Methods
    
    func detectReaction(from utterance: String) async -> DetectedReaction? {
        isProcessing = true
        defer { isProcessing = false }
        
        let lowercasedUtterance = utterance.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip very short utterances
        guard lowercasedUtterance.count > 2 else { return nil }
        
        // Analyze sentiment
        let sentiment = analyzeSentiment(utterance)
        
        // Check each reaction type
        var bestMatch: (type: ReactionType, confidence: Float)? = nil
        
        for (reactionType, patterns) in reactionPatterns {
            let confidence = calculateConfidence(
                utterance: lowercasedUtterance,
                patterns: patterns,
                sentiment: sentiment
            )
            
            if confidence > sensitivityLevel {
                if let currentBest = bestMatch {
                    if confidence > currentBest.confidence {
                        bestMatch = (reactionType, confidence)
                    }
                } else {
                    bestMatch = (reactionType, confidence)
                }
            }
        }
        
        // Use NLP for additional detection if no pattern match
        if bestMatch == nil {
            bestMatch = detectReactionUsingNLP(lowercasedUtterance, sentiment: sentiment)
        }
        
        // Create reaction if detected
        if let match = bestMatch {
            let reaction = DetectedReaction(
                type: match.type,
                confidence: match.confidence,
                utterance: utterance,
                timestamp: Date(),
                sentiment: sentiment,
                context: previousUtterance
            )
            
            // Update state
            lastDetectedReaction = reaction
            reactionHistory.append(reaction)
            
            // Maintain history size
            if reactionHistory.count > 100 {
                reactionHistory.removeFirst()
            }
            
            // Update context
            updateContext(utterance)
            
            logger.info("Detected reaction: \(match.type.rawValue) with confidence: \(match.confidence)")
            
            return reaction
        }
        
        // Update context even if no reaction detected
        updateContext(utterance)
        
        return nil
    }
    
    func adjustSensitivity(for genre: String) {
        // Adjust sensitivity based on content genre
        switch genre.lowercased() {
        case "philosophy", "science", "academic":
            sensitivityLevel = 0.8 // Higher threshold for academic content
        case "fiction", "novel", "story":
            sensitivityLevel = 0.6 // Lower threshold for narrative content
        case "poetry", "creative":
            sensitivityLevel = 0.5 // Very sensitive for creative content
        default:
            sensitivityLevel = 0.7 // Default
        }
        
        logger.info("Adjusted sensitivity to \(self.sensitivityLevel) for genre: \(genre)")
    }
    
    func getReactionTrends() -> [ReactionType: Int] {
        var trends: [ReactionType: Int] = [:]
        
        for reaction in reactionHistory {
            trends[reaction.type, default: 0] += 1
        }
        
        return trends
    }
    
    func clearHistory() {
        reactionHistory.removeAll()
        conversationContext.removeAll()
        previousUtterance = nil
    }
    
    // MARK: - Private Methods
    
    private func calculateConfidence(
        utterance: String,
        patterns: [String],
        sentiment: Float
    ) -> Float {
        var confidence: Float = 0.0
        
        // Check for pattern matches
        for pattern in patterns {
            if utterance.contains(pattern) {
                // Base confidence from pattern match
                confidence = 0.8
                
                // Boost confidence if pattern is at the beginning
                if utterance.hasPrefix(pattern) {
                    confidence += 0.1
                }
                
                // Adjust based on sentiment alignment
                confidence += sentiment * 0.1
                
                break
            }
        }
        
        // Check for partial matches
        if confidence == 0 {
            for pattern in patterns {
                let words = pattern.split(separator: " ")
                var matchCount = 0
                
                for word in words {
                    if utterance.contains(String(word)) {
                        matchCount += 1
                    }
                }
                
                if matchCount > 0 {
                    confidence = Float(matchCount) / Float(words.count) * 0.6
                    break
                }
            }
        }
        
        return min(confidence, 1.0)
    }
    
    private func detectReactionUsingNLP(
        _ utterance: String,
        sentiment: Float
    ) -> (type: ReactionType, confidence: Float)? {
        // Use linguistic features for detection
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = utterance
        
        var hasQuestion = false
        let hasExclamation = utterance.contains("!") || utterance.contains("?!")
        var hasInterjection = false
        
        tagger.enumerateTags(
            in: utterance.startIndex..<utterance.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, range in
            if tag == .interjection {
                hasInterjection = true
            }
            if utterance[range] == "?" {
                hasQuestion = true
            }
            return true
        }
        
        // Heuristic-based detection
        if hasInterjection && sentiment > 0.5 {
            return (.excitement, 0.65)
        } else if hasQuestion && sentiment < -0.2 {
            return (.confusion, 0.6)
        } else if hasQuestion && sentiment > 0.1 {
            return (.wonder, 0.6)
        } else if hasExclamation && sentiment > 0.3 {
            return (.surprise, 0.65)
        }
        
        return nil
    }
    
    private func analyzeSentiment(_ text: String) -> Float {
        guard let sentimentPredictor = sentimentPredictor else { return 0.0 }
        
        let sentiment = sentimentPredictor.predictedLabel(for: text) ?? "neutral"
        
        switch sentiment {
        case "positive":
            return 0.7
        case "negative":
            return -0.7
        default:
            return 0.0
        }
    }
    
    private func updateContext(_ utterance: String) {
        previousUtterance = utterance
        conversationContext.append(utterance)
        
        if conversationContext.count > maxContextSize {
            conversationContext.removeFirst()
        }
    }
}

