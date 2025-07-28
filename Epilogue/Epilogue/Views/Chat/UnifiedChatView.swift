import SwiftUI
import SwiftData

struct UnifiedChatView: View {
    @State private var currentBookContext: Book?
    @State private var messages: [UnifiedChatMessage] = []
    @State private var scrollProxy: ScrollViewProxy?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // Color extraction state - reuse from BookDetailView
    @State private var colorPalette: ColorPalette?
    @State private var coverImage: UIImage?
    
    // Input state
    @State private var messageText = ""
    @State private var showingCommandPalette = false
    @FocusState private var isInputFocused: Bool
    
    // Ambient/Whisper state
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var pipeline = AmbientIntelligencePipeline()
    @State private var isRecording = false
    @State private var audioLevel: Float = 0
    @State private var currentSession: AmbientSession?
    @State private var showingSummary = false
    @State private var liveTranscription: String = ""
    
    var body: some View {
        ZStack {
            // Gradient system with ambient recording support
            if isRecording {
                // Use the breathing gradient during recording
                ClaudeInspiredGradient(
                    book: currentBookContext,
                    audioLevel: $audioLevel,
                    isListening: $isRecording
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            } else if let book = currentBookContext {
                // Use the same BookAtmosphericGradientView with extracted colors
                BookAtmosphericGradientView(colorPalette: colorPalette ?? generatePlaceholderPalette(for: book))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .id(book.localId) // Force view recreation when book changes
            } else {
                // Use existing ambient gradient for empty state
                AmbientChatGradientView()
                    .ignoresSafeArea()
            }
            
            // Chat UI overlay
            VStack(spacing: 0) {
                // Book context indicator (like Perplexity's model selector)
                bookContextPill
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                // Messages area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                emptyStateView
                                    .padding(.top, 100)
                            } else {
                                ForEach(messages) { message in
                                    ChatMessageView(message: message, currentBookContext: currentBookContext)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Space for input area
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
                
                Spacer()
                
                // Live transcription preview during recording
                if isRecording && !liveTranscription.isEmpty {
                    LiveTranscriptionView(transcription: liveTranscription)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Chat input bar
                UnifiedChatInputBar(
                    messageText: $messageText,
                    showingCommandPalette: $showingCommandPalette,
                    isInputFocused: $isInputFocused,
                    currentBook: currentBookContext,
                    onSend: sendMessage,
                    isRecording: $isRecording,
                    onMicrophoneTap: handleMicrophoneTap
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onChange(of: currentBookContext) { oldBook, newBook in
            // Extract colors when book context changes
            if let book = newBook {
                Task {
                    await extractColorsForBook(book)
                }
            } else {
                colorPalette = nil
                coverImage = nil
            }
        }
        .overlay(alignment: .bottom) {
            if showingCommandPalette {
                ChatCommandPalette(
                    isPresented: $showingCommandPalette,
                    selectedBook: $currentBookContext,
                    commandText: $messageText
                )
                .environmentObject(libraryViewModel)
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // Above input bar
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingCommandPalette)
        .sheet(isPresented: $showingSummary) {
            // Show session complete overlay
            if let session = currentSession, let processed = session.processedData {
                SessionCompleteView(
                    session: processed,
                    onDismiss: {
                        showingSummary = false
                        // Add session summary as system message
                        addSessionSummaryMessage(processed)
                    }
                )
            }
        }
        .onReceive(voiceManager.$transcribedText) { text in
            // Update live transcription
            if isRecording && !text.isEmpty {
                liveTranscription = text
            }
        }
        .onReceive(voiceManager.$currentAmplitude) { level in
            // Update audio level for gradient animation
            audioLevel = level
        }
    }
    
    // MARK: - Book Context Pill
    
    private var bookContextPill: some View {
        HStack(spacing: 12) {
            if let book = currentBookContext {
                // Book context active
                HStack(spacing: 8) {
                    // Mini book cover
                    if let coverURL = book.coverImageURL {
                        SharedBookCoverView(
                            coverURL: coverURL,
                            width: 24,
                            height: 36
                        )
                        .cornerRadius(3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        
                        Text(book.author)
                            .font(.system(size: 11))
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentBookContext = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 350)
                .glassEffect(.regular) // Using .regular as specified
                .clipShape(Capsule())
            } else {
                // No book context - show selector
                Button {
                    showingCommandPalette = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 14))
                        
                        Text("Select a book")
                            .font(.system(size: 14, weight: .medium))
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular)
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: currentBookContext != nil ? "book.and.wrench" : "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text(currentBookContext != nil ? "Start a conversation about \(currentBookContext?.title ?? "")" : "Start a new conversation")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            if currentBookContext != nil {
                Text("Ask questions, explore themes, or discuss characters")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Message Handling
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Create user message
        let userMessage = UnifiedChatMessage(
            content: messageText,
            isUser: true,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        
        // Add to messages
        messages.append(userMessage)
        
        // Clear input
        messageText = ""
        
        // Scroll to bottom
        if let lastMessage = messages.last {
            withAnimation {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
        
        // TODO: Send to AI service and get response
    }
    
    // MARK: - Ambient Session Handling
    
    private func handleMicrophoneTap() {
        if isRecording {
            endAmbientSession()
        } else {
            startAmbientSession()
        }
    }
    
    private func startAmbientSession() {
        // Create new session
        currentSession = AmbientSession(
            startTime: Date(),
            book: currentBookContext
        )
        
        // Start listening
        voiceManager.startAmbientListening()
        isRecording = true
        liveTranscription = ""
        
        // Add temporary transcription message
        let transcriptionMessage = UnifiedChatMessage(
            content: "[Transcribing]",
            isUser: true,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        messages.append(transcriptionMessage)
        
        // Haptic feedback
        HapticManager.shared.mediumTap()
    }
    
    private func endAmbientSession() {
        guard var session = currentSession else { return }
        
        // Stop listening
        voiceManager.stopListening()
        isRecording = false
        
        // Update session with final transcription
        session.endTime = Date()
        session.rawTranscriptions = [liveTranscription]
        
        // Process through intent detection
        Task {
            // For now, create a mock processed session
            // TODO: Integrate with actual pipeline processing
            let processed = ProcessedAmbientSession(
                quotes: [],
                notes: [],
                questions: [],
                summary: "Session recorded for \(session.duration) seconds",
                duration: session.duration
            )
            session.processedData = processed
            currentSession = session
            
            // Show summary
            await MainActor.run {
                showingSummary = true
                
                // Remove temporary transcription message and add final
                if let lastIndex = messages.lastIndex(where: { $0.content == "[Transcribing]" }) {
                    messages[lastIndex] = UnifiedChatMessage(
                        content: liveTranscription,
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                }
                
                liveTranscription = ""
            }
        }
        
        HapticManager.shared.lightTap()
    }
    
    private func addSessionSummaryMessage(_ processed: ProcessedAmbientSession) {
        let summaryContent = """
        📝 Session Complete (\(processed.formattedDuration))
        
        **Quotes:** \(processed.quotes.count)
        **Notes:** \(processed.notes.count)  
        **Questions:** \(processed.questions.count)
        
        \(processed.summary)
        """
        
        let summaryMessage = UnifiedChatMessage(
            content: summaryContent,
            isUser: false,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        
        messages.append(summaryMessage)
        
        // Scroll to bottom
        if let lastMessage = messages.last {
            withAnimation {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Color Extraction (Reused from BookDetailView)
    
    private func extractColorsForBook(_ book: Book) async {
        // Check cache first
        let bookID = book.localId.uuidString
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            await MainActor.run {
                self.colorPalette = cachedPalette
            }
            return
        }
        
        // Extract colors if not cached
        guard let coverURLString = book.coverImageURL,
              let coverURL = URL(string: coverURLString) else {
            return
        }
        
        do {
            let (imageData, _) = try await URLSession.shared.data(from: coverURL)
            guard let uiImage = UIImage(data: imageData) else { return }
            
            self.coverImage = uiImage
            
            // Use the same extraction as BookDetailView
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: uiImage, imageSource: book.title)
            
            await MainActor.run {
                self.colorPalette = palette
            }
            
            // Cache the result
            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
            
        } catch {
            print("Failed to extract colors: \(error)")
        }
    }
    
    private func generatePlaceholderPalette(for book: Book) -> ColorPalette {
        // Same neutral placeholder as BookDetailView
        return ColorPalette(
            primary: Color(white: 0.3),
            secondary: Color(white: 0.25),
            accent: Color.warmAmber.opacity(0.3),
            background: Color(white: 0.1),
            textColor: .white,
            luminance: 0.3,
            isMonochromatic: true,
            extractionQuality: 0.1
        )
    }
}

// MARK: - Message Model

struct UnifiedChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let bookContext: Book?
}


// MARK: - Live Transcription View

struct LiveTranscriptionView: View {
    let transcription: String
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.red)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            
            Text(transcription)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.red.opacity(0.3), lineWidth: 1)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Session Complete View

struct SessionCompleteView: View {
    let session: ProcessedAmbientSession
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            SessionSummaryView(
                session: session,
                onDismiss: {
                    // Dismiss is handled by binding
                },
                onViewDetails: {
                    // TODO: Navigate to details view
                }
            )
                .navigationTitle("Session Complete")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Ambient Chat Gradient (Fallback)

struct AmbientChatGradientView: View {
    var body: some View {
        ZStack {
            Color.black
            
            // Subtle amber gradient for empty state
            LinearGradient(
                stops: [
                    .init(color: Color.warmAmber.opacity(0.15), location: 0.0),
                    .init(color: Color.warmAmber.opacity(0.08), location: 0.3),
                    .init(color: Color.clear, location: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Preview

#Preview {
    UnifiedChatView()
        .environmentObject(LibraryViewModel())
}