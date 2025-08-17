import Foundation
import SwiftUI
import OSLog
import Combine

// MARK: - Response Components
struct SynthesizedResponse {
    var text: String
    var citations: [Citation] = []
    var confidence: Double = 0.0
    var sources: [ResponseSource] = []
    var followUpQuestions: [String] = []
    var keyInsights: [String] = []
    var mediaEmbeds: [MediaEmbed] = []
    var contradictions: [Contradiction] = []
    var enhancementLevel: EnhancementLevel = .basic
    
    enum EnhancementLevel {
        case basic      // Initial response
        case enhanced   // With citations
        case enriched   // With insights and media
        case complete   // Fully synthesized
    }
}

struct ResponseSource {
    let model: String
    let confidence: Double
    let latency: TimeInterval
    let content: String
    let type: SourceType
    
    enum SourceType {
        case foundationModel
        case perplexity
        case cache
    }
}

struct Contradiction {
    let topic: String
    let localResponse: String
    let webResponse: String
    let resolution: String
}

struct MediaEmbed {
    let type: MediaType
    let url: String
    let caption: String?
    
    enum MediaType {
        case image
        case video
        case chart
        case map
    }
}

// MARK: - Response Synthesizer
@MainActor
class ResponseSynthesizer: ObservableObject {
    static let shared = ResponseSynthesizer()
    
    private let logger = Logger(subsystem: "com.epilogue", category: "ResponseSynthesis")
    
    @Published var currentResponse = SynthesizedResponse(text: "")
    @Published var isEnhancing = false
    
    private var enhancementTask: Task<Void, Never>?
    private let contradictionResolver = ContradictionResolver()
    private let insightExtractor = InsightExtractor()
    private let followUpGenerator = FollowUpGenerator()
    
    // Confidence weights for different query types
    private let confidenceWeights = ConfidenceWeights()
    
    private init() {}
    
    // MARK: - Progressive Synthesis
    
    func synthesizeProgressively(
        query: String,
        bookContext: Book?,
        onUpdate: @escaping (SynthesizedResponse) -> Void
    ) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Reset current response
        currentResponse = SynthesizedResponse(text: "")
        isEnhancing = true
        
        // Phase 1: Immediate local response (<100ms)
        await provideImmediateResponse(query: query, bookContext: bookContext, onUpdate: onUpdate)
        
        // Phase 2: Stream enhancements in parallel
        await streamEnhancements(query: query, bookContext: bookContext, onUpdate: onUpdate)
        
        // Phase 3: Final synthesis and enrichment
        await finalizeResponse(query: query, onUpdate: onUpdate)
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("✨ Complete synthesis in \(String(format: "%.1f", totalTime))ms")
        
        isEnhancing = false
    }
    
    // MARK: - Phase 1: Immediate Response
    
    private func provideImmediateResponse(
        query: String,
        bookContext: Book?,
        onUpdate: @escaping (SynthesizedResponse) -> Void
    ) async {
        let localStart = CFAbsoluteTimeGetCurrent()
        
        // Try Foundation Models first for instant response
        if FoundationModelsManager.shared.isAvailable() {
            let localResponse = await FoundationModelsManager.shared.processQuery(query, bookContext: bookContext)
            
            self.currentResponse.text = localResponse
            self.currentResponse.sources.append(ResponseSource(
                model: "Foundation Models 3B",
                confidence: 0.85,
                latency: (CFAbsoluteTimeGetCurrent() - localStart) * 1000,
                content: localResponse,
                type: .foundationModel
            ))
            self.currentResponse.enhancementLevel = .basic
            
            onUpdate(self.currentResponse)
            
            logger.info("⚡ Local response delivered in \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - localStart) * 1000))ms")
        } else {
            // Fallback to Smart AI for quick response
            if let book = bookContext {
                SmartEpilogueAI.shared.setActiveBook(book.toIntelligentBookModel())
            }
            
            let localResponse = await SmartEpilogueAI.shared.smartQuery(query)
            
            self.currentResponse.text = localResponse
            self.currentResponse.sources.append(ResponseSource(
                model: "SmartEpilogue",
                confidence: 0.7,
                latency: (CFAbsoluteTimeGetCurrent() - localStart) * 1000,
                content: localResponse,
                type: .foundationModel
            ))
            self.currentResponse.enhancementLevel = .basic
            
            onUpdate(self.currentResponse)
        }
    }
    
    // MARK: - Phase 2: Stream Enhancements
    
    private func streamEnhancements(
        query: String,
        bookContext: Book?,
        onUpdate: @escaping (SynthesizedResponse) -> Void
    ) async {
        // Determine if we need web enhancements
        let needsWeb = IntelligentQueryRouter.shared.needsWebAccess(query)
        
        if needsWeb {
            logger.info("🌐 Streaming web enhancements...")
            
            do {
                var webContent = ""
                var webCitations: [Citation] = []
                let webStart = CFAbsoluteTimeGetCurrent()
                
                for try await response in OptimizedPerplexityService.shared.streamSonarResponse(query, bookContext: bookContext) {
                    webContent = response.text
                    webCitations = response.citations
                    
                    // Merge web content intelligently
                    let merged = await mergeResponses(
                        local: self.currentResponse.sources.first?.content ?? "",
                        web: webContent,
                        query: query,
                        bookContext: bookContext
                    )
                    
                    self.currentResponse.text = merged.text
                    self.currentResponse.citations = mergeCitations(
                        local: self.currentResponse.citations,
                        web: webCitations
                    )
                    self.currentResponse.confidence = merged.confidence
                    self.currentResponse.enhancementLevel = .enhanced
                    
                    // Add web source
                    if !response.cached {
                        self.currentResponse.sources.append(ResponseSource(
                            model: response.model,
                            confidence: response.confidence,
                            latency: (CFAbsoluteTimeGetCurrent() - webStart) * 1000,
                            content: webContent,
                            type: .perplexity
                        ))
                    }
                    
                    onUpdate(self.currentResponse)
                }
                
                logger.info("✅ Web enhancements complete with \(webCitations.count) citations")
                
            } catch {
                logger.error("❌ Web enhancement failed: \(error)")
            }
        }
        
        // Extract insights in parallel
        Task {
            let insights = await insightExtractor.extract(from: self.currentResponse.text, query: query)
            self.currentResponse.keyInsights = insights
            onUpdate(self.currentResponse)
        }
        
        // Generate follow-up questions
        Task {
            let followUps = await followUpGenerator.generate(
                from: self.currentResponse.text,
                originalQuery: query,
                bookContext: bookContext
            )
            self.currentResponse.followUpQuestions = followUps
            onUpdate(self.currentResponse)
        }
    }
    
    // MARK: - Phase 3: Final Synthesis
    
    private func finalizeResponse(
        query: String,
        onUpdate: @escaping (SynthesizedResponse) -> Void
    ) async {
        // Format the final response beautifully
        self.currentResponse.text = formatResponseWithMarkdown(self.currentResponse)
        
        // Add any media embeds if relevant
        if let embeds = await findRelevantMedia(for: query) {
            self.currentResponse.mediaEmbeds = embeds
        }
        
        self.currentResponse.enhancementLevel = .complete
        onUpdate(self.currentResponse)
        
        logger.info("🎨 Response finalized with \(self.currentResponse.keyInsights.count) insights, \(self.currentResponse.followUpQuestions.count) follow-ups")
    }
    
    // MARK: - Response Merging
    
    private func mergeResponses(
        local: String,
        web: String,
        query: String,
        bookContext: Book?
    ) async -> (text: String, confidence: Double) {
        let queryType = detectQueryType(query)
        
        // Check for contradictions
        let contradictions = await contradictionResolver.findContradictions(
            local: local,
            web: web,
            context: query
        )
        
        if !contradictions.isEmpty {
            self.currentResponse.contradictions = contradictions
            logger.info("⚠️ Found \(contradictions.count) contradictions to resolve")
        }
        
        // Weight responses based on query type
        let localWeight = confidenceWeights.getLocalWeight(for: queryType, hasBook: bookContext != nil)
        let webWeight = confidenceWeights.getWebWeight(for: queryType)
        
        // Intelligent merging based on weights
        if localWeight > webWeight {
            // Local is primary
            if !web.isEmpty && web != local {
                let merged = """
                \(local)
                
                \(web.count > 200 ? "\n**Additional Context:**\n\(web)" : "")
                """
                return (merged, localWeight)
            }
            return (local, localWeight)
            
        } else if webWeight > localWeight {
            // Web is primary
            if !local.isEmpty && local != web {
                let merged = """
                \(web)
                
                \(local.count > 200 ? "\n**Book Analysis:**\n\(local)" : "")
                """
                return (merged, webWeight)
            }
            return (web, webWeight)
            
        } else {
            // Equal weight - synthesize both
            return synthesizeEqualWeightResponses(local: local, web: web)
        }
    }
    
    private func synthesizeEqualWeightResponses(local: String, web: String) -> (text: String, confidence: Double) {
        // Find unique content in each
        let localUnique = findUniqueContent(local, comparedTo: web)
        let webUnique = findUniqueContent(web, comparedTo: local)
        
        var synthesized = ""
        
        // Start with common ground
        if let common = findCommonContent(local, web) {
            synthesized = common
        }
        
        // Add unique perspectives
        if !localUnique.isEmpty {
            synthesized += "\n\n**Literary Analysis:**\n\(localUnique)"
        }
        
        if !webUnique.isEmpty {
            synthesized += "\n\n**Current Context:**\n\(webUnique)"
        }
        
        return (synthesized, 0.75)
    }
    
    // MARK: - Citation Merging
    
    private func mergeCitations(local: [Citation], web: [Citation]) -> [Citation] {
        var merged = local
        
        for webCitation in web {
            // Check for duplicates
            let isDuplicate = merged.contains { citation in
                citation.source == webCitation.source ||
                citation.text == webCitation.text
            }
            
            if !isDuplicate {
                merged.append(webCitation)
            }
        }
        
        // Sort by credibility and position
        return merged.sorted { lhs, rhs in
            if abs(lhs.credibilityScore - rhs.credibilityScore) > 0.1 {
                return lhs.credibilityScore > rhs.credibilityScore
            }
            return lhs.position < rhs.position
        }
    }
    
    // MARK: - Formatting
    
    private func formatResponseWithMarkdown(_ response: SynthesizedResponse) -> String {
        var formatted = response.text
        
        // Add key insights if available
        if !response.keyInsights.isEmpty {
            formatted = "**Key Insights:**\n" +
                response.keyInsights.map { "• \($0)" }.joined(separator: "\n") +
                "\n\n---\n\n" + formatted
        }
        
        // Add citations
        if !response.citations.isEmpty {
            formatted += "\n\n---\n**Sources:**\n"
            for (index, citation) in response.citations.enumerated() {
                let credEmoji = citation.credibilityScore > 0.8 ? "🟢" :
                               citation.credibilityScore > 0.6 ? "🟡" : "🔴"
                formatted += "\n\(index + 1). \(credEmoji) \(citation.source)"
                if let url = citation.url {
                    formatted += " [↗](\(url))"
                }
            }
        }
        
        // Add contradictions if any
        if !response.contradictions.isEmpty {
            formatted += "\n\n---\n**Different Perspectives:**\n"
            for contradiction in response.contradictions {
                formatted += "\n📊 **\(contradiction.topic):**\n"
                formatted += "• Book perspective: \(contradiction.localResponse)\n"
                formatted += "• Current information: \(contradiction.webResponse)\n"
                formatted += "• *\(contradiction.resolution)*\n"
            }
        }
        
        // Add follow-up questions
        if !response.followUpQuestions.isEmpty {
            formatted += "\n\n---\n**You might also ask:**\n"
            for question in response.followUpQuestions.prefix(3) {
                formatted += "• \(question)\n"
            }
        }
        
        return formatted
    }
    
    // MARK: - Helper Methods
    
    private func detectQueryType(_ query: String) -> QueryType {
        let queryLower = query.lowercased()
        
        if queryLower.contains("theme") || queryLower.contains("character") ||
           queryLower.contains("plot") || queryLower.contains("chapter") {
            return .bookContent
        }
        
        if queryLower.contains("author") && queryLower.contains("interview") ||
           queryLower.contains("adaptation") || queryLower.contains("news") {
            return .currentEvents
        }
        
        if queryLower.contains("compare") || queryLower.contains("similar") {
            return .comparison
        }
        
        return .general
    }
    
    private func findUniqueContent(_ text1: String, comparedTo text2: String) -> String {
        let sentences1 = text1.components(separatedBy: ". ")
        let sentences2 = Set(text2.components(separatedBy: ". "))
        
        let unique = sentences1.filter { !sentences2.contains($0) }
        return unique.joined(separator: ". ")
    }
    
    private func findCommonContent(_ text1: String, _ text2: String) -> String? {
        let sentences1 = Set(text1.components(separatedBy: ". "))
        let sentences2 = Set(text2.components(separatedBy: ". "))
        
        let common = sentences1.intersection(sentences2)
        return common.isEmpty ? nil : Array(common).joined(separator: ". ")
    }
    
    private func findRelevantMedia(for query: String) async -> [MediaEmbed]? {
        // This would integrate with media services
        // For now, return nil
        return nil
    }
    
    enum QueryType {
        case bookContent
        case currentEvents
        case comparison
        case general
    }
}

// MARK: - Confidence Weights

private class ConfidenceWeights {
    func getLocalWeight(for queryType: ResponseSynthesizer.QueryType, hasBook: Bool) -> Double {
        switch queryType {
        case .bookContent:
            return hasBook ? 0.9 : 0.5
        case .currentEvents:
            return 0.2
        case .comparison:
            return hasBook ? 0.6 : 0.4
        case .general:
            return 0.5
        }
    }
    
    func getWebWeight(for queryType: ResponseSynthesizer.QueryType) -> Double {
        switch queryType {
        case .bookContent:
            return 0.3
        case .currentEvents:
            return 0.95
        case .comparison:
            return 0.6
        case .general:
            return 0.5
        }
    }
}

// MARK: - Contradiction Resolver

private actor ContradictionResolver {
    private let logger = Logger(subsystem: "com.epilogue", category: "ContradictionResolver")
    
    func findContradictions(local: String, web: String, context: String) async -> [Contradiction] {
        var contradictions: [Contradiction] = []
        
        // Check for date/fact contradictions
        if let dateContradiction = findDateContradiction(local: local, web: web) {
            contradictions.append(dateContradiction)
        }
        
        // Check for number contradictions
        if let numberContradiction = findNumberContradiction(local: local, web: web) {
            contradictions.append(numberContradiction)
        }
        
        return contradictions
    }
    
    private func findDateContradiction(local: String, web: String) -> Contradiction? {
        // Simple date extraction regex
        let datePattern = #"\b(19|20)\d{2}\b"#
        
        let localDates = extractMatches(pattern: datePattern, from: local)
        let webDates = extractMatches(pattern: datePattern, from: web)
        
        if !localDates.isEmpty && !webDates.isEmpty && localDates != webDates {
            return Contradiction(
                topic: "Publication Date",
                localResponse: localDates.first ?? "",
                webResponse: webDates.first ?? "",
                resolution: "The web source provides the most current information"
            )
        }
        
        return nil
    }
    
    private func findNumberContradiction(local: String, web: String) -> Contradiction? {
        // Extract numbers that might be statistics
        let numberPattern = #"\b\d+(?:,\d{3})*(?:\.\d+)?\s*(?:million|billion|thousand)?\b"#
        
        let localNumbers = extractMatches(pattern: numberPattern, from: local)
        let webNumbers = extractMatches(pattern: numberPattern, from: web)
        
        if !localNumbers.isEmpty && !webNumbers.isEmpty && localNumbers != webNumbers {
            return Contradiction(
                topic: "Statistics",
                localResponse: localNumbers.first ?? "",
                webResponse: webNumbers.first ?? "",
                resolution: "Different sources may report varying statistics"
            )
        }
        
        return nil
    }
    
    private func extractMatches(pattern: String, from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}

// MARK: - Insight Extractor

private actor InsightExtractor {
    func extract(from text: String, query: String) async -> [String] {
        var insights: [String] = []
        
        // Extract key themes
        if text.count > 200 {
            // Find sentences with strong indicators
            let sentences = text.components(separatedBy: ". ")
            
            for sentence in sentences {
                if sentence.contains("significance") ||
                   sentence.contains("represents") ||
                   sentence.contains("symbolizes") ||
                   sentence.contains("demonstrates") ||
                   sentence.contains("reveals") {
                    insights.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                
                if insights.count >= 3 { break }
            }
        }
        
        return insights
    }
}

// MARK: - Follow-Up Generator

private actor FollowUpGenerator {
    func generate(from response: String, originalQuery: String, bookContext: Book?) async -> [String] {
        var followUps: [String] = []
        
        // Context-aware follow-ups
        if let book = bookContext {
            if originalQuery.lowercased().contains("character") {
                followUps.append("How does this character evolve throughout \(book.title)?")
                followUps.append("What other characters share similar traits?")
            }
            
            if originalQuery.lowercased().contains("theme") {
                followUps.append("How does \(book.author) develop this theme?")
                followUps.append("What symbols represent this theme in the book?")
            }
            
            if originalQuery.lowercased().contains("ending") {
                followUps.append("What alternative endings could have worked?")
                followUps.append("How does the ending reflect the book's themes?")
            }
        }
        
        // Generic intelligent follow-ups
        if followUps.isEmpty {
            followUps.append("Can you provide more specific examples?")
            followUps.append("How does this compare to similar works?")
            followUps.append("What's the historical context behind this?")
        }
        
        return Array(followUps.prefix(5))
    }
}

// MARK: - Response View Model

@MainActor
class ResponseViewModel: ObservableObject {
    @Published var synthesizedResponse = SynthesizedResponse(text: "")
    @Published var isLoading = false
    @Published var animationPhase: AnimationPhase = .idle
    
    private let synthesizer = ResponseSynthesizer.shared
    
    enum AnimationPhase {
        case idle
        case thinking
        case enhancing
        case complete
    }
    
    func processQuery(_ query: String, bookContext: Book?) async {
        isLoading = true
        animationPhase = .thinking
        
        await synthesizer.synthesizeProgressively(
            query: query,
            bookContext: bookContext
        ) { [weak self] response in
            Task { @MainActor in
                self?.synthesizedResponse = response
                
                // Update animation phase
                switch response.enhancementLevel {
                case .basic:
                    self?.animationPhase = .thinking
                case .enhanced:
                    self?.animationPhase = .enhancing
                case .enriched, .complete:
                    self?.animationPhase = .complete
                }
            }
        }
        
        isLoading = false
    }
}