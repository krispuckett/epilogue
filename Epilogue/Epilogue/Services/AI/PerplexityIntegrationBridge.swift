import Foundation
import OSLog

// MARK: - Perplexity Integration Bridge
// Bridges OptimizedPerplexityService with existing components

extension IntelligentQueryRouter {
    
    // Enhanced processing with optimized Perplexity streaming
    func processWithOptimizedStreaming(_ query: String, bookContext: Book?) async -> String {
        let extensionLogger = Logger(subsystem: "com.epilogue", category: "QueryRouter")
        let queryType = analyzeQuery(query, bookContext: bookContext)
        
        switch queryType {
        case .bookContent:
            // Use local AI for book-specific content
            extensionLogger.info("📚 Using local AI for book content")
            
            if let book = bookContext {
                Epilogue.SmartEpilogueAI.shared.setActiveBook(book.toIntelligentBookModel())
            }
            
            // Check if Foundation Models are available for enhanced local processing
            if Epilogue.FoundationModelsManager.shared.isAvailable() {
                return await Epilogue.FoundationModelsManager.shared.processQuery(query, bookContext: bookContext)
            } else {
                return await Epilogue.SmartEpilogueAI.shared.smartQuery(query)
            }
            
        case .currentEvents, .hybrid:
            // Use optimized Perplexity with streaming and citations
            extensionLogger.info("🌐 Using Optimized Perplexity with citations")
            
            var fullResponse = ""
            var citations: [Citation] = []
            
            do {
                for try await response in Epilogue.OptimizedPerplexityService.shared.streamSonarResponse(query, bookContext: bookContext) {
                    fullResponse = response.text
                    citations = response.citations
                    
                    // Log performance metrics
                    if response.cached {
                        extensionLogger.info("💨 Served from cache with \(citations.count) citations")
                    } else {
                        extensionLogger.info("📊 Confidence: \(String(format: "%.2f", response.confidence)), Citations: \(citations.count)")
                    }
                }
                
                // Format response with citations if available
                if !citations.isEmpty {
                    return formatResponseWithCitations(text: fullResponse, citations: citations)
                }
                
                return fullResponse
                
            } catch {
                extensionLogger.error("❌ Optimized streaming failed: \(error)")
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
        let extensionLogger = Logger(subsystem: "com.epilogue", category: "AmbientStreaming")
        
        // Check if we need web access
        if Epilogue.IntelligentQueryRouter.shared.needsWebAccess(question) {
            extensionLogger.info("🌐 Question needs web access, using Optimized Perplexity")
            
            var fullResponse = ""
            var streamStarted = false
            
            do {
                for try await response in Epilogue.OptimizedPerplexityService.shared.streamSonarResponse(question, bookContext: bookContext) {
                    if !streamStarted {
                        extensionLogger.info("🚀 Stream started, model: \(response.model)")
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
                extensionLogger.error("❌ Streaming failed: \(error)")
                return "I'm having trouble processing your question. Please try again."
            }
            
        } else {
            // Use local processing for speed
            extensionLogger.info("📚 Using local processing for instant response")
            return await Epilogue.IntelligentQueryRouter.shared.processWithParallelism(question, bookContext: bookContext)
        }
    }
    
    private func updateDetectedContentWithPartialResponse(question: String, partialResponse: String, citations: [Citation]) async {
        await MainActor.run {
            if let index = detectedContent.firstIndex(where: { $0.text == question && $0.type == .question }) {
                detectedContent[index].response = partialResponse
                
                // Add citation count to response text if available
                if !citations.isEmpty {
                    let citationCount = citations.count
                    let topCredibility = citations.map { $0.credibilityScore }.max() ?? 0.0
                    let citationInfo = " [\(citationCount) sources, \(String(format: "%.0f", topCredibility * 100))% credibility]"
                    
                    // Only add citation info if not already present
                    if !partialResponse.contains("[") {
                        detectedContent[index].response = partialResponse + citationInfo
                    }
                }
            }
        }
    }
}

// MARK: - AICompanionService Extension

extension AICompanionService {
    
    // Enhanced chat with streaming and citations
    func chatWithOptimizedStreaming(message: String, bookContext: Book?) async throws -> String {
        let extensionLogger = Logger(subsystem: "com.epilogue", category: "AICompanionOptimized")
        
        // Try Foundation Models first for local processing
        if Epilogue.FoundationModelsManager.shared.isAvailable() {
            extensionLogger.info("🤖 Using Foundation Models for local processing")
            
            // Stream with Foundation Models
            var fullResponse = ""
            for try await chunk in Epilogue.FoundationModelsManager.shared.streamResponse(message, bookContext: bookContext) {
                fullResponse += chunk
            }
            
            // Check if we need to enhance with web data
            if Epilogue.IntelligentQueryRouter.shared.needsWebAccess(message) {
                extensionLogger.info("🔄 Enhancing with web data")
                
                let webResponse = try await Epilogue.OptimizedPerplexityService.shared.chat(
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
            extensionLogger.info("🌐 Using Optimized Perplexity as primary service")
            
            return try await Epilogue.OptimizedPerplexityService.shared.chat(
                message: message,
                bookContext: bookContext
            )
        }
    }
}

// MARK: - Performance Monitoring

@MainActor
class PerplexityPerformanceMonitor {
    static let shared = PerplexityPerformanceMonitor()
    private let monitorLogger = Logger(subsystem: "com.epilogue", category: "PerformanceMetrics")
    
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
            monitorLogger.warning("⚠️ High latency for \(operation): \(String(format: "%.2f", latency))s")
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
        monitorLogger.info("📊 Performance Summary:")
        
        for (operation, measurements) in metrics {
            if let avg = getAverageLatency(for: operation),
               let p95 = getP95Latency(for: operation) {
                monitorLogger.info("  \(operation): avg=\(String(format: "%.2f", avg))s, p95=\(String(format: "%.2f", p95))s")
            }
        }
        
        // Log cache stats
        Task {
            let stats = await Epilogue.OptimizedPerplexityService.shared.getCacheStats()
            let hitRate = Double(stats.hits) / Double(stats.hits + stats.misses) * 100
            monitorLogger.info("  Cache: \(stats.hits) hits, \(stats.misses) misses (\(String(format: "%.1f", hitRate))% hit rate)")
        }
    }
}