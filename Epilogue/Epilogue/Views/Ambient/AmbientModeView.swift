import SwiftUI
import SwiftData

// MARK: - Fixed Ambient Mode View with Beautiful Gradients
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
            // EXACT gradient structure from UnifiedChatView
            gradientBackground
            
            // Main scroll content
            mainScrollContent
            
            // Voice gradient overlay at bottom when recording
            voiceGradientOverlay
        }
        // Input bar at bottom
        .safeAreaInset(edge: .bottom) {
            if !isRecording {
                bottomInputArea
            }
        }
        // Exit button overlay
        .overlay(alignment: .topLeading) {
            ambientModeExitButton
        }
        .statusBarHidden(true)
        .onAppear {
            startAmbientExperience()
        }
        .onChange(of: processor.detectedContent.count) { _, _ in
            processDetectedContent(processor.detectedContent)
        }
        .onReceive(bookDetector.$detectedBook) { book in
            handleBookDetection(book)
        }
        .onReceive(voiceManager.$transcribedText) { text in
            liveTranscription = text
            // Check for book mentions in transcript
            if !text.isEmpty {
                bookDetector.detectBookInText(text)
            }
        }
        .onReceive(voiceManager.$currentAmplitude) { amplitude in
            audioLevel = amplitude
        }
        .onReceive(NotificationCenter.default.publisher(for: .questionProcessed)) { notification in
            handleAIResponse(notification)
        }
    }
    
    // MARK: - Gradient Background (EXACT from UnifiedChatView)
    @ViewBuilder
    private var gradientBackground: some View {
        if isRecording, let book = currentBookContext {
            // Use the breathing gradient during recording with book context
            let palette = colorPalette ?? generatePlaceholderPalette(for: book)
            BookAtmosphericGradientView(
                colorPalette: palette, 
                intensity: 0.9 + Double(audioLevel) * 0.3, // Audio-reactive intensity
                audioLevel: audioLevel
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
            BookAtmosphericGradientView(
                colorPalette: palette, 
                intensity: 0.85,
                audioLevel: 0
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
                .id(book.localId)
        } else {
            // Use existing ambient gradient for empty state
            AmbientChatGradientView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }
    
    // MARK: - Voice Gradient Overlay (CRITICAL FOR BOTTOM GRADIENT)
    @ViewBuilder
    private var voiceGradientOverlay: some View {
        if isRecording {
            VStack {
                Spacer()
                
                // Bottom voice-responsive gradient
                VoiceResponsiveBottomGradient(
                    colorPalette: colorPalette,
                    audioLevel: audioLevel,
                    isRecording: isRecording,
                    bookContext: currentBookContext
                )
                .allowsHitTesting(false)
                .frame(height: 300)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            }
            .ignoresSafeArea()
            
            // Recording UI overlay
            VStack {
                Spacer()
                
                // Book context pill
                if let book = currentBookContext {
                    bookContextPill(for: book)
                        .padding(.bottom, 20)
                }
                
                // Transcription view
                if !liveTranscription.isEmpty {
                    VStack(spacing: 12) {
                        Text(liveTranscription)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                                .symbolEffect(.pulse, value: isRecording)
                            
                            Text("Transcribing...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)
                }
                
                // Stop button
                Button {
                    stopRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 72, height: 72)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 60)
            }
        }
    }
    
    // MARK: - Main Scroll Content
    @ViewBuilder
    private var mainScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Check if we only have transcribing messages (not real content)
                    let hasRealContent = messages.contains { msg in
                        !msg.content.contains("[Transcribing]")
                    }
                    
                    if !hasRealContent {
                        if currentBookContext == nil && !isRecording {
                            // Show elegant welcome prompt for ambient mode
                            ambientWelcomeView
                                .padding(.top, 100)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.98).combined(with: .opacity),
                                    removal: .scale(scale: 1.02).combined(with: .opacity)
                                ))
                        } else {
                            // Show empty state with book
                            emptyStateView
                                .padding(.top, 100)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.98).combined(with: .opacity),
                                    removal: .scale(scale: 1.02).combined(with: .opacity)
                                ))
                        }
                    }
                    
                    // Always show messages if they exist
                    messagesListView
                    
                    // Show persistent thread indicator
                    if !messages.isEmpty {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("Chat thread persists across books")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .contentShape(Rectangle())
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Bottom Input Area
    @ViewBuilder
    private var bottomInputArea: some View {
        VStack(spacing: 0) {
            // Recording indicators
            if isRecording {
                recordingIndicators
            }
            
            UniversalInputBar(
                messageText: $messageText,
                showingCommandPalette: $showingCommandPalette,
                isInputFocused: $isInputFocused,
                context: .chat(book: currentBookContext),
                onSend: sendMessage,
                onMicrophoneTap: handleMicrophoneTap,
                isRecording: $isRecording,
                colorPalette: colorPalette,
                isAmbientMode: true
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Recording Indicators
    @ViewBuilder
    private var recordingIndicators: some View {
        VStack(spacing: 12) {
            // Detection indicator and hint
            if detectionState != .idle {
                HStack(spacing: 12) {
                    AmbientDetectionIndicator(
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
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8)
    }
    
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
                                    Color(red: 1.0, green: 0.55, blue: 0.26),
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
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - Empty State View (with book)
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
                    isAmbientMode: true
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
                        // In ambient mode, we don't select books manually
                    },
                    isAmbientMode: true
                )
            }
        }
    }
    
    // MARK: - Messages List
    private var messagesListView: some View {
        ForEach(messages) { message in
            ChatMessageView(
                message: message,
                currentBookContext: currentBookContext,
                colorPalette: colorPalette ?? defaultColorPalette
            )
            .id(message.id)
        }
    }
    
    // MARK: - Book Context Pill
    private func bookContextPill(for book: Book) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            
            Text(book.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Exit Button
    private var ambientModeExitButton: some View {
        Button {
            exitInstantly()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.6))
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
        }
        .padding(.leading, 20)
        .padding(.top, 60)
    }
    
    // MARK: - Actions
    
    private func startAmbientExperience() {
        processor.setModelContext(modelContext)
        processor.startSession()
        
        // Set up book detection with library books
        bookDetector.updateLibrary(libraryViewModel.books)
        
        // Auto-start recording after delay
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
        
        // Add temporary transcription message
        let transcriptionMessage = UnifiedChatMessage(
            content: "[Transcribing]",
            isUser: true,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        messages.append(transcriptionMessage)
    }
    
    private func stopRecording() {
        isRecording = false
        voiceManager.stopListening()
        liveTranscription = ""
        HapticManager.shared.lightTap()
        
        // Remove transcription message
        if let lastIndex = messages.lastIndex(where: { $0.content == "[Transcribing]" }) {
            messages.remove(at: lastIndex)
        }
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
        
        // Get AI response
        Task {
            await getAIResponse(for: messageText)
        }
        
        messageText = ""
    }
    
    private func getAIResponse(for text: String) async {
        // Add AI response processing here
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
    
    private func exitInstantly() {
        isRecording = false
        voiceManager.stopListening()
        dismiss()
        
        Task.detached {
            await processor.endSession()
            await AmbientLiveActivityManager.shared.endActivity()
        }
    }
    
    private func processDetectedContent(_ content: [AmbientProcessedContent]) {
        for item in content {
            if !messages.contains(where: { $0.content == item.text }) {
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
                
                let message = UnifiedChatMessage(
                    content: item.text,
                    isUser: true,
                    timestamp: item.timestamp,
                    bookContext: currentBookContext
                )
                messages.append(message)
                
                if let response = item.response {
                    let aiMessage = UnifiedChatMessage(
                        content: response,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(aiMessage)
                }
                
                // Reset detection state after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        detectionState = .idle
                    }
                }
            }
        }
    }
    
    private func handleBookDetection(_ book: Book?) {
        guard let book = book else { return }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentBookContext = book
        }
        
        Task {
            await extractColorsForBook(book)
        }
    }
    
    private func extractColorsForBook(_ book: Book) async {
        // Check cache first
        let bookID = book.localId.uuidString
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.colorPalette = cachedPalette
                }
            }
            return
        }
        
        guard let coverURLString = book.coverImageURL,
              let coverURL = URL(string: coverURLString),
              let imageData = try? await URLSession.shared.data(from: coverURL).0,
              let image = UIImage(data: imageData) else { return }
        
        let extractor = OKLABColorExtractor()
        let palette = try? await extractor.extractPalette(from: image)
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 1.5)) {
                self.colorPalette = palette
                self.coverImage = image
            }
        }
        
        // Cache the result
        if let palette = palette {
            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
        }
    }
    
    private func handleAIResponse(_ notification: Notification) {
        guard let content = notification.object as? AmbientProcessedContent else { return }
        HapticManager.shared.lightTap()
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
}

// MARK: - Ambient Detection Indicator
struct AmbientDetectionIndicator: View {
    let state: AmbientModeView.DetectionState
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