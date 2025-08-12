import SwiftUI
import SwiftData

// MARK: - Main Ambient Mode View (EXACT UnifiedChatView Structure)
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
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
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
            
            // Main scroll content - EXACT structure
            mainScrollContent
            
            // Voice gradient overlay when recording
            voiceGradientOverlay
        }
        // Input bar at bottom - EXACT from UnifiedChatView
        .safeAreaInset(edge: .bottom) {
            if !isRecording {
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
        // Exit button overlay
        .overlay(alignment: .topLeading) {
            ambientModeExitButton
        }
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
    
    // MARK: - Gradient Background (VIBRANT VOICE-RESPONSIVE)
    @ViewBuilder
    private var gradientBackground: some View {
        ZStack {
            // Always show base gradient
            if let book = currentBookContext, let palette = colorPalette {
                // Book-specific VIBRANT gradient
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: 1.0 // FULL intensity for vibrant colors
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 1.5), value: colorPalette)
            } else {
                // Default VIBRANT amber gradient
                LinearGradient(
                    stops: [
                        .init(color: Color.black, location: 0.0),
                        .init(color: Color.black.opacity(0.95), location: 0.3),
                        .init(color: Color(red: 0.4, green: 0.1, blue: 0.05), location: 0.5),
                        .init(color: Color(red: 0.8, green: 0.3, blue: 0.15), location: 0.7),
                        .init(color: Color(red: 1.0, green: 0.55, blue: 0.26), location: 0.85),
                        .init(color: Color(red: 1.0, green: 0.65, blue: 0.35), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            
            // Voice-responsive overlay gradient
            if isRecording {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.clear,
                        Color(red: 1.0, green: 0.55, blue: 0.26).opacity(Double(audioLevel) * 0.3),
                        Color(red: 1.0, green: 0.45, blue: 0.2).opacity(Double(audioLevel) * 0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
    }
    
    // MARK: - Main Scroll Content (EXACT structure from UnifiedChatView)
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
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Ambient Welcome View (EXACT from UnifiedChatView)
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
    
    // MARK: - Voice Gradient Overlay (when recording)
    @ViewBuilder
    private var voiceGradientOverlay: some View {
        if isRecording {
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
    }
    
    private func stopRecording() {
        isRecording = false
        voiceManager.stopListening()
        liveTranscription = ""
        HapticManager.shared.lightTap()
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
    }
    
    private func handleAIResponse(_ notification: Notification) {
        guard let content = notification.object as? AmbientProcessedContent else { return }
        HapticManager.shared.lightTap()
    }
    
    private func generatePlaceholderPalette(for book: Book) -> ColorPalette {
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