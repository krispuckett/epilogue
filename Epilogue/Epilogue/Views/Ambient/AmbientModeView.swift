import SwiftUI
import SwiftData
import Combine
import OSLog
import UIKit
import Vision
import PhotosUI

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientModeView")

// MARK: - Scrolling Book Messages for Loading State
struct ScrollingBookMessages: View {
    @State private var currentMessageIndex = 0
    @State private var opacity: Double = 1.0
    @State private var usedIndices: Set<Int> = []
    
    let messages = [
        // Literary and bookish phrases
        "Reading between the lines...",
        "Consulting the archives...",
        "Searching ancient texts...",
        "Analyzing the narrative...",
        "Cross-referencing chapters...",
        "Studying the lore...",
        "Unraveling the story...",
        "Decoding the metaphors...",
        "Following the plot threads...",
        "Examining character arcs...",
        "Parsing the prose...",
        "Exploring the themes...",
        "Mapping the world...",
        "Tracing the timeline...",
        "Uncovering hidden meanings...",
        "Connecting the dots...",
        "Diving into the subtext...",
        "Illuminating the passage...",
        "Consulting my notes...",
        "Checking the appendices...",
        "Reviewing the canon...",
        "Scanning the margins...",
        "Flipping through pages...",
        "Pondering the symbolism...",
        "Seeking wisdom...",
        "Gathering insights...",
        "Weaving understanding...",
        "Building connections...",
        "Finding the answer...",
        "Contemplating deeply..."
    ]
    
    var body: some View {
        Text(messages[currentMessageIndex])
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.4), value: opacity)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false) // Keep text on single line
            .onAppear {
                // Start with a random message
                currentMessageIndex = Int.random(in: 0..<messages.count)
                usedIndices.insert(currentMessageIndex)
                startCycling()
            }
    }
    
    private func startCycling() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Get next random message, avoiding recently used ones
                let nextIndex = getNextRandomIndex()
                currentMessageIndex = nextIndex
                usedIndices.insert(nextIndex)
                
                // Reset used indices if we've used more than half
                if usedIndices.count > messages.count / 2 {
                    let currentIndex = currentMessageIndex
                    usedIndices.removeAll()
                    usedIndices.insert(currentIndex)
                }
                
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                }
            }
        }
    }
    
    private func getNextRandomIndex() -> Int {
        var availableIndices = Array(0..<messages.count).filter { !usedIndices.contains($0) }
        
        // If all have been used, reset and exclude current
        if availableIndices.isEmpty {
            availableIndices = Array(0..<messages.count).filter { $0 != currentMessageIndex }
        }
        
        return availableIndices.randomElement() ?? 0
    }
}

// MARK: - Fixed Ambient Mode View (Keeping Original Gradients!)
struct AmbientModeView: View {
    @StateObject private var processor = TrueAmbientProcessor.shared
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var bookDetector = AmbientBookDetector.shared
    
    // Namespace for matched geometry morphing animation
    @Namespace private var buttonMorphNamespace
    
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
    @State private var savedItemType: String? = nil
    @State private var showBookCover = false
    @State private var showBookSelector = false
    @State private var bookCoverTimer: Timer?
    @State private var expandedMessageIds = Set<UUID>()  // Track expanded messages individually
    @State private var showImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var showQuoteHighlighter = false
    @State private var processedContentHashes = Set<String>() // Deduplication
    @State private var transcriptionFadeTimer: Timer?
    @State private var isTranscriptionDissolving = false
    @State private var currentSession: AmbientSession?
    @State private var showingSessionSummary = false
    @State private var sessionStartTime: Date?
    @State private var isEditingTranscription = false
    @State private var editableTranscription = ""
    @FocusState private var isTranscriptionFocused: Bool
    // Removed: isWaitingForAIResponse and shouldCollapseThinking - now using inline thinking messages
    @State private var pendingQuestion: String?
    @State private var lastProcessedCount = 0
    @State private var debounceTimer: Timer?
    
    // New keyboard input states
    @State private var inputMode: AmbientInputMode = .listening
    @State private var keyboardText = ""
    @State private var containerBlur: Double = 0
    @State private var submitBlurWave: Double = 0
    @State private var textFieldHeight: CGFloat = 44  // Track dynamic height, starts compact at single line
    @State private var lastCharacterCount: Int = 0
    @State private var breathingTimer: Timer?
    @Namespace private var morphingNamespace  // For smooth morphing animation
    @FocusState private var isKeyboardFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    // Smooth gradient transitions
    @State private var gradientOpacity: Double = 0
    @State private var lastBookId: UUID? = nil
    
    // Inline editing states
    @State private var editingMessageId: UUID? = nil
    @State private var editingMessageType: UnifiedChatMessage.MessageType? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    // Settings
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("showLiveTranscriptionBubble") private var showLiveTranscriptionBubble = true
    
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
    
    // Input mode for keyboard/voice switching
    enum AmbientInputMode {
        case listening          // Voice active
        case paused            // Voice paused, ready for input
        case textInput         // Keyboard active
        
        var isTextInput: Bool {
            self == .textInput
        }
    }
    
    // Adaptive UI color based on current palette
    private var adaptiveUIColor: Color {
        if let palette = colorPalette {
            return palette.adaptiveUIColor
        } else {
            return DesignSystem.Colors.primaryAccent
        }
    }
    
    // MARK: - Simple Live Transcription View
    private var liveTranscriptionView: some View {
        GeometryReader { geometry in
            VStack {
                Spacer() // Push content to bottom
                if isRecording && !liveTranscription.isEmpty && showLiveTranscriptionBubble {
                    HStack {
                        Spacer()
                        
                        // Simple text that appears with rectangular shape
                        Text(liveTranscription)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                            .padding(.vertical, 16)
                            .frame(maxWidth: geometry.size.width - 100)
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .animation(DesignSystem.Animation.easeStandard, value: liveTranscription)
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Base gradient background - pinned to edges from start
            gradientBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            // Main scroll content
            mainScrollContent
        }
        // Double tap gesture to show keyboard
        .onTapGesture(count: 2) {
            // Double tap anywhere to show keyboard
            if inputMode != .textInput {
                if isRecording {
                    stopRecording()
                }
                withAnimation(DesignSystem.Animation.springStandard) {
                    inputMode = .textInput
                    isKeyboardFocused = true
                }
                SensoryFeedback.light()
            }
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
        // Bottom gradient and input controls
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                // Bottom gradient - ALWAYS VISIBLE, ALWAYS FULL STRENGTH
                voiceGradientOverlay
                    .allowsHitTesting(false) // Ensure gradient doesn't block touches
                
                // Input controls overlay on top of gradient
                bottomInputArea
                    .frame(maxWidth: .infinity, alignment: .bottom)  // Removed maxHeight to not fill entire space
            }
        }
        // Top navigation bar with BookView-style header
        .safeAreaInset(edge: .top) {
            bookStyleHeader
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.vertical, 8)
        }
        // Removed - moved above transcription bar
        .statusBarHidden(true)
        .fullScreenCover(isPresented: $showingSessionSummary) {
            if let session = currentSession {
                AmbientSessionSummaryView(
                    session: session,
                    colorPalette: colorPalette,
                    onDismiss: {
                        // Dismiss both the summary and ambient mode together
                        showingSessionSummary = false
                        dismiss()
                    }
                )
                .environment(\.modelContext, modelContext)
                .environmentObject(libraryViewModel)
                .environmentObject(notesViewModel)
            }
        }
        .onAppear {
            // Check if we have an initial book from the coordinator
            if let initialBook = EpilogueAmbientCoordinator.shared.initialBook {
                currentBookContext = initialBook
                lastDetectedBookId = initialBook.localId
                print("📚 Starting ambient mode with book: \(initialBook.title)")
                
                // Extract colors for the book
                Task {
                    await extractColorsForBook(initialBook)
                }
                
                // Clear the initial book from coordinator after using it
                EpilogueAmbientCoordinator.shared.initialBook = nil
            }
            
            startAmbientExperience()
            setupKeyboardObservers()
            
            // Auto-expand the first AI response if it exists
            if let firstAIResponse = messages.first(where: { !$0.isUser }) {
                expandedMessageIds.insert(firstAIResponse.id)
            }
            
            // Smooth gradient fade in on load
            withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
                gradientOpacity = 1.0
            }
        }
        .onChange(of: inputMode) { _, newMode in
            // Handle focus changes when switching modes
            if newMode == .textInput {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isKeyboardFocused = true
                }
            } else {
                isKeyboardFocused = false
            }
        }
        .onReceive(processor.$detectedContent.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)) { newContent in
            // Only process if there are actual new items
            if newContent.count > lastProcessedCount {
                let newItems = Array(newContent.suffix(newContent.count - lastProcessedCount))
                processAndSaveDetectedContent(newItems)
                lastProcessedCount = newContent.count
            }
            // Always check for response updates
            checkForResponseUpdates(in: newContent)
        }
        // Add a second listener without debounce specifically for progressive updates
        .onReceive(processor.$detectedContent) { content in
            // Immediate check for progressive response updates (no debounce)
            // This ensures streaming responses show immediately
            for item in content.suffix(5) where item.type == .question {
                if let response = item.response, !response.isEmpty && response != "Thinking..." {
                    // Update UI immediately for progressive loading
                    if let existingMsgIndex = messages.lastIndex(where: { msg in
                        !msg.isUser && msg.content.contains("**\(item.text)**")
                    }) {
                        let currentMsg = messages[existingMsgIndex]
                        let updatedContent = "**\(item.text)**\n\n\(response)"
                        if currentMsg.content != updatedContent {
                            messages[existingMsgIndex] = UnifiedChatMessage(
                                content: updatedContent,
                                isUser: false,
                                timestamp: currentMsg.timestamp,
                                bookContext: currentBookContext,
                                messageType: .text
                            )
                            print("📝 Progressive UI update: \(response.count) chars")
                        }
                    }
                }
            }
        }
        .onReceive(bookDetector.$detectedBook) { book in
            // Smooth gradient transition when book changes
            if book?.localId != lastBookId {
                withAnimation(.easeOut(duration: 0.4)) {
                    gradientOpacity = 0.3 // Fade to low opacity
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    handleBookDetection(book)
                    lastBookId = book?.localId
                    
                    // Fade back in with new colors
                    withAnimation(.easeIn(duration: 0.8)) {
                        gradientOpacity = 1.0
                    }
                }
            } else {
                handleBookDetection(book)
            }
        }
        .onDisappear {
            bookCoverTimer?.invalidate()
            transcriptionFadeTimer?.invalidate()
            breathingTimer?.invalidate()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $capturedImage)
                .onDisappear {
                    if let image = capturedImage {
                        processImageForText(image)
                    }
                }
        }
        .sheet(isPresented: $showQuoteHighlighter) {
            QuoteHighlighterView(
                image: capturedImage,
                extractedText: extractedText,
                onSave: saveHighlightedQuote
            )
        }
        .onChange(of: isRecording) { _, newValue in
            // Clear transcription when recording stops
            if !newValue {
                liveTranscription = ""
                transcriptionFadeTimer?.invalidate()
                transcriptionFadeTimer = nil
                // Also clear the voice manager's text
                voiceManager.transcribedText = ""
            }
        }
        .onReceive(voiceManager.$transcribedText) { text in
            // CRITICAL: Only update if actually recording
            guard isRecording else {
                // Clear everything when not recording
                if !liveTranscription.isEmpty {
                    liveTranscription = ""
                    transcriptionFadeTimer?.invalidate()
                    transcriptionFadeTimer = nil
                }
                return
            }
            
            // Clean transcription - only show new content
            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for page mentions (e.g., "page 42", "on page 42", "I'm on page 42")
            detectPageMention(in: cleanedText)
            
            // Update live transcription only if there's text
            if !cleanedText.isEmpty {
                liveTranscription = cleanedText
                // Transcription visibility controlled by showLiveTranscriptionBubble setting
                
                // Debug log
                print("📝 Live transcription received: \(cleanedText)")
            } else {
                // Empty text means clear everything
                liveTranscription = ""
                transcriptionFadeTimer?.invalidate()
                transcriptionFadeTimer = nil
            }
            
            // Simple fade timer - no complex logic
            if !cleanedText.isEmpty {
                // Cancel any existing timer
                transcriptionFadeTimer?.invalidate()
                
                // Set a simple timer to fade after 3 seconds
                transcriptionFadeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    withAnimation(.easeOut(duration: 0.5)) {
                        // Fade handled by animation, visibility controlled by setting
                    }
                    // Clear text after fade
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        liveTranscription = ""
                    }
                }
            }
            
            // Detect book mentions - always check, even for short text  
            if cleanedText.count > 5 {
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
    
    // MARK: - Gradient Background (Smooth Loading)
    @ViewBuilder
    private var gradientBackground: some View {
        // Always show a base black layer for smooth transitions
        Color.black
            .ignoresSafeArea(.all)
            .overlay {
                if let book = currentBookContext {
                    // Use book-specific gradient with extracted colors
                    let palette = colorPalette ?? generatePlaceholderPalette(for: book)
                    BookAtmosphericGradientView(
                        colorPalette: palette, 
                        intensity: gradientIntensity * (isRecording ? 0.9 + Double(audioLevel) * 0.3 : 0.85),
                        audioLevel: isRecording ? audioLevel : 0
                    )
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                    .opacity(gradientOpacity)
                    // Only animate opacity, not position or scale
                    .animation(.easeInOut(duration: 1.0), value: gradientOpacity)
                    .transition(.opacity) // Simple opacity transition
                    .id(book.localId)
                } else {
                    // Default warm ambient gradient with smooth fade
                    AmbientChatGradientView()
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                        .opacity(gradientOpacity * (isRecording ? 0.8 + Double(audioLevel) * 0.4 : 1.0))
                        // Only animate opacity
                        .animation(.easeInOut(duration: 0.8), value: gradientOpacity)
                        .transition(.opacity)
                }
            }
    }
    
    // MARK: - Voice Gradient Overlay (Matching UnifiedChatView)
    @ViewBuilder
    private var voiceGradientOverlay: some View {
        VStack {
            // Book cover - show when book is detected, fade after 10 seconds
            if showBookCover, let book = currentBookContext, let coverURL = book.coverImageURL {
                SharedBookCoverView(
                    coverURL: coverURL,
                    width: 140,
                    height: 210
                )
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(isRecording ? 1.0 : 0.9)
                .opacity(isRecording ? 1.0 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isRecording)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 1.1).combined(with: .opacity)
                ))
                .padding(.top, 140)
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
            // All UI elements moved to bottomInputArea for proper positioning
        }
    }
    
    // MARK: - Clean Main Scroll Content
    @ViewBuilder
    private var mainScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Top spacing for message positioning
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 64) // ← Reduced by 16px
                        .id("top")
                    
                    let hasRealContent = messages.contains { msg in
                        !msg.content.contains("[Transcribing]")
                    }
                    
                    if !hasRealContent {
                        if currentBookContext == nil && !isRecording {
                            // Simplified welcome
                            minimalWelcomeView
                                .padding(.top, 34) // ← Reduced from 50 to 34
                        }
                    }
                    
                    // Conversation section in minimal thread style
                    if !messages.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            // Section header if we have multiple messages
                            if messages.count > 1 {
                                Text("CONVERSATION")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .tracking(1.2)
                                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                            }
                            
                            // Thread-style messages
                            VStack(spacing: 1) {
                                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                    // Display quotes with special formatting
                                    if case .quote(let capturedQuote) = message.messageType {
                                        AmbientQuoteView(
                                            quote: capturedQuote, 
                                            index: index,
                                            onEdit: { quoteText in
                                                // Prepopulate input with quote text for editing
                                                keyboardText = quoteText
                                                editingMessageId = message.id
                                                editingMessageType = .quote(capturedQuote)
                                                
                                                // Switch to text input mode
                                                withAnimation(DesignSystem.Animation.springStandard) {
                                                    inputMode = .textInput
                                                    isKeyboardFocused = true
                                                }
                                            }
                                        )
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    } else if case .note(let capturedNote) = message.messageType {
                                        // Display notes with special formatting
                                        AmbientNoteView(
                                            note: capturedNote,
                                            index: index,
                                            onEdit: { noteText in
                                                // Prepopulate input with note text for editing
                                                keyboardText = noteText
                                                editingMessageId = message.id
                                                editingMessageType = .note(capturedNote)
                                                
                                                // Switch to text input mode
                                                withAnimation(DesignSystem.Animation.springStandard) {
                                                    inputMode = .textInput
                                                    isKeyboardFocused = true
                                                }
                                            }
                                        )
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    } else if case .noteWithContext(let capturedNote, _) = message.messageType {
                                        // Display notes with context using same view (context handled internally if needed)
                                        AmbientNoteView(
                                            note: capturedNote,
                                            index: index,
                                            onEdit: { noteText in
                                                // Prepopulate input with note text for editing
                                                keyboardText = noteText
                                                editingMessageId = message.id
                                                editingMessageType = .note(capturedNote)
                                                
                                                // Switch to text input mode
                                                withAnimation(DesignSystem.Animation.springStandard) {
                                                    inputMode = .textInput
                                                    isKeyboardFocused = true
                                                }
                                            }
                                        )
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    } else {
                                        AmbientMessageThreadView(
                                            message: message,
                                            index: index,
                                            totalMessages: messages.filter { !$0.isUser }.count,
                                            isExpanded: expandedMessageIds.contains(message.id),
                                            onToggle: {
                                                withAnimation(DesignSystem.Animation.easeQuick) {
                                                    if expandedMessageIds.contains(message.id) {
                                                        expandedMessageIds.remove(message.id)
                                                    } else {
                                                        expandedMessageIds.insert(message.id)
                                                    }
                                                }
                                            },
                                            onEdit: message.isUser ? { questionText in
                                                // Prepopulate input with question text for editing
                                                keyboardText = questionText
                                                editingMessageId = message.id
                                                editingMessageType = message.messageType
                                                
                                                // Switch to text input mode
                                                withAnimation(DesignSystem.Animation.springStandard) {
                                                    inputMode = .textInput
                                                    isKeyboardFocused = true
                                                }
                                            } : nil
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        }
                    }
                    
                    // Bottom spacer for input area - adjusted for keyboard mode
                    Color.clear
                        .frame(height: inputMode == .textInput ? 20 : 100)
                        .id("bottom")
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical) // Prevent excessive bouncing
            .scrollDismissesKeyboard(.immediately)
            .contentMargins(.top, 0, for: .scrollContent) // Prevent scrolling above content
            .scrollClipDisabled(false) // Ensure content doesn't scroll outside bounds
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: messages.count) { _, _ in
                // Scroll to new message with delay to ensure layout is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        if let lastMessage = messages.last {
                            // Center the new message in view
                            proxy.scrollTo(lastMessage.id, anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: expandedMessageIds) { _, _ in
                // When a message is expanded, ensure it's visible
                if let expandedId = expandedMessageIds.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            proxy.scrollTo(expandedId, anchor: .center)
                        }
                    }
                }
            }
            .scrollBounceBehavior(isRecording ? .automatic : .basedOnSize)
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
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Clean Bottom Input Area
    @ViewBuilder
    private var bottomInputArea: some View {
        ZStack {
            // Removed invisible tap area that was blocking scrolling
            // Dismissal will be handled by scrollDismissesKeyboard instead
            
            VStack(spacing: 16) { // ← Fixed spacing and order
                // Removed Spacer that was expanding the VStack unnecessarily
                
                // Save indicator - positioned above everything else
                if showSaveAnimation, let itemType = savedItemType {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .symbolEffect(.bounce, value: showSaveAnimation)
                        
                        Text("Saved \(itemType)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.vertical, 10)
                    .glassEffect()
                    .clipShape(Capsule())
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                        removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top))
                    ))
                    .animation(DesignSystem.Animation.springStandard, value: showSaveAnimation)
                }
                
                // Spacer to push content to bottom
                Spacer()
                
                // Scrolling text animation - shows only when processing a question
                // Positioned above the live transcription when both are visible
                if pendingQuestion != nil {
                    ScrollingBookMessages()
                        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                        .padding(.vertical, 12)
                        .glassEffect()
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
                
                // Live transcription bubble - positioned below ScrollingBookMessages
                if isRecording && !liveTranscription.isEmpty && showLiveTranscriptionBubble {
                    HStack {
                        Spacer()
                        
                        Text(liveTranscription)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                            .padding(.vertical, 16)
                            .frame(maxWidth: 300) // Limit width
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        
                        Spacer()
                    }
                    .animation(DesignSystem.Animation.easeStandard, value: liveTranscription)
                }
                
                // FIXED: Main input controls at the very bottom
                GeometryReader { geometry in
                HStack(spacing: 0) {
                    Spacer()
                        .allowsHitTesting(false)  // Don't block touches
                    
                    // Single morphing container that expands/contracts
                    ZStack {
                        // Morphing background with smooth transition
                        if inputMode == .textInput {
                            // Rectangle with fixed corner radius for text input
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.001)) // Nearly invisible for glass
                                .frame(
                                    width: min(geometry.size.width - 80, 320),
                                    height: textFieldHeight  // Dynamic height
                                )
                                .blur(radius: containerBlur) // Ambient container blur
                                .glassEffect(.regular, in: .rect(cornerRadius: 20)) // Fixed corner radius glass
                                .matchedGeometryEffect(id: "inputContainer", in: morphingNamespace)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 1.2).combined(with: .opacity)
                                ))
                                .allowsHitTesting(false)  // Glass background shouldn't block touches
                        } else {
                            // Circle for voice mode
                            Circle()
                                .fill(Color.white.opacity(0.001)) // Nearly invisible for glass
                                .frame(width: 64, height: 64)
                                .blur(radius: containerBlur) // Ambient container blur
                                .glassEffect() // Circle glass effect
                                .matchedGeometryEffect(id: "inputContainer", in: morphingNamespace)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 1.2).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity)
                                ))
                                .allowsHitTesting(false)  // Glass background shouldn't block touches
                        }
                        
                        // Content that transitions inside the morphing container
                        ZStack {
                            // Voice mode content (stop/waveform icon)
                            if !inputMode.isTextInput {
                                Button {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.25)) {
                                        if inputMode == .listening && isRecording {
                                            handleMicrophoneTap()
                                        } else if inputMode == .paused {
                                            inputMode = .textInput
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                isKeyboardFocused = true
                                            }
                                        } else {
                                            handleMicrophoneTap()
                                        }
                                    }
                                } label: {
                                    Image(systemName: inputMode == .paused ? "keyboard" : (isRecording ? "stop.fill" : "waveform"))
                                        .font(.system(size: 28, weight: .medium, design: .rounded))
                                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                                        .frame(width: 64, height: 64)
                                        .contentTransition(.interpolate)
                                }
                                .buttonStyle(.plain)
                                .opacity(inputMode == .textInput ? 0 : 1)
                                .scaleEffect(inputMode == .textInput ? 0.5 : 1)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: inputMode)
                            }
                            
                            // Text input mode content
                            if inputMode == .textInput {
                                HStack(spacing: 8) {
                                    // Camera button
                                    Button {
                                        showImagePicker = true
                                    } label: {
                                        Image(systemName: "camera")
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.6))
                                            .frame(width: 32, height: 32)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .opacity(inputMode == .textInput ? 1 : 0)
                                    .scaleEffect(inputMode == .textInput ? 1 : 0.5)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8).delay(0.15), value: inputMode)
                                    
                                    // Enhanced text field with ambient blur
                                    ZStack(alignment: .leading) {
                                        // Placeholder - NO BLUR
                                        if keyboardText.isEmpty {
                                            Text(editingMessageId != nil ? "Edit your message..." : "Ask, capture, or type...")
                                                .foregroundColor(DesignSystem.Colors.textQuaternary)
                                                .font(.system(size: 16))
                                        }
                                        
                                        // Hidden text to measure intrinsic height
                                        Text(keyboardText.isEmpty ? " " : keyboardText)
                                            .font(.system(size: 16))
                                            .lineLimit(1...3)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .hidden()
                                            .background(
                                                GeometryReader { proxy in
                                                    Color.clear
                                                        .onAppear {
                                                            // Set initial height on appear
                                                            let measuredHeight = max(44, min(proxy.size.height + 16, 100))
                                                            if abs(textFieldHeight - measuredHeight) > 1 {
                                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                                    textFieldHeight = measuredHeight
                                                                }
                                                            }
                                                        }
                                                        .onChange(of: proxy.size) { _, newSize in
                                                            // Update height when text changes
                                                            let measuredHeight = max(44, min(newSize.height + 16, 100))
                                                            if abs(textFieldHeight - measuredHeight) > 1 {
                                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                                    textFieldHeight = measuredHeight
                                                                }
                                                            }
                                                        }
                                                }
                                            )
                                        
                                        TextField("", text: $keyboardText, axis: .vertical)
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .tint(DesignSystem.Colors.primaryAccent)
                                            .focused($isKeyboardFocused)
                                            .lineLimit(1...3)
                                            .textFieldStyle(.plain)
                                            .onChange(of: keyboardText) { oldValue, newValue in
                                                lastCharacterCount = newValue.count
                                            }
                                            .onSubmit {
                                                if !keyboardText.isEmpty {
                                                    // Removed blur wave for cleaner submission
                                                    sendTextMessage()
                                                }
                                            }
                                    }
                                    .frame(maxWidth: .infinity)  // Fill available space
                                    .opacity(inputMode == .textInput ? 1 : 0)
                                    .scaleEffect(inputMode == .textInput ? 1 : 0.8)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8).delay(0.2), value: inputMode)
                                }
                                .padding(.leading, 12)  // Proper padding for camera icon
                                .padding(.trailing, 12)
                                .padding(.vertical, 8)  // Dynamic vertical padding
                            }
                        }
                    }
                    .onAppear {
                        // Start subtle idle breathing animation
                        startContainerBreathing()
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.25), value: inputMode)
                    
                    // Morphing button - waveform when empty, submit when has text
                    if inputMode == .textInput {
                        Button {
                            if !keyboardText.isEmpty {
                                // Submit the message
                                // Removed blur wave for cleaner submission
                                sendTextMessage()
                            } else {
                                // Return to voice mode
                                isKeyboardFocused = false
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.25)) {
                                    keyboardText = ""
                                    textFieldHeight = 44  // Reset to compact height
                                    inputMode = .listening
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    startRecording()
                                }
                            }
                        } label: {
                            Circle()
                                .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                                .frame(width: 48, height: 48)
                                .glassEffect()
                                .overlay(
                                    Image(systemName: keyboardText.isEmpty ? "waveform" : "arrow.up")
                                        .font(.system(size: 20, weight: keyboardText.isEmpty ? .medium : .semibold, design: .rounded))
                                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                                        .contentTransition(.symbolEffect(.replace))
                                )
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0).combined(with: .opacity).combined(with: .move(edge: .leading)),
                            removal: .scale(scale: 0).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1), value: inputMode)
                        .padding(.leading, 12)
                    }
                    
                    Spacer()
                        .allowsHitTesting(false)  // Don't block touches
                }
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height)
                .allowsHitTesting(true)  // Only allow hit testing on actual interactive elements
            }
            .frame(height: 100)
            .allowsHitTesting(true)  // Ensure only actual controls are interactive
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)  // Back to original padding
        .padding(.bottom, inputMode == .textInput ? 18 : 36)  // Back to previous values
        
        // Long press for quick keyboard
        .onLongPressGesture(minimumDuration: 0.5) {
            if isRecording {
                stopRecording()
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.25)) {
                inputMode = .textInput
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isKeyboardFocused = true
                }
            }
            SensoryFeedback.medium()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86, blendDuration: 0), value: inputMode)
        }
    }
    
    // MARK: - Text Input Bar Component (DEPRECATED - now integrated into bottomInputArea)
    // Keeping for reference but no longer used
    private var ambientTextInputBar_DEPRECATED: some View {
        HStack(spacing: 12) {
            // Minimal Raycast-style input field
            HStack(spacing: 8) {
                // Camera button for page capture
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Text field with minimal styling
                TextField("", text: $keyboardText, axis: .vertical)
                    .placeholder(when: keyboardText.isEmpty) {
                        Text("Ask, capture, or type...")
                            .foregroundColor(DesignSystem.Colors.textQuaternary)
                            .font(.system(size: 16))
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .tint(.white.opacity(0.8))
                    .focused($isKeyboardFocused)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if !keyboardText.isEmpty {
                            sendTextMessage()
                        }
                    }
                
                // Send button (only visible with text)
                if !keyboardText.isEmpty {
                    Button {
                        sendTextMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.black, .white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.vertical, 12)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous))
            
            // Voice return button - proper liquid glass
            Button {
                withAnimation(DesignSystem.Animation.springStandard) {
                    returnToVoiceMode()
                }
            } label: {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .glassEffect()
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding) // Match the voice button's horizontal positioning
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
            
            // Removed Switch Book button - book switching is handled via book strip
        }
    }
    
    // MARK: - CRITICAL DATA PERSISTENCE FIX
    
    private func checkForResponseUpdates(in content: [AmbientProcessedContent]) {
        // Only check recent items for response updates to avoid excessive processing
        let recentItems = content.suffix(10)
        
        for item in recentItems {
            if item.type == .question, let response = item.response, response != "Thinking..." {
                // Check if we already have this response displayed
                let responseKey = "\(item.text)_response"
                if !processedContentHashes.contains(responseKey) {
                    processedContentHashes.insert(responseKey)
                    
                    print("✅ Response update detected for: \(item.text.prefix(30))...")
                    
                    // Update the saved question in SwiftData with the answer
                    if let session = currentSession {
                        if let savedQuestion = (session.capturedQuestions ?? []).first(where: { $0.content == item.text }) {
                            savedQuestion.answer = response
                            try? modelContext.save()
                            print("✅ Updated saved question with answer")
                        }
                    }
                    
                    // Find and update the thinking message with the actual response
                    if let thinkingIndex = messages.lastIndex(where: { 
                        !$0.isUser && 
                        ($0.content.contains("**\(item.text)**") || 
                         $0.content == "[Thinking]" ||
                         $0.content == "**\(item.text)**")
                    }) {
                        let updatedMessage = UnifiedChatMessage(
                            content: "**\(item.text)**\n\n\(response)",
                            isUser: false,
                            timestamp: messages[thinkingIndex].timestamp,
                            bookContext: currentBookContext,
                            messageType: .text
                        )
                        messages[thinkingIndex] = updatedMessage
                        pendingQuestion = nil
                        
                        // Automatically expand the message to show the response
                        if !expandedMessageIds.contains(updatedMessage.id) {
                            expandedMessageIds.insert(updatedMessage.id)
                        }
                        
                        print("✅ Updated thinking message with response and expanded it")
                        print("   Message content: \(updatedMessage.content.prefix(100))...")
                        print("   Total messages: \(messages.count)")
                    } else {
                        // No thinking message found, add response as new message
                        let aiMessage = UnifiedChatMessage(
                            content: "**\(item.text)**\n\n\(response)",
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext,
                            messageType: .text
                        )
                        messages.append(aiMessage)
                        pendingQuestion = nil
                        
                        // Automatically expand the new message to show the response
                        expandedMessageIds.insert(aiMessage.id)
                        
                        print("✅ Added new message with response and expanded it")
                    }
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
            withAnimation(DesignSystem.Animation.springStandard) {
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
            
            // Smart filtering - automatically filter out non-book content
            if item.type == .question {
                let questionLower = item.text.lowercased()
                
                // Keywords that indicate non-book conversation
                let nonBookKeywords = ["chewy box", "shoe box", "bring", "brought", "aftership", "tracking", "package", "delivery"]
                let isNonBookContent = nonBookKeywords.contains { questionLower.contains($0) }
                
                // Keywords that indicate book-related content
                let bookRelatedKeywords = ["book", "character", "story", "plot", "chapter", "page", "author", "reading",
                                          "frodo", "gandalf", "bilbo", "ring", "hobbit", "shire", "middle-earth", 
                                          "protagonist", "antagonist", "theme", "ending", "beginning"]
                let seemsBookRelated = bookRelatedKeywords.contains { questionLower.contains($0) } ||
                                       (currentBookContext != nil && 
                                        currentBookContext!.title.lowercased().split(separator: " ").contains { 
                                            questionLower.contains($0) && $0.count > 3 
                                        })
                
                // Filter out if it's clearly non-book content and not book-related
                if isNonBookContent && !seemsBookRelated {
                    logger.info("🚫 Auto-filtering non-book question: \(item.text.prefix(50))...")
                    continue
                }
            }
            
            // Show save animation for quotes and notes (saving is handled by processor)
            switch item.type {
            case .quote:
                // Save quote to SwiftData with session relationship and get the CapturedQuote
                if let capturedQuote = saveQuoteToSwiftData(item) {
                    savedItemsCount += 1
                    savedItemType = "Quote"
                    
                    // Add formatted quote to messages for display using the CapturedQuote
                    let quoteMessage = UnifiedChatMessage(
                        content: capturedQuote.text ?? "",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .quote(capturedQuote)  // Use quote type with the CapturedQuote object
                    )
                    messages.append(quoteMessage)
                    
                    // Gracefully collapse previous messages when new quote arrives
                    withAnimation(DesignSystem.Animation.easeStandard) {
                        expandedMessageIds.removeAll()
                    }
                    
                    print("🎯 SAVE ANIMATION: Setting showSaveAnimation = true for Quote")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSaveAnimation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            print("🎯 SAVE ANIMATION: Hiding save animation for Quote")
                            showSaveAnimation = false
                            savedItemType = nil
                        }
                    }
                    logger.info("💾 Quote detected and saved: \(item.text.prefix(50))...")
                } else {
                    logger.warning("⚠️ Failed to save quote: \(item.text.prefix(50))...")
                }
            case .note, .thought:
                // Save note to SwiftData with session relationship
                if let capturedNote = saveNoteToSwiftData(item) {
                    savedItemsCount += 1
                    savedItemType = item.type == .note ? "Note" : "Thought"
                    
                    // Add formatted note/thought to messages for display
                    let noteMessage = UnifiedChatMessage(
                        content: capturedNote.content ?? "",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .note(capturedNote)  // Use note type with the CapturedNote object
                    )
                    messages.append(noteMessage)
                    
                    // Gracefully collapse previous messages when new note/thought arrives
                    withAnimation(DesignSystem.Animation.easeStandard) {
                        expandedMessageIds.removeAll()
                    }
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSaveAnimation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSaveAnimation = false
                            savedItemType = nil
                        }
                    }
                    logger.info("💾 \(item.type == .note ? "Note" : "Thought") detected and saved: \(item.text.prefix(50))...")
                } else {
                    logger.warning("⚠️ Failed to save note/thought: \(item.text.prefix(50))...")
                }
            case .question:
                // Save question to SwiftData with session relationship
                saveQuestionToSwiftData(item)
                logger.info("❓ Question detected and saved: \(item.text.prefix(50))...")
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
                        // Format the response with the question for context
                        let formattedResponse = "**\(item.text)**\n\n\(item.response!)"
                        let aiMessage = UnifiedChatMessage(
                            content: formattedResponse,
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext,
                            messageType: .text
                        )
                        // Check if this is the first response BEFORE adding it
                        _ = messages.filter { !$0.isUser }.count == 0
                        
                        messages.append(aiMessage)
                        
                        // Auto-collapse all previous messages and expand only the new one
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(aiMessage.id)
                        }
                        print("✅ Added AI response for question: \(item.text.prefix(30))...")
                    } else {
                        print("⚠️ Response already exists for question: \(item.text.prefix(30))...")
                    }
                } else {
                    // Question detected but no response yet - add thinking message
                    // Check if we already have a thinking message for this question
                    let alreadyHasThinking = messages.contains { msg in
                        !msg.isUser && msg.content.contains(item.text) && !msg.content.contains("\n\n")
                    }
                    
                    if !alreadyHasThinking {
                        let thinkingMessage = UnifiedChatMessage(
                            content: "**\(item.text)**",
                            isUser: false,
                            timestamp: Date(),
                            messageType: .text
                        )
                        messages.append(thinkingMessage)
                        
                        // Collapse all previous messages and only expand the new one
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(thinkingMessage.id)
                        }
                        
                        pendingQuestion = item.text
                        print("💭 Added thinking message for question: \(item.text.prefix(30))...")
                        
                        // Trigger AI response
                        Task {
                            await getAIResponseForAmbientQuestion(item.text)
                        }
                    } else {
                        print("⚠️ Thinking message already exists for: \(item.text.prefix(30))...")
                    }
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
    
    @discardableResult
    private func saveQuoteToSwiftData(_ content: AmbientProcessedContent) -> CapturedQuote? {
        // Clean the quote text - remove common prefixes
        var quoteText = content.text
        let prefixesToRemove = [
            "i love this quote.",
            "i love this quote",
            "quote...",
            "quote:",
            "quote "
        ]
        
        for prefix in prefixesToRemove {
            if quoteText.lowercased().hasPrefix(prefix) {
                quoteText = String(quoteText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // CRITICAL: Remove quotation marks for proper formatting
        // The quote card will add its own drop cap quotation mark
        quoteText = quoteText
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\u{201C}", with: "") // Left double quotation mark
            .replacingOccurrences(of: "\u{201D}", with: "") // Right double quotation mark
            .replacingOccurrences(of: "\u{2018}", with: "") // Left single quotation mark
            .replacingOccurrences(of: "\u{2019}", with: "") // Right single quotation mark
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for duplicates
        let fetchRequest = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { quote in
                quote.text == quoteText
            }
        )
        
        if let existingQuotes = try? modelContext.fetch(fetchRequest), !existingQuotes.isEmpty {
            print("⚠️ Quote already exists: \(quoteText.prefix(30))...")
            
            // Show graceful reminder to user
            savedItemsCount += 1
            savedItemType = "Quote (Already Saved)"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSaveAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSaveAnimation = false
                    savedItemType = nil
                }
            }
            
            // Still link to session if not already linked
            if let session = currentSession, let existingQuote = existingQuotes.first {
                if existingQuote.ambientSession == nil || !(session.capturedQuotes ?? []).contains(where: { $0.id == existingQuote.id }) {
                    existingQuote.ambientSession = session
                    // Check if quote is already in session's captured quotes before adding
                    if !(session.capturedQuotes ?? []).contains(where: { $0.id == existingQuote.id }) {
                        session.capturedQuotes = (session.capturedQuotes ?? []) + [existingQuote]
                    }
                    try? modelContext.save()
                    print("✅ Linked existing quote to current session")
                }
            }
            return existingQuotes.first
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
        
        let capturedQuote = CapturedQuote(
            text: quoteText,
            book: bookModel,
            author: currentBookContext?.author,
            pageNumber: nil,
            timestamp: content.timestamp,
            source: .ambient
        )
        
        // CRITICAL: Set the session relationship immediately
        if let session = currentSession {
            capturedQuote.ambientSession = session
            // Check for duplicates before adding (defensive programming)
            if !(session.capturedQuotes ?? []).contains(where: { $0.text == capturedQuote.text }) {
                session.capturedQuotes = (session.capturedQuotes ?? []) + [capturedQuote]
            }
        }
        
        modelContext.insert(capturedQuote)
        
        do {
            try modelContext.save()
            print("✅ Quote saved to SwiftData with session: \(quoteText.prefix(50))...")
            SensoryFeedback.success()
            return capturedQuote
        } catch {
            print("❌ Failed to save quote: \(error)")
            return nil
        }
    }
    
    private func saveNoteToSwiftData(_ content: AmbientProcessedContent) -> CapturedNote? {
        // Use the raw text as-is for consistency
        let noteText = content.text
        let fetchRequest = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { note in
                note.content == noteText
            }
        )
        
        if let existingNotes = try? modelContext.fetch(fetchRequest), !existingNotes.isEmpty {
            print("⚠️ Note already exists, skipping save: \(noteText.prefix(30))...")
            return existingNotes.first
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
        
        // CRITICAL: Set the session relationship immediately
        if let session = currentSession {
            capturedNote.ambientSession = session
            session.capturedNotes = (session.capturedNotes ?? []) + [capturedNote]
        }
        
        modelContext.insert(capturedNote)
        
        do {
            try modelContext.save()
            print("✅ Note saved to SwiftData with session: \(content.text.prefix(50))...")
            SensoryFeedback.success()
            return capturedNote
        } catch {
            print("❌ Failed to save note: \(error)")
            return nil
        }
    }
    
    private func saveQuestionToSwiftData(_ content: AmbientProcessedContent) {
        // Use the raw text as-is for consistency
        let questionText = content.text
        
        // CRITICAL: Check for duplicate questions in current session
        guard let session = currentSession else { return }
        
        // Check if question already exists in this session
        let isDuplicate = (session.capturedQuestions ?? []).contains { question in
            question.content == questionText
        }
        
        if isDuplicate {
            print("⚠️ DUPLICATE QUESTION DETECTED - NOT SAVING: \(questionText)")
            return // EXIT EARLY - DO NOT SAVE DUPLICATE
        }
        
        let fetchRequest = FetchDescriptor<CapturedQuestion>(
            predicate: #Predicate { question in
                question.content == questionText
            }
        )
        
        if let existingQuestions = try? modelContext.fetch(fetchRequest), 
           let existingQuestion = existingQuestions.first {
            // Link to session if not already linked
            if let session = currentSession {
                if existingQuestion.ambientSession == nil {
                    existingQuestion.ambientSession = session
                    // Check if question is already in session before adding
                    if !(session.capturedQuestions ?? []).contains(where: { $0.id == existingQuestion.id }) {
                        session.capturedQuestions = (session.capturedQuestions ?? []) + [existingQuestion]
                    }
                    print("📎 Linked existing question to session: \(questionText.prefix(30))...")
                }
            }
            
            // Update answer if we have a response
            if let response = content.response, existingQuestion.answer == nil {
                existingQuestion.answer = response
                existingQuestion.isAnswered = true
            }
            
            do {
                try modelContext.save()
                print("✅ Updated existing question: \(questionText.prefix(30))...")
                print("   Session now has \((currentSession?.capturedQuestions ?? []).count) questions")
            } catch {
                print("❌ Failed to update question: \(error)")
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
            content: questionText,
            book: bookModel,
            timestamp: content.timestamp,
            source: .ambient
        )
        
        // Add answer if available
        if let response = content.response {
            capturedQuestion.answer = response
            capturedQuestion.isAnswered = true
        }
        
        // CRITICAL: Set the session relationship immediately
        if let session = currentSession {
            capturedQuestion.ambientSession = session
            // Check for duplicates before adding (defensive programming)
            if !(session.capturedQuestions ?? []).contains(where: { $0.content == capturedQuestion.content }) {
                session.capturedQuestions = (session.capturedQuestions ?? []) + [capturedQuestion]
            }
        }
        
        modelContext.insert(capturedQuestion)
        
        do {
            try modelContext.save()
            print("✅ Question saved to SwiftData with session: \(questionText.prefix(50))...")
            print("   Session now has \((currentSession?.capturedQuestions ?? []).count) questions")
        } catch {
            print("❌ Failed to save question: \(error)")
        }
    }
    
    // MARK: - Actions
    
    private func setupKeyboardObservers() {
        // Observe keyboard notifications
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(DesignSystem.Animation.springStandard) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(DesignSystem.Animation.springStandard) {
                keyboardHeight = 0
            }
        }
    }
    
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
        // These are now managed internally by TrueAmbientProcessor
        // processor.setModelContext(modelContext)
        // processor.setCurrentSession(session)
        // processor.startSession()
        
        // Update library for book detection
        bookDetector.updateLibrary(libraryViewModel.books)
        
        // Set initial input mode
        inputMode = .listening
        
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
        
        // Don't collapse messages when recording starts
        // Let new messages handle collapsing the previous ones
        pendingQuestion = nil
        
        // processor.startSession() - managed internally
        voiceManager.startAmbientListeningMode()
        bookDetector.startDetection()
        SensoryFeedback.medium()
    }
    
    private func stopRecording() {
        isRecording = false
        liveTranscription = "" // Clear immediately
        // Visibility controlled by showLiveTranscriptionBubble setting
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        voiceManager.stopListening()
        voiceManager.transcribedText = "" // Force clear the source
        SensoryFeedback.light()
        
        // Don't force scroll - let the content stay where it is
        // The onChange handler will scroll when new messages arrive
    }
    
    // MARK: - Input Mode Management
    
    private func pauseForTextInput() {
        // Pause recording but keep session active
        if isRecording {
            stopRecording()
        }
        
        // First transition to paused state
        withAnimation(DesignSystem.Animation.springStandard) {
            inputMode = .paused
        }
        
        SensoryFeedback.light()
    }
    
    private func resumeVoiceInput() {
        withAnimation(DesignSystem.Animation.springStandard) {
            inputMode = .listening
        }
        startRecording()
    }
    
    private func returnToVoiceMode() {
        // Clear keyboard
        isKeyboardFocused = false
        keyboardText = ""
        
        withAnimation(DesignSystem.Animation.springStandard) {
            inputMode = .listening
        }
        
        // Resume recording after animation - maintain book context
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Don't change currentBookContext - maintain it
            startRecording()
        }
    }
    
    // MARK: - Ambient Blur Animations
    private func startContainerBreathing() {
        // Subtle idle breathing effect on container
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 3.0)) {
                containerBlur = containerBlur == 0.5 ? 0 : 0.5
            }
        }
    }
    
    
    private func triggerSubmitBlurWave() {
        // Create outward blur wave effect on submit
        withAnimation(.easeOut(duration: 0.3)) {
            submitBlurWave = 15
        }
        withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
            submitBlurWave = 0
        }
    }
    
    private func sendTextMessage() {
        guard !keyboardText.isEmpty else { return }
        
        let messageText = keyboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        keyboardText = "" // Clear immediately
        
        // Check if we're editing an existing message
        if let editingId = editingMessageId {
            // Find and update the message
            if let index = messages.firstIndex(where: { $0.id == editingId }) {
                let updatedMessage = messages[index]
                
                // Update the message content
                messages[index] = UnifiedChatMessage(
                    content: messageText,
                    isUser: updatedMessage.isUser,
                    timestamp: updatedMessage.timestamp,
                    messageType: updatedMessage.messageType
                )
                
                // Update in processor's detected content
                if let processorIndex = processor.detectedContent.firstIndex(where: { 
                    $0.text == updatedMessage.content 
                }) {
                    // Create a new content object with updated text (since text is immutable)
                    let oldContent = processor.detectedContent[processorIndex]
                    let newContent = AmbientProcessedContent(
                        text: messageText,
                        type: oldContent.type,
                        timestamp: oldContent.timestamp,
                        confidence: oldContent.confidence,
                        response: oldContent.response,
                        bookTitle: oldContent.bookTitle,
                        bookAuthor: oldContent.bookAuthor
                    )
                    // Note: We can't directly modify published property
                    // The processor should handle updates internally
                    // processor.detectedContent[processorIndex] = newContent
                }
                
                // If it's a question (user text message), regenerate the response
                if updatedMessage.isUser, case .text = updatedMessage.messageType {
                    // Remove old response
                    if let responseIndex = messages.firstIndex(where: { 
                        !$0.isUser && $0.timestamp > updatedMessage.timestamp
                    }) {
                        messages.remove(at: responseIndex)
                    }
                    
                    // Add thinking message and get new response
                    let thinkingMessage = UnifiedChatMessage(
                        content: "[Thinking]",
                        isUser: false,
                        timestamp: Date()
                    )
                    messages.append(thinkingMessage)
                    pendingQuestion = messageText
                    
                    Task {
                        await getAIResponse(for: messageText)
                    }
                }
                
                // Update in SwiftData if it's a quote
                if case .quote(let capturedQuote) = updatedMessage.messageType {
                    // Find and update the quote in the session
                    if let session = currentSession,
                       let quoteIndex = (session.capturedQuotes ?? []).firstIndex(where: { $0.id == capturedQuote.id }) {
                        var quotes = session.capturedQuotes ?? []
                        quotes[quoteIndex].text = messageText
                        session.capturedQuotes = quotes
                        try? modelContext.save()
                    }
                }
            }
            
            // Clear editing state
            editingMessageId = nil
            editingMessageType = nil
            return
        }
        
        // Normal message processing (not editing)
        // Check for page mentions in typed text too
        detectPageMention(in: messageText)
        
        // Smart content type detection
        let contentType = determineContentType(messageText)
        
        print("📝 Processing typed message: '\(messageText)' as \(contentType)")
        
        if contentType == .question {
            // Save the question immediately for the session
            let content = AmbientProcessedContent(
                text: messageText,
                type: .question,
                timestamp: Date(),
                confidence: 1.0,
                response: nil,
                bookTitle: currentBookContext?.title,
                bookAuthor: currentBookContext?.author
            )
            // Processor manages its own content array
            // processor.detectedContent.append(content)
            
            // Save question to SwiftData immediately
            saveQuestionToSwiftData(content)
            
            // Set pendingQuestion to show scrolling text
            pendingQuestion = messageText
            
            // For questions, add a thinking message immediately
            let thinkingMessage = UnifiedChatMessage(
                content: "**\(messageText)**",
                isUser: false,
                timestamp: Date(),
                messageType: .text
            )
            messages.append(thinkingMessage)
            
            // Collapse all previous and expand only the new question
            withAnimation(DesignSystem.Animation.easeStandard) {
                expandedMessageIds.removeAll()
                expandedMessageIds.insert(thinkingMessage.id)
            }
            
            // Get AI response using the same processor as voice input
            Task {
                // Add to processor's detected content
                processor.detectedContent.append(content)
                // Process through the same path as voice questions
                await processor.processQuestionDirectly(messageText, bookContext: currentBookContext)
            }
        } else {
            // For notes and quotes, save immediately
            let content = AmbientProcessedContent(
                text: messageText,
                type: contentType,
                timestamp: Date(),
                confidence: 1.0,
                response: nil,
                bookTitle: currentBookContext?.title,
                bookAuthor: currentBookContext?.author
            )
            
            // Save to SwiftData based on type
            if contentType == .quote {
                // Save quote and get the CapturedQuote object
                if let capturedQuote = saveQuoteToSwiftData(content) {
                    // Add to messages for display
                    let quoteMessage = UnifiedChatMessage(
                        content: capturedQuote.text ?? "",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .quote(capturedQuote)
                    )
                    messages.append(quoteMessage)
                    
                    // Add to session if available
                    if let session = currentSession {
                        session.capturedQuotes = (session.capturedQuotes ?? []) + [capturedQuote]
                        try? modelContext.save()
                    }
                    
                    print("✅ Quote saved to SwiftData: \(capturedQuote.text)")
                }
            } else {
                // Save note and get the CapturedNote object
                if let capturedNote = saveNoteToSwiftData(content) {
                    // Add to messages for display
                    let noteMessage = UnifiedChatMessage(
                        content: capturedNote.content ?? "",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .note(capturedNote)
                    )
                    messages.append(noteMessage)
                    
                    // Add to session if available
                    if let session = currentSession {
                        session.capturedNotes = (session.capturedNotes ?? []) + [capturedNote]
                        try? modelContext.save()
                    }
                    
                    print("✅ Note saved to SwiftData: \(capturedNote.content)")
                }
            }
            
            // Don't add to processor's content - it will try to save again
            // Just track for session summary purposes only
            // processor.detectedContent.append(content)
            
            // Show appropriate save animation
            savedItemsCount += 1
            savedItemType = contentType == .quote ? "Quote" : "Note"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSaveAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSaveAnimation = false
                    savedItemType = nil
                }
            }
        }
        
        // Don't auto-return to voice - let user control this
    }
    
    private func determineContentType(_ text: String) -> AmbientProcessedContent.ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        // Check for questions - be comprehensive
        if trimmed.hasSuffix("?") ||
           lowercased.starts(with: "who ") ||
           lowercased.starts(with: "what ") ||
           lowercased.starts(with: "where ") ||
           lowercased.starts(with: "when ") ||
           lowercased.starts(with: "why ") ||
           lowercased.starts(with: "how ") ||
           lowercased.starts(with: "is ") ||
           lowercased.starts(with: "are ") ||
           lowercased.starts(with: "can ") ||
           lowercased.starts(with: "could ") ||
           lowercased.starts(with: "would ") ||
           lowercased.starts(with: "should ") ||
           lowercased.starts(with: "will ") ||
           lowercased.starts(with: "do ") ||
           lowercased.starts(with: "does ") ||
           lowercased.starts(with: "did ") ||
           lowercased.starts(with: "has ") ||
           lowercased.starts(with: "have ") ||
           lowercased.starts(with: "had ") ||
           lowercased.starts(with: "tell me") ||
           lowercased.starts(with: "explain") ||
           lowercased.starts(with: "describe") ||
           lowercased.starts(with: "analyze") ||
           lowercased.starts(with: "compare") ||
           lowercased.starts(with: "contrast") ||
           lowercased.starts(with: "summarize") ||
           lowercased.starts(with: "define") ||
           lowercased.starts(with: "discuss") ||
           lowercased.starts(with: "elaborate") ||
           lowercased.starts(with: "clarify") ||
           lowercased.contains("tell me about") ||
           lowercased.contains("what about") ||
           lowercased.contains("how about") ||
           lowercased.contains("thoughts on") ||
           lowercased.contains("opinion on") ||
           lowercased.contains("do you think") ||
           lowercased.contains("what do you think") {
            return .question
        }
        
        // Check for quotes - with or without quotation marks
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("\u{201C}") && trimmed.hasSuffix("\u{201D}")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
           lowercased.starts(with: "quote:") {
            return .quote
        }
        
        // Everything else is a note
        return .note
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
    
    // MARK: - Photo Capture & OCR
    private func processImageForText(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else { return }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            DispatchQueue.main.async {
                self.extractedText = recognizedStrings.joined(separator: "\n")
                self.showQuoteHighlighter = true
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error)")
        }
    }
    
    private func saveHighlightedQuote(_ quote: String, pageNumber: Int? = nil) {
        // Save as a quote through the ambient processor
        let content = AmbientProcessedContent(
            text: quote,
            type: .quote,
            timestamp: Date(),
            confidence: 1.0,
            response: nil,
            bookTitle: currentBookContext?.title,
            bookAuthor: currentBookContext?.author
        )
        
        processor.detectedContent.append(content)
        
        // Show save animation
        savedItemsCount += 1
        savedItemType = "Quote from Photo"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSaveAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSaveAnimation = false
                savedItemType = nil
            }
        }
        
        // Clear the captured image
        capturedImage = nil
        showQuoteHighlighter = false
        extractedText = ""
    }
    
    private func getAIResponse(for text: String) async {
        let aiService = AICompanionService.shared
        
        guard aiService.isConfigured() else {
            await MainActor.run {
                // Update thinking message to show error
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let updatedMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\nPlease configure your AI service.",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        bookContext: currentBookContext
                    )
                    messages[thinkingIndex] = updatedMessage
                } else {
                    let configMessage = UnifiedChatMessage(
                        content: "Please configure your AI service.",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(configMessage)
                }
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
                // Update thinking message if it exists, otherwise append new message
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let updatedMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\n\(response)",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        bookContext: currentBookContext
                    )
                    messages[thinkingIndex] = updatedMessage
                    
                    // AUTO-EXPAND the first question's answer!
                    let nonUserMessages = messages.filter { !$0.isUser }
                    if nonUserMessages.count == 1 {
                        // This is the first question/answer - auto-expand it
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.insert(updatedMessage.id)
                        }
                    }
                } else {
                    let aiMessage = UnifiedChatMessage(
                        content: response,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(aiMessage)
                }
                pendingQuestion = nil
                
                // Update the processed content with the response
                if let pendingQ = pendingQuestion,
                   let index = processor.detectedContent.firstIndex(where: { $0.text == pendingQ && $0.type == .question }) {
                    processor.detectedContent[index] = AmbientProcessedContent(
                        text: pendingQ,
                        type: .question,
                        timestamp: processor.detectedContent[index].timestamp,
                        confidence: 1.0,
                        response: response,
                        bookTitle: currentBookContext?.title,
                        bookAuthor: currentBookContext?.author
                    )
                    
                    // CRITICAL: Update the saved question in SwiftData with the answer
                    if let session = currentSession {
                        // Find the question in the current session's questions
                        if let question = (session.capturedQuestions ?? []).first(where: { $0.content == pendingQ }) {
                            question.answer = response
                            question.isAnswered = true
                            try? modelContext.save()
                            print("✅ Updated SwiftData question with answer for summary view")
                        }
                    }
                }
                pendingQuestion = nil
            }
        } catch {
            await MainActor.run {
                // Update thinking message to show error
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let updatedMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\nSorry, I couldn't process your message.",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        bookContext: currentBookContext
                    )
                    messages[thinkingIndex] = updatedMessage
                } else {
                    let errorMessage = UnifiedChatMessage(
                        content: "Sorry, I couldn't process your message.",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(errorMessage)
                }
                pendingQuestion = nil
            }
        }
    }
    
    private func getAIResponseForAmbientQuestion(_ text: String) async {
        let aiService = AICompanionService.shared
        
        // First update the thinking message to show it's processing
        await MainActor.run {
            if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                let processingMessage = UnifiedChatMessage(
                    content: "**\(text)**",  // Just the question, no answer yet
                    isUser: false,
                    timestamp: messages[thinkingIndex].timestamp,
                    messageType: .text
                )
                messages[thinkingIndex] = processingMessage
                
                // Auto-expand this message to show the scrolling text
                expandedMessageIds.insert(processingMessage.id)
            }
        }
        
        // Small delay to show the animation
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard aiService.isConfigured() else {
            print("🔑 AI Service configured: false")
            await MainActor.run {
                // Update thinking message to show error with better formatting
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") }) {
                    let errorMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\n⚠️ **AI Service Not Configured**\n\nTo get AI responses, please add your Perplexity API key in Settings → AI Services.\n\n*Your question has been saved and will be available when you configure the service.*",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        messageType: .text
                    )
                    messages[thinkingIndex] = errorMessage
                }
                pendingQuestion = nil
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
                // Update the thinking message with the actual response
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let updatedMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\n\(response)",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        messageType: .text
                    )
                    messages[thinkingIndex] = updatedMessage
                    
                    // AUTO-EXPAND the first question's answer!
                    let nonUserMessages = messages.filter { !$0.isUser }
                    if nonUserMessages.count == 1 {
                        // This is the first question/answer - auto-expand it
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.insert(updatedMessage.id)
                        }
                    }
                }
                
                // Update the processed content with the response
                if let index = processor.detectedContent.firstIndex(where: { $0.text == text && $0.type == .question && $0.response == nil }) {
                    processor.detectedContent[index] = AmbientProcessedContent(
                        text: text,
                        type: .question,
                        timestamp: processor.detectedContent[index].timestamp,
                        confidence: 1.0,
                        response: response,
                        bookTitle: currentBookContext?.title,
                        bookAuthor: currentBookContext?.author
                    )
                    print("✅ Updated ambient question with AI response: \(text.prefix(30))...")
                }
                
                // CRITICAL: Update the saved question in SwiftData with the answer
                if let session = currentSession {
                    // Find the question in the current session's questions
                    if let question = (session.capturedQuestions ?? []).first(where: { $0.content == text }) {
                        question.answer = response
                        question.isAnswered = true
                        try? modelContext.save()
                        print("✅ Updated SwiftData question with answer for summary view")
                        print("   Session has \((session.capturedQuestions ?? []).count) questions")
                    }
                }
                
                pendingQuestion = nil
            }
        } catch {
            await MainActor.run {
                // Update thinking message to show error
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") }) {
                    var errorContent: String
                    
                    // Check if it's a rate limit error
                    if let perplexityError = error as? PerplexityError,
                       case .rateLimitExceeded(let remaining, let resetTime) = perplexityError {
                        // Show rate limit message with remaining questions
                        let formatter = DateFormatter()
                        formatter.timeStyle = .short
                        let resetTimeStr = formatter.string(from: resetTime)
                        
                        errorContent = """
                        **\(text)**
                        
                        📊 **Daily Question Limit Reached**
                        
                        You've used all 10 free questions for today. Your limit resets at \(resetTimeStr).
                        
                        *Your question has been saved and you can try again tomorrow.*
                        
                        💡 **Tip**: Questions are precious! Make them count by:
                        • Combining related questions into one
                        • Using quotes and notes (unlimited) to capture insights
                        • Reflecting before asking
                        """
                    } else {
                        // Generic error message
                        errorContent = "**\(text)**\n\n⚠️ Sorry, I couldn't process your message. \(error.localizedDescription)"
                    }
                    
                    let updatedMessage = UnifiedChatMessage(
                        content: errorContent,
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        messageType: .text
                    )
                    messages[thinkingIndex] = updatedMessage
                }
                pendingQuestion = nil
                print("❌ Failed to get AI response: \(error)")
            }
        }
    }
    
    private func handleBookDetection(_ book: Book?) {
        guard let book = book else { return }
        
        // CRITICAL: Prevent duplicate detections for the same book
        if lastDetectedBookId == book.localId {
            print("📚 Ignoring duplicate book detection: \(book.title)")
            return
        }
        
        // Also check if it's the same as current book context
        if currentBookContext?.localId == book.localId {
            print("📚 Book already set as current context: \(book.title)")
            return
        }
        
        print("📚 Book detected: \(book.title)")
        lastDetectedBookId = book.localId
        
        // Clear the transcription immediately to prevent double appearance
        liveTranscription = ""
        // Visibility controlled by showLiveTranscriptionBubble setting
        
        // Cancel any pending fade timer
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        
        // Save current session before switching books (if there was a previous book)
        if currentBookContext != nil {
            saveCurrentSessionBeforeBookSwitch()
            
            // Start a new session for the detected book
            withAnimation(.easeInOut(duration: 0.5)) {
                currentBookContext = book
                showBookCover = true
                startNewSessionForBook(book)
            }
        } else {
            // First book detection - just update the existing session
            withAnimation(.easeInOut(duration: 0.5)) {
                currentBookContext = book
                showBookCover = true
                
                // Update the current session with the detected book
                if let session = currentSession {
                    session.bookModel = BookModel(from: book)
                    do {
                        try modelContext.save()
                        print("📚 Updated session with first detected book: \(book.title)")
                    } catch {
                        print("❌ Failed to update session with detected book: \(error)")
                    }
                }
            }
        }
        
        // Start timer to hide book cover after 4 seconds
        bookCoverTimer?.invalidate()
        bookCoverTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.8)) {
                showBookCover = false
            }
        }
        
        // Update the TrueAmbientProcessor with the new book context
        TrueAmbientProcessor.shared.updateBookContext(book)
        
        Task {
            await extractColorsForBook(book)
        }
        
        SensoryFeedback.light()
    }
    
    // MARK: - Page Detection
    private func detectPageMention(in text: String) {
        let lowercased = text.lowercased()
        
        // Regex patterns for page mentions
        let patterns = [
            "page (\\d+)",
            "on page (\\d+)",
            "i'm on page (\\d+)",
            "i am on page (\\d+)",
            "reading page (\\d+)",
            "at page (\\d+)",
            "page number (\\d+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.count))
                
                if let match = matches.first,
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: lowercased) {
                    let pageNumberString = String(lowercased[range])
                    if let pageNumber = Int(pageNumberString) {
                        // Update the session with the current page
                        if let session = currentSession {
                            session.currentPage = pageNumber
                            try? modelContext.save()
                            print("📖 Updated current page to: \(pageNumber)")
                            
                            // Show subtle feedback
                            withAnimation(DesignSystem.Animation.easeStandard) {
                                savedItemType = "Page \(pageNumber)"
                                showSaveAnimation = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    showSaveAnimation = false
                                    savedItemType = nil
                                }
                            }
                        }
                        break // Only take the first page mention
                    }
                }
            }
        }
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
        // Visibility controlled by showLiveTranscriptionBubble setting
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        voiceManager.stopListening()
        
        // End processor session
        Task {
            _ = await processor.endSession()
        }
        
        // Dismiss the view immediately
        dismiss()
    }
    
    private func stopAndSaveSession() {
        // Stop recording immediately
        isRecording = false
        liveTranscription = ""
        // Visibility controlled by showLiveTranscriptionBubble setting
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        
        // Stop voice manager first
        voiceManager.stopListening()
        
        // Clean up processor in background
        Task {
            _ = await processor.endSession()
        }
        
        // Finalize the session
        if let session = currentSession {
            session.endTime = Date()
            
            // Force save to ensure all relationships are persisted
            do {
                try modelContext.save()
                print("✅ Session saved with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
            } catch {
                print("❌ Failed to save session: \(error)")
            }
            
            // Debug: Log what we're saving
            print("📊 Session Summary Debug:")
            print("   Questions: \((session.capturedQuestions ?? []).count)")
            for (i, q) in (session.capturedQuestions ?? []).enumerated() {
                print("     \(i+1). \((q.content ?? "").prefix(50))... Answer: \(q.isAnswered ?? false ? "Yes" : "No")")
            }
            print("   Quotes: \((session.capturedQuotes ?? []).count)")
            for (i, quote) in (session.capturedQuotes ?? []).enumerated() {
                print("     \(i+1). \((quote.text ?? "").prefix(50))...")
            }
            print("   Notes: \((session.capturedNotes ?? []).count)")
            for (i, note) in (session.capturedNotes ?? []).enumerated() {
                print("     \(i+1). \((note.content ?? "").prefix(50))...")
            }
            
            // Show summary if there's meaningful content
            if (session.capturedQuestions ?? []).count > 0 || (session.capturedQuotes ?? []).count > 0 || (session.capturedNotes ?? []).count > 0 {
                // Present the session summary sheet
                showingSessionSummary = true
                logger.info("📊 Showing session summary with \((session.capturedQuestions ?? []).count) questions, \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes")
            } else {
                // No meaningful content - just dismiss
                logger.info("📊 No meaningful content in session, dismissing directly")
                dismiss()
            }
        } else {
            // No session - just dismiss
            logger.info("❌ No session found, dismissing")
            dismiss()
        }
    }
    
    private func createSession() -> AmbientSession {
        // Use existing session - it was created at start and items were added during saving
        guard let session = currentSession else {
            print("❌ No current session found!")
            return AmbientSession(book: currentBookContext)
        }
        
        // Just set the end time
        session.endTime = Date()
        
        print("📊 Finalizing session with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
        
        // Save final state
        do {
            try modelContext.save()
            print("✅ Session finalized in SwiftData")
        } catch {
            print("❌ Failed to finalize session: \(error)")
        }
        
        // End processor session in background
        Task.detached { [weak processor] in
            _ = await processor?.endSession()
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
    
    private func saveCurrentSessionBeforeBookSwitch() {
        guard let session = currentSession else { return }
        
        // Save the session with its current book
        session.endTime = Date()
        
        // Ensure all content is saved to the current book
        do {
            try modelContext.save()
            print("✅ Saved session for \(currentBookContext?.title ?? "unknown book") with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
        } catch {
            print("❌ Failed to save session before book switch: \(error)")
        }
    }
    
    private func startNewSessionForBook(_ book: Book) {
        // Set the book context in the detector
        bookDetector.setCurrentBook(book)
        
        // Create a fresh session for the new book
        let newSession = AmbientSession()
        newSession.startTime = Date()
        newSession.bookModel = BookModel(from: book)
        modelContext.insert(newSession)
        currentSession = newSession
        
        // Clear the detected content from previous book
        processor.detectedContent.removeAll()
        
        // Reset counts
        savedItemsCount = 0
        
        do {
            try modelContext.save()
            print("📚 Started new session for book: \(book.title)")
        } catch {
            print("❌ Failed to create new session: \(error)")
        }
    }
    
    private func generatePlaceholderPalette(for book: Book) -> ColorPalette {
        ColorPalette(
            primary: DesignSystem.Colors.primaryAccent.opacity(0.8),
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
            primary: DesignSystem.Colors.primaryAccent,
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
                    withAnimation(DesignSystem.Animation.springStandard) {
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
                        // Save current session content before clearing book
                        saveCurrentSessionBeforeBookSwitch()
                        
                        withAnimation(DesignSystem.Animation.springStandard) {
                            currentBookContext = nil
                            showingBookStrip = false
                            
                            // Create a new session without a book
                            let newSession = AmbientSession()
                            newSession.startTime = Date()
                            newSession.bookModel = nil
                            modelContext.insert(newSession)
                            currentSession = newSession
                            
                            // Clear the detected content
                            processor.detectedContent.removeAll()
                            savedItemsCount = 0
                            
                            do {
                                try modelContext.save()
                                print("📚 Started new session without book context")
                            } catch {
                                print("❌ Failed to create new session: \(error)")
                            }
                        }
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
                    }
                    
                    // Book covers
                    ForEach(libraryViewModel.books) { book in
                        Button {
                            // Save current session content before switching books
                            saveCurrentSessionBeforeBookSwitch()
                            
                            withAnimation(DesignSystem.Animation.springStandard) {
                                currentBookContext = book
                                showingBookStrip = false
                                lastDetectedBookId = book.localId
                                
                                // Create a new session for the new book
                                startNewSessionForBook(book)
                            }
                            Task {
                                await extractColorsForBook(book)
                            }
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
                                        .stroke(Color.white, lineWidth: 2)
                                }
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.listItemPadding)
                .padding(.top, 60)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Ambient Message Thread View (Minimal Style)
// MARK: - Quote View for Live Ambient Mode
struct AmbientQuoteView: View {
    let quote: CapturedQuote
    let index: Int
    let onEdit: (String) -> Void
    
    @State private var quoteOpacity: Double = 0.3
    @State private var quoteBlur: Double = 12
    @State private var quoteScale: CGFloat = 0.96
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(width: 24)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                // Quote icon
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("QUOTE")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1.2)
                    
                    Spacer()
                }
                
                // Quote text with elegant typography - TAPPABLE FOR EDITING
                Text(quote.text ?? "")
                    .font(.custom("Georgia", size: 16))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        SensoryFeedback.light()
                        onEdit(quote.text ?? "")
                    }
                
                // Author attribution if available
                if let author = quote.author {
                    Text("— \(author)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
        .opacity(quoteOpacity)
        .blur(radius: quoteBlur)
        .scaleEffect(quoteScale)
        .onAppear {
            // Check for reduced motion preference
            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            
            if reduceMotion {
                // Simple fade for accessibility
                withAnimation(.easeOut(duration: 0.3)) {
                    quoteOpacity = 1.0
                }
            } else {
                // Sophisticated blur revelation for quotes
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.5)) {
                    quoteOpacity = 1.0
                    quoteBlur = 0
                    quoteScale = 1.0
                }
            }
        }
    }
}

// MARK: - Note View for Live Ambient Mode
struct AmbientNoteView: View {
    let note: CapturedNote
    let index: Int
    let onEdit: (String) -> Void
    
    @State private var noteOpacity: Double = 0.3
    @State private var noteBlur: Double = 12
    @State private var noteScale: CGFloat = 0.96
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Index number
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 24)
                
                // Note content with icon
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                            .foregroundStyle(.yellow.opacity(0.8))
                        
                        Text("Note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.yellow.opacity(0.8))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    
                    Text(note.content ?? "")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                SensoryFeedback.light()
                onEdit(note.content ?? "")
            }
        }
        .padding(.vertical, 16)
        .opacity(noteOpacity)
        .blur(radius: noteBlur)
        .scaleEffect(noteScale)
        .onAppear {
            // Check for reduced motion preference
            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            
            if reduceMotion {
                // Simple fade for accessibility
                withAnimation(.easeOut(duration: 0.3)) {
                    noteOpacity = 1.0
                }
            } else {
                // Sophisticated blur revelation animation
                withAnimation(
                    .timingCurve(0.215, 0.61, 0.355, 1, duration: 0.8)
                ) {
                    noteOpacity = 1.0
                    noteBlur = 0
                    noteScale = 1.0
                }
            }
        }
    }
}

struct AmbientMessageThreadView: View {
    let message: UnifiedChatMessage
    let index: Int
    let totalMessages: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    let onEdit: ((String) -> Void)?
    
    @State private var messageOpacity: Double = 0.3
    @State private var messageBlur: Double = 12
    @State private var messageScale: CGFloat = 0.96
    @State private var showThinkingParticles = false
    @State private var answerOpacity: Double = 0
    @State private var answerBlur: Double = 8
    @State private var hasShownAnswer = false
    
    // Check if this is the first AI response in the session
    private var isFirstAIResponse: Bool {
        // Simplified check - you can make this more robust based on your needs
        !message.isUser && index < 2
    }
    
    private var animationDelay: Double {
        if message.isUser {
            return 0 // User messages appear immediately
        } else {
            return isFirstAIResponse ? 0.6 : 0.4 // AI responses have delay
        }
    }
    
    private var animationDuration: Double {
        isFirstAIResponse ? 0.8 : 0.6
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thinking particles for AI messages (before message appears)
            if !message.isUser && showThinkingParticles {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(DesignSystem.Colors.textQuaternary)
                            .frame(width: 4, height: 4)
                            .blur(radius: 1)
                            .scaleEffect(showThinkingParticles ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: showThinkingParticles
                            )
                    }
                }
                .padding(.leading, 40)
                .opacity(messageOpacity < 1 ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: messageOpacity)
            }
            
            // Question/response row with blur revelation
            HStack(alignment: .center, spacing: 16) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 24)
                
                if message.isUser {
                    Text(message.content)
                        .font(.system(size: 16, weight: .regular, design: .default))  // Match note cards
                        .foregroundStyle(.white.opacity(0.95)) // Match note cards opacity
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Extract question from AI response if formatted
                    let content = extractContent(from: message.content)
                    
                    // Show question text
                    Text(content.question)
                        .font(.system(size: 16, weight: .regular, design: .default))  // Match note cards
                        .foregroundStyle(.white.opacity(0.95)) // Match note cards opacity
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if !message.isUser {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textQuaternary)
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .opacity(messageOpacity)
            .blur(radius: messageBlur) // No extra blur when collapsed
            .scaleEffect(messageScale)
            .onTapGesture {
                if message.isUser {
                    // Edit user questions
                    if let onEdit = onEdit {
                        SensoryFeedback.light()
                        onEdit(message.content)
                    }
                } else {
                    // Toggle expansion for AI responses
                    onToggle()
                }
            }
            .onAppear {
                // Check for reduced motion preference
                let reduceMotion = UIAccessibility.isReduceMotionEnabled
                
                if reduceMotion {
                    // Simple fade for accessibility
                    withAnimation(.easeOut(duration: 0.3).delay(animationDelay)) {
                        messageOpacity = 1.0
                    }
                } else {
                    // Show thinking particles for AI messages
                    if !message.isUser {
                        showThinkingParticles = true
                    }
                    
                    // Sophisticated blur revelation animation
                    withAnimation(
                        .timingCurve(0.215, 0.61, 0.355, 1, duration: animationDuration)
                        .delay(animationDelay)
                    ) {
                        messageOpacity = 1.0
                        messageBlur = 0
                        messageScale = 1.0
                        showThinkingParticles = false
                    }
                }
            }
            
            // Answer (expandable for AI responses) with blur transition
            if !message.isUser && isExpanded {
                let content = extractContent(from: message.content)
                
                // If no answer yet, don't show anything special
                // The scrolling text is already shown above the input field
                if content.answer.isEmpty {
                    // Empty state - answer will appear here when ready
                } else {
                    // Show answer when ready with staggered fade-in
                    VStack(alignment: .leading, spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 0.5)
                        
                        Text(formatResponseText(content.answer))
                            .font(.custom("Georgia", size: 17))  // ← Increased from 15
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(8)  // ← Increased from 6
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 0)  // ← Changed to align under number
                            .padding(.trailing, 20)
                            .padding(.vertical, 12)
                            .padding(.bottom, 4)
                    }
                    .opacity(isExpanded ? answerOpacity : 0)
                    .blur(radius: isExpanded ? answerBlur : 8)
                    .onAppear {
                        // Show answer immediately without delay
                        hasShownAnswer = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            answerOpacity = 1.0
                            answerBlur = 0
                        }
                    }
                    .onChange(of: isExpanded) { _, newValue in
                        // Handle collapse/expand without animation after first show
                        if hasShownAnswer {
                            answerOpacity = newValue ? 1.0 : 0
                            answerBlur = newValue ? 0 : 8
                        }
                    }
                }
            }
        }
    }
    
    private func extractContent(from text: String) -> (question: String, answer: String) {
        // Check if the content is formatted with question and answer
        if text.contains("**") && text.contains("\n\n") {
            let parts = text.components(separatedBy: "\n\n")
            if parts.count >= 2 {
                let question = parts[0].replacingOccurrences(of: "**", with: "")
                let answer = parts.dropFirst().joined(separator: "\n\n")
                return (question, answer)
            }
        }
        // Otherwise return the full text as the question
        return (text, "")
    }
    
    private func formatResponseText(_ text: String) -> AttributedString {
        // Split text into sentences and group into paragraphs
        let sentences = text.components(separatedBy: ". ")
        var paragraphs: [String] = []
        var currentParagraph = ""
        
        for (index, sentence) in sentences.enumerated() {
            let cleanSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanSentence.isEmpty {
                currentParagraph += cleanSentence
                if !cleanSentence.hasSuffix(".") {
                    currentParagraph += "."
                }
                
                // Create paragraph break every 2-3 sentences or at natural breaks
                if (index + 1) % 3 == 0 || 
                   cleanSentence.contains("However") || 
                   cleanSentence.contains("Additionally") ||
                   cleanSentence.contains("Furthermore") ||
                   cleanSentence.contains("In conclusion") ||
                   cleanSentence.contains("First") ||
                   cleanSentence.contains("Second") ||
                   cleanSentence.contains("Finally") {
                    paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
                    currentParagraph = ""
                } else if index < sentences.count - 1 {
                    currentParagraph += " "
                }
            }
        }
        
        // Add any remaining text as final paragraph
        if !currentParagraph.trimmingCharacters(in: .whitespaces).isEmpty {
            paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
        }
        
        // Join paragraphs with double newlines for spacing
        let formattedText = paragraphs.joined(separator: "\n\n")
        
        // Convert to AttributedString with markdown support
        do {
            return try AttributedString(markdown: formattedText)
        } catch {
            return AttributedString(formattedText)
        }
    }
}


