import SwiftUI
import SwiftData
import OSLog

struct UnifiedChatView: View {
    let preSelectedBook: Book?
    let startInVoiceMode: Bool
    let isAmbientMode: Bool
    
    @State private var currentBookContext: Book?
    @State private var messages: [UnifiedChatMessage] = []
    @Environment(\.dismiss) private var dismiss
    
    init(preSelectedBook: Book? = nil, startInVoiceMode: Bool = false, isAmbientMode: Bool = false) {
        self.preSelectedBook = preSelectedBook
        self.startInVoiceMode = startInVoiceMode
        self.isAmbientMode = isAmbientMode
        
        // SAFETY: Initialize showingBookStrip - NEVER show in ambient mode
        self._showingBookStrip = State(initialValue: false)
    }
    @State private var scrollProxy: ScrollViewProxy?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    // Settings
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    @AppStorage("enableAnimations") private var enableAnimations = true
    @ObservedObject private var syncManager = NotesSyncManager.shared
    
    // Ambient session tracking
    @State private var ambientSession: OptimizedAmbientSession?
    @State private var showingSessionSummary = false
    @State private var sessionStartTime: Date?
    @State private var sessionContent: [SessionContent] = []
    @State private var showDebugOverlay = false // Disabled in production
    
    // Real-time processing state
    @State private var detectionState: DetectionState = .idle
    @State private var detectedEntities: [(text: String, confidence: Float)] = []
    @State private var processingHint: String = ""
    @State private var showQuickActions = false
    @State private var editingContent: DetectedContent?
    @State private var lastProcessedText = ""
    
    // Deduplication tracking
    @State private var recentlyProcessedHashes = Set<Int>()
    @State private var lastProcessedTime = Date()
    
    // THE SINGLE SOURCE PROCESSOR - replaces all competing systems
    @StateObject private var processor = TrueAmbientProcessor.shared
    
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
        
        var text: String {
            switch self {
            case .idle: return "Listening..."
            case .detectingQuote: return "Capturing Quote"
            case .processingQuestion: return "Processing Question"
            case .savingNote: return "Saving Note"
            case .saved: return "Saved!"
            }
        }
        
        var hint: String {
            switch self {
            case .idle: return ""
            case .detectingQuote: return "I heard a quote, keep talking..."
            case .processingQuestion: return "Processing your question..."
            case .savingNote: return "Saving your reflection..."
            case .saved: return "Saved successfully"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .white.opacity(0.6)
            case .detectingQuote: return .green
            case .processingQuestion: return .blue
            case .savingNote: return .orange
            case .saved: return .green
            }
        }
    }
    
    private let logger = Logger(subsystem: "com.epilogue", category: "UnifiedChatView")
    
    struct DetectedContent: Identifiable {
        let id = UUID()
        var text: String
        let type: ContentType
        let confidence: Float
        var isEditing: Bool = false
        
        enum ContentType {
            case quote, question, note
        }
    }
    
    // Filter messages for current context - NOW PERSISTENT IN AMBIENT MODE
    private var filteredMessages: [UnifiedChatMessage] {
        // In ambient mode, show ALL messages in a persistent thread
        if isAmbientMode {
            // Show all messages regardless of book context - persistent chat thread
            return messages.filter { message in
                !message.isDeleted()
            }
        }
        
        // Non-ambient mode: filter by book context
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
    
    // Session detection
    private var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    private var shouldShowSessionSummary: Bool {
        // Show summary after 5+ minutes with 3+ interactions
        return isAmbientMode && sessionDuration > 300 && sessionContent.count >= 3
    }
    @State private var coverImage: UIImage?
    
    // Input state
    @State private var messageText = ""
    @State private var showingCommandPalette = false
    @State private var showingBookStrip = false
    @FocusState private var isInputFocused: Bool
    
    // Ambient/Whisper state
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    // Pipeline replaced by TrueAmbientProcessor
    @StateObject private var pipeline = TrueAmbientProcessor.shared
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
            return DesignSystem.Colors.primaryAccent
        }
    }
    
    // MARK: - Body Components
    
    private var baseView: some View {
        mainContent
            .animation(.easeInOut(duration: 0.5), value: currentBookContext?.localId)
            .animation(.easeInOut(duration: 0.8), value: isRecording)
    }
    
    private var viewWithOverlays: some View {
        baseView
            .overlay(alignment: .bottom) { voiceGradientOverlay }
            .overlay(alignment: .topLeading) {
                if isAmbientMode { ambientModeExitButton }
            }
            // Debug overlay removed for production
    }
    
    private var viewWithNavigation: some View {
        viewWithOverlays
            .navigationTitle(isAmbientMode ? "" : (currentBookContext?.title ?? "Chat"))
            .navigationBarTitleDisplayMode(isAmbientMode ? .inline : .large)
            .navigationBarHidden(isAmbientMode)
    }
    
    private var viewWithSheet: some View {
        viewWithNavigation
            .sheet(isPresented: $showingSessionSummary) {
                if let optimizedSession = ambientSession {
                    // Convert OptimizedAmbientSession to AmbientSession
                    let session = AmbientSession(book: optimizedSession.bookContext)
                    AmbientSessionSummaryView(
                        session: session,
                        colorPalette: colorPalette
                    )
                    .onDisappear {
                        handleSessionSummaryDismiss()
                    }
                }
            }
    }
    
    private func handleSessionSummaryDismiss() {
        if let session = ambientSession, !sessionContent.isEmpty {
            autoSaveShortSession(session)
        }
        ambientSession = nil
        sessionContent.removeAll()
        sessionStartTime = nil
    }
    
    private func handleTranscribedText(_ text: String) {
        guard isRecording && !text.isEmpty else { return }
        
        // Process with improved processor
        // Context is handled internally by the processor
        
        // Process incrementally through smart buffer
        if text != lastProcessedText {
            let newContent = String(text.dropFirst(lastProcessedText.count))
            if !newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // TrueAmbientProcessor processes audio buffers, not text
                // Text processing happens via VoiceRecognitionManager
            }
            lastProcessedText = text
        }
        
        // Show live transcription
        liveTranscription = text
    }
    
    private func handleProcessorResult(_ result: AmbientProcessedContent) {
        Task {
            await handleProcessedResult(result)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        viewWithSheet
            .ambientModeModifiers(isAmbientMode: isAmbientMode, dismiss: dismiss) { 
                handleMicrophoneTap() 
            }
            .statusBarHidden(isAmbientMode)
            .onAppear {
                setupInitialState()
                // Debug overlay disabled for production
                // #if DEBUG
                // if isAmbientMode { showDebugOverlay = false }
                // #endif
            }
            .onChange(of: currentBookContext) { oldBook, newBook in
                handleBookContextChange(oldBook: oldBook, newBook: newBook)
                
                // Clear transcription when switching books
                if oldBook != newBook {
                    liveTranscription = ""
                    detectionState = .idle
                    detectedEntities.removeAll()
                    
                    // Force re-render of transcription view to restart animations
                    if isRecording {
                        // Briefly toggle to restart animation
                        withAnimation(.none) {
                            liveTranscription = " " // Force update
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            liveTranscription = ""
                        }
                    }
                }
            }
            .onChange(of: voiceManager.currentAmplitude) { _, newAmplitude in
                audioLevel = newAmplitude
            }
            .overlay(alignment: .bottom) { commandPaletteOverlay }
            .animation(DesignSystem.Animation.springStandard, value: showingCommandPalette)
            .onReceive(voiceManager.$transcribedText, perform: handleTranscribedText)
            // Processing handled via detectedContent observable
            .onReceive(processor.$detectedContent) { content in
                // Optimized: Only process the last few items instead of entire history
                let recentItems = content.suffix(5)  // Only check recent items
                
                for item in recentItems {
                    if item.type == .question, let response = item.response {
                        // Use a more efficient check
                        let needsResponse = messages.contains { msg in
                            msg.content == item.text && msg.isUser
                        } && !messages.contains { msg in
                            msg.content == response && !msg.isUser
                        }
                        
                        if needsResponse {
                            messages.append(UnifiedChatMessage(
                                content: response,
                                isUser: false,
                                timestamp: Date(),
                                bookContext: currentBookContext
                            ))
                            logger.info("✅ AI response displayed: \(response.prefix(50))...")
                        }
                    }
                }
                
                // Handle new items
                if let lastItem = content.last {
                    handleProcessorResult(lastItem)
                }
            }
            .onChange(of: showingBookStrip) { oldValue, newValue in
                if isAmbientMode && newValue {
                    print("🛡️ SAFETY: Blocking book strip activation in ambient mode")
                    showingBookStrip = false
                    return
                }
                if showingBookStrip {
                    isInputFocused = false
                }
            }
            .toolbar {
                if !isAmbientMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // SAFETY: Additional check before toggling book strip
                            guard !isAmbientMode else {
                                print("🛡️ SAFETY: Prevented book strip toggle in ambient mode")
                                return
                            }
                            withAnimation(DesignSystem.Animation.springStandard) {
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
            }
            // Notification handlers
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AmbientChatBookChanged"))) { notification in
                if let book = notification.object as? Book {
                    currentBookContext = book
                    Task {
                        await extractColorsForBook(book)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowAmbientBookSelector"))) { _ in
                guard !isAmbientMode else {
                    print("🛡️ SAFETY: Blocked ShowAmbientBookSelector in ambient mode")
                    return
                }
                withAnimation(DesignSystem.Animation.springStandard) {
                    showingBookStrip = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AmbientSessionCleared"))) { _ in
                messages.removeAll()
                currentSession = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AmbientBookDetected"))) { notification in
                if let book = notification.object as? Book {
                    guard currentBookContext?.id != book.id else { return }
                    withAnimation(DesignSystem.Animation.springStandard) {
                        currentBookContext = book
                        SensoryFeedback.light()
                        Task {
                            await extractColorsForBook(book)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AmbientBookCleared"))) { _ in
                withAnimation(DesignSystem.Animation.springStandard) {
                    currentBookContext = nil
                    colorPalette = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AIResponseComplete"))) { notification in
                handleAIResponseComplete(notification: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UnifiedProcessorDetection"))) { notification in
                guard isAmbientMode, let content = notification.object as? AmbientProcessedContent else { return }
                Task {
                    await processAmbientChunk(content.text)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UnifiedProcessorSaved"))) { notification in
                guard let content = notification.object as? AmbientProcessedContent else { return }
                print("💾 Content saved: \(content.type) - \(content.text.prefix(50))...")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ImmediateQuestionDetected"))) { notification in
                handleImmediateQuestion(notification: notification)
            }
    }
    
    @ViewBuilder
    private var gradientBackground: some View {
        if isRecording, let book = currentBookContext {
            // Use the breathing gradient during recording with book context
            let palette = colorPalette ?? generatePlaceholderPalette(for: book)
            BookAtmosphericGradientView(
                colorPalette: palette, 
                intensity: gradientIntensity * (0.9 + Double(audioLevel) * 0.3) // Audio-reactive intensity with user setting
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .id("recording-\(book.localId)")
        } else if isRecording {
            // Recording without book context - use ambient gradient with audio reactivity
            AmbientChatGradientView()
                .opacity(0.8 + Double(audioLevel) * 0.4) // Audio-reactive opacity
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
                .id("recording-ambient")
        } else if let book = currentBookContext {
            // Use the same BookAtmosphericGradientView with extracted colors
            let palette = colorPalette ?? generatePlaceholderPalette(for: book)
            BookAtmosphericGradientView(colorPalette: palette, intensity: gradientIntensity * 0.85)
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
    
    @ViewBuilder
    private var mainScrollContent: some View {
        ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Check if we only have transcribing messages (not real content)
                        let hasRealContent = filteredMessages.contains { msg in
                            !msg.content.contains("[Transcribing]")
                        }
                        
                        if !hasRealContent {
                            if isAmbientMode && currentBookContext == nil && !isRecording {
                                // Show elegant welcome prompt for ambient mode
                                ambientWelcomeView
                                    .padding(.top, 100)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.98).combined(with: .opacity),
                                        removal: .scale(scale: 1.02).combined(with: .opacity)
                                    ))
                            } else if showingBookStrip && !isAmbientMode {
                                // SAFETY: Double-check - never show book grid in ambient mode
                                bookGridView
                                    .padding(.top, 40)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .scale(scale: 1.05).combined(with: .opacity)
                                    ))
                            } else {
                                // Show empty state even when recording to keep book cover visible
                                emptyStateView
                                    .padding(.top, 100)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.98).combined(with: .opacity),
                                        removal: .scale(scale: 1.02).combined(with: .opacity)
                                    ))
                                    .animation(.easeInOut(duration: 0.5), value: colorPalette)
                            }
                        }
                        
                        // Always show messages if they exist
                        messagesListView
                        
                        // Show persistent thread indicator in ambient mode
                        if isAmbientMode && !filteredMessages.isEmpty {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
                                Text("Chat thread persists across books")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.top, 16) // Top padding for content
                    .padding(.bottom, 100) // Extra bottom padding to account for tab bar
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss keyboard when tapping on the content area
                    isInputFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }
    }
    
    @ViewBuilder
    private var messagesListView: some View {
        if !filteredMessages.isEmpty {
            ForEach(filteredMessages) { message in
                MessageWithQuickActions(
                    message: message,
                    currentBookContext: currentBookContext,
                    colorPalette: colorPalette,
                    onEdit: { editedText in
                        handleContentEdit(message: message, newText: editedText)
                    },
                    onRefine: {
                        refineQuestion(message: message)
                    },
                    onExpand: {
                        expandNote(message: message)
                    }
                )
                .id(message.id)
            }
        }
    }
    
    @ViewBuilder
    private var keyboardDismissBackground: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
    
    @ViewBuilder
    private var recordingIndicators: some View {
        if isRecording {
            VStack(spacing: 12) {
                // Detection indicator and hint
                if detectionState != .idle {
                    HStack(spacing: 12) {
                        DetectionIndicator(
                            state: detectionState,
                            adaptiveUIColor: adaptiveUIColor
                        )
                        
                        Text(detectionState.hint)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(detectionState.color)
                            .transition(.asymmetric(
                                insertion: .push(from: .leading).combined(with: .opacity),
                                removal: .push(from: .trailing).combined(with: .opacity)
                            ))
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Live transcription view for chat mode
                if !liveTranscription.isEmpty {
                    LiveTranscriptionView(
                        transcription: liveTranscription,
                        adaptiveUIColor: adaptiveUIColor,
                        isTranscribing: isRecording,
                        onCancel: cancelTranscription
                    )
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .overlay(alignment: .topTrailing) {
                        // Real-time processing indicator
                        if detectionState != .idle {
                            ProcessingIndicator(state: detectionState)
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private var bottomInputArea: some View {
        VStack(spacing: 0) {
            recordingIndicators
            
            UniversalInputBar(
                messageText: $messageText,
                showingCommandPalette: $showingCommandPalette,
                isInputFocused: $isInputFocused,
                context: .chat(book: currentBookContext),
                onSend: sendMessage,
                onMicrophoneTap: handleMicrophoneTap,
                isRecording: $isRecording,
                colorPalette: colorPalette,
                isAmbientMode: isAmbientMode
            )
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.vertical, 16)
        }
    }
    
    private func cancelTranscription() {
        voiceManager.stopListening()
        isRecording = false
        liveTranscription = ""
        detectionState = .idle
        detectedEntities.removeAll()
        
        // Force process any remaining content in buffer before clearing
        Task {
            // TrueAmbientProcessor handles session end processing
            // No need to force process here
            
            // Clear the smart buffer
            await MainActor.run {
                // Buffer is cleared automatically by processor
                lastProcessedText = ""
            }
        }
        
        if let lastIndex = messages.lastIndex(where: { $0.content == "[Transcribing]" }) {
            messages.remove(at: lastIndex)
        }
        
        SensoryFeedback.light()
    }
    
    private var mainContent: some View {
        ZStack {
            keyboardDismissBackground
            gradientBackground
            mainScrollContent
                .safeAreaBar(edge: .bottom) {
                    bottomInputArea
                }
        }
    }
    
    @ViewBuilder
    private var voiceGradientOverlay: some View {
        if isRecording {
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
    }
    
    @ViewBuilder
    private var commandPaletteOverlay: some View {
        if showingCommandPalette {
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
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.bottom, 80)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.98, anchor: .bottom).combined(with: .opacity),
                removal: .scale(scale: 0.98, anchor: .bottom).combined(with: .opacity)
            ))
            .zIndex(100)
        }
    }
    
    private func setupInitialState() {
        if let book = preSelectedBook {
            currentBookContext = book
            print("onAppear: Setting pre-selected book: \(book.title)")
        }
        
        if let book = currentBookContext {
            print("onAppear: Found initial book context: \(book.title)")
            Task {
                await extractColorsForBook(book)
            }
        }
        
        if isAmbientMode {
            showingBookStrip = false
            print("🛡️ SAFETY: Forcing showingBookStrip = false in ambient mode")
        }
        
        if startInVoiceMode || isAmbientMode {
            if isAmbientMode {
                voiceManager.updateLibraryBooks(libraryViewModel.books)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🎙️ Starting ambient session immediately")
                    startAmbientSession()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handleMicrophoneTap()
                }
            }
        }
    }
    
    private func handleBookContextChange(oldBook: Book?, newBook: Book?) {
        print("Book context changed from \(oldBook?.title ?? "none") to \(newBook?.title ?? "none")")
        print("New book ID: \(newBook?.localId.uuidString ?? "none")")
        print("Cover URL: \(newBook?.coverImageURL ?? "none")")
        
        if let book = newBook {
            print("Extracting colors for: \(book.title)")
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
    
    private func handleAIResponseComplete(notification: Notification) {
        guard isAmbientMode, let aiResponse = notification.object as? AIResponse else { return }
        
        let responseMessage = UnifiedChatMessage(
            content: aiResponse.answer,
            isUser: false,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        messages.append(responseMessage)
        
        if isAmbientMode {
            let aiSessionResponse = AISessionResponse(
                question: aiResponse.question,
                answer: aiResponse.answer,
                model: aiResponse.model.rawValue,
                confidence: aiResponse.confidence,
                responseTime: aiResponse.responseTime,
                timestamp: aiResponse.timestamp,
                isStreamed: aiResponse.isStreaming,
                wasFromCache: !aiResponse.isStreaming
            )
            
            if let lastQuestionIndex = sessionContent.lastIndex(where: { $0.type == .question && $0.text == aiResponse.question }) {
                var updatedContent = sessionContent[lastQuestionIndex]
                sessionContent[lastQuestionIndex] = SessionContent(
                    type: updatedContent.type,
                    text: updatedContent.text,
                    timestamp: updatedContent.timestamp,
                    confidence: updatedContent.confidence,
                    bookContext: updatedContent.bookContext,
                    aiResponse: aiSessionResponse
                )
            }
        }
    }
    
    private func handleImmediateQuestion(notification: Notification) {
        guard isAmbientMode, let data = notification.object as? [String: Any],
              let question = data["question"] as? String else { return }
        
        let bookContext = data["bookContext"] as? Book
        
        let questionMessage = UnifiedChatMessage(
            content: question,
            isUser: true,
            timestamp: Date(),
            bookContext: bookContext ?? currentBookContext
        )
        messages.append(questionMessage)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                if let lastMessage = messages.last {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
        
        if isAmbientMode {
            Task {
                await OptimizedAIResponseService.shared.processImmediateQuestion(question, bookContext: currentBookContext)
            }
        } else {
            Task {
                await getAIResponse(for: question)
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
        Group {
            if let book = currentBookContext {
                // Book-specific empty state
                BookEmptyStateView(
                    book: book,
                    colorPalette: colorPalette,
                    onSuggestionTap: { suggestion in
                        messageText = suggestion
                        isInputFocused = true
                    },
                    isAmbientMode: isAmbientMode
                )
                .environmentObject(notesViewModel)
            } else {
                // Initial empty state
                InitialEmptyStateView(
                    onSuggestionTap: { suggestion in
                        messageText = suggestion
                        isInputFocused = true
                    },
                    onSelectBook: {
                        showingBookStrip = true
                    },
                    isAmbientMode: isAmbientMode
                )
            }
        }
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
                SensoryFeedback.light()
            } label: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(Color.white.opacity(0.1))
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .overlay {
                        if currentBookContext == nil {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .stroke(DesignSystem.Colors.primaryAccent, lineWidth: 2)
                        }
                    }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Book items
            ForEach(libraryViewModel.books) { book in
                Button {
                    currentBookContext = book
                    showingBookStrip = false
                    SensoryFeedback.light()
                } label: {
                    SharedBookCoverView(
                        coverURL: book.coverImageURL,
                        width: 90,
                        height: 135
                    )
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                    .overlay {
                        if currentBookContext?.id == book.id {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .stroke(DesignSystem.Colors.primaryAccent, lineWidth: 2)
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
            SensoryFeedback.success()
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
            SensoryFeedback.success()
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
        // Track session start for auto-save
        sessionStartTime = Date()
        sessionContent.removeAll()
        
        // Create optimized session for summary
        ambientSession = OptimizedAmbientSession(
            startTime: Date(),
            bookContext: currentBookContext,
            metadata: SessionMetadata()
        )
        
        // Create SwiftData session for compatibility
        let newSession = AmbientSession(book: currentBookContext)
        currentSession = newSession
        
        // Start listening in ambient mode (with book detection)
        voiceManager.startAmbientListeningMode()
        
        // Check for resumable session
        checkForResumableSession()
        
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
        SensoryFeedback.medium()
    }
    
    private func endAmbientSession() {
        // INSTANT UI update - absolutely no waiting
        isRecording = false
        liveTranscription = ""
        detectionState = .idle
        detectedEntities.removeAll()
        
        // Stop voice immediately
        voiceManager.stopListening()
        
        // Quick haptic
        SensoryFeedback.light()
        
        // Remove transcription message immediately if present
        if let lastIndex = messages.lastIndex(where: { $0.content == "[Transcribing]" }) {
            messages.remove(at: lastIndex)
        }
        
        // INSTANT dismiss - NO DELAYS, NO PROCESSING, NO WAITING
        if isAmbientMode {
            // Just dismiss immediately - don't wait for anything
            dismiss()
        }
        
        // DON'T do any processing here - it causes the 20-second delay
        // All processing should happen in real-time, not on exit
    }
    
    // MARK: - Real-Time Progressive Processing
    
    /// Process and display content immediately - no waiting for session end!
    private func processAndDisplayImmediately(_ result: AmbientProcessedContent) async {
        await MainActor.run {
            logger.info("📱 Displaying \(String(describing: result.type)) immediately: \(result.text.prefix(30))...")
            
            // Scroll to bottom after adding message to keep chat thread visible
            let scrollToBottom = {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        if let lastMessage = messages.last {
                            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Create appropriate message based on content type
            switch result.type {
            case .quote:
                // Create and save Quote to SwiftData IMMEDIATELY
                let bookModel: BookModel? = if let book = currentBookContext {
                    BookModel(from: book)
                } else {
                    nil
                }
                
                let quoteModel = CapturedQuote(
                    text: result.text,
                    book: bookModel,
                    author: currentBookContext?.author ?? bookModel?.author,  // Use book's author
                    pageNumber: nil,  // Page number not available
                    timestamp: result.timestamp,
                    source: .ambient
                )
                
                // Insert into SwiftData immediately
                modelContext.insert(quoteModel)
                
                // Add to messages with quote type - USER SEES IT IMMEDIATELY
                messages.append(UnifiedChatMessage(
                    content: "\"\(result.text)\"",
                    isUser: false,
                    timestamp: result.timestamp,
                    bookContext: currentBookContext,
                    messageType: .quote(quoteModel)
                ))
                
                // Visual feedback - green checkmark animation
                withAnimation(DesignSystem.Animation.springStandard) {
                    // Could trigger a temporary overlay here
                    logger.info("✅ Quote saved and displayed immediately!")
                }
                
                // Scroll to show the new message
                scrollToBottom()
                
            case .question:
                // Show question immediately
                messages.append(UnifiedChatMessage(
                    content: result.text,
                    isUser: true,
                    timestamp: result.timestamp,
                    bookContext: currentBookContext
                ))
                
                // Scroll to show the question
                scrollToBottom()
                
                // AI response is handled separately by TrueAmbientProcessor
                logger.info("❓ Question displayed, awaiting AI response...")
                
            case .thought, .note:  // Map to thought and note
                // Create note with special type
                let bookModel: BookModel? = if let book = currentBookContext {
                    BookModel(from: book)
                } else {
                    nil
                }
                
                let noteModel = CapturedNote(
                    content: result.text,
                    book: bookModel,
                    timestamp: result.timestamp,
                    source: .ambient
                )
                
                modelContext.insert(noteModel)
                
                // Show as note message
                messages.append(UnifiedChatMessage(
                    content: result.text,
                    isUser: false,
                    timestamp: result.timestamp,
                    bookContext: currentBookContext,
                    messageType: .note(noteModel)
                ))
                
                logger.info("💭 \(String(describing: result.type)) saved and displayed!")
                
                // Scroll to show the new message
                scrollToBottom()
                
            case .note:
                // Simple note - save and show
                if result.text.count > 10 { // Filter out trivial notes
                    let bookModel: BookModel? = if let book = currentBookContext {
                        BookModel(from: book)
                    } else {
                        nil
                    }
                    
                    let noteModel = CapturedNote(
                        content: result.text,
                        book: bookModel,
                        timestamp: result.timestamp,
                        source: .ambient
                    )
                    
                    modelContext.insert(noteModel)
                    
                    messages.append(UnifiedChatMessage(
                        content: result.text,
                        isUser: false,
                        timestamp: result.timestamp,
                        bookContext: currentBookContext,
                        messageType: .note(noteModel)
                    ))
                    
                    logger.info("📝 Note saved and displayed!")
                    
                    // Scroll to show the new message
                    scrollToBottom()
                }
                
            case .ambient, .unknown:
                // Don't display ambient or unknown content directly
                logger.debug("Ambient/unknown content: \(result.text)")
            }
            
            // Try to save context immediately (non-blocking)
            do {
                try modelContext.save()
                logger.info("💾 SwiftData saved immediately")
            } catch {
                logger.error("Failed to save immediately: \(error)")
            }
        }
    }
    
    // MARK: - Progressive Ambient Processing
    
    private func saveToSession(_ result: AmbientProcessedContent) async {
        await MainActor.run {
            // Map content type to SessionContent.ContentType  
            let sessionContentType: SessionContent.ContentType = {
                switch result.type {
                case .question: return .question
                case .quote: return .quote
                case .thought: return .reflection  // Map thought to reflection
                case .note: return .insight  // Map note to insight
                case .ambient, .unknown: return .reaction  // Map to reaction as default
                }
            }()
            
            let content = SessionContent(
                type: sessionContentType,
                text: result.text,
                timestamp: result.timestamp,
                confidence: Float(result.confidence),
                bookContext: currentBookContext?.title,
                aiResponse: nil
            )
            
            // Add to session content
            sessionContent.append(content)
            
            // Update session if exists
            if let session = ambientSession {
                ambientSession?.allContent = sessionContent
            }
        }
    }
    
    private func handleProcessedResult(_ result: AmbientProcessedContent) async {
        // REAL-TIME PROGRESSIVE PROCESSING - Process and show immediately
        logger.info("🚀 Real-time processing: \(String(describing: result.type)) - \(result.text.prefix(50))...")
        
        // Update detection state with visual feedback
        await MainActor.run {
            withAnimation(DesignSystem.Animation.springStandard) {
                switch result.type {
                case .question:
                    detectionState = .processingQuestion
                    SensoryFeedback.light() // Immediate feedback
                case .quote:
                    detectionState = .detectingQuote
                    SensoryFeedback.medium() // Quote detected
                case .note, .thought:
                    detectionState = .savingNote
                    SensoryFeedback.light()
                case .ambient, .unknown:
                    detectionState = .idle
                }
            }
            
            // Update detected entities for visual feedback
            if result.confidence > 0.6 {
                detectedEntities.append((text: result.text, confidence: Float(result.confidence)))
                
                // Keep only recent entities
                if detectedEntities.count > 5 {
                    detectedEntities.removeFirst()
                }
            }
        }
        
        // IMMEDIATE PROCESSING - Don't wait for session end!
        await processAndDisplayImmediately(result)
        
        // Process based on content type
        if result.type == .question {  // Questions require AI response
            Task {
                let responseText = await getAIResponseForContent(result.text)
                // Create an AIResponse object from the text response
                let aiResponse = AIResponse(
                    question: result.text,
                    answer: responseText,
                    confidence: 0.85,
                    timestamp: Date(),
                    bookContext: currentBookContext,
                    model: .sonar,
                    responseTime: 0.5,
                    isStreaming: false
                )
                await showAIResponse(aiResponse)
            }
        }
        
        // Save the content to session
        await saveToSession(result)
        
        // Reset detection state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                self.detectionState = .idle
            }
        }
    }
    
    // DEPRECATED - SmartContentBuffer and ImprovedUnifiedProcessor replaced by TrueAmbientProcessor
    
    
    // MARK: - Real-time Content Display Methods
    
    private func showQuestionImmediately(_ content: AmbientProcessedContent) async {
        await MainActor.run {
            // Remove processing indicator
            if let lastMessage = messages.last, lastMessage.content == "Processing question..." {
                messages.removeLast()
            }
            
            // Add the actual question
            let questionMessage = UnifiedChatMessage(
                content: content.text,
                isUser: true,
                timestamp: content.timestamp,
                bookContext: currentBookContext  // Use current book context
            )
            messages.append(questionMessage)
            
            // Track in session
            trackSessionContent(type: .question, text: content.text)
            
            // Scroll to show question
            withAnimation {
                scrollProxy?.scrollTo(questionMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func getAIResponseForContent(_ text: String) async -> String {
        let aiService = AICompanionService.shared
        
        guard aiService.isConfigured() else {
            return "Please configure your AI service."
        }
        
        do {
            let response = try await aiService.processMessage(
                text,
                bookContext: currentBookContext,
                conversationHistory: filteredMessages
            )
            return response
        } catch {
            return "Sorry, I couldn't process your question."
        }
    }
    
    private func showAIResponse(_ response: AIResponse) async {
        await MainActor.run {
            logger.info("🤖 Displaying AI response in real-time: \(response.answer.prefix(50))...")
            
            let aiMessage = UnifiedChatMessage(
                content: response.answer,
                isUser: false,
                timestamp: Date(),
                bookContext: currentBookContext
            )
            messages.append(aiMessage)
            
            // Visual feedback for AI response
            SensoryFeedback.medium()
            
            // Smooth scroll to show response
            withAnimation(DesignSystem.Animation.springStandard) {
                scrollProxy?.scrollTo(aiMessage.id, anchor: .bottom)
            }
            
            // Clear processing state
            detectionState = .idle
        }
    }
    
    private func saveQuote(_ content: AmbientProcessedContent) async {
        await MainActor.run {
            // Remove processing indicator
            if let lastMessage = messages.last, lastMessage.content == "Capturing quote..." {
                messages.removeLast()
            }
            
            // Create BookModel if needed
            var bookModel: BookModel? = nil
            if let book = currentBookContext {  // Use current book context
                bookModel = BookModel(from: book)
                modelContext.insert(bookModel!)
            }
            
            // Create and save quote
            let capturedQuote = CapturedQuote(
                text: content.text,
                book: bookModel,
                timestamp: content.timestamp,
                source: .ambient
            )
            
            modelContext.insert(capturedQuote)
            
            do {
                try modelContext.save()
                print("✅ Quote saved: \(content.text)")
                
                // Track in session
                trackSessionContent(type: .quote, text: content.text)
            } catch {
                print("❌ Failed to save quote: \(error)")
            }
        }
    }
    
    private func showQuoteCard(_ content: AmbientProcessedContent) async {
        await MainActor.run {
            // Find the saved quote
            let searchText = content.text
            let quotes = try? modelContext.fetch(
                FetchDescriptor<CapturedQuote>(
                    predicate: #Predicate { quote in
                        quote.text == searchText
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            )
            
            if let capturedQuote = quotes?.first {
                // Add quote card with quick actions
                let quoteMessage = UnifiedChatMessage(
                    content: "\"\(content.text)\"",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext,
                    messageType: .quote(capturedQuote)
                )
                messages.append(quoteMessage)
                
                // Update detection state to saved
                withAnimation(DesignSystem.Animation.springStandard) {
                    detectionState = .saved
                }
                
                // Reset after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.detectionState = .idle
                    }
                }
                
                // Haptic feedback
                SensoryFeedback.success()
                
                // Scroll to show quote
                withAnimation {
                    scrollProxy?.scrollTo(quoteMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private func saveNote(_ content: AmbientProcessedContent) async {
        await MainActor.run {
            // Remove processing indicator
            if let lastMessage = messages.last, lastMessage.content == "Saving note..." {
                messages.removeLast()
            }
            
            // Create BookModel if needed
            var bookModel: BookModel? = nil
            if let book = currentBookContext {  // Use current book context
                bookModel = BookModel(from: book)
                modelContext.insert(bookModel!)
            }
            
            // Create and save note
            let capturedNote = CapturedNote(
                content: content.text,
                book: bookModel,
                timestamp: content.timestamp,
                source: .ambient
            )
            
            modelContext.insert(capturedNote)
            
            do {
                try modelContext.save()
                print("✅ Note saved: \(content.text)")
                
                // Track in session
                trackSessionContent(type: content.type == .thought ? .reflection : .insight, text: content.text)
            } catch {
                print("❌ Failed to save note: \(error)")
            }
        }
    }
    
    private func showNoteCard(_ content: AmbientProcessedContent) async {
        await MainActor.run {
            // Find the saved note
            let searchText = content.text
            let notes = try? modelContext.fetch(
                FetchDescriptor<CapturedNote>(
                    predicate: #Predicate { note in
                        note.content == searchText
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            )
            
            if let capturedNote = notes?.first {
                // Check if we should provide context
                if shouldProvideContext(for: content.text),
                   let context = generateContextualInfo(for: content.text, book: currentBookContext) {
                    // Add note with context
                    let noteMessage = UnifiedChatMessage(
                        content: content.text,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .noteWithContext(capturedNote, context: context)
                    )
                    messages.append(noteMessage)
                } else {
                    // Add regular note
                    let noteMessage = UnifiedChatMessage(
                        content: content.text,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .note(capturedNote)
                    )
                    messages.append(noteMessage)
                }
                
                // Haptic feedback
                SensoryFeedback.success()
                
                // Scroll to show note
                withAnimation {
                    if let lastMessage = messages.last {
                        scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Legacy Transcription Processing (for backward compatibility)
    
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
            var extractedQuoteText: String? = nil
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
                            // Track for session summary
                            if isAmbientMode {
                                trackSessionContent(type: .quote, text: quoteText)
                            }
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
                    // Track for session summary
                    if isAmbientMode {
                        trackSessionContent(type: .quote, text: quoteText)
                    }
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
                    // Track for session summary
                    if isAmbientMode {
                        trackSessionContent(type: .quote, text: quotedContent)
                    }
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
                    timestamp: Date(),
                    response: nil  // Will be filled in later if AI responds
                ))
                // Track for session summary
                if isAmbientMode {
                    trackSessionContent(type: .question, text: trimmed)
                }
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
                // Track for session summary
                if isAmbientMode {
                    let contentType: SessionContent.ContentType
                    switch noteType {
                    case .reflection:
                        contentType = .reflection
                    case .insight:
                        contentType = .insight
                    case .connection:
                        contentType = .connection
                    }
                    trackSessionContent(type: contentType, text: noteText)
                }
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
    
    private func shouldOfferAIResponse(for text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Check for conversational patterns that might benefit from AI response
        let conversationalTriggers = [
            "i think", "i feel", "i wonder", "what do you think",
            "this makes me", "this reminds me", "i don't understand",
            "this is interesting", "this is confusing", "help me",
            "can you", "what does", "why does", "how does"
        ]
        
        return conversationalTriggers.contains { trigger in
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
    
    // MARK: - Quick Action Handlers
    
    private func handleContentEdit(message: UnifiedChatMessage, newText: String) {
        // Update the content based on message type
        switch message.messageType {
        case .quote(let quote):
            // Update quote in SwiftData
            quote.text = newText
            do {
                try modelContext.save()
                SensoryFeedback.success()
            } catch {
                print("Failed to update quote: \(error)")
            }
            
        case .note(let note), .noteWithContext(let note, _):
            // Update note in SwiftData
            note.content = newText
            do {
                try modelContext.save()
                SensoryFeedback.success()
            } catch {
                print("Failed to update note: \(error)")
            }
            
        default:
            break
        }
    }
    
    private func refineQuestion(message: UnifiedChatMessage) {
        // Create a refined version of the question
        let refinedPrompt = "Can you help me refine this question for clarity: \(message.content)"
        
        Task {
            await getAIResponse(for: refinedPrompt)
        }
    }
    
    private func expandNote(message: UnifiedChatMessage) {
        // Expand on the note with AI assistance
        if case .note(let note) = message.messageType {
            let expandPrompt = "Can you help me expand on this thought: \(note.content)"
            
            Task {
                await getAIResponse(for: expandPrompt)
            }
        }
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
            // Use SharedBookCoverManager for cached loading
            guard let uiImage = await SharedBookCoverManager.shared.loadFullImage(from: secureURLString) else {
                print("Failed to load image from SharedBookCoverManager")
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
            primary: DesignSystem.Colors.primaryAccent.opacity(0.8),     // Warm amber
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


// MARK: - Detection Indicator

struct DetectionIndicator: View {
    let state: UnifiedChatView.DetectionState
    let adaptiveUIColor: Color
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Pulsing background
            Circle()
                .fill(state.color.opacity(0.2))
                .frame(width: 32, height: 32)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.0 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // Icon
            Image(systemName: state.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(state.color)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            if state != .idle && state != .saved {
                isAnimating = true
            }
        }
        .onChange(of: state) { _, newState in
            isAnimating = (newState != .idle && newState != .saved)
        }
    }
}

// MARK: - Real-Time Processing Indicator

struct ProcessingIndicator: View {
    let state: UnifiedChatView.DetectionState
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: state.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(state.color)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
            
            Text(state.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(state.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(state.color.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(state.color.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - ViewHeightKey for auto-expanding text
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}


// MARK: - Live Transcription View (Legacy)

struct LiveTranscriptionView: View {
    let transcription: String
    let adaptiveUIColor: Color
    var isTranscribing: Bool = true
    var onCancel: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Listening indicator
            ZStack {
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
                
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(adaptiveUIColor)
            }
            .frame(width: 36, height: 36)
            
            Text(transcription)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let onCancel = onCancel {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textQuaternary, .white.opacity(0.1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 24))
        .overlay {
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

// MARK: - Message With Quick Actions

struct MessageWithQuickActions: View {
    let message: UnifiedChatMessage
    let currentBookContext: Book?
    let colorPalette: ColorPalette?
    let onEdit: (String) -> Void
    let onRefine: () -> Void
    let onExpand: () -> Void
    
    @State private var showActions = false
    @State private var isEditing = false
    @State private var editedText = ""
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            // Original message view
            ChatMessageView(
                message: message,
                currentBookContext: currentBookContext,
                colorPalette: colorPalette
            )
            .onLongPressGesture {
                withAnimation(DesignSystem.Animation.springStandard) {
                    showActions.toggle()
                    SensoryFeedback.light()
                }
            }
            
            // Quick actions overlay
            if showActions {
                HStack(spacing: 12) {
                    // Edit action (for quotes and notes)
                    if case .text = message.messageType {
                        QuickActionButton(
                            icon: "pencil.circle.fill",
                            label: "Edit",
                            color: .blue
                        ) {
                            isEditing = true
                            editedText = message.content
                        }
                    }
                    
                    // Refine action (for questions)
                    if message.isUser && message.content.contains("?") {
                        QuickActionButton(
                            icon: "arrow.triangle.2.circlepath",
                            label: "Refine",
                            color: .purple
                        ) {
                            onRefine()
                        }
                    }
                    
                    // Expand action (for notes)
                    if case .note = message.messageType {
                        QuickActionButton(
                            icon: "arrow.up.left.and.arrow.down.right",
                            label: "Expand",
                            color: .orange
                        ) {
                            onExpand()
                        }
                    }
                    
                    // Dismiss actions
                    QuickActionButton(
                        icon: "xmark.circle.fill",
                        label: "Close",
                        color: .gray
                    ) {
                        withAnimation {
                            showActions = false
                        }
                    }
                }
                .padding(.horizontal, message.isUser ? 0 : 20)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: message.isUser ? .topTrailing : .topLeading)
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: message.isUser ? .topTrailing : .topLeading)
                        .combined(with: .opacity)
                ))
            }
        }
        .overlay {
            if isEditing {
                EditContentOverlay(
                    originalText: message.content,
                    editedText: $editedText,
                    isPresented: $isEditing,
                    onSave: {
                        onEdit(editedText)
                        showActions = false
                    }
                )
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(width: 50, height: 50)
            .glassEffect(in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

struct EditContentOverlay: View {
    let originalText: String
    @Binding var editedText: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark backdrop - visible like LiquidCommandPalette
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPresented = false
                        SensoryFeedback.light()
                    }
                
                VStack {
                    Spacer()
                    
                    // Clean input bar - just text field and arrow button
                    HStack(alignment: .bottom, spacing: 12) {
                        // Text input field with the content already loaded
                        TextField("", text: $editedText, axis: .vertical)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.white)
                            .tint(DesignSystem.Colors.primaryAccent)
                            .focused($isFocused)
                            .lineLimit(1...8) // Allow vertical expansion
                            .textFieldStyle(.plain)
                            .padding(.vertical, 12)
                            .padding(.leading, 16)
                        
                        // Single arrow button for save/submit
                        Button {
                            if editedText != originalText && !editedText.isEmpty {
                                SensoryFeedback.success()
                                onSave()
                                isPresented = false
                            } else if editedText.isEmpty {
                                // If empty, just close
                                SensoryFeedback.light()
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(
                                    editedText != originalText && !editedText.isEmpty
                                        ? DesignSystem.Colors.primaryAccent
                                        : DesignSystem.Colors.textQuaternary
                                )
                                .padding(.trailing, 16)
                                .padding(.vertical, 12)
                        }
                        .disabled(editedText == originalText || editedText.isEmpty)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(red: 0.12, green: 0.11, blue: 0.105))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.bottom, keyboardHeight > 0 ? 20 : 30) // Adjust padding when keyboard shown
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
                .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .ignoresSafeArea(.container, edges: .top) // Only ignore top safe area
        .onAppear {
            // Text is already populated with originalText via binding
            withAnimation(.easeOut(duration: 0.2)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
            
            // Subscribe to keyboard notifications
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = keyboardFrame.height
                    }
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
        }
    }
}

// MARK: - Voice-Responsive Bottom Gradient

struct VoiceResponsiveBottomGradient: View {
    let colorPalette: ColorPalette?
    let audioLevel: Float
    let isRecording: Bool
    let bookContext: Book?
    
    @State private var pulsePhase: Double = 0
    @State private var waveOffset: Double = 0
    
    private var gradientColors: [Color] {
        guard let palette = colorPalette else {
            // Fallback to warm amber gradient
            return [
                DesignSystem.Colors.primaryAccent.opacity(0.6),
                Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.4),
                Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.2),
                Color.clear
            ]
        }
        
        // Use enhanced colors from book palette with stronger opacity
        return [
            palette.primary.opacity(0.85),
            palette.secondary.opacity(0.65), 
            palette.accent.opacity(0.4),
            Color.clear
        ]
    }
    
    private func gradientHeight(for screenHeight: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 240 // Slightly lower base
        
        // Apply logarithmic curve to make it more sensitive to lower volumes
        // This amplifies quiet sounds more than loud ones
        let normalizedAudio = min(audioLevel, 1.0) // Ensure it's capped at 1.0
        let amplifiedLevel = log10(1 + normalizedAudio * 9) // Log curve: more boost at low levels
        
        let audioBoost = CGFloat(amplifiedLevel) * 200 // Increased multiplier for visibility
        let maxHeight: CGFloat = screenHeight * 0.35 // Cap at 35% of screen (reduced from 40%)
        return min(baseHeight + audioBoost, maxHeight)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // Voice-responsive gradient
                LinearGradient(
                    stops: [
                        .init(color: gradientColors[0], location: 0.0),
                        .init(color: gradientColors[1], location: 0.3),
                        .init(color: gradientColors[2], location: 0.6),
                        .init(color: gradientColors[3], location: 1.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: gradientHeight(for: geometry.size.height))
                .blur(radius: 20)
                .opacity(isRecording ? 1.0 : 0.0)
                .scaleEffect(y: 1.0 + Double(min(log10(1 + audioLevel * 9), 1.0)) * 0.6, anchor: .bottom) // More sensitive scale with log curve
                .animation(.easeInOut(duration: 0.1), value: audioLevel)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRecording)
                
                // Add subtle wave animation
                .overlay(alignment: .bottom) {
                    if isRecording {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        gradientColors[0].opacity(0.3),
                                        gradientColors[1].opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: 60)
                            .blur(radius: 15)
                            .offset(y: sin(waveOffset) * 10)
                            .animation(
                                .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                                value: waveOffset
                            )
                    }
                }
            }
        }
        .onAppear {
            // Start wave animation
            withAnimation {
                waveOffset = .pi
            }
        }
        .onChange(of: audioLevel) { _, newLevel in
            // Pulse effect on high audio levels
            if newLevel > 0.3 {
                withAnimation(DesignSystem.Animation.easeQuick) {
                    pulsePhase = pulsePhase + 0.5
                }
            }
        }
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
                    .init(color: DesignSystem.Colors.primaryAccent.opacity(0.4), location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.25), location: 0.15),
                    .init(color: Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.15), location: 0.3),
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
                .foregroundStyle(DesignSystem.Colors.primaryAccent)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .onTapGesture {
                    showingCommandPalette = true
                }
            
            // Text input
            ZStack(alignment: .leading) {
                if messageText.isEmpty {
                    Text(placeholderText)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
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
                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    } else {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                
                // Send button
                if !messageText.isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, DesignSystem.Colors.primaryAccent)
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
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primaryAccent.opacity(0.3),
                            DesignSystem.Colors.primaryAccent.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .animation(DesignSystem.Animation.springStandard, value: messageText.isEmpty)
    }
}

// MARK: - Extensions for UnifiedChatView

extension UnifiedChatView {
    // MARK: - Ambient Welcome View
    
    private var ambientWelcomeView: some View {
        VStack(spacing: 32) {
            // Animated waveform visualization
            HStack(spacing: 4) {
                ForEach(0..<7) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primaryAccent,
                                    Color(red: 1.0, green: 0.45, blue: 0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: CGFloat.random(in: 20...60))
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                            value: isRecording
                        )
                }
            }
            .frame(height: 60)
            
            VStack(spacing: 12) {
                Text("Listening...")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white)
                
                Text("Just start talking about what you're reading")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - Book Context Pill
    
    private var bookContextPill: some View {
        HStack(spacing: 6) {
            if let book = currentBookContext {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Text(book.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .padding(.top, 60)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
    }
    
    // MARK: - Ambient Mode Exit Button
    
    private var ambientModeExitButton: some View {
        Button {
            // Save session before closing
            if let session = ambientSession {
                var updatedSession = session
                updatedSession.endTime = Date()
                updatedSession.allContent = sessionContent
                
                // Auto-save session data
                if !sessionContent.isEmpty {
                    autoSaveShortSession(updatedSession)
                }
            }
            
            // Stop voice if active
            if isRecording {
                handleMicrophoneTap()
            }
            
            // Dismiss via coordinator
            SimplifiedAmbientCoordinator.shared.closeAmbientReading()
            
            // Also dismiss locally
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .glassEffect(in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                }
        }
        .padding(.top, 20)
        .padding(.leading, 20)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
    }
    
    // MARK: - Session Management Helpers
    
    private func checkForResumableSession() {
        // Check for recent incomplete session for this book
        if let book = currentBookContext {
            let recentSessions = SessionHistoryData.loadForBook(book.id)
            if let lastSession = recentSessions.last,
               Date().timeIntervalSince(lastSession.endTime) < 3600 { // Within last hour
                // Offer to resume
                let resumeMessage = UnifiedChatMessage(
                    content: "Welcome back! Continuing from your last session \(formatTimeAgo(lastSession.endTime)) ago.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: book,
                    messageType: .system
                )
                messages.append(resumeMessage)
            }
        }
    }
    
    private func autoSaveShortSession(_ session: OptimizedAmbientSession) {
        // Auto-save even short sessions for continuity
        Task {
            let sessionData = SessionHistoryData(
                id: session.id,
                bookId: session.bookContext?.id,
                bookTitle: session.bookContext?.title ?? "General Reading",
                startTime: session.startTime,
                endTime: session.endTime ?? Date(),
                duration: session.duration,
                questionCount: session.totalQuestions,
                quoteCount: session.allContent.filter { $0.type == .quote }.count,
                insightCount: session.allContent.filter { $0.type == .insight }.count,
                mood: session.metadata.mood.rawValue,
                clusters: [],
                allContent: session.allContent.map { 
                    SessionHistoryData.ContentSummary(
                        type: $0.type.rawValue,
                        text: $0.text,
                        timestamp: $0.timestamp
                    )
                }
            )
            
            var sessions = SessionHistoryData.loadAll()
            sessions.append(sessionData)
            
            // Keep only last 50 sessions
            if sessions.count > 50 {
                sessions = Array(sessions.suffix(50))
            }
            
            SessionHistoryData.saveAll(sessions)
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        
        if minutes < 1 {
            return "moments"
        } else if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    private func trackSessionContent(type: SessionContent.ContentType, text: String, aiResponse: AISessionResponse? = nil) {
        let content = SessionContent(
            type: type,
            text: text,
            timestamp: Date(),
            confidence: 0.8,
            bookContext: currentBookContext?.title,
            aiResponse: aiResponse
        )
        sessionContent.append(content)
        
        // Update session
        ambientSession?.allContent = sessionContent
    }
}


// MARK: - View Extension for Conditional Modifiers

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func ambientModeModifiers(isAmbientMode: Bool, dismiss: DismissAction, handleMicrophoneTap: @escaping () -> Void) -> some View {
        if isAmbientMode {
            self
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            // Swipe down to dismiss
                            if value.translation.height > 100 && abs(value.translation.width) < 100 {
                                SimplifiedAmbientCoordinator.shared.closeAmbientReading()
                                dismiss()
                            }
                        }
                )
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    UnifiedChatView()
        .environmentObject(LibraryViewModel())
}