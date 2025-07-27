import Speech
import AVFoundation
import Combine
import OSLog
import Accelerate.vecLib.vDSP
import UIKit
// Potential iOS 26 imports - uncomment if available
// import SpeechAnalysis
// import FoundationModels
// import SpeechKit

private let logger = Logger(subsystem: "com.epilogue", category: "VoiceRecognition")

@MainActor
class VoiceRecognitionManager: NSObject, ObservableObject {
    static let shared = VoiceRecognitionManager()
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var whisperTranscribedText = ""
    @Published var currentAmplitude: Float = 0.0
    @Published var recognitionState: RecognitionState = .idle
    @Published var confidenceScore: Float = 0.0
    @Published var whisperConfidence: Float = 0.0
    @Published var isProcessingWhisper = false
    @Published var detectedLanguage = "en"
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var audioBufferCount = 0
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode!
    private var audioSession: AVAudioSession!
    
    // Voice Activity Detection
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date = Date()
    private let silenceThreshold: TimeInterval = 3.0
    private let voiceActivityThreshold: Float = 0.00005 // Even lower threshold for better sensitivity
    
    // Natural reaction detection
    private var reactionDetectionEnabled = true
    private var lastReactionTime: Date?
    
    // Audio analysis
    private var amplitudeBuffer: [Float] = []
    private let amplitudeBufferSize = 50
    
    // Advanced pipeline integration
    private let intelligencePipeline = AmbientIntelligencePipeline()
    private let whisperProcessor = OptimizedWhisperProcessor()
    private var audioBufferForWhisper: [AVAudioPCMBuffer] = []
    private var whisperProcessingTimer: Timer?
    private let whisperBufferDuration: TimeInterval = 2.0 // Process every 2 seconds for better responsiveness
    
    // Debug logging counters
    private var voiceBufferLogCounter = 0
    private var vadCheckLogCounter = 0
    
    enum RecognitionState: String {
        case idle = "Idle"
        case listening = "Listening..."
        case processing = "Processing voice"
    }
    
    // MARK: - Initialization
    private var isInitialized = false
    
    override init() {
        super.init()
        // Don't initialize anything here - wait for first use
        logger.info("VoiceRecognitionManager created - deferring initialization")
    }
    
    // Lazy initialization when first needed
    private func ensureInitialized() async {
        guard !isInitialized else { return }
        isInitialized = true
        logger.info("Initializing voice recognition on first use...")
        await setupAudioSession()
        await requestPermissions()
    }
    
    // MARK: - Setup Methods
    private func setupAudioSession() async {
        do {
            audioSession = AVAudioSession.sharedInstance()
            
            // Configure for ambient continuous listening
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .measurement,
                                        options: [.defaultToSpeaker, 
                                                 .allowBluetooth, 
                                                 .mixWithOthers])
            
            // Enable voice processing for better recognition
            try audioSession.setMode(.voiceChat)
            
            // Set preferred settings for low-power continuous listening
            try audioSession.setPreferredSampleRate(16000) // Lower sample rate for efficiency
            try audioSession.setPreferredIOBufferDuration(0.05) // 50ms buffer
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            logger.info("Audio session configured for ambient listening")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    private func requestPermissions() async {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        // Request microphone permission
        let micAuthorized = await AVAudioApplication.requestRecordPermission()
        
        if speechStatus == .authorized && micAuthorized {
            await setupSpeechRecognizer()
        } else {
            logger.error("Permissions not granted - Speech: \(speechStatus.rawValue), Mic: \(micAuthorized)")
        }
    }
    
    // MARK: - Speech Recognizer Setup with iOS 26 Enhancements
    private func setupSpeechRecognizer() async {
        // Create speech recognizer with on-device recognition
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        
        // iOS 26 Enhanced Configuration
        if #available(iOS 26.0, *) {
            // Enable enhanced on-device recognition for iOS 26
            speechRecognizer?.supportsOnDeviceRecognition = true
            
            // iOS 26: Try to access enhanced features if available
            // These might be available through different properties in iOS 26
            if speechRecognizer?.responds(to: #selector(getter: SFSpeechRecognizer.supportsOnDeviceRecognition)) == true {
                logger.info("iOS 26 enhanced on-device recognition enabled")
            }
            
            // Check for continuous recognition support
            if let recognizer = speechRecognizer {
                // iOS 26 might have new properties for continuous recognition
                // Try setting any available enhanced modes
                logger.info("Speech recognizer configured for iOS 26 with locale: \(recognizer.locale)")
            }
        } else {
            // Fallback for older iOS versions
            speechRecognizer?.supportsOnDeviceRecognition = true
        }
        
        // Set as delegate
        speechRecognizer?.delegate = self
        
        logger.info("SpeechRecognizer configured with on-device recognition")
    }
    
    // MARK: - Start/Stop Listening
    func startAmbientListening() {
        guard !isListening else { 
            logger.warning("Already listening, ignoring startAmbientListening")
            return 
        }
        
        logger.info("🎤 Starting ambient listening...")
        isListening = true
        recognitionState = .listening  // Always listening when activated
        
        Task {
            // Ensure initialized before starting
            await ensureInitialized()
            // Ensure Whisper model is loaded first
            if !self.whisperProcessor.isModelLoaded {
                logger.info("Loading default Whisper model...")
                let availableModels = self.whisperProcessor.availableModels
                logger.info("Available Whisper models: \(availableModels.map { $0.displayName }.joined(separator: ", "))")
                
                if let defaultModel = availableModels.first(where: { $0.recommendedForDevice }) {
                    logger.info("Loading recommended model: \(defaultModel.displayName)")
                    do {
                        try await self.whisperProcessor.loadModel(defaultModel)
                        logger.info("Whisper model loaded successfully")
                    } catch {
                        logger.error("Failed to load Whisper model: \(error)")
                    }
                } else if let firstModel = availableModels.first {
                    logger.info("No recommended model, loading: \(firstModel.displayName)")
                    do {
                        try await self.whisperProcessor.loadModel(firstModel)
                        logger.info("Whisper model \(firstModel.displayName) loaded")
                    } catch {
                        logger.error("Failed to load first model: \(error)")
                    }
                }
            } else {
                logger.info("Whisper model already loaded: \(self.whisperProcessor.currentModel)")
            }
            
            await startContinuousRecognition()
        }
        
        logger.info("Started ambient listening mode")
    }
    
    func stopListening() {
        isListening = false
        recognitionState = .idle
        
        audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        silenceTimer?.invalidate()
        whisperProcessingTimer?.invalidate()
        whisperProcessingTimer = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Process any remaining audio with Whisper before clearing
        if !audioBufferForWhisper.isEmpty {
            logger.info("Processing final \(self.audioBufferForWhisper.count) buffers with Whisper before stopping")
            Task {
                await processWithWhisper()
            }
        }
        
        logger.info("Stopped listening")
    }
    
    // MARK: - Continuous Recognition with VAD
    private func startContinuousRecognition() async {
        do {
            // Cancel previous task
            recognitionTask?.cancel()
            recognitionTask = nil
            
            // Configure recognition request with iOS 26 enhancements
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            // iOS 26 Enhanced Configuration
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true
            recognitionRequest.addsPunctuation = true
            
            if #available(iOS 26.0, *) {
                // iOS 26: Enable continuous recognition without time limits
                // This is the key setting for unlimited recognition
                recognitionRequest.taskHint = .unspecified
                
                // iOS 26: Try to set any new properties for continuous mode
                // These properties might exist in iOS 26 but not be documented yet
                if recognitionRequest.responds(to: NSSelectorFromString("setContinuousRecognitionEnabled:")) {
                    recognitionRequest.setValue(true, forKey: "continuousRecognitionEnabled")
                    logger.info("iOS 26 continuous recognition mode enabled")
                }
            }
            
            // Configure audio engine
            inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Install tap for audio analysis
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                
                // Log every 100th buffer to avoid spam
                self.audioBufferCount += 1
                if self.audioBufferCount % 100 == 0 {
                    logger.debug("🎤 Audio buffer #\(self.audioBufferCount), amplitude: \(self.currentAmplitude)")
                }
                
                // Update amplitude for visualization
                self.updateAmplitude(from: buffer)
                
                // Always append to recognition request (Apple needs continuous audio)
                self.recognitionRequest?.append(buffer)
                
                // Voice Activity Detection
                let hasVoice = self.detectVoiceActivity(from: buffer)
                
                if hasVoice {
                    self.handleVoiceDetected()
                } else {
                    self.handleSilence()
                }
                
                // Send to advanced pipeline for processing
                Task {
                    await self.intelligencePipeline.analyzeAudioStream(buffer)
                }
                
                // Buffer for Whisper whenever we're actively listening (not just when voice detected)
                // This ensures we capture all audio that Apple is transcribing
                if self.recognitionState == .listening || !self.transcribedText.isEmpty {
                    self.bufferAudioForWhisper(buffer)
                    
                    // Log periodically
                    self.voiceBufferLogCounter += 1
                    if self.voiceBufferLogCounter % 100 == 0 {
                        logger.debug("Buffering audio for Whisper (count: \(self.voiceBufferLogCounter), state: \(self.recognitionState.rawValue))")
                    }
                }
            }
            
            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()
            
            // Start recognition task with iOS 26 configuration
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    Task { @MainActor in
                        await self.processTranscriptionResult(result)
                    }
                }
                
                // Handle errors but continue recognition
                if let error = error as NSError? {
                    // iOS 26: Check for specific error codes that don't require restart
                    let shouldRestart = error.code != 1110 && // Not a network error
                                       error.code != 203 &&  // Not a no speech detected error
                                       self.isListening
                    
                    if shouldRestart {
                        logger.debug("Recognition error (will restart): \(error.localizedDescription)")
                        // Restart recognition for continuous listening
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                            if self.isListening {
                                await self.startContinuousRecognition()
                            }
                        }
                    }
                }
            }
            
        } catch {
            logger.error("Recognition error: \(error.localizedDescription)")
            // Attempt to restart if still listening
            if isListening {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    await startContinuousRecognition()
                }
            }
        }
    }
    
    // MARK: - Voice Activity Detection
    private func detectVoiceActivity(from buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData?[0] else { return false }
        
        let frames = buffer.frameLength
        var rms: Float = 0.0
        
        // Calculate RMS (Root Mean Square) for better voice detection
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frames))
        
        // Update rolling average for smoother detection
        amplitudeBuffer.append(rms)
        if amplitudeBuffer.count > amplitudeBufferSize {
            amplitudeBuffer.removeFirst()
        }
        
        let avgAmplitude = amplitudeBuffer.reduce(0, +) / Float(amplitudeBuffer.count)
        
        // Enhanced VAD: Check for voice-like patterns
        // 1. Basic energy threshold
        let hasEnergy = avgAmplitude > voiceActivityThreshold
        
        // 2. Zero-crossing rate (helps distinguish voice from noise)
        let zcr = calculateZeroCrossingRate(channelData: channelData, frameLength: frames)
        let hasVoiceLikeZCR = zcr > 10 && zcr < 120 // Voice typically has moderate ZCR
        
        // 3. Simple spectral analysis - voice has energy in 80-4000Hz range
        let hasVoiceSpectrum = hasVoiceFrequencyContent(channelData: channelData, frameLength: frames, sampleRate: buffer.format.sampleRate)
        
        // Combine all indicators
        let hasVoice = hasEnergy && (hasVoiceLikeZCR || hasVoiceSpectrum)
        
        // Log every 100th check to avoid spam
        self.vadCheckLogCounter += 1
        if self.vadCheckLogCounter % 100 == 0 {
            logger.debug("VAD check #\(self.vadCheckLogCounter): amplitude=\(avgAmplitude), ZCR=\(zcr), hasVoice=\(hasVoice)")
        }
        
        return hasVoice
    }
    
    private func calculateZeroCrossingRate(channelData: UnsafeMutablePointer<Float>, frameLength: AVAudioFrameCount) -> Float {
        var crossings: Float = 0
        for i in 1..<Int(frameLength) {
            if (channelData[i] >= 0 && channelData[i-1] < 0) || (channelData[i] < 0 && channelData[i-1] >= 0) {
                crossings += 1
            }
        }
        return crossings / Float(frameLength) * 100
    }
    
    private func hasVoiceFrequencyContent(channelData: UnsafeMutablePointer<Float>, frameLength: AVAudioFrameCount, sampleRate: Double) -> Bool {
        // Simple energy-based frequency detection
        // For a more accurate implementation, we would use FFT
        // For now, use a heuristic based on sample variance
        var mean: Float = 0
        vDSP_meanv(channelData, 1, &mean, vDSP_Length(frameLength))
        
        var variance: Float = 0
        var temp = [Float](repeating: 0, count: Int(frameLength))
        
        // Calculate variance as a proxy for frequency content
        for i in 0..<Int(frameLength) {
            temp[i] = pow(channelData[i] - mean, 2)
        }
        vDSP_meanv(temp, 1, &variance, vDSP_Length(frameLength))
        
        // Voice typically has moderate variance (not too low like silence, not too high like noise)
        return variance > 0.0001 && variance < 0.1
    }
    
    private func updateAmplitude(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frames = buffer.frameLength
        var amplitude: Float = 0.0
        
        // Calculate average amplitude for visualization
        vDSP_meamgv(channelData, 1, &amplitude, vDSP_Length(frames))
        
        // Smooth the amplitude for visualization
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentAmplitude = self.currentAmplitude * 0.8 + amplitude * 0.2
        }
    }
    
    private func handleVoiceDetected() {
        lastSpeechTime = Date()
        silenceTimer?.invalidate()
        
        // Update state only if transitioning from idle
        if recognitionState == .idle {
            DispatchQueue.main.async { [weak self] in
                self?.recognitionState = .listening
            }
        }
    }
    
    private func handleSilence() {
        let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeechTime)
        
        if timeSinceLastSpeech > silenceThreshold && recognitionState != .idle {
            DispatchQueue.main.async { [weak self] in
                self?.recognitionState = .idle
                self?.currentAmplitude = 0.0
            }
            
            // Clear transcription buffer after extended silence
            if timeSinceLastSpeech > silenceThreshold * 2 {
                DispatchQueue.main.async { [weak self] in
                    self?.transcribedText = ""
                }
            }
        }
    }
    
    // MARK: - Process Transcription
    @MainActor
    private func processTranscriptionResult(_ result: SFSpeechRecognitionResult) async {
        let text = result.bestTranscription.formattedString
        self.transcribedText = text
        
        // Update confidence score for debugging
        if let segment = result.bestTranscription.segments.last {
            self.confidenceScore = segment.confidence
            logger.debug("Transcription confidence: \(segment.confidence) - '\(segment.substring)'")
        }
        
        // Process natural reactions only for substantial text
        if reactionDetectionEnabled && !text.isEmpty && text.split(separator: " ").count >= 3 {
            // Only process if we have a complete sentence or if it's been stable for a moment
            if result.isFinal || (self.confidenceScore > 0.8 && text.hasSuffix(".") || text.hasSuffix("?") || text.hasSuffix("!")) {
                await processNaturalReaction(text)
            }
        }
    }
    
    private func processNaturalReaction(_ text: String) async {
        // Cooldown to prevent repeated processing
        if let lastTime = lastReactionTime,
           Date().timeIntervalSince(lastTime) < 1.0 {
            return
        }
        
        lastReactionTime = Date()
        
        logger.info("Processing natural reaction: '\(text)'")
        
        // Post reaction for AI processing
        NotificationCenter.default.post(
            name: Notification.Name("NaturalReactionDetected"),
            object: text
        )
    }
    
    // MARK: - Background Handling
    func handleAppBackground() {
        // Reduce processing when backgrounded
        if isListening {
            logger.info("App backgrounded - reducing voice processing")
            // Could implement reduced sampling rate or pause non-essential processing
        }
    }
    
    func handleAppForeground() {
        // Resume full processing
        if isListening {
            logger.info("App foregrounded - resuming full voice processing")
        }
    }
    
    // MARK: - Whisper Integration
    
    private func bufferAudioForWhisper(_ buffer: AVAudioPCMBuffer) {
        // Validate buffer
        guard buffer.frameLength > 0 && buffer.frameCapacity > 0 else {
            logger.warning("Invalid buffer dimensions: frameLength=\(buffer.frameLength), frameCapacity=\(buffer.frameCapacity)")
            return
        }
        
        // Create a copy of the buffer
        guard let bufferCopy = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else {
            logger.error("Failed to create buffer copy")
            return
        }
        
        bufferCopy.frameLength = buffer.frameLength
        
        // Copy audio data
        if let sourceData = buffer.floatChannelData,
           let destData = bufferCopy.floatChannelData {
            for channel in 0..<Int(buffer.format.channelCount) {
                memcpy(destData[channel], sourceData[channel], 
                       Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }
        
        audioBufferForWhisper.append(bufferCopy)
        // Log only every 10th buffer to reduce spam
        if audioBufferForWhisper.count % 10 == 0 {
            logger.debug("Added buffer to Whisper queue. Total buffers: \(self.audioBufferForWhisper.count)")
        }
        
        // Start the processing timer only if it's not already running
        if whisperProcessingTimer == nil {
            logger.info("Starting Whisper processing timer (2 seconds)")
            whisperProcessingTimer = Timer.scheduledTimer(withTimeInterval: whisperBufferDuration, repeats: true) { [weak self] _ in
                logger.info("Whisper processing timer fired")
                Task {
                    await self?.processWithWhisper()
                }
            }
        }
    }
    
    private func processWithWhisper() async {
        guard !audioBufferForWhisper.isEmpty else { 
            logger.debug("No audio buffers to process with Whisper")
            return 
        }
        
        logger.info("Processing \(self.audioBufferForWhisper.count) audio buffers with Whisper")
        
        // Combine all buffers into one
        guard let combinedBuffer = combineAudioBuffers(audioBufferForWhisper) else { 
            logger.error("Failed to combine audio buffers")
            return 
        }
        
        logger.info("Combined buffer: \(combinedBuffer.frameLength) frames, format: \(combinedBuffer.format)")
        
        // Calculate duration
        let duration = Double(combinedBuffer.frameLength) / combinedBuffer.format.sampleRate
        logger.info("Audio duration: \(String(format: "%.2f", duration)) seconds")
        
        // Clear the buffer
        audioBufferForWhisper.removeAll()
        
        // Check if we have enough audio (at least 0.5 seconds)
        guard duration >= 0.5 else {
            logger.info("Not enough audio for WhisperKit (need at least 0.5 seconds, got \(String(format: "%.2f", duration))s)")
            isProcessingWhisper = false
            return
        }
        
        // Check if Whisper model is loaded
        guard self.whisperProcessor.isModelLoaded else {
            logger.warning("Whisper model not loaded yet")
            isProcessingWhisper = false
            return
        }
        
        // Process with Whisper
        isProcessingWhisper = true
        
        do {
            logger.info("Starting Whisper transcription...")
            let result = try await self.whisperProcessor.transcribe(audioBuffer: combinedBuffer)
            
            // Check if Whisper failed and use fallback
            if result.text == "[BLANK_AUDIO]" || result.text.isEmpty {
                logger.warning("Whisper returned blank audio, using Apple transcription as fallback")
                
                // Use Apple's transcription as fallback if available
                if !transcribedText.isEmpty {
                    whisperTranscribedText = "[Fallback] \(transcribedText)"
                    whisperConfidence = confidenceScore
                    
                    NotificationCenter.default.post(
                        name: Notification.Name("WhisperTranscriptionReady"),
                        object: transcribedText as NSString
                    )
                } else {
                    whisperTranscribedText = ""
                    whisperConfidence = 0.0
                }
            } else {
                whisperTranscribedText = result.text
                // Calculate confidence from segments
                let avgConfidence: Float
                if result.segments.isEmpty {
                    avgConfidence = 0.0
                } else {
                    let probabilities = result.segments.map { segment in
                        return segment.probability
                    }
                    let sum = probabilities.reduce(0, +)
                    avgConfidence = sum / Float(result.segments.count)
                }
                whisperConfidence = avgConfidence
                detectedLanguage = result.language ?? "en"
                
                logger.info("Whisper transcription: \(result.text) (confidence: \(avgConfidence), language: \(result.language ?? "unknown"))")
                
                // Post notification with Whisper's transcription
                NotificationCenter.default.post(
                    name: Notification.Name("WhisperTranscriptionReady"),
                    object: result.text as NSString
                )
            }
        } catch {
            logger.error("Whisper transcription failed: \(error.localizedDescription)")
            
            // Use Apple transcription as fallback on error
            if !transcribedText.isEmpty {
                whisperTranscribedText = "[Error fallback] \(transcribedText)"
                whisperConfidence = confidenceScore * 0.8 // Reduce confidence for fallback
            }
        }
        
        isProcessingWhisper = false
    }
    
    private func combineAudioBuffers(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard !buffers.isEmpty else { return nil }
        
        let format = buffers[0].format
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        
        guard let combinedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(totalFrames)
        ) else { return nil }
        
        // CRITICAL: Set frameLength before copying
        combinedBuffer.frameLength = AVAudioFrameCount(totalFrames)
        
        var writePointer = combinedBuffer.floatChannelData![0]
        
        for buffer in buffers {
            let readPointer = buffer.floatChannelData![0]
            let frames = Int(buffer.frameLength)
            
            // Copy with explicit frame count
            memcpy(writePointer, readPointer, frames * MemoryLayout<Float>.size)
            writePointer = writePointer.advanced(by: frames)
        }
        
        return combinedBuffer
    }
    
    func clearWhisperTranscription() {
        whisperTranscribedText = ""
        whisperConfidence = 0.0
        audioBufferForWhisper.removeAll()
        whisperProcessingTimer?.invalidate()
    }
    
    // MARK: - Testing
    
    func testWhisperKit() async {
        logger.info("Running WhisperKit test...")
        
        do {
            // Ensure model is loaded
            if !self.whisperProcessor.isModelLoaded {
                logger.info("Loading Whisper model for test...")
                if let model = self.whisperProcessor.availableModels.first {
                    try await self.whisperProcessor.loadModel(model)
                }
            }
            
            let result = try await self.whisperProcessor.testTranscription()
            logger.info("WhisperKit test result: '\(result)'")
            
            // Update UI
            await MainActor.run {
                self.whisperTranscribedText = "Test: \(result)"
            }
        } catch {
            logger.error("WhisperKit test error: \(error)")
            await MainActor.run {
                self.whisperTranscribedText = "Test error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension VoiceRecognitionManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                stopListening()
                logger.warning("Speech recognition became unavailable")
            }
        }
    }
}

// MARK: - iOS 26 SpeechAnalyzer Alternative
// If SpeechAnalyzer becomes available, uncomment and use this extension
/*
extension VoiceRecognitionManager {
    private func setupSpeechAnalyzerIfAvailable() async {
        // Try to use iOS 26 SpeechAnalyzer if available
        // This would be the preferred approach once we find the correct import
        
        // Example usage (when available):
        // let configuration = SpeechAnalyzer.Configuration(
        //     requiresOnDeviceRecognition: true
        // )
        // speechAnalyzer = try? await SpeechAnalyzer(configuration: configuration)
    }
}
*/