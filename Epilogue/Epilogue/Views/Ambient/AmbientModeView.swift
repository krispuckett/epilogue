import SwiftUI
import SwiftData
import Combine

// MARK: - Fixed Ambient Mode View (Keeping Original Gradients!)
struct AmbientModeView: View {
    @StateObject private var processor = TrueAmbientProcessor.shared
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var bookDetector = AmbientBookDetector.shared
    
    @State private var messages: [UnifiedChatMessage] = []
    @State private var currentBookContext: Book?
    @State private var colorPalette: ColorPalette?
    @State private var isRecording = false
    @State private var liveTranscription: String = ""
    @State private var audioLevel: Float = 0
    @State private var messageText = ""
    @State private var coverImage: UIImage?
    @FocusState private var isInputFocused: Bool
    @State private var showingCommandPalette = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var detectionState: DetectionState = .idle
    @State private var lastDetectedBookId: UUID?
    @State private var showingBookStrip = false
    @State private var showBookCoverInChat = true
    @State private var savedItemsCount = 0
    @State private var showSaveAnimation = false
    @State private var processedContentHashes = Set<String>() // Deduplication
    @State private var transcriptionFadeTimer: Timer?
    @State private var showLiveTranscription = true
    @State private var currentSession: AmbientSession?
    @State private var showingSessionSummary = false
    @State private var sessionStartTime: Date?
    @State private var isEditingTranscription = false
    @State private var editableTranscription = ""
    @FocusState private var isTranscriptionFocused: Bool
    @State private var isWaitingForAIResponse = false
    @State private var pendingQuestion: String?
    @State private var lastProcessedCount = 0
    @State private var debounceTimer: Timer?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    enum DetectionState {
        case idle
        case detectingQuote
        case processingQuestion
        case savingNote
        case saved
        
        var icon: String {
            switch self {
            case .idle: return "waveform"
            case .detectingQuote: return "quote.bubble.fill"
            case .processingQuestion: return "questionmark.circle.fill"
            case .savingNote: return "note.text"
            case .saved: return "checkmark.circle.fill"
            }
        }
    }
    
    // Adaptive UI color based on current palette
    private var adaptiveUIColor: Color {
        if let palette = colorPalette {
            return palette.adaptiveUIColor
        } else {
            return Color(red: 1.0, green: 0.55, blue: 0.26)
        }
    }
    
    var body: some View {
        ZStack {
            // Base gradient background - always visible
            gradientBackground
            
            // Main scroll content
            mainScrollContent
        }
        // Top gradient overlay for fake blur effect (like BookView)
        .overlay(alignment: .top) {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),  // Much darker at the top
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.05),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)  // Slightly taller for smoother gradient
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .blur(radius: 0.5)  // Subtle blur to soften the gradient edge
        }
        // Voice gradient overlay - appears on top when recording
        .overlay(alignment: .bottom) {
            if isRecording {
                voiceGradientOverlay
            }
        }
        // Clean minimal input bar
        .safeAreaInset(edge: .bottom) {
            if !isRecording {
                bottomInputArea
            }
        }
        // Top navigation bar with BookView-style header
        .safeAreaInset(edge: .top) {
            bookStyleHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        // Removed - moved above transcription bar
        .statusBarHidden(true)
        .fullScreenCover(isPresented: $showingSessionSummary, onDismiss: {
            // After summary is dismissed, close ambient mode
            dismiss()
        }) {
            if let session = currentSession {
                AmbientSessionSummaryView(
                    session: session,
                    colorPalette: colorPalette
                )
                .environment(\.modelContext, modelContext)
                .environmentObject(libraryViewModel)
                .environmentObject(notesViewModel)
            }
        }
        .onAppear {
            startAmbientExperience()
        }
        .onReceive(processor.$detectedContent.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)) { newContent in
            // Only process if there are actual new items
            if newContent.count > lastProcessedCount {
                let newItems = Array(newContent.suffix(newContent.count - lastProcessedCount))
                processAndSaveDetectedContent(newItems)
                lastProcessedCount = newContent.count
            } else if newContent.count == lastProcessedCount && newContent.count > 0 {
                // Check for response updates on existing items
                checkForResponseUpdates(in: newContent)
            }
        }
        .onReceive(bookDetector.$detectedBook) { book in
            handleBookDetection(book)
        }
        .onReceive(voiceManager.$transcribedText) { text in
            // Only update if actually recording
            guard isRecording else {
                liveTranscription = ""
                showLiveTranscription = false
                transcriptionFadeTimer?.invalidate()
                return
            }
            
            // Clean transcription - only show new content
            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Debug log
            if !cleanedText.isEmpty {
                print("📝 Live transcription received: \(cleanedText)")
            }
            
            // Update live transcription
            liveTranscription = cleanedText
            
            // Show transcription immediately when new text arrives
            if !cleanedText.isEmpty {
                withAnimation(.easeIn(duration: 0.2)) {
                    showLiveTranscription = true
                }
                
                // Cancel existing timer
                transcriptionFadeTimer?.invalidate()
                
                // Check if this is a book mention or progress update - fade faster
                let lowercased = cleanedText.lowercased()
                let isBookMention = lowercased.contains("i'm reading") ||
                                   lowercased.contains("currently reading") ||
                                   lowercased.contains("just started") ||
                                   lowercased.contains("finished reading") ||
                                   lowercased.contains("reading") && libraryViewModel.books.contains { book in
                                       lowercased.contains(book.title.lowercased())
                                   }
                
                // Also fade faster for progress updates
                let isProgressUpdate = lowercased.contains("chapter") ||
                                      lowercased.contains("page") ||
                                      lowercased.contains("finished") ||
                                      lowercased.contains("i'm on") ||
                                      lowercased.contains("just got to")
                
                // Use shorter fade time for contextual mentions (1.5s) vs normal content (5s)
                let fadeDelay = (isBookMention || isProgressUpdate) ? 1.5 : 5.0
                
                // Start timer for fade out
                transcriptionFadeTimer = Timer.scheduledTimer(withTimeInterval: fadeDelay, repeats: false) { _ in
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLiveTranscription = false
                    }
                }
            }
            
            // Detect book mentions if text is substantial
            if cleanedText.count > 10 {
                bookDetector.detectBookInText(cleanedText)
            }
        }
        .onReceive(voiceManager.$currentAmplitude) { amplitude in
            audioLevel = amplitude
        }
        // Removed duplicate question processing notification handler
        // Book strip overlay
        .overlay {
            if showingBookStrip {
                bookStripOverlay
            }
        }
    }
    
    // MARK: - Gradient Background (Matching UnifiedChatView)
    @ViewBuilder
    private var gradientBackground: some View {
        if let book = currentBookContext {
            // Use book-specific gradient with extracted colors
            let palette = colorPalette ?? generatePlaceholderPalette(for: book)
            BookAtmosphericGradientView(
                colorPalette: palette, 
                intensity: isRecording ? 0.9 + Double(audioLevel) * 0.3 : 0.85,
                audioLevel: isRecording ? audioLevel : 0
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.8), value: currentBookContext?.localId)
            .id(book.localId)
        } else {
            // Default warm ambient gradient
            AmbientChatGradientView()
                .opacity(isRecording ? 0.8 + Double(audioLevel) * 0.4 : 1.0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: isRecording)
        }
    }
    
    // MARK: - Voice Gradient Overlay (Matching UnifiedChatView)
    @ViewBuilder
    private var voiceGradientOverlay: some View {
        VStack {
            // Book cover - only show when no messages (questions) are visible
            let hasQuestions = messages.contains { !$0.content.contains("[Transcribing]") }
            if let book = currentBookContext, let coverURL = book.coverImageURL, !hasQuestions {
                SharedBookCoverView(
                    coverURL: coverURL,
                    width: 140,
                    height: 210
                )
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(isRecording ? 1.0 : 0.9)
                .opacity(isRecording ? 1.0 : 0.3)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isRecording)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .scale(scale: 0.5).combined(with: .opacity)
                ))
                .padding(.top, 140) // Position below navigation buttons with more space
            }
            
            Spacer()
            
            // Voice responsive bottom gradient - exactly like UnifiedChatView
            VoiceResponsiveBottomGradient(
                colorPalette: colorPalette,
                audioLevel: audioLevel,
                isRecording: isRecording,
                bookContext: currentBookContext
            )
            .allowsHitTesting(false)
            .ignoresSafeArea(.all)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            ))
        }
        
        // Minimal recording UI
        VStack {
            Spacer()
            
            // Save indicator above transcription
            if showSaveAnimation {
                HStack(spacing: 6) {
                    Image(systemName: detectionState.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .symbolEffect(.pulse)
                    
                    Text("Saved")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect()
                .glassEffectTransition(.materialize)
                .clipShape(Capsule())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
                .padding(.bottom, 10)
            }
            
            // Live transcription with animated glass container (editable)
            if isRecording && !liveTranscription.isEmpty {
                Group {
                    if isEditingTranscription {
                        TextField("Edit transcription...", text: $editableTranscription)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .focused($isTranscriptionFocused)
                            .onSubmit {
                                liveTranscription = editableTranscription
                                isEditingTranscription = false
                            }
                    } else {
                        Text(liveTranscription)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .onTapGesture {
                                editableTranscription = liveTranscription
                                isEditingTranscription = true
                                isTranscriptionFocused = true
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: UIScreen.main.bounds.width - 80)
                .glassEffect()
                .glassEffectTransition(.materialize)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12  // Fixed corner radius for polished look
                    )
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: liveTranscription.count)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .opacity(showLiveTranscription ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: showLiveTranscription)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            }
            
            // Clean stop button with red glass tint
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    stopRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .glassEffect()
                        .glassEffectTransition(.materialize)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                }
            }
            .padding(.bottom, 50)
            .scaleEffect(1.0)
            .transition(.asymmetric(
                insertion: .scale(scale: 1.2).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .push(from: .top))
            ))
        }
    }
    
    // MARK: - Clean Main Scroll Content
    @ViewBuilder
    private var mainScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Small top spacer since header uses safeAreaInset
                    Color.clear
                        .frame(height: 20)
                    
                    let hasRealContent = messages.contains { msg in
                        !msg.content.contains("[Transcribing]")
                    }
                    
                    if !hasRealContent {
                        if currentBookContext == nil && !isRecording {
                            // Simplified welcome
                            minimalWelcomeView
                                .padding(.top, 50)
                        }
                    }
                    
                    // Messages
                    ForEach(messages) { message in
                        ChatMessageView(
                            message: message,
                            currentBookContext: currentBookContext,
                            colorPalette: colorPalette ?? defaultColorPalette
                        )
                        .id(message.id)
                    }
                    
                    // Subtle thinking indicator for pending questions
                    if isWaitingForAIResponse, let question = pendingQuestion {
                        HStack {
                            SubtleLiquidThinking(bookColor: adaptiveUIColor)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                    }
                    
                    // Bottom spacer for input area
                    Color.clear
                        .frame(height: 80)
                        .id("bottom")
                }
                .padding(.horizontal, 20)
            }
            .scrollBounceBehavior(.basedOnSize) // Prevent excessive bouncing
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: messages.count) { _, _ in
                // Scroll to new message with delay to ensure layout is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if let lastMessage = messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Minimal Welcome View
    private var minimalWelcomeView: some View {
        VStack(spacing: 20) {
            Text("Listening...")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
            
            Text("Just start talking about what you're reading")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Clean Bottom Input Area
    @ViewBuilder
    private var bottomInputArea: some View {
        VStack {
            Spacer()
            
            // Waveform button with smooth morphing animation
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    handleMicrophoneTap()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                        .frame(width: 64, height: 64)
                        .glassEffect()
                        .glassEffectTransition(.materialize)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .symbolEffect(.bounce, value: isRecording)
                }
            }
            .padding(.bottom, 50)
            .scaleEffect(1.0)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .push(from: .bottom)),
                removal: .scale(scale: 1.2).combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - BookView-Style Header
    private var bookStyleHeader: some View {
        HStack(spacing: 0) {
            // Left side - Exit button (X in circle with liquid glass)
            Button {
                stopAndSaveSession()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .glassEffect()
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Right side - Switch books pill with liquid glass
            if currentBookContext != nil {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingBookStrip.toggle()
                    }
                } label: {
                    Text("Switch Book")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassEffect()
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - CRITICAL DATA PERSISTENCE FIX
    
    private func checkForResponseUpdates(in content: [AmbientProcessedContent]) {
        // Only check recent items for response updates to avoid excessive processing
        let recentItems = content.suffix(10)
        
        for item in recentItems {
            if item.type == .question, let response = item.response {
                // Check if we already have this response displayed
                let responseKey = "\(item.text)_response"
                if !processedContentHashes.contains(responseKey) {
                    processedContentHashes.insert(responseKey)
                    
                    // Hide thinking indicator and show response
                    isWaitingForAIResponse = false
                    pendingQuestion = nil
                    
                    // Format and display the response
                    let formattedResponse = "**\(item.text)**\n\n\(response)"
                    let aiMessage = UnifiedChatMessage(
                        content: formattedResponse,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .text
                    )
                    messages.append(aiMessage)
                    print("✅ Added AI response via update check: \(item.text.prefix(30))...")
                }
            }
        }
    }
    
    private func processAndSaveDetectedContent(_ content: [AmbientProcessedContent]) {
        for item in content {
            // Create hash for deduplication - include response for questions to prevent duplicate AI responses
            let contentHash: String
            if item.type == .question {
                // For questions, include the response in the hash to ensure uniqueness
                contentHash = "\(item.type)_\(item.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))_\(item.response ?? "")"
            } else {
                contentHash = "\(item.type)_\(item.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            
            // Skip if already processed (using hash to prevent duplicates)
            if processedContentHashes.contains(contentHash) {
                print("⚠️ Skipping duplicate: \(item.text.prefix(30))...")
                continue
            }
            
            // Mark as processed
            processedContentHashes.insert(contentHash)
            
            // Update detection state
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                switch item.type {
                case .question:
                    detectionState = .processingQuestion
                case .quote:
                    detectionState = .detectingQuote
                case .note, .thought:
                    detectionState = .savingNote
                default:
                    detectionState = .idle
                }
            }
            
            // SAVE TO SWIFTDATA IMMEDIATELY
            switch item.type {
            case .quote:
                saveQuoteToSwiftData(item)
                savedItemsCount += 1
                showSaveAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSaveAnimation = false
                }
            case .note, .thought:
                saveNoteToSwiftData(item)
                savedItemsCount += 1
                showSaveAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSaveAnimation = false
                }
            case .question:
                saveQuestionToSwiftData(item)
            default:
                break
            }
            
            // ONLY show AI responses for questions in ambient mode
            // Don't show the user's question as a bubble - just the AI response
            if item.type == .question {
                if item.response != nil {
                    // More robust duplicate check - check both content and question context
                    let responseExists = messages.contains { msg in
                        !msg.isUser && (msg.content == item.response || msg.content.contains(item.text))
                    }
                    
                    if !responseExists {
                        // Hide thinking indicator when we have a response
                        isWaitingForAIResponse = false
                        
                        // Format the response with the question for context
                        let formattedResponse = "**\(item.text)**\n\n\(item.response!)"
                        let aiMessage = UnifiedChatMessage(
                            content: formattedResponse,
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext,
                            messageType: .text
                        )
                        messages.append(aiMessage)
                        print("✅ Added AI response for question: \(item.text.prefix(30))...")
                    } else {
                        print("⚠️ Response already exists for question: \(item.text.prefix(30))...")
                    }
                } else {
                    // Question detected but no response yet - show thinking indicator
                    pendingQuestion = item.text
                    isWaitingForAIResponse = true
                    print("💭 Showing thinking indicator for question: \(item.text.prefix(30))...")
                }
            }
            
            // Reset state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    detectionState = .idle
                }
            }
        }
    }
    
    private func saveQuoteToSwiftData(_ content: AmbientProcessedContent) {
        // Check for existing duplicate before saving
        let cleanText = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetchRequest = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { quote in
                quote.text == cleanText
            }
        )
        
        if let existingQuotes = try? modelContext.fetch(fetchRequest), !existingQuotes.isEmpty {
            print("⚠️ Quote already exists, skipping save: \(cleanText.prefix(30))...")
            return
        }
        
        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            // Check if BookModel already exists in context
            let fetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.localId == book.localId.uuidString
                }
            )
            
            if let existingBook = try? modelContext.fetch(fetchRequest).first {
                bookModel = existingBook
            } else {
                bookModel = BookModel(from: book)
                modelContext.insert(bookModel!)
            }
        }
        
        // The text should already be cleaned by TrueAmbientProcessor
        // Just use it as-is since the processor handles the cleanup
        let quoteText = content.text
        
        let capturedQuote = CapturedQuote(
            text: quoteText,
            book: bookModel,
            author: currentBookContext?.author,
            pageNumber: nil,
            timestamp: content.timestamp,
            source: .ambient
        )
        
        modelContext.insert(capturedQuote)
        
        do {
            try modelContext.save()
            print("✅ Quote saved to SwiftData: \(content.text.prefix(50))...")
            HapticManager.shared.success()
        } catch {
            print("❌ Failed to save quote: \(error)")
        }
    }
    
    private func saveNoteToSwiftData(_ content: AmbientProcessedContent) {
        // Check for existing duplicate before saving
        let cleanText = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetchRequest = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { note in
                note.content == cleanText
            }
        )
        
        if let existingNotes = try? modelContext.fetch(fetchRequest), !existingNotes.isEmpty {
            print("⚠️ Note already exists, skipping save: \(cleanText.prefix(30))...")
            return
        }
        
        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            let fetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.localId == book.localId.uuidString
                }
            )
            
            if let existingBook = try? modelContext.fetch(fetchRequest).first {
                bookModel = existingBook
            } else {
                bookModel = BookModel(from: book)
                modelContext.insert(bookModel!)
            }
        }
        
        let capturedNote = CapturedNote(
            content: content.text,
            book: bookModel,
            pageNumber: nil,
            timestamp: content.timestamp,
            source: .ambient
        )
        
        modelContext.insert(capturedNote)
        
        do {
            try modelContext.save()
            print("✅ Note saved to SwiftData: \(content.text.prefix(50))...")
            HapticManager.shared.success()
        } catch {
            print("❌ Failed to save note: \(error)")
        }
    }
    
    private func saveQuestionToSwiftData(_ content: AmbientProcessedContent) {
        // Check for existing duplicate before saving
        let cleanText = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetchRequest = FetchDescriptor<CapturedQuestion>(
            predicate: #Predicate { question in
                question.content == cleanText
            }
        )
        
        if let existingQuestions = try? modelContext.fetch(fetchRequest), 
           let existingQuestion = existingQuestions.first {
            // Update answer if we have a response
            if let response = content.response, existingQuestion.answer == nil {
                existingQuestion.answer = response
                existingQuestion.isAnswered = true
                do {
                    try modelContext.save()
                    print("✅ Updated question with answer: \(cleanText.prefix(30))...")
                } catch {
                    print("❌ Failed to update question: \(error)")
                }
            } else {
                print("⚠️ Question already exists with answer: \(cleanText.prefix(30))...")
            }
            return
        }
        
        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            let fetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.localId == book.localId.uuidString
                }
            )
            
            if let existingBook = try? modelContext.fetch(fetchRequest).first {
                bookModel = existingBook
            } else {
                bookModel = BookModel(from: book)
                modelContext.insert(bookModel!)
            }
        }
        
        let capturedQuestion = CapturedQuestion(
            content: content.text,
            book: bookModel,
            timestamp: content.timestamp,
            source: .ambient
        )
        
        // Add answer if available
        if let response = content.response {
            capturedQuestion.answer = response
            capturedQuestion.isAnswered = true
        }
        
        modelContext.insert(capturedQuestion)
        
        do {
            try modelContext.save()
            print("✅ Question saved to SwiftData: \(content.text.prefix(50))...")
        } catch {
            print("❌ Failed to save question: \(error)")
        }
    }
    
    // MARK: - Actions
    
    private func startAmbientExperience() {
        // Record when the session actually starts
        sessionStartTime = Date()
        
        // Create the session at the START
        let session = AmbientSession(book: currentBookContext)
        session.startTime = sessionStartTime! // Use the actual start time
        currentSession = session
        modelContext.insert(session)
        
        // Save the session immediately so relationships can be established
        do {
            try modelContext.save()
            print("✅ Initial session created and saved")
        } catch {
            print("❌ Failed to save initial session: \(error)")
        }
        
        // CRITICAL: Set the model context and session for the processor
        processor.setModelContext(modelContext)
        processor.setCurrentSession(session)
        processor.startSession()
        
        // Update library for book detection
        bookDetector.updateLibrary(libraryViewModel.books)
        
        // Auto-start recording after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            handleMicrophoneTap()
        }
    }
    
    private func handleMicrophoneTap() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        processor.startSession()
        voiceManager.startAmbientListeningMode()
        bookDetector.startDetection()
        HapticManager.shared.mediumTap()
    }
    
    private func stopRecording() {
        isRecording = false
        liveTranscription = "" // Clear immediately
        showLiveTranscription = false
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        voiceManager.stopListening()
        voiceManager.transcribedText = "" // Force clear the source
        HapticManager.shared.lightTap()
        
        // Don't force scroll - let the content stay where it is
        // The onChange handler will scroll when new messages arrive
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let message = UnifiedChatMessage(
            content: messageText,
            isUser: true,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        messages.append(message)
        
        Task {
            await getAIResponse(for: messageText)
        }
        
        messageText = ""
    }
    
    private func getAIResponse(for text: String) async {
        let aiService = AICompanionService.shared
        
        guard aiService.isConfigured() else {
            await MainActor.run {
                let configMessage = UnifiedChatMessage(
                    content: "Please configure your AI service.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                messages.append(configMessage)
            }
            return
        }
        
        do {
            let response = try await aiService.processMessage(
                text,
                bookContext: currentBookContext,
                conversationHistory: messages
            )
            
            await MainActor.run {
                let aiMessage = UnifiedChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                messages.append(aiMessage)
            }
        } catch {
            await MainActor.run {
                let errorMessage = UnifiedChatMessage(
                    content: "Sorry, I couldn't process your message.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                messages.append(errorMessage)
            }
        }
    }
    
    private func handleBookDetection(_ book: Book?) {
        guard let book = book else { return }
        
        // Prevent duplicate detections
        if lastDetectedBookId == book.localId {
            return
        }
        
        print("📚 Book detected: \(book.title)")
        lastDetectedBookId = book.localId
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentBookContext = book
        }
        
        // Update the TrueAmbientProcessor with the new book context
        TrueAmbientProcessor.shared.updateBookContext(book)
        
        Task {
            await extractColorsForBook(book)
        }
        
        HapticManager.shared.lightTap()
    }
    
    private func extractColorsForBook(_ book: Book) async {
        let bookID = book.localId.uuidString
        print("🎨 Extracting colors for: \(book.title)")
        
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            print("✅ Found cached palette for: \(book.title)")
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.colorPalette = cachedPalette
                }
            }
            return
        }
        
        guard let coverURLString = book.coverImageURL else { 
            print("❌ No cover URL for: \(book.title)")
            return 
        }
        
        // Convert HTTP to HTTPS for ATS compliance
        let secureURLString = coverURLString.replacingOccurrences(of: "http://", with: "https://")
        guard let coverURL = URL(string: secureURLString) else {
            print("❌ Invalid URL: \(secureURLString)")
            return
        }
        
        do {
            let (imageData, _) = try await URLSession.shared.data(from: coverURL)
            guard let image = UIImage(data: imageData) else { 
                print("❌ Failed to create image from data")
                return 
            }
            
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: image)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.5)) {
                    self.colorPalette = palette
                    self.coverImage = image
                    print("✅ Color palette extracted for: \(book.title)")
                    print("  Primary: \(palette.primary)")
                    print("  Secondary: \(palette.secondary)")
                }
            }
            
            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
        } catch {
            print("❌ Failed to extract colors: \(error)")
        }
    }
    
    // Removed duplicate handleAIResponse function - no longer needed
    
    private func exitInstantly() {
        // INSTANT UI updates
        isRecording = false
        liveTranscription = ""
        showLiveTranscription = false
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        voiceManager.stopListening()
        
        // End processor session
        Task {
            await processor.endSession()
        }
        
        // Dismiss the view immediately
        dismiss()
    }
    
    private func stopAndSaveSession() {
        // Stop recording
        isRecording = false
        liveTranscription = ""
        showLiveTranscription = false
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        voiceManager.stopListening()
        
        // Create and save session if we have content
        if !processor.detectedContent.isEmpty {
            // Create the session first
            let session = createSession()
            
            // Set it as current for the sheet
            currentSession = session
            
            // Show the summary with a small delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🎬 Presenting session summary...")
                showingSessionSummary = true
            }
            
            // DON'T dismiss yet - let the summary view handle that
        } else {
            // No content to save, just dismiss
            Task {
                await processor.endSession()
            }
            dismiss()
        }
    }
    
    private func createSession() -> AmbientSession {
        // Use existing session or create new one if somehow missing
        let session = currentSession ?? AmbientSession(book: currentBookContext)
        
        // Ensure the correct start and end times
        if let startTime = sessionStartTime {
            session.startTime = startTime
        }
        session.endTime = Date()
        
        print("📊 Creating session with \(processor.detectedContent.count) items")
        
        // Add captured content to session
        for item in processor.detectedContent {
            switch item.type {
            case .quote:
                if let quote = findQuote(matching: item.text) {
                    quote.ambientSession = session
                    session.capturedQuotes.append(quote)
                    print("✅ Added quote to session")
                }
            case .note, .thought:
                if let note = findNote(matching: item.text) {
                    note.ambientSession = session
                    session.capturedNotes.append(note)
                    print("✅ Added note to session")
                }
            case .question:
                // For questions, also check if it's saved with answer property
                if let question = findQuestion(matching: item.text) {
                    // Make sure the question has the latest answer
                    if let response = item.response, question.answer == nil {
                        question.answer = response
                        question.isAnswered = true
                    }
                    question.ambientSession = session
                    session.capturedQuestions.append(question)
                    print("✅ Added question to session: \(item.text) with answer: \(question.answer != nil)")
                } else {
                    // Create a new question if not found
                    let bookModel: BookModel? = nil // We'd need to convert Book to BookModel
                    let newQuestion = CapturedQuestion(
                        content: item.text,
                        book: bookModel,
                        timestamp: item.timestamp,
                        source: .ambient
                    )
                    newQuestion.answer = item.response
                    newQuestion.isAnswered = item.response != nil
                    modelContext.insert(newQuestion)
                    session.capturedQuestions.append(newQuestion)
                    print("✅ Created and added new question to session")
                }
            default:
                break
            }
        }
        
        // Save session to SwiftData (only insert if not already inserted)
        if currentSession == nil {
            modelContext.insert(session)
        }
        do {
            try modelContext.save()
            print("✅ Session saved to SwiftData with all relationships")
        } catch {
            print("❌ Failed to save session: \(error)")
        }
        
        // End processor session in background
        Task.detached { [weak processor] in
            await processor?.endSession()
            await AmbientLiveActivityManager.shared.endActivity()
        }
        
        return session
    }
    
    private func findQuote(matching text: String) -> CapturedQuote? {
        let fetchRequest = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { quote in
                quote.text == text
            }
        )
        return try? modelContext.fetch(fetchRequest).first
    }
    
    private func findNote(matching text: String) -> CapturedNote? {
        let fetchRequest = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { note in
                note.content == text
            }
        )
        return try? modelContext.fetch(fetchRequest).first
    }
    
    private func findQuestion(matching text: String) -> CapturedQuestion? {
        let fetchRequest = FetchDescriptor<CapturedQuestion>(
            predicate: #Predicate { question in
                question.content == text
            }
        )
        return try? modelContext.fetch(fetchRequest).first
    }
    
    private func generatePlaceholderPalette(for book: Book) -> ColorPalette {
        ColorPalette(
            primary: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8),
            secondary: Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.6),
            accent: Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.5),
            background: Color(white: 0.1),
            textColor: .white,
            luminance: 0.3,
            isMonochromatic: false,
            extractionQuality: 0.1
        )
    }
    
    private var defaultColorPalette: ColorPalette {
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
    
    // MARK: - Book Strip Overlay
    @ViewBuilder
    private var bookStripOverlay: some View {
        ZStack {
            // Background tap to dismiss
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingBookStrip = false
                    }
                }
            
            // Book grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 90), spacing: 16)
                ], spacing: 16) {
                    // "All books" button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentBookContext = nil
                            showingBookStrip = false
                        }
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
                    }
                    
                    // Book covers
                    ForEach(libraryViewModel.books) { book in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentBookContext = book
                                showingBookStrip = false
                                lastDetectedBookId = book.localId
                            }
                            Task {
                                await extractColorsForBook(book)
                            }
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
                                        .stroke(Color.white, lineWidth: 2)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.top, 60)
            }
        }
        .transition(.opacity)
    }
}