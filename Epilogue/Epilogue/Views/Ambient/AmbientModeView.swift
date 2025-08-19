import SwiftUI
import SwiftData
import Combine
import OSLog
import UIKit
import Vision
import PhotosUI

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientModeView")

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
    @State private var savedItemType: String? = nil
    @State private var showBookCover = false
    @State private var bookCoverTimer: Timer?
    @State private var expandedMessageIds = Set<UUID>()  // Track expanded messages individually
    @State private var showImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var showQuoteHighlighter = false
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
    
    // New keyboard input states
    @State private var inputMode: AmbientInputMode = .listening
    @State private var keyboardText = ""
    @FocusState private var isKeyboardFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
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
    
    // Input mode for keyboard/voice switching
    enum AmbientInputMode {
        case listening          // Voice active
        case paused            // Voice paused, ready for input
        case textInput         // Keyboard active
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
        // Double tap gesture to show keyboard
        .onTapGesture(count: 2) {
            // Double tap anywhere to show keyboard
            if inputMode != .textInput {
                if isRecording {
                    stopRecording()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    inputMode = .textInput
                    isKeyboardFocused = true
                }
                HapticManager.shared.lightTap()
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
            // After summary is dismissed, close ambient mode with a tiny delay to fix transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
            }
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
            setupKeyboardObservers()
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
            } else if newContent.count == lastProcessedCount && newContent.count > 0 {
                // Check for response updates on existing items
                checkForResponseUpdates(in: newContent)
            }
        }
        .onReceive(bookDetector.$detectedBook) { book in
            handleBookDetection(book)
        }
        .onDisappear {
            bookCoverTimer?.invalidate()
            transcriptionFadeTimer?.invalidate()
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
            
            // Don't update transcription if we just detected a book (prevents double showing)
            if cleanedText.lowercased() == "lord of the rings" && lastDetectedBookId != nil {
                return
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
                                   lowercased.contains("reading lord of the rings") ||
                                   lowercased.contains("reading") && libraryViewModel.books.contains { book in
                                       let bookWords = book.title.lowercased().split(separator: " ")
                                       let textWords = lowercased.split(separator: " ")
                                       // Check if significant portion of book title is mentioned
                                       let matchCount = bookWords.filter { word in
                                           textWords.contains(word)
                                       }.count
                                       return matchCount >= min(2, bookWords.count)
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
            // Book cover - show when book is detected, fade after 10 seconds
            if showBookCover, let book = currentBookContext, let coverURL = book.coverImageURL {
                SharedBookCoverView(
                    coverURL: coverURL,
                    width: 140,
                    height: 210
                )
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
            
            // Save indicator above transcription with proper type
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect()
                .clipShape(Capsule())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                    removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top))
                ))
                .padding(.bottom, 12)
                .zIndex(200) // Higher z-index to ensure visibility
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSaveAnimation)
            }
            
            // REMOVED duplicate thinking indicator - only need one in bottomInputArea
            
            // Live transcription with animated glass container (editable)
            if isRecording && !liveTranscription.isEmpty {
                VStack {
                    if isEditingTranscription {
                        TextField("Edit transcription...", text: $editableTranscription)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .focused($isTranscriptionFocused)
                            .onSubmit {
                                let finalText = editableTranscription
                                liveTranscription = ""  // Clear to prevent duplicate processing
                                isEditingTranscription = false
                                
                                // Process as a single complete thought
                                let contentType = determineContentType(finalText)
                                
                                if contentType == .question {
                                    // Handle as question with AI response
                                    let userMessage = UnifiedChatMessage(
                                        content: finalText,
                                        isUser: true,
                                        timestamp: Date(),
                                        bookContext: currentBookContext
                                    )
                                    messages.append(userMessage)
                                    
                                    isWaitingForAIResponse = true
                                    pendingQuestion = finalText
                                    
                                    Task {
                                        await getAIResponse(for: finalText)
                                    }
                                } else {
                                    // Process as note/quote
                                    Task {
                                        await processor.processDetectedText(finalText, confidence: 1.0)
                                    }
                                }
                            }
                    } else {
                        Text(liveTranscription)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .onTapGesture {
                                // Pause any pending AI processing
                                debounceTimer?.invalidate()
                                
                                editableTranscription = liveTranscription
                                isEditingTranscription = true
                                isTranscriptionFocused = true
                                
                                // Clear any pending questions
                                if isWaitingForAIResponse {
                                    isWaitingForAIResponse = false
                                    pendingQuestion = nil
                                }
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
                    // Proper top spacing to prevent scrolling above content
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                        .id("top")
                    
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
                    
                    // Conversation section in minimal thread style
                    if !messages.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            // Section header if we have multiple messages
                            if messages.count > 1 {
                                Text("CONVERSATION")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .tracking(1.2)
                                    .padding(.horizontal, 20)
                            }
                            
                            // Thread-style messages
                            VStack(spacing: 1) {
                                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                    AmbientMessageThreadView(
                                        message: message,
                                        index: index,
                                        isExpanded: expandedMessageIds.contains(message.id),
                                        onToggle: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if expandedMessageIds.contains(message.id) {
                                                    expandedMessageIds.remove(message.id)
                                                } else {
                                                    expandedMessageIds.insert(message.id)
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Bottom spacer for input area with more padding
                    Color.clear
                        .frame(height: 100)
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
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if let lastMessage = messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Clean Bottom Input Area
    @ViewBuilder
    private var bottomInputArea: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // AI thinking indicator - using our existing component
            if isWaitingForAIResponse {
                SubtleLiquidThinking(bookColor: adaptiveUIColor)
                    .scaleEffect(0.6) // Proper size
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.1).combined(with: .opacity)
                    ))
            }
            
            // Single input control that transitions between states
            ZStack {
                // Text input bar - always present but hidden when not in text mode or on summary
                ambientTextInputBar
                    .opacity(inputMode == .textInput && currentSession != nil ? 1 : 0)
                    .scaleEffect(inputMode == .textInput && currentSession != nil ? 1 : 0.8)
                    .allowsHitTesting(inputMode == .textInput && currentSession != nil)
                    .zIndex(inputMode == .textInput ? 1 : 0) // Ensure text input is on top
                
                // Waveform/Stop button - COMPLETELY HIDDEN when text input is active
                if inputMode != .textInput {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            if inputMode == .listening && isRecording {
                                // Tap to stop recording
                                handleMicrophoneTap()
                            } else if inputMode == .paused {
                                // Continue to text input
                                inputMode = .textInput
                                isKeyboardFocused = true
                            } else {
                                // Start recording
                                handleMicrophoneTap()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                                .frame(width: 64, height: 64)
                                .glassEffect()
                                .glassEffectTransition(.materialize)
                            
                            Image(systemName: inputMode == .paused ? "keyboard" : (isRecording ? "stop.fill" : "waveform"))
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                                .symbolEffect(.bounce, value: isRecording)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: inputMode)
                        }
                    }
                    .scaleEffect(inputMode == .paused ? 0.9 : 1.0)
                    .opacity(inputMode == .textInput ? 0 : 1) // Hide when text input
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: inputMode)
                    // Long press gesture for keyboard
                    .onLongPressGesture(minimumDuration: 0.5) {
                        // Long press to show keyboard
                        if isRecording {
                            stopRecording()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            inputMode = .textInput
                            isKeyboardFocused = true
                        }
                        HapticManager.shared.mediumTap()
                    }
                }
            }
            .padding(.bottom, 50) // Single padding for the entire ZStack
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: inputMode)
    }
    
    // MARK: - Text Input Bar Component (Raycast-style)
    private var ambientTextInputBar: some View {
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
                            .foregroundColor(.white.opacity(0.35))
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            
            // Voice return button - proper liquid glass
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    returnToVoiceMode()
                }
            } label: {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .glassEffect(
                        .regular,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20) // Match the voice button's horizontal positioning
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
                // Save quote to SwiftData with session relationship
                saveQuoteToSwiftData(item)
                savedItemsCount += 1
                savedItemType = "Quote"
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
            case .note, .thought:
                // Save note to SwiftData with session relationship
                saveNoteToSwiftData(item)
                savedItemsCount += 1
                savedItemType = item.type == .note ? "Note" : "Thought"
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
                        
                        // Auto-expand new question and close others
                        expandedMessageIds.removeAll() // Close all previous
                        expandedMessageIds.insert(aiMessage.id) // Open new one
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
                if existingQuote.ambientSession == nil || !session.capturedQuotes.contains(where: { $0.id == existingQuote.id }) {
                    existingQuote.ambientSession = session
                    // Check if quote is already in session's captured quotes before adding
                    if !session.capturedQuotes.contains(where: { $0.id == existingQuote.id }) {
                        session.capturedQuotes.append(existingQuote)
                    }
                    try? modelContext.save()
                    print("✅ Linked existing quote to current session")
                }
            }
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
            if !session.capturedQuotes.contains(where: { $0.text == capturedQuote.text }) {
                session.capturedQuotes.append(capturedQuote)
            }
        }
        
        modelContext.insert(capturedQuote)
        
        do {
            try modelContext.save()
            print("✅ Quote saved to SwiftData with session: \(quoteText.prefix(50))...")
            HapticManager.shared.success()
        } catch {
            print("❌ Failed to save quote: \(error)")
        }
    }
    
    private func saveNoteToSwiftData(_ content: AmbientProcessedContent) {
        // Use the raw text as-is for consistency
        let noteText = content.text
        let fetchRequest = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { note in
                note.content == noteText
            }
        )
        
        if let existingNotes = try? modelContext.fetch(fetchRequest), !existingNotes.isEmpty {
            print("⚠️ Note already exists, skipping save: \(noteText.prefix(30))...")
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
        
        // CRITICAL: Set the session relationship immediately
        if let session = currentSession {
            capturedNote.ambientSession = session
            session.capturedNotes.append(capturedNote)
        }
        
        modelContext.insert(capturedNote)
        
        do {
            try modelContext.save()
            print("✅ Note saved to SwiftData with session: \(content.text.prefix(50))...")
            HapticManager.shared.success()
        } catch {
            print("❌ Failed to save note: \(error)")
        }
    }
    
    private func saveQuestionToSwiftData(_ content: AmbientProcessedContent) {
        // Use the raw text as-is for consistency
        let questionText = content.text
        
        // CRITICAL: Check for duplicate questions in current session
        guard let session = currentSession else { return }
        
        // Check if question already exists in this session
        let isDuplicate = session.capturedQuestions.contains { question in
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
                    if !session.capturedQuestions.contains(where: { $0.id == existingQuestion.id }) {
                        session.capturedQuestions.append(existingQuestion)
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
                print("   Session now has \(currentSession?.capturedQuestions.count ?? 0) questions")
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
            if !session.capturedQuestions.contains(where: { $0.content == capturedQuestion.content }) {
                session.capturedQuestions.append(capturedQuestion)
            }
        }
        
        modelContext.insert(capturedQuestion)
        
        do {
            try modelContext.save()
            print("✅ Question saved to SwiftData with session: \(questionText.prefix(50))...")
            print("   Session now has \(currentSession?.capturedQuestions.count ?? 0) questions")
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
        processor.setModelContext(modelContext)
        processor.setCurrentSession(session)
        processor.startSession()
        
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
    
    // MARK: - Input Mode Management
    
    private func pauseForTextInput() {
        // Pause recording but keep session active
        if isRecording {
            stopRecording()
        }
        
        // First transition to paused state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            inputMode = .paused
        }
        
        HapticManager.shared.lightTap()
    }
    
    private func resumeVoiceInput() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            inputMode = .listening
        }
        startRecording()
    }
    
    private func returnToVoiceMode() {
        // Clear keyboard
        isKeyboardFocused = false
        keyboardText = ""
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            inputMode = .listening
        }
        
        // Resume recording after animation - maintain book context
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Don't change currentBookContext - maintain it
            startRecording()
        }
    }
    
    private func sendTextMessage() {
        guard !keyboardText.isEmpty else { return }
        
        let messageText = keyboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        keyboardText = "" // Clear immediately
        
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
            processor.detectedContent.append(content)
            
            // For questions, show thinking and get AI response
            isWaitingForAIResponse = true
            pendingQuestion = messageText
            
            // Get AI response - it will handle updating with the response
            Task {
                await getAIResponseForAmbientQuestion(messageText)
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
            
            // Add to processor for saving
            processor.detectedContent.append(content)
            
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
           lowercased.starts(with: "tell me about") ||
           lowercased.starts(with: "explain") {
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
                isWaitingForAIResponse = false
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
                isWaitingForAIResponse = false  // Clear thinking indicator
                let aiMessage = UnifiedChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                messages.append(aiMessage)
                
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
                }
                pendingQuestion = nil
            }
        } catch {
            await MainActor.run {
                isWaitingForAIResponse = false  // Clear thinking indicator
                let errorMessage = UnifiedChatMessage(
                    content: "Sorry, I couldn't process your message.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBookContext
                )
                messages.append(errorMessage)
                pendingQuestion = nil
            }
        }
    }
    
    private func getAIResponseForAmbientQuestion(_ text: String) async {
        let aiService = AICompanionService.shared
        
        guard aiService.isConfigured() else {
            await MainActor.run {
                isWaitingForAIResponse = false
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
                isWaitingForAIResponse = false
                pendingQuestion = nil
                
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
            }
        } catch {
            await MainActor.run {
                isWaitingForAIResponse = false
                pendingQuestion = nil
                print("❌ Failed to get AI response for ambient question: \(error)")
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
        showLiveTranscription = false
        
        // Cancel any pending fade timer
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentBookContext = book
            showBookCover = true
        }
        
        // Start timer to hide book cover after 10 seconds
        bookCoverTimer?.invalidate()
        bookCoverTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.8)) {
                showBookCover = false
            }
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
        // Stop recording immediately
        isRecording = false
        liveTranscription = ""
        showLiveTranscription = false
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        
        // Stop voice manager first
        voiceManager.stopListening()
        
        // Clean up processor in background
        Task {
            await processor.endSession()
        }
        
        // Finalize the session
        if let session = currentSession {
            session.endTime = Date()
            
            // Force save to ensure all relationships are persisted
            do {
                try modelContext.save()
                print("✅ Session saved with \(session.capturedQuotes.count) quotes, \(session.capturedNotes.count) notes, \(session.capturedQuestions.count) questions")
            } catch {
                print("❌ Failed to save session: \(error)")
            }
            
            // Show summary if there's meaningful content
            if session.capturedQuestions.count > 0 || session.capturedQuotes.count > 0 || session.capturedNotes.count > 0 {
                // Present the session summary sheet
                showingSessionSummary = true
                logger.info("📊 Showing session summary with \(session.capturedQuestions.count) questions, \(session.capturedQuotes.count) quotes, \(session.capturedNotes.count) notes")
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
        
        print("📊 Finalizing session with \(session.capturedQuotes.count) quotes, \(session.capturedNotes.count) notes, \(session.capturedQuestions.count) questions")
        
        // Save final state
        do {
            try modelContext.save()
            print("✅ Session finalized in SwiftData")
        } catch {
            print("❌ Failed to finalize session: \(error)")
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

// MARK: - Ambient Message Thread View (Minimal Style)
struct AmbientMessageThreadView: View {
    let message: UnifiedChatMessage
    let index: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Question/response row
            HStack(alignment: .center, spacing: 16) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 24)
                
                if message.isUser {
                    Text(message.content)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Extract question from AI response if formatted
                    let content = extractContent(from: message.content)
                    Text(content.question)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if !message.isUser {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                if !message.isUser {
                    onToggle()
                }
            }
            
            // Answer (expandable for AI responses)
            if !message.isUser && isExpanded {
                let content = extractContent(from: message.content)
                if !content.answer.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 0.5)
                        
                        Text(try! AttributedString(markdown: content.answer))
                            .font(.custom("Georgia", size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 40)
                            .padding(.trailing, 20)  // Add right padding for better spacing
                            .padding(.vertical, 12)
                            .padding(.bottom, 4)  // Extra padding at bottom since we removed the line
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
}