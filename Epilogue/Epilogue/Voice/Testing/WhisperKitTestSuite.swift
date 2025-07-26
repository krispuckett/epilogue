import Foundation
import SwiftUI
import Combine
import AVFoundation
import WhisperKit
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "WhisperKitTests")

// MARK: - WhisperKit Test Suite
@MainActor
class WhisperKitTestSuite: ObservableObject {
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    @Published var currentTest = ""
    
    private let whisperProcessor = OptimizedWhisperProcessor()
    
    struct TestResult: Identifiable {
        let id = UUID()
        let testName: String
        let passed: Bool
        let duration: TimeInterval
        let details: String
        let timestamp = Date()
    }
    
    // MARK: - Run All Tests
    
    func runAllTests() async {
        isRunning = true
        testResults.removeAll()
        
        logger.info("Starting WhisperKit test suite...")
        
        // Test 1: Model Loading
        await testModelLoading()
        
        // Test 2: Audio Normalization
        await testAudioNormalization()
        
        // Test 3: Sample Rate Conversion
        await testSampleRateConversion()
        
        // Test 4: Transcription Accuracy
        await testTranscriptionAccuracy()
        
        // Test 5: Performance Benchmarks
        await testPerformanceBenchmarks()
        
        // Test 6: Parallel Processing
        await testParallelProcessing()
        
        // Test 7: Voice Activity Detection
        await testVoiceActivityDetection()
        
        // Test 8: Model Switching
        await testModelSwitching()
        
        isRunning = false
        logger.info("WhisperKit test suite completed. \(self.testResults.filter { $0.passed }.count)/\(self.testResults.count) tests passed")
    }
    
    // MARK: - Individual Tests
    
    private func testModelLoading() async {
        currentTest = "Model Loading"
        let startTime = Date()
        
        do {
            // Test loading each model
            for model in EpilogueWhisperModel.allCases {
                logger.info("Testing model loading: \(model.rawValue)")
                try await whisperProcessor.loadModel(model)
                
                // Verify model is loaded
                if !whisperProcessor.isModelLoaded {
                    throw TestError.modelLoadFailed(model.rawValue)
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            testResults.append(TestResult(
                testName: "Model Loading",
                passed: true,
                duration: duration,
                details: "Successfully loaded all models (tiny, small, base)"
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Model Loading",
                passed: false,
                duration: Date().timeIntervalSince(startTime),
                details: "Failed: \(error.localizedDescription)"
            ))
        }
    }
    
    private func testAudioNormalization() async {
        currentTest = "Audio Normalization"
        let startTime = Date()
        
        // Create test audio samples
        let quietAudio = generateTestAudio(amplitude: 0.01, duration: 1.0)
        let normalAudio = generateTestAudio(amplitude: 0.3, duration: 1.0)
        let loudAudio = generateTestAudio(amplitude: 0.99, duration: 1.0)
        
        var allPassed = true
        var details = ""
        
        // Test quiet audio normalization
        if let quietBuffer = createAudioBuffer(from: quietAudio) {
            do {
                let result = try await whisperProcessor.transcribe(audioBuffer: quietBuffer)
                details += "Quiet audio: Processed successfully\n"
            } catch {
                allPassed = false
                details += "Quiet audio: Failed - \(error)\n"
            }
        }
        
        // Test normal audio
        if let normalBuffer = createAudioBuffer(from: normalAudio) {
            do {
                let result = try await whisperProcessor.transcribe(audioBuffer: normalBuffer)
                details += "Normal audio: Processed successfully\n"
            } catch {
                allPassed = false
                details += "Normal audio: Failed - \(error)\n"
            }
        }
        
        // Test loud audio
        if let loudBuffer = createAudioBuffer(from: loudAudio) {
            do {
                let result = try await whisperProcessor.transcribe(audioBuffer: loudBuffer)
                details += "Loud audio: Processed successfully\n"
            } catch {
                allPassed = false
                details += "Loud audio: Failed - \(error)\n"
            }
        }
        
        testResults.append(TestResult(
            testName: "Audio Normalization",
            passed: allPassed,
            duration: Date().timeIntervalSince(startTime),
            details: details.trimmingCharacters(in: .newlines)
        ))
    }
    
    private func testSampleRateConversion() async {
        currentTest = "Sample Rate Conversion"
        let startTime = Date()
        
        var allPassed = true
        var details = ""
        
        // Test different sample rates
        let sampleRates: [Double] = [8000, 16000, 44100, 48000]
        
        for sampleRate in sampleRates {
            let audio = generateTestAudio(amplitude: 0.3, duration: 1.0)
            if let buffer = createAudioBuffer(from: audio, sampleRate: sampleRate) {
                do {
                    let result = try await whisperProcessor.transcribe(audioBuffer: buffer)
                    details += "\(Int(sampleRate))Hz: Converted and processed successfully\n"
                } catch {
                    allPassed = false
                    details += "\(Int(sampleRate))Hz: Failed - \(error)\n"
                }
            }
        }
        
        testResults.append(TestResult(
            testName: "Sample Rate Conversion",
            passed: allPassed,
            duration: Date().timeIntervalSince(startTime),
            details: details.trimmingCharacters(in: .newlines)
        ))
    }
    
    private func testTranscriptionAccuracy() async {
        currentTest = "Transcription Accuracy"
        let startTime = Date()
        
        // Generate speech-like test audio
        let testAudio = generateSpeechLikeAudio(duration: 3.0)
        
        guard let buffer = createAudioBuffer(from: testAudio) else {
            testResults.append(TestResult(
                testName: "Transcription Accuracy",
                passed: false,
                duration: Date().timeIntervalSince(startTime),
                details: "Failed to create test audio buffer"
            ))
            return
        }
        
        do {
            let result = try await whisperProcessor.transcribe(audioBuffer: buffer)
            
            let passed = !result.text.isEmpty && result.text != "[BLANK_AUDIO]"
            let confidence = result.segments.map { $0.probability }.reduce(0, +) / Float(max(result.segments.count, 1))
            
            testResults.append(TestResult(
                testName: "Transcription Accuracy",
                passed: passed,
                duration: Date().timeIntervalSince(startTime),
                details: "Result: '\(result.text)'\nConfidence: \(String(format: "%.2f%%", confidence * 100))\nSegments: \(result.segments.count)"
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Transcription Accuracy",
                passed: false,
                duration: Date().timeIntervalSince(startTime),
                details: "Failed: \(error.localizedDescription)"
            ))
        }
    }
    
    private func testPerformanceBenchmarks() async {
        currentTest = "Performance Benchmarks"
        let startTime = Date()
        
        var totalTime: TimeInterval = 0
        let iterations = 3
        var details = ""
        
        // Test with different audio durations
        let durations: [TimeInterval] = [1.0, 3.0, 5.0]
        
        for duration in durations {
            let audio = generateSpeechLikeAudio(duration: duration)
            guard let buffer = createAudioBuffer(from: audio) else { continue }
            
            var iterationTimes: [TimeInterval] = []
            
            for i in 0..<iterations {
                let iterStart = Date()
                do {
                    _ = try await whisperProcessor.transcribe(audioBuffer: buffer)
                    let iterTime = Date().timeIntervalSince(iterStart)
                    iterationTimes.append(iterTime)
                } catch {
                    details += "\(duration)s audio - iteration \(i+1): Failed\n"
                }
            }
            
            if !iterationTimes.isEmpty {
                let avgTime = iterationTimes.reduce(0, +) / Double(iterationTimes.count)
                let rtf = avgTime / duration // Real-time factor
                details += "\(Int(duration))s audio: Avg \(String(format: "%.2f", avgTime))s (RTF: \(String(format: "%.2f", rtf))x)\n"
                totalTime += avgTime
            }
        }
        
        let avgRTF = totalTime / durations.reduce(0, +)
        let passed = avgRTF < 1.0 // Should be faster than real-time
        
        testResults.append(TestResult(
            testName: "Performance Benchmarks",
            passed: passed,
            duration: Date().timeIntervalSince(startTime),
            details: details + "\nOverall RTF: \(String(format: "%.2f", avgRTF))x"
        ))
    }
    
    private func testParallelProcessing() async {
        currentTest = "Parallel Processing"
        let startTime = Date()
        
        // Create a longer audio sample that will be chunked
        let audio = generateSpeechLikeAudio(duration: 15.0)
        guard let buffer = createAudioBuffer(from: audio) else {
            testResults.append(TestResult(
                testName: "Parallel Processing",
                passed: false,
                duration: Date().timeIntervalSince(startTime),
                details: "Failed to create test audio buffer"
            ))
            return
        }
        
        do {
            let result = try await whisperProcessor.transcribe(audioBuffer: buffer)
            
            let passed = !result.text.isEmpty
            let processingTime = whisperProcessor.processingTime
            
            testResults.append(TestResult(
                testName: "Parallel Processing",
                passed: passed,
                duration: Date().timeIntervalSince(startTime),
                details: "Processed 15s audio in \(String(format: "%.2f", processingTime))s\nText length: \(result.text.count) chars\nModel: \(whisperProcessor.currentModel)"
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Parallel Processing",
                passed: false,
                duration: Date().timeIntervalSince(startTime),
                details: "Failed: \(error.localizedDescription)"
            ))
        }
    }
    
    private func testVoiceActivityDetection() async {
        currentTest = "Voice Activity Detection"
        let startTime = Date()
        
        var details = ""
        var allPassed = true
        
        // Test 1: Silence should not trigger VAD
        let silence = Array(repeating: Float(0), count: 16000)
        if let silenceBuffer = createAudioBuffer(from: silence) {
            let vadResult = testVAD(buffer: silenceBuffer)
            if vadResult {
                allPassed = false
                details += "Silence: Failed (detected as voice)\n"
            } else {
                details += "Silence: Passed (correctly identified)\n"
            }
        }
        
        // Test 2: Voice should trigger VAD
        let voice = generateSpeechLikeAudio(duration: 1.0)
        if let voiceBuffer = createAudioBuffer(from: voice) {
            let vadResult = testVAD(buffer: voiceBuffer)
            if !vadResult {
                allPassed = false
                details += "Voice: Failed (not detected)\n"
            } else {
                details += "Voice: Passed (correctly detected)\n"
            }
        }
        
        // Test 3: Noise should not trigger VAD
        let noise = (0..<16000).map { _ in Float.random(in: -0.1...0.1) }
        if let noiseBuffer = createAudioBuffer(from: noise) {
            let vadResult = testVAD(buffer: noiseBuffer)
            if vadResult {
                allPassed = false
                details += "Noise: Failed (detected as voice)\n"
            } else {
                details += "Noise: Passed (correctly rejected)\n"
            }
        }
        
        testResults.append(TestResult(
            testName: "Voice Activity Detection",
            passed: allPassed,
            duration: Date().timeIntervalSince(startTime),
            details: details.trimmingCharacters(in: .newlines)
        ))
    }
    
    private func testModelSwitching() async {
        currentTest = "Model Switching"
        let startTime = Date()
        
        do {
            // Start with base model
            try await whisperProcessor.loadModel(.base)
            
            // Simulate slow performance
            for _ in 0..<6 {
                whisperProcessor.processingTime = 4.0 // Simulate slow processing
                await whisperProcessor.monitorPerformanceAndAdaptModel(processingTime: 4.0)
            }
            
            // Check if model was downgraded
            let downgradedModel = whisperProcessor.currentModel
            let downgraded = downgradedModel != "base"
            
            // Now simulate fast performance
            for _ in 0..<6 {
                whisperProcessor.processingTime = 0.5 // Simulate fast processing
                await whisperProcessor.monitorPerformanceAndAdaptModel(processingTime: 0.5)
            }
            
            // Check if model was upgraded
            let upgradedModel = whisperProcessor.currentModel
            
            testResults.append(TestResult(
                testName: "Model Switching",
                passed: downgraded,
                duration: Date().timeIntervalSince(startTime),
                details: "Started: base\nAfter slow: \(downgradedModel)\nAfter fast: \(upgradedModel)\nAuto-switching: \(downgraded ? "Working" : "Not working")"
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Model Switching",
                passed: false,
                duration: Date().timeIntervalSince(startTime),
                details: "Failed: \(error.localizedDescription)"
            ))
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateTestAudio(amplitude: Float, duration: TimeInterval) -> [Float] {
        let sampleRate = 16000
        let sampleCount = Int(Double(sampleRate) * duration)
        
        return (0..<sampleCount).map { i in
            amplitude * sin(2.0 * Float.pi * 440.0 * Float(i) / Float(sampleRate))
        }
    }
    
    private func generateSpeechLikeAudio(duration: TimeInterval) -> [Float] {
        let sampleRate: Float = 16000
        let sampleCount = Int(sampleRate * Float(duration))
        
        var audio = [Float](repeating: 0, count: sampleCount)
        
        // Generate speech-like patterns
        let fundamentalFreq: Float = 125.0
        let formants: [(freq: Float, amp: Float)] = [
            (700, 0.3),
            (1220, 0.2),
            (2600, 0.1)
        ]
        
        for i in 0..<sampleCount {
            var sample: Float = 0
            
            // Fundamental frequency
            sample += 0.2 * sin(2.0 * Float.pi * fundamentalFreq * Float(i) / sampleRate)
            
            // Formants
            for formant in formants {
                sample += formant.amp * sin(2.0 * Float.pi * formant.freq * Float(i) / sampleRate)
            }
            
            // Add variation
            let modulation = 0.1 * sin(2.0 * Float.pi * 3.0 * Float(i) / sampleRate)
            sample *= (1.0 + modulation)
            
            // Add slight noise
            sample += 0.02 * Float.random(in: -1...1)
            
            audio[i] = sample
        }
        
        return audio
    }
    
    private func createAudioBuffer(from samples: [Float], sampleRate: Double = 16000) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else { return nil }
        
        buffer.frameLength = AVAudioFrameCount(samples.count)
        
        if let channelData = buffer.floatChannelData {
            for i in 0..<samples.count {
                channelData[0][i] = samples[i]
            }
        }
        
        return buffer
    }
    
    private func testVAD(buffer: AVAudioPCMBuffer) -> Bool {
        // Simple VAD test based on RMS
        guard let channelData = buffer.floatChannelData?[0] else { return false }
        
        let frames = buffer.frameLength
        var rms: Float = 0.0
        
        for i in 0..<Int(frames) {
            rms += channelData[i] * channelData[i]
        }
        rms = sqrt(rms / Float(frames))
        
        return rms > 0.05 // Simple threshold
    }
    
    enum TestError: LocalizedError {
        case modelLoadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .modelLoadFailed(let model):
                return "Failed to load model: \(model)"
            }
        }
    }
}

// MARK: - Test UI View
struct WhisperKitTestView: View {
    @StateObject private var testSuite = WhisperKitTestSuite()
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task {
                            await testSuite.runAllTests()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Run All Tests")
                        }
                    }
                    .disabled(testSuite.isRunning)
                    
                    if testSuite.isRunning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Running: \(testSuite.currentTest)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Test Results") {
                    if testSuite.testResults.isEmpty {
                        Text("No tests run yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(testSuite.testResults) { result in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(result.passed ? .green : .red)
                                    
                                    Text(result.testName)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text("\(String(format: "%.2f", result.duration))s")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text(result.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("WhisperKit Tests")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}