import Foundation
import OSLog

// Ultra-fast query router with parallel processing
@MainActor
class IntelligentQueryRouter {
    static let shared = IntelligentQueryRouter()
    private let logger = Logger(subsystem: "com.epilogue", category: "QueryRouter")
    
    enum QueryType {
        case bookContent      // 0.6ms local
        case currentEvents    // Needs Perplexity
        case hybrid          // Both needed
    }
    
    private init() {}
    
    // Analyze query in <1ms
    func analyzeQuery(_ query: String, bookContext: Book?) -> QueryType {
        let startTime = CFAbsoluteTimeGetCurrent()
        let queryLower = query.lowercased()
        
        // ULTRA-FAST: Check common book questions first (most frequent)
        let bookIndicators = [
            "character", "plot", "chapter", "ending", "theme",
            "what happens", "who is", "why did", "explain",
            "tell me about", "describe", "significance", "meaning",
            "symbolism", "quote", "passage", "scene",
            "gandalf", "frodo", "aragorn", "odysseus" // Common character names
        ]
        
        for indicator in bookIndicators {
            if queryLower.contains(indicator) {
                let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                logger.info("📚 Book content query detected in \(String(format: "%.2f", analysisTime))ms")
                return .bookContent
            }
        }
        
        // Check for current events/web needs
        let webIndicators = [
            "latest", "2024", "2025", "news", "current",
            "author interview", "movie adaptation", "reviews",
            "recently", "today", "this year", "update",
            "real world", "actually", "in reality"
        ]
        
        for indicator in webIndicators {
            if queryLower.contains(indicator) {
                let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                logger.info("🌐 Current events query detected in \(String(format: "%.2f", analysisTime))ms")
                return .currentEvents
            }
        }
        
        // Complex queries need both
        if queryLower.contains("compare") || queryLower.contains("vs") || 
           queryLower.contains("difference between") || queryLower.contains("similar to") {
            let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("🔀 Hybrid query detected in \(String(format: "%.2f", analysisTime))ms")
            return .hybrid
        }
        
        // Default to local for speed when book context exists
        let defaultType = bookContext != nil ? QueryType.bookContent : QueryType.currentEvents
        let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("⚡ Default to \(defaultType) in \(String(format: "%.2f", analysisTime))ms")
        return defaultType
    }
    
    // Process with parallel execution for complex queries
    func processWithParallelism(_ query: String, bookContext: Book?) async -> String {
        let queryType = analyzeQuery(query, bookContext: bookContext)
        
        switch queryType {
        case .bookContent:
            // Instant local response using SmartEpilogueAI
            logger.info("🏃 Using local AI for instant response")
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Set book context for SmartEpilogueAI
            if let book = bookContext {
                SmartEpilogueAI.shared.setActiveBook(book.toBookModel())
            }
            
            let response = await SmartEpilogueAI.shared.smartQuery(query)
            let responseTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("⚡ Local response in \(String(format: "%.1f", responseTime))ms")
            return response
            
        case .currentEvents:
            // Direct to Perplexity for web knowledge
            logger.info("🌐 Using Perplexity for current events")
            
            do {
                let service = PerplexityService()
                let response = try await service.chat(message: query, bookContext: bookContext)
                return response
            } catch {
                logger.error("❌ Perplexity failed: \(error)")
                return "I need current information to answer this question. Please ensure your Perplexity API key is configured."
            }
            
        case .hybrid:
            // Parallel processing for best of both worlds
            logger.info("🔀 Parallel processing with local + web")
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Set book context
            if let book = bookContext {
                SmartEpilogueAI.shared.setActiveBook(book.toBookModel())
            }
            
            // Execute in parallel
            async let localResult = SmartEpilogueAI.shared.smartQuery(query)
            async let webResult = fetchWebResult(query, bookContext: bookContext)
            
            let (local, web) = await (localResult, webResult)
            
            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("✨ Hybrid response ready in \(String(format: "%.1f", totalTime))ms")
            
            // Combine intelligently
            return synthesizeResponses(local: local, web: web, query: query)
        }
    }
    
    private func fetchWebResult(_ query: String, bookContext: Book?) async -> String? {
        do {
            let service = PerplexityService()
            return try await service.chat(message: query, bookContext: bookContext)
        } catch {
            logger.error("❌ Web fetch failed: \(error)")
            return nil
        }
    }
    
    private func synthesizeResponses(local: String, web: String?, query: String) -> String {
        // If we have both responses, combine them intelligently
        if let webResponse = web, !webResponse.isEmpty {
            // Check if responses are substantially different
            if !local.lowercased().contains(webResponse.prefix(50).lowercased()) {
                // They provide different perspectives - combine them
                return """
                \(local)
                
                \(webResponse)
                """
            } else {
                // Similar content - prefer the more detailed one
                return local.count > webResponse.count ? local : webResponse
            }
        }
        
        // Only local response available
        return local
    }
    
    // Quick check if a query needs web access
    func needsWebAccess(_ query: String) -> Bool {
        let queryType = analyzeQuery(query, bookContext: nil)
        return queryType == .currentEvents || queryType == .hybrid
    }
    
    // Preload for common questions
    func preloadCommonQuestions(for book: Book) async {
        let commonQuestions = [
            "What are the main themes?",
            "Who is the main character?",
            "What is the significance of the title?"
        ]
        
        // Preload local AI with book context
        SmartEpilogueAI.shared.setActiveBook(book.toBookModel())
        
        for question in commonQuestions {
            _ = await SmartEpilogueAI.shared.smartQuery(question)
            logger.info("📚 Preloaded: \(question)")
        }
    }
}

// Extension to convert Book to BookModel if needed
extension Book {
    func toBookModel() -> BookModel {
        return BookModel(from: self)
    }
}