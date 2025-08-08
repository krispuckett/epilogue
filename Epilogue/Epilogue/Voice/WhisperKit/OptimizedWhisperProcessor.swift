import Foundation
import AVFoundation
import OSLog
import CoreML
import Combine
import WhisperKit
import Accelerate
import Speech

private let logger = Logger(subsystem: "com.epilogue", category: "OptimizedWhisperProcessor")

// MARK: - Optimized Whisper Processor
@MainActor
class OptimizedWhisperProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var currentModel: String = "tiny"
    @Published var processingTime: TimeInterval = 0
    @Published var confidence: Float = 0
    @Published var isModelLoaded = false
    @Published var availableModels: [EpilogueWhisperModel] = EpilogueWhisperModel.allCases
    @Published var audioQualityStatus: AudioQualityStatus = .good
    
    private var whisperKit: WhisperKit?
    private var modelCache: [String: WhisperKit] = [:]
    private let audioPreprocessor = AudioPreprocessor()
    private var fallbackRecognizer: SFSpeechRecognizer?
    
    // Configuration
    private let chunkDuration: TimeInterval = 5.0  // Reduced to 5 seconds for faster processing
    private let overlapDuration: TimeInterval = 1.0
    private var processedChunks: [TranscriptionChunk] = []
    
    // Performance monitoring
    private var recentProcessingTimes: [TimeInterval] = []
    private let performanceWindowSize = 5
    private let performanceThreshold: TimeInterval = 2.0 // Switch models if avg > 2 seconds
    
    // Audio quality thresholds
    private let minConfidenceThreshold: Float = 0.5
    private let blankAudioThreshold: Float = 0.01
    
    enum AudioQualityStatus {
        case good
        case low
        case noVoice
        case tooQuiet
    }
    
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
        // Initialize fallback recognizer
        fallbackRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        // Pre-warm the model with adaptive selection
        try await loadOptimalModel()
    }
    
    func loadModel(_ model: EpilogueWhisperModel) async throws {
        currentModel = model.rawValue
        try await loadOptimalModel()
    }
    
    private func loadOptimalModel() async throws {
        // Determine optimal model based on device capabilities
        let deviceModel = await getDeviceCapabilities()
        let optimalModel = selectOptimalModel(for: deviceModel)
        
        logger.info("Loading optimal Whisper model: \(optimalModel)")
        
        // Check cache first
        if let cachedKit = modelCache[optimalModel] {
            whisperKit = cachedKit
            currentModel = optimalModel
            isModelLoaded = true
            logger.info("Using cached WhisperKit model: \(optimalModel)")
            return
        }
        
        // Create WhisperKit configuration
        let config = WhisperKitConfig(
            model: optimalModel,
            modelRepo: "argmaxinc/whisperkit-coreml"
        )
        
        logger.info("Creating WhisperKit with config: model=\(optimalModel)")
        
        do {
            // Load WhisperKit with configuration
            whisperKit = try await WhisperKit(config)
            modelCache[optimalModel] = whisperKit
            currentModel = optimalModel
            
            logger.info("WhisperKit initialized successfully with \(optimalModel) model")
            isModelLoaded = true
        } catch {
            logger.error("Failed to initialize WhisperKit: \(error)")
            
            // Try fallback to tiny model if optimal model fails
            if optimalModel != "tiny" {
                logger.info("Falling back to tiny model")
                currentModel = "tiny"
                let fallbackConfig = WhisperKitConfig(
                    model: "tiny",
                    modelRepo: "argmaxinc/whisperkit-coreml"
                )
                whisperKit = try await WhisperKit(fallbackConfig)
                modelCache["tiny"] = whisperKit
                isModelLoaded = true
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Optimized Transcription with Quality Detection
    
    func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        guard isModelLoaded else {
            throw EpilogueWhisperError.modelNotLoaded
        }
        
        let startTime = Date()
        logger.info("Starting transcription with buffer: \(audioBuffer.frameLength) frames")
        
        // 1. Pre-process audio correctly
        let processedAudio = try preprocessAudio(audioBuffer)
        
        // 2. Check audio quality
        let quality = analyzeAudioQuality(processedAudio)
        audioQualityStatus = quality
        
        // Log audio statistics for debugging
        logAudioStatistics(processedAudio)
        
        // 3. Handle poor quality audio
        switch quality {
        case .tooQuiet:
            logger.warning("Audio too quiet, requesting user to speak louder")
            throw EpilogueWhisperError.audioTooQuiet("Please speak louder for better recognition")
            
        case .noVoice:
            logger.warning("No voice detected, falling back to Apple Speech")
            return try await fallbackToAppleSpeech(audioBuffer)
            
        case .low:
            logger.info("Low quality audio detected, using enhanced processing")
            // Continue with enhanced processing options
            break
            
        case .good:
            logger.info("Good audio quality detected")
            break
        }
        
        // 4. Process in chunks with parallel processing
        let result = try await processChunkedAudio(processedAudio)
        
        // 5. Monitor performance and adapt model
        let processingTime = Date().timeIntervalSince(startTime)
        await updatePerformanceMetrics(processingTime)
        
        // 6. Check if we need to switch models
        if shouldSwitchModel() {
            Task {
                try await adaptModelBasedOnPerformance()
            }
        }
        
        return result
    }
    
    // MARK: - Audio Pre-processing
    
    private func preprocessAudio(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            throw EpilogueWhisperError.invalidAudioBuffer
        }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        let format = buffer.format
        
        // 1. Resample to 16kHz if needed
        let resampledSamples: [Float]
        if format.sampleRate != 16000 {
            logger.info("Resampling from \(format.sampleRate)Hz to 16000Hz")
            resampledSamples = resampleAudioHighQuality(
                samples: samples,
                fromSampleRate: Float(format.sampleRate),
                toSampleRate: 16000
            )
        } else {
            resampledSamples = samples
        }
        
        // 2. Normalize to [-1, 1] range properly
        let normalizedSamples = normalizeAudioProperly(resampledSamples)
        
        // 3. Apply Voice Activity Detection (VAD)
        let vadSamples = applyVAD(normalizedSamples)
        
        return vadSamples
    }
    
    private func normalizeAudioProperly(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }
        
        // Calculate statistics
        var sum: Float = 0
        var sumSquares: Float = 0
        vDSP_sve(samples, 1, &sum, vDSP_Length(samples.count))
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        
        let mean = sum / Float(samples.count)
        let rms = sqrt(sumSquares / Float(samples.count))
        
        // Find peak amplitude
        var maxValue: Float = 0
        vDSP_maxmgv(samples, 1, &maxValue, vDSP_Length(samples.count))
        
        logger.info("Audio stats - Mean: \(mean), RMS: \(rms), Peak: \(maxValue)")
        
        // Remove DC offset
        var centeredSamples = samples
        var negativeMean = -mean
        vDSP_vsadd(samples, 1, &negativeMean, &centeredSamples, 1, vDSP_Length(samples.count))
        
        // Normalize based on peak or RMS
        var normalizedSamples = centeredSamples
        
        if maxValue > 0.001 {
            // Use peak normalization with headroom
            let targetPeak: Float = 0.95 // Leave some headroom
            var scaleFactor = targetPeak / maxValue
            
            // Apply scaling
            vDSP_vsmul(centeredSamples, 1, &scaleFactor, &normalizedSamples, 1, vDSP_Length(samples.count))
            
            logger.info("Applied peak normalization with factor: \(scaleFactor)")
        } else if rms > 0.001 {
            // Use RMS normalization for very quiet audio
            let targetRMS: Float = 0.2
            var scaleFactor = targetRMS / rms
            
            // Apply scaling with limiting
            vDSP_vsmul(centeredSamples, 1, &scaleFactor, &normalizedSamples, 1, vDSP_Length(samples.count))
            
            // Apply soft limiting to prevent clipping
            normalizedSamples = normalizedSamples.map { sample in
                if abs(sample) > 0.95 {
                    return 0.95 * (sample > 0 ? 1 : -1) * (1.0 - exp(-abs(sample)))
                }
                return sample
            }
            
            logger.info("Applied RMS normalization with factor: \(scaleFactor)")
        }
        
        return normalizedSamples
    }
    
    private func resampleAudioHighQuality(samples: [Float], fromSampleRate: Float, toSampleRate: Float) -> [Float] {
        let ratio = toSampleRate / fromSampleRate
        let outputLength = Int(Float(samples.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)
        
        // Use Lanczos resampling for better quality
        let a = 3 // Lanczos parameter
        
        for i in 0..<outputLength {
            let inputPosition = Float(i) / ratio
            let inputIndex = Int(inputPosition)
            let fraction = inputPosition - Float(inputIndex)
            
            var sum: Float = 0
            var weightSum: Float = 0
            
            // Apply Lanczos kernel
            for j in -a+1...a {
                let sampleIndex = inputIndex + j
                if sampleIndex >= 0 && sampleIndex < samples.count {
                    let x = Float(j) - fraction
                    let weight = lanczosKernel(x, a: Float(a))
                    sum += samples[sampleIndex] * weight
                    weightSum += weight
                }
            }
            
            output[i] = weightSum > 0 ? sum / weightSum : 0
        }
        
        return output
    }
    
    private func lanczosKernel(_ x: Float, a: Float) -> Float {
        if x == 0 { return 1 }
        if abs(x) >= a { return 0 }
        
        let piX = Float.pi * x
        let piXOverA = piX / a
        return (sin(piX) / piX) * (sin(piXOverA) / piXOverA)
    }
    
    private func applyVAD(_ samples: [Float]) -> [Float] {
        // Simple energy-based VAD with adaptive threshold
        let windowSize = 160 // 10ms at 16kHz
        let hopSize = 80 // 5ms hop
        
        var vadFlags = [Bool](repeating: false, count: samples.count)
        var energyValues: [Float] = []
        
        // Calculate energy for each window
        for i in stride(from: 0, to: samples.count - windowSize, by: hopSize) {
            let window = Array(samples[i..<i+windowSize])
            var energy: Float = 0
            vDSP_svesq(window, 1, &energy, vDSP_Length(windowSize))
            energyValues.append(energy / Float(windowSize))
        }
        
        // Calculate adaptive threshold
        let sortedEnergies = energyValues.sorted()
        let percentile20 = sortedEnergies[Int(Float(sortedEnergies.count) * 0.2)]
        let percentile80 = sortedEnergies[Int(Float(sortedEnergies.count) * 0.8)]
        let threshold = percentile20 + 0.1 * (percentile80 - percentile20)
        
        // Apply VAD flags
        for (i, energy) in energyValues.enumerated() {
            if energy > threshold {
                let startIdx = i * hopSize
                let endIdx = min(startIdx + windowSize, samples.count)
                for j in startIdx..<endIdx {
                    vadFlags[j] = true
                }
            }
        }
        
        // Apply morphological operations to clean up VAD
        vadFlags = applyMorphologicalOperations(vadFlags)
        
        // Extract voice segments with context
        var processedSamples = samples
        for i in 0..<samples.count {
            if !vadFlags[i] {
                processedSamples[i] *= 0.1 // Attenuate non-voice regions
            }
        }
        
        return processedSamples
    }
    
    private func applyMorphologicalOperations(_ flags: [Bool]) -> [Bool] {
        var result = flags
        
        // Closing operation (dilation followed by erosion)
        let kernelSize = 80 // 5ms at 16kHz
        
        // Dilation
        for i in 0..<flags.count {
            if flags[i] {
                for j in max(0, i-kernelSize)...min(flags.count-1, i+kernelSize) {
                    result[j] = true
                }
            }
        }
        
        // Erosion
        var eroded = result
        for i in kernelSize..<(flags.count-kernelSize) {
            var allTrue = true
            for j in (i-kernelSize)...(i+kernelSize) {
                if !result[j] {
                    allTrue = false
                    break
                }
            }
            eroded[i] = allTrue
        }
        
        return eroded
    }
    
    // MARK: - Chunked Processing
    
    private func processChunkedAudio(_ samples: [Float]) async throws -> TranscriptionResult {
        let chunks = createOverlappingChunks(samples)
        
        logger.info("Processing \(chunks.count) chunks")
        
        // Process chunks in parallel for speed
        let transcriptionTasks = chunks.enumerated().map { index, chunk in
            Task {
                try await transcribeChunk(chunk, index: index)
            }
        }
        
        // Wait for all chunks to complete
        var allSegments: [TranscriptionSegment] = []
        for task in transcriptionTasks {
            if let result = try await task.value {
                allSegments.append(contentsOf: result.segments)
            }
        }
        
        // Merge results intelligently
        let mergedResult = mergeTranscriptionSegments(allSegments)
        
        return TranscriptionResult(
            text: mergedResult.text,
            segments: mergedResult.segments,
            language: "en",
            languageProbability: calculateOverallConfidence(mergedResult.segments),
            timings: nil
        )
    }
    
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
            
            // Only add chunks with sufficient length
            if chunk.count >= sampleRate { // At least 1 second
                chunks.append(chunk)
            }
            
            startIndex += stepSize
        }
        
        return chunks
    }
    
    private func transcribeChunk(_ chunk: [Float], index: Int) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else {
            throw EpilogueWhisperError.modelNotLoaded
        }
        
        // Configure decoding options for optimal quality
        let options = DecodingOptions(
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
            wordTimestamps: true, // Enable word-level timestamps
            promptTokens: nil,
            prefixTokens: nil,
            suppressBlank: true,
            supressTokens: nil,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0,
            firstTokenLogProbThreshold: -1.0,
            noSpeechThreshold: 0.3
        )
        
        do {
            let results = try await whisperKit.transcribe(
                audioArray: chunk,
                decodeOptions: options,
                callback: nil
            )
            
            guard let firstResult = results.first, !firstResult.text.isEmpty else {
                logger.info("Empty result for chunk \(index)")
                return nil
            }
            
            // Calculate chunk offset
            let chunkOffset = Double(index) * (chunkDuration - overlapDuration)
            
            // Convert segments with proper timestamps
            let segments = firstResult.segments.map { seg in
                TranscriptionSegment(
                    text: seg.text,
                    start: TimeInterval(seg.start) + chunkOffset,
                    end: TimeInterval(seg.end) + chunkOffset,
                    probability: exp(seg.avgLogprob)
                )
            }
            
            // Store chunk for quality analysis
            let chunkInfo = TranscriptionChunk(
                text: firstResult.text,
                startTime: chunkOffset,
                endTime: chunkOffset + chunkDuration,
                confidence: calculateSegmentConfidence(segments),
                tokens: []
            )
            processedChunks.append(chunkInfo)
            
            return TranscriptionResult(
                text: firstResult.text,
                segments: segments,
                language: firstResult.language,
                languageProbability: 0.95,
                timings: nil
            )
            
        } catch {
            logger.error("Error transcribing chunk \(index): \(error)")
            return nil
        }
    }
    
    private func mergeTranscriptionSegments(_ segments: [TranscriptionSegment]) -> (text: String, segments: [TranscriptionSegment]) {
        // Remove duplicates from overlapping regions
        var mergedSegments: [TranscriptionSegment] = []
        var processedRanges: [(start: TimeInterval, end: TimeInterval)] = []
        
        for segment in segments.sorted(by: { $0.start < $1.start }) {
            // Check if this segment overlaps with already processed segments
            var isOverlapping = false
            for range in processedRanges {
                if segment.start >= range.start && segment.start < range.end {
                    isOverlapping = true
                    break
                }
            }
            
            if !isOverlapping {
                mergedSegments.append(segment)
                processedRanges.append((start: segment.start, end: segment.end))
            }
        }
        
        // Build final text
        let finalText = mergedSegments
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return (finalText, mergedSegments)
    }
    
    // MARK: - Quality Detection
    
    private func analyzeAudioQuality(_ samples: [Float]) -> AudioQualityStatus {
        // Calculate RMS and peak levels
        var sumSquares: Float = 0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        let rms = sqrt(sumSquares / Float(samples.count))
        
        var maxValue: Float = 0
        vDSP_maxmgv(samples, 1, &maxValue, vDSP_Length(samples.count))
        
        logger.info("Audio quality - RMS: \(rms), Peak: \(maxValue)")
        
        // Check for blank audio
        if rms < blankAudioThreshold {
            return .noVoice
        }
        
        // Check if too quiet
        if rms < 0.05 {
            return .tooQuiet
        }
        
        // Check signal quality
        let snr = calculateSNR(samples)
        if snr < 10 { // Less than 10dB SNR
            return .low
        }
        
        return .good
    }
    
    private func calculateSNR(_ samples: [Float]) -> Float {
        // Simple SNR estimation using high-pass filter
        let windowSize = 1600 // 100ms at 16kHz
        var signalPower: Float = 0
        var noisePower: Float = 0
        
        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize) {
            let window = Array(samples[i..<i+windowSize])
            
            var energy: Float = 0
            vDSP_svesq(window, 1, &energy, vDSP_Length(windowSize))
            energy /= Float(windowSize)
            
            // Assume lowest 20% is noise
            if energy < 0.01 {
                noisePower += energy
            } else {
                signalPower += energy
            }
        }
        
        guard noisePower > 0 else { return 40 } // High SNR if no noise detected
        
        return 10 * log10(signalPower / noisePower)
    }
    
    private func logAudioStatistics(_ samples: [Float]) {
        var sum: Float = 0
        var sumSquares: Float = 0
        var maxValue: Float = 0
        var minValue: Float = 0
        
        vDSP_sve(samples, 1, &sum, vDSP_Length(samples.count))
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        vDSP_maxv(samples, 1, &maxValue, vDSP_Length(samples.count))
        vDSP_minv(samples, 1, &minValue, vDSP_Length(samples.count))
        
        let mean = sum / Float(samples.count)
        let rms = sqrt(sumSquares / Float(samples.count))
        let variance = (sumSquares / Float(samples.count)) - (mean * mean)
        
        logger.info("""
            Audio Statistics:
            - Samples: \(samples.count)
            - Mean: \(mean)
            - RMS: \(rms)
            - Variance: \(variance)
            - Peak: \(maxValue)
            - Min: \(minValue)
            - Non-zero samples: \(samples.filter { $0 != 0 }.count)
            """)
    }
    
    // MARK: - Fallback to Apple Speech
    
    private func fallbackToAppleSpeech(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        logger.info("Falling back to Apple Speech Recognition")
        
        guard let recognizer = fallbackRecognizer,
              recognizer.isAvailable else {
            throw EpilogueWhisperError.fallbackUnavailable
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        
        request.append(buffer)
        request.endAudio()
        
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result, result.isFinal {
                        continuation.resume(returning: result)
                    }
                }
            }
            
            // Convert to TranscriptionResult
            let segments = result.bestTranscription.segments.map { segment in
                TranscriptionSegment(
                    text: segment.substring,
                    start: segment.timestamp,
                    end: segment.timestamp + segment.duration,
                    probability: Float(segment.confidence)
                )
            }
            
            return TranscriptionResult(
                text: result.bestTranscription.formattedString,
                segments: segments,
                language: "en",
                languageProbability: 0.9,
                timings: nil
            )
            
        } catch {
            logger.error("Apple Speech fallback failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Model Optimization
    
    private func calculateSegmentConfidence(_ segments: [TranscriptionSegment]) -> Float {
        guard !segments.isEmpty else { return 0 }
        
        let probabilities = segments.map { $0.probability }
        return probabilities.reduce(0, +) / Float(probabilities.count)
    }
    
    private func calculateOverallConfidence(_ segments: [TranscriptionSegment]) -> Float {
        guard !segments.isEmpty else { return 0 }
        
        // Weighted average based on segment length
        var totalWeight: Float = 0
        var weightedSum: Float = 0
        
        for segment in segments {
            let duration = Float(segment.end - segment.start)
            weightedSum += segment.probability * duration
            totalWeight += duration
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }
    
    private func updatePerformanceMetrics(_ time: TimeInterval) async {
        recentProcessingTimes.append(time)
        if recentProcessingTimes.count > performanceWindowSize {
            recentProcessingTimes.removeFirst()
        }
        
        processingTime = time
        logger.info("Processing completed in \(String(format: "%.2f", time))s")
    }
    
    private func shouldSwitchModel() -> Bool {
        guard recentProcessingTimes.count >= performanceWindowSize else { return false }
        
        let avgTime = recentProcessingTimes.reduce(0, +) / Double(recentProcessingTimes.count)
        
        // Switch to smaller model if too slow
        if avgTime > performanceThreshold && currentModel != "tiny" {
            return true
        }
        
        // Switch to larger model if very fast and not at max
        if avgTime < 0.5 && currentModel == "tiny" {
            return true
        }
        
        return false
    }
    
    private func adaptModelBasedOnPerformance() async throws {
        let avgTime = recentProcessingTimes.reduce(0, +) / Double(recentProcessingTimes.count)
        
        if avgTime > performanceThreshold {
            // Switch to smaller model
            if currentModel == "base" {
                logger.info("Switching to tiny model for better performance")
                currentModel = "tiny"
            }
        } else if avgTime < 0.5 {
            // Switch to larger model
            if currentModel == "tiny" {
                logger.info("Switching to base model for better quality")
                currentModel = "base"
            }
        }
        
        try await loadOptimalModel()
    }
    
    // MARK: - Device Optimization
    
    private func getDeviceCapabilities() async -> DeviceCapabilities {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let cpuCount = ProcessInfo.processInfo.processorCount
        
        // Check for Neural Engine (all modern iOS devices have it)
        let hasNeuralEngine = true
        
        // Check available memory
        let availableMemory = os_proc_available_memory()
        
        return DeviceCapabilities(
            memoryGB: Int(totalMemory / 1_073_741_824),
            cpuCores: cpuCount,
            hasNeuralEngine: hasNeuralEngine,
            availableMemoryMB: Int(availableMemory / 1_048_576)
        )
    }
    
    private func selectOptimalModel(for device: DeviceCapabilities) -> String {
        // Start with tiny for initial load
        if !isModelLoaded {
            return "tiny"
        }
        
        // Dynamic model selection based on available resources
        if device.availableMemoryMB < 500 {
            return "tiny"
        } else if device.availableMemoryMB < 1000 || device.cpuCores < 6 {
            return "tiny"
        } else if device.memoryGB >= 6 && device.cpuCores >= 8 {
            return "base"
        } else {
            return "tiny"
        }
    }
    
    struct DeviceCapabilities {
        let memoryGB: Int
        let cpuCores: Int
        let hasNeuralEngine: Bool
        let availableMemoryMB: Int
    }
}

// Error cases are defined in EpilogueWhisperKit.swift