import Foundation
import AVFoundation
import SoundAnalysis
import Accelerate
import OSLog
import Combine

private let logger = Logger(subsystem: "com.epilogue", category: "AudioPreprocessor")

// MARK: - Audio Preprocessor
@MainActor
class AudioPreprocessor: ObservableObject {
    @Published var isProcessing = false
    @Published var voiceActivityLevel: Float = 0.0
    @Published var noiseLevel: Float = 0.0
    
    // Voice Activity Detection
    private var audioStreamAnalyzer: SNAudioStreamAnalyzer?
    private var voiceDetectionRequest: SNClassifySoundRequest?
    
    // Audio processing
    private let sampleRate: Double = 16000 // Optimal for Whisper
    private let chunkDuration: TimeInterval = 10.0 // 10-second chunks
    private let overlapDuration: TimeInterval = 1.0 // 1-second overlap
    private let contextBuffer: TimeInterval = 2.0 // 2 seconds before/after speech
    
    // Buffers
    private var audioBuffer: [Float] = []
    private var speechSegments: [SpeechSegment] = []
    private let maxBufferSize = 16000 * 60 // 1 minute at 16kHz
    
    // VAD parameters
    private let vadThreshold: Float = 0.02
    private let silenceDuration: TimeInterval = 1.5
    private var lastVoiceTime: Date = Date()
    private var isSpeaking = false
    
    struct SpeechSegment {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let audioData: [Float]
        let confidence: Float
    }
    
    // MARK: - Initialization
    
    init() {
        setupVoiceActivityDetection()
    }
    
    private func setupVoiceActivityDetection() {
        do {
            // Create sound classification request
            voiceDetectionRequest = try SNClassifySoundRequest(classifierIdentifier: .version1)
            
            logger.info("Voice activity detection configured")
        } catch {
            logger.error("Failed to setup VAD: \(error)")
        }
    }
    
    // MARK: - Audio Processing
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async -> ProcessedAudio? {
        guard let channelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        // 1. Normalize audio levels
        let normalizedSamples = normalizeAudio(samples)
        
        // 2. Apply noise reduction
        let denoisedSamples = await reduceNoise(normalizedSamples)
        
        // 3. Detect voice activity
        let hasVoice = detectVoiceActivity(denoisedSamples)
        
        // 4. Update buffers
        updateBuffers(denoisedSamples, hasVoice: hasVoice)
        
        // 5. Extract speech segments
        if let segment = extractSpeechSegment() {
            return ProcessedAudio(
                samples: segment.audioData,
                sampleRate: sampleRate,
                hasVoice: true,
                confidence: segment.confidence
            )
        }
        
        return nil
    }
    
    // MARK: - Audio Normalization
    
    private func normalizeAudio(_ samples: [Float]) -> [Float] {
        var normalizedSamples = samples
        
        // Find peak amplitude
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        
        // Normalize to 0.9 peak to avoid clipping
        if peak > 0 {
            var scale = 0.9 / peak
            vDSP_vsmul(samples, 1, &scale, &normalizedSamples, 1, vDSP_Length(samples.count))
        }
        
        return normalizedSamples
    }
    
    // MARK: - Noise Reduction
    
    private func reduceNoise(_ samples: [Float]) async -> [Float] {
        // Simple spectral subtraction noise reduction
        let fftLength = 2048
        guard samples.count >= fftLength else { return samples }
        
        // Convert to frequency domain
        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftLength))), FFTRadix(FFT_RADIX2))!
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var real = [Float](repeating: 0, count: fftLength/2)
        var imag = [Float](repeating: 0, count: fftLength/2)
        var window = [Float](repeating: 0, count: fftLength)
        
        // Apply Hann window
        vDSP_hann_window(&window, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
        
        var windowedSamples = [Float](repeating: 0, count: fftLength)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftLength))
        
        // Perform FFT
        windowedSamples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftLength/2) { complexPtr in
                var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftLength/2))
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(fftLength))), FFTDirection(FFT_FORWARD))
            }
        }
        
        // Estimate noise floor and subtract
        var magnitudes = [Float](repeating: 0, count: fftLength/2)
        var splitComplexForMag = DSPSplitComplex(realp: &real, imagp: &imag)
        vDSP_zvmags(&splitComplexForMag, 1, &magnitudes, 1, vDSP_Length(fftLength/2))
        
        // Simple noise gate
        let noiseFloor: Float = magnitudes.sorted()[magnitudes.count / 10] // 10th percentile
        for i in 0..<magnitudes.count {
            if magnitudes[i] < noiseFloor * 2 {
                real[i] *= 0.1
                imag[i] *= 0.1
            }
        }
        
        // Inverse FFT
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(fftLength))), FFTDirection(FFT_INVERSE))
        
        var result = [Float](repeating: 0, count: fftLength)
        result.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftLength/2) { complexPtr in
                vDSP_ztoc(&splitComplex, 1, complexPtr, 2, vDSP_Length(fftLength/2))
            }
        }
        
        // Scale
        var scale = Float(1.0 / Float(fftLength))
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(fftLength))
        
        return result
    }
    
    // MARK: - Voice Activity Detection
    
    private func detectVoiceActivity(_ samples: [Float]) -> Bool {
        // Calculate RMS energy
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        
        // Update voice activity level for UI
        DispatchQueue.main.async {
            self.voiceActivityLevel = rms
        }
        
        // Check if above threshold
        let hasVoice = rms > vadThreshold
        
        if hasVoice {
            lastVoiceTime = Date()
            if !isSpeaking {
                isSpeaking = true
                logger.debug("Voice activity started")
            }
        } else if isSpeaking && Date().timeIntervalSince(lastVoiceTime) > silenceDuration {
            isSpeaking = false
            logger.debug("Voice activity ended")
        }
        
        return hasVoice || isSpeaking
    }
    
    // MARK: - Buffer Management
    
    private func updateBuffers(_ samples: [Float], hasVoice: Bool) {
        // Add to main buffer
        audioBuffer.append(contentsOf: samples)
        
        // Trim buffer if too large
        if audioBuffer.count > maxBufferSize {
            audioBuffer.removeFirst(audioBuffer.count - maxBufferSize)
        }
        
        // Track speech segments
        if hasVoice && !isSpeaking {
            // Start new segment with context buffer
            let startIndex = max(0, audioBuffer.count - Int(contextBuffer * sampleRate) - samples.count)
            let segmentStart = TimeInterval(startIndex) / sampleRate
            
            speechSegments.append(SpeechSegment(
                startTime: segmentStart,
                endTime: segmentStart,
                audioData: [],
                confidence: 0.9
            ))
        }
        
        // Update current segment
        if hasVoice && isSpeaking && !speechSegments.isEmpty {
            var lastSegment = speechSegments.removeLast()
            lastSegment = SpeechSegment(
                startTime: lastSegment.startTime,
                endTime: TimeInterval(audioBuffer.count) / sampleRate,
                audioData: audioBuffer,
                confidence: lastSegment.confidence
            )
            speechSegments.append(lastSegment)
        }
    }
    
    // MARK: - Speech Segment Extraction
    
    private func extractSpeechSegment() -> SpeechSegment? {
        // Check if we have a complete segment
        guard let lastSegment = speechSegments.last else { return nil }
        
        let segmentDuration = lastSegment.endTime - lastSegment.startTime
        
        // Extract if we have enough audio or speech has ended
        if segmentDuration >= chunkDuration || (!isSpeaking && segmentDuration > 0.5) {
            speechSegments.removeLast()
            
            // Add context buffer at the end
            let endIndex = min(audioBuffer.count, Int((lastSegment.endTime + contextBuffer) * sampleRate))
            let startIndex = Int(lastSegment.startTime * sampleRate)
            
            let audioData = Array(audioBuffer[startIndex..<endIndex])
            
            return SpeechSegment(
                startTime: lastSegment.startTime,
                endTime: lastSegment.endTime,
                audioData: audioData,
                confidence: lastSegment.confidence
            )
        }
        
        return nil
    }
    
    // MARK: - Public Methods
    
    func reset() {
        audioBuffer.removeAll()
        speechSegments.removeAll()
        isSpeaking = false
        lastVoiceTime = Date()
    }
    
    func getAudioStatistics() -> AudioStatistics {
        var avgLevel: Float = 0
        if !audioBuffer.isEmpty {
            vDSP_meanv(audioBuffer, 1, &avgLevel, vDSP_Length(audioBuffer.count))
        }
        
        return AudioStatistics(
            bufferSize: audioBuffer.count,
            averageLevel: avgLevel,
            voiceActivity: voiceActivityLevel,
            isSpeaking: isSpeaking,
            segmentCount: speechSegments.count
        )
    }
}

// MARK: - Supporting Types

struct ProcessedAudio {
    let samples: [Float]
    let sampleRate: Double
    let hasVoice: Bool
    let confidence: Float
}

struct AudioStatistics {
    let bufferSize: Int
    let averageLevel: Float
    let voiceActivity: Float
    let isSpeaking: Bool
    let segmentCount: Int
}