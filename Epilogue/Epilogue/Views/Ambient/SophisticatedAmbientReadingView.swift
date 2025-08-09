import SwiftUI
import SwiftData
import AVFoundation
import Combine

// MARK: - Display States
enum AmbientDisplayState {
    case listening
    case thinking
    case responding
    case complete
    
    var gradientIntensity: Double {
        switch self {
        case .listening:
            return 0.9
        case .thinking:
            return 0.7
        case .responding:
            return 1.0
        case .complete:
            return 0.85
        }
    }
    
    var description: String {
        switch self {
        case .listening:
            return "Listening..."
        case .thinking:
            return "Thinking..."
        case .responding:
            return "Speaking..."
        case .complete:
            return "Complete"
        }
    }
}

// MARK: - Main Sophisticated Ambient Reading View
struct SophisticatedAmbientReadingView: View {
    // Core services
    @StateObject private var processor = SingleSourceProcessor.shared
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var libraryViewModel = LibraryViewModel()
    @Namespace private var animationNamespace
    
    // Display state
    @State private var displayState: AmbientDisplayState = .listening
    @State private var isListening: Bool = true
    @State private var showSettings: Bool = false
    
    // Book and gradient
    @State private var selectedBook: Book?
    @State private var bookPalette: ColorPalette?
    @State private var gradientIntensity: Double = 0.9
    
    // Voice parameters for gradient
    @State private var voiceFrequency: Double = 0.0
    @State private var voiceRhythm: Double = 0.0
    @State private var speakingSpeed: Double = 150.0
    
    // UI state
    @State private var showBookSelector: Bool = false
    @State private var showCommandPalette: Bool = false
    @State private var lastProcessedText: String = ""
    
    // Transcript and entity detection
    @State private var currentTranscription: String = ""
    @State private var detectedEntities: [DetectedEntity] = []
    @State private var transcriptionConfidence: Float = 0.9
    @State private var isProcessing: Bool = false
    
    // Session tracking
    @State private var currentSession: OptimizedAmbientSession?
    @State private var sessionStartTime: Date?
    @State private var capturedContent: [SessionContent] = []
    @State private var showSessionSummary: Bool = false
    @State private var processedResults: [SingleSourceProcessor.ProcessingResult] = []
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Default palette for when no book is selected
    private var ambientDefaultPalette: ColorPalette {
        ColorPalette(
            primary: Color(red: 1.0, green: 0.55, blue: 0.26),
            secondary: Color(red: 0.8, green: 0.3, blue: 0.4),
            accent: Color(red: 0.6, green: 0.2, blue: 0.5),
            background: Color.black,
            textColor: Color.white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 1.0
        )
    }
    
    var body: some View {
        ZStack {
            // MARK: - Ambient Gradient Background
            ambientGradientBackground
            
            // MARK: - Main Content
            VStack(spacing: 0) {
                // Header with controls
                ambientHeader
                    .padding(.top, 60)
                
                Spacer()
                
                // Central content area
                if !processedResults.isEmpty {
                    processedContentDisplay
                        .padding(.horizontal, 24)
                } else if !currentTranscription.isEmpty || isProcessing {
                    transcriptDisplay
                        .padding(.horizontal, 24)
                } else {
                    listeningIndicator
                }
                
                Spacer()
                
                // Voice visualization
                voiceVisualization
                    .padding(.bottom, 100)
            }
            
            // MARK: - Overlays
            if showBookSelector {
                bookSelectorOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Command palette hint
            if !showCommandPalette {
                commandPaletteHint
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { startAmbientMode() }
        .onDisappear { stopAmbientMode() }
        .sheet(isPresented: $showCommandPalette) {
            LiquidCommandPalettePresentation(
                isPresented: $showCommandPalette,
                animationNamespace: animationNamespace,
                initialContent: nil,
                editingNote: nil,
                onUpdate: nil,
                bookContext: selectedBook
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showSessionSummary) {
            if let session = currentSession {
                AmbientSessionSummaryView(session: session)
                    .onDisappear { dismiss() }
            }
        }
        .onChange(of: displayState) { _, newState in
            updateGradientForState(newState)
        }
        .onReceive(voiceManager.$currentTranscription) { transcription in
            handleTranscription(transcription)
        }
        .onReceive(processor.$lastResult) { result in
            handleProcessingResult(result)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -50 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showCommandPalette = true
                        }
                    }
                }
        )
    }
    
    // MARK: - Ambient Gradient Background
    
    private var ambientGradientBackground: some View {
        BookAtmosphericGradientView(
            book: selectedBook,
            colorPalette: bookPalette ?? ambientDefaultPalette,
            intensity: gradientIntensity + Double(voiceManager.audioLevel) * 0.3,
            frequency: mapFrequency(voiceFrequency),
            rhythm: voiceRhythm,
            speakingSpeed: speakingSpeed
        )
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.8), value: bookPalette)
        .animation(.smooth(duration: 0.3), value: gradientIntensity)
        .animation(.smooth(duration: 0.1), value: voiceManager.audioLevel)
        .overlay(
            // Vignette effect
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.1 + voiceManager.audioLevel * 0.05)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - Header
    
    private var ambientHeader: some View {
        HStack(spacing: 16) {
            // Exit button - GLASS EFFECT
            Button {
                endAmbientSession()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .glassEffect(in: .circle)
            }
            
            Spacer()
            
            // Book selector - GLASS EFFECT
            Button {
                if selectedBook == nil {
                    showBookSelector = true
                } else {
                    showCommandPalette = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedBook == nil ? "books.vertical" : "book.closed.fill")
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                    
                    Text(selectedBook?.title ?? "Say 'I'm reading...' or tap to select")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .lineLimit(1)
                    
                    if selectedBook != nil {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(in: .capsule)
            }
            
            Spacer()
            
            // Commands button - GLASS EFFECT
            Button {
                showCommandPalette = true
            } label: {
                Image(systemName: "command")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .glassEffect(in: .circle)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Transcript Display
    
    private var transcriptDisplay: some View {
        ProgressiveTranscriptView(
            transcription: currentTranscription,
            detectedEntities: detectedEntities,
            confidence: transcriptionConfidence,
            isProcessing: isProcessing,
            fontSize: 18,
            lineSpacing: 6,
            adaptiveColor: bookPalette?.primary ?? ambientDefaultPalette.primary
        )
        .frame(maxHeight: 400)
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            (bookPalette?.primary ?? ambientDefaultPalette.primary).opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
    
    // MARK: - Processed Content Display
    
    private var processedContentDisplay: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(processedResults.suffix(5)) { result in
                    ProcessedContentCard(result: result)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                }
            }
        }
        .frame(maxHeight: 400)
    }
    
    // MARK: - Listening Indicator
    
    private var listeningIndicator: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            (bookPalette?.primary ?? ambientDefaultPalette.primary).opacity(0.8),
                            (bookPalette?.secondary ?? ambientDefaultPalette.secondary).opacity(0.6)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.5), value: isListening)
            
            Text(displayState.description)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(32)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
    
    // MARK: - Voice Visualization
    
    private var voiceVisualization: some View {
        ZStack {
            if isListening {
                // Animated waveform
                WaveformVisualization(
                    amplitude: voiceManager.currentAmplitude,
                    frequency: voiceFrequency,
                    color: bookPalette?.primary ?? ambientDefaultPalette.primary
                )
                .frame(height: 80)
                .padding(.horizontal, 40)
            }
            
            // Mic button
            Button {
                toggleListening()
            } label: {
                ZStack {
                    // Animated ring when listening
                    if isListening {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        (bookPalette?.primary ?? ambientDefaultPalette.primary).opacity(0.6),
                                        (bookPalette?.primary ?? ambientDefaultPalette.primary).opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 76, height: 76)
                            .scaleEffect(isListening ? 1.15 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                value: isListening
                            )
                    }
                    
                    Image(systemName: isListening ? "pause.fill" : "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, options: .repeating, value: isListening)
                        .frame(width: 64, height: 64)
                        .glassEffect(in: .circle)
                }
            }
            .scaleEffect(isListening ? 1.0 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isListening)
        }
    }
    
    // MARK: - Book Selector Overlay
    
    private var bookSelectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showBookSelector = false
                    }
                }
            
            VStack(spacing: 20) {
                Text("Select a Book")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 120))
                    ], spacing: 20) {
                        ForEach(libraryViewModel.books) { book in
                            BookCoverButton(book: book) {
                                selectBook(book)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showBookSelector = false
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
            .padding(30)
            .glassEffect(in: .rect(cornerRadius: 20))
            .padding(40)
        }
    }
    
    // MARK: - Command Palette Hint
    
    private var commandPaletteHint: some View {
        VStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "chevron.compact.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Commands")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.bottom, 16)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showCommandPalette = true
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func startAmbientMode() {
        isListening = true
        voiceManager.startAmbientListening()
        
        // Start session tracking
        sessionStartTime = Date()
        currentSession = OptimizedAmbientSession(
            startTime: sessionStartTime!,
            bookContext: selectedBook,
            metadata: SessionMetadata(
                wordCount: 0,
                readingSpeed: 150,
                engagementScore: 0.8,
                comprehensionScore: 0.8,
                mood: .excited,
                topics: [],
                difficulty: .medium,
                sessionType: .exploratory
            )
        )
        
        // Update voice parameters
        updateVoiceParameters()
    }
    
    private func stopAmbientMode() {
        isListening = false
        voiceManager.stopListening()
    }
    
    private func endAmbientSession() {
        HapticManager.shared.lightTap()
        stopAmbientMode()
        
        // End session and show summary if there was meaningful content
        if var session = currentSession {
            session.endTime = Date()
            session.allContent = capturedContent
            
            // Show summary if we captured any content
            if !capturedContent.isEmpty {
                currentSession = session
                showSessionSummary = true
            } else {
                dismiss()
            }
        } else {
            dismiss()
        }
    }
    
    private func toggleListening() {
        HapticManager.shared.lightTap()
        isListening.toggle()
        
        if isListening {
            voiceManager.startAmbientListening()
            withAnimation(.spring(response: 0.3)) {
                displayState = .listening
            }
        } else {
            voiceManager.stopListening()
            withAnimation(.spring(response: 0.3)) {
                displayState = .complete
            }
        }
    }
    
    private func selectBook(_ book: Book) {
        selectedBook = book
        HapticManager.shared.lightTap()
        
        Task {
            await extractColorsForBook(book)
        }
        
        // Update session with book context
        if let session = currentSession {
            currentSession = OptimizedAmbientSession(
                startTime: session.startTime,
                bookContext: book,
                metadata: session.metadata
            )
            currentSession?.allContent = session.allContent
            currentSession?.clusters = session.clusters
            currentSession?.rawTranscriptions = session.rawTranscriptions
        }
    }
    
    private func extractColorsForBook(_ book: Book) async {
        guard let coverURLString = book.coverImageURL,
              let coverURL = URL(string: coverURLString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: coverURL)
            if let image = UIImage(data: data) {
                let extractor = OKLABColorExtractor()
                let palette = try await extractor.extractPalette(from: image)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        self.bookPalette = palette
                    }
                }
            }
        } catch {
            print("Failed to extract colors: \(error)")
        }
    }
    
    private func handleTranscription(_ transcription: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentTranscription = transcription
        }
        
        // Detect book mentions
        detectBookFromSpeech(transcription)
    }
    
    private func handleProcessingResult(_ result: SingleSourceProcessor.ProcessingResult?) {
        guard let result = result else { return }
        
        // Update processing state
        isProcessing = processor.isProcessing
        
        // Add to processed results for display
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            processedResults.append(result)
            
            // Keep only recent results
            if processedResults.count > 10 {
                processedResults.removeFirst()
            }
        }
        
        // Create entity for highlighting
        let entity = DetectedEntity(
            text: result.content,
            type: mapProcessingResultToEntityType(result.type),
            confidence: Float(result.confidence),
            range: nil
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if !detectedEntities.contains(where: { $0.text == entity.text }) {
                detectedEntities.append(entity)
            }
        }
        
        // Add to session content
        let sessionContent = SessionContent(
            type: mapProcessingResultToContentType(result.type),
            text: result.content,
            timestamp: result.timestamp,
            confidence: Float(result.confidence),
            bookContext: selectedBook?.title,
            aiResponse: nil
        )
        capturedContent.append(sessionContent)
    }
    
    private func detectBookFromSpeech(_ text: String) {
        let lowercased = text.lowercased()
        
        let patterns = [
            "i'm reading ",
            "i am reading ",
            "currently reading ",
            "reading ",
            "the book is ",
            "this book is "
        ]
        
        for pattern in patterns {
            if lowercased.contains(pattern) {
                if let range = lowercased.range(of: pattern) {
                    let afterPattern = String(text[range.upperBound...])
                    let potentialTitle = afterPattern
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: "'", with: "")
                    
                    let books = libraryViewModel.books
                    if let matchedBook = books.first(where: { 
                        $0.title.lowercased().contains(potentialTitle.lowercased()) ||
                        potentialTitle.lowercased().contains($0.title.lowercased())
                    }) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectBook(matchedBook)
                        }
                        HapticManager.shared.success()
                        break
                    }
                }
            }
        }
    }
    
    private func updateGradientForState(_ state: AmbientDisplayState) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            gradientIntensity = state.gradientIntensity
        }
    }
    
    private func updateVoiceParameters() {
        voiceFrequency = voiceManager.voiceFrequency
        voiceRhythm = voiceManager.voiceRhythm
        speakingSpeed = voiceManager.wordsPerMinute
    }
    
    private func mapFrequency(_ frequency: Double) -> Double {
        min(1.0, max(0.0, frequency / 1000.0))
    }
    
    private func mapProcessingResultToEntityType(_ contentType: Any) -> EntityType {
        let typeString = String(describing: contentType).lowercased()
        switch typeString {
        case "question": return .question
        case "quote": return .quote
        case "insight", "reflection", "connection": return .insight
        case "reaction", "note": return .note
        default: return .unknown
        }
    }
    
    private func mapProcessingResultToContentType(_ contentType: Any) -> SessionContent.ContentType {
        let typeString = String(describing: contentType).lowercased()
        switch typeString {
        case "question": return .question
        case "quote": return .quote
        case "insight": return .insight
        case "reflection": return .reflection
        case "connection": return .connection
        case "reaction": return .reaction
        default: return .insight
        }
    }
}

// MARK: - Processed Content Card

struct ProcessedContentCard: View {
    let result: SingleSourceProcessor.ProcessingResult
    
    private var icon: String {
        let typeString = String(describing: result.type).lowercased()
        switch typeString {
        case "question": return "questionmark.circle.fill"
        case "quote": return "quote.bubble.fill"
        case "insight": return "lightbulb.fill"
        case "reflection": return "brain.head.profile"
        case "note": return "note.text"
        default: return "sparkles"
        }
    }
    
    private var color: Color {
        let typeString = String(describing: result.type).lowercased()
        switch typeString {
        case "question": return .blue
        case "quote": return .green
        case "insight": return Color(red: 1.0, green: 0.55, blue: 0.26)
        case "reflection": return .purple
        case "note": return .pink
        default: return .white
        }
    }
    
    private var label: String {
        let typeString = String(describing: result.type)
        return typeString.capitalized
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .fill(color.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                
                Text(result.content)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                
                if let bookContext = result.bookContext {
                    Text(bookContext.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}

// MARK: - Book Cover Button

struct BookCoverButton: View {
    let book: Book
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let coverURL = book.coverImageURL {
                    AsyncImage(url: URL(string: coverURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Text(book.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Waveform Visualization

struct WaveformVisualization: View {
    let amplitude: Float
    let frequency: Double
    let color: Color
    
    @State private var phase: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                let wavelength = width / 5
                let amplitudeScale = Double(amplitude) * midHeight * 0.8
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, through: width, by: 2) {
                    let relativeX = x / wavelength
                    let sine = sin((relativeX + phase) * .pi * 2)
                    let y = midHeight + sine * amplitudeScale
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [color, color.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SophisticatedAmbientReadingView()
        .modelContainer(for: [CapturedNote.self, CapturedQuote.self])
}