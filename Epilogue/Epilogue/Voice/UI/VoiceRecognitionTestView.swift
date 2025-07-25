import SwiftUI
import Combine

struct VoiceRecognitionTestView: View {
    @StateObject private var voiceManager = VoiceRecognitionManager()
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var startTime: Date?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    Text("Voice Recognition Test")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                    
                    // Control Button - Moved to top
                    Button {
                        toggleRecording()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: voiceManager.isListening ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 24))
                            
                            Text(voiceManager.isListening ? "Stop Recording" : "Start Recording")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(voiceManager.isListening ? Color.red : Color(red: 1.0, green: 0.55, blue: 0.26))
                        )
                    }
                    
                    // Recording Duration
                    if voiceManager.isListening {
                        VStack(spacing: 8) {
                            Text("Continuous Recording Time")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text(timeString(from: elapsedTime))
                                .font(.system(.largeTitle, design: .monospaced, weight: .thin))
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Voice Amplitude Visualization
                    if voiceManager.isListening {
                        AudioVisualizerView(amplitude: voiceManager.currentAmplitude)
                            .frame(height: 60)
                            .padding(.horizontal, 40)
                    }
                    
                    // Status Indicator
                    HStack(spacing: 12) {
                        Circle()
                            .fill(stateColor(for: voiceManager.recognitionState))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(stateColor(for: voiceManager.recognitionState).opacity(0.3), lineWidth: 3)
                                    .scaleEffect(voiceManager.recognitionState == .listening ? 1.5 : 1.0)
                                    .opacity(voiceManager.recognitionState == .listening ? 0.0 : 1.0)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: voiceManager.recognitionState == .listening)
                            )
                        
                        Text(stateText(for: voiceManager.recognitionState))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.3))
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    
                    // Transcription Cards
                    VStack(spacing: 20) {
                        // Live Transcription (Apple)
                        TranscriptionCard(
                            title: "Live Transcription (Apple)",
                            text: voiceManager.transcribedText,
                            placeholder: "Say something...",
                            confidence: voiceManager.confidenceScore,
                            isPulsing: voiceManager.recognitionState == .listening
                        )
                        
                        // Whisper Transcription
                        TranscriptionCard(
                            title: "Whisper Transcription",
                            text: voiceManager.whisperTranscribedText,
                            placeholder: "Waiting for Whisper processing...",
                            confidence: voiceManager.whisperConfidence,
                            isProcessing: voiceManager.isProcessingWhisper,
                            language: voiceManager.detectedLanguage
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Debug Info
                    if voiceManager.isListening {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug Info")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                            
                            HStack {
                                Text("State:")
                                Text(stateText(for: voiceManager.recognitionState))
                                    .foregroundStyle(stateColor(for: voiceManager.recognitionState))
                            }
                            .font(.system(size: 11))
                            
                            HStack {
                                Text("Amplitude:")
                                Text(String(format: "%.4f", voiceManager.currentAmplitude))
                            }
                            .font(.system(size: 11))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func toggleRecording() {
        if voiceManager.isListening {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        voiceManager.startAmbientListening()
        startTime = Date()
        elapsedTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopRecording() {
        voiceManager.stopListening()
        timer?.invalidate()
        timer = nil
        startTime = nil
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let tenths = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
    
    private func stateColor(for state: VoiceRecognitionManager.RecognitionState) -> Color {
        switch state {
        case .idle:
            return .gray
        case .listening:
            return .green
        case .processing:
            return .orange
        }
    }
    
    private func stateText(for state: VoiceRecognitionManager.RecognitionState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        }
    }
}

// Transcription Card Component
struct TranscriptionCard: View {
    let title: String
    let text: String
    let placeholder: String
    let confidence: Float
    var isProcessing: Bool = false
    var language: String = ""
    var isPulsing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.leading, 8)
                }
                
                Spacer()
                
                if confidence > 0 {
                    Text("Confidence: \(Int(confidence * 100))%")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                if !language.isEmpty && language != "en" {
                    Text("[\(language.uppercased())]")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            
            ScrollView {
                VStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(.white.opacity(0.3))
                    } else {
                        Text(text)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 80)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPulsing ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.5) : .white.opacity(0.1), lineWidth: isPulsing ? 2 : 1)
                )
                .scaleEffect(isPulsing ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isPulsing)
        )
    }
}

// Keep the existing AudioVisualizerView and HighlightedText components
struct AudioVisualizerView: View {
    let amplitude: Float
    let barCount = 40
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.26),
                                    Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: (geometry.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount),
                            height: barHeight(for: index, maxHeight: geometry.size.height)
                        )
                        .animation(.easeInOut(duration: 0.1), value: amplitude)
                }
            }
        }
    }
    
    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let normalizedIndex = Float(index) / Float(barCount - 1)
        let gaussianMultiplier = exp(-pow((normalizedIndex - 0.5) * 4, 2))
        let randomVariation = Float.random(in: 0.8...1.2)
        let height = CGFloat(amplitude * gaussianMultiplier * randomVariation * 100)
        return min(max(height, 4), maxHeight)
    }
}

struct VoiceRecognitionTestView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceRecognitionTestView()
    }
}