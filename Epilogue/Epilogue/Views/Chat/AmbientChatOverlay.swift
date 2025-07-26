import SwiftUI
import SwiftData

// MARK: - Ambient Session Model
struct AmbientSession: Identifiable {
    let id = UUID()
    let startTime: Date
    var endTime: Date?
    var book: Book?
    var rawTranscriptions: [String] = []
    var processedData: ProcessedAmbientSession?
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}

struct ProcessedAmbientSession {
    let quotes: [ExtractedQuote]
    let notes: [ExtractedNote]
    let questions: [ExtractedQuestion]
    let summary: String
    let duration: TimeInterval
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

struct ExtractedQuote {
    let text: String
    let context: String?
    let timestamp: Date
}

struct ExtractedNote {
    let text: String
    let type: NoteType
    let timestamp: Date
    
    enum NoteType {
        case reflection
        case insight
        case connection
    }
}

struct ExtractedQuestion {
    let text: String
    let context: String?
    let timestamp: Date
}

// MARK: - Claude-Inspired Gradient Background
struct ClaudeInspiredGradient: View {
    @State private var phase: CGFloat = 0
    let book: Book?
    @State private var colorPalette: ColorPalette?
    @Binding var audioLevel: Float
    @Binding var isListening: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if let palette = colorPalette, book != nil {
                // Book-specific gradient when listening
                BookListeningGradient(palette: palette, phase: phase, audioLevel: audioLevel, isListening: isListening)
            } else {
                // Default amber gradient - enhanced with radial curves
                EnhancedAmberGradient(phase: phase, audioLevel: audioLevel, isListening: isListening)
            }
        }
        .onAppear {
            startWaveAnimation()
        }
        .onChange(of: book) { _, newBook in
            if let newBook = newBook {
                Task {
                    await extractBookColors(newBook)
                }
            } else {
                colorPalette = nil
            }
        }
    }
    
    private func startWaveAnimation() {
        // Base animation speed modulated by audio
        let baseDuration: Double = isListening && audioLevel > 0.1 ? 1.5 : 2.5
        let speedMultiplier = 1.0 - Double(audioLevel * 0.5) // Faster when louder
        
        withAnimation(.easeInOut(duration: baseDuration * speedMultiplier).repeatForever(autoreverses: true)) {
            phase = 1
        }
    }
    
    private func extractBookColors(_ book: Book) async {
        guard let coverURL = book.coverImageURL else { 
            print("No cover URL for book: \(book.title)")
            return 
        }
        
        // Force high quality image and HTTPS
        let highQualityURL = coverURL
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "zoom=1", with: "zoom=3")
            .replacingOccurrences(of: "zoom=2", with: "zoom=3")
        
        print("Extracting colors from: \(highQualityURL)")
        
        guard let url = URL(string: highQualityURL),
              let data = try? await URLSession.shared.data(from: url).0,
              let image = UIImage(data: data) else { 
            print("Failed to load image from URL")
            return 
        }
        
        let extractor = OKLABColorExtractor()
        if let extractedPalette = try? await extractor.extractPalette(from: image, imageSource: "BookCover") {
            print("Successfully extracted palette")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.colorPalette = extractedPalette
                }
            }
        } else {
            print("Failed to extract palette")
        }
    }
}

// Book-specific gradient with breathing animation - matching BookCoverBackgroundView exactly
struct BookListeningGradient: View {
    let palette: ColorPalette
    let phase: CGFloat
    let audioLevel: Float
    let isListening: Bool
    
    var body: some View {
        ZStack {
            // Pure black base
            Color.black.ignoresSafeArea()
            
            // Top gradient - exact copy from BookCoverBackgroundView
            LinearGradient(
                stops: [
                    .init(color: enhanceColor(palette.primary), location: 0.0),
                    .init(color: enhanceColor(palette.primary).opacity(0.85), location: 0.10),
                    .init(color: enhanceColor(palette.secondary).opacity(0.7), location: 0.20),
                    .init(color: enhanceColor(palette.accent).opacity(0.5), location: 0.32),
                    .init(color: enhanceColor(palette.background).opacity(0.3), location: 0.45),
                    .init(color: Color.black.opacity(0.5), location: 0.58),
                    .init(color: Color.black, location: 0.70)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .blur(radius: 45 * (1 - CGFloat(audioLevel * 0.2))) // Less blur when speaking
            .scaleEffect(y: 0.7 + CGFloat(audioLevel * 0.2)) // Expand with voice
            .offset(y: -200 + phase * 50 + CGFloat(audioLevel * 40)) // Voice pushes gradient
            .scaleEffect(x: 1 + phase * 0.1 + CGFloat(audioLevel * 0.15)) // Horizontal expansion with voice
            
            // Bottom gradient - mirrored version
            LinearGradient(
                stops: [
                    .init(color: enhanceColor(palette.accent), location: 0.0),
                    .init(color: enhanceColor(palette.accent).opacity(0.85), location: 0.10),
                    .init(color: enhanceColor(palette.secondary).opacity(0.7), location: 0.20),
                    .init(color: enhanceColor(palette.primary).opacity(0.5), location: 0.32),
                    .init(color: enhanceColor(palette.background).opacity(0.3), location: 0.45),
                    .init(color: Color.black.opacity(0.5), location: 0.58),
                    .init(color: Color.black, location: 0.70)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
            .blur(radius: 45 * (1 - CGFloat(audioLevel * 0.2))) // Less blur when speaking
            .scaleEffect(y: 0.7 + CGFloat(audioLevel * 0.2)) // Expand with voice
            .offset(y: 200 - phase * 50 - CGFloat(audioLevel * 40)) // Voice pushes gradient
            .scaleEffect(x: 1 + phase * 0.1 + CGFloat(audioLevel * 0.15)) // Horizontal expansion with voice
            
            // Very subtle noise texture overlay for depth
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.05 + Double(audioLevel * 0.1))
                .ignoresSafeArea()
                .blendMode(.plusLighter)
            
            // Voice ripple effect from bottom  
            if isListening && audioLevel > 0.1 {
                ForEach(0..<3) { ripple in
                    rippleView(for: ripple, with: palette)
                }
            }
        }
    }
    
    // Copy the enhance color function from BookCoverBackgroundView
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost vibrancy significantly for Apple Music effect
        saturation = min(saturation * 1.6, 1.0)
        brightness = max(brightness, 0.5) // Ensure minimum brightness
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
    
    @ViewBuilder
    private func rippleView(for index: Int, with palette: ColorPalette) -> some View {
        let opacity = Double(1 - index) * 0.4 * Double(audioLevel)
        let size = 150 + CGFloat(index) * 200 * CGFloat(audioLevel)
        let blurAmount = CGFloat(index) * 3
        let delay = Double(index) * 0.15
        
        Circle()
            .stroke(enhanceColor(palette.accent).opacity(opacity), lineWidth: 3)
            .frame(width: size, height: size)
            .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height)
            .blur(radius: blurAmount)
            .animation(.easeOut(duration: 1.8).delay(delay), value: audioLevel)
    }
}

// Enhanced amber gradient with smoother radial curves
struct EnhancedAmberGradient: View {
    let phase: CGFloat
    let audioLevel: Float
    let isListening: Bool
    
    var body: some View {
        ZStack {
            // Base gradients with phase animation
            ForEach(0..<3) { index in
                topGradientLayer(index: index)
            }
            
            // Mirrored bottom
            ForEach(0..<3) { index in
                bottomGradientLayer(index: index)
            }
            
            // Top radial curve overlay
            RadialGradient(
                colors: [
                    Color.orange.opacity(0.4),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.5
            )
            .ignoresSafeArea()
            .opacity(0.6)
            
            // Bottom radial curve overlay - pulses with voice
            RadialGradient(
                colors: [
                    Color.orange.opacity(0.3 + Double(audioLevel * 0.5)),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.5 * (1 + CGFloat(audioLevel * 0.3))
            )
            .ignoresSafeArea()
            .opacity(0.5 + Double(audioLevel * 0.3))
            
            // Subtle center glow - breathes with voice
            RadialGradient(
                colors: [
                    Color.orange.opacity(0.1 + Double(audioLevel * 0.2)),
                    Color.clear
                ],
                center: .center,
                startRadius: 50 * (1 - CGFloat(audioLevel * 0.2)),
                endRadius: 200 * (1 + CGFloat(audioLevel * 0.3))
            )
            .blur(radius: 20 * (1 - CGFloat(audioLevel * 0.3)))
            .opacity(0.5 + Double(audioLevel * 0.2))
            
            // Voice ripple effect from bottom
            if isListening && audioLevel > 0.1 {
                ForEach(0..<3) { ripple in
                    amberRippleView(for: ripple)
                }
            }
        }
    }
    
    @ViewBuilder
    private func amberRippleView(for index: Int) -> some View {
        let opacity = Double(1 - index) * 0.3 * Double(audioLevel)
        let size = 100 + CGFloat(index) * 150 * CGFloat(audioLevel)
        let blurAmount = CGFloat(index) * 2
        let delay = Double(index) * 0.1
        
        Circle()
            .stroke(Color.orange.opacity(opacity), lineWidth: 2)
            .frame(width: size, height: size)
            .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height)
            .blur(radius: blurAmount)
            .animation(.easeOut(duration: 1.5).delay(delay), value: audioLevel)
    }
    
    @ViewBuilder
    private func topGradientLayer(index: Int) -> some View {
        let baseOpacity = 0.3 + Double(index) * 0.1
        let midOpacity = 0.5 + Double(index) * 0.1
        
        LinearGradient(
            colors: [
                Color.clear,
                Color.orange.opacity(baseOpacity),
                Color.orange.opacity(midOpacity),
                Color.orange.opacity(baseOpacity),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .modifier(GradientAnimationModifier(
            phase: phase,
            audioLevel: audioLevel,
            index: index,
            isTop: true
        ))
    }
    
    @ViewBuilder
    private func bottomGradientLayer(index: Int) -> some View {
        let baseOpacity = 0.3 + Double(index) * 0.1
        let midOpacity = 0.5 + Double(index) * 0.1
        
        LinearGradient(
            colors: [
                Color.clear,
                Color.orange.opacity(baseOpacity),
                Color.orange.opacity(midOpacity),
                Color.orange.opacity(baseOpacity),
                Color.clear
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        .modifier(GradientAnimationModifier(
            phase: phase,
            audioLevel: audioLevel,
            index: index,
            isTop: false
        ))
    }
}

// Helper modifier to simplify gradient animations
struct GradientAnimationModifier: ViewModifier {
    let phase: CGFloat
    let audioLevel: Float
    let index: Int
    let isTop: Bool
    
    func body(content: Content) -> some View {
        // Break down calculations into simpler parts
        let phaseScale = phase * 0.1
        let audioScale = CGFloat(audioLevel) * 0.3
        let yScale = 0.5 + phaseScale + audioScale
        
        let phaseXScale = phase * 0.15
        let audioXScale = CGFloat(audioLevel) * 0.2
        let xScale = 1 + phaseXScale + audioXScale
        
        // Calculate y offset components separately
        let baseOffset: CGFloat = isTop ? -200 : 200
        let phaseOffset = phase * 80
        let indexOffset = CGFloat(index) * 30
        let audioOffset = CGFloat(audioLevel) * 50
        
        let yOffset: CGFloat
        if isTop {
            yOffset = baseOffset + phaseOffset + indexOffset + audioOffset
        } else {
            yOffset = baseOffset - phaseOffset - indexOffset - audioOffset
        }
        
        // Simplify other calculations
        let audioFactor = Float(1 - audioLevel * 0.3)
        let blurRadius = CGFloat(index * 5) * CGFloat(audioFactor)
        
        let indexOpacity = Double(index) * 0.15
        let audioOpacity = Double(audioLevel) * 0.3
        let opacity = 0.6 - indexOpacity + audioOpacity
        
        // Rotation calculations
        let phaseRotation = Double(phase * 5)
        let indexRotation = Double(index) * 2
        let audioRotation = Double(audioLevel) * 10
        
        let rotation: Double
        if isTop {
            rotation = phaseRotation - indexRotation + audioRotation
        } else {
            rotation = -phaseRotation + indexRotation - audioRotation
        }
        
        return content
            .scaleEffect(y: yScale)
            .scaleEffect(x: xScale)
            .offset(y: yOffset)
            .blur(radius: blurRadius)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Minimal Book Selection
struct MinimalBookSelection: View {
    @Binding var selectedBook: Book?
    @State private var showingBookPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("What are you reading?")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Say the book title or tap to select")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
            
            Button {
                showingBookPicker = true
            } label: {
                Image(systemName: "book")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet(onBookSelected: { book in
                selectedBook = book
                showingBookPicker = false
            })
        }
    }
}

// MARK: - Minimal Ambient Chat Overlay
struct AmbientChatOverlay: View {
    @Binding var isActive: Bool
    @Binding var selectedBook: Book?
    @Binding var session: AmbientSession?
    
    @State private var pulseAnimation = false
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var pipeline = AmbientIntelligencePipeline()
    @StateObject private var audioMonitor = AudioLevelMonitor()
    @State private var showProcessingView = false
    @State private var showingSummary = false
    @State private var processedSession: ProcessedAmbientSession?
    @State private var showingBookPicker = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            // Claude-inspired gradient background
            ClaudeInspiredGradient(
                book: selectedBook,
                audioLevel: $audioMonitor.audioLevel,
                isListening: $audioMonitor.isRecording
            )
            
            VStack {
                // Minimal header with close button
                HStack {
                    Spacer()
                    
                    Button {
                        // Simple direct close without processing
                        voiceManager.stopListening()
                        isActive = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Central content
                if selectedBook == nil {
                    // Book selection
                    MinimalBookSelection(selectedBook: $selectedBook)
                } else {
                    // Listening indicator (no pulsing animation)
                    ZStack {
                        // Static outer ring
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            .frame(width: 100, height: 100)
                        
                        // Center orb
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: voiceManager.isListening ? "waveform" : "mic.fill")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.black)
                            )
                    }
                }
                
                Spacer()
                
                // Stop button with text above
                if selectedBook != nil {
                    VStack(spacing: 20) {
                        // Status text moved here
                        VStack(spacing: 8) {
                            Text(statusText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            // Book title with swap button
                            if let book = selectedBook {
                                HStack(spacing: 8) {
                                    Text(book.title)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    
                                    Button {
                                        // Stop listening and show book picker
                                        voiceManager.stopListening()
                                        showingBookPicker = true
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.6))
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 40)
                            }
                        }
                        
                        Button {
                            stopSession()
                        } label: {
                            Text("Stop Listening")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            
            // Processing overlay
            if showProcessingView {
                ProcessingOverlay(session: session)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if selectedBook != nil {
                startListening()
            }
        }
        .onChange(of: selectedBook) { _, newValue in
            if newValue != nil {
                startListening()
            }
        }
        .onChange(of: voiceManager.transcribedText) { oldValue, newValue in
            // Store transcriptions in session
            if !newValue.isEmpty && newValue != oldValue {
                print("[AmbientChat] New transcription: \(newValue)")
                session?.rawTranscriptions.append(newValue)
                // Reset transcribed text to capture continuous speech
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    voiceManager.transcribedText = ""
                }
            }
        }
        .sheet(isPresented: $showingSummary) {
            if let processed = processedSession {
                SessionSummaryView(
                    session: processed,
                    onDismiss: {
                        showingSummary = false
                        isActive = false
                    },
                    onViewDetails: {
                        showingSummary = false
                        isActive = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet(onBookSelected: handleBookPickerSelection)
        }
    }
    
    private var statusText: String {
        switch voiceManager.recognitionState {
        case .idle:
            return "Tap to start"
        case .listening:
            return voiceManager.transcribedText.isEmpty ? "Listening..." : "I'm listening..."
        case .processing:
            return "Processing..."
        }
    }
    
    private func handleBookPickerSelection(_ book: Book) {
        // Save current session if there's transcription
        let hasTranscriptions = !(session?.rawTranscriptions.isEmpty ?? true)
        
        if hasTranscriptions {
            // Process and save current session before switching
            Task {
                await processCurrentSessionBeforeSwitch()
                
                // Switch to new book
                await MainActor.run {
                    selectedBook = book
                    session?.book = book
                    showingBookPicker = false
                    
                    // Resume listening with new book
                    voiceManager.startAmbientListening()
                }
            }
        } else {
            // No transcriptions yet, just switch
            selectedBook = book
            session?.book = book
            showingBookPicker = false
            voiceManager.startAmbientListening()
        }
    }
    
    private func startListening() {
        // Create new session
        session = AmbientSession(startTime: Date(), book: selectedBook)
        
        // Start listening
        voiceManager.startAmbientListening()
        
        // Start audio monitoring for visual feedback
        audioMonitor.startMonitoring()
    }
    
    private func stopSession() {
        // Stop listening
        voiceManager.stopListening()
        
        // Stop audio monitoring
        audioMonitor.stopMonitoring()
        
        // Mark session end time
        session?.endTime = Date()
        
        // Show processing view
        withAnimation {
            showProcessingView = true
        }
        
        // Process after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            processSessionAndDismiss()
        }
    }
    
    private func processSessionAndDismiss() {
        guard let session = session else {
            withAnimation {
                isActive = false
            }
            return
        }
        
        Task {
            // Process the session
            let processed = await processAmbientSession(session)
            
            // Save to SwiftData - find existing thread or create new one
            await MainActor.run {
                // Query for existing thread for this book
                let bookId = session.book?.localId
                let descriptor = FetchDescriptor<ChatThread>(
                    predicate: bookId != nil ? #Predicate<ChatThread> { thread in
                        thread.bookId == bookId
                    } : nil
                )
                
                let existingThreads = try? modelContext.fetch(descriptor)
                let chatThread: ChatThread
                
                if let existingThread = existingThreads?.first {
                    // Update existing thread with new session data
                    chatThread = existingThread
                    chatThread.isAmbientSession = true
                    chatThread.capturedItems += processed.quotes.count + processed.notes.count + processed.questions.count
                    chatThread.sessionDuration += session.duration
                    chatThread.lastMessageDate = session.endTime ?? Date()
                    
                    // Add a message summarizing the ambient session
                    let summaryMessage = ThreadedChatMessage(
                        content: "🎙️ Ambient Session (\(processed.formattedDuration))\n\n" +
                                "Captured: \(processed.quotes.count) quotes, \(processed.notes.count) notes, \(processed.questions.count) questions\n\n" +
                                processed.summary,
                        isUser: false,
                        timestamp: session.endTime ?? Date()
                    )
                    chatThread.messages.append(summaryMessage)
                } else {
                    // Create new thread for this book
                    chatThread = ChatThread(ambientSession: session, processedData: processed)
                    modelContext.insert(chatThread)
                }
                
                try? modelContext.save()
                
                // Show summary
                processedSession = processed
                showProcessingView = false
                showingSummary = true
            }
        }
    }
    
    private func processAmbientSession(_ session: AmbientSession) async -> ProcessedAmbientSession {
        print("[AmbientChat] Processing session with \(session.rawTranscriptions.count) transcriptions")
        
        // Combine all transcriptions into a single text for better context
        let fullTranscript = session.rawTranscriptions.joined(separator: " ")
        print("[AmbientChat] Full transcript: \(fullTranscript)")
        
        // Extract quotes, notes, and questions from raw transcriptions
        var quotes: [ExtractedQuote] = []
        var notes: [ExtractedNote] = []
        var questions: [ExtractedQuestion] = []
        
        // Process each transcription segment
        for (index, transcription) in session.rawTranscriptions.enumerated() {
            let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            print("[AmbientChat] Processing segment \(index): \(trimmed)")
            
            // Look for quotes (multiple patterns)
            var foundQuote = false
            
            // Pattern 1: Text in quotation marks
            let quotePatterns = [
                #"\"([^\"]+)\""#, // Double quotes
                #"'([^']+)'"#, // Single quotes
                #""([^"]+)""#, // Smart quotes
            ]
            
            for pattern in quotePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
                    for match in matches {
                        if let range = Range(match.range(at: 1), in: trimmed) {
                            let quoteText = String(trimmed[range])
                            quotes.append(ExtractedQuote(
                                text: quoteText,
                                context: session.book?.title,
                                timestamp: Date()
                            ))
                            foundQuote = true
                        }
                    }
                }
            }
            
            // Pattern 2: Sentences that mention quoting or reading
            let quoteIndicators = ["quote", "passage", "says", "writes", "wrote", "according to"]
            let lowercased = trimmed.lowercased()
            if !foundQuote && quoteIndicators.contains(where: { lowercased.contains($0) }) {
                // Extract the sentence after the indicator
                quotes.append(ExtractedQuote(
                    text: trimmed,
                    context: session.book?.title,
                    timestamp: Date()
                ))
                foundQuote = true
            }
            
            // Look for questions
            var foundQuestion = false
            if trimmed.contains("?") || 
               trimmed.lowercased().starts(with: "why") ||
               trimmed.lowercased().starts(with: "how") ||
               trimmed.lowercased().starts(with: "what") ||
               trimmed.lowercased().starts(with: "when") ||
               trimmed.lowercased().starts(with: "where") ||
               trimmed.lowercased().starts(with: "who") ||
               trimmed.lowercased().contains("i wonder") ||
               trimmed.lowercased().contains("i'm unsure") {
                questions.append(ExtractedQuestion(
                    text: trimmed,
                    context: session.book?.title,
                    timestamp: Date()
                ))
                foundQuestion = true
            }
            
            // Everything else becomes a note (reflection/insight)
            if !foundQuote && !foundQuestion {
                // Determine note type based on content
                let noteType: ExtractedNote.NoteType
                if trimmed.lowercased().contains("reminds me") || 
                   trimmed.lowercased().contains("similar to") ||
                   trimmed.lowercased().contains("connects to") {
                    noteType = .connection
                } else if trimmed.lowercased().contains("realize") ||
                          trimmed.lowercased().contains("understand") ||
                          trimmed.lowercased().contains("insight") {
                    noteType = .insight
                } else {
                    noteType = .reflection
                }
                
                notes.append(ExtractedNote(
                    text: trimmed,
                    type: noteType,
                    timestamp: Date()
                ))
            }
        }
        
        print("[AmbientChat] Extracted: \(quotes.count) quotes, \(notes.count) notes, \(questions.count) questions")
        
        // Generate summary
        let summary = generateSessionSummary(session: session, quotes: quotes, notes: notes, questions: questions)
        
        return ProcessedAmbientSession(
            quotes: quotes,
            notes: notes,
            questions: questions,
            summary: summary,
            duration: session.duration
        )
    }
    
    private func generateSessionSummary(session: AmbientSession, quotes: [ExtractedQuote], notes: [ExtractedNote], questions: [ExtractedQuestion]) -> String {
        var summary = "Reading session"
        
        if let book = session.book {
            summary += " with \(book.title)"
        }
        
        summary += ". Captured \(quotes.count) quotes, \(notes.count) notes, and \(questions.count) questions."
        
        return summary
    }
    
    private func processCurrentSessionBeforeSwitch() async {
        guard let session = session, !session.rawTranscriptions.isEmpty else { return }
        
        // Process the current session
        let processed = await processAmbientSession(session)
        
        // Save to existing thread
        await MainActor.run {
            let bookId = session.book?.localId
            let descriptor = FetchDescriptor<ChatThread>(
                predicate: bookId != nil ? #Predicate<ChatThread> { thread in
                    thread.bookId == bookId
                } : nil
            )
            
            if let existingThreads = try? modelContext.fetch(descriptor),
               let existingThread = existingThreads.first {
                // Add summary message to existing thread
                let summaryMessage = ThreadedChatMessage(
                    content: "🎙️ Ambient Session (\(processed.formattedDuration))\n\n" +
                            "Captured: \(processed.quotes.count) quotes, \(processed.notes.count) notes, \(processed.questions.count) questions",
                    isUser: false,
                    timestamp: Date()
                )
                existingThread.messages.append(summaryMessage)
                existingThread.capturedItems += processed.quotes.count + processed.notes.count + processed.questions.count
                existingThread.sessionDuration += session.duration
                existingThread.lastMessageDate = Date()
                
                try? modelContext.save()
            }
            
            // Clear current session transcriptions for new book
            self.session?.rawTranscriptions.removeAll()
        }
    }
}

// MARK: - Minimal Processing Overlay
struct ProcessingOverlay: View {
    let session: AmbientSession?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Processing your session...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}