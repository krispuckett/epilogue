import SwiftUI
import Combine

// MARK: - Voice Mode Overlay
struct VoiceModeOverlay: View {
    @Binding var isActive: Bool
    @Binding var transcript: String
    let bookTitle: String?
    let bookAuthor: String?
    let onSendTranscript: (String) -> Void
    
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @State private var glowOpacity: Double = 0.3
    @State private var pulseScale: CGFloat = 1.0
    @State private var wavePhase: CGFloat = 0
    @State private var isListening = false
    @State private var hasTranscript = false
    @State private var detectedPatterns: [PatternMatch] = []
    @State private var showPatternIndicator = false
    @StateObject private var autoStopManager = AutoStopManager.shared
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    stopListening()
                }
            
            // Orange glow effect
            RadialGradient(
                colors: [
                    Color.orange.opacity(glowOpacity),
                    Color.orange.opacity(glowOpacity * 0.5),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 300
            )
            .ignoresSafeArea()
            .scaleEffect(pulseScale)
            .allowsHitTesting(false)
            
            VStack(spacing: 40) {
                // Header with privacy indicator and cancel button
                HStack {
                    // Privacy indicator
                    PrivacyIndicator(isListening: voiceManager.isListening, isRecording: isListening)
                        .frame(maxWidth: 200)
                    
                    Spacer()
                    
                    Button {
                        stopListening()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(DesignSystem.Colors.textQuaternary, .white.opacity(0.1))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                .padding(.top, 60)
                
                Spacer()
                
                // Central content
                VStack(spacing: 30) {
                    // Waveform icon with glow
                    ZStack {
                        // Glow rings
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(Color.orange.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                                .frame(width: 100 + CGFloat(index) * 40, height: 100 + CGFloat(index) * 40)
                                .scaleEffect(pulseScale)
                                .animation(
                                    .easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.3),
                                    value: pulseScale
                                )
                        }
                        
                        // Central icon
                        Image(systemName: "waveform")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                            .shadow(color: .orange, radius: 20)
                    }
                    
                    // Status text
                    VStack(spacing: 8) {
                        Text(isListening ? "Listening..." : "Tap to speak")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                        
                        if let bookTitle = bookTitle {
                            Text("Discussing \(bookTitle)")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        // Show detected pattern
                        if showPatternIndicator, let pattern = detectedPatterns.last {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hexString: pattern.pattern.color))
                                    .frame(width: 8, height: 8)
                                
                                Text(pattern.pattern.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(hexString: pattern.pattern.color))
                            }
                            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hexString: pattern.pattern.color).opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color(hexString: pattern.pattern.color).opacity(0.4), lineWidth: 1)
                                    )
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    // Transcript display
                    if !transcript.isEmpty {
                        Text(transcript)
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    if isListening {
                        // Stop button
                        Button {
                            stopListening()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 70))
                                .foregroundStyle(.white, Color.red.opacity(0.8))
                        }
                    } else {
                        // Start listening button
                        Button {
                            startListening()
                        } label: {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 70))
                                .foregroundStyle(.white, Color.orange)
                        }
                    }
                    
                    // Send button (appears when there's transcript)
                    if !transcript.isEmpty {
                        Button {
                            sendTranscript()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white, Color.green)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startPulseAnimation()
            
            // Automatically start listening
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startListening()
            }
        }
        .onDisappear {
            if voiceManager.isListening {
                voiceManager.stopListening()
            }
        }
        .onChange(of: voiceManager.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                transcript = newValue
                hasTranscript = true
                
                // Detect patterns
                let patterns = CognitivePatternRecognizer.shared.recognizePatterns(in: newValue)
                if !patterns.isEmpty {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        detectedPatterns = patterns
                        showPatternIndicator = true
                    }
                    
                    // Hide after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            showPatternIndicator = false
                        }
                    }
                }
            }
        }
        .onChange(of: voiceManager.currentAmplitude) { _, amplitude in
            withAnimation(.easeInOut(duration: 0.1)) {
                glowOpacity = 0.3 + Double(amplitude) * 2.0
                glowOpacity = min(glowOpacity, 0.8)
            }
        }
        .animation(DesignSystem.Animation.springStandard, value: isListening)
        .animation(DesignSystem.Animation.springStandard, value: hasTranscript)
        .onReceive(NotificationCenter.default.publisher(for: .autoStopTriggered)) { _ in
            stopListening()
        }
        .onChange(of: voiceManager.currentAmplitude) { _, amplitude in
            // Reset silence timer when voice detected
            if amplitude > 0.01 {
                autoStopManager.resetSilenceTimer()
            }
        }
        .privacyBlur(isActive: false) // Can be enabled based on user preference
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
    
    private func startListening() {
        isListening = true
        transcript = ""
        hasTranscript = false
        voiceManager.transcribedText = ""
        voiceManager.startAmbientListening()
        
        // Start auto-stop for voice mode (shorter duration)
        autoStopManager.maxDuration = 60.0 // 1 minute for voice mode
        autoStopManager.startMonitoring()
        
        DesignSystem.HapticFeedback.light()
    }
    
    private func stopListening() {
        isListening = false
        voiceManager.stopListening()
        autoStopManager.stopMonitoring()
        
        if transcript.isEmpty {
            // No transcript, just close
            isActive = false
        }
        // If there's a transcript, keep the overlay open so user can send or retry
    }
    
    private func sendTranscript() {
        guard !transcript.isEmpty else { return }
        
        voiceManager.stopListening()
        onSendTranscript(transcript)
        DesignSystem.HapticFeedback.success()
        
        // Close overlay after sending
        withAnimation {
            isActive = false
        }
    }
}

// MARK: - Preview
#Preview {
    VoiceModeOverlay(
        isActive: .constant(true),
        transcript: .constant(""),
        bookTitle: "The Great Gatsby",
        bookAuthor: "F. Scott Fitzgerald",
        onSendTranscript: { _ in }
    )
}