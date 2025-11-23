import Speech
import AVFoundation
import Combine
import OSLog
import Accelerate.vecLib.vDSP
import UIKit
import SwiftData
// Potential iOS 26 imports - uncomment if available
// import SpeechAnalysis
// import FoundationModels
// import SpeechKit

private let logger = Logger(subsystem: "com.epilogue", category: "VoiceRecognition")

// MARK: - Voice Recognition Error
enum VoiceRecognitionError: LocalizedError {
    case audioSetupFailed
    case permissionDenied
    case recognitionFailed
    case notAvailable
    
    var errorDescription: String? {
        switch self {
        case .audioSetupFailed:
            return "Failed to set up audio engine"
        case .permissionDenied:
            return "Microphone or speech recognition permission denied"
        case .recognitionFailed:
            return "Failed to recognize speech"
        case .notAvailable:
            return "Speech recognition is not available"
        }
    }
}

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
    @Published var isListeningInAmbientMode: Bool = false
    @Published var isProcessingWhisper = false
    @Published var detectedLanguage = "en"
    
    // Advanced voice pattern analysis
    @Published var voiceFrequency: Double = 0.5   // 0.0 = low pitch, 1.0 = high pitch
    @Published var voiceIntensity: Double = 0.0   // 0.0 = silent, 1.0 = loud
    @Published var voiceRhythm: Double = 0.0      // 0.0 = steady, 1.0 = variable
    @Published var wordsPerMinute: Double = 150.0 // Average speaking speed in WPM
    @Published var audioLevel: Double = 0.0       // Current audio level for visualization
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var audioBufferCount = 0
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    
    // Silence detection for complete thoughts
    private var lastSpeechTime: Date = Date()
    private var pendingTranscription: String = ""
    private var thoughtTimer: Timer?
    private var audioSession: AVAudioSession?

    // ADAPTIVE TIMER: Learn user's speaking patterns
    private var userPauseHistory: [TimeInterval] = [] // Track typical pause lengths
    private var recentConfidenceScores: [Double] = [] // Track confidence trends
    private var lastVADSignal: Bool = false // Track if VAD detecting activity
    
    // Voice Activity Detection
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 3.0
    private let voiceActivityThreshold: Float = 0.00005 // Even lower threshold for better sensitivity
    
    // Natural reaction detection
    private var reactionDetectionEnabled = true
    private var lastReactionTime: Date?
    
    // Pause detection for quote reactions
    private var pauseDetectionTimer: Timer?
    private var reactionPhraseDetected: String? = nil
    private var textBeforePause: String = ""
    private let shortPauseThreshold: TimeInterval = 0.5
    private let mediumPauseThreshold: TimeInterval = 1.0
    private let longPauseThreshold: TimeInterval = 2.0
    
    // Audio analysis
    private var amplitudeBuffer: [Float] = []
    private let amplitudeBufferSize = 50
    
    // Rhythm analysis
    private var rhythmBuffer: [Float] = []
    private let rhythmBufferSize = 30
    private var lastRhythmUpdate = Date()
    
    // WhisperKit integration
    private let whisperProcessor = OptimizedWhisperProcessor()
    private var audioBufferForWhisper: [AVAudioPCMBuffer] = []
    private var whisperProcessingTimer: Timer?
    private let whisperBufferDuration: TimeInterval = 2.0 // Process every 2 seconds for better responsiveness
    
    // Library books for detection
    private var libraryBooks: [Book] = []
    
    // Debug logging counters
    private var voiceBufferLogCounter = 0
    private var vadCheckLogCounter = 0

    // ✅ CONTINUOUS SESSION MANAGEMENT (Perplexity/ChatGPT pattern)
    private var appLifecycleObservers: [Any] = []  // Store observers for cleanup
    private let maxWhisperBufferCount = 150  // ~5 seconds at 30 buffers/sec, prevents memory bloat
    private var engineHealthTimer: Timer?  // Monitor if audio engine stalls
    private var lastAudioBufferTime = Date()  // Track last buffer received
    private var isHandlingInterruption = false  // Prevent multiple simultaneous restarts

    enum RecognitionState: String {
        case idle = "Idle"
        case listening = "Listening..."
        case processing = "Processing voice"
    }
    
    // MARK: - Voice Characteristics Analysis
    
    /// WPM tracking
    private var wordTimestamps: [(word: String, time: Date)] = []
    private let wpmWindowSize: TimeInterval = 10.0 // Calculate WPM over 10 second windows
    
    /// Analyze voice characteristics from audio buffer
    private func analyzeVoiceCharacteristics(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Analyze amplitude (intensity)
        var sum: Float = 0
        var maxAmplitude: Float = 0
        
        for frame in 0..<frameLength {
            let sample = abs(channelData[0][frame])
            sum += sample
            maxAmplitude = max(maxAmplitude, sample)
        }
        
        let averageAmplitude = sum / Float(frameLength)
        
        // Update voice intensity (normalized to 0-1)
        DispatchQueue.main.async {
            self.voiceIntensity = Double(min(1.0, averageAmplitude * 50))
            self.audioLevel = Double(min(1.0, averageAmplitude * 50))
        }
        
        // Analyze frequency using zero-crossing rate (simple pitch detection)
        var zeroCrossings = 0
        for i in 1..<frameLength {
            let current = channelData[0][i]
            let previous = channelData[0][i-1]
            if (current >= 0 && previous < 0) || (current < 0 && previous >= 0) {
                zeroCrossings += 1
            }
        }
        
        // Estimate frequency from zero-crossing rate
        let sampleRate = buffer.format.sampleRate
        let estimatedFrequency = Double(zeroCrossings) * sampleRate / Double(frameLength * 2)
        
        // Normalize frequency to 0-1 range (100Hz - 500Hz typical speech range)
        let normalizedFrequency = min(1.0, max(0.0, (estimatedFrequency - 100) / 400))
        
        DispatchQueue.main.async {
            self.voiceFrequency = normalizedFrequency
        }
        
        // Analyze rhythm (variation in amplitude over time)
        amplitudeBuffer.append(averageAmplitude)
        if amplitudeBuffer.count > amplitudeBufferSize {
            amplitudeBuffer.removeFirst()
        }
        
        if amplitudeBuffer.count >= 10 {
            // Calculate standard deviation of amplitude
            let mean = amplitudeBuffer.reduce(0, +) / Float(amplitudeBuffer.count)
            let variance = amplitudeBuffer.map { pow($0 - mean, 2) }.reduce(0, +) / Float(amplitudeBuffer.count)
            let stdDev = sqrt(variance)
            
            // Normalize rhythm to 0-1 range
            let normalizedRhythm = min(1.0, Double(stdDev * 10))
            
            DispatchQueue.main.async {
                self.voiceRhythm = normalizedRhythm
            }
        }
    }
    
    /// Update words per minute based on transcription
    private func updateWordsPerMinute(from text: String) {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let now = Date()
        
        // Add new words with timestamps
        for word in words {
            wordTimestamps.append((word: word, time: now))
        }
        
        // Remove old words outside the window
        let cutoffTime = now.addingTimeInterval(-wpmWindowSize)
        wordTimestamps.removeAll { $0.time < cutoffTime }
        
        // Calculate WPM
        if wordTimestamps.count > 5, let firstTimestamp = wordTimestamps.first {
            let timeSpan = now.timeIntervalSince(firstTimestamp.time)
            if timeSpan > 0 {
                let wpm = Double(wordTimestamps.count) * 60.0 / timeSpan
                
                DispatchQueue.main.async {
                    // Smooth the WPM value
                    self.wordsPerMinute = self.wordsPerMinute * 0.7 + wpm * 0.3
                }
            }
        }
    }
    
    // MARK: - Initialization
    private var isInitialized = false
    
    override init() {
        super.init()
        // Don't initialize anything here - wait for first use
        logger.info("VoiceRecognitionManager created - deferring initialization")

        // ✅ CONTINUOUS SESSION: Setup lifecycle observers (Perplexity/ChatGPT pattern)
        setupContinuousSessionManagement()
    }

    deinit {
        // ✅ CLEANUP: Remove all observers to prevent leaks
        appLifecycleObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        engineHealthTimer?.invalidate()
        logger.info("VoiceRecognitionManager cleaned up")
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
            let session = AVAudioSession.sharedInstance()
            audioSession = session
            
            // Configure for ambient continuous listening
            try session.setCategory(.playAndRecord, 
                                        mode: .measurement,
                                        options: [.defaultToSpeaker, 
                                                 .allowBluetoothHFP, 
                                                 .mixWithOthers])
            
            // Enable voice processing for better recognition
            try session.setMode(.voiceChat)
            
            // Set preferred settings for low-power continuous listening
            try session.setPreferredSampleRate(16000) // Lower sample rate for efficiency
            try session.setPreferredIOBufferDuration(0.05) // 50ms buffer
            
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
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
        // Haptic feedback for voice recording start
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        // IMMEDIATE state changes for instant UI response
        isListening = false
        recognitionState = .idle
        
        // Stop audio engine immediately
        audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        
        // Cancel timers immediately
        silenceTimer?.invalidate()
        pauseDetectionTimer?.invalidate()
        whisperProcessingTimer?.invalidate()
        whisperProcessingTimer = nil
        thoughtTimer?.invalidate()
        thoughtTimer = nil
        
        // Clear buffers immediately (don't process)
        audioBufferForWhisper.removeAll()
        
        // End recognition immediately
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Reset state immediately
        reactionPhraseDetected = nil
        textBeforePause = ""
        
        logger.info("Stopped listening instantly")
        
        // Process any final transcription in background (non-blocking)
        if !pendingTranscription.isEmpty {
            let finalThought = pendingTranscription
            pendingTranscription = ""
            Task.detached {
                logger.info("🎯 Processing final thought in background: \(finalThought)")
                await TrueAmbientProcessor.shared.processDetectedText(finalThought, confidence: Float(self.confidenceScore))
            }
        }
        
        // Haptic feedback in background (non-blocking)
        Task.detached {
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
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
            
            // Add contextual hints for better book-related recognition
            if #available(iOS 17.0, *) {
                // Add common fantasy/book character names and enhanced context
                var contextualStrings = [
                    // Lord of the Rings characters
                    "Frodo", "Baggins", "Gandalf", "Aragorn", "Legolas",
                    "Bilbo", "Samwise", "Merry", "Pippin", "Boromir",
                    "Gollum", "Sauron", "Saruman", "Elrond", "Galadriel",
                    "Gimli", "Faramir", "Éowyn", "Théoden", "Sméagol",
                    
                    // The Odyssey & Classic Literature
                    "Odysseus", "Telemachus", "Penelope", "Athena", "Poseidon",
                    "Polyphemus", "Circe", "Calypso", "Ithaca", "Achilles",
                    
                    // Common book terms
                    "chapter", "paragraph", "quote", "passage", "author",
                    "protagonist", "antagonist", "character", "plot", "theme",
                    "symbolism", "metaphor", "foreshadowing", "climax", "resolution",
                    
                    // Enhanced question patterns (critical for AI response)
                    "Who is", "What is", "Why did", "How does", "When did",
                    "Where is", "Tell me about", "Explain", "What happens",
                    "Could you", "Can you", "Would you", "Should I",
                    "What do you think", "What if", "Remember when",
                    "The part where", "When he said", "When she said",
                    
                    // Frequently misheard book titles/authors
                    "Silmarillion", "Tolkien", "Homer", "Iliad", "Aeneid",
                    "Love Wins", "Rob Bell"
                ]
                
                // CRITICAL: Add enriched book data (characters, themes from Perplexity)
                // This is the bridge from BookEnrichmentService → Speech Recognition
                if let detectedBook = AmbientBookDetector.shared.detectedBook {
                    contextualStrings.append(detectedBook.title)
                    contextualStrings.append(detectedBook.author)

                    // Add pendingEnrichedContext loaded from BookModel
                    // This contains character names like "Odysseus", "Telemachus", "Penelope"
                    // preventing "Otis" when user says "Odysseus"
                    if !self.pendingEnrichedContext.isEmpty {
                        contextualStrings.append(contentsOf: self.pendingEnrichedContext)
                        logger.info("✅ Added \(self.pendingEnrichedContext.count) enriched terms from BookModel")
                        logger.info("   Enriched context: \(self.pendingEnrichedContext.joined(separator: ", "))")
                    } else {
                        logger.warning("⚠️ No enriched context available for '\(detectedBook.title)'")
                        logger.warning("   Call loadEnrichmentForCurrentBook() first or run BookEnrichmentService")
                    }
                }
                
                recognitionRequest.contextualStrings = contextualStrings
                logger.info("Added \(contextualStrings.count) contextual hints for transcription")
            }
            
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
            guard let inputNode = inputNode else {
                throw VoiceRecognitionError.audioSetupFailed
            }
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Remove any existing tap before installing new one
            inputNode.removeTap(onBus: 0)
            
            // Install tap for audio analysis
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }

                // ✅ HEALTH MONITORING: Track last buffer time for stall detection
                self.updateLastAudioBufferTime()

                // PERFORMANCE OPTIMIZATION: Throttle expensive operations
                // Keep buffer size at 1024 for smooth gradient response
                // But only run expensive analysis every 3rd buffer (saves ~60% CPU on analysis)
                self.audioBufferCount += 1
                let shouldRunExpensiveAnalysis = (self.audioBufferCount % 3 == 0)

                if self.audioBufferCount % 100 == 0 {
                    logger.debug("🎤 Audio buffer #\(self.audioBufferCount), amplitude: \(self.currentAmplitude)")
                }

                // ALWAYS update amplitude for gradient visualization (keeps gradient smooth!)
                self.updateAmplitude(from: buffer)

                // THROTTLED: Voice characteristics analysis (expensive FFT-like operations)
                // Only run every 3rd buffer - gradient doesn't need this, it uses amplitude
                if shouldRunExpensiveAnalysis {
                    self.analyzeVoiceCharacteristics(buffer)
                }

                // ALWAYS append to recognition request (Apple needs continuous audio)
                self.recognitionRequest?.append(buffer)

                // THROTTLED: Voice Activity Detection (expensive zero-crossing & frequency analysis)
                // Only run every 3rd buffer - saves CPU, still responsive enough
                if shouldRunExpensiveAnalysis {
                    let hasVoice = self.detectVoiceActivity(from: buffer)
                    self.lastVADSignal = hasVoice

                    if hasVoice {
                        self.handleVoiceDetected()
                    } else {
                        self.handleSilence()
                    }
                }

                // Buffer for Whisper whenever we're actively listening
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
            
            // Start recognition task with streaming support (Perplexity/ChatGPT pattern)
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    Task { @MainActor in
                        // ✅ STREAMING: Show partial results immediately (feels instant like ChatGPT)
                        await self.processTranscriptionResult(result)

                        // ✅ ACCURACY: Only run Whisper on final results for correction
                        if result.isFinal {
                            logger.info("🎯 Final result detected - running Whisper correction")
                            await self.runWhisperCorrectionPass(appleText: result.bestTranscription.formattedString)
                        }
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
        
        // Make amplitude more sensitive but balanced - multiply by 5
        let boostedAmplitude = min(amplitude * 5.0, 1.0)
        
        // Analyze voice patterns with boosted amplitude
        analyzeVoicePatterns(from: buffer, amplitude: boostedAmplitude)
        
        // Smooth the amplitude for visualization (less smoothing for more responsiveness)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let previousAmplitude = self.currentAmplitude
            self.currentAmplitude = self.currentAmplitude * 0.6 + boostedAmplitude * 0.4
            
            // Debug logging for audio level changes
            if abs(self.currentAmplitude - previousAmplitude) > 0.01 {
                logger.info("🎤 Audio Level Update: \(String(format: "%.3f", self.currentAmplitude)) (raw: \(String(format: "%.3f", amplitude)))")
            }
        }
    }
    
    // MARK: - Advanced Voice Pattern Analysis
    
    private func analyzeVoicePatterns(from buffer: AVAudioPCMBuffer, amplitude: Float) {
        // Update intensity (normalized amplitude)
        // Balanced scaling factor for refined response
        let normalizedIntensity = min(amplitude * 50.0, 1.0)
        
        // Analyze frequency
        let dominantFreq = calculateDominantFrequency(from: buffer)
        let normalizedFreq = mapFrequencyToRange(dominantFreq)
        
        // Update rhythm analysis
        updateRhythmAnalysis(normalizedIntensity)
        
        // Smooth all values
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let previousIntensity = self.voiceIntensity
            let previousFrequency = self.voiceFrequency
            
            // Smooth intensity
            self.voiceIntensity = self.voiceIntensity * 0.85 + CGFloat(normalizedIntensity) * 0.15
            
            // Smooth frequency
            self.voiceFrequency = self.voiceFrequency * 0.9 + normalizedFreq * 0.1
            
            // Debug logging for voice pattern changes (commented out to reduce noise)
            // Uncomment for debugging voice patterns
            /*
            if abs(self.voiceIntensity - previousIntensity) > 0.05 || abs(self.voiceFrequency - previousFrequency) > 0.05 {
                #if DEBUG
                print("🎵 Voice Patterns - Intensity: \(String(format: "%.2f", self.voiceIntensity)), Frequency: \(String(format: "%.2f", self.voiceFrequency)), Rhythm: \(String(format: "%.2f", self.voiceRhythm))")
                #endif
            }
            */
        }
    }
    
    private func calculateDominantFrequency(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 440.0 }
        
        let frames = buffer.frameLength
        
        // Simple zero-crossing rate for pitch estimation
        var zeroCrossings: Float = 0
        for i in 1..<Int(frames) {
            if (channelData[i] > 0 && channelData[i-1] <= 0) ||
               (channelData[i] < 0 && channelData[i-1] >= 0) {
                zeroCrossings += 1
            }
        }
        
        // Convert to frequency estimate (rough approximation)
        let sampleRate: Float = 44100.0
        let frequency = (zeroCrossings * sampleRate) / (2.0 * Float(frames))
        
        return frequency
    }
    
    private func mapFrequencyToRange(_ frequency: Float) -> CGFloat {
        // Map typical voice frequencies to 0-1 range
        // Male voice: 85-180 Hz
        // Female voice: 165-255 Hz
        // Children: 250-400 Hz
        
        let minFreq: Float = 85.0
        let maxFreq: Float = 400.0
        
        let normalized = (frequency - minFreq) / (maxFreq - minFreq)
        return CGFloat(max(0.0, min(1.0, normalized)))
    }
    
    private func updateRhythmAnalysis(_ intensity: Float) {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastRhythmUpdate)
        
        // Update rhythm buffer every 100ms
        if timeDelta > 0.1 {
            rhythmBuffer.append(intensity)
            if rhythmBuffer.count > rhythmBufferSize {
                rhythmBuffer.removeFirst()
            }
            lastRhythmUpdate = now
            
            // Calculate rhythm variance
            if rhythmBuffer.count >= 5 {
                // Calculate variance manually
                let mean = rhythmBuffer.reduce(0, +) / Float(rhythmBuffer.count)
                let squaredDiffs = rhythmBuffer.map { pow($0 - mean, 2) }
                let variance = squaredDiffs.reduce(0, +) / Float(rhythmBuffer.count)
                
                DispatchQueue.main.async { [weak self] in
                    self?.voiceRhythm = CGFloat(min(variance * 10.0, 1.0))
                }
            }
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
    
    // MARK: - Process Transcription - SINGLE SOURCE ROUTING
    @MainActor
    private func processTranscriptionResult(_ result: SFSpeechRecognitionResult) async {
        let text = result.bestTranscription.formattedString
        self.transcribedText = text  // Used for LIVE UI FEEDBACK ONLY

        // Update words per minute tracking
        updateWordsPerMinute(from: text)

        // Update confidence score for debugging
        if let segment = result.bestTranscription.segments.last {
            self.confidenceScore = segment.confidence
            logger.debug("Apple Speech confidence: \(segment.confidence) - '\(segment.substring)'")
        }

        // IMPORTANT: Apple Speech is now ONLY for real-time UI feedback
        // WhisperKit handles actual processing (more accurate, especially with names)
        // This prevents "Otis" when user says "Odysseus"
        if isListeningInAmbientMode {
            // Detect book mentions for context
            detectBookFromSpeech(text)

            logger.info("📱 Apple Speech (UI only): '\(text.prefix(50))...' (final: \(result.isFinal))")

            // Capture for potential fallback only
            if !text.isEmpty {
                pendingTranscription = text
                lastSpeechTime = Date()
                
                // Check if we have a complete sentence (ends with punctuation) and process immediately
                // BUT: For questions, always wait for stabilization to avoid "Otis" vs "Odysseus" mistakes
                let isQuestionText = text.lowercased().hasPrefix("who ") || text.lowercased().hasPrefix("what ") ||
                                    text.lowercased().hasPrefix("where ") || text.lowercased().hasPrefix("when ") ||
                                    text.lowercased().hasPrefix("why ") || text.lowercased().hasPrefix("how ") ||
                                    text.hasSuffix("?")

                // NO LONGER PROCESSING Apple Speech results directly
                // WhisperKit will handle all processing for better accuracy
                // Just update the pending transcription for fallback scenarios
                thoughtTimer?.invalidate()

                // Track confidence scores for adaptive timing
                recentConfidenceScores.append(Double(self.confidenceScore))
                if recentConfidenceScores.count > 10 {
                    recentConfidenceScores.removeFirst()
                }
            }
        }
        
        // Check for reaction phrases that might precede quotes
        detectReactionPhrases(in: text)
        
        // Process natural reactions only for substantial text
        if reactionDetectionEnabled && !text.isEmpty && text.split(separator: " ").count >= 3 {
            // Only process if we have a complete sentence or if it's been stable for a moment
            if result.isFinal || (self.confidenceScore > 0.8 && text.hasSuffix(".") || text.hasSuffix("?") || text.hasSuffix("!")) {
                await processNaturalReaction(text)
            }
        }
    }
    
    // MARK: - DEPRECATED Real-time Question Detection - Now handled by SingleSourceProcessor
    private var detectedQuestions: [String] = []
    private var questionDetectionTimer: Timer?
    private let questionConfidenceThreshold: Float = 0.6
    
    // DEPRECATED - now handled by SingleSourceProcessor
    private func isQuestion(_ text: String) -> Bool {
        // This is now handled by SingleSourceProcessor - DO NOT USE
        // Keeping for backward compatibility temporarily
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for question mark
        if text.hasSuffix("?") {
            return true
        }
        
        // Check for question words at the beginning
        let questionStarters = [
            "what", "why", "how", "when", "where", "who", "which",
            "can you", "could you", "would you", "will you",
            "is it", "is this", "is that", "are these", "are those",
            "do you", "does", "did", "should", "shall"
        ]
        
        for starter in questionStarters {
            if lowercased.hasPrefix(starter) {
                return true
            }
        }
        
        // Check for question patterns anywhere in the text
        let questionPatterns = [
            "what does", "what is", "what are",
            "can you explain", "could you explain",
            "tell me about", "tell me more"
        ]
        
        for pattern in questionPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    // DEPRECATED - now handled by SingleSourceProcessor
    private func triggerImmediateAIResponse(for question: String) async {
        // This is now handled by SingleSourceProcessor - DO NOT USE
        // The processor will automatically trigger AI responses for questions
        logger.info("🤖 [Deprecated] Question detection moved to SingleSourceProcessor")
        
        // For backward compatibility, still post the notification
        NotificationCenter.default.post(
            name: Notification.Name("ImmediateQuestionDetected"),
            object: [
                "question": question,
                "timestamp": Date(),
                "bookContext": SimplifiedAmbientCoordinator.shared.currentBook
            ]
        )
    }
    
    private func detectReactionPhrases(in text: String) {
        let lowercased = text.lowercased()
        let reactionPhrases = [
            "this is beautiful", "i love this", "listen to this", 
            "oh wow", "this is amazing", "here's a great line",
            "check this out", "this part", "the author says",
            "this is incredible", "this is perfect", "yes exactly",
            "this speaks to me", "this is so good", "love this",
            "wow listen to this", "oh my god", "oh my gosh",
            "this is powerful", "this is profound", "this is brilliant"
        ]
        
        // Check if current text ends with a reaction phrase
        for phrase in reactionPhrases {
            if lowercased.hasSuffix(phrase) || lowercased == phrase {
                logger.info("Detected reaction phrase: '\(phrase)' - waiting for potential quote")
                reactionPhraseDetected = phrase
                textBeforePause = text
                
                // Start pause detection timer
                pauseDetectionTimer?.invalidate()
                pauseDetectionTimer = Timer.scheduledTimer(withTimeInterval: shortPauseThreshold, repeats: false) { _ in
                    self.handlePauseAfterReaction()
                }
                break
            }
        }
    }
    
    private func handlePauseAfterReaction() {
        guard let reaction = reactionPhraseDetected else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we have new text after the pause
            if self.transcribedText.count > self.textBeforePause.count + 10 {
                // Text continued after pause - likely a quote
                logger.info("Quote detected after reaction '\(reaction)' and pause")
                
                // Post notification for quote processing
                NotificationCenter.default.post(
                    name: Notification.Name("ReactionBasedQuoteDetected"),
                    object: ["reaction": reaction, "fullText": self.transcribedText]
                )
            }
            
            // Reset detection state
            self.reactionPhraseDetected = nil
            self.textBeforePause = ""
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
        
        // Post reaction for AI processing with confidence
        NotificationCenter.default.post(
            name: Notification.Name("NaturalReactionDetected"),
            object: ["text": text, "confidence": self.confidenceScore]
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

    /// Run Whisper correction pass on final results (Perplexity/ChatGPT pattern)
    /// Only runs when user stops talking for accuracy, not on every partial result
    private func runWhisperCorrectionPass(appleText: String) async {
        guard !audioBufferForWhisper.isEmpty else {
            logger.debug("No audio buffers for Whisper correction")
            return
        }

        logger.info("🔄 Running Whisper correction on: '\(appleText.prefix(50))...'")
        isProcessingWhisper = true

        // Combine audio buffers for Whisper processing
        guard let combinedBuffer = combineAudioBuffers(audioBufferForWhisper) else {
            logger.error("Failed to combine buffers for Whisper")
            isProcessingWhisper = false
            return
        }

        // Process with WhisperKit
        do {
            let result = try await whisperProcessor.transcribe(audioBuffer: combinedBuffer)

            if !result.text.isEmpty {
                logger.info("✅ Whisper result: '\(result.text.prefix(50))...' (confidence: \(result.segments.first?.probability ?? 0))")

                // Update with Whisper's more accurate transcription
                self.whisperTranscribedText = result.text
                self.whisperConfidence = result.segments.first?.probability ?? 0

                // If Whisper is significantly different and more confident, prefer it
                if result.segments.first?.probability ?? 0 > 0.7 {
                    self.transcribedText = result.text
                    logger.info("🎯 Using Whisper result (high confidence)")
                } else {
                    logger.info("📱 Keeping Apple Speech result (Whisper low confidence)")
                }
            }

            // Clear processed buffers
            audioBufferForWhisper.removeAll()

        } catch {
            logger.error("Whisper correction failed: \(error.localizedDescription)")
        }

        isProcessingWhisper = false
    }

    // MARK: - Continuous Session Management (Perplexity/ChatGPT Pattern)

    /// Setup lifecycle observers for background/foreground transitions and audio interruptions
    private func setupContinuousSessionManagement() {
        let nc = NotificationCenter.default

        // ✅ BACKGROUND: Handle app going to background (maintain audio session)
        let willResignActive = nc.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillResignActive()
        }
        appLifecycleObservers.append(willResignActive)

        // ✅ FOREGROUND: Handle app returning to foreground (resume if needed)
        let didBecomeActive = nc.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidBecomeActive()
        }
        appLifecycleObservers.append(didBecomeActive)

        // ✅ INTERRUPTION: Handle audio interruptions (phone calls, Siri, etc.)
        let audioInterruption = nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioInterruption(notification)
        }
        appLifecycleObservers.append(audioInterruption)

        // ✅ ROUTE CHANGE: Handle audio route changes (headphones plugged/unplugged)
        let routeChange = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioRouteChange(notification)
        }
        appLifecycleObservers.append(routeChange)

        logger.info("✅ Continuous session management configured")
    }

    /// Handle app going to background - maintain audio session for continuous listening
    private func handleWillResignActive() {
        guard isListening else { return }
        logger.info("📱 App backgrounding - maintaining audio session for ambient mode")

        // Audio session stays active for background listening
        // Live Activities keep the session alive
    }

    /// Handle app returning to foreground - check if we need to restart
    private func handleDidBecomeActive() {
        guard isListening else { return }
        logger.info("📱 App foregrounding - checking audio engine health")

        // Check if audio engine stalled while backgrounded
        let timeSinceLastBuffer = Date().timeIntervalSince(lastAudioBufferTime)
        if timeSinceLastBuffer > 5.0 {  // No buffers for 5+ seconds = stalled
            logger.warning("⚠️ Audio engine stalled (\(timeSinceLastBuffer)s), restarting")
            Task {
                await restartAudioEngine()
            }
        }
    }

    /// Handle audio interruptions (phone calls, Siri, notifications, etc.)
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            logger.info("🔕 Audio interruption began (phone call, Siri, etc.)")
            // Don't stop listening - just pause audio engine
            // We'll resume when interruption ends
            if audioEngine.isRunning {
                audioEngine.pause()
            }

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) && isListening {
                logger.info("🔔 Audio interruption ended - resuming ambient mode")
                Task {
                    await restartAudioEngine()
                }
            }

        @unknown default:
            break
        }
    }

    /// Handle audio route changes (headphones plugged/unplugged, Bluetooth connected/disconnected)
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable:
            logger.info("🎧 New audio device connected")
            // Continue listening on new device

        case .oldDeviceUnavailable:
            logger.info("🎧 Audio device disconnected")
            // Continue with built-in mic/speaker
            if isListening {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)  // Brief delay
                    await restartAudioEngine()
                }
            }

        default:
            break
        }
    }

    /// Restart audio engine gracefully (for interruptions, route changes, stalls)
    private func restartAudioEngine() async {
        guard isListening && !isHandlingInterruption else { return }

        isHandlingInterruption = true
        logger.info("🔄 Restarting audio engine...")

        // Stop current engine
        audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()

        // Brief pause to let system settle
        try? await Task.sleep(nanoseconds: 250_000_000)  // 0.25 seconds

        // Restart recognition
        await startContinuousRecognition()

        isHandlingInterruption = false
        logger.info("✅ Audio engine restarted")
    }

    /// Track audio buffer timing for health monitoring
    private func updateLastAudioBufferTime() {
        lastAudioBufferTime = Date()
    }

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
        
        // ✅ ROLLING BUFFER: Keep only recent audio (~5 seconds at 30 buffers/sec)
        // This prevents memory bloat during long ambient sessions
        if self.audioBufferForWhisper.count >= maxWhisperBufferCount {
            // Remove oldest buffers, keep most recent (rolling window)
            let removeCount = self.audioBufferForWhisper.count - (maxWhisperBufferCount / 2)
            self.audioBufferForWhisper.removeFirst(removeCount)

            if self.audioBufferForWhisper.count % 50 == 0 {  // Log occasionally
                logger.debug("🔄 Rolling buffer: trimmed \(removeCount) old buffers, keeping \(self.audioBufferForWhisper.count)")
            }
        }

        self.audioBufferForWhisper.append(bufferCopy)
        // Log only every 10th buffer to reduce spam
        if audioBufferForWhisper.count % 10 == 0 {
            logger.debug("Added buffer to Whisper queue. Total buffers: \(self.audioBufferForWhisper.count)")
        }
        
        // Start the processing timer only if it's not already running
        if whisperProcessingTimer == nil {
            logger.info("Starting Whisper processing timer (\(Int(self.whisperBufferDuration)) seconds)")
            whisperProcessingTimer = Timer.scheduledTimer(withTimeInterval: self.whisperBufferDuration, repeats: true) { [weak self] _ in
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
            // Don't clear buffers on combine failure - might be temporary
            return 
        }
        
        logger.info("Combined buffer: \(combinedBuffer.frameLength) frames, format: \(combinedBuffer.format)")
        
        // Calculate duration
        let duration = Double(combinedBuffer.frameLength) / combinedBuffer.format.sampleRate
        logger.info("Audio duration: \(String(format: "%.2f", duration)) seconds")
        
        // Check if we have enough audio (at least 0.5 seconds)
        guard duration >= 0.5 else {
            logger.info("Not enough audio for WhisperKit (need at least 0.5 seconds, got \(String(format: "%.2f", duration))s)")
            // Don't clear buffers if not enough audio - wait for more
            isProcessingWhisper = false
            return
        }
        
        // Check if Whisper model is loaded
        guard self.whisperProcessor.isModelLoaded else {
            logger.warning("Whisper model not loaded yet")
            // Don't clear buffers if model not loaded - wait for it to load
            isProcessingWhisper = false
            return
        }
        
        // Clear the buffer only after all checks pass
        audioBufferForWhisper.removeAll()
        
        // Process with Whisper
        isProcessingWhisper = true
        
        do {
            logger.info("Starting Whisper transcription...")
            let result = try await self.whisperProcessor.transcribe(audioBuffer: combinedBuffer)
            
            // Check if Whisper failed and use fallback
            if result.text == "[BLANK_AUDIO]" || result.text.isEmpty {
                logger.warning("Whisper returned blank audio, using Apple transcription as fallback")
                
                // Use Apple's transcription as fallback if available
                if !transcribedText.isEmpty && isListeningInAmbientMode {
                    whisperTranscribedText = "[Fallback] \(transcribedText)"
                    whisperConfidence = confidenceScore

                    logger.warning("⚠️ WhisperKit returned blank, falling back to Apple Speech (less accurate)")

                    // Process with Apple Speech as fallback
                    Task {
                        await TrueAmbientProcessor.shared.processDetectedText(transcribedText, confidence: confidenceScore)
                    }
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
                
                logger.info("✅ Whisper transcription: \(result.text) (confidence: \(avgConfidence), language: \(result.language ?? "unknown"))")

                // CRITICAL: Use WhisperKit as PRIMARY transcription engine
                // Apple Speech is only for real-time UI feedback
                // WhisperKit is more accurate, especially with names like "Odysseus" (not "Otis")
                if isListeningInAmbientMode && !result.text.isEmpty {
                    // Process with TrueAmbientProcessor using WhisperKit's ACCURATE transcription
                    Task {
                        logger.info("🎯 Using WhisperKit transcription for processing: \(result.text)")
                        await TrueAmbientProcessor.shared.processDetectedText(result.text, confidence: avgConfidence)
                    }
                }

                // Also post notification for any other listeners
                NotificationCenter.default.post(
                    name: Notification.Name("WhisperTranscriptionReady"),
                    object: result.text as NSString
                )
            }
        } catch {
            logger.error("Whisper transcription failed: \(error.localizedDescription)")

            // Use Apple transcription as fallback on error
            if !transcribedText.isEmpty && isListeningInAmbientMode {
                whisperTranscribedText = "[Error fallback] \(transcribedText)"
                whisperConfidence = confidenceScore * 0.8 // Reduce confidence for fallback

                logger.warning("⚠️ WhisperKit error, falling back to Apple Speech")

                // Process with Apple Speech as fallback
                Task {
                    await TrueAmbientProcessor.shared.processDetectedText(transcribedText, confidence: confidenceScore * 0.8)
                }
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
        
        guard let channelData = combinedBuffer.floatChannelData else {
            logger.error("Failed to get combinedBuffer channel data")
            return nil
        }
        var writePointer = channelData[0]
        
        for buffer in buffers {
            guard let bufferChannelData = buffer.floatChannelData else {
                logger.error("Failed to get buffer channel data")
                continue
            }
            let readPointer = bufferChannelData[0]
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
            
            // Test method removed - use transcribe() directly
            // let result = try await self.whisperProcessor.testTranscription()
            // logger.info("WhisperKit test result: '\(result)'")
            
            // Update UI
            await MainActor.run {
                self.whisperTranscribedText = "WhisperKit loaded successfully"
            }
        } catch {
            logger.error("WhisperKit test error: \(error)")
            await MainActor.run {
                self.whisperTranscribedText = "Test error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Natural Book Detection
    
    func startAmbientListeningMode() {
        isListeningInAmbientMode = true
        startAmbientListening()
    }
    
    func stopAmbientListeningMode() {
        isListeningInAmbientMode = false
        stopListening()
    }
    
    // Public method to update library books
    func updateLibraryBooks(_ books: [Book]) {
        self.libraryBooks = books
        logger.info("Updated library books for voice detection: \(books.count) books")
    }

    // MARK: - Book Enrichment Integration

    // Store enriched context to apply on next recognition session
    private var pendingEnrichedContext: [String] = []

    /// Load enriched data for the current book
    /// Call this when starting ambient mode to warm up character names
    @MainActor
    func loadEnrichmentForCurrentBook(modelContext: ModelContext?) async {
        guard let book = AmbientBookDetector.shared.detectedBook else {
            logger.info("No book detected yet for enrichment")
            return
        }

        guard let modelContext = modelContext else {
            logger.warning("No model context available for enrichment lookup")
            return
        }

        logger.info("📚 Loading enrichment data for '\(book.title)'...")

        do {
            // Fetch the BookModel for this Book
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { bookModel in
                    bookModel.id == book.id || bookModel.localId == book.localId.uuidString
                }
            )

            let results = try modelContext.fetch(descriptor)

            if let bookModel = results.first {
                pendingEnrichedContext.removeAll()

                // Add enriched character names (THE WHOLE POINT!)
                if let characters = bookModel.majorCharacters, !characters.isEmpty {
                    pendingEnrichedContext.append(contentsOf: characters)
                    logger.info("✅ Loaded \(characters.count) enriched characters: \(characters.joined(separator: ", "))")
                } else {
                    logger.warning("⚠️ No enriched characters for '\(book.title)' - book may need enrichment")
                }

                // Add key themes
                if let themes = bookModel.keyThemes, !themes.isEmpty {
                    pendingEnrichedContext.append(contentsOf: themes)
                    logger.info("✅ Loaded \(themes.count) themes: \(themes.joined(separator: ", "))")
                }

                // Add series name if available
                if let seriesName = bookModel.seriesName {
                    pendingEnrichedContext.append(seriesName)
                }

                if pendingEnrichedContext.isEmpty {
                    logger.warning("⚠️ '\(book.title)' has NO enrichment data - needs to run BookEnrichmentService")
                    logger.warning("   Without enrichment, 'Odysseus' might be heard as 'Otis'")
                }
            } else {
                logger.warning("⚠️ No BookModel found for '\(book.title)' - enrichment not available")
            }
        } catch {
            logger.error("Failed to fetch enriched data: \(error)")
        }
    }
    
    private func detectBookFromSpeech(_ text: String) {
        let lowercased = text.lowercased()

        // ONLY detect explicit book-switching intent, NOT general questions
        // Removed generic patterns like "reading ", "in ", "from " that trigger on everything
        // This was causing "Who is Gandalf?" to auto-switch from Odyssey to Lord of the Rings
        let patterns = [
            "i'm reading ",
            "i am reading ",
            "currently reading ",
            "just finished reading ",
            "started reading ",
            "switch to ",
            "change to "
        ]

        // Check for book mentions with explicit intent
        for pattern in patterns {
            if let range = lowercased.range(of: pattern) {
                let afterPattern = String(text[range.upperBound...])

                // Try to match against library books
                if let matchedBook = fuzzyMatchBook(afterPattern) {
                    // Update coordinator
                    SimplifiedAmbientCoordinator.shared.setBookContext(matchedBook)
                    logger.info("📖 Book detected from explicit intent '\(pattern)': \(matchedBook.title)")
                    return
                }
            }
        }

        // REMOVED: Fuzzy title matching on every input
        // This was causing character names and topics to switch books inappropriately
        // Users should explicitly say "switch to [book]" or "I'm reading [book]" to change context
    }
    
    private func fuzzyMatchBook(_ text: String) -> Book? {
        // Use stored library books
        let books = self.libraryBooks
        
        let lowercasedText = text.lowercased()
        
        for book in books {
            let bookTitle = book.title.lowercased()
            let bookWords = bookTitle.split(separator: " ")
            
            // Check if enough title words appear in text
            let matchingWords = bookWords.filter { word in
                lowercasedText.contains(word)
            }
            
            // 60% match threshold
            if !bookWords.isEmpty && Double(matchingWords.count) / Double(bookWords.count) > 0.6 {
                return book
            }
            
            // Also check author name
            let authorName = book.author.lowercased()
            if authorName.count > 3 && lowercasedText.contains(authorName) {
                return book
            }
        }
        
        return nil
    }
    
    private func fuzzyMatchBookTitle(in text: String) -> Book? {
        // Use stored library books
        let books = self.libraryBooks
        let lowercasedText = text.lowercased()
        
        // Direct title matching with some flexibility
        for book in books {
            let bookTitle = book.title.lowercased()
            
            // Check for exact title match
            if lowercasedText.contains(bookTitle) {
                return book
            }
            
            // Check for title without articles
            let titleWithoutArticles = bookTitle
                .replacingOccurrences(of: "the ", with: "")
                .replacingOccurrences(of: "a ", with: "")
                .replacingOccurrences(of: "an ", with: "")
            
            if titleWithoutArticles.count > 3 && lowercasedText.contains(titleWithoutArticles) {
                return book
            }
        }
        
        return nil
    }
    
    // Voice commands for ambient mode
    func processAmbientVoiceCommand(_ text: String) {
        let lowercased = text.lowercased()
        
        // Switch book command
        if lowercased.contains("switch to") || lowercased.contains("change to") {
            for pattern in ["switch to ", "change to "] {
                if let range = lowercased.range(of: pattern) {
                    let bookName = String(text[range.upperBound...])
                    if let book = fuzzyMatchBook(bookName) {
                        SimplifiedAmbientCoordinator.shared.setBookContext(book)
                        speakBookConfirmation(book)
                    }
                    return
                }
            }
        }
        
        // What book am I reading?
        if lowercased.contains("what book") || lowercased.contains("which book") {
            if let currentBook = SimplifiedAmbientCoordinator.shared.currentBook {
                speakBookConfirmation(currentBook)
            } else {
                speak("No book selected")
            }
            return
        }
        
        // Clear book context
        if lowercased.contains("clear book") || lowercased.contains("remove book") {
            SimplifiedAmbientCoordinator.shared.clearBookContext()
            speak("Book context cleared")
            return
        }
        
        // Done reading / exit
        if lowercased.contains("i'm done") || lowercased.contains("done reading") || lowercased.contains("stop ambient") {
            SimplifiedAmbientCoordinator.shared.closeAmbientReading()
            return
        }
    }
    
    private func speakBookConfirmation(_ book: Book) {
        speak("Now reading \(book.title)")
    }
    
    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }

    /// Calculates optimal pause duration based on user's speaking patterns and current context
    /// This makes the system work for slow/thoughtful speakers while staying responsive
    private func calculateAdaptiveTimerDuration() -> TimeInterval {
        // Base duration: 2.0 seconds (our new baseline)
        var duration: TimeInterval = 2.0

        // FACTOR 1: User's historical pause patterns
        // If user typically pauses 3-4 seconds between thoughts, adapt to that
        if userPauseHistory.count >= 3 {
            let averagePause = userPauseHistory.reduce(0, +) / Double(userPauseHistory.count)
            let maxRecentPause = userPauseHistory.suffix(5).max() ?? 2.0

            // Use the larger of average or recent max, but cap at 4 seconds
            duration = max(duration, min(averagePause, 4.0))
            duration = max(duration, min(maxRecentPause, 4.0))

            logger.debug("📊 Adaptive timer: User avg pause = \(String(format: "%.1f", averagePause))s, using \(String(format: "%.1f", duration))s")
        }

        // FACTOR 2: Confidence score trends
        // If confidence is dropping, user might be mid-word - extend timer
        if recentConfidenceScores.count >= 3 {
            let recentScores = Array(recentConfidenceScores.suffix(3))
            let isDecreasing = recentScores[2] < recentScores[1] && recentScores[1] < recentScores[0]

            if isDecreasing {
                duration += 0.5 // Add 500ms if confidence dropping (speech likely continuing)
                logger.debug("📉 Confidence dropping, extending timer to \(String(format: "%.1f", duration))s")
            }
        }

        // FACTOR 3: Voice Activity Detection
        // If VAD still detecting potential speech, extend timer
        if lastVADSignal {
            duration += 0.5 // Add 500ms if voice activity detected
            logger.debug("🎤 VAD signal active, extending timer to \(String(format: "%.1f", duration))s")
        }

        // FACTOR 4: Question detection
        // If current text looks like start of question, be MORE patient (increased delay)
        let lowerText = pendingTranscription.lowercased()
        let questionStarters = ["who", "what", "where", "when", "why", "how", "is", "are", "can", "could", "should", "would"]
        let startsWithQuestion = questionStarters.contains(where: { lowerText.hasPrefix($0 + " ") })
        let hasQuestionMark = pendingTranscription.contains("?")

        // INCREASED: Give questions 2 seconds extra (was 1 second) to stabilize
        // This prevents "Who is Otis?" when user said "Who is Odysseus?"
        if startsWithQuestion || hasQuestionMark {
            duration += 2.0  // Increased from 1.0
            logger.debug("❓ Question detected, extending timer to \(String(format: "%.1f", duration))s for transcription stability")
        }

        // Cap at 5 seconds max to avoid waiting forever
        duration = min(duration, 5.0)

        return duration
    }

    /// Track user's pause after completing a thought (for learning patterns)
    private func trackUserPause(duration: TimeInterval) {
        userPauseHistory.append(duration)

        // Keep only last 20 pauses for rolling average
        if userPauseHistory.count > 20 {
            userPauseHistory.removeFirst()
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
