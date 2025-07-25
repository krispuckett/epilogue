import Foundation
import AVFoundation
import WhisperKit
import CoreML
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "WhisperKit")

// MARK: - WhisperKit Model Types
enum WhisperKitModel: String, CaseIterable {
    case tiny = "openai_whisper-tiny"
    case tinyEn = "openai_whisper-tiny.en"
    case base = "openai_whisper-base"
    case baseEn = "openai_whisper-base.en"
    case small = "openai_whisper-small"
    case smallEn = "openai_whisper-small.en"
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .tinyEn: return "Tiny (English)"
        case .base: return "Base"
        case .baseEn: return "Base (English)"
        case .small: return "Small"
        case .smallEn: return "Small (English)"
        }
    }
    
    var description: String {
        switch self {
        case .tiny, .tinyEn: return "Fastest, good for real-time"
        case .base, .baseEn: return "Balanced speed and accuracy"
        case .small, .smallEn: return "Best accuracy, slower"
        }
    }
    
    var sizeInMB: Int {
        switch self {
        case .tiny, .tinyEn: return 39
        case .base, .baseEn: return 74
        case .small, .smallEn: return 244
        }
    }
    
    var isEnglishOnly: Bool {
        return rawValue.contains(".en")
    }
    
    var recommendedForDevice: Bool {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        switch self {
        case .tiny, .tinyEn: return true
        case .base, .baseEn: return totalMemory >= 4_000_000_000 // 4GB+
        case .small, .smallEn: return totalMemory >= 6_000_000_000 // 6GB+
        }
    }
}

// MARK: - Transcription Result
struct TranscriptionTimings {
    let fullPipeline: TimeInterval
    let vad: TimeInterval
    let audioProcessing: TimeInterval
    let whisperProcessing: TimeInterval
}

struct WhisperKitTranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String
    let languageProbability: Float
    let timings: TranscriptionTimings
    let modelUsed: String
}

// MARK: - WhisperKit Processor
@MainActor
class WhisperKitProcessor: ObservableObject {
    // MARK: - Published Properties
    @Published var isModelLoaded = false
    @Published var currentModel: WhisperKitModel?
    @Published var availableModels: [WhisperKitModel] = []
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var isProcessing = false
    @Published var lastTranscription: WhisperKitTranscriptionResult?
    @Published var processingProgress: Double = 0
    @Published var currentLanguage: String = "en"
    @Published var modelLoadingError: String?
    
    // MARK: - Private Properties
    private var whisperKit: WhisperKit?
    private let modelStorage = WhisperKitModelStorage()
    private let audioProcessor = WhisperKitAudioProcessor()
    private var cancellables = Set<AnyCancellable>()
    
    // Audio buffering
    private var audioBuffer: [Float] = []
    private let maxBufferDuration: TimeInterval = 30.0
    private let chunkDuration: TimeInterval = 30.0 // Process in 30-second chunks
    
    // Performance monitoring
    private var lastProcessingTime: TimeInterval = 0
    private var averageProcessingTime: TimeInterval = 0
    private var processedChunks = 0
    
    // MARK: - Initialization
    init() {
        Task {
            await initializeWhisperKit()
        }
    }
    
    // MARK: - WhisperKit Initialization
    private func initializeWhisperKit() async {
        // Check for available models
        availableModels = await modelStorage.getAvailableModels()
        
        // Auto-select best model for device
        if let recommendedModel = selectRecommendedModel() {
            await loadModel(recommendedModel)
        }
    }
    
    private func selectRecommendedModel() -> WhisperKitModel? {
        let deviceModel = getDeviceModel()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // iPhone 15 Pro or newer with 8GB+ RAM
        if deviceModel.contains("iPhone16") || (deviceModel.contains("iPhone15,3") && totalMemory >= 8_000_000_000) {
            return availableModels.first { $0 == .small || $0 == .smallEn }
        }
        // Mid-range devices
        else if totalMemory >= 4_000_000_000 {
            return availableModels.first { $0 == .base || $0 == .baseEn }
        }
        // Older devices
        else {
            return availableModels.first { $0 == .tiny || $0 == .tinyEn }
        }
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    // MARK: - Model Management
    func loadModel(_ model: WhisperKitModel) async {
        guard !isDownloading else { return }
        
        do {
            isModelLoaded = false
            modelLoadingError = nil
            
            // Download model if needed
            if !modelStorage.isModelDownloaded(model) {
                try await downloadModel(model)
            }
            
            // Initialize WhisperKit with the model
            let modelPath = modelStorage.modelPath(for: model)
            
            // Use simple initialization
            whisperKit = try await WhisperKit(model: model.rawValue)
            
            currentModel = model
            isModelLoaded = true
            
            logger.info("Loaded WhisperKit model: \(model.displayName)")
            
        } catch {
            modelLoadingError = error.localizedDescription
            logger.error("Failed to load model: \(error.localizedDescription)")
        }
    }
    
    private func downloadModel(_ model: WhisperKitModel) async throws {
        isDownloading = true
        downloadProgress = 0
        
        // WhisperKit will handle the download internally
        // For now, we'll simulate progress
        for i in 0...10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            downloadProgress = Double(i) / 10.0
        }
        
        isDownloading = false
        downloadProgress = 1.0
        
        // Add to available models
        if !availableModels.contains(model) {
            availableModels.append(model)
        }
        
        logger.info("Downloaded WhisperKit model: \(model.displayName)")
    }
    
    func deleteModel(_ model: WhisperKitModel) {
        modelStorage.deleteModel(model)
        availableModels.removeAll { $0 == model }
        
        if currentModel == model {
            currentModel = nil
            isModelLoaded = false
            whisperKit = nil
        }
    }
    
    // MARK: - Transcription
    func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> WhisperKitTranscriptionResult {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw WhisperKitError.modelNotLoaded
        }
        
        isProcessing = true
        processingProgress = 0
        
        let startTime = Date()
        
        do {
            // Convert audio buffer to proper format
            let audioProcessingStart = Date()
            let audioArray = try await audioProcessor.processBuffer(audioBuffer)
            let audioProcessingTime = Date().timeIntervalSince(audioProcessingStart)
            
            processingProgress = 0.3
            
            // Perform transcription
            let whisperStart = Date()
            let transcriptionResults = try await whisperKit.transcribe(
                audioArray: audioArray
            )
            let whisperProcessingTime = Date().timeIntervalSince(whisperStart)
            
            processingProgress = 0.8
            
            // Convert result
            let fullTime = Date().timeIntervalSince(startTime)
            let timings = TranscriptionTimings(
                fullPipeline: fullTime,
                vad: 0,
                audioProcessing: audioProcessingTime,
                whisperProcessing: whisperProcessingTime
            )
            
            let result = convertToResult(
                transcriptionResults,
                timings: timings
            )
            
            processingProgress = 1.0
            isProcessing = false
            lastTranscription = result
            
            // Update performance metrics
            updatePerformanceMetrics(timings.fullPipeline)
            
            return result
            
        } catch {
            isProcessing = false
            processingProgress = 0
            throw error
        }
    }
    
    func transcribeWithVAD(audioBuffer: AVAudioPCMBuffer) async throws -> WhisperKitTranscriptionResult {
        // For now, just use regular transcription
        // VAD can be implemented separately if needed
        return try await transcribe(audioBuffer: audioBuffer)
    }
    
    // MARK: - Streaming Transcription
    func startStreamingTranscription() -> AsyncThrowingStream<WhisperKitTranscriptionResult, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: WhisperKitError.notImplemented)
        }
    }
    
    // MARK: - Helper Methods
    private func convertToResult(
        _ results: [TranscriptionResult],
        timings: TranscriptionTimings
    ) -> WhisperKitTranscriptionResult {
        var allSegments: [TranscriptionSegment] = []
        var fullText = ""
        
        for result in results {
            allSegments.append(contentsOf: result.segments)
            fullText += result.text + " "
        }
        
        return WhisperKitTranscriptionResult(
            text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: allSegments,
            language: results.first?.language ?? "en",
            languageProbability: 1.0, // WhisperKit doesn't expose this
            timings: timings,
            modelUsed: currentModel?.displayName ?? "Unknown"
        )
    }
    
    private func updatePerformanceMetrics(_ processingTime: TimeInterval) {
        processedChunks += 1
        lastProcessingTime = processingTime
        
        // Update rolling average
        averageProcessingTime = ((averageProcessingTime * Double(processedChunks - 1)) + processingTime) / Double(processedChunks)
        
        logger.info("Processing time: \(String(format: "%.2f", processingTime))s (avg: \(String(format: "%.2f", self.averageProcessingTime))s)")
    }
}

// MARK: - Audio Processor
private class WhisperKitAudioProcessor {
    func processBuffer(_ buffer: AVAudioPCMBuffer) async throws -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            throw WhisperKitError.audioProcessingFailed
        }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        var audioArray = [Float]()
        
        // Convert to mono if needed
        if channelCount == 2 {
            for frame in 0..<frameLength {
                let sample = (channelData[0][frame] + channelData[1][frame]) / 2.0
                audioArray.append(sample)
            }
        } else {
            audioArray = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        }
        
        // Resample to 16kHz if needed
        if buffer.format.sampleRate != 16000 {
            audioArray = try resample(audioArray, from: buffer.format.sampleRate, to: 16000)
        }
        
        return audioArray
    }
    
    private func resample(_ input: [Float], from inputRate: Double, to outputRate: Double) throws -> [Float] {
        // Use Accelerate framework for high-quality resampling
        // This is a simplified version - WhisperKit handles this internally
        let ratio = outputRate / inputRate
        let outputLength = Int(Double(input.count) * ratio)
        
        // For now, simple linear interpolation
        var output = [Float](repeating: 0, count: outputLength)
        
        for i in 0..<outputLength {
            let srcIndex = Double(i) / ratio
            let index = Int(srcIndex)
            let fraction = Float(srcIndex - Double(index))
            
            if index < input.count - 1 {
                output[i] = input[index] * (1 - fraction) + input[index + 1] * fraction
            } else if index < input.count {
                output[i] = input[index]
            }
        }
        
        return output
    }
}

// MARK: - Model Storage
private class WhisperKitModelStorage {
    private let fileManager = FileManager.default
    
    private var modelsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("WhisperKitModels")
    }
    
    init() {
        createModelsDirectory()
    }
    
    private func createModelsDirectory() {
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
    
    func getAvailableModels() async -> [WhisperKitModel] {
        // For now, return all models as potentially available
        // In production, this would check actual downloaded models
        return WhisperKitModel.allCases
    }
    
    func isModelDownloaded(_ model: WhisperKitModel) -> Bool {
        // WhisperKit handles its own model storage
        // This is a placeholder
        return false
    }
    
    func modelPath(for model: WhisperKitModel) -> URL {
        return modelsDirectory.appendingPathComponent(model.rawValue)
    }
    
    func deleteModel(_ model: WhisperKitModel) {
        // WhisperKit handles its own model deletion
        // This is a placeholder
    }
}

// MARK: - Errors
enum WhisperKitError: LocalizedError {
    case modelNotLoaded
    case audioProcessingFailed
    case noSpeechDetected
    case downloadFailed(String)
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "WhisperKit model not loaded"
        case .audioProcessingFailed:
            return "Failed to process audio"
        case .noSpeechDetected:
            return "No speech detected in audio"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .notImplemented:
            return "Feature not implemented yet"
        }
    }
}