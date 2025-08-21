import SwiftUI

/// Minimalist Siri-style text animation for live transcription
/// - NO character-by-character animation (maintains text layout integrity)
/// - Word-based flow animations with ethereal blur effects
/// - Fixed container height to prevent UI jumping
/// - Optimized for 120fps ProMotion displays
struct EtherealTranscription: View {
    let currentText: String
    var amplitudeLevel: Float = 0 // Optional microphone amplitude (0-1)
    var isActive: Bool = true
    
    @State private var displayText: String = ""
    @State private var previousLine: String = ""
    @State private var isAnimating: Bool = false
    @State private var textBlur: Double = 0
    @State private var textOffset: CGFloat = 0
    @State private var containerGlow: Double = 0
    @State private var pulseTimer: Timer?
    
    // Animation controls
    @State private var wordRevealProgress: Double = 0
    @State private var oldTextBlur: Double = 0
    @State private var oldTextOffset: CGFloat = 0
    
    private let maxCharacters = 80
    private let containerHeight: CGFloat = 80
    
    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.clear)
            .frame(height: containerHeight)
            .frame(maxWidth: UIScreen.main.bounds.width - 60)
            .glassEffect() // Using existing glass effect
    }
    
    private var glowOverlay: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(containerGlow * 0.3),
                        Color.white.opacity(containerGlow * 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .blur(radius: containerGlow * 2)
    }
    
    private var shadowModifier: some ViewModifier {
        struct ShadowMod: ViewModifier {
            let amplitudeLevel: Float
            func body(content: Content) -> some View {
                let shadowOpacity = Double(0.2 + (amplitudeLevel * 0.1))
                let shadowRadius = CGFloat(10 + (amplitudeLevel * 5))
                return content.shadow(
                    color: .black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    y: 5
                )
            }
        }
        return ShadowMod(amplitudeLevel: amplitudeLevel)
    }
    
    private var previousLineView: some View {
        Text(previousLine)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .blur(radius: oldTextBlur)
            .offset(x: -oldTextOffset)
    }
    
    private var currentTextView: some View {
        Text(displayText)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .truncationMode(.head)
            .blur(radius: textBlur)
            .offset(x: textOffset)
            .opacity(wordRevealProgress)
    }
    
    var body: some View {
        ZStack {
            // Container background
            containerBackground
                .overlay(glowOverlay)
                .modifier(shadowModifier)
            
            // Text content
            VStack(spacing: 4) {
                if !previousLine.isEmpty {
                    previousLineView
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                }
                
                if !displayText.isEmpty {
                    currentTextView
                        .animation(.easeOut(duration: 0.3), value: textBlur)
                        .animation(.easeOut(duration: 0.3), value: textOffset)
                        .animation(.easeOut(duration: 0.3), value: wordRevealProgress)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: containerHeight)
            .frame(maxWidth: UIScreen.main.bounds.width - 60)
        }
        .drawingGroup() // GPU acceleration for smooth 120fps
        .onChange(of: currentText) { oldValue, newValue in
            updateText(from: oldValue, to: newValue)
        }
        .onChange(of: isActive) { _, active in
            if active {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
        .onAppear {
            if isActive {
                startPulseAnimation()
            }
            if !currentText.isEmpty {
                updateText(from: "", to: currentText)
            }
        }
        .onDisappear {
            stopPulseAnimation()
        }
    }
    
    /// Smart text update with word-boundary preservation
    private func updateText(from oldText: String, to newText: String) {
        // Handle empty text
        guard !newText.isEmpty else {
            withAnimation(.easeOut(duration: 0.5)) {
                textBlur = 15
                wordRevealProgress = 0
                oldTextBlur = 15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                displayText = ""
                previousLine = ""
            }
            return
        }
        
        // Smart truncation to prevent overflow
        let processedText = processTextForDisplay(newText)
        
        // Detect if we need to push text to previous line
        let words = processedText.split(separator: " ")
        if words.count > 8 && previousLine.isEmpty {
            // Move first portion to previous line
            let midPoint = words.count / 2
            previousLine = words.prefix(midPoint).joined(separator: " ")
            displayText = words.suffix(from: midPoint).joined(separator: " ")
            
            // Animate the transition
            withAnimation(.easeInOut(duration: 0.5)) {
                oldTextBlur = 5
                oldTextOffset = 10
            }
        } else if processedText != displayText {
            // Flow animation for new text
            isAnimating = true
            
            // Initial state - text flows in from right with blur
            textOffset = 20
            textBlur = 5
            wordRevealProgress = 0
            
            displayText = processedText
            
            // Animate to final state
            withAnimation(.easeOut(duration: 0.3)) {
                textOffset = 0
                textBlur = 0
                wordRevealProgress = 1
            }
            
            // Clean up animation flag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }
    }
    
    /// Process text for display with smart truncation
    private func processTextForDisplay(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If text is too long, show most recent portion with ellipsis
        if trimmed.count > maxCharacters {
            let startIndex = trimmed.index(trimmed.endIndex, offsetBy: -maxCharacters)
            let truncated = String(trimmed[startIndex...])
            
            // Find first word boundary to avoid mid-word cuts
            if let spaceIndex = truncated.firstIndex(of: " ") {
                let cleanStart = truncated.index(after: spaceIndex)
                return "..." + String(truncated[cleanStart...])
            }
            return "..." + truncated
        }
        
        return trimmed
    }
    
    /// Container glow pulse animation
    private func startPulseAnimation() {
        containerGlow = 0
        
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                containerGlow = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    containerGlow = 0
                }
            }
        }
    }
    
    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        
        withAnimation(.easeOut(duration: 0.5)) {
            containerGlow = 0
        }
    }
}

// MARK: - Preview
struct EtherealTranscription_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            
            VStack(spacing: 40) {
                // Short text
                EtherealTranscription(
                    currentText: "Hello, how can I help you today?",
                    amplitudeLevel: 0.3
                )
                
                // Long text that will truncate
                EtherealTranscription(
                    currentText: "This is a much longer transcription that will demonstrate how the text flows and truncates properly at word boundaries without breaking the layout",
                    amplitudeLevel: 0.7
                )
                
                // Empty state
                EtherealTranscription(
                    currentText: "",
                    amplitudeLevel: 0
                )
            }
            .padding()
        }
    }
}