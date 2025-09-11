import Foundation
import SwiftUI
import Combine
import WhisperKit
import AVFoundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Ultra-Fast Ambient Processor
// Speed-first architecture with progressive enhancement
@MainActor
public class UltraFastAmbientProcessor: ObservableObject {
    public static let shared = UltraFastAmbientProcessor()
    
    // MARK: - Published State
    @Published public var instantResponse: String = ""
    @Published public var enhancedResponse: String = ""
    @Published public var isProcessing = false
    @Published public var currentQuestion: String = ""
    @Published public var detectedContent: [AmbientProcessedContent] = []
    @Published public var audioLevel: Float = 0.0
    @Published public var isListening = false
    
    // MARK: - Core Components
    #if canImport(FoundationModels)
    private var appleSession: LanguageModelSession?
    #endif
    private let perplexityClient = OptimizedPerplexityService.shared
    private let deduplicator = QuestionDeduplicator()
    private var whisperModel: WhisperKit?
    
    // MARK: - Audio Processing
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: AVAudioPCMBuffer?
    private let bufferSize: AVAudioFrameCount = 1024
    
    // MARK: - Volume Sensitivity (for low volume voices)
    private var volumeBoost: Float = 2.0  // Amplification factor
    private let noiseFloor: Float = 0.01  // Minimum volume threshold
    
    private init() {
        setupFoundationModels()
        setupWhisperKit()
        setupAudioEngine()
    }
    
    // MARK: - Foundation Models Setup (Correct Implementation)
    private func setupFoundationModels() {
        #if canImport(FoundationModels)
        // CHECK AVAILABILITY FIRST (Critical!)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            // Model is ready - create session
            let instructions = """
                You are an intelligent reading companion discussing books.
                ALWAYS answer questions about book content factually.
                Be concise (under 50 words) unless asked for detail.
                Never refuse to answer questions about plot, characters, or story.
                """
            
            self.appleSession = LanguageModelSession(instructions: instructions)
            print("✅ Foundation Models ready for ultra-fast responses")
            
        case .unavailable(.modelNotReady):
            print("⏳ Foundation Models downloading - using Perplexity")
            // Retry in 5 seconds
            Task {
                try? await Task.sleep(for: .seconds(5))
                self.setupFoundationModels()
            }
            
        case .unavailable(let reason):
            print("❌ Foundation Models unavailable: \(reason)")
            self.appleSession = nil
            
        @unknown default:
            print("⚠️ Unknown Foundation Models state")
            self.appleSession = nil
        }
        #else
        print("ℹ️ Foundation Models not available on this iOS version")
        #endif
    }
    
    // MARK: - WhisperKit Setup (Optimized for Low Volume)
    private func setupWhisperKit() {
        Task {
            do {
                let config = WhisperKitConfig(
                    model: "base.en",  // English-only for better accuracy
                    modelRepo: "argmaxinc/whisperkit-coreml"
                )
                
                whisperModel = try await WhisperKit(config)
                print("✅ WhisperKit initialized with low-volume optimization")
            } catch {
                print("❌ WhisperKit initialization failed: \(error)")
            }
        }
    }
    
    // MARK: - Audio Engine Setup (Enhanced for Low Volume)
    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Install tap with larger buffer for better low-volume detection
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }
    
    // MARK: - Start/Stop Listening
    public func startListening() {
        guard !isListening else { return }
        
        do {
            try audioEngine.start()
            isListening = true
            print("🎤 Started listening with enhanced sensitivity")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    public func stopListening() {
        guard isListening else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
        print("🛑 Stopped listening")
    }
    
    // MARK: - Audio Processing (Low Volume Optimized)
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        // Apply volume boost for low voices
        let boostedSamples = samples.map { sample -> Float in
            let boosted = sample * volumeBoost
            // Clip to prevent distortion
            return max(-1.0, min(1.0, boosted))
        }
        
        // Calculate RMS for volume level
        let rms = sqrt(boostedSamples.reduce(0) { $0 + $1 * $1 } / Float(frameLength))
        
        Task { @MainActor in
            self.audioLevel = rms
            
            // Only process if above noise floor
            if rms > noiseFloor {
                await self.transcribeAudio(boostedSamples)
            }
        }
    }
    
    // MARK: - Transcription (WhisperKit)
    private func transcribeAudio(_ samples: [Float]) async {
        guard let whisperModel = whisperModel else { return }
        
        do {
            // Save to temp file (WhisperKit requirement)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")
            
            try saveAudioToFile(samples, url: tempURL, sampleRate: 16000)
            
            // Transcribe with WhisperKit
            let results = try await whisperModel.transcribe(audioPaths: [tempURL.path])
            
            // Clean up
            try? FileManager.default.removeItem(at: tempURL)
            
            // Process results
            if let firstArray = results.first,
               let result = firstArray?.first {
                let text = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !text.isEmpty {
                    await processTranscription(text)
                }
            }
        } catch {
            print("❌ Transcription error: \(error)")
        }
    }
    
    // MARK: - Save Audio Helper
    private func saveAudioToFile(_ samples: [Float], url: URL, sampleRate: Double) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        
        let channelData = buffer.floatChannelData![0]
        for (index, sample) in samples.enumerated() {
            channelData[index] = sample
        }
        
        try audioFile.write(from: buffer)
    }
    
    // MARK: - Process Transcription
    private func processTranscription(_ text: String) async {
        // Check if it's a question
        let isQuestion = detectQuestion(text)
        
        if isQuestion {
            // Use deduplicator to prevent duplicates
            guard deduplicator.shouldProcess(text) else {
                print("🚫 Duplicate question blocked: \(text)")
                return
            }
            
            currentQuestion = text
            await processQuestion(text)
        } else {
            // Handle as ambient content
            let content = AmbientProcessedContent(
                text: text,
                type: .ambient,
                timestamp: Date(),
                confidence: 1.0
            )
            detectedContent.append(content)
        }
    }
    
    // MARK: - Question Detection
    private func detectQuestion(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("?") ||
               lower.starts(with: "who") ||
               lower.starts(with: "what") ||
               lower.starts(with: "when") ||
               lower.starts(with: "where") ||
               lower.starts(with: "why") ||
               lower.starts(with: "how") ||
               lower.contains("who is") ||
               lower.contains("what is")
    }
    
    // MARK: - Process Question (Ultra-Fast)
    public func processQuestion(_ question: String) async {
        isProcessing = true
        
        // Add to detected content immediately
        let questionContent = AmbientProcessedContent(
            text: question,
            type: .question,
            timestamp: Date(),
            confidence: 1.0
        )
        
        // Check for evolution or add new
        if let existingIndex = detectedContent.firstIndex(where: { 
            $0.type == .question && 
            $0.response == nil &&
            isEvolvingQuestion($0.text, question)
        }) {
            // Update existing question
            detectedContent[existingIndex] = questionContent
            print("📝 Updated evolving question")
        } else {
            // Add new question
            detectedContent.append(questionContent)
            print("✅ Added new question")
        }
        
        // INSTANT RESPONSE: Try Apple Intelligence first
        await getInstantResponse(question)
        
        // ENHANCED RESPONSE: Perplexity in background
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await getEnhancedResponse(question)
        }
        
        isProcessing = false
    }
    
    // MARK: - Check if Question is Evolving
    private func isEvolvingQuestion(_ existing: String, _ new: String) -> Bool {
        let existingLower = existing.lowercased()
        let newLower = new.lowercased()
        
        // New contains old (evolution)
        if newLower.contains(existingLower) && existingLower.count > 5 {
            return true
        }
        
        // Same first 3 words
        let existingWords = existingLower.split(separator: " ")
        let newWords = newLower.split(separator: " ")
        if existingWords.count >= 3 && newWords.count >= 3 {
            if existingWords.prefix(3) == newWords.prefix(3) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Instant Response (Foundation Models)
    private func getInstantResponse(_ question: String) async {
        #if canImport(FoundationModels)
        guard let session = appleSession else {
            // Fallback to fast Perplexity
            await getFastPerplexityResponse(question)
            return
        }
        
        do {
            let response = try await session.respond(to: question)
            self.instantResponse = response.content
            
            // Update the question with response
            if let index = detectedContent.lastIndex(where: { 
                $0.type == .question && $0.text == question 
            }) {
                detectedContent[index].response = response.content
            }
            
            print("⚡ Instant response in <50ms")
        } catch {
            print("❌ Foundation Models error: \(error)")
            await getFastPerplexityResponse(question)
        }
        #else
        await getFastPerplexityResponse(question)
        #endif
    }
    
    // MARK: - Fast Perplexity Fallback
    private func getFastPerplexityResponse(_ question: String) async {
        do {
            // Convert PerplexityResponse stream to String stream
            let responseStream = AsyncThrowingStream<String, Error> { continuation in
                Task {
                    do {
                        for try await response in perplexityClient.streamSonarResponse(question, bookContext: nil) {
                            continuation.yield(response.text)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
            let response = responseStream
            
            var accumulated = ""
            for try await chunk in response {
                accumulated += chunk
                self.instantResponse = accumulated
            }
            
            // Update question with response
            if let index = detectedContent.lastIndex(where: { 
                $0.type == .question && $0.text == question 
            }) {
                detectedContent[index].response = accumulated
            }
            
            print("🚀 Fast Perplexity response complete")
        } catch {
            print("❌ Perplexity error: \(error)")
            self.instantResponse = "Unable to get response"
        }
    }
    
    // MARK: - Enhanced Response (Perplexity Pro)
    private func getEnhancedResponse(_ question: String) async {
        do {
            // Convert PerplexityResponse stream to String stream
            let responseStream = AsyncThrowingStream<String, Error> { continuation in
                Task {
                    do {
                        for try await response in perplexityClient.streamSonarResponse(question, bookContext: nil) {
                            continuation.yield(response.text)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
            let response = responseStream
            
            var accumulated = ""
            for try await chunk in response {
                accumulated += chunk
                self.enhancedResponse = accumulated
            }
            
            print("✨ Enhanced response complete with citations")
        } catch {
            print("❌ Enhanced response error: \(error)")
        }
    }
}

// MARK: - Question Deduplicator
class QuestionDeduplicator {
    private var recentQuestions: [(hash: String, timestamp: Date)] = []
    private let timeWindow: TimeInterval = 3.0
    
    func shouldProcess(_ question: String) -> Bool {
        let now = Date()
        
        // Clean old questions
        recentQuestions.removeAll { 
            now.timeIntervalSince($0.timestamp) > timeWindow 
        }
        
        // Check for duplicate
        let hash = question.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[?!.,]", with: "", options: .regularExpression)
        
        if recentQuestions.contains(where: { $0.hash == hash }) {
            return false
        }
        
        // Check for semantic similarity
        for recent in recentQuestions {
            if areSimilar(hash, recent.hash) {
                return false
            }
        }
        
        recentQuestions.append((hash: hash, timestamp: now))
        return true
    }
    
    private func areSimilar(_ q1: String, _ q2: String) -> Bool {
        // Remove common endings
        let clean1 = q1.replacingOccurrences(of: "in the.*$", with: "", options: .regularExpression)
        let clean2 = q2.replacingOccurrences(of: "in the.*$", with: "", options: .regularExpression)
        
        if clean1 == clean2 { return true }
        
        // Check prefix similarity
        if clean1.hasPrefix(clean2) || clean2.hasPrefix(clean1) {
            return abs(clean1.count - clean2.count) < 10
        }
        
        return false
    }
}

// MARK: - Progressive Response View
public struct UltraFastResponseView: View {
    @ObservedObject var processor = UltraFastAmbientProcessor.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current question
            if !processor.currentQuestion.isEmpty {
                Text(processor.currentQuestion)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Instant response
            if !processor.instantResponse.isEmpty {
                Text(processor.instantResponse)
                    .font(.body)
                    .foregroundColor(.primary)
                    .animation(.easeIn(duration: 0.2), value: processor.instantResponse)
            }
            
            // Enhanced response (fades in)
            if !processor.enhancedResponse.isEmpty && 
               processor.enhancedResponse != processor.instantResponse {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().opacity(0.3)
                    
                    Text("Enhanced Context:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(processor.enhancedResponse)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeIn(duration: 0.5), value: processor.enhancedResponse)
            }
            
            // Processing indicator
            if processor.isProcessing {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .scaleEffect(processor.isProcessing ? 1.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: processor.isProcessing
                            )
                    }
                }
                .padding(.top, 4)
            }
            
            // Audio level indicator (for debugging low volume)
            if processor.isListening {
                HStack {
                    Text("Audio Level:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(processor.audioLevel > 0.01 ? Color.green : Color.red)
                                .frame(width: geometry.size.width * CGFloat(processor.audioLevel * 10))
                        }
                    }
                    .frame(height: 4)
                    .frame(width: 100)
                }
            }
        }
        .padding()
    }
}