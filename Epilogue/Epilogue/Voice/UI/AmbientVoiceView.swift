import SwiftUI
import Combine

struct AmbientVoiceView: View {
    @StateObject private var voiceManager = VoiceRecognitionManager()
    @State private var showingVoiceInterface = false
    @State private var pulseAnimation = false
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            // Ambient indicator when listening
            if voiceManager.isListening && !showingVoiceInterface {
                AmbientListeningIndicator(
                    amplitude: voiceManager.currentAmplitude,
                    state: voiceManager.recognitionState
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            // Full voice interface when wake word detected
            if showingVoiceInterface {
                VoiceInterfaceView(
                    voiceManager: voiceManager,
                    isShowing: $showingVoiceInterface
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WakeWordDetected"))) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showingVoiceInterface = true
            }
        }
        .onAppear {
            voiceManager.startAmbientListening()
        }
        .onDisappear {
            voiceManager.stopListening()
        }
    }
}

struct AmbientListeningIndicator: View {
    let amplitude: Float
    let state: VoiceRecognitionManager.RecognitionState
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primaryAccent.opacity(0.3),
                                    DesignSystem.Colors.primaryAccent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulseScale)
                        .opacity(state == .processing ? 1 : 0.5)
                    
                    // Inner indicator
                    Circle()
                        .fill(.thinMaterial)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: state == .processing ? "waveform" : "mic.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                                .scaleEffect(1 + CGFloat(amplitude * 2))
                                .animation(.easeOut(duration: 0.1), value: amplitude)
                        }
                        .shadow(
                            color: DesignSystem.Colors.primaryAccent.opacity(0.3),
                            radius: 8,
                            y: 2
                        )
                }
                .padding(DesignSystem.Spacing.cardPadding)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
            }
        }
    }
}

struct VoiceInterfaceView: View {
    @ObservedObject var voiceManager: VoiceRecognitionManager
    @Binding var isShowing: Bool
    @State private var responseText = ""
    @State private var isProcessingResponse = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissInterface()
                }
            
            // Main interface
            VStack(spacing: 24) {
                // Voice visualizer
                VoiceVisualizer(amplitude: voiceManager.currentAmplitude)
                    .frame(height: 120)
                
                // Transcribed text
                VStack(spacing: 12) {
                    if !voiceManager.transcribedText.isEmpty {
                        Text(voiceManager.transcribedText)
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // Status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(statusText)
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                
                // Response area
                if !responseText.isEmpty {
                    ScrollView {
                        Text(responseText)
                            .font(.system(size: 16, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(DesignSystem.Spacing.listItemPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                    }
                    .frame(maxHeight: 200)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        dismissInterface()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    if voiceManager.recognitionState == .processing {
                        Button {
                            processCommand()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Send")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                            .padding(.vertical, 10)
                            .glassEffect(
                                .regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.3)),
                                in: Capsule()
                            )
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.cardPadding)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: 400)
            .glassEffect(in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(32)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: voiceManager.recognitionState)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: responseText)
    }
    
    private var statusColor: Color {
        switch voiceManager.recognitionState {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .processing:
            return DesignSystem.Colors.primaryAccent
        }
    }
    
    private var statusText: String {
        switch voiceManager.recognitionState {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        }
    }
    
    private func processCommand() {
        isProcessingResponse = true
        // Set state to processing while handling response
        
        // TODO: Send to Perplexity API for processing
        // For now, just simulate a response
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            responseText = "I understand you want to know about \"\(voiceManager.transcribedText)\". Let me help you with that..."
            isProcessingResponse = false
        }
    }
    
    private func dismissInterface() {
        withAnimation(DesignSystem.Animation.springStandard) {
            isShowing = false
        }
        
        // Reset state
        voiceManager.transcribedText = ""
        responseText = ""
    }
}

struct VoiceVisualizer: View {
    let amplitude: Float
    @State private var bars: [CGFloat] = Array(repeating: 0.2, count: 40)
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<bars.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primaryAccent,
                                    DesignSystem.Colors.primaryAccent.opacity(0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: (geometry.size.width / CGFloat(bars.count)) - 2)
                        .scaleEffect(y: bars[index], anchor: .bottom)
                }
            }
            .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
                updateBars()
            }
        }
    }
    
    private func updateBars() {
        for i in 0..<bars.count {
            let targetHeight = CGFloat.random(in: 0.1...0.3) + CGFloat(amplitude * 3)
            
            withAnimation(.easeOut(duration: 0.1)) {
                bars[i] = min(targetHeight, 1.0)
            }
        }
    }
}