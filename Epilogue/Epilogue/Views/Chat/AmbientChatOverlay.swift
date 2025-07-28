import SwiftUI
import SwiftData
import UIImageColors

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
                // Book-specific gradient when we have colors
                BookSpecificGradient(palette: palette, phase: phase, audioLevel: audioLevel, isListening: isListening)
            } else {
                // Default enhanced amber gradient with motion
                EnhancedAmberGradient(phase: phase, audioLevel: audioLevel, isListening: isListening)
            }
        }
        .onAppear {
            startWaveAnimation()
            if let book = book {
                Task {
                    await extractBookColors(book)
                }
            }
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
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            phase = 1
        }
    }
    
    private func extractBookColors(_ book: Book) async {
        guard let coverURL = book.coverImageURL else { return }
        
        let highQualityURL = coverURL
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "&zoom=5", with: "")
            .replacingOccurrences(of: "&zoom=4", with: "")
            .replacingOccurrences(of: "&zoom=3", with: "")
            .replacingOccurrences(of: "&zoom=2", with: "")
            .replacingOccurrences(of: "&zoom=1", with: "")
            .replacingOccurrences(of: "zoom=5", with: "")
            .replacingOccurrences(of: "zoom=4", with: "")
            .replacingOccurrences(of: "zoom=3", with: "")
            .replacingOccurrences(of: "zoom=2", with: "")
            .replacingOccurrences(of: "zoom=1", with: "")
        
        guard let url = URL(string: highQualityURL),
              let data = try? await URLSession.shared.data(from: url).0,
              let image = UIImage(data: data) else { return }
        
        print("🎨 AmbientChat: Extracting colors for \(book.title)")
        
        // Use improved color extraction with OKLAB as primary
        if let palette = await ImprovedColorExtraction.extractColors(from: image, bookTitle: book.title) {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.colorPalette = palette
                    print("✅ AmbientChat: Color extraction successful")
                }
            }
        } else {
            print("❌ AmbientChat: Color extraction failed for \(book.title)")
        }
    }
}

// Enhanced amber gradient - simple mirrored version
struct EnhancedAmberGradient: View {
    let phase: CGFloat
    let audioLevel: Float
    let isListening: Bool
    
    var body: some View {
        ZStack {
            // Base black layer
            Color.black
                .ignoresSafeArea()
            
            // Top gradient
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.0, green: 0.35, blue: 0.1), location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.55, blue: 0.26), location: 0.15),
                    .init(color: Color(red: 1.0, green: 0.7, blue: 0.4).opacity(0.5), location: 0.3),
                    .init(color: Color.clear, location: 0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .blur(radius: 40)
            .scaleEffect(y: 0.6 + phase * 0.2)
            .offset(y: -100 + phase * 30)
            
            // Bottom gradient (mirrored)
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.0, green: 0.35, blue: 0.1), location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.55, blue: 0.26), location: 0.15),
                    .init(color: Color(red: 1.0, green: 0.7, blue: 0.4).opacity(0.5), location: 0.3),
                    .init(color: Color.clear, location: 0.6)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
            .blur(radius: 40)
            .scaleEffect(y: 0.6 + phase * 0.2)
            .offset(y: 100 - phase * 30)
        }
    }
}

// Book-specific gradient using the rebuilt system
struct BookSpecificGradient: View {
    let palette: ColorPalette
    let phase: CGFloat
    let audioLevel: Float
    let isListening: Bool
    
    var body: some View {
        // Use the exact same gradient as BookDetailView
        BookCoverBackgroundView(colorPalette: palette)
            // Add animation by scaling and moving the entire gradient
            .scaleEffect(y: 0.8 + phase * 0.1)
            .offset(y: -50 + phase * 20)
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
    @State private var audioLevel: Float = 0
    @State private var isRecording = false
    @State private var showProcessingView = false
    @State private var showingSummary = false
    @State private var processedSession: ProcessedAmbientSession?
    @State private var showingBookPicker = false
    @Environment(\.modelContext) private var modelContext
    @State private var detectedPatterns: [PatternMatch] = []
    @State private var showPatternVisualizer = false
    @StateObject private var autoStopManager = AutoStopManager.shared
    @State private var showAutoStopWarning = false
    
    var body: some View {
        ZStack {
            // Claude-inspired gradient background
            ClaudeInspiredGradient(
                book: selectedBook,
                audioLevel: $audioLevel,
                isListening: $isRecording
            )
            
            VStack {
                // Minimal header with close button only
                HStack {
                    Spacer()
                    
                    Button {
                        // Simple direct close without processing
                        voiceManager.stopListening()
                        autoStopManager.stopMonitoring()
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
                } else if let book = selectedBook {
                    // Show book cover instead of listening indicator
                    VStack(spacing: 16) {
                        if let coverURL = book.coverImageURL {
                            SharedBookCoverView(coverURL: coverURL, width: 80, height: 112)
                                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        } else {
                            // Fallback if no cover
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 80, height: 112)
                                .overlay(
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white.opacity(0.3))
                                )
                        }
                        
                        // Small listening indicator below book
                        if voiceManager.isListening {
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .symbolEffect(.variableColor.iterative, options: .repeating)
                                
                                // Show pattern indicator if detected
                                if let latestPattern = detectedPatterns.last {
                                    Text(latestPattern.pattern.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color(hexString: latestPattern.pattern.color))
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
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
            
            // Pattern visualizer overlay
            if showPatternVisualizer && !detectedPatterns.isEmpty {
                CognitivePatternVisualizer(patterns: detectedPatterns)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Auto-stop warning
            if showAutoStopWarning {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                AutoStopWarningView(
                    timeRemaining: autoStopManager.timeRemaining,
                    onDismiss: {
                        stopSession()
                    },
                    onExtend: {
                        autoStopManager.maxDuration += 300 // Add 5 minutes
                        showAutoStopWarning = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
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
                
                // Detect cognitive patterns in real-time
                let patterns = CognitivePatternRecognizer.shared.recognizePatterns(in: newValue)
                if !patterns.isEmpty {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        detectedPatterns.append(contentsOf: patterns)
                        showPatternVisualizer = true
                    }
                    
                    // Hide visualizer after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation {
                            showPatternVisualizer = false
                        }
                    }
                }
                
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
        .onReceive(NotificationCenter.default.publisher(for: .autoStopTriggered)) { notification in
            if let reason = notification.object as? String {
                print("[AmbientChat] Auto-stop triggered: \(reason)")
                stopSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoStopWarning)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showAutoStopWarning = true
            }
        }
        .onChange(of: voiceManager.currentAmplitude) { _, amplitude in
            // Reset silence timer when voice detected
            if amplitude > 0.01 {
                autoStopManager.resetSilenceTimer()
            }
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
        isRecording = true
        
        // Start auto-stop monitoring
        autoStopManager.startMonitoring()
        
        // Haptic feedback
        HapticManager.shared.mediumTap()
    }
    
    private func stopSession() {
        // Stop listening
        voiceManager.stopListening()
        isRecording = false
        
        // Stop auto-stop monitoring
        autoStopManager.stopMonitoring()
        
        // Mark session end time
        session?.endTime = Date()
        
        // Haptic feedback
        HapticManager.shared.success()
        
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
        
        // Analyze cognitive patterns
        let cognitiveAnalysis = CognitivePatternRecognizer.shared.analyzeSessionPatterns(session.rawTranscriptions)
        
        // Process each transcription segment with cognitive pattern recognition
        for (index, transcription) in session.rawTranscriptions.enumerated() {
            let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            print("[AmbientChat] Processing segment \(index): \(trimmed)")
            
            // Get cognitive patterns for this segment
            let patterns = CognitivePatternRecognizer.shared.recognizePatterns(in: trimmed)
            let primaryPattern = patterns.first?.pattern
            
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
                // Determine note type based on cognitive pattern
                let noteType: ExtractedNote.NoteType
                
                switch primaryPattern {
                case .connecting:
                    noteType = .connection
                case .analyzing, .synthesizing, .evaluating:
                    noteType = .insight
                case .reflecting, .creating, nil:
                    noteType = .reflection
                default:
                    // Use content-based detection as fallback
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
                }
                
                notes.append(ExtractedNote(
                    text: trimmed,
                    type: noteType,
                    timestamp: Date()
                ))
            }
        }
        
        print("[AmbientChat] Extracted: \(quotes.count) quotes, \(notes.count) notes, \(questions.count) questions")
        
        // Generate summary with cognitive analysis
        let summary = generateSessionSummary(session: session, quotes: quotes, notes: notes, questions: questions, cognitiveAnalysis: cognitiveAnalysis)
        
        return ProcessedAmbientSession(
            quotes: quotes,
            notes: notes,
            questions: questions,
            summary: summary,
            duration: session.duration
        )
    }
    
    private func generateSessionSummary(session: AmbientSession, quotes: [ExtractedQuote], notes: [ExtractedNote], questions: [ExtractedQuestion], cognitiveAnalysis: SessionCognitiveAnalysis) -> String {
        var summary = "Reading session"
        
        if let book = session.book {
            summary += " with \(book.title)"
        }
        
        summary += ". Captured \(quotes.count) quotes, \(notes.count) notes, and \(questions.count) questions. "
        summary += cognitiveAnalysis.summary
        
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