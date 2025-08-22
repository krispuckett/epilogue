import SwiftUI

// MARK: - Word Model
struct WordModel: Identifiable {
    let id = UUID()
    let text: String
    var isVisible: Bool = false
    var isExiting: Bool = false
}

// MARK: - Line Model
struct LineModel: Identifiable {
    let id = UUID()
    let text: String
    var words: [WordModel]
    var isExiting: Bool = false
}

// MARK: - Framer Motion-style Transcription View
struct FramerTranscriptionView: View {
    let transcribedText: String
    
    @State private var lines: [LineModel] = []
    @State private var lastProcessedText: String = ""
    @State private var containerHeight: CGFloat = 54
    
    private let maxCharsPerLine = 40
    private let singleLineHeight: CGFloat = 54
    private let twoLineHeight: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            // Glass container that expands smoothly
            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines) { line in
                    HStack(spacing: 4) {
                        ForEach(line.words) { word in
                            WordView(
                                word: word,
                                isLineExiting: line.isExiting
                            )
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: geometry.size.width - 80)
            .frame(minHeight: containerHeight)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: lines.count)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: containerHeight)
            .onChange(of: transcribedText) { oldValue, newValue in
                if newValue != lastProcessedText {
                    processNewText(newValue)
                    lastProcessedText = newValue
                }
            }
            .onAppear {
                if !transcribedText.isEmpty {
                    processNewText(transcribedText)
                    lastProcessedText = transcribedText
                }
            }
        }
    }
    
    private func processNewText(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            // Clear with animation
            withAnimation(.easeOut(duration: 0.5)) {
                for index in lines.indices {
                    lines[index].isExiting = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                lines.removeAll()
                containerHeight = singleLineHeight
            }
            return
        }
        
        // Split text into words
        let allWords = cleanText.split(separator: " ").map(String.init)
        
        // Build lines with smart word wrapping
        var newLines: [LineModel] = []
        var currentLineWords: [String] = []
        var currentLineLength = 0
        
        for word in allWords {
            let wordLength = word.count + (currentLineWords.isEmpty ? 0 : 1) // +1 for space
            
            if currentLineLength + wordLength > maxCharsPerLine && !currentLineWords.isEmpty {
                // Start new line
                let lineText = currentLineWords.joined(separator: " ")
                let wordModels = currentLineWords.map { WordModel(text: $0, isVisible: false) }
                newLines.append(LineModel(text: lineText, words: wordModels, isExiting: false))
                
                currentLineWords = [word]
                currentLineLength = word.count
            } else {
                currentLineWords.append(word)
                currentLineLength += wordLength
            }
        }
        
        // Add remaining words as last line
        if !currentLineWords.isEmpty {
            let lineText = currentLineWords.joined(separator: " ")
            let wordModels = currentLineWords.map { WordModel(text: $0, isVisible: false) }
            newLines.append(LineModel(text: lineText, words: wordModels, isExiting: false))
        }
        
        // Keep only last 2 lines
        if newLines.count > 2 {
            newLines = Array(newLines.suffix(2))
        }
        
        // Animate line transitions
        updateLines(with: newLines)
    }
    
    private func updateLines(with newLines: [LineModel]) {
        // Mark excess lines for exit
        if lines.count >= 2 && newLines.count > lines.count {
            withAnimation(.easeOut(duration: 0.5)) {
                if lines.count > 0 {
                    lines[0].isExiting = true
                }
            }
            
            // Remove exiting line after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if lines.count > 0 && lines[0].isExiting {
                    lines.removeFirst()
                }
            }
        }
        
        // Update or add new lines
        for (index, newLine) in newLines.enumerated() {
            if index < lines.count {
                // Update existing line if different
                if lines[index].text != newLine.text {
                    lines[index] = newLine
                    animateWordsIn(at: index)
                }
            } else {
                // Add new line
                lines.append(newLine)
                animateWordsIn(at: lines.count - 1)
            }
        }
        
        // Update container height
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            containerHeight = lines.count > 1 ? twoLineHeight : singleLineHeight
        }
    }
    
    private func animateWordsIn(at lineIndex: Int) {
        guard lineIndex < lines.count else { return }
        
        // Animate each word with slight delay
        for (wordIndex, _) in lines[lineIndex].words.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(wordIndex) * 0.02) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    if lineIndex < lines.count && wordIndex < lines[lineIndex].words.count {
                        lines[lineIndex].words[wordIndex].isVisible = true
                    }
                }
            }
        }
    }
}

// MARK: - Individual Word View
struct WordView: View {
    let word: WordModel
    let isLineExiting: Bool
    
    private var blurRadius: Double {
        if isLineExiting {
            return 30
        } else if !word.isVisible {
            return 20
        } else {
            return 0
        }
    }
    
    private var opacity: Double {
        if isLineExiting {
            return 0
        } else if !word.isVisible {
            return 0
        } else {
            return 1
        }
    }
    
    private var yOffset: CGFloat {
        if isLineExiting {
            return -25
        } else if !word.isVisible {
            return 20
        } else {
            return 0
        }
    }
    
    var body: some View {
        Text(word.text)
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .blur(radius: blurRadius)
            .opacity(opacity)
            .offset(y: yOffset)
            .animation(
                isLineExiting ? 
                    .easeOut(duration: 0.5) : 
                    .spring(response: 0.5, dampingFraction: 0.8),
                value: word.isVisible
            )
            .animation(
                .easeOut(duration: 0.5),
                value: isLineExiting
            )
    }
}

// MARK: - Preview
struct FramerTranscriptionView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text = "Hello, this is a test"
        
        var body: some View {
            ZStack {
                Color.black
                
                VStack(spacing: 40) {
                    FramerTranscriptionView(transcribedText: text)
                    
                    Button("Add Text") {
                        text += " and here is some more text to demonstrate the animation"
                    }
                    .foregroundColor(.white)
                }
                .padding()
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}