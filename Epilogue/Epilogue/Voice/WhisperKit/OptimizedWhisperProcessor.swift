import Foundation
import AVFoundation
import OSLog
import CoreML
import Combine
import WhisperKit
import Accelerate

private let logger = Logger(subsystem: "com.epilogue", category: "OptimizedWhisperProcessor")

// MARK: - Optimized Whisper Processor
@MainActor
class OptimizedWhisperProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var currentModel: String = "base"
    @Published var processingTime: TimeInterval = 0
    @Published var confidence: Float = 0
    @Published var isModelLoaded = false
    @Published var availableModels: [EpilogueWhisperModel] = EpilogueWhisperModel.allCases
    
    private var whisperKit: WhisperKit?
    private var modelCache: [String: WhisperKit] = [:]
    private let audioPreprocessor = AudioPreprocessor()
    
    // Configuration
    private let chunkDuration: TimeInterval = 10.0
    private let overlapDuration: TimeInterval = 1.0
    private var processedChunks: [TranscriptionChunk] = []
    
    // Performance monitoring
    private var recentProcessingTimes: [TimeInterval] = []
    private let performanceWindowSize = 5
    private let performanceThreshold: TimeInterval = 3.0 // Switch models if avg > 3 seconds
    
    struct TranscriptionChunk {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
        let tokens: [WhisperToken]
    }
    
    struct WhisperToken {
        let text: String
        let probability: Float
        let timestamp: TimeInterval?
    }
    
    // MARK: - Initialization
    
    func initialize() async throws {
        // Pre-warm the model
        try await loadOptimalModel()
    }
    
    func loadModel(_ model: EpilogueWhisperModel) async throws {
        currentModel = model.rawValue
        try await loadOptimalModel()
    }
    
    private func loadOptimalModel() async throws {
        // Determine optimal model based on device
        let deviceModel = await getDeviceCapabilities()
        let optimalModel = selectOptimalModel(for: deviceModel)
        
        logger.info("Loading optimal Whisper model: \(optimalModel)")
        
        // Create WhisperKit configuration
        let config = WhisperKitConfig(
            model: optimalModel,
            modelRepo: "argmaxinc/whisperkit-coreml" // Official repo
        )
        
        logger.info("Creating WhisperKit with config: model=\(optimalModel), repo=argmaxinc/whisperkit-coreml")
        
        do {
            // Load WhisperKit with configuration
            whisperKit = try await WhisperKit(config)
            modelCache[optimalModel] = whisperKit
            currentModel = optimalModel
            
            logger.info("WhisperKit initialized successfully with \(optimalModel) model")
            isModelLoaded = true
        } catch {
            logger.error("Failed to initialize WhisperKit: \(error)")
            logger.error("Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Optimized Transcription
    
    func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        guard isModelLoaded else {
            throw EpilogueWhisperError.modelNotLoaded
        }
        
        logger.info("transcribe called with buffer: \(audioBuffer.frameLength) frames")
        
        // Try direct transcription first for debugging
        let directResult = try await transcribeDirect(audioBuffer: audioBuffer)
        logger.info("Direct transcription result: '\(directResult.text)'")
        
        if !directResult.text.isEmpty {
            return directResult
        }
        
        // Fall back to optimized transcription
        let result = try await transcribeOptimized(audioBuffer: audioBuffer)
        
        // Convert to TranscriptionResult for compatibility
        return TranscriptionResult(
            text: result.text,
            segments: result.segments,
            language: result.language,
            languageProbability: result.languageProbability,
            timings: result.timings
        )
    }
    
    // Direct transcription for debugging
    private func transcribeDirect(audioBuffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw EpilogueWhisperError.modelNotLoaded
        }
        
        // Convert buffer to float array directly
        guard let channelData = audioBuffer.floatChannelData else {
            logger.error("No channel data in audio buffer")
            return TranscriptionResult(text: "", segments: [], language: "en", languageProbability: 0, timings: nil)
        }
        
        let frameLength = Int(audioBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        // Get format early
        let format = audioBuffer.format
        
        // Resample to 16kHz if needed
        let processedSamples: [Float]
        if format.sampleRate != 16000 {
            logger.info("Resampling audio from \(format.sampleRate) Hz to 16000 Hz")
            processedSamples = resampleAudio(samples: samples, 
                                           fromSampleRate: Float(format.sampleRate), 
                                           toSampleRate: 16000)
        } else {
            processedSamples = samples
        }
        
        // Normalize audio properly for WhisperKit
        let normalizedSamples = normalizeAudio(processedSamples)
        
        // Check buffer format details
        logger.info("Audio format: original \(format.sampleRate) Hz → resampled to 16000 Hz, \(format.channelCount) channels")
        logger.info("Direct transcription: \(normalizedSamples.count) samples (resampled), non-zero: \(normalizedSamples.filter { $0 != 0 }.count)")
        
        // Check amplitude range
        let minSample = normalizedSamples.min() ?? 0
        let maxSample = normalizedSamples.max() ?? 0
        logger.info("Audio sample range after resampling: min=\(minSample), max=\(maxSample)")
        
        // Decoding options optimized for speech (not music/sounds)
        let options = DecodingOptions(
            verbose: true, // Enable verbose for debugging
            task: DecodingTask.transcribe,
            language: "en", // Use ISO code
            temperature: 0.0, // Start with deterministic
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 3, // Try harder with different temps
            sampleLength: 224, // Standard sample length
            topK: 5,
            usePrefillPrompt: true, // Enable prefill for better results
            usePrefillCache: true,
            detectLanguage: false, // Force English
            skipSpecialTokens: true,
            withoutTimestamps: false,
            wordTimestamps: false,
            promptTokens: nil,
            prefixTokens: nil,
            suppressBlank: true,
            supressTokens: nil,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0, // More lenient
            firstTokenLogProbThreshold: -1.0,
            noSpeechThreshold: 0.3 // Lower threshold for speech detection
        )
        
        logger.info("Calling WhisperKit transcribe with \(normalizedSamples.count) samples")
        
        do {
            let results = try await whisperKit.transcribe(
                audioArray: normalizedSamples,
                decodeOptions: options,
                callback: nil
            )
            
            logger.info("WhisperKit transcribe returned \(results.count) results")
            
            // Log all results for debugging
            for (index, result) in results.enumerated() {
                logger.info("Result \(index): '\(result.text)' (segments: \(result.segments.count), avgLogprob: \(result.segments.first?.avgLogprob ?? 0))")
                // Log segment details
                for (segIndex, segment) in result.segments.enumerated() {
                    logger.info("  Segment \(segIndex): '\(segment.text)' [start: \(segment.start), end: \(segment.end), avgLogprob: \(segment.avgLogprob)]")
                    // Log tokens if available - tokens is an array of Ints (token IDs)
                    if !segment.tokens.isEmpty {
                        logger.info("    Token IDs: \(segment.tokens)")
                    }
                }
            }
            
            guard let firstResult = results.first else {
                logger.warning("WhisperKit returned empty results array")
                return TranscriptionResult(text: "", segments: [], language: "en", languageProbability: 0, timings: nil)
            }
            
            logger.info("First result: text='\(firstResult.text)', segments=\(firstResult.segments.count)")
            
            // Convert segments
            let segments = firstResult.segments.map { seg in
                TranscriptionSegment(
                    text: seg.text,
                    start: TimeInterval(seg.start),
                    end: TimeInterval(seg.end),
                    probability: exp(seg.avgLogprob)
                )
            }
            
            return TranscriptionResult(
                text: firstResult.text,
                segments: segments,
                language: firstResult.language,
                languageProbability: 0.95,
                timings: nil
            )
            
        } catch {
            logger.error("WhisperKit transcribe error: \(error)")
            logger.error("Error type: \(type(of: error))")
            if let localizedError = error as? LocalizedError {
                logger.error("Localized description: \(localizedError.localizedDescription)")
            }
            throw error
        }
    }
    
    func transcribeOptimized(audioBuffer: AVAudioPCMBuffer) async throws -> EpilogueTranscriptionResult {
        let startTime = Date()
        
        logger.info("Starting optimized transcription with buffer: \(audioBuffer.frameLength) frames, format: \(audioBuffer.format)")
        
        // 1. Preprocess audio
        guard let processedAudio = await audioPreprocessor.processAudioBuffer(audioBuffer) else {
            logger.warning("Audio preprocessing returned nil - no voice detected")
            return EpilogueTranscriptionResult(
                text: "",
                segments: [],
                language: "en",
                languageProbability: 0,
                timings: EpilogueTranscriptionTimings(
                    fullPipeline: 0,
                    vad: 0,
                    audioProcessing: 0,
                    whisperProcessing: 0
                ),
                modelUsed: currentModel
            )
        }
        
        logger.info("Preprocessed audio: \(processedAudio.samples.count) samples, hasVoice: \(processedAudio.hasVoice), confidence: \(processedAudio.confidence)")
        
        // 2. Configure decoding options for reading companion - using WhisperKit's DecodingOptions
        let decodingOptions = DecodingOptions(
            verbose: false,
            task: DecodingTask.transcribe,
            language: "en",
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            topK: 5,
            usePrefillPrompt: true,
            usePrefillCache: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            wordTimestamps: false,
            promptTokens: nil,
            prefixTokens: nil,
            suppressBlank: true,
            supressTokens: nil,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0,
            firstTokenLogProbThreshold: -1.0,
            noSpeechThreshold: 0.3
        )
        
        // 3. Process in chunks with overlap
        let chunks = createOverlappingChunks(processedAudio.samples)
        var allSegments: [TranscriptionSegment] = []
        
        // Process chunks in parallel for better performance
        if chunks.count > 1 {
            logger.info("Processing \(chunks.count) chunks in parallel")
            
            // Process chunks concurrently
            let chunkResults = await withTaskGroup(of: (Int, EpilogueTranscriptionResult?).self) { group in
                for (index, chunk) in chunks.enumerated() {
                    group.addTask {
                        do {
                            let result = try await self.processChunk(chunk, options: decodingOptions, index: index)
                            return (index, result)
                        } catch {
                            logger.error("Failed to process chunk \(index): \(error)")
                            return (index, nil)
                        }
                    }
                }
                
                // Collect results in order
                var results: [(Int, EpilogueTranscriptionResult?)] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }
            }
            
            // Combine segments in order
            for (_, result) in chunkResults {
                if let result = result {
                    allSegments.append(contentsOf: result.segments)
                }
            }
        } else {
            // Single chunk - process normally
            for (index, chunk) in chunks.enumerated() {
                do {
                    let chunkResult = try await processChunk(chunk, options: decodingOptions, index: index)
                    allSegments.append(contentsOf: chunkResult.segments)
                } catch {
                    logger.error("Failed to process chunk \(index): \(error)")
                }
            }
        }
        
        // 4. Merge chunks intelligently
        let mergedResult = mergeTranscriptionChunks(allSegments)
        
        // 5. Calculate metrics
        let endTime = Date()
        processingTime = endTime.timeIntervalSince(startTime)
        confidence = calculateConfidence(from: mergedResult)
        
        logger.info("Transcription completed in \(String(format: "%.2f", self.processingTime))s with confidence: \(self.confidence)")
        
        // Monitor performance and switch models if needed
        await monitorPerformanceAndAdaptModel(processingTime: processingTime)
        
        return EpilogueTranscriptionResult(
            text: mergedResult.text,
            segments: mergedResult.segments,
            language: "en",
            languageProbability: 0.95,
            timings: EpilogueTranscriptionTimings(
                fullPipeline: processingTime,
                vad: audioPreprocessor.getAudioStatistics().voiceActivity > 0 ? 0.1 : 0,
                audioProcessing: 0.05,
                whisperProcessing: processingTime * 0.9
            ),
            modelUsed: currentModel
        )
    }
    
    // MARK: - Chunk Processing
    
    private func createOverlappingChunks(_ samples: [Float]) -> [[Float]] {
        let sampleRate = 16000
        let chunkSize = Int(chunkDuration * Double(sampleRate))
        let overlapSize = Int(overlapDuration * Double(sampleRate))
        let stepSize = chunkSize - overlapSize
        
        var chunks: [[Float]] = []
        var startIndex = 0
        
        while startIndex < samples.count {
            let endIndex = min(startIndex + chunkSize, samples.count)
            let chunk = Array(samples[startIndex..<endIndex])
            
            // Pad if necessary
            if chunk.count < chunkSize {
                var paddedChunk = chunk
                paddedChunk.append(contentsOf: Array(repeating: 0, count: chunkSize - chunk.count))
                chunks.append(paddedChunk)
            } else {
                chunks.append(chunk)
            }
            
            startIndex += stepSize
            
            // Stop if we've processed everything
            if endIndex == samples.count {
                break
            }
        }
        
        return chunks
    }
    
    private func processChunk(_ samples: [Float], options: DecodingOptions, index: Int) async throws -> EpilogueTranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw EpilogueWhisperError.modelNotLoaded
        }
        
        // Convert to audio array format expected by WhisperKit
        let audioArray = samples
        
        // Process with WhisperKit - it returns an array of results
        logger.debug("Processing chunk \(index) with \(audioArray.count) samples")
        
        // Validate audio samples
        let nonZeroSamples = audioArray.filter { $0 != 0 }.count
        logger.info("Chunk \(index): \(nonZeroSamples) non-zero samples out of \(audioArray.count) total")
        
        // Check sample range
        let minSample = audioArray.min() ?? 0
        let maxSample = audioArray.max() ?? 0
        logger.info("Chunk \(index) audio range: min=\(minSample), max=\(maxSample)")
        
        // Create WhisperKit DecodingOptions - just pass through since we're already using WhisperKit's type
        let whisperOptions = options
        
        logger.info("Starting WhisperKit transcribe for chunk \(index)...")
        let results = try await whisperKit.transcribe(
            audioArray: audioArray,
            decodeOptions: whisperOptions,
            callback: nil
        )
        logger.info("WhisperKit returned \(results.count) results for chunk \(index)")
        
        // Get the first result (WhisperKit returns an array)
        guard let firstResult = results.first else {
            logger.warning("No results from WhisperKit for chunk \(index)")
            return EpilogueTranscriptionResult(
                text: "",
                segments: [],
                language: "en",
                languageProbability: 0,
                timings: EpilogueTranscriptionTimings(
                    fullPipeline: 0,
                    vad: 0,
                    audioProcessing: 0,
                    whisperProcessing: 0
                ),
                modelUsed: currentModel
            )
        }
        
        logger.debug("WhisperKit result for chunk \(index): text='\(firstResult.text)', segments=\(firstResult.segments.count)")
        
        // Check if we got a result
        guard !firstResult.text.isEmpty else {
            logger.warning("Empty result from WhisperKit for chunk \(index)")
            return EpilogueTranscriptionResult(
                text: "",
                segments: [],
                language: "en",
                languageProbability: 0,
                timings: EpilogueTranscriptionTimings(
                    fullPipeline: 0,
                    vad: 0,
                    audioProcessing: 0,
                    whisperProcessing: 0
                ),
                modelUsed: currentModel
            )
        }
        
        // Convert WhisperKit segments to our segments
        let ourSegments = firstResult.segments.map { whkSegment in
            TranscriptionSegment(
                text: whkSegment.text,
                start: TimeInterval(whkSegment.start),
                end: TimeInterval(whkSegment.end),
                probability: exp(whkSegment.avgLogprob) // Convert log probability to probability
            )
        }
        
        // Store chunk for later reference
        let chunk = TranscriptionChunk(
            text: firstResult.text,
            startTime: Double(index) * (chunkDuration - overlapDuration),
            endTime: Double(index) * (chunkDuration - overlapDuration) + chunkDuration,
            confidence: calculateSegmentConfidence(ourSegments),
            tokens: [] // We'll skip token extraction for now
        )
        
        processedChunks.append(chunk)
        
        // Convert timings if available
        let timings: EpilogueTranscriptionTimings
        let whkTimings = firstResult.timings // This is not optional
        timings = EpilogueTranscriptionTimings(
            fullPipeline: whkTimings.fullPipeline,
            vad: 0.0, // VAD is handled separately in our pipeline
            audioProcessing: whkTimings.audioProcessing,
            whisperProcessing: whkTimings.encoding + whkTimings.decodingLoop // Combine encoding and decoding time
        )
        
        // Convert to EpilogueTranscriptionResult
        return EpilogueTranscriptionResult(
            text: firstResult.text,
            segments: ourSegments,
            language: firstResult.language,
            languageProbability: 0.95, // WhisperKit doesn't expose this directly
            timings: timings,
            modelUsed: currentModel
        )
    }
    
    // MARK: - Intelligent Merging
    
    private func mergeTranscriptionChunks(_ segments: [TranscriptionSegment]) -> (text: String, segments: [TranscriptionSegment]) {
        // Remove duplicates from overlapping regions
        var mergedSegments: [TranscriptionSegment] = []
        var processedText = Set<String>()
        
        for segment in segments.sorted(by: { $0.start < $1.start }) {
            let segmentText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip if we've already processed similar text
            if !processedText.contains(segmentText) && !segmentText.isEmpty {
                processedText.insert(segmentText)
                mergedSegments.append(segment)
            }
        }
        
        // Build final text
        let finalText = mergedSegments
            .map { $0.text }
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (finalText, mergedSegments)
    }
    
    // MARK: - Confidence Scoring
    
    private func calculateConfidence(from result: (text: String, segments: [TranscriptionSegment])) -> Float {
        guard !result.segments.isEmpty else { return 0 }
        
        // Average probability
        let avgProb = result.segments
            .map { $0.probability }
            .reduce(0, +) / Float(result.segments.count)
        
        return avgProb
    }
    
    private func calculateSegmentConfidence(_ segments: [TranscriptionSegment]) -> Float {
        guard !segments.isEmpty else { return 0 }
        
        let probabilities = segments.map { $0.probability }
        return probabilities.reduce(0, +) / Float(probabilities.count)
    }
    
    private func extractTokens(from segments: [TranscriptionSegment]) -> [WhisperToken] {
        // Extract token-level information if available
        return segments.flatMap { segment in
            // Convert segment words to tokens
            let words = segment.text.split(separator: " ")
            return words.map { word in
                WhisperToken(
                    text: String(word),
                    probability: segment.probability,
                    timestamp: segment.start
                )
            }
        }
    }
    
    // MARK: - Device Optimization
    
    private func getDeviceCapabilities() async -> DeviceCapabilities {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let cpuCount = ProcessInfo.processInfo.processorCount
        
        // Check for Neural Engine
        let hasNeuralEngine = true // All modern iOS devices have ANE
        
        return DeviceCapabilities(
            memoryGB: Int(totalMemory / 1_073_741_824),
            cpuCores: cpuCount,
            hasNeuralEngine: hasNeuralEngine
        )
    }
    
    private func selectOptimalModel(for device: DeviceCapabilities) -> String {
        // Dynamic model selection based on device capabilities
        logger.info("Device capabilities: \(device.memoryGB)GB RAM, \(device.cpuCores) cores, Neural Engine: \(device.hasNeuralEngine)")
        
        // Note: Medium and Large models are typically too resource-intensive for mobile devices
        // Only use them if explicitly requested by the user
        
        // For high-end devices (iPhone 15 Pro, iPad Pro, etc.)
        if device.memoryGB >= 8 && device.cpuCores >= 8 {
            logger.info("High-end device detected, using base model for better accuracy")
            return "base"
        }
        // For mid-range devices (iPhone 14, iPhone 13, etc.)
        else if device.memoryGB >= 6 {
            logger.info("Mid-range device detected, using small model for balance")
            return "small"
        }
        // For lower-end devices or when conserving resources
        else {
            logger.info("Lower-end device detected, using tiny model for performance")
            return "tiny"
        }
    }
    
    // MARK: - Performance Monitoring
    
    func monitorPerformanceAndAdaptModel(processingTime: TimeInterval) async {
        // Add to recent processing times
        recentProcessingTimes.append(processingTime)
        if recentProcessingTimes.count > performanceWindowSize {
            recentProcessingTimes.removeFirst()
        }
        
        // Calculate average processing time
        let avgProcessingTime = recentProcessingTimes.reduce(0, +) / Double(recentProcessingTimes.count)
        
        logger.info("Average processing time: \(String(format: "%.2f", avgProcessingTime))s (threshold: \(self.performanceThreshold)s)")
        
        // Switch to a lighter model if performance is poor
        if avgProcessingTime > performanceThreshold && recentProcessingTimes.count >= performanceWindowSize {
            let currentModelEnum = EpilogueWhisperModel(rawValue: currentModel) ?? .base
            
            switch currentModelEnum {
            case .large:
                logger.warning("Performance is slow with large model, switching to medium")
                try? await loadModel(.medium)
                recentProcessingTimes.removeAll()
            case .medium:
                logger.warning("Performance is slow with medium model, switching to base")
                try? await loadModel(.base)
                recentProcessingTimes.removeAll()
            case .base:
                logger.warning("Performance is slow with base model, switching to small")
                try? await loadModel(.small)
                recentProcessingTimes.removeAll() // Reset after model switch
            case .small:
                logger.warning("Performance is slow with small model, switching to tiny")
                try? await loadModel(.tiny)
                recentProcessingTimes.removeAll()
            case .tiny:
                logger.info("Already using tiny model, cannot downgrade further")
            }
        } else if avgProcessingTime < performanceThreshold / 2 && recentProcessingTimes.count >= performanceWindowSize {
            // Consider upgrading if performance is very good
            let currentModelEnum = EpilogueWhisperModel(rawValue: currentModel) ?? .tiny
            
            switch currentModelEnum {
            case .tiny:
                logger.info("Performance is excellent with tiny model, considering upgrade to small")
                // Only upgrade if device has sufficient resources
                let device = await getDeviceCapabilities()
                if device.memoryGB >= 6 {
                    try? await loadModel(.small)
                    recentProcessingTimes.removeAll()
                }
            case .small:
                logger.info("Performance is excellent with small model, considering upgrade to base")
                let device = await getDeviceCapabilities()
                if device.memoryGB >= 8 {
                    try? await loadModel(.base)
                    recentProcessingTimes.removeAll()
                }
            case .base:
                logger.info("Performance is excellent with base model, considering upgrade to medium")
                let device = await getDeviceCapabilities()
                if device.memoryGB >= 12 {
                    try? await loadModel(.medium)
                    recentProcessingTimes.removeAll()
                }
            case .medium:
                logger.info("Performance is excellent with medium model, considering upgrade to large")
                let device = await getDeviceCapabilities()
                if device.memoryGB >= 16 {
                    try? await loadModel(.large)
                    recentProcessingTimes.removeAll()
                }
            case .large:
                logger.info("Already using best model")
            }
        }
    }
    
    // MARK: - Cache Management
    
    func preloadModel(_ model: String) async throws {
        guard modelCache[model] == nil else { return }
        
        logger.info("Preloading \(model) model")
        
        let config = WhisperKitConfig(
            model: model,
            modelRepo: "argmaxinc/whisperkit-coreml"
        )
        
        let whisperInstance = try await WhisperKit(config)
        modelCache[model] = whisperInstance
    }
    
    func clearCache() {
        modelCache.removeAll()
        processedChunks.removeAll()
    }
    
    // MARK: - Testing
    
    func testTranscription() async throws -> String {
        guard let whisperKit = whisperKit else {
            throw EpilogueWhisperError.modelNotLoaded
        }
        
        logger.info("Running WhisperKit test transcription...")
        
        // Generate test speech-like audio (not a pure tone)
        let testAudio = generateTestSpeech()
        
        logger.info("Test audio: \(testAudio.count) samples at 16000 Hz")
        
        // Use the same options as regular transcription
        let options = DecodingOptions(
            verbose: true,
            task: DecodingTask.transcribe,
            language: "en",
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            topK: 5,
            usePrefillPrompt: true,
            usePrefillCache: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            wordTimestamps: false,
            promptTokens: nil,
            prefixTokens: nil,
            suppressBlank: true,
            supressTokens: nil,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0,
            firstTokenLogProbThreshold: -1.0,
            noSpeechThreshold: 0.3
        )
        
        let results = try await whisperKit.transcribe(
            audioArray: testAudio,
            decodeOptions: options
        )
        
        logger.info("Test results: \(results.count) results")
        
        if let firstResult = results.first {
            logger.info("Test transcription: '\(firstResult.text)'")
            
            if firstResult.text == "[BLANK_AUDIO]" {
                logger.error("ERROR: Whisper still returning blank for test audio")
                // Try with different parameters
                logger.info("Trying with different decoding parameters...")
                
                let altOptions = DecodingOptions(
                    verbose: true,
                    task: DecodingTask.transcribe,
                    language: "en",
                    temperature: 0.8,
                    noSpeechThreshold: 0.1
                )
                
                let altResults = try await whisperKit.transcribe(
                    audioArray: testAudio,
                    decodeOptions: altOptions
                )
                
                if let altResult = altResults.first {
                    logger.info("Alternative test transcription: '\(altResult.text)'")
                    return altResult.text
                }
            }
            
            return firstResult.text
        }
        
        return "No transcription"
    }
    
    // Generate speech-like test audio
    private func generateTestSpeech() -> [Float] {
        let sampleRate: Float = 16000
        let duration: Float = 3.0
        let sampleCount = Int(sampleRate * duration)
        
        var testAudio = [Float](repeating: 0, count: sampleCount)
        
        // Generate speech-like patterns with multiple formants
        let fundamentalFreq: Float = 125.0 // Male voice fundamental
        let formants: [(freq: Float, amp: Float)] = [
            (700, 0.3),   // F1
            (1220, 0.2),  // F2
            (2600, 0.1)   // F3
        ]
        
        for i in 0..<sampleCount {
            var sample: Float = 0
            
            // Add fundamental frequency
            sample += 0.2 * sin(2.0 * Float.pi * fundamentalFreq * Float(i) / sampleRate)
            
            // Add formants
            for formant in formants {
                sample += formant.amp * sin(2.0 * Float.pi * formant.freq * Float(i) / sampleRate)
            }
            
            // Add some noise for realism
            sample += 0.02 * Float.random(in: -1...1)
            
            // Apply envelope (fade in/out)
            let envelope: Float
            if i < sampleCount / 10 {
                envelope = Float(i) / Float(sampleCount / 10)
            } else if i > sampleCount * 9 / 10 {
                envelope = Float(sampleCount - i) / Float(sampleCount / 10)
            } else {
                envelope = 1.0
            }
            
            testAudio[i] = sample * envelope
        }
        
        // Normalize
        return normalizeAudio(testAudio)
    }
    
    // MARK: - Post-Processing
    
    func applyReadingContextPostProcessing(_ text: String, bookContext: BookContext?) -> String {
        var processedText = text
        
        // Add custom vocabulary if available
        if let customTerms = bookContext?.customVocabulary {
            for term in customTerms {
                // Case-insensitive replacement with proper casing
                let pattern = "\\b\(term.lowercased())\\b"
                processedText = processedText.replacingOccurrences(
                    of: pattern,
                    with: term,
                    options: [.regularExpression, .caseInsensitive]
                )
            }
        }
        
        // Fix common transcription errors for reading
        let corrections = [
            "gonna": "going to",
            "wanna": "want to",
            "gotta": "got to",
            "[BLANK_AUDIO]": "",
            "[INAUDIBLE]": "..."
        ]
        
        for (wrong, right) in corrections {
            processedText = processedText.replacingOccurrences(of: wrong, with: right)
        }
        
        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Audio Resampling
    
    private func resampleAudio(samples: [Float], fromSampleRate: Float, toSampleRate: Float) -> [Float] {
        let ratio = toSampleRate / fromSampleRate
        let outputLength = Int(Float(samples.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)
        
        // Use vDSP for high-quality resampling
        var inputPointer: Float = 0.0
        let increment = 1.0 / ratio
        
        for i in 0..<outputLength {
            let inputIndex = Int(inputPointer)
            let fraction = inputPointer - Float(inputIndex)
            
            if inputIndex < samples.count - 1 {
                // Linear interpolation between samples
                output[i] = samples[inputIndex] * (1.0 - fraction) + samples[inputIndex + 1] * fraction
            } else if inputIndex < samples.count {
                output[i] = samples[inputIndex]
            }
            
            inputPointer += increment
        }
        
        // Apply a low-pass filter to prevent aliasing
        if ratio < 1.0 {
            // Downsampling - apply anti-aliasing filter
            let cutoffFrequency = toSampleRate * 0.45 // Nyquist frequency with margin
            output = applyLowPassFilter(samples: output, sampleRate: toSampleRate, cutoffFrequency: cutoffFrequency)
        }
        
        logger.info("Resampled \(samples.count) samples at \(fromSampleRate)Hz to \(output.count) samples at \(toSampleRate)Hz")
        return output
    }
    
    private func applyLowPassFilter(samples: [Float], sampleRate: Float, cutoffFrequency: Float) -> [Float] {
        // Simple Butterworth low-pass filter
        let RC = 1.0 / (2.0 * Float.pi * cutoffFrequency)
        let dt = 1.0 / sampleRate
        let alpha = dt / (RC + dt)
        
        var filtered = [Float](repeating: 0, count: samples.count)
        filtered[0] = samples[0]
        
        for i in 1..<samples.count {
            filtered[i] = filtered[i-1] + alpha * (samples[i] - filtered[i-1])
        }
        
        return filtered
    }
    
    // MARK: - Audio Normalization
    
    private func normalizeAudio(_ samples: [Float]) -> [Float] {
        // Calculate RMS (Root Mean Square) for more accurate level detection
        let squaredSum = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(squaredSum / Float(samples.count))
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0.0001
        
        logger.info("Audio normalization: RMS = \(rms), max amplitude = \(maxAmplitude)")
        
        // Use RMS-based normalization for better results
        if rms < 0.01 {
            // Very quiet audio - scale based on RMS
            let targetRMS: Float = 0.1
            let scaleFactor = targetRMS / max(rms, 0.0001)
            logger.info("Scaling up quiet audio (RMS-based) by factor: \(scaleFactor)")
            
            // Apply scaling with soft limiting to prevent clipping
            return samples.map { sample in
                let scaled = sample * scaleFactor
                // Soft limiting using tanh to prevent harsh clipping
                return tanh(scaled * 0.7) / 0.7
            }
        } else if maxAmplitude > 0.95 {
            // Only scale down if clipping
            let scaleFactor = 0.9 / maxAmplitude
            logger.info("Scaling down loud audio by factor: \(scaleFactor)")
            return samples.map { $0 * scaleFactor }
        } else if rms > 0.3 {
            // Audio might be too loud (even if not clipping)
            let targetRMS: Float = 0.2
            let scaleFactor = targetRMS / rms
            logger.info("Scaling down loud audio (RMS-based) by factor: \(scaleFactor)")
            return samples.map { $0 * scaleFactor }
        }
        
        // Otherwise, leave audio as-is
        logger.info("Audio levels are good, no normalization needed")
        return samples
    }
}

// MARK: - Supporting Types

struct DeviceCapabilities {
    let memoryGB: Int
    let cpuCores: Int
    let hasNeuralEngine: Bool
}

struct BookContext {
    let title: String
    let author: String
    let genre: String
    let customVocabulary: [String]?
}