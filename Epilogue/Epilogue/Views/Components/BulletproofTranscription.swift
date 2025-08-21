import SwiftUI

// MARK: - BULLETPROOF SOLUTION - Line-Based Only
struct BulletproofTranscription: View {
    let currentText: String
    
    @State private var line1: String = ""
    @State private var line2: String = ""
    @State private var line1Opacity: Double = 0
    @State private var line2Opacity: Double = 0
    @State private var line1Blur: Double = 0
    @State private var line2Blur: Double = 0
    @State private var line1Offset: Double = 0
    @State private var line2Offset: Double = 0
    @State private var containerHeight: CGFloat = 54
    
    private let maxCharsPerLine = 40
    
    var body: some View {
        // Single VStack, no HStacks, no ForEach on words
        VStack(alignment: .center, spacing: 6) {
            if !line1.isEmpty {
                Text(line1) // SINGLE Text view for entire line
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .opacity(line1Opacity)
                    .blur(radius: line1Blur)
                    .offset(y: line1Offset)
            }
            
            if !line2.isEmpty {
                Text(line2) // SINGLE Text view for entire line
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .opacity(line2Opacity)
                    .blur(radius: line2Blur)
                    .offset(y: line2Offset)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: UIScreen.main.bounds.width - 80)
        .frame(minHeight: containerHeight)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: containerHeight)
        .onChange(of: currentText) { _, newText in
            updateLines(with: newText)
        }
        .onAppear {
            if !currentText.isEmpty {
                updateLines(with: currentText)
            }
        }
    }
    
    private func updateLines(with text: String) {
        // Parse into lines - NO WORD ARRAYS
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            if testLine.count <= maxCharsPerLine {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        // Take only last 2 lines
        lines = Array(lines.suffix(2))
        
        // Update display with animations
        updateDisplay(lines: lines)
    }
    
    private func updateDisplay(lines: [String]) {
        let newLine1 = lines.count > 0 ? lines[0] : ""
        let newLine2 = lines.count > 1 ? lines[1] : ""
        
        // If line1 is changing and we have 2 lines, it means line1 is being pushed out
        if line1 != newLine1 && !line1.isEmpty && lines.count == 2 {
            // Animate old line1 out
            withAnimation(.easeOut(duration: 0.5)) {
                line1Blur = 30
                line1Opacity = 0
                line1Offset = -25
            }
            
            // After exit animation, update content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                line1 = newLine1
                line1Blur = 20
                line1Opacity = 0
                line1Offset = 20
                
                // Animate new line1 in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    line1Blur = 0
                    line1Opacity = 1
                    line1Offset = 0
                }
            }
        } else if line1 != newLine1 {
            // Simple update for line1
            line1 = newLine1
            if !newLine1.isEmpty {
                line1Blur = 20
                line1Opacity = 0
                line1Offset = 20
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    line1Blur = 0
                    line1Opacity = 1
                    line1Offset = 0
                }
            }
        }
        
        // Update line2
        if line2 != newLine2 {
            line2 = newLine2
            if !newLine2.isEmpty {
                line2Blur = 20
                line2Opacity = 0
                line2Offset = 20
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    line2Blur = 0
                    line2Opacity = 1
                    line2Offset = 0
                }
            }
        }
        
        // Update container height
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            containerHeight = lines.count <= 1 ? 54 : 80
        }
    }
}

// MARK: - EVEN SIMPLER FALLBACK
struct UltraSimpleLineTranscription: View {
    let currentText: String
    @State private var displayText: String = ""
    @State private var textOpacity: Double = 1
    
    var body: some View {
        Text(displayText)
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .lineSpacing(4)
            .opacity(textOpacity)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: UIScreen.main.bounds.width - 80)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onChange(of: currentText) { _, newText in
                // Simple fade transition
                withAnimation(.easeOut(duration: 0.2)) {
                    textOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    displayText = String(newText.suffix(80))
                    withAnimation(.easeIn(duration: 0.3)) {
                        textOpacity = 1
                    }
                }
            }
            .onAppear {
                displayText = String(currentText.suffix(80))
            }
    }
}

// MARK: - Testing View to Verify It Works
struct TestTranscriptionView: View {
    @State private var testText = ""
    @State private var wordIndex = 0
    
    let testWords = [
        "This", "is", "actually", "working", "now",
        "with", "proper", "line", "management", "and",
        "no", "broken", "word", "animations", "that",
        "scatter", "text", "everywhere", "like", "before"
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 50) {
                // The working transcription
                BulletproofTranscription(currentText: testText)
                
                // Test controls
                VStack(spacing: 20) {
                    Button("Add Word") {
                        if wordIndex < testWords.count {
                            testText = testWords[0...wordIndex].joined(separator: " ")
                            wordIndex += 1
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(10)
                    
                    Button("Reset") {
                        testText = ""
                        wordIndex = 0
                    }
                    .padding()
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(10)
                }
                .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Preview
struct BulletproofTranscription_Previews: PreviewProvider {
    static var previews: some View {
        TestTranscriptionView()
            .preferredColorScheme(.dark)
    }
}