import Foundation
import OSLog

// MARK: - Perplexity Integration Bridge
// Bridges OptimizedPerplexityService with existing components

extension IntelligentQueryRouter {
    
    // Enhanced processing with optimized Perplexity streaming
    func processWithOptimizedStreaming(_ query: String, bookContext: Book?) async -> String {
        let queryType = analyzeQuery(query, bookContext: bookContext)
        
        switch queryType {
        case .bookContent:
            // Use local AI for book-specific content
            logger.info("📚 Using local AI for book content")
            
            if let book = bookContext {
                SmartEpilogueAI.shared.setActiveBook(book.toBookModel())
            }
            
            // Check if Foundation Models are available for enhanced local processing
            if FoundationModelsManager.shared.isAvailable() {
                return await FoundationModelsManager.shared.processQuery(query, bookContext: bookContext)
            } else {
                return await SmartEpilogueAI.shared.smartQuery(query)
            }
            
        case .currentEvents, .hybrid:
            // Use optimized Perplexity with streaming and citations
            logger.info("🌐 Using Optimized Perplexity with citations")
            
            var fullResponse = ""
            var citations: [Citation] = []
            
            do {
                for try await response in OptimizedPerplexityService.shared.streamSonarResponse(query, bookContext: bookContext) {
                    fullResponse = response.text
                    citations = response.citations
                    
                    // Log performance metrics
                    if response.cached {
                        logger.info("💨 Served from cache with \(citations.count) citations")
                    } else {
                        logger.info("📊 Confidence: \(String(format: "%.2f", response.confidence)), Citations: \(citations.count)")
                    }
                }
                
                // Format response with citations if available
                if !citations.isEmpty {
                    return formatResponseWithCitations(text: fullResponse, citations: citations)
                }
                
                return fullResponse
                
            } catch {
                logger.error("❌ Optimized streaming failed: \(error)")
                // Fallback to standard processing
                return await processWithParallelism(query, bookContext: bookContext)
            }
        }
    }
    
    private func formatResponseWithCitations(text: String, citations: [Citation]) -> String {
        var formattedText = text
        
        // Add citation markers
        for (index, citation) in citations.enumerated() {
            let marker = "[\(index + 1)]"
            
            // Find and mark citation position
            if let range = formattedText.range(of: citation.text) {
                formattedText.replaceSubrange(range, with: "\(citation.text)\(marker)")
            }
        }
        
        // Add citation list at the end
        if !citations.isEmpty {
            formattedText += "\n\n---\nSources:\n"
            for (index, citation) in citations.enumerated() {
                let credibilityEmoji = citation.credibilityScore > 0.8 ? "✅" : 
                                       citation.credibilityScore > 0.6 ? "⚠️" : "❓"
                formattedText += "\n[\(index + 1)] \(credibilityEmoji) \(citation.source)"
                if let url = citation.url {
                    formattedText += " - \(url)"
                }
            }
        }
        
        return formattedText
    }
}

// MARK: - TrueAmbientProcessor Extension

extension TrueAmbientProcessor {
    
    // Enhanced processing with streaming and citations
    func processQuestionWithStreaming(_ question: String, bookContext: Book?) async -> String {
        let logger = Logger(subsystem: "com.epilogue", category: "AmbientStreaming")
        
        // Check if we need web access
        if IntelligentQueryRouter.shared.needsWebAccess(question) {
            logger.info("🌐 Question needs web access, using Optimized Perplexity")
            
            var fullResponse = ""
            var streamStarted = false
            
            do {
                for try await response in OptimizedPerplexityService.shared.streamSonarResponse(question, bookContext: bookContext) {
                    if !streamStarted {
                        logger.info("🚀 Stream started, model: \(response.model)")
                        streamStarted = true
                    }
                    
                    fullResponse = response.text
                    
                    // Update UI with partial responses for better UX
                    await updateDetectedContentWithPartialResponse(
                        question: question,
                        partialResponse: fullResponse,
                        citations: response.citations
                    )
                }
                
                return fullResponse
                
            } catch {
                logger.error("❌ Streaming failed: \(error)")
                return "I'm having trouble processing your question. Please try again."
            }
            
        } else {
            // Use local processing for speed
            logger.info("📚 Using local processing for instant response")
            return await IntelligentQueryRouter.shared.processWithParallelism(question, bookContext: bookContext)
        }
    }
    
    private func updateDetectedContentWithPartialResponse(question: String, partialResponse: String, citations: [Citation]) async {
        await MainActor.run {
            if let index = detectedContent.firstIndex(where: { $0.text == question && $0.type == .question }) {
                detectedContent[index].response = partialResponse
                
                // Add citation indicators if available
                if !citations.isEmpty {
                    detectedContent[index].metadata = [
                        "citations": citations.count,
                        "topCredibility": citations.map { $0.credibilityScore }.max() ?? 0.0
                    ]
                }
            }
        }
    }
}

// MARK: - AICompanionService Extension

extension AICompanionService {
    
    // Enhanced chat with streaming and citations
    func chatWithOptimizedStreaming(message: String, bookContext: Book?) async throws -> String {
        let logger = Logger(subsystem: "com.epilogue", category: "AICompanionOptimized")
        
        // Try Foundation Models first for local processing
        if FoundationModelsManager.shared.isAvailable() {
            logger.info("🤖 Using Foundation Models for local processing")
            
            // Stream with Foundation Models
            var fullResponse = ""
            for try await chunk in FoundationModelsManager.shared.streamResponse(message, bookContext: bookContext) {
                fullResponse += chunk
            }
            
            // Check if we need to enhance with web data
            if IntelligentQueryRouter.shared.needsWebAccess(message) {
                logger.info("🔄 Enhancing with web data")
                
                let webResponse = try await OptimizedPerplexityService.shared.chat(
                    message: message,
                    bookContext: bookContext
                )
                
                return """
                \(fullResponse)
                
                Additional Context:
                \(webResponse)
                """
            }
            
            return fullResponse
            
        } else {
            // Use Optimized Perplexity as primary
            logger.info("🌐 Using Optimized Perplexity as primary service")
            
            return try await OptimizedPerplexityService.shared.chat(
                message: message,
                bookContext: bookContext
            )
        }
    }
}

// MARK: - Performance Monitoring

class PerplexityPerformanceMonitor {
    static let shared = PerplexityPerformanceMonitor()
    private let logger = Logger(subsystem: "com.epilogue", category: "PerformanceMetrics")
    
    private var metrics: [String: [TimeInterval]] = [:]
    
    func recordLatency(for operation: String, latency: TimeInterval) {
        if metrics[operation] == nil {
            metrics[operation] = []
        }
        metrics[operation]?.append(latency)
        
        // Keep only last 100 measurements
        if let count = metrics[operation]?.count, count > 100 {
            metrics[operation]?.removeFirst(count - 100)
        }
        
        // Log if latency exceeds threshold
        if latency > 1.0 {
            logger.warning("⚠️ High latency for \(operation): \(String(format: "%.2f", latency))s")
        }
    }
    
    func getAverageLatency(for operation: String) -> TimeInterval? {
        guard let measurements = metrics[operation], !measurements.isEmpty else {
            return nil
        }
        return measurements.reduce(0, +) / Double(measurements.count)
    }
    
    func getP95Latency(for operation: String) -> TimeInterval? {
        guard let measurements = metrics[operation], !measurements.isEmpty else {
            return nil
        }
        let sorted = measurements.sorted()
        let index = Int(Double(sorted.count) * 0.95)
        return sorted[min(index, sorted.count - 1)]
    }
    
    func logPerformanceSummary() {
        logger.info("📊 Performance Summary:")
        
        for (operation, measurements) in metrics {
            if let avg = getAverageLatency(for: operation),
               let p95 = getP95Latency(for: operation) {
                logger.info("  \(operation): avg=\(String(format: "%.2f", avg))s, p95=\(String(format: "%.2f", p95))s")
            }
        }
        
        // Log cache stats
        Task {
            let stats = await OptimizedPerplexityService.shared.getCacheStats()
            let hitRate = Double(stats.hits) / Double(stats.hits + stats.misses) * 100
            logger.info("  Cache: \(stats.hits) hits, \(stats.misses) misses (\(String(format: "%.1f", hitRate))% hit rate)")
        }
    }
}