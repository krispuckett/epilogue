import SwiftUI

struct AmbientOrbView: View {
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @State private var orbScale: CGFloat = 1.0
    @State private var orbOpacity: Double = 0.8
    @State private var isPressed = false
    @State private var breathingAnimation = false
    @State private var pulseAnimation = false
    @State private var glowIntensity: Double = 0.3
    @State private var lastStateChange = Date()
    private let stateChangeDebounce: TimeInterval = 0.5
    
    // Colors for different states
    private var orbColor: Color {
        switch voiceManager.recognitionState {
        case .idle:
            return Color(red: 0.7, green: 0.7, blue: 0.9) // Soft lavender
        case .listening:
            return Color(red: 0.4, green: 0.8, blue: 0.9) // Soft cyan
        case .processing:
            return Color(red: 0.9, green: 0.6, blue: 0.4) // Warm orange
        }
    }
    
    var body: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            orbColor.opacity(glowIntensity),
                            orbColor.opacity(0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 20)
                .scaleEffect(breathingAnimation ? 1.2 : 1.0)
                .animation(
                    .easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true),
                    value: breathingAnimation
                )
            
            // Particle effects when processing
            if voiceManager.recognitionState == .processing {
                ForEach(0..<8, id: \.self) { index in
                    ParticleView(color: orbColor, index: index)
                }
            }
            
            // Main orb
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            orbColor.opacity(0.9),
                            orbColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: orbColor.opacity(0.6), radius: 10, x: 0, y: 5)
                .scaleEffect(isPressed ? 0.9 : orbScale)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .opacity(orbOpacity)
            
            // Sound wave visualization when listening
            if voiceManager.recognitionState == .listening {
                SoundWaveView(amplitude: voiceManager.currentAmplitude)
                    .frame(width: 80, height: 80)
                    .allowsHitTesting(false)
            }
            
            // Status icon
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .onTapGesture {
            handleTap()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .onAppear {
            breathingAnimation = true
        }
        .onChange(of: voiceManager.recognitionState) { _, newState in
            // Debounce state changes to avoid flickering
            let timeSinceLastChange = Date().timeIntervalSince(lastStateChange)
            guard timeSinceLastChange > stateChangeDebounce else { return }
            
            lastStateChange = Date()
            
            withAnimation(DesignSystem.Animation.easeStandard) {
                switch newState {
                case .idle:
                    glowIntensity = 0.3
                    pulseAnimation = false
                case .listening:
                    glowIntensity = 0.5
                    pulseAnimation = false
                case .processing:
                    glowIntensity = 0.7
                    pulseAnimation = true
                }
            }
        }
    }
    
    private var iconName: String {
        switch voiceManager.recognitionState {
        case .idle:
            return "mic.slash.fill"
        case .listening:
            return "waveform"
        case .processing:
            return "brain"
        }
    }
    
    private func handleTap() {
        DesignSystem.HapticFeedback.light()
        
        print("🎤 AmbientOrb: Tap detected, isListening = \(voiceManager.isListening)")
        
        if voiceManager.isListening {
            print("🎤 AmbientOrb: Stopping listening")
            voiceManager.stopListening()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                orbScale = 0.8
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                orbScale = 1.0
            }
        } else {
            print("🎤 AmbientOrb: Starting ambient listening")
            voiceManager.startAmbientListening()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                orbScale = 1.2
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                orbScale = 1.0
            }
        }
    }
}

// Sound wave visualization component
struct SoundWaveView: View {
    let amplitude: Float
    @State private var phase: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, to: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin(relativeX * Double.pi * 4 + phase) * Double(amplitude) * 20
                    let y = midHeight + sine
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.8),
                        DesignSystem.Colors.textQuaternary
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = Double.pi * 2
            }
        }
    }
}

// Particle effect for processing state
struct ParticleView: View {
    let color: Color
    let index: Int
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                let angle = Double(index) * (Double.pi * 2 / 8)
                let distance: CGFloat = 60
                
                withAnimation(
                    .easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                    .delay(Double(index) * 0.1)
                ) {
                    offset = CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    )
                    opacity = 0
                }
                
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1
                }
            }
    }
}

struct AmbientOrbView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            AmbientOrbView()
        }
    }
}

// Debug view for testing
struct AmbientOrbDebugView: View {
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            AmbientOrbView()
            
            // Test WhisperKit button
            Button(action: {
                Task {
                    await voiceManager.testWhisperKit()
                }
            }) {
                Label("Test WhisperKit", systemImage: "waveform.badge.exclamationmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            
            // Clear button
            Button(action: {
                voiceManager.clearWhisperTranscription()
                voiceManager.transcribedText = ""
            }) {
                Label("Clear All", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            
            // Results
            VStack(alignment: .leading, spacing: 10) {
                if !voiceManager.transcribedText.isEmpty {
                    Text("Apple: \(voiceManager.transcribedText)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if !voiceManager.whisperTranscribedText.isEmpty {
                    Text("Whisper: \(voiceManager.whisperTranscribedText)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        .padding()
        .background(Color.black)
    }
}