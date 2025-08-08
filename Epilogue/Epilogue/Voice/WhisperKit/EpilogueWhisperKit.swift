import Foundation
import WhisperKit

// MARK: - Epilogue WhisperKit Types

// Custom model enum for Epilogue
enum EpilogueWhisperModel: String, CaseIterable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    var recommendedForDevice: Bool {
        // Recommend base model as default for most devices
        return self == .base
    }
}

// TranscriptionSegment - represents a segment of transcribed audio
struct TranscriptionSegment {
    let text: String
    let start: TimeInterval
    let end: TimeInterval
    let probability: Float
    
    // Computed property for compatibility
    var avgLogprob: Float {
        return log(probability)
    }
}

// Custom transcription result for Epilogue
struct EpilogueTranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String
    let languageProbability: Float
    let timings: EpilogueTranscriptionTimings
    let modelUsed: String
}

// Custom timing structure
struct EpilogueTranscriptionTimings {
    let fullPipeline: TimeInterval
    let vad: TimeInterval
    let audioProcessing: TimeInterval
    let whisperProcessing: TimeInterval
}

// Custom error types
enum EpilogueWhisperError: LocalizedError {
    case modelNotLoaded
    case audioProcessingFailed
    case transcriptionFailed
    case invalidAudioBuffer
    case audioTooQuiet(String)
    case fallbackUnavailable
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model not loaded"
        case .audioProcessingFailed:
            return "Audio processing failed"
        case .transcriptionFailed:
            return "Transcription failed"
        case .invalidAudioBuffer:
            return "Invalid audio buffer"
        case .audioTooQuiet(let message):
            return message
        case .fallbackUnavailable:
            return "Speech recognition fallback unavailable"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
}

// TranscriptionResult - result from WhisperKit transcription
struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?
    let languageProbability: Float?
    let timings: EpilogueTranscriptionTimings?
}

// Note: DecodingOptions is now imported from WhisperKit directly

// Note: This extension is removed to avoid conflicts with the actual WhisperKit API
// The OptimizedWhisperProcessor will use WhisperKit's native methods directly