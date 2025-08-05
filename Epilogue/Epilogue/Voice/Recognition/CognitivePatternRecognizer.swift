import Foundation
import OSLog
import Combine

private let logger = Logger(subsystem: "com.epilogue", category: "CognitivePatterns")

// MARK: - Cognitive Pattern Types
enum CognitivePattern: String, CaseIterable {
    case quoting = "Quoting"
    case reflecting = "Reflecting"
    case questioning = "Questioning"
    case connecting = "Connecting"
    case analyzing = "Analyzing"
    case synthesizing = "Synthesizing"
    case evaluating = "Evaluating"
    case creating = "Creating"
    
    var color: String {
        switch self {
        case .quoting: return "#FFD700"
        case .reflecting: return "#87CEEB"
        case .questioning: return "#FF6B6B"
        case .connecting: return "#98D8C8"
        case .analyzing: return "#9B59B6"
        case .synthesizing: return "#3498DB"
        case .evaluating: return "#E74C3C"
        case .creating: return "#2ECC71"
        }
    }
    
    var indicators: [String] {
        switch self {
        case .quoting:
            return ["quote", "passage", "says", "writes", "wrote", "according to", "states", "mentions", "the author", "in the book", "reading"]
        case .reflecting:
            return ["I think", "I feel", "reminds me", "makes me think", "I wonder if", "perhaps", "maybe", "it seems", "I believe", "in my opinion"]
        case .questioning:
            return ["why", "how", "what", "when", "where", "who", "I wonder", "I'm curious", "does this mean", "could it be", "is it possible"]
        case .connecting:
            return ["similar to", "like", "reminds me of", "connects to", "relates to", "just like", "in contrast", "unlike", "whereas", "however"]
        case .analyzing:
            return ["because", "therefore", "thus", "hence", "as a result", "this shows", "this suggests", "implies", "indicates", "reveals"]
        case .synthesizing:
            return ["overall", "in summary", "brings together", "combines", "integrates", "the main idea", "essentially", "fundamentally", "at its core"]
        case .evaluating:
            return ["good", "bad", "effective", "ineffective", "strong", "weak", "agree", "disagree", "right", "wrong", "better", "worse"]
        case .creating:
            return ["what if", "imagine", "suppose", "let's say", "picture this", "envision", "could create", "might develop", "would design"]
        }
    }
}

// MARK: - Pattern Match Result
struct PatternMatch: Equatable {
    let pattern: CognitivePattern
    let confidence: Float
    let matchedIndicators: [String]
    let context: String
}

// MARK: - Session Analysis Result
struct SessionCognitiveAnalysis {
    let matches: [PatternMatch]
    let patternCounts: [CognitivePattern: Int]
    let dominantPattern: CognitivePattern?
    let cognitiveDiversity: Float
    let totalSegments: Int
    
    var summary: String {
        guard !matches.isEmpty else {
            return "No clear cognitive patterns detected."
        }
        
        var summary = "Cognitive patterns detected: "
        
        if let dominant = dominantPattern {
            summary += "Primarily \(dominant.rawValue.lowercased()) "
        }
        
        let patternList = patternCounts.sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key.rawValue) (\($0.value))" }
            .joined(separator: ", ")
        
        summary += "[\(patternList)]. "
        summary += "Cognitive diversity: \(Int(cognitiveDiversity * 100))%"
        
        return summary
    }
}

// MARK: - Cognitive Pattern Recognizer  
@MainActor
class CognitivePatternRecognizer: ObservableObject {
    static let shared = CognitivePatternRecognizer()
    
    @Published var currentPatterns: [PatternMatch] = []
    @Published var isAnalyzing = false
    
    private init() {}
    
    // MARK: - Main Recognition Method
    func recognizePatterns(in text: String) -> [PatternMatch] {
        let lowercased = text.lowercased()
        var matches: [PatternMatch] = []
        
        for pattern in CognitivePattern.allCases {
            let matchResult = detectPattern(pattern, in: lowercased, originalText: text)
            if let match = matchResult {
                matches.append(match)
            }
        }
        
        matches.sort { $0.confidence > $1.confidence }
        
        if !matches.isEmpty {
            logger.info("Detected \(matches.count) patterns in text: \(matches.map { $0.pattern.rawValue }.joined(separator: ", "))")
        }
        
        return matches
    }
    
    // MARK: - Pattern Detection
    private func detectPattern(_ pattern: CognitivePattern, in text: String, originalText: String) -> PatternMatch? {
        var matchedIndicators: [String] = []
        var totalScore: Float = 0
        
        for indicator in pattern.indicators {
            if text.contains(indicator) {
                matchedIndicators.append(indicator)
                totalScore += 1.0
            }
        }
        
        switch pattern {
        case .quoting:
            if originalText.contains("\"") || originalText.contains("'") {
                totalScore += 2.0
                matchedIndicators.append("quotation marks")
            }
        case .questioning:
            if originalText.contains("?") {
                totalScore += 2.0
                matchedIndicators.append("question mark")
            }
        case .reflecting:
            let firstPersonPronouns = ["i ", "me ", "my ", "myself"]
            for pronoun in firstPersonPronouns {
                if text.contains(pronoun) {
                    totalScore += 0.5
                }
            }
        case .analyzing:
            let causalConnectors = ["because", "since", "as", "due to", "owing to"]
            for connector in causalConnectors {
                if text.contains(connector) {
                    totalScore += 0.5
                }
            }
        default:
            break
        }
        
        let maxPossibleScore = Float(pattern.indicators.count) + 2.0
        let confidence = min(totalScore / maxPossibleScore, 1.0)
        
        if confidence > 0.15 && !matchedIndicators.isEmpty {
            return PatternMatch(
                pattern: pattern,
                confidence: confidence,
                matchedIndicators: matchedIndicators,
                context: extractContext(from: originalText, pattern: pattern)
            )
        }
        
        return nil
    }
    
    // MARK: - Context Extraction
    private func extractContext(from text: String, pattern: CognitivePattern) -> String {
        let words = text.split(separator: " ")
        
        if words.count <= 10 {
            return text
        }
        
        if pattern == .quoting {
            if let quoteRange = extractQuote(from: text) {
                return String(text[quoteRange])
            }
        }
        
        if pattern == .questioning {
            if let questionRange = extractQuestion(from: text) {
                return String(text[questionRange])
            }
        }
        
        let endIndex = text.index(text.startIndex, offsetBy: min(50, text.count))
        return String(text[text.startIndex..<endIndex]) + "..."
    }
    
    private func extractQuote(from text: String) -> Range<String.Index>? {
        let patterns = [
            ("\"", "\""),
            ("'", "'")
        ]
        
        for (start, end) in patterns {
            if let startRange = text.range(of: start),
               let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) {
                return startRange.lowerBound..<endRange.upperBound
            }
        }
        
        return nil
    }
    
    private func extractQuestion(from text: String) -> Range<String.Index>? {
        if let questionMark = text.firstIndex(of: "?") {
            let punctuation: Set<Character> = [".", "!", "?", "\n"]
            var startIndex = text.startIndex
            
            for (index, _) in text.enumerated().reversed() {
                if index < text.distance(from: text.startIndex, to: questionMark) {
                    let charIndex = text.index(text.startIndex, offsetBy: index)
                    if punctuation.contains(text[charIndex]) {
                        startIndex = text.index(after: charIndex)
                        break
                    }
                }
            }
            
            return startIndex..<text.index(after: questionMark)
        }
        
        return nil
    }
    
    // MARK: - Enhanced Pattern Analysis
    func analyzeSessionPatterns(_ transcriptions: [String]) -> SessionCognitiveAnalysis {
        var allMatches: [PatternMatch] = []
        var patternCounts: [CognitivePattern: Int] = [:]
        
        for transcription in transcriptions {
            let matches = recognizePatterns(in: transcription)
            allMatches.append(contentsOf: matches)
            
            for match in matches {
                patternCounts[match.pattern, default: 0] += 1
            }
        }
        
        let dominantPattern = patternCounts.max { $0.value < $1.value }?.key
        let uniquePatterns = Set(allMatches.map { $0.pattern })
        let diversity = Float(uniquePatterns.count) / Float(CognitivePattern.allCases.count)
        
        return SessionCognitiveAnalysis(
            matches: allMatches,
            patternCounts: patternCounts,
            dominantPattern: dominantPattern,
            cognitiveDiversity: diversity,
            totalSegments: transcriptions.count
        )
    }
    
    func streamPatternRecognition(for text: String, completion: @escaping (PatternMatch) -> Void) {
        let sentences = text.split(whereSeparator: { ".?!".contains($0) })
        
        for (index, sentence) in sentences.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                let matches = self.recognizePatterns(in: String(sentence))
                if let bestMatch = matches.first {
                    completion(bestMatch)
                }
            }
        }
    }
}
