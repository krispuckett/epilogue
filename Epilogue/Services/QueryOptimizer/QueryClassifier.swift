import Foundation
import NaturalLanguage

class QueryClassifier {
    
    enum QueryType: String, CaseIterable {
        case factual = "factual"           // Simple fact lookup
        case summary = "summary"           // Book/chapter summaries
        case analysis = "analysis"         // Character/theme analysis
        case comparison = "comparison"     // Comparing elements
        case explanation = "explanation"   // Explaining concepts
        case opinion = "opinion"           // Subjective questions
        case navigation = "navigation"     // Finding specific content
        case metadata = "metadata"         // Book info queries
    }
    
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .language])
    
    // MARK: - Query Classification
    
    func classify(_ query: String) -> QueryOptimizationService.QueryComplexity {
        let queryType = identifyQueryType(query)
        let wordCount = query.split(separator: " ").count
        let hasMultipleClauses = detectMultipleClauses(query)
        let requiresContext = needsBookContext(query)
        
        // Rule-based classification
        switch queryType {
        case .factual, .metadata, .navigation:
            return .simple
            
        case .summary, .explanation:
            if wordCount < 10 && !hasMultipleClauses {
                return .moderate
            }
            return .complex
            
        case .analysis, .comparison, .opinion:
            return wordCount < 15 ? .complex : .analytical
        }
    }
    
    func identifyQueryType(_ query: String) -> QueryType {
        let lowercased = query.lowercased()
        
        // Pattern matching for query types
        let patterns: [(QueryType, [String])] = [
            (.factual, ["what is", "who is", "when did", "where is", "how many"]),
            (.summary, ["summarize", "summary of", "what happens", "give me overview", "brief"]),
            (.analysis, ["analyze", "analysis", "significance", "interpret", "deeper meaning"]),
            (.comparison, ["compare", "difference between", "similar to", "versus", "vs"]),
            (.explanation, ["explain", "why does", "how does", "what does", "meaning of"]),
            (.opinion, ["think about", "opinion", "best", "favorite", "should", "would you"]),
            (.navigation, ["find", "locate", "where in", "which chapter", "page"]),
            (.metadata, ["author", "published", "genre", "isbn", "rating"])
        ]
        
        for (type, keywords) in patterns {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    return type
                }
            }
        }
        
        // Use NLP for more sophisticated classification
        return classifyWithNLP(query)
    }
    
    private func classifyWithNLP(_ query: String) -> QueryType {
        tagger.string = query
        
        var nounCount = 0
        var verbCount = 0
        var adjectiveCount = 0
        var questionWords = 0
        
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if let tag = tag {
                switch tag {
                case .noun, .pronoun:
                    nounCount += 1
                case .verb:
                    verbCount += 1
                case .adjective:
                    adjectiveCount += 1
                case .adverb, .determiner:
                    let word = String(query[range]).lowercased()
                    if ["what", "when", "where", "why", "how", "who"].contains(word) {
                        questionWords += 1
                    }
                default:
                    break
                }
            }
            return true
        }
        
        // Heuristics based on POS tags
        if questionWords > 0 && nounCount > verbCount {
            return .factual
        } else if verbCount > nounCount && adjectiveCount > 1 {
            return .analysis
        } else if adjectiveCount > 2 {
            return .opinion
        }
        
        return .explanation
    }
    
    // MARK: - Complexity Analysis
    
    private func detectMultipleClauses(_ query: String) -> Bool {
        let conjunctions = ["and", "but", "or", "because", "although", "while", "whereas"]
        let lowercased = query.lowercased()
        
        for conjunction in conjunctions {
            if lowercased.contains(" \(conjunction) ") {
                return true
            }
        }
        
        // Check for multiple questions
        let questionMarks = query.filter { $0 == "?" }.count
        return questionMarks > 1
    }
    
    private func needsBookContext(_ query: String) -> Bool {
        let contextIndicators = [
            "this", "that", "these", "those",
            "chapter", "page", "section", "part",
            "character", "protagonist", "antagonist",
            "theme", "plot", "story"
        ]
        
        let lowercased = query.lowercased()
        return contextIndicators.contains { lowercased.contains($0) }
    }
    
    // MARK: - Query Optimization Hints
    
    func getOptimizationHints(for query: String) -> QueryOptimizationHints {
        let type = identifyQueryType(query)
        let complexity = classify(query)
        
        var hints = QueryOptimizationHints()
        
        switch type {
        case .factual, .metadata:
            hints.canUseCache = true
            hints.maxContextTokens = 500
            hints.requiresFullBook = false
            
        case .summary:
            hints.canUseCache = true
            hints.maxContextTokens = 2000
            hints.requiresFullBook = false
            hints.progressiveLoadingEnabled = true
            
        case .analysis, .comparison:
            hints.canUseCache = false
            hints.maxContextTokens = 4000
            hints.requiresFullBook = true
            hints.progressiveLoadingEnabled = true
            
        case .explanation:
            hints.canUseCache = true
            hints.maxContextTokens = 1500
            hints.requiresFullBook = false
            
        case .opinion:
            hints.canUseCache = false
            hints.maxContextTokens = 3000
            hints.requiresFullBook = false
            
        case .navigation:
            hints.canUseCache = true
            hints.maxContextTokens = 500
            hints.requiresFullBook = false
            hints.useSemanticSearch = true
        }
        
        hints.estimatedResponseTime = estimateResponseTime(complexity: complexity)
        hints.suggestedCacheExpiry = getSuggestedCacheExpiry(type: type)
        
        return hints
    }
    
    private func estimateResponseTime(complexity: QueryOptimizationService.QueryComplexity) -> TimeInterval {
        switch complexity {
        case .simple:
            return 0.5
        case .moderate:
            return 2.0
        case .complex:
            return 5.0
        case .analytical:
            return 10.0
        }
    }
    
    private func getSuggestedCacheExpiry(type: QueryType) -> TimeInterval {
        switch type {
        case .factual, .metadata:
            return 30 * 24 * 60 * 60 // 30 days
        case .summary, .explanation:
            return 7 * 24 * 60 * 60  // 7 days
        case .navigation:
            return 24 * 60 * 60       // 1 day
        case .analysis, .comparison, .opinion:
            return 3 * 24 * 60 * 60   // 3 days
        }
    }
    
    // MARK: - Query Simplification
    
    func simplifyQuery(_ query: String) -> String {
        var simplified = query
        
        // Remove filler words
        let fillers = ["please", "could you", "can you", "would you", "I want to", "I need to", "tell me"]
        for filler in fillers {
            simplified = simplified.replacingOccurrences(
                of: filler,
                with: "",
                options: .caseInsensitive
            )
        }
        
        // Trim whitespace and clean up
        simplified = simplified
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
        
        return simplified
    }
    
    // MARK: - Related Queries Generation
    
    func generateRelatedQueries(for query: String, type: QueryType) -> [String] {
        var related: [String] = []
        
        switch type {
        case .factual:
            related = generateFactualVariations(query)
        case .summary:
            related = generateSummaryVariations(query)
        case .analysis:
            related = generateAnalysisVariations(query)
        default:
            break
        }
        
        return related
    }
    
    private func generateFactualVariations(_ query: String) -> [String] {
        var variations: [String] = []
        
        // Replace question words
        let replacements = [
            "what": ["which", "what kind of"],
            "who": ["which person", "which character"],
            "when": ["at what time", "what year"],
            "where": ["in which place", "what location"]
        ]
        
        for (original, alternatives) in replacements {
            if query.lowercased().contains(original) {
                for alternative in alternatives {
                    let variation = query.replacingOccurrences(
                        of: original,
                        with: alternative,
                        options: .caseInsensitive
                    )
                    variations.append(variation)
                }
            }
        }
        
        return variations
    }
    
    private func generateSummaryVariations(_ query: String) -> [String] {
        return [
            "Give me a brief overview",
            "What are the main points",
            "Summarize the key ideas",
            "What's the gist of this"
        ]
    }
    
    private func generateAnalysisVariations(_ query: String) -> [String] {
        return [
            "What's the deeper meaning",
            "Analyze the significance",
            "Interpret this passage",
            "What does this symbolize"
        ]
    }
}

// MARK: - Supporting Types

struct QueryOptimizationHints {
    var canUseCache: Bool = true
    var maxContextTokens: Int = 2000
    var requiresFullBook: Bool = false
    var progressiveLoadingEnabled: Bool = false
    var useSemanticSearch: Bool = false
    var estimatedResponseTime: TimeInterval = 2.0
    var suggestedCacheExpiry: TimeInterval = 86400 // 24 hours
}