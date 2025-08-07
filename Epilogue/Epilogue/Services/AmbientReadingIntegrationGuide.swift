import Foundation
import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientIntegration")

/*
 MARK: - Optimized AI Response System Integration Guide
 
 This system provides instant AI responses for ambient reading sessions with:
 1. Real-time question detection
 2. Streaming responses for immediate feedback
 3. Smart caching for common questions
 4. Optimized session data organization
 
 INTEGRATION STEPS:
 
 1. Replace existing AmbientReadingView content with StreamingAmbientChatView
 2. Initialize OptimizedAIResponseService.shared in app startup
 3. Ensure VoiceRecognitionManager sends ImmediateQuestionDetected notifications
 4. Set up proper notification observers in your ambient views
 
 PERFORMANCE OPTIMIZATIONS:
 
 - Questions are detected in real-time (no waiting for session end)
 - AI responses start streaming immediately (sub-second response start)
 - Smart model selection: sonar for simple questions, sonar-pro for complex
 - Intelligent caching with dynamic expiration based on confidence and usage
 - Session data is organized into clusters for better UI presentation
 
 USAGE EXAMPLE:
 
 ```swift
 // In your AmbientReadingView:
 
 struct AmbientReadingView: View {
     @State private var isShowingChat = false
     let book: Book
     
     var body: some View {
         ZStack {
             // Your existing ambient reading UI
             BookAtmosphericGradientView(book: book)
             
             // New streaming chat overlay
             if isShowingChat {
                 StreamingAmbientChatView(bookContext: book)
                     .transition(.opacity)
             }
         }
         .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ImmediateQuestionDetected"))) { _ in
             withAnimation {
                 isShowingChat = true
             }
         }
     }
 }
 ```
 
 TESTING:
 
 Use the test methods below to verify the system is working correctly.
 */

// MARK: - Integration Manager

@MainActor
class AmbientReadingIntegrationManager: ObservableObject {
    static let shared = AmbientReadingIntegrationManager()
    
    @Published var isSystemActive = false
    @Published var performanceMetrics: [String: Any] = [:]
    
    private let aiService = OptimizedAIResponseService.shared
    private let responseCache = ResponseCache.shared
    private let voiceManager = VoiceRecognitionManager.shared
    
    private init() {
        setupIntegration()
    }
    
    // MARK: - System Setup
    
    private func setupIntegration() {
        logger.info("🚀 Setting up Optimized AI Response System integration")
        
        // Initialize services
        _ = aiService
        
        // Setup cache cleaning timer
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                self.responseCache.cleanExpiredEntries()
                self.updatePerformanceMetrics()
            }
        }
        
        // Preload common questions for popular books
        Task {
            await preloadCommonQuestions()
        }
        
        logger.info("✅ Integration setup complete")
    }
    
    // MARK: - Testing Methods
    
    func testQuestionDetection() async {
        logger.info("🧪 Testing question detection system")
        
        let testQuestions = [
            "What is this book about?",
            "Who is the main character?",
            "Why did the author write this?",
            "How does this chapter relate to the theme?",
            "Can you explain this concept?",
            "What does this symbolize?"
        ]
        
        for (index, question) in testQuestions.enumerated() {
            logger.info("Testing question \(index + 1): \(question)")
            
            // Simulate question detection
            NotificationCenter.default.post(
                name: Notification.Name("ImmediateQuestionDetected"),
                object: [
                    "question": question,
                    "timestamp": Date(),
                    "bookContext": nil
                ]
            )
            
            // Small delay between tests
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        logger.info("✅ Question detection test complete")
    }
    
    func testStreamingResponse() async {
        logger.info("🧪 Testing streaming response system")
        
        let testQuestion = "What are the main themes in this book?"
        
        let startTime = Date()
        await aiService.processImmediateQuestion(testQuestion, bookContext: nil)
        let responseTime = Date().timeIntervalSince(startTime)
        
        logger.info("✅ Streaming response test complete in \(String(format: "%.2f", responseTime))s")
    }
    
    func testCachePerformance() async {
        logger.info("🧪 Testing cache performance")
        
        let testQuestion = "Who wrote this book?"
        
        // First request (should create cache entry)
        let startTime1 = Date()
        await aiService.processImmediateQuestion(testQuestion, bookContext: nil)
        let responseTime1 = Date().timeIntervalSince(startTime1)
        
        // Second request (should use cache)
        let startTime2 = Date()
        await aiService.processImmediateQuestion(testQuestion, bookContext: nil)
        let responseTime2 = Date().timeIntervalSince(startTime2)
        
        let speedImprovement = responseTime1 / max(responseTime2, 0.001)
        
        logger.info("✅ Cache performance test:")
        logger.info("  First response: \(String(format: "%.2f", responseTime1))s")
        logger.info("  Cached response: \(String(format: "%.2f", responseTime2))s")
        logger.info("  Speed improvement: \(String(format: "%.1f", speedImprovement))x")
    }
    
    func testSessionDataModel() {
        logger.info("🧪 Testing session data model")
        
        // Create test session
        var session = OptimizedAmbientSession(
            startTime: Date().addingTimeInterval(-3600), // 1 hour ago
            bookContext: nil,
            metadata: SessionMetadata()
        )
        
        // Add test content
        let testContent = [
            SessionContent(
                type: .question,
                text: "What is the main theme?",
                timestamp: Date().addingTimeInterval(-3500),
                confidence: 0.9,
                bookContext: nil,
                aiResponse: AISessionResponse(
                    question: "What is the main theme?",
                    answer: "The main theme is...",
                    model: "sonar",
                    confidence: 0.85,
                    responseTime: 1.2,
                    timestamp: Date().addingTimeInterval(-3498),
                    isStreamed: true,
                    wasFromCache: false
                )
            ),
            SessionContent(
                type: .reflection,
                text: "This is really interesting",
                timestamp: Date().addingTimeInterval(-3000),
                confidence: 0.7,
                bookContext: nil,
                aiResponse: nil
            )
        ]
        
        session.allContent = testContent
        
        logger.info("✅ Session data model test:")
        logger.info("  Duration: \(String(format: "%.1f", session.duration / 60)) minutes")
        logger.info("  Questions: \(session.totalQuestions)")
        logger.info("  AI Responses: \(session.totalAIResponses)")
        logger.info("  Avg Response Time: \(String(format: "%.2f", session.averageResponseTime))s")
        logger.info("  Cache Hit Rate: \(Int(session.cacheHitRate * 100))%")
    }
    
    // MARK: - Performance Monitoring
    
    func updatePerformanceMetrics() {
        let aiMetrics = aiService.getPerformanceMetrics()
        let cacheStats = responseCache.getCacheStatistics()
        
        performanceMetrics = [
            "ai": aiMetrics,
            "cache": cacheStats,
            "lastUpdated": Date()
        ]
        
        logger.info("📊 Performance metrics updated")
    }
    
    func getSystemStatus() -> [String: Any] {
        return [
            "isActive": isSystemActive,
            "voiceRecognitionActive": voiceManager.isListening,
            "aiServiceActive": aiService.isProcessing,
            "cacheEntries": responseCache.getCacheStatistics()["totalEntries"] ?? 0,
            "performanceMetrics": performanceMetrics
        ]
    }
    
    // MARK: - Common Questions Preloading
    
    private func preloadCommonQuestions() async {
        let commonQuestions = [
            "What is this book about?",
            "Who is the main character?",
            "Who wrote this book?",
            "What genre is this?",
            "What are the main themes?",
            "When was this published?",
            "What happens in this chapter?",
            "Can you summarize this?",
            "What does this mean?",
            "Why is this important?"
        ]
        
        // Preload for current book context if available
        // This would be called when a book is selected
        for question in commonQuestions {
            // Check if already cached
            if responseCache.getResponse(for: question, bookTitle: nil) == nil {
                // Generate response in background
                // Process question using the public method
                await aiService.processImmediateQuestion(question, bookContext: nil)
            }
        }
        
        logger.info("✅ Common questions preloaded")
    }
    
    // MARK: - Activation/Deactivation
    
    func activateSystem(for book: Book? = nil) {
        isSystemActive = true
        
        if let book = book {
            // Preload book-specific questions
            aiService.preloadCommonQuestions(for: book)
        }
        
        // Start voice recognition if not already active
        if !voiceManager.isListening {
            voiceManager.startAmbientListening()
        }
        
        logger.info("🟢 Optimized AI Response System activated")
    }
    
    func deactivateSystem() {
        isSystemActive = false
        
        // Stop voice recognition
        voiceManager.stopListening()
        
        logger.info("🔴 Optimized AI Response System deactivated")
    }
}

// MARK: - Integration Test View

struct AmbientIntegrationTestView: View {
    @StateObject private var integration = AmbientReadingIntegrationManager.shared
    @State private var testResults: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // System Status
                statusSection
                
                // Performance Metrics
                metricsSection
                
                // Test Buttons
                testSection
                
                // Test Results
                resultsSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI System Tests")
            .onAppear {
                integration.updatePerformanceMetrics()
            }
        }
    }
    
    private var statusSection: some View {
        GroupBox("System Status") {
            let status = integration.getSystemStatus()
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(label: "System Active", value: status["isActive"] as? Bool ?? false)
                StatusRow(label: "Voice Recognition", value: status["voiceRecognitionActive"] as? Bool ?? false)
                StatusRow(label: "AI Service", value: status["aiServiceActive"] as? Bool ?? false)
                StatusRow(label: "Cache Entries", value: status["cacheEntries"] as? Int ?? 0)
            }
        }
    }
    
    private var metricsSection: some View {
        GroupBox("Performance Metrics") {
            if let metrics = integration.performanceMetrics["ai"] as? [String: Any] {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Response Time: \(String(format: "%.2f", metrics["avgResponseTime"] as? Double ?? 0))s")
                    Text("Total Responses: \(metrics["totalResponses"] as? Int ?? 0)")
                    Text("Cache Hit Rate: \(Int((metrics["cacheHitRate"] as? Double ?? 0) * 100))%")
                    Text("Active Streams: \(metrics["activeStreams"] as? Int ?? 0)")
                }
                .font(.caption)
            }
        }
    }
    
    private var testSection: some View {
        GroupBox("Tests") {
            VStack(spacing: 12) {
                Button("Test Question Detection") {
                    Task {
                        await integration.testQuestionDetection()
                        testResults.append("✅ Question detection test completed")
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Test Streaming Response") {
                    Task {
                        await integration.testStreamingResponse()
                        testResults.append("✅ Streaming response test completed")
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Test Cache Performance") {
                    Task {
                        await integration.testCachePerformance()
                        testResults.append("✅ Cache performance test completed")
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Test Session Model") {
                    integration.testSessionDataModel()
                    testResults.append("✅ Session data model test completed")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var resultsSection: some View {
        GroupBox("Test Results") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
    
    struct StatusRow: View {
        let label: String
        let value: Any
        
        var body: some View {
            HStack {
                Text(label)
                Spacer()
                if let boolValue = value as? Bool {
                    Circle()
                        .fill(boolValue ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                } else {
                    Text("\(value)")
                        .fontWeight(.medium)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AmbientIntegrationTestView()
}