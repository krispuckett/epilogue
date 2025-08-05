import SwiftUI
import SwiftData

struct UnifiedChatView: View {
    @State private var currentBookContext: Book?
    @State private var messages: [UnifiedChatMessage] = []
    @State private var scrollProxy: ScrollViewProxy?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @ObservedObject private var syncManager = NotesSyncManager.shared
    
    // Filter messages for current context
    private var filteredMessages: [UnifiedChatMessage] {
        let baseMessages: [UnifiedChatMessage]
        
        if let currentBook = currentBookContext {
            // Show only messages for this specific book
            baseMessages = messages.filter { message in
                message.bookContext?.id == currentBook.id
            }
        } else {
            // Show only messages with NO book context (general chat)
            baseMessages = messages.filter { message in
                message.bookContext == nil
            }
        }
        
        // Filter out messages that reference deleted notes
        return baseMessages.filter { message in
            !message.isDeleted()
        }
    }
    
    // Color extraction state - reuse from BookDetailView
    @State private var colorPalette: ColorPalette?
    @State private var coverImage: UIImage?
    
    // Input state
    @State private var messageText = ""
    @State private var showingCommandPalette = false
    @State private var showingBookStrip = false
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
            // 1. Gradient background (exactly like LibraryView)
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
            
            // 2. ScrollView as direct child of ZStack (exactly like LibraryView)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filteredMessages.isEmpty {
                            if showingBookStrip {
                                bookGridView
                                    .padding(.top, 40)
                            } else {
                                emptyStateView
                                    .padding(.top, 100)
                            }
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
                    .padding(.bottom, 100) // Extra bottom padding to account for tab bar
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }
            // Native navigation setup
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    // Live transcription preview during recording
                    if isRecording && !liveTranscription.isEmpty {
                        LiveTranscriptionView(
                            transcription: liveTranscription, 
                            adaptiveUIColor: adaptiveUIColor,
                            isTranscribing: isRecording,
                            onCancel: {
                                // Cancel the transcription
                                voiceManager.stopListening()
                                isRecording = false
                                liveTranscription = ""
                                
                                // Remove temporary transcription message
                                if let lastIndex = messages.lastIndex(where: { $0.content == "[Transcribing]" }) {
                                    messages.remove(at: lastIndex)
                                }
                                
                                HapticManager.shared.lightTap()
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Universal input bar (same design as Quick Actions)
                    UniversalInputBar(
                        messageText: $messageText,
                        showingCommandPalette: $showingCommandPalette,
                        isInputFocused: $isInputFocused,
                        context: .chat(book: currentBookContext),
                        onSend: sendMessage,
                        onMicrophoneTap: handleMicrophoneTap,
                        isRecording: $isRecording,
                        colorPalette: colorPalette
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: currentBookContext?.localId)
        .animation(.easeInOut(duration: 0.8), value: isRecording) // Slower transition for recording state
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
                .padding(.bottom, 80) // Above input bar with safe area
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.98, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .bottom).combined(with: .opacity)
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
        } // End of ZStack
        // Navigation setup with native blur
        .navigationTitle(currentBookContext?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingBookStrip.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Switch books")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        
                        Image(systemName: showingBookStrip ? "xmark.circle.fill" : "book.closed.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    }
                }
            }
        }
        .onChange(of: showingBookStrip) { _, _ in
            if showingBookStrip {
                // Dismiss keyboard if active
                isInputFocused = false
            }
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
                .foregroundStyle(.white.opacity(0.6))
            
            Text("What are we reading \(timeBasedGreeting)?")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            if currentBookContext != nil {
                Text("Discussing \(currentBookContext?.title ?? "")")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                
                Text("Ask questions, explore themes, or share thoughts")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else {
                Text("Select a book to start a focused conversation")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Book Grid View
    
    private var bookGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 20) {
            // All Books button
            Button {
                currentBookContext = nil
                showingBookStrip = false
                HapticManager.shared.lightTap()
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .overlay {
                        if currentBookContext == nil {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 2)
                        }
                    }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Book items
            ForEach(libraryViewModel.books) { book in
                Button {
                    currentBookContext = book
                    showingBookStrip = false
                    HapticManager.shared.lightTap()
                } label: {
                    SharedBookCoverView(
                        coverURL: book.coverImageURL,
                        width: 90,
                        height: 135
                    )
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if currentBookContext?.id == book.id {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 2)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 125)
    }
    
    // MARK: - Message Handling
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Store message text before clearing
        let userInput = messageText
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create user message FIRST
        let userMessage = UnifiedChatMessage(
            content: messageText,
            isUser: true,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        
        // Add to messages
        messages.append(userMessage)
        
        // Use CommandParser to detect intent intelligently
        let intent = CommandParser.parse(trimmed, books: libraryViewModel.books, notes: [])
        var isProcessedAsNoteOrQuote = false
        
        switch intent {
        case .createQuote(let text):
            // Process as quote
            processQuoteFromKeyboard(text: text)
            isProcessedAsNoteOrQuote = true
            
        case .createNote(let text):
            // Process as note
            processNoteFromKeyboard(text: text)
            isProcessedAsNoteOrQuote = true
            
        default:
            // For other intents, just send as normal message
            break
        }
        
        // Clear input
        messageText = ""
        
        // Delay scroll slightly to ensure all messages are rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                // Scroll to the last message
                if let lastMessage = messages.last {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
        
        // Send to AI service and get response (only if not processed as note/quote)
        if !isProcessedAsNoteOrQuote {
            Task {
                await getAIResponse(for: userInput)
            }
        }
    }
    
    // MARK: - Keyboard Note/Quote Processing
    
    private func processNoteFromKeyboard(text: String) {
        // CommandParser already cleaned the text, just use it directly
        let noteText = text
        
        // Create BookModel if we have book context
        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            bookModel = BookModel(from: book)
            // Insert book model if not already in context
            modelContext.insert(bookModel!)
        }
        
        // Create and save the note
        let capturedNote = CapturedNote(
            content: noteText,
            book: bookModel,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual
        )
        
        modelContext.insert(capturedNote)
        
        // Save to SwiftData
        do {
            try modelContext.save()
            print("✅ Saved note from keyboard: \(noteText)")
            
            // Add system message to chat
            let systemMessage = UnifiedChatMessage(
                content: "📝 Note saved",
                isUser: false,
                timestamp: Date(),
                bookContext: currentBookContext,
                messageType: .system
            )
            messages.append(systemMessage)
            
            // Haptic feedback
            HapticManager.shared.success()
        } catch {
            print("❌ Failed to save note: \(error)")
        }
    }
    
    private func processQuoteFromKeyboard(text: String) {
        // Use CommandParser to parse the quote properly
        let (content, attribution) = CommandParser.parseQuote(text)
        
        var author: String? = nil
        var bookTitle: String? = nil
        var pageNumber: Int? = nil
        
        // Parse the attribution if present
        if let attr = attribution {
            let parts = attr.split(separator: "|||").map { String($0) }
            if parts.count >= 1 {
                author = parts[0]
            }
            if parts.count >= 3 && parts[1] == "BOOK" {
                bookTitle = parts[2]
            }
            if parts.count >= 5 && parts[3] == "PAGE" {
                if let pageStr = parts[4].split(separator: " ").last {
                    pageNumber = Int(pageStr)
                }
            }
        }
        
        // Create BookModel if we have book context
        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            bookModel = BookModel(from: book)
            // Insert book model if not already in context
            modelContext.insert(bookModel!)
            
            // If no author specified, use book author
            if author == nil {
                author = book.author
            }
        }
        
        // Create and save the quote
        let capturedQuote = CapturedQuote(
            text: content,
            book: bookModel,
            author: author,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual
        )
        
        modelContext.insert(capturedQuote)
        
        // Save to SwiftData
        do {
            try modelContext.save()
            print("✅ Saved quote from keyboard: \(content)")
            
            // Add system message to chat with mini quote card
            let systemMessage = UnifiedChatMessage(
                content: "",
                isUser: false,
                timestamp: Date(),
                bookContext: currentBookContext,
                messageType: .quote(capturedQuote)
            )
            messages.append(systemMessage)
            
            // Haptic feedback
            HapticManager.shared.success()
        } catch {
            print("❌ Failed to save quote: \(error)")
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
                    
                    // Check if we should provide context for this reflection
                    if shouldProvideContext(for: note.text),
                       let context = generateContextualInfo(for: note.text, book: currentBookContext) {
                        // Add note with context
                        messages.append(UnifiedChatMessage(
                            content: note.text,
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext,
                            messageType: .noteWithContext(noteModel, context: context)
                        ))
                    } else {
                        // Add regular note
                        messages.append(UnifiedChatMessage(
                            content: note.text,
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext,
                            messageType: .note(noteModel)
                        ))
                    }
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
        
        // Process the entire transcription as one unit instead of splitting by sentences
        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            print("\nProcessing full transcription: \(trimmed)")
            let lowercased = trimmed.lowercased()
            
            // Improved QUOTE detection
            var isQuote = false
            
            // Reaction-based quote detection patterns FIRST
            let reactionPhrases = [
                "i love this quote", "this is beautiful", "i love this", "listen to this", 
                "oh wow", "this is amazing", "here's a great line",
                "check this out", "this part", "the author says",
                "this is incredible", "this is perfect", "yes exactly",
                "this speaks to me", "this is so good", "love this",
                "wow listen to this", "oh my god", "oh my gosh",
                "this is powerful", "this is profound", "this is brilliant"
            ]
            
            // Check for reaction phrase followed by more text (indicating a quote)
            var detectedReactionQuote = false
            for phrase in reactionPhrases {
                if lowercased.contains(phrase) {
                    // Find where the phrase ends and extract everything after it
                    if let range = lowercased.range(of: phrase) {
                        let afterPhrase = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        
                        // Clean up common separators and filler words
                        var quoteText = afterPhrase
                        let separators = ["...", "…", "..", ".", ":", "-", "—", "–"]
                        for separator in separators {
                            if quoteText.starts(with: separator) {
                                quoteText = String(quoteText.dropFirst(separator.count)).trimmingCharacters(in: .whitespaces)
                                break
                            }
                        }
                        
                        // Clean quotation marks if present
                        quoteText = quoteText
                            .replacingOccurrences(of: "\"", with: "")
                            .replacingOccurrences(of: "\u{201C}", with: "")
                            .replacingOccurrences(of: "\u{201D}", with: "")
                            .replacingOccurrences(of: "'", with: "")
                            .replacingOccurrences(of: "'", with: "")
                            .replacingOccurrences(of: "'", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // If we have text after the reaction phrase, it's a quote
                        if !quoteText.isEmpty && quoteText.count > 5 {
                            print("   Detected as QUOTE (by reaction pattern: '\(phrase)')")
                            print("   Extracted quote: '\(quoteText)'")
                            quotes.append(ExtractedQuote(
                                text: quoteText,
                                context: "User reaction: \(phrase)",
                                timestamp: Date()
                            ))
                            detectedReactionQuote = true
                            isQuote = true
                            break
                        }
                    }
                }
            }
            
            // Check for explicit quote indicators (if not already detected by reaction)
            if !detectedReactionQuote && (lowercased.starts(with: "quote:") ||
               lowercased.contains("save this quote") ||
               lowercased.contains("i want to quote") ||
               lowercased.contains("remember this quote") ||
               lowercased.contains("here's a quote") ||
               lowercased.contains("the book says") ||
               lowercased.contains("it says") ||
               lowercased.contains("she says") ||
               lowercased.contains("he says") ||
               lowercased.contains("they say")) {
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
            
            // Check for REFLECTIONS first (these should become notes, not questions)
            var isReflection = false
            if !isQuote {
                let reflectionPatterns = [
                    "i love",
                    "i think",
                    "i feel",
                    "i believe",
                    "i wonder if",  // Rhetorical wondering, not a direct question
                    "i wonder about",
                    "i'm thinking",
                    "it's interesting that",
                    "this reminds me",
                    "this makes me think",
                    "i find it",
                    "reminds me of",
                    "makes me wonder",
                    "i appreciate",
                    "i notice",
                    "i'm struck by",
                    "it occurs to me",
                    "i'm reminded of",
                    "this connects to",
                    "i'm fascinated by"
                ]
                
                for pattern in reflectionPatterns {
                    if lowercased.contains(pattern) {
                        print("   Detected as REFLECTION/NOTE")
                        isReflection = true
                        break
                    }
                }
            }
            
            // Improved QUESTION detection (only if not a reflection)
            var isQuestion = false
            if !isQuote && !isReflection && (trimmed.hasSuffix("?") ||
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
            
            // NOTE detection (including reflections)
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
        }  // End of if !trimmed.isEmpty
        
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
    
    // MARK: - Smart Context Generation for Reflections
    
    private func shouldProvideContext(for thought: String) -> Bool {
        // Only provide context if the thought references something specific
        let contextTriggers = [
            "this", "that", "it", "the idea of", "concept", "theme",
            "character", "protagonist", "antagonist", "hero",
            "journey", "symbolism", "metaphor", "allegory",
            "monomyth", "archetype", "motif"
        ]
        
        let lowercased = thought.lowercased()
        return contextTriggers.contains { trigger in
            lowercased.contains(trigger)
        }
    }
    
    private func generateContextualInfo(for thought: String, book: Book?) -> String? {
        let lowercased = thought.lowercased()
        
        // Check for specific concepts mentioned
        if lowercased.contains("monomyth") || lowercased.contains("hero's journey") {
            return "The Hero's Journey: Joseph Campbell's narrative pattern found in myths worldwide"
        }
        
        if lowercased.contains("archetype") {
            return "Archetypes: Universal character types that appear across cultures and stories"
        }
        
        if lowercased.contains("ring") && book?.title.contains("Lord of the Rings") == true {
            return "The One Ring: Symbol of power and corruption in Tolkien's Middle-earth"
        }
        
        if lowercased.contains("green light") && book?.title.contains("Gatsby") == true {
            return "The green light: Symbol of hope and the American Dream in Fitzgerald's novel"
        }
        
        // More generic contextual hints based on keywords
        if lowercased.contains("symbolism") {
            return "Literary device where objects or actions represent ideas beyond their literal meaning"
        }
        
        if lowercased.contains("foreshadowing") {
            return "Literary technique: hints or clues about events that will occur later in the story"
        }
        
        // Return nil if no specific context is relevant
        return nil
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
        case noteWithContext(CapturedNote, context: String)
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
    var isTranscribing: Bool = true
    var onCancel: (() -> Void)? = nil
    
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
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Elegant cancel button (only if onCancel is provided)
            if let onCancel = onCancel {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3), .white.opacity(0.1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
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

// MARK: - Input Bar Component

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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: messageText.isEmpty)
    }
}


// MARK: - Preview

#Preview {
    UnifiedChatView()
        .environmentObject(LibraryViewModel())
}