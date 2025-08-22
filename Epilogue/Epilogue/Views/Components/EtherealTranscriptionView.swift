import SwiftUI

// MARK: - Award-Winning Ethereal Transcription System
// PURE LIQUID GLASS - NO BACKGROUNDS, NO FILLS, NO ULTRATHIN MATERIAL

struct EtherealTranscriptionView: View {
    let currentText: String
    let isDissolving: Bool
    
    @State private var displayedLines: [EtherealTranscriptionLine] = []
    @State private var characterReveals: [UUID: CGFloat] = [:]
    @State private var lineBlurs: [UUID: CGFloat] = [:]
    @State private var lineOpacities: [UUID: CGFloat] = [:]
    @State private var lineOffsets: [UUID: CGFloat] = [:]
    @State private var containerScale: CGFloat = 0.95
    @State private var containerBlur: CGFloat = 10
    @State private var glowIntensity: CGFloat = 0
    
    private let maxLinesVisible = 3
    private let charactersPerLine = 42
    private let revealDuration: Double = 0.04 // Per character
    private let lineTransitionDuration: Double = 0.8
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 8) {
                ForEach(displayedLines) { line in
                    EtherealTranscriptionLineView(
                        line: line,
                        revealProgress: characterReveals[line.id] ?? 0,
                        blurAmount: lineBlurs[line.id] ?? 0,
                        opacity: lineOpacities[line.id] ?? 0,
                        yOffset: lineOffsets[line.id] ?? 0,
                        glowIntensity: glowIntensity
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 20)),
                        removal: .opacity.combined(with: .offset(y: -20)).combined(with: .scale(scale: 0.95))
                    ))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: geometry.size.width - 60)
            .glassEffect() // YOUR LIQUID GLASS - NOTHING ELSE
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .scaleEffect(containerScale)
            .blur(radius: containerBlur)
            .shadow(
                color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(glowIntensity * 0.3),
                radius: 20 * glowIntensity,
                x: 0,
                y: 0
            )
            .onChange(of: currentText) { _, newText in
                updateTranscription(with: newText)
            }
            .onChange(of: isDissolving) { _, dissolving in
                if dissolving {
                    performEtherealDissolve()
                }
            }
            .onAppear {
                // Entrance animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    containerScale = 1.0
                    containerBlur = 0
                }
                
                if !currentText.isEmpty {
                    updateTranscription(with: currentText)
                }
            }
        }
    }
    
    private func updateTranscription(with text: String) {
        // Intelligently parse text into lines
        let newLines = parseIntoLines(text)
        
        // Calculate diff for smooth transitions
        let transition = calculateTransition(from: displayedLines, to: newLines)
        
        // Apply the transition with beautiful animations
        applyTransition(transition)
        
        // Pulse glow on new content
        withAnimation(.easeOut(duration: 0.3)) {
            glowIntensity = 0.8
        }
        withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
            glowIntensity = 0
        }
    }
    
    private func parseIntoLines(_ text: String) -> [EtherealTranscriptionLine] {
        let words = text.split(separator: " ").map(String.init)
        var lines: [EtherealTranscriptionLine] = []
        var currentLineText = ""
        var currentLineWords: [String] = []
        
        for word in words {
            let testLine = currentLineWords.isEmpty ? word : "\(currentLineText) \(word)"
            
            if testLine.count <= charactersPerLine {
                currentLineText = testLine
                currentLineWords.append(word)
            } else {
                if !currentLineWords.isEmpty {
                    lines.append(EtherealTranscriptionLine(
                        text: currentLineText,
                        words: currentLineWords
                    ))
                }
                currentLineText = word
                currentLineWords = [word]
            }
        }
        
        if !currentLineWords.isEmpty {
            lines.append(EtherealTranscriptionLine(
                text: currentLineText,
                words: currentLineWords
            ))
        }
        
        // Keep only the most recent lines
        return Array(lines.suffix(maxLinesVisible))
    }
    
    private func calculateTransition(
        from oldLines: [EtherealTranscriptionLine],
        to newLines: [EtherealTranscriptionLine]
    ) -> EtherealTranscriptionTransition {
        var linesToRemove: [EtherealTranscriptionLine] = []
        var linesToAdd: [EtherealTranscriptionLine] = []
        var linesToKeep: [EtherealTranscriptionLine] = []
        
        // Find lines to remove (old lines not in new)
        for oldLine in oldLines {
            if !newLines.contains(where: { $0.text == oldLine.text }) {
                linesToRemove.append(oldLine)
            } else {
                linesToKeep.append(oldLine)
            }
        }
        
        // Find lines to add (new lines not in old)
        for newLine in newLines {
            if !oldLines.contains(where: { $0.text == newLine.text }) {
                linesToAdd.append(newLine)
            }
        }
        
        return EtherealTranscriptionTransition(
            remove: linesToRemove,
            add: linesToAdd,
            keep: linesToKeep,
            finalLines: newLines
        )
    }
    
    private func applyTransition(_ transition: EtherealTranscriptionTransition) {
        // Remove old lines with ethereal fade
        for line in transition.remove {
            withAnimation(.easeOut(duration: lineTransitionDuration)) {
                lineBlurs[line.id] = 20
                lineOpacities[line.id] = 0
                lineOffsets[line.id] = -30
            }
            
            // Clean up after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + lineTransitionDuration) {
                displayedLines.removeAll { $0.id == line.id }
                characterReveals.removeValue(forKey: line.id)
                lineBlurs.removeValue(forKey: line.id)
                lineOpacities.removeValue(forKey: line.id)
                lineOffsets.removeValue(forKey: line.id)
            }
        }
        
        // Update displayed lines for new content
        DispatchQueue.main.asyncAfter(deadline: .now() + (transition.remove.isEmpty ? 0 : lineTransitionDuration * 0.5)) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                displayedLines = transition.finalLines
            }
            
            // Add new lines with character-by-character reveal
            for (index, line) in transition.add.enumerated() {
                // Initialize states
                characterReveals[line.id] = 0
                lineBlurs[line.id] = 15
                lineOpacities[line.id] = 0
                lineOffsets[line.id] = 20
                
                // Entrance animation
                withAnimation(.easeOut(duration: 0.4).delay(Double(index) * 0.1)) {
                    lineBlurs[line.id] = 0
                    lineOpacities[line.id] = 1
                    lineOffsets[line.id] = 0
                }
                
                // Character reveal animation
                animateCharacterReveal(for: line, delay: Double(index) * 0.2)
            }
        }
    }
    
    private func animateCharacterReveal(for line: EtherealTranscriptionLine, delay: TimeInterval) {
        let totalCharacters = line.text.count
        let animationSteps = 20 // Smooth animation steps
        let stepDuration = (Double(totalCharacters) * revealDuration) / Double(animationSteps)
        
        for step in 0...animationSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + (Double(step) * stepDuration)) {
                withAnimation(.easeOut(duration: stepDuration * 2)) {
                    characterReveals[line.id] = CGFloat(step) / CGFloat(animationSteps)
                }
            }
        }
    }
    
    private func performEtherealDissolve() {
        // Beautiful multi-layer dissolve effect
        for (index, line) in displayedLines.enumerated() {
            let delay = Double(index) * 0.1
            
            withAnimation(.easeOut(duration: 0.8).delay(delay)) {
                lineBlurs[line.id] = 30
                lineOpacities[line.id] = 0
                lineOffsets[line.id] = -40
            }
        }
        
        // Container dissolve
        withAnimation(.easeOut(duration: 1.0)) {
            containerScale = 0.9
            containerBlur = 15
            glowIntensity = 0
        }
        
        // Clear everything after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            displayedLines.removeAll()
            characterReveals.removeAll()
            lineBlurs.removeAll()
            lineOpacities.removeAll()
            lineOffsets.removeAll()
        }
    }
}

// MARK: - Individual Line View with Character-Level Animation
struct EtherealTranscriptionLineView: View {
    let line: EtherealTranscriptionLine
    let revealProgress: CGFloat
    let blurAmount: CGFloat
    let opacity: CGFloat
    let yOffset: CGFloat
    let glowIntensity: CGFloat
    
    var body: some View {
        ZStack {
            // Full text for layout (invisible)
            Text(line.text)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundColor(.clear)
            
            // Character-by-character reveal with blur
            HStack(spacing: 0) {
                ForEach(Array(line.text.enumerated()), id: \.offset) { index, character in
                    let normalizedIndex = CGFloat(index) / CGFloat(max(1, line.text.count - 1))
                    let isRevealed = normalizedIndex <= revealProgress
                    
                    Text(String(character))
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(isRevealed ? 1.0 : 0.0)
                        .blur(radius: isRevealed ? 0 : 12)
                        .scaleEffect(isRevealed ? 1.0 : 0.8)
                        .shadow(
                            color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(isRevealed ? glowIntensity * 0.5 : 0),
                            radius: 4,
                            x: 0,
                            y: 0
                        )
                        .animation(
                            .spring(
                                response: 0.4,
                                dampingFraction: 0.7,
                                blendDuration: 0
                            ).delay(Double(index) * 0.02),
                            value: isRevealed
                        )
                }
            }
        }
        .blur(radius: blurAmount)
        .opacity(opacity)
        .offset(y: yOffset)
    }
}

// MARK: - Supporting Models
struct EtherealTranscriptionLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let words: [String]
    
    static func == (lhs: EtherealTranscriptionLine, rhs: EtherealTranscriptionLine) -> Bool {
        lhs.text == rhs.text
    }
}

struct EtherealTranscriptionTransition {
    let remove: [EtherealTranscriptionLine]
    let add: [EtherealTranscriptionLine]
    let keep: [EtherealTranscriptionLine]
    let finalLines: [EtherealTranscriptionLine]
}

// MARK: - Alternative: Simplified Liquid Glass Version
struct SimplifiedLiquidGlassTranscription: View {
    let currentText: String
    @State private var displayText: String = ""
    @State private var revealProgress: CGFloat = 0
    @State private var containerScale: CGFloat = 0.95
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Invisible full text for sizing
                Text(displayText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.clear)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .lineSpacing(6)
                
                // Revealed text with per-character animation
                Text(displayText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .lineSpacing(6)
                    .mask(
                        GeometryReader { geometry in
                            Rectangle()
                                .frame(width: geometry.size.width * revealProgress)
                        }
                    )
                    .blur(radius: (1 - revealProgress) * 10)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: geometry.size.width - 80)
            .glassEffect() // ONLY YOUR LIQUID GLASS
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(containerScale)
            .onChange(of: currentText) { _, newText in
                // Reset for new text
                revealProgress = 0
                displayText = String(newText.suffix(120))
                
                // Animate reveal
                withAnimation(.easeOut(duration: 0.8)) {
                    revealProgress = 1
                    containerScale = 1.02
                }
                withAnimation(.easeInOut(duration: 0.4).delay(0.8)) {
                    containerScale = 1.0
                }
            }
            .onAppear {
                displayText = String(currentText.suffix(120))
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    containerScale = 1.0
                    revealProgress = 1
                }
            }
        }
    }
}