import SwiftUI
import SwiftData

struct UnifiedChatView: View {
    @State private var currentBookContext: Book?
    @State private var messages: [UnifiedChatMessage] = []
    @State private var scrollProxy: ScrollViewProxy?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // Filter messages for current context
    private var filteredMessages: [UnifiedChatMessage] {
        if let currentBook = currentBookContext {
            // Show only messages for this specific book
            return messages.filter { message in
                message.bookContext?.id == currentBook.id
            }
        } else {
            // Show only messages with NO book context (general chat)
            return messages.filter { message in
                message.bookContext == nil
            }
        }
    }
    
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
    
    // Adaptive UI color based on current palette
    private var adaptiveUIColor: Color {
        if let palette = colorPalette {
            return palette.adaptiveUIColor
        } else {
            // Default warm amber
            return Color(red: 1.0, green: 0.55, blue: 0.26)
        }
    }
    
    var body: some View {
        ZStack {
            // Gradient system with ambient recording support
            Group {
                if isRecording, let book = currentBookContext {
                    // Use the breathing gradient during recording with book context
                    ClaudeInspiredGradient(
                        book: currentBookContext,
                        colorPalette: colorPalette, // Pass existing palette
                        audioLevel: $audioLevel,
                        isListening: $isRecording,
                        voiceFrequency: voiceManager.voiceFrequency,
                        voiceIntensity: voiceManager.voiceIntensity,
                        voiceRhythm: voiceManager.voiceRhythm
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .id("recording-\(book.localId)")
                } else if isRecording {
                    // Recording without book context - use ambient gradient
                    ClaudeInspiredGradient(
                        book: nil,
                        colorPalette: nil,
                        audioLevel: $audioLevel,
                        isListening: $isRecording,
                        voiceFrequency: voiceManager.voiceFrequency,
                        voiceIntensity: voiceManager.voiceIntensity,
                        voiceRhythm: voiceManager.voiceRhythm
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .id("recording-ambient")
                } else if let book = currentBookContext {
                    // Use the same BookAtmosphericGradientView with extracted colors
                    let palette = colorPalette ?? generatePlaceholderPalette(for: book)
                    BookAtmosphericGradientView(colorPalette: palette, intensity: 0.85)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .id(book.localId) // Simplify ID to just book ID
                        .onAppear {
                            print("BookAtmosphericGradientView appeared for: \(book.title)")
                            print("Using palette: \(colorPalette != nil ? "extracted" : "placeholder")")
                            if let cp = colorPalette {
                                print("Primary: \(cp.primary)")
                                print("Secondary: \(cp.secondary)")
                                print("Accent: \(cp.accent)")
                            }
                        }
                } else {
                    // Use existing ambient gradient for empty state
                    AmbientChatGradientView()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: currentBookContext?.localId)
            .animation(.easeInOut(duration: 0.8), value: isRecording) // Slower transition for recording state
            
            // Messages area with proper safe area insets
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filteredMessages.isEmpty {
                            emptyStateView
                                .padding(.top, 100)
                        } else {
                            ForEach(filteredMessages) { message in
                                ChatMessageView(
                                    message: message,
                                    currentBookContext: currentBookContext,
                                    colorPalette: colorPalette
                                )
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16) // Top padding for content
                    .padding(.bottom, 16) // Bottom padding for content
                }
                .onAppear {
                    scrollProxy = proxy
                }
                // iOS 26 safe area blur for header
                .safeAreaInset(edge: .top) {
                    BookContextMenuView(
                        currentBook: $currentBookContext,
                        books: libraryViewModel.books
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                // iOS 26 safe area blur for footer
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        // Live transcription preview during recording
                        if isRecording && !liveTranscription.isEmpty {
                            LiveTranscriptionView(transcription: liveTranscription, adaptiveUIColor: adaptiveUIColor)
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
                            onMicrophoneTap: handleMicrophoneTap,
                            colorPalette: colorPalette
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .onAppear {
            // Extract colors for initial book context if present
            if let book = currentBookContext {
                print("onAppear: Found initial book context: \(book.title)")
                Task {
                    await extractColorsForBook(book)
                }
            }
        }
        // Remove animation modifiers from here since they're on the Group now
        .onChange(of: currentBookContext) { oldBook, newBook in
            print("Book context changed from \(oldBook?.title ?? "none") to \(newBook?.title ?? "none")")
            print("New book ID: \(newBook?.localId.uuidString ?? "none")")
            print("Cover URL: \(newBook?.coverImageURL ?? "none")")
            
            // Extract colors when book context changes
            if let book = newBook {
                print("Extracting colors for: \(book.title)")
                // Don't clear palette immediately - let the transition handle it
                Task {
                    await extractColorsForBook(book)
                }
            } else {
                print("Clearing color palette")
                withAnimation(.easeInOut(duration: 0.5)) {
                    colorPalette = nil
                    coverImage = nil
                }
            }
        }
        // Sync audio level from voice manager
        .onChange(of: voiceManager.currentAmplitude) { _, newAmplitude in
            audioLevel = newAmplitude
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
                .padding(.bottom, 120) // Above input bar with safe area
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
    
    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5:
            return "this late night"
        case 5..<12:
            return "this morning"
        case 12..<17:
            return "this afternoon"
        case 17..<21:
            return "this evening"
        default:
            return "tonight"
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // Use custom glass-msgs icon
            Image("glass-msgs")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .foregroundStyle(.white.opacity(0.3))
            
            Text("What are we reading \(timeBasedGreeting)?")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            
            if currentBookContext != nil {
                Text("Discussing \(currentBookContext?.title ?? "")")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                
                Text("Ask questions, explore themes, or share thoughts")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
            } else {
                Text("Select a book to start a focused conversation")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
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
        
        // Store message text before clearing
        let userInput = messageText
        
        // Clear input
        messageText = ""
        
        // Scroll to bottom - use the actual message we just added
        withAnimation {
            scrollProxy?.scrollTo(userMessage.id, anchor: .bottom)
        }
        
        // Send to AI service and get response
        Task {
            await getAIResponse(for: userInput)
        }
    }
    
    private func getAIResponse(for userInput: String) async {
        // Use AICompanionService for flexibility between providers
        let aiService = AICompanionService.shared
        
        // Check if service is configured
        guard aiService.isConfigured() else {
            await MainActor.run {
                let configMessage = UnifiedChatMessage(
                    content: "Please configure your AI service. Add your Perplexity API key to Info.plist.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                messages.append(configMessage)
            }
            return
        }
        
        do {
            // Get response from AI with conversation context
            let response = try await aiService.processMessage(
                userInput,
                bookContext: currentBookContext,
                conversationHistory: filteredMessages  // Only this book's history
            )
            
            // Add AI response to messages
            await MainActor.run {
                let aiMessage = UnifiedChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                messages.append(aiMessage)
                
                // Scroll to bottom to show new message
                withAnimation {
                    scrollProxy?.scrollTo(aiMessage.id, anchor: .bottom)
                }
            }
        } catch {
            // Handle error by showing error message
            await MainActor.run {
                let errorMessage = UnifiedChatMessage(
                    content: "Sorry, I couldn't process your message. \(error.localizedDescription)",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                messages.append(errorMessage)
                
                // Log error for debugging
                print("Chat AI Error: \(error)")
            }
        }
    }
    
    // MARK: - Ambient Session Handling
    
    private func handleMicrophoneTap() {
        print("🎤 Microphone button tapped. Current isRecording: \(isRecording)")
        if isRecording {
            print("🛑 Stopping ambient session...")
            endAmbientSession()
        } else {
            print("▶️ Starting ambient session...")
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
        
        // Ensure UI state updates on main thread
        Task { @MainActor in
            print("▶️ Setting isRecording to true")
            isRecording = true
            liveTranscription = ""
        }
        
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
        
        // Ensure UI state updates on main thread
        Task { @MainActor in
            print("🛑 Setting isRecording to false")
            isRecording = false
        }
        
        // Update session with final transcription
        session.endTime = Date()
        session.rawTranscriptions = [liveTranscription]
        
        // Process through intent detection
        Task {
            print("Starting ambient session processing...")
            print("Raw transcription: \(liveTranscription)")
            
            // Process the transcription to extract quotes, notes, and questions
            let processed = await processTranscription(liveTranscription)
            session.processedData = processed
            currentSession = session
            
            print("Processing session with:")
            print("   - \(processed.quotes.count) quotes")
            print("   - \(processed.notes.count) notes")
            print("   - \(processed.questions.count) questions")
            
            // Remove temporary transcription message
            await MainActor.run {
                if let lastIndex = messages.lastIndex(where: { $0.content == "[Transcribing]" }) {
                    messages.remove(at: lastIndex)
                }
            }
            
            // Process quotes and notes first
            await MainActor.run {
                // Create BookModel from current book context if available
                let bookModel: BookModel? = if let book = currentBookContext {
                    BookModel(from: book)
                } else {
                    nil
                }
                
                // Add quotes
                for quote in processed.quotes {
                    // Create and save Quote to SwiftData
                    let quoteModel = CapturedQuote(
                        text: quote.text,
                        book: bookModel,
                        timestamp: quote.timestamp,
                        source: .ambient
                    )
                    
                    // Insert into SwiftData
                    modelContext.insert(quoteModel)
                    
                    // Add to messages with quote type
                    messages.append(UnifiedChatMessage(
                        content: "\"\(quote.text)\"",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .quote(quoteModel)
                    ))
                }
                
                // Add notes
                for note in processed.notes {
                    // Create and save Note to SwiftData
                    let noteModel = CapturedNote(
                        content: note.text,
                        book: bookModel,
                        timestamp: note.timestamp,
                        source: .ambient
                    )
                    
                    // Insert into SwiftData
                    modelContext.insert(noteModel)
                    
                    // Add to messages with note type
                    messages.append(UnifiedChatMessage(
                        content: note.text,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .note(noteModel)
                    ))
                }
                
                // Save the context after inserting all items
                do {
                    try modelContext.save()
                    print("Successfully saved \(processed.quotes.count) quotes and \(processed.notes.count) notes to SwiftData")
                } catch {
                    print("Failed to save to SwiftData: \(error)")
                }
            }
            
            // Process questions with AI responses
            print("\nQUESTION PROCESSING:")
            print("Processing \(processed.questions.count) questions from ambient session")
            
            for (index, question) in processed.questions.enumerated() {
                print("\nQuestion \(index + 1) of \(processed.questions.count): \(question.text)")
                
                // Add question to chat
                let questionMessage = UnifiedChatMessage(
                    content: question.text,
                    isUser: true,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                
                await MainActor.run {
                    messages.append(questionMessage)
                    print("Added question to chat messages")
                }
                
                // Get AI response immediately
                do {
                    let aiService = AICompanionService.shared
                    print("Getting AI response...")
                    print("   - Service configured: \(aiService.isConfigured())")
                    print("   - Book context: \(currentBookContext?.title ?? "None")")
                    
                    // Only pass filtered history for this book
                    let bookHistory = await MainActor.run {
                        if let bookId = currentBookContext?.id {
                            return messages.filter { $0.bookContext?.id == bookId }
                        } else {
                            return messages.filter { $0.bookContext == nil }
                        }
                    }
                    
                    print("   - History messages: \(bookHistory.count)")
                    
                    let answer = try await aiService.processMessage(
                        question.text,
                        bookContext: currentBookContext,
                        conversationHistory: bookHistory
                    )
                    
                    print("AI Response received:")
                    print("   - Length: \(answer.count) characters")
                    print("   - Preview: \(answer.prefix(100))...")
                    
                    // Add AI response
                    let answerMessage = UnifiedChatMessage(
                        content: answer,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    
                    await MainActor.run {
                        messages.append(answerMessage)
                        print("Added AI response to chat messages")
                    }
                    
                } catch {
                    print("AI Error Details:")
                    print("   - Error type: \(type(of: error))")
                    print("   - Error description: \(error)")
                    print("   - Localized: \(error.localizedDescription)")
                    
                    // Add detailed error message
                    let errorMessage = UnifiedChatMessage(
                        content: "I couldn't answer that question. Error: \(error.localizedDescription)",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    await MainActor.run {
                        messages.append(errorMessage)
                        print("Added error message to chat")
                    }
                }
            }
            
            // Final summary and cleanup
            await MainActor.run {
                let totalItems = processed.quotes.count + processed.notes.count + processed.questions.count
                
                if totalItems > 0 {
                    let summary = buildSessionSummary(processed)
                    messages.append(UnifiedChatMessage(
                        content: summary,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .system
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
        print("\nTRANSCRIPTION PROCESSING:")
        print("Raw text: \(transcription)")
        
        var quotes: [ExtractedQuote] = []
        var notes: [ExtractedNote] = []
        var questions: [ExtractedQuestion] = []
        
        // Split by sentences first, then by newlines if needed
        let sentences = transcription
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: "! ", with: "!\n")
            .components(separatedBy: .newlines)
        
        print("Split into \(sentences.count) sentences")
        
        for (index, sentence) in sentences.enumerated() {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            print("\nSentence \(index + 1): \(trimmed)")
            let lowercased = trimmed.lowercased()
            
            // Improved QUOTE detection
            var isQuote = false
            
            // Check for explicit quote indicators FIRST
            if lowercased.starts(with: "quote:") ||
               lowercased.contains("save this quote") ||
               lowercased.contains("i want to quote") ||
               lowercased.contains("remember this quote") ||
               lowercased.contains("here's a quote") ||
               lowercased.contains("the book says") ||
               lowercased.contains("the author says") ||
               lowercased.contains("it says") ||
               lowercased.contains("she says") ||
               lowercased.contains("he says") ||
               lowercased.contains("they say") {
                print("   Detected as QUOTE (by keyword)")
                isQuote = true
                
                // Extract the actual quote text
                var quoteText = trimmed
                
                // Remove the quote indicator prefix if present
                if lowercased.starts(with: "quote:") {
                    quoteText = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                }
                
                // Clean quotation marks if present
                quoteText = quoteText
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "\u{201C}", with: "")
                    .replacingOccurrences(of: "\u{201D}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !quoteText.isEmpty {
                    quotes.append(ExtractedQuote(
                        text: quoteText,
                        context: nil,
                        timestamp: Date()
                    ))
                }
            }
            // Check for quotation marks (but only if not already marked as quote)
            else if trimmed.contains("\"") || trimmed.contains("\u{201C}") || trimmed.contains("\u{201D}") {
                // Only treat as quote if it has substantial quoted content
                let quotedContent = extractQuotedContent(from: trimmed)
                if !quotedContent.isEmpty && quotedContent.count > 10 { // At least 10 chars
                    print("   Detected as QUOTE (by quotation marks)")
                    isQuote = true
                    quotes.append(ExtractedQuote(
                        text: quotedContent,
                        context: nil,
                        timestamp: Date()
                    ))
                }
            }
            
            // Improved QUESTION detection
            var isQuestion = false
            if !isQuote && (trimmed.hasSuffix("?") ||
                lowercased.starts(with: "why ") ||
                lowercased.starts(with: "how ") ||
                lowercased.starts(with: "what ") ||
                lowercased.starts(with: "when ") ||
                lowercased.starts(with: "where ") ||
                lowercased.starts(with: "who ") ||
                lowercased.starts(with: "which ") ||
                lowercased.starts(with: "can you") ||
                lowercased.starts(with: "could you") ||
                lowercased.starts(with: "would you") ||
                lowercased.starts(with: "should ") ||
                lowercased.starts(with: "is this") ||
                lowercased.starts(with: "are these") ||
                lowercased.starts(with: "do you") ||
                lowercased.starts(with: "does this") ||
                lowercased.contains("i wonder") ||
                lowercased.contains("i'm curious") ||
                lowercased.contains("what does this mean") ||
                lowercased.contains("what does that mean") ||
                lowercased.contains("can you explain") ||
                lowercased.contains("could you explain") ||
                lowercased.contains("please explain") ||
                lowercased.contains("tell me about") ||
                lowercased.contains("tell me more")) {
                print("   Detected as QUESTION")
                isQuestion = true
                questions.append(ExtractedQuestion(
                    text: trimmed,
                    context: nil,
                    timestamp: Date()
                ))
            }
            
            // Improved NOTE detection
            if !isQuote && !isQuestion {
                // Check for explicit note indicators
                var noteType: ExtractedNote.NoteType = .reflection
                
                if lowercased.starts(with: "note:") ||
                   lowercased.starts(with: "i think") ||
                   lowercased.starts(with: "i feel") ||
                   lowercased.starts(with: "i believe") ||
                   lowercased.starts(with: "my thought") ||
                   lowercased.starts(with: "my opinion") ||
                   lowercased.contains("reminds me of") ||
                   lowercased.contains("this makes me think") {
                    noteType = .reflection
                } else if lowercased.contains("similar to") ||
                          lowercased.contains("connects to") ||
                          lowercased.contains("relates to") ||
                          lowercased.contains("like when") {
                    noteType = .connection
                } else if lowercased.contains("i realize") ||
                          lowercased.contains("i understand") ||
                          lowercased.contains("this shows") ||
                          lowercased.contains("this means") ||
                          lowercased.contains("insight") {
                    noteType = .insight
                }
                
                print("   Detected as NOTE (type: \(noteType))")
                
                // Remove "Note:" prefix if present
                var noteText = trimmed
                if lowercased.starts(with: "note:") {
                    noteText = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                }
                
                notes.append(ExtractedNote(
                    text: noteText,
                    type: noteType,
                    timestamp: Date()
                ))
            }
        }
        
        print("\nPROCESSING SUMMARY:")
        print("   - Quotes: \(quotes.count)")
        print("   - Notes: \(notes.count)")
        print("   - Questions: \(questions.count)")
        
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
            return "Session recorded"
        } else {
            return "Added " + parts.joined(separator: " and ")
        }
    }
    
    // Helper function to extract quoted content from a string
    private func extractQuotedContent(from text: String) -> String {
        // Try to find content between quotation marks
        let patterns = [
            "\"([^\"]+)\"",      // Double quotes
            "\u{201C}([^\u{201D}]+)\u{201D}", // Smart quotes
            "'([^']+)'"         // Single quotes
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        
        // If no quotes found, return empty
        return ""
    }
    
    // MARK: - Color Extraction (Reused from BookDetailView)
    
    private func extractColorsForBook(_ book: Book) async {
        // Check cache first
        let bookID = book.localId.uuidString
        print("Checking cache for book ID: \(bookID)")
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            print("Found cached palette for: \(book.title)")
            print("Cached colors - Primary: \(cachedPalette.primary), Secondary: \(cachedPalette.secondary)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.colorPalette = cachedPalette
                }
            }
            return
        }
        print("No cached palette found, will extract colors")
        
        // Extract colors if not cached
        guard let coverURLString = book.coverImageURL else {
            print("No cover URL for book: \(book.title)")
            return
        }
        
        // Convert HTTP to HTTPS for ATS compliance
        let secureURLString = coverURLString.replacingOccurrences(of: "http://", with: "https://")
        guard let coverURL = URL(string: secureURLString) else {
            print("Invalid cover URL for book: \(book.title)")
            return
        }
        
        print("Starting color extraction from: \(secureURLString)")
        
        do {
            let (imageData, _) = try await URLSession.shared.data(from: coverURL)
            guard let uiImage = UIImage(data: imageData) else { 
                print("Failed to create UIImage from data")
                return 
            }
            
            self.coverImage = uiImage
            
            // Use the same extraction as BookDetailView
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: uiImage, imageSource: book.title)
            
            print("Extracted new palette for: \(book.title)")
            print("Extracted colors - Primary: \(palette.primary), Secondary: \(palette.secondary), Accent: \(palette.accent)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.colorPalette = palette
                    print("Palette assigned to colorPalette state")
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
    let messageType: MessageType
    
    enum Role {
        case user
        case assistant
    }
    
    enum MessageType {
        case text
        case note(CapturedNote)
        case quote(CapturedQuote)
        case system
        case contextSwitch
        case transcribing
    }
    
    init(content: String, isUser: Bool, timestamp: Date = Date(), bookContext: Book? = nil, messageType: MessageType = .text) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.bookContext = bookContext
        self.messageType = messageType
    }
}


// MARK: - Live Transcription View

struct LiveTranscriptionView: View {
    let transcription: String
    let adaptiveUIColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Listening indicator (no controls)
            ZStack {
                // Static subtle glow behind icon
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                adaptiveUIColor.opacity(0.2),
                                adaptiveUIColor.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 36, height: 36)
                    .blur(radius: 6)
                
                // Simple waveform indicator (no animation, just shows we're listening)
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(adaptiveUIColor)
            }
            .frame(width: 36, height: 36)
            
            // Transcription text with elegant styling
            Text(transcription)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 24))
        .overlay {
            // Refined border with gradient
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
    }
}


// MARK: - Ambient Chat Gradient (Fallback)

struct AmbientChatGradientView: View {
    var body: some View {
        ZStack {
            // Deep black base
            Color.black
            
            // Warm sunset glow gradient for empty state - top only
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.25), location: 0.15),
                    .init(color: Color.warmAmber.opacity(0.15), location: 0.3),
                    .init(color: Color.clear, location: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
        }
        .ignoresSafeArea()
    }
}

// MARK: - Book Context Menu View

struct BookContextMenuView: View {
    @Binding var currentBook: Book?
    let books: [Book]
    @State private var hasPreCached = false
    
    var body: some View {
        Menu {
            Section {
                // Show user's books with lazy loading
                ForEach(Array(books.prefix(20))) { book in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        currentBook = book
                    }
                    HapticManager.shared.lightTap()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(.body)
                            Text(book.author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        // Use lower quality URL for menu thumbnails
                        let thumbnailURL = book.coverImageURL?.replacingOccurrences(of: "&zoom=5", with: "")
                            .replacingOccurrences(of: "&zoom=4", with: "")
                            .replacingOccurrences(of: "&zoom=3", with: "")
                            .replacingOccurrences(of: "&zoom=2", with: "")
                        
                        AsyncImage(url: URL(string: thumbnailURL ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 30, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            case .failure(_), .empty:
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 30, height: 40)
                            @unknown default:
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 30, height: 40)
                            }
                        }
                        .id(book.id) // Help SwiftUI cache the image
                    }
                }
                } // Close ForEach
            }
            
            if !books.isEmpty {
                Divider()
            }
            
            Button {
                currentBook = nil
                HapticManager.shared.lightTap()
            } label: {
                Label("Clear Selection", systemImage: "xmark.circle")
            }
        } label: {
            BookContextPill(
                book: currentBook,
                onTap: {}
            )
        }
        .menuStyle(.automatic) // Use native iOS menu style
        .preferredColorScheme(.dark) // Prefer dark mode for menu
    }
}

// MARK: - Simplified Components Without Glass Effects

struct SimplifiedBookContextPill: View {
    let book: Book?
    let onBookSelected: (Book) -> Void
    let onClearSelection: () -> Void
    let libraryViewModel: LibraryViewModel
    
    var body: some View {
        Menu {
            // Show user's books
            ForEach(libraryViewModel.books) { book in
                Button {
                    onBookSelected(book)
                    HapticManager.shared.lightTap()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(.body)
                            Text(book.author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        SharedBookCoverView(
                            coverURL: book.coverImageURL,
                            width: 30,
                            height: 40
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            
            if !libraryViewModel.books.isEmpty {
                Divider()
            }
            
            Button {
                onClearSelection()
                HapticManager.shared.lightTap()
            } label: {
                Label("Clear Selection", systemImage: "xmark.circle")
            }
        } label: {
            // Use original BookContextPill but without glass effect
            BookContextPillContent(book: book)
        }
    }
}

struct BookContextPillContent: View {
    let book: Book?
    
    private var readingProgress: Double? {
        if let book = book, 
           let pageCount = book.pageCount, 
           pageCount > 0,
           book.currentPage > 0 {
            return Double(book.currentPage) / Double(pageCount)
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let book = book {
                // Mini book cover
                if let coverURL = book.coverImageURL {
                    AsyncImage(url: URL(string: coverURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 16, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        case .failure(_), .empty:
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.1))
                                .frame(width: 16, height: 24)
                                .overlay {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                        @unknown default:
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.1))
                                .frame(width: 16, height: 24)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.1))
                        .frame(width: 16, height: 24)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                }
                
                // Book info
                VStack(alignment: .leading, spacing: 1) {
                    Text(book.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    HStack(spacing: 4) {
                        Text(book.author)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        // Reading progress indicator
                        if let progress = readingProgress {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                            
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: 200, alignment: .leading)
            } else {
                Image(systemName: "books.vertical")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Select a book")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Chevron indicator
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}

struct SimplifiedUnifiedChatInputBar: View {
    @Binding var messageText: String
    @Binding var showingCommandPalette: Bool
    @FocusState.Binding var isInputFocused: Bool
    let currentBook: Book?
    let onSend: () -> Void
    @Binding var isRecording: Bool
    let onMicrophoneTap: () -> Void
    
    private var placeholderText: String {
        if let book = currentBook {
            return "Ask about \(book.title)..."
        } else {
            return "Ask about your books..."
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Library navigation button
            Button {
                NotificationCenter.default.post(name: Notification.Name("NavigateToTab"), object: 0)
                HapticManager.shared.lightTap()
            } label: {
                // Use custom icon if available
                if let _ = UIImage(named: "glass-book-open") {
                    Image("glass-book-open")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 44, height: 44)
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
            
            // Main input bar
            HStack(spacing: 0) {
                // Command icon
                Image(systemName: "command")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .onTapGesture {
                        showingCommandPalette = true
                    }
                
                // Text input
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        Text(placeholderText)
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 16))
                    }
                    
                    TextField("", text: $messageText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            if !messageText.isEmpty {
                                onSend()
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                
                // Action buttons
                HStack(spacing: 8) {
                    // Waveform/Stop button
                    Button {
                        onMicrophoneTap()
                    } label: {
                        if isRecording {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        } else {
                            Image(systemName: "waveform")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Send button
                    if !messageText.isEmpty {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white, Color(red: 1.0, green: 0.55, blue: 0.26))
                        }
                        .buttonStyle(.plain)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .padding(.trailing, 12)
            }
            .frame(minHeight: 36)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3),
                                Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: messageText.isEmpty)
    }
}

// MARK: - Preview

#Preview {
    UnifiedChatView()
        .environmentObject(LibraryViewModel())
}