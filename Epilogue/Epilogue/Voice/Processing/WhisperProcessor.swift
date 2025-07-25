import Foundation
import AVFoundation
import Combine
import OSLog
import WhisperKit

private let logger = Logger(subsystem: "com.epilogue", category: "WhisperProcessor")

// MARK: - WhisperProcessor
// This is a bridge to WhisperKitProcessor that maintains compatibility
// with the existing VoiceRecognitionManager interface
@MainActor
class WhisperProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0.0
    @Published var lastTranscription: WhisperKitTranscriptionResult?
    @Published var isModelLoaded = false
    @Published var currentLanguage: String = "en"
    @Published var availableModels: [WhisperKitModel] = []
    @Published var currentModel: WhisperKitModel?
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    
    // Use WhisperKitProcessor instead of whisper.cpp
    private let whisperKitProcessor = WhisperKitProcessor()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func loadModel(_ model: WhisperKitModel) async throws {
        await whisperKitProcessor.loadModel(model)
        isModelLoaded = whisperKitProcessor.isModelLoaded
        currentModel = whisperKitProcessor.currentModel
    }
    
    func deleteModel(_ model: WhisperKitModel) {
        whisperKitProcessor.deleteModel(model)
    }
    
    func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> WhisperKitTranscriptionResult {
        guard isModelLoaded else {
            throw WhisperKitError.modelNotLoaded
        }
        
        isProcessing = true
        let result = try await whisperKitProcessor.transcribe(audioBuffer: audioBuffer)
        
        lastTranscription = result
        isProcessing = false
        
        logger.info("Transcription completed in \(String(format: "%.2f", result.timings.fullPipeline))s: \(result.text)")
        
        return result
    }
    
    func transcribeFromFile(url: URL) async throws -> WhisperKitTranscriptionResult {
        guard isModelLoaded else {
            throw WhisperKitError.modelNotLoaded
        }
        
        // Load audio file
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw WhisperKitError.audioProcessingFailed
        }
        
        try audioFile.read(into: buffer)
        buffer.frameLength = frameCount
        
        return try await transcribe(audioBuffer: buffer)
    }
    
    func transcribeWithVAD(audioBuffer: AVAudioPCMBuffer) async throws -> WhisperKitTranscriptionResult {
        return try await whisperKitProcessor.transcribeWithVAD(audioBuffer: audioBuffer)
    }
    
    func startStreamingTranscription() -> AsyncThrowingStream<WhisperKitTranscriptionResult, Error> {
        return whisperKitProcessor.startStreamingTranscription()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Sync processing state
        whisperKitProcessor.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessing)
        
        // Sync progress
        whisperKitProcessor.$processingProgress
            .receive(on: DispatchQueue.main)
            .map { Float($0) }
            .assign(to: &$processingProgress)
        
        // Sync model loaded state
        whisperKitProcessor.$isModelLoaded
            .receive(on: DispatchQueue.main)
            .assign(to: &$isModelLoaded)
        
        // Sync language
        whisperKitProcessor.$currentLanguage
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentLanguage)
        
        // Sync available models
        whisperKitProcessor.$availableModels
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableModels)
        
        // Sync current model
        whisperKitProcessor.$currentModel
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentModel)
        
        // Sync download progress
        whisperKitProcessor.$downloadProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$downloadProgress)
        
        // Sync downloading state
        whisperKitProcessor.$isDownloading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isDownloading)
        
        // Auto-select model on startup
        Task {
            // Wait for initialization
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            if let recommendedModel = whisperKitProcessor.availableModels.first(where: { $0.recommendedForDevice }) {
                try? await loadModel(recommendedModel)
            }
        }
    }
}

// Re-export WhisperKit types for compatibility
typealias WhisperTranscriptionResult = WhisperKitTranscriptionResult
typealias WhisperError = WhisperKitError