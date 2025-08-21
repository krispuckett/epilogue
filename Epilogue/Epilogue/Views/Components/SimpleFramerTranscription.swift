import SwiftUI

// MARK: - Height Measurement PreferenceKey
struct TranscriptionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Line Model for Animation
struct SimpleFramerLine: Identifiable {
    let id = UUID()
    let text: String
    var isVisible: Bool = false
    var isExiting: Bool = false
}

// MARK: - Simple Framer Transcription with Line-Based Animation
struct SimpleFramerTranscription: View {
    let text: String
    
    @State private var displayLines: [SimpleFramerLine] = []
    @State private var exitingLine: SimpleFramerLine?
    @State private var lastProcessedText: String = ""
    @State private var containerHeight: CGFloat = 0
    @State private var textHeight: CGFloat = 0
    
    private let maxCharsPerLine = 40
    private let minHeight: CGFloat = 54
    private let maxHeight: CGFloat = 80
    private let lineSpacing: CGFloat = 6
    
    var body: some View {
        ZStack {
            // Container that expands smoothly
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.clear)
                .frame(maxWidth: UIScreen.main.bounds.width - 80)
                .frame(height: max(minHeight, containerHeight))
                .glassEffect()
                .shadow(color: .white.opacity(0.1), radius: 20)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: containerHeight)
            
            // Content with height measurement
            VStack(alignment: .leading, spacing: lineSpacing) {
                // Exiting line (if any)
                if let exitingLine = exitingLine {
                    SimpleFramerLineView(line: exitingLine)
                        .transition(.identity)
                }
                
                // Current lines
                ForEach(displayLines) { line in
                    SimpleFramerLineView(line: line)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: UIScreen.main.bounds.width - 80, alignment: .leading)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: TranscriptionHeightKey.self, value: geometry.size.height)
                }
            )
            .onPreferenceChange(TranscriptionHeightKey.self) { height in
                // Calculate container height based on content
                let targetHeight = height + 32 // padding
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    containerHeight = min(maxHeight, max(minHeight, targetHeight))
                }
            }
        }
        .onChange(of: text) { oldValue, newValue in
            if newValue != lastProcessedText {
                processNewText(newValue)
                lastProcessedText = newValue
            }
        }
        .onAppear {
            if !text.isEmpty {
                processNewText(text)
                lastProcessedText = text
            }
        }
    }
    
    private func processNewText(_ newText: String) {
        let cleanText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty text
        guard !cleanText.isEmpty else {
            withAnimation(.easeOut(duration: 0.5)) {
                displayLines.forEach { line in
                    if let index = displayLines.firstIndex(where: { $0.id == line.id }) {
                        displayLines[index].isExiting = true
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                displayLines.removeAll()
                exitingLine = nil
            }
            return
        }
        
        // Parse text into lines
        let newLines = parseIntoLines(cleanText)
        
        // Handle line transitions
        updateLines(with: newLines)
    }
    
    private func parseIntoLines(_ text: String) -> [String] {
        var lines: [String] = []
        var currentLine = ""
        
        let words = text.split(separator: " ").map(String.init)
        
        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            
            if testLine.count > maxCharsPerLine {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                    currentLine = word
                } else {
                    // Word is too long, truncate it
                    lines.append(String(word.prefix(maxCharsPerLine)))
                    currentLine = ""
                }
            } else {
                currentLine = testLine
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        // Keep only last 2 lines visible
        return Array(lines.suffix(2))
    }
    
    private func updateLines(with newLines: [String]) {
        // If we have more than 2 lines and need to remove the first
        if displayLines.count >= 2 && newLines.count >= 2 && displayLines.first?.text != newLines.first {
            // Move first line to exiting
            if let firstLine = displayLines.first {
                exitingLine = SimpleFramerLine(text: firstLine.text, isVisible: true, isExiting: true)
                
                // Animate exit
                withAnimation(.easeOut(duration: 0.5)) {
                    exitingLine?.isExiting = true
                }
                
                // Clean up after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    exitingLine = nil
                }
                
                // Remove from display lines
                displayLines.removeFirst()
            }
        }
        
        // Update or add lines
        for (index, lineText) in newLines.enumerated() {
            if index < displayLines.count {
                // Update existing line if different
                if displayLines[index].text != lineText {
                    displayLines[index] = SimpleFramerLine(text: lineText, isVisible: false)
                    animateLineIn(at: index)
                }
            } else {
                // Add new line
                let newLine = SimpleFramerLine(text: lineText, isVisible: false)
                displayLines.append(newLine)
                animateLineIn(at: displayLines.count - 1)
            }
        }
        
        // Remove excess lines
        if displayLines.count > newLines.count {
            displayLines = Array(displayLines.prefix(newLines.count))
        }
    }
    
    private func animateLineIn(at index: Int) {
        guard index < displayLines.count else { return }
        
        // Animate line appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                displayLines[index].isVisible = true
            }
        }
    }
}

// MARK: - Individual Line View
struct SimpleFramerLineView: View {
    let line: SimpleFramerLine
    
    private var blurRadius: Double {
        if line.isExiting {
            return 30
        } else if !line.isVisible {
            return 20
        } else {
            return 0
        }
    }
    
    private var opacity: Double {
        if line.isExiting {
            return 0
        } else if !line.isVisible {
            return 0
        } else {
            return 1
        }
    }
    
    private var yOffset: CGFloat {
        if line.isExiting {
            return -25
        } else if !line.isVisible {
            return 20
        } else {
            return 0
        }
    }
    
    var body: some View {
        Text(line.text)
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .blur(radius: blurRadius)
            .opacity(opacity)
            .offset(y: yOffset)
            .animation(
                line.isExiting ?
                    .easeOut(duration: 0.5) :
                    .spring(response: 0.5, dampingFraction: 0.8),
                value: line.isVisible
            )
            .animation(
                .easeOut(duration: 0.5),
                value: line.isExiting
            )
    }
}

// MARK: - Test Harness
struct SimpleFramerTranscription_TestHarness: View {
    @State private var testText = ""
    @State private var lineCount = 0
    @State private var showDebug = true
    
    let sampleTexts = [
        "",
        "Hello world",
        "This is a longer text that will wrap to multiple lines",
        "This is an even longer text that demonstrates how the container smoothly expands and contracts as lines are added and removed from the transcription view"
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Transcription view
                SimpleFramerTranscription(text: testText)
                    .overlay(alignment: .topTrailing) {
                        if showDebug {
                            // Debug overlay
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Lines: \(countLines(testText))")
                                Text("Chars: \(testText.count)")
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .offset(x: -10, y: 10)
                        }
                    }
                
                // Test controls
                VStack(spacing: 15) {
                    HStack(spacing: 15) {
                        Button("Clear") {
                            testText = ""
                        }
                        
                        Button("Short") {
                            testText = sampleTexts[1]
                        }
                        
                        Button("Medium") {
                            testText = sampleTexts[2]
                        }
                        
                        Button("Long") {
                            testText = sampleTexts[3]
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Simulate Typing") {
                        simulateTyping()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Toggle("Show Debug", isOn: $showDebug)
                        .toggleStyle(.switch)
                        .frame(width: 150)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func countLines(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let words = text.split(separator: " ")
        var lines = 1
        var currentLineLength = 0
        
        for word in words {
            if currentLineLength + word.count + 1 > 40 {
                lines += 1
                currentLineLength = word.count
            } else {
                currentLineLength += word.count + 1
            }
        }
        
        return min(lines, 2) // Max 2 visible
    }
    
    private func simulateTyping() {
        testText = ""
        let fullText = "This is a simulation of real time transcription that gradually adds words to demonstrate the smooth container expansion"
        let words = fullText.split(separator: " ").map(String.init)
        
        for (index, word) in words.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                testText += (testText.isEmpty ? "" : " ") + word
            }
        }
    }
}

// MARK: - Preview
struct SimpleFramerTranscription_Previews: PreviewProvider {
    static var previews: some View {
        SimpleFramerTranscription_TestHarness()
            .preferredColorScheme(.dark)
    }
}