import SwiftUI

// MARK: - Clean Blur Transcription (No Glass Container)
struct CleanBlurTranscription: View {
    let currentText: String
    @State private var visibleText = ""
    @State private var characterBlur: [Double] = []
    @State private var isDissolving = false
    @State private var animationTimer: Timer?
    
    private let maxCharacters = 80
    
    var body: some View {
        // Simple text with blur - NO container, NO glass
        Text(visibleText)
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.95))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: UIScreen.main.bounds.width - 80)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .modifier(CharacterBlurModifier(
                text: visibleText,
                blurValues: characterBlur,
                isDissolving: isDissolving
            ))
            .onChange(of: currentText) { _, newText in
                updateText(newText)
            }
            .onAppear {
                if !currentText.isEmpty {
                    updateText(currentText)
                }
            }
            .onDisappear {
                animationTimer?.invalidate()
            }
    }
    
    private func updateText(_ newText: String) {
        // Cancel any existing animation
        animationTimer?.invalidate()
        isDissolving = false
        
        // Truncate if needed
        let textToShow = newText.count > maxCharacters ? 
            "..." + String(newText.suffix(maxCharacters - 3)) : newText
        
        // Reset blur array
        characterBlur = Array(repeating: 8.0, count: textToShow.count)
        visibleText = textToShow
        
        // Animate characters appearing
        animateReveal()
    }
    
    private func animateReveal() {
        var currentIndex = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard currentIndex < visibleText.count else {
                timer.invalidate()
                // Start dissolve after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    startDissolve()
                }
                return
            }
            
            // Reveal characters in batches
            let batchSize = 3
            for i in currentIndex..<min(currentIndex + batchSize, characterBlur.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    characterBlur[i] = 0
                }
            }
            currentIndex += batchSize
        }
    }
    
    private func startDissolve() {
        withAnimation(.easeOut(duration: 0.8)) {
            isDissolving = true
        }
    }
}

// MARK: - Character Blur Modifier
struct CharacterBlurModifier: ViewModifier {
    let text: String
    let blurValues: [Double]
    let isDissolving: Bool
    
    func body(content: Content) -> some View {
        if blurValues.isEmpty {
            content
        } else {
            // Apply average blur to the whole text for performance
            let avgBlur = blurValues.reduce(0, +) / Double(blurValues.count)
            content
                .blur(radius: isDissolving ? 10 : avgBlur, opaque: true)
                .opacity(isDissolving ? 0 : 1)
                .scaleEffect(isDissolving ? 0.95 : 1.0)
                .offset(y: isDissolving ? -10 : 0)
        }
    }
}

// MARK: - Ultra Simple Version with Fixed 20pt Corners
struct UltraSimpleTranscription: View {
    let text: String
    
    @State private var visibleCharCount: Int = 0
    @State private var charBlurs: [Double] = []
    
    var body: some View {
        Text(text)
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3) // Allow up to 3 lines
            .frame(maxWidth: UIScreen.main.bounds.width - 100)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .glassEffect() // Apply glass effect
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) // LOCKED at 20!
            .mask(
                // Character-by-character reveal
                HStack(spacing: 0) {
                    ForEach(0..<text.count, id: \.self) { index in
                        Rectangle()
                            .opacity(index < visibleCharCount ? 1 : 0)
                            .blur(radius: index < charBlurs.count ? charBlurs[index] : 10)
                            .animation(
                                .easeOut(duration: 0.3)
                                .delay(Double(index) * 0.03),
                                value: visibleCharCount
                            )
                    }
                }
            )
            .onChange(of: text) { _, newText in
                animateIn(newText)
            }
            .onAppear {
                if !text.isEmpty {
                    animateIn(text)
                }
            }
    }
    
    private func animateIn(_ newText: String) {
        visibleCharCount = 0
        charBlurs = Array(repeating: 10, count: newText.count)
        
        // Reveal characters
        withAnimation {
            visibleCharCount = newText.count
        }
        
        // Remove blur per character
        for index in 0..<newText.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.03) {
                if index < charBlurs.count {
                    withAnimation(.easeOut(duration: 0.3)) {
                        charBlurs[index] = 0
                    }
                }
            }
        }
    }
}