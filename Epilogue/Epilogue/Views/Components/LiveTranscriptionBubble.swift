import SwiftUI

// MARK: - Size Preference Key
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Live Transcription Bubble with Dynamic Sizing
struct LiveTranscriptionBubble: View {
    let text: String
    let isDissolving: Bool
    
    @State private var displayedText: String = ""
    @State private var containerHeight: CGFloat = 60
    @State private var containerWidth: CGFloat = 180
    @State private var animationTimer: Timer?
    
    // Design constants
    private let cornerRadius: CGFloat = 24
    private let horizontalPadding: CGFloat = 24
    private let verticalPadding: CGFloat = 16
    @State private var maxWidth: CGFloat = 310  // Default: 390 - 80
    private let minHeight: CGFloat = 60
    private let fontSize: CGFloat = 17
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
            // Text content (measure it first for sizing)
            Text(displayedText)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: maxWidth - (horizontalPadding * 2))
                .opacity(isDissolving ? 0 : 1)
                .blur(radius: isDissolving ? 8 : 0)
                .scaleEffect(isDissolving ? 0.95 : 1)
                .animation(.easeOut(duration: 0.6), value: isDissolving)
                .overlay(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: SizePreferenceKey.self, value: geometry.size)
                    }
                )
        }
        .frame(width: containerWidth, height: containerHeight)
        .glassEffect() // YOUR LIQUID GLASS - NO BACKGROUND!
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: containerHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: containerWidth)
        .onPreferenceChange(SizePreferenceKey.self) { size in
            updateContainerSize(size)
        }
        .onChange(of: text) { _, newText in
            updateDisplayedText(newText)
        }
        .onAppear {
            if !text.isEmpty {
                updateDisplayedText(text)
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
        .onAppear {
            maxWidth = geometry.size.width - 80
        }
        }
    }
    
    private func updateContainerSize(_ size: CGSize) {
        // Update container to fit text with padding
        let newHeight = max(minHeight, size.height + verticalPadding * 2)
        let newWidth = min(maxWidth, max(180, size.width + horizontalPadding * 2))
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            containerHeight = newHeight
            containerWidth = newWidth
        }
    }
    
    private func updateDisplayedText(_ newText: String) {
        // Animate text appearance
        animationTimer?.invalidate()
        
        // For short text, show immediately
        if newText.count < 20 {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedText = newText
            }
        } else {
            // For longer text, progressive reveal
            displayedText = ""
            let characters = Array(newText)
            var currentIndex = 0
            
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                if currentIndex < characters.count {
                    displayedText.append(characters[currentIndex])
                    currentIndex += 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - Simplified Rectangle Bubble (iOS 18 Exact Match)
struct SimplifiedTranscriptionBubble: View {
    let text: String
    @State private var displayedText: String = ""
    @State private var bubbleHeight: CGFloat = 56
    @State private var bubbleWidth: CGFloat = 200
    
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            
            Text(displayedText.isEmpty ? text : displayedText)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(minWidth: 60)
                .frame(width: bubbleWidth, height: bubbleHeight)
                .glassEffect() // ONLY GLASS EFFECT - NO BACKGROUND!
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: SizePreferenceKey.self, value: geometry.size)
                    }
                )
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.9), value: displayedText)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: bubbleHeight)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: bubbleWidth)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onPreferenceChange(SizePreferenceKey.self) { size in
            // Update bubble size to fit content
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                bubbleHeight = max(56, size.height)
                bubbleWidth = min(maxWidth, max(200, size.width))
            }
        }
        .onAppear {
            displayedText = text
        }
        .onChange(of: text) { _, newText in
            displayedText = newText
        }
    }
}

// MARK: - Ultra Minimal Version
struct MinimalTranscriptionBubble: View {
    let text: String
    @State private var isVisible = false
    
    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .glassEffect() // LIQUID GLASS ONLY!
            .clipShape(Capsule(style: .continuous))
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isVisible = true
                }
            }
            .onChange(of: text) { _, _ in
                // Bounce effect on text change
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isVisible = false
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Preview Provider
struct TranscriptionBubblePreview: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                LiveTranscriptionBubble(
                    text: "How does transcription work on the device when I have longer text and things keep going",
                    isDissolving: false
                )
                
                SimplifiedTranscriptionBubble(
                    text: "This maintains the rectangle shape as it expands"
                )
                
                MinimalTranscriptionBubble(
                    text: "Clean capsule version"
                )
            }
            .padding()
        }
    }
}