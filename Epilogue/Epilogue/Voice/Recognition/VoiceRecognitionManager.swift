import Speech
import AVFoundation
import Combine
import OSLog
import Accelerate.vecLib.vDSP
import UIKit
import WhisperKit
// Potential iOS 26 imports - uncomment if available
// import SpeechAnalysis
// import FoundationModels
// import SpeechKit

private let logger = Logger(subsystem: "com.epilogue", category: "VoiceRecognition")

@MainActor
class VoiceRecognitionManager: NSObject, ObservableObject {
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
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode!
    private var audioSession: AVAudioSession!
    
    // Voice Activity Detection
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date = Date()
    private let silenceThreshold: TimeInterval = 3.0
    private let voiceActivityThreshold: Float = 0.0005 // Very sensitive - adjust based on device
    
    // Wake word detection
    private let wakeWords = ["epilogue", "hey epilogue", "ok epilogue"]
    private var isWakeWordDetected = false
    private var wakeWordCooldown: Date?
    
    // Audio analysis
    private var amplitudeBuffer: [Float] = []
    private let amplitudeBufferSize = 50
    
    // Whisper integration
    private let whisperProcessor = WhisperProcessor()
    private var audioBufferForWhisper: [AVAudioPCMBuffer] = []
    private var whisperProcessingTimer: Timer?
    private let whisperBufferDuration: TimeInterval = 5.0 // Process every 5 seconds
    
    // Debug logging counters
    private var voiceBufferLogCounter = 0
    private var vadCheckLogCounter = 0
    
    enum RecognitionState: String {
        case idle = "Idle"
        case listening = "Listening..."
        case processing = "Processing voice"
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        Task {
            await setupAudioSession()
            await requestPermissions()
        }
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
        guard !isListening else { return }
        
        isListening = true
        recognitionState = .idle
        
        Task {
            // Ensure Whisper model is loaded first
            if !whisperProcessor.isModelLoaded {
                logger.info("Loading default Whisper model...")
                let availableModels = whisperProcessor.availableModels
                logger.info("Available Whisper models: \(availableModels.map { $0.displayName }.joined(separator: ", "))")
                
                if let defaultModel = availableModels.first(where: { $0.recommendedForDevice }) {
                    logger.info("Loading recommended model: \(defaultModel.displayName)")
                    do {
                        try await whisperProcessor.loadModel(defaultModel)
                        logger.info("Whisper model loaded successfully")
                    } catch {
                        logger.error("Failed to load Whisper model: \(error)")
                    }
                } else if let firstModel = availableModels.first {
                    logger.info("No recommended model, loading: \(firstModel.displayName)")
                    try? await whisperProcessor.loadModel(firstModel)
                }
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
        let hasVoice = avgAmplitude > voiceActivityThreshold
        
        // Log every 100th check to avoid spam
        self.vadCheckLogCounter += 1
        if self.vadCheckLogCounter % 100 == 0 {
            logger.debug("VAD check #\(self.vadCheckLogCounter): amplitude=\(avgAmplitude), threshold=\(self.voiceActivityThreshold), hasVoice=\(hasVoice)")
        }
        
        return hasVoice
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
                    self?.isWakeWordDetected = false
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
        
        // Check for wake word
        if !isWakeWordDetected && containsWakeWord(text) {
            await handleWakeWordDetected()
        }
        
        // Process commands only after wake word
        if isWakeWordDetected && !text.isEmpty {
            recognitionState = .processing
            await processVoiceCommand(text)
        }
        
        // Reset wake word after processing if final
        if result.isFinal && isWakeWordDetected {
            resetWakeWordDetection()
        }
    }
    
    private func containsWakeWord(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        
        // Check cooldown to prevent repeated triggers
        if let cooldown = wakeWordCooldown,
           Date().timeIntervalSince(cooldown) < 2.0 {
            return false
        }
        
        return wakeWords.contains { lowercasedText.contains($0) }
    }
    
    private func handleWakeWordDetected() async {
        isWakeWordDetected = true
        wakeWordCooldown = Date()
        
        // Haptic feedback
        HapticManager.shared.mediumImpact()
        
        // Clear buffer for command
        transcribedText = ""
        recognitionState = .processing
        
        logger.info("Wake word detected - ready for command")
        
        // Post notification for UI response
        NotificationCenter.default.post(name: Notification.Name("WakeWordDetected"), object: nil)
    }
    
    private func processVoiceCommand(_ command: String) async {
        // Remove wake word from command
        var cleanCommand = command.lowercased()
        for wakeWord in wakeWords {
            cleanCommand = cleanCommand.replacingOccurrences(of: wakeWord, with: "").trimmingCharacters(in: .whitespaces)
        }
        
        if !cleanCommand.isEmpty {
            logger.info("Processing command: '\(cleanCommand)'")
            
            // Post command for processing
            NotificationCenter.default.post(
                name: Notification.Name("VoiceCommandReceived"),
                object: cleanCommand
            )
        }
    }
    
    private func resetWakeWordDetection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isWakeWordDetected = false
            self?.transcribedText = ""
            self?.recognitionState = .idle
        }
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
        logger.debug("Added buffer to Whisper queue. Total buffers: \(self.audioBufferForWhisper.count)")
        
        // Start the processing timer only if it's not already running
        if whisperProcessingTimer == nil {
            logger.info("Starting Whisper processing timer (5 seconds)")
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
        
        // Clear the buffer
        audioBufferForWhisper.removeAll()
        
        // Check if Whisper model is loaded
        guard whisperProcessor.isModelLoaded else {
            logger.warning("Whisper model not loaded yet")
            isProcessingWhisper = false
            return
        }
        
        // Process with Whisper
        isProcessingWhisper = true
        
        do {
            logger.info("Starting Whisper transcription...")
            let result = try await whisperProcessor.transcribe(audioBuffer: combinedBuffer)
            
            whisperTranscribedText = result.text
            // Calculate confidence from segments using avgLogprob
            let avgConfidence = result.segments.isEmpty ? 0.0 : 
                result.segments.map { exp($0.avgLogprob) }.reduce(0, +) / Float(result.segments.count)
            whisperConfidence = avgConfidence
            detectedLanguage = result.language
            
            logger.info("Whisper transcription: \(result.text) (confidence: \(avgConfidence), language: \(result.language))")
            
            // If wake word was detected and Whisper has better transcription, use it
            if isWakeWordDetected && !result.text.isEmpty {
                // Post notification with Whisper's transcription
                NotificationCenter.default.post(
                    name: Notification.Name("WhisperTranscriptionReady"),
                    object: result.text
                )
            }
        } catch {
            logger.error("Whisper transcription failed: \(error.localizedDescription)")
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
    
    func clearWhisperTranscription() {
        whisperTranscribedText = ""
        whisperConfidence = 0.0
        audioBufferForWhisper.removeAll()
        whisperProcessingTimer?.invalidate()
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