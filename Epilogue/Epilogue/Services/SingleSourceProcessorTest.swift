#if DEBUG
import Foundation

// MARK: - SingleSourceProcessor Validation Test
/// Quick validation test to ensure the SingleSourceProcessor is working correctly
/// This replaces the need for complex unit tests during initial implementation
class SingleSourceProcessorTest {
    
    static func runValidationTests() async {
        print("🧪 Starting SingleSourceProcessor Validation Tests")
        
        await testDeduplication()
        await testContentDetection()  
        await testAIResponseChain()
        
        print("✅ SingleSourceProcessor validation complete!")
    }
    
    // Test 1: Deduplication with 95% threshold
    private static func testDeduplication() async {
        print("\n🔍 Testing Deduplication (95% threshold)...")
        
        let processor = SingleSourceProcessor.shared
        let duplicateText = "I'm reading Lord of the Rings and it's amazing"
        
        // Process same text multiple times
        var results: [SingleSourceProcessor.ProcessingResult?] = []
        
        for i in 1...3 {
            print("   Processing attempt \(i): '\(duplicateText)'")
            let result = await processor.process(duplicateText, bookContext: nil)
            results.append(result)
        }
        
        // Should only process once
        let successfulResults = results.compactMap { $0 }
        print("   Results: \(successfulResults.count) processed out of 3 attempts")
        
        if successfulResults.count == 1 {
            print("   ✅ Deduplication working correctly - only processed once")
        } else {
            print("   ❌ Deduplication failed - processed \(successfulResults.count) times")
        }
    }
    
    // Test 2: Content type detection
    private static func testContentDetection() async {
        print("\n🔍 Testing Content Type Detection...")
        
        let processor = SingleSourceProcessor.shared
        let testCases = [
            ("What does this passage mean?", ContentType.question),
            ("I love this quote from the book", ContentType.quote),
            ("This makes me realize something important", ContentType.insight),
            ("I think this character is interesting", ContentType.reflection),
            ("Just taking notes about the chapter", ContentType.note)
        ]
        
        for (text, expectedType) in testCases {
            print("   Testing: '\(text)'")
            if let result = await processor.process(text, bookContext: nil) {
                let match = result.type == expectedType
                let emoji = match ? "✅" : "❌"
                print("   \(emoji) Expected: \(expectedType), Got: \(result.type) (confidence: \(String(format: "%.2f", result.confidence)))")
            } else {
                print("   ❌ No result returned for: '\(text)'")
            }
        }
    }
    
    // Test 3: AI response chain (questions should trigger responses)
    private static func testAIResponseChain() async {
        print("\n🔍 Testing AI Response Chain...")
        
        let processor = SingleSourceProcessor.shared
        let questionText = "What are the main themes in this book?"
        
        print("   Processing question: '\(questionText)'")
        if let result = await processor.process(questionText, bookContext: nil) {
            if result.requiresAIResponse {
                print("   ✅ Question correctly identified as requiring AI response")
                print("   ✅ AI response chain should be triggered (check logs for API calls)")
            } else {
                print("   ❌ Question not identified as requiring AI response")
            }
        } else {
            print("   ❌ Question was not processed")
        }
    }
}

// MARK: - Performance Test
class SingleSourcePerformanceTest {
    
    static func runPerformanceTests() async {
        print("\n⚡ Running Performance Tests...")
        
        let processor = SingleSourceProcessor.shared
        let testTexts = [
            "Short note",
            "This is a medium length reflection about the book I'm reading",
            "What is the significance of the ring in Lord of the Rings and how does it relate to power?",
            "I love this quote: 'Not all those who wander are lost' - it's so meaningful",
            "This chapter makes me realize that the author is exploring themes of friendship and loyalty"
        ]
        
        let startTime = Date()
        var processedCount = 0
        
        for text in testTexts {
            if await processor.process(text, bookContext: nil) != nil {
                processedCount += 1
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(testTexts.count)
        
        print("   Processed \(processedCount)/\(testTexts.count) items")
        print("   Total time: \(String(format: "%.3f", totalTime))s")
        print("   Average time per item: \(String(format: "%.3f", averageTime))s")
        
        if averageTime < 0.05 { // 50ms target from requirements
            print("   ✅ Performance meets requirements (<50ms per item)")
        } else {
            print("   ⚠️ Performance slower than target (>50ms per item)")
        }
    }
}

// MARK: - Integration Test
class SingleSourceIntegrationTest {
    
    static func testFullIntegration() async {
        print("\n🔗 Testing Full Integration...")
        
        // This simulates the full flow:
        // VoiceRecognitionManager -> SingleSourceProcessor -> AI Response
        
        let testTranscription = "What is the meaning of life according to this book?"
        
        print("   Simulating voice transcription: '\(testTranscription)'")
        
        // This is what VoiceRecognitionManager now does
        let processor = SingleSourceProcessor.shared
        let result = await processor.process(
            testTranscription,
            confidence: 0.85,
            isFinal: true,
            bookContext: nil
        )
        
        if let result = result {
            print("   ✅ Transcription processed successfully")
            print("   - Type: \(result.type)")
            print("   - Confidence: \(String(format: "%.2f", result.confidence))")
            print("   - Requires AI: \(result.requiresAIResponse)")
            
            if result.requiresAIResponse {
                print("   ✅ AI response should be triggered automatically")
            }
        } else {
            print("   ❌ Integration test failed - no processing result")
        }
    }
}
#endif