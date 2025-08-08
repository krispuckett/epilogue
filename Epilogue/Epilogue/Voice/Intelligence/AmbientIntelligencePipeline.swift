import Foundation
import AVFoundation
import Speech
import SoundAnalysis
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientIntelligencePipeline")

// MARK: - Type Definitions

struct SoundEvent {
    let type: SoundType
    let confidence: Float
    let timestamp: Date
}

enum SoundType {
    case pageTurn
    case breathing
    case backgroundNoise
    case silence
}

enum ActionType {
    case saveQuote
    case addNote
    case answerQuestion
    case exploreEmotion
    case bookmark
    case search
    case define
    case none
}

enum Urgency: String {
    case immediate = "Immediate"
    case normal = "Normal"
    case low = "Low"
}

// MARK: - Advanced Intelligence Pipeline
@MainActor
class AmbientIntelligencePipeline: ObservableObject {
    @Published var isProcessing = false
    @Published var latestResult: IntelligenceResult?
    @Published var processingMetrics = ProcessingMetrics()
    @Published var confidence: Float = 0
    
    // Components
    private let audioPreprocessor = AudioPreprocessor()
    private let optimizedWhisperProcessor = OptimizedWhisperProcessor()
    private let foundationModelsProcessor = FoundationModelsProcessor()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var soundClassifier: SNAudioStreamAnalyzer?
    
    // Parallel processing
    private let processingQueue = DispatchQueue(label: "com.epilogue.pipeline", attributes: .concurrent)
    private var audioQueue: [AVAudioPCMBuffer] = []
    private let maxQueueSize = 10
    
    // Adaptive quality
    private let adaptiveQuality = AdaptiveQualityManager()
    
    // Cache
    private var resultCache: [String: IntelligenceResult] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    struct IntelligenceResult {
        let transcription: TranscriptionResult
        let intent: ReadingIntent
        let entities: [FoundationModelsProcessor.ExtractedEntity]
        let sentiment: FoundationModelsProcessor.SentimentScore
        let soundEvents: [SoundEvent]
        let suggestedAction: SuggestedAction
        let confidence: Float
        let timestamp: Date
    }
    
    struct TranscriptionResult {
        let whisperText: String
        let appleText: String
        let finalText: String
        let confidence: Float
        let processingTime: TimeInterval
    }
    
    // SoundEvent moved to top level
    
    struct SuggestedAction {
        let type: ActionType
        let title: String
        let description: String
        let urgency: Urgency
    }
    
    // ActionType and Urgency moved to top level
    
    struct ProcessingMetrics {
        var audioLatency: TimeInterval = 0
        var whisperLatency: TimeInterval = 0
        var appleLatency: TimeInterval = 0
        var modelsLatency: TimeInterval = 0
        var totalLatency: TimeInterval = 0
        var batteryImpact: Float = 0
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        // Initialize Whisper
        try? await optimizedWhisperProcessor.initialize()
        
        // Pre-warm Foundation Models
        await foundationModelsProcessor.prewarmModels()
        
        // Setup sound classifier
        setupSoundClassifier()
        
        // Start adaptive quality monitoring
        adaptiveQuality.startMonitoring()
        
        logger.info("Ambient Intelligence Pipeline initialized")
    }
    
    private func setupSoundClassifier() {
        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else { return }
        
        soundClassifier = SNAudioStreamAnalyzer(format: audioFormat)
        
        // Add sound classification request
        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            try soundClassifier?.add(request, withObserver: SoundClassifierObserver { [weak self] results in
                self?.processSoundClassification(results)
            })
        } catch {
            logger.error("Failed to setup sound classifier: \(error)")
        }
    }
    
    // MARK: - Stage 1: Audio Analysis
    
    func analyzeAudioStream(_ buffer: AVAudioPCMBuffer) async {
        let startTime = Date()
        
        // Check if we should process based on adaptive quality
        guard adaptiveQuality.shouldProcessAudio() else { return }
        
        // Preprocess audio
        guard let processedAudio = await audioPreprocessor.processAudioBuffer(buffer) else {
            return
        }
        
        // Only queue if voice detected
        if processedAudio.hasVoice {
            audioQueue.append(buffer)
            
            // Process if queue is full or significant pause detected
            if audioQueue.count >= maxQueueSize || shouldProcessQueue() {
                await processAudioQueue()
            }
        }
        
        // Update metrics
        processingMetrics.audioLatency = Date().timeIntervalSince(startTime)
    }
    
    private func shouldProcessQueue() -> Bool {
        // Process if we have enough audio or detected end of utterance
        let stats = audioPreprocessor.getAudioStatistics()
        return !stats.isSpeaking && audioQueue.count > 2
    }
    
    // MARK: - Stage 2: Parallel Processing
    
    private func processAudioQueue() async {
        guard !audioQueue.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let buffers = audioQueue
        audioQueue.removeAll()
        
        // Combine buffers
        guard let combinedBuffer = combineAudioBuffers(buffers) else { return }
        
        // Run all processors in parallel
        async let whisperTask = processWithWhisper(combinedBuffer)
        async let appleTask = processWithApple(combinedBuffer)
        async let soundTask = processWithSoundClassifier(combinedBuffer)
        
        // Wait for all results
        let (whisperResult, appleResult, soundEvents) = await (whisperTask, appleTask, soundTask)
        
        // Combine results intelligently
        let combinedTranscription = combineTranscriptions(
            whisper: whisperResult,
            apple: appleResult
        )
        
        // Apply intelligence layer
        await applyIntelligence(
            transcription: combinedTranscription,
            soundEvents: soundEvents
        )
    }
    
    private func processWithWhisper(_ buffer: AVAudioPCMBuffer) async -> EpilogueTranscriptionResult? {
        let startTime = Date()
        
        do {
            let transcriptionResult = try await optimizedWhisperProcessor.transcribe(audioBuffer: buffer)
            // Convert to EpilogueTranscriptionResult
            let result = EpilogueTranscriptionResult(
                text: transcriptionResult.text,
                segments: transcriptionResult.segments,
                language: transcriptionResult.language ?? "en",
                languageProbability: transcriptionResult.languageProbability ?? 0.95,
                timings: transcriptionResult.timings ?? EpilogueTranscriptionTimings(
                    fullPipeline: 0,
                    vad: 0,
                    audioProcessing: 0,
                    whisperProcessing: 0
                ),
                modelUsed: optimizedWhisperProcessor.currentModel
            )
            processingMetrics.whisperLatency = Date().timeIntervalSince(startTime)
            return result
        } catch {
            logger.error("Whisper processing failed: \(error)")
            return nil
        }
    }
    
    private func processWithApple(_ buffer: AVAudioPCMBuffer) async -> String? {
        let startTime = Date()
        
        guard let recognizer = speechRecognizer else { return nil }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        
        request.append(buffer)
        request.endAudio()
        
        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    logger.error("Apple speech recognition failed: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let result = result else {
                    continuation.resume(returning: nil)
                    return
                }
                
                self.processingMetrics.appleLatency = Date().timeIntervalSince(startTime)
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
    
    private func processWithSoundClassifier(_ buffer: AVAudioPCMBuffer) async -> [SoundEvent] {
        soundClassifier?.analyze(buffer, atAudioFramePosition: 0)
        
        // Return accumulated sound events
        return [] // Placeholder - actual events come through observer
    }
    
    // MARK: - Stage 3: Intelligence Layer
    
    private func applyIntelligence(
        transcription: TranscriptionResult,
        soundEvents: [SoundEvent]
    ) async {
        let startTime = Date()
        
        // Skip if no meaningful content
        guard !transcription.finalText.isEmpty else { return }
        
        // Check cache first
        if let cached = resultCache[transcription.finalText],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            latestResult = cached
            return
        }
        
        // Get book context
        let bookContext = getCurrentBookContext()
        
        // Run Foundation Models in parallel
        async let intentTask = foundationModelsProcessor.classifyIntent(
            from: transcription.finalText,
            bookContext: bookContext
        )
        async let entitiesTask = foundationModelsProcessor.extractEntities(
            from: transcription.finalText
        )
        async let sentimentTask = foundationModelsProcessor.analyzeSentiment(
            from: transcription.finalText
        )
        
        // Wait for all results
        do {
            let (intentResult, entities, sentiment) = try await (intentTask, entitiesTask, sentimentTask)
            
            // Build context and determine action
            let context = buildContext(
                intent: intentResult.intent,
                entities: entities,
                sentiment: sentiment,
                soundEvents: soundEvents,
                bookContext: bookContext
            )
            
            let suggestedAction = determineSuggestedAction(context)
            
            // Calculate combined confidence
            let combinedConfidence = calculateCombinedConfidence(
                transcription: transcription.confidence,
                intent: intentResult.confidence,
                entities: entities.isEmpty ? 0.5 : 0.8
            )
            
            // Create final result
            let result = IntelligenceResult(
                transcription: transcription,
                intent: intentResult.intent,
                entities: entities,
                sentiment: sentiment,
                soundEvents: soundEvents,
                suggestedAction: suggestedAction,
                confidence: combinedConfidence,
                timestamp: Date()
            )
            
            // Update state
            latestResult = result
            confidence = combinedConfidence
            
            // Cache result
            resultCache[transcription.finalText] = result
            
            // Update metrics
            processingMetrics.modelsLatency = Date().timeIntervalSince(startTime)
            processingMetrics.totalLatency = processingMetrics.audioLatency +
                                            processingMetrics.whisperLatency +
                                            processingMetrics.modelsLatency
            
            logger.info("Intelligence processing complete: \(intentResult.intent.rawValue) with confidence \(combinedConfidence)")
            
            // Post notification for UI
            NotificationCenter.default.post(
                name: Notification.Name("IntelligenceResultReady"),
                object: result
            )
            
        } catch {
            logger.error("Intelligence processing failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func combineAudioBuffers(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard !buffers.isEmpty else { return nil }
        
        let format = buffers[0].format
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        
        guard let combinedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(totalFrames)
        ) else { return nil }
        
        var currentFrame = 0
        
        for buffer in buffers {
            let frameCount = Int(buffer.frameLength)
            
            if let sourceData = buffer.floatChannelData,
               let destData = combinedBuffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    let destPtr = destData[channel].advanced(by: currentFrame)
                    memcpy(destPtr, sourceData[channel], frameCount * MemoryLayout<Float>.size)
                }
            }
            
            currentFrame += frameCount
        }
        
        combinedBuffer.frameLength = AVAudioFrameCount(totalFrames)
        return combinedBuffer
    }
    
    private func combineTranscriptions(
        whisper: EpilogueTranscriptionResult?,
        apple: String?
    ) -> TranscriptionResult {
        // Use Whisper as primary, Apple as fallback
        let whisperText = whisper?.text ?? ""
        let appleText = apple ?? ""
        
        // Choose best transcription based on confidence and length
        let finalText: String
        let confidence: Float
        
        if !whisperText.isEmpty && (whisper?.segments.count ?? 0) > 0 {
            finalText = whisperText
            confidence = optimizedWhisperProcessor.confidence
        } else if !appleText.isEmpty {
            finalText = appleText
            confidence = 0.7 // Default confidence for Apple
        } else {
            finalText = ""
            confidence = 0
        }
        
        return TranscriptionResult(
            whisperText: whisperText,
            appleText: appleText,
            finalText: finalText,
            confidence: confidence,
            processingTime: processingMetrics.whisperLatency
        )
    }
    
    private func buildContext(
        intent: ReadingIntent,
        entities: [FoundationModelsProcessor.ExtractedEntity],
        sentiment: FoundationModelsProcessor.SentimentScore,
        soundEvents: [SoundEvent],
        bookContext: Book?
    ) -> IntelligenceContext {
        return IntelligenceContext(
            intent: intent,
            entities: entities,
            sentiment: sentiment,
            soundEvents: soundEvents,
            bookContext: bookContext,
            userMood: determineUserMood(from: sentiment),
            readingPace: calculateReadingPace(from: soundEvents)
        )
    }
    
    private func determineSuggestedAction(_ context: IntelligenceContext) -> SuggestedAction {
        switch context.intent {
        case .quoteCapture:
            return SuggestedAction(
                type: .saveQuote,
                title: "Save Quote",
                description: "Highlight and save this passage to your collection",
                urgency: .immediate
            )
            
        case .question:
            return SuggestedAction(
                type: .answerQuestion,
                title: "Get Explanation",
                description: "I can help clarify this concept for you",
                urgency: .immediate
            )
            
        case .emotionalReaction:
            if context.sentiment.positive > 0.7 {
                return SuggestedAction(
                    type: .exploreEmotion,
                    title: "Explore This Feeling",
                    description: "This passage resonated with you. Want to explore why?",
                    urgency: .normal
                )
            } else {
                return SuggestedAction(
                    type: .none,
                    title: "",
                    description: "",
                    urgency: .low
                )
            }
            
        case .personalNote:
            return SuggestedAction(
                type: .addNote,
                title: "Add Note",
                description: "Save your thought about this passage",
                urgency: .normal
            )
            
        default:
            return SuggestedAction(
                type: .none,
                title: "",
                description: "",
                urgency: .low
            )
        }
    }
    
    private func calculateCombinedConfidence(
        transcription: Float,
        intent: Float,
        entities: Float
    ) -> Float {
        // Weighted average
        let weights: [Float] = [0.4, 0.4, 0.2]
        let scores: [Float] = [transcription, intent, entities]
        
        let weightedSum = zip(weights, scores).map { $0 * $1 }.reduce(0, +)
        return min(weightedSum, 1.0)
    }
    
    private func getCurrentBookContext() -> Book? {
        // Get from reading session - placeholder for now
        // TODO: Get actual book from SimplifiedAmbientCoordinator
        return nil
    }
    
    private func determineUserMood(
        from sentiment: FoundationModelsProcessor.SentimentScore
    ) -> UserMood {
        if sentiment.positive > 0.6 {
            return .engaged
        } else if sentiment.negative > 0.6 {
            return .confused
        } else {
            return .neutral
        }
    }
    
    private func calculateReadingPace(from soundEvents: [SoundEvent]) -> ReadingPace {
        let pageTurns = soundEvents.filter { $0.type == .pageTurn }.count
        
        if pageTurns > 5 {
            return .fast
        } else if pageTurns > 2 {
            return .normal
        } else {
            return .slow
        }
    }
    
    private func processSoundClassification(_ results: [SNClassificationResult]) {
        // Process sound classification results
        for result in results {
            for classification in result.classifications {
                logger.debug("Sound detected: \(classification.identifier) with confidence: \(classification.confidence)")
            }
        }
    }
}

// MARK: - Supporting Types

struct IntelligenceContext {
    let intent: ReadingIntent
    let entities: [FoundationModelsProcessor.ExtractedEntity]
    let sentiment: FoundationModelsProcessor.SentimentScore
    let soundEvents: [SoundEvent]
    let bookContext: Book?
    let userMood: UserMood
    let readingPace: ReadingPace
}

enum UserMood {
    case engaged
    case confused
    case excited
    case contemplative
    case neutral
}

enum ReadingPace {
    case fast
    case normal
    case slow
}

// MARK: - Sound Classifier Observer

class SoundClassifierObserver: NSObject, SNResultsObserving {
    private let completion: ([SNClassificationResult]) -> Void
    
    init(completion: @escaping ([SNClassificationResult]) -> Void) {
        self.completion = completion
    }
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        if let classificationResult = result as? SNClassificationResult {
            completion([classificationResult])
        }
    }
}