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
    @State private var liveTranscription: String = ""
    
    var body: some View {
        let _ = print("🎨 UnifiedChatView body called, currentBookContext: \(currentBookContext?.title ?? "none")")
        ZStack {
            // Gradient system with ambient recording support
            Group {
                if isRecording {
                    // Use the breathing gradient during recording
                    ClaudeInspiredGradient(
                        book: currentBookContext,
                        audioLevel: $audioLevel,
                        isListening: $isRecording
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                } else if let book = currentBookContext {
                    // Use the same BookAtmosphericGradientView with extracted colors
                    let palette = colorPalette ?? generatePlaceholderPalette(for: book)
                    BookAtmosphericGradientView(colorPalette: palette)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .id(book.localId) // Simplify ID to just book ID
                        .onAppear {
                            print("🎨 BookAtmosphericGradientView appeared for: \(book.title)")
                            print("🎨 Using palette: \(colorPalette != nil ? "extracted" : "placeholder")")
                            if let cp = colorPalette {
                                print("🎨 Primary: \(cp.primary)")
                                print("🎨 Secondary: \(cp.secondary)")
                                print("🎨 Accent: \(cp.accent)")
                            }
                        }
                } else {
                    // Use existing ambient gradient for empty state
                    AmbientChatGradientView()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: currentBookContext?.localId)
            .animation(.easeInOut(duration: 0.5), value: isRecording)
            
            // Chat UI overlay
            VStack(spacing: 0) {
                // Book context indicator with native dropdown menu
                Menu {
                    // Show user's books
                    ForEach(libraryViewModel.books) { book in
                        Button {
                            currentBookContext = book
                            HapticManager.shared.lightTap()
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(book.title)
                                        .font(.body)
                                    Text(book.author)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                // Small book cover if available
                                if let coverURL = book.coverImageURL,
                                   let url = URL(string: coverURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 30, height: 40)
                                            .cornerRadius(4)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 30, height: 40)
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 30, height: 40)
                                        .overlay {
                                            Image(systemName: "book.closed")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                }
                            }
                        }
                    }
                    
                    if !libraryViewModel.books.isEmpty {
                        Divider()
                    }
                    
                    // Clear selection option
                    Button {
                        currentBookContext = nil
                        HapticManager.shared.lightTap()
                    } label: {
                        Label("Clear Selection", systemImage: "xmark.circle")
                    }
                } label: {
                    BookContextPill(
                        book: currentBookContext,
                        onTap: {} // Empty since Menu handles the tap
                    )
                }
                .menuStyle(.automatic) // Use iOS default menu style
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
        .onAppear {
            // Extract colors for initial book context if present
            if let book = currentBookContext {
                print("🎨 onAppear: Found initial book context: \(book.title)")
                Task {
                    await extractColorsForBook(book)
                }
            }
        }
        // Remove animation modifiers from here since they're on the Group now
        .onChange(of: currentBookContext) { oldBook, newBook in
            print("📚 Book context changed from \(oldBook?.title ?? "none") to \(newBook?.title ?? "none")")
            print("📚 New book ID: \(newBook?.localId.uuidString ?? "none")")
            print("📚 Cover URL: \(newBook?.coverImageURL ?? "none")")
            
            // Extract colors when book context changes
            if let book = newBook {
                print("🎨 Extracting colors for: \(book.title)")
                // Don't clear palette immediately - let the transition handle it
                Task {
                    await extractColorsForBook(book)
                }
            } else {
                print("🎨 Clearing color palette")
                withAnimation(.easeInOut(duration: 0.5)) {
                    colorPalette = nil
                    coverImage = nil
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showingCommandPalette {
                // Tap outside backdrop
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingCommandPalette = false
                    }
                    .ignoresSafeArea()
                
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
        
        // Send to AI service and get response
        Task {
            // Placeholder for AI integration
            // Will be implemented when PerplexityService is configured
        }
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
            // Process the transcription to extract quotes, notes, and questions
            let processed = await processTranscription(liveTranscription)
            session.processedData = processed
            currentSession = session
            
            await MainActor.run {
                // Remove temporary transcription message
                if let lastIndex = messages.lastIndex(where: { $0.content == "[Transcribing]" }) {
                    messages.remove(at: lastIndex)
                }
                
                // Add extracted items as individual messages
                var addedCount = 0
                
                // Add quotes
                for quote in processed.quotes {
                    messages.append(UnifiedChatMessage(
                        content: "📖 \"\(quote.text)\"",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    ))
                    addedCount += 1
                }
                
                // Add notes
                for note in processed.notes {
                    messages.append(UnifiedChatMessage(
                        content: "📝 \(note.text)",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    ))
                    addedCount += 1
                }
                
                // Add questions
                for question in processed.questions {
                    messages.append(UnifiedChatMessage(
                        content: "❓ \(question.text)",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    ))
                    addedCount += 1
                }
                
                // Show confirmation toast or inline message
                if addedCount > 0 {
                    let summary = buildSessionSummary(processed)
                    messages.append(UnifiedChatMessage(
                        content: summary,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    ))
                } else if !liveTranscription.isEmpty {
                    // If no structured content was extracted, add the raw transcription
                    messages.append(UnifiedChatMessage(
                        content: liveTranscription,
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    ))
                }
                
                liveTranscription = ""
                
                // Scroll to bottom to show new messages
                if let lastMessage = messages.last {
                    withAnimation {
                        scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        
        HapticManager.shared.lightTap()
    }
    
    // MARK: - Transcription Processing
    
    private func processTranscription(_ transcription: String) async -> ProcessedAmbientSession {
        // Mock processing - in production, this would use NLP to extract quotes, notes, and questions
        var quotes: [ExtractedQuote] = []
        var notes: [ExtractedNote] = []
        var questions: [ExtractedQuestion] = []
        
        // Simple pattern matching for now
        let lines = transcription.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Detect quotes (lines with quotation marks)
            if trimmed.contains("\"") || trimmed.contains("\u{201C}") || trimmed.contains("\u{201D}") {
                let cleanedQuote = trimmed
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "\u{201C}", with: "")
                    .replacingOccurrences(of: "\u{201D}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedQuote.isEmpty {
                    quotes.append(ExtractedQuote(
                        text: cleanedQuote,
                        context: nil,
                        timestamp: Date()
                    ))
                }
            }
            // Detect questions (lines ending with ?)
            else if trimmed.hasSuffix("?") {
                questions.append(ExtractedQuestion(
                    text: trimmed,
                    context: nil,
                    timestamp: Date()
                ))
            }
            // Everything else is a note
            else {
                notes.append(ExtractedNote(
                    text: trimmed,
                    type: .reflection,
                    timestamp: Date()
                ))
            }
        }
        
        return ProcessedAmbientSession(
            quotes: quotes,
            notes: notes,
            questions: questions,
            summary: "",
            duration: currentSession?.duration ?? 0
        )
    }
    
    private func buildSessionSummary(_ processed: ProcessedAmbientSession) -> String {
        var parts: [String] = []
        
        if processed.quotes.count > 0 {
            parts.append("\(processed.quotes.count) quote\(processed.quotes.count == 1 ? "" : "s")")
        }
        if processed.notes.count > 0 {
            parts.append("\(processed.notes.count) note\(processed.notes.count == 1 ? "" : "s")")
        }
        if processed.questions.count > 0 {
            parts.append("\(processed.questions.count) question\(processed.questions.count == 1 ? "" : "s")")
        }
        
        if parts.isEmpty {
            return "✓ Session recorded"
        } else {
            return "✓ Added " + parts.joined(separator: " and ")
        }
    }
    
    // MARK: - Color Extraction (Reused from BookDetailView)
    
    private func extractColorsForBook(_ book: Book) async {
        // Check cache first
        let bookID = book.localId.uuidString
        print("🎨 Checking cache for book ID: \(bookID)")
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            print("🎨 Found cached palette for: \(book.title)")
            print("🎨 Cached colors - Primary: \(cachedPalette.primary), Secondary: \(cachedPalette.secondary)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.colorPalette = cachedPalette
                }
            }
            return
        }
        print("🎨 No cached palette found, will extract colors")
        
        // Extract colors if not cached
        guard let coverURLString = book.coverImageURL else {
            print("🎨 No cover URL for book: \(book.title)")
            return
        }
        
        // Convert HTTP to HTTPS for ATS compliance
        let secureURLString = coverURLString.replacingOccurrences(of: "http://", with: "https://")
        guard let coverURL = URL(string: secureURLString) else {
            print("🎨 Invalid cover URL for book: \(book.title)")
            return
        }
        
        print("🎨 Starting color extraction from: \(secureURLString)")
        
        do {
            let (imageData, _) = try await URLSession.shared.data(from: coverURL)
            guard let uiImage = UIImage(data: imageData) else { 
                print("🎨 Failed to create UIImage from data")
                return 
            }
            
            self.coverImage = uiImage
            
            // Use the same extraction as BookDetailView
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: uiImage, imageSource: book.title)
            
            print("🎨 Extracted new palette for: \(book.title)")
            print("🎨 Extracted colors - Primary: \(palette.primary), Secondary: \(palette.secondary), Accent: \(palette.accent)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.colorPalette = palette
                    print("🎨 Palette assigned to colorPalette state")
                }
            }
            
            // Cache the result
            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
            
        } catch {
            print("Failed to extract colors: \(error)")
        }
    }
    
    private func generatePlaceholderPalette(for book: Book) -> ColorPalette {
        // Use warm amber gradient as placeholder until colors are extracted
        return ColorPalette(
            primary: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8),     // Warm amber
            secondary: Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.6),   // Deeper orange
            accent: Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.5),    // Light amber
            background: Color(white: 0.1),
            textColor: .white,
            luminance: 0.3,
            isMonochromatic: false,
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


// MARK: - Ambient Chat Gradient (Fallback)

struct AmbientChatGradientView: View {
    var body: some View {
        ZStack {
            // Deep black base
            Color.black
            
            // Warm sunset glow gradient for empty state
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.25), location: 0.2),
                    .init(color: Color.warmAmber.opacity(0.15), location: 0.4),
                    .init(color: Color.orange.opacity(0.08), location: 0.6),
                    .init(color: Color.clear, location: 0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Additional radial glow for warmth
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 1.0, green: 0.6, blue: 0.3).opacity(0.3), location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.5, blue: 0.25).opacity(0.15), location: 0.3),
                    .init(color: Color.clear, location: 0.7)
                ]),
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    UnifiedChatView()
        .environmentObject(LibraryViewModel())
}