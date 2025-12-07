import SwiftUI
import SwiftData
import Combine
import OSLog
import UIKit
import Vision
import PhotosUI
import AVFoundation
import Speech
import TipKit

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientModeView")

// MARK: - Scrolling Book Messages for Loading State
struct ScrollingBookMessages: View {
    @State private var currentMessageIndex = 0
    @State private var opacity: Double = 1.0
    @State private var usedIndices: Set<Int> = []
    @State private var cyclingTimer: Timer?
    
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
            .onDisappear {
                cyclingTimer?.invalidate()
                cyclingTimer = nil
            }
    }
    
    private func startCycling() {
        cyclingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
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
    @StateObject private var microInteractionManager = MicroInteractionManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var storeKit = SimplifiedStoreKitManager.shared

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
    @State private var relatedQuestionsMap: [UUID: [String]] = [:]  // Related questions per AI message
    @State private var showImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var showQuoteHighlighter = false
    @State private var cameraJustUsed = false
    @State private var isProcessingImage = false
    @State private var streamingResponses: [UUID: String] = [:]  // Track streaming text by message ID
    @State private var processedContentHashes = Set<String>() // Deduplication
    @State private var transcriptionFadeTimer: Timer?
    @State private var isTranscriptionDissolving = false
    @State private var currentSession: AmbientSession?
    @State private var showingSessionSummary = false
    @State private var showPaywall = false
    @State private var sessionStartTime: Date?
    @State private var isEditingTranscription = false
    @State private var editableTranscription = ""
    @FocusState private var isTranscriptionFocused: Bool
    // Removed: isWaitingForAIResponse and shouldCollapseThinking - now using inline thinking messages
    @State private var pendingQuestion: String?
    @State private var isGenericModeThinking = false  // Typing indicator for Generic mode
    @State private var lastProcessedCount = 0
    @State private var showRecommendationFlow = false  // Quick question flow for recommendations
    @State private var recommendationContext: RecommendationContext? = nil  // Context from questions
    @State private var showReadingPlanFlow: ReadingPlanQuestionFlow.FlowType? = nil  // Reading habit/challenge flow
    @State private var readingPlanContext: ReadingPlanContext? = nil
    @State private var debounceTimer: Timer?
    @State private var createdReadingPlan: ReadingHabitPlan? = nil  // Newly created plan to display
    @State private var showPlanDetail = false  // Show full plan detail view
    @State private var showLocalToast = false  // Local toast for ambient mode
    @State private var localToastMessage = ""
    @Query(filter: #Predicate<ReadingHabitPlan> { $0.isActive == true }, sort: \ReadingHabitPlan.createdAt, order: .reverse)
    private var activeReadingPlans: [ReadingHabitPlan]  // Query for active plans

    @Query(sort: \BookModel.dateAdded, order: .reverse)
    private var allBookModels: [BookModel]  // For book selection in reading plans
    
    // New keyboard input states
    @State private var inputMode: AmbientInputMode = .listening
    @State private var keyboardText = ""
    @State private var containerBlur: Double = 0
    @State private var submitBlurWave: Double = 0
    @State private var textFieldHeight: CGFloat = 44  // Track dynamic height, starts compact at single line
    @State private var lastCharacterCount: Int = 0
    @State private var breathingTimer: Timer?
    @State private var showVisualIntelligenceCapture = false
    @Namespace private var morphingNamespace  // For smooth morphing animation
    @FocusState private var isKeyboardFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    // Smooth gradient transitions - start visible
    @State private var gradientOpacity: Double = 1.0  // Start visible immediately
    @State private var lastBookId: UUID? = nil
    
    // Inline editing states
    @State private var editingMessageId: UUID? = nil
    @State private var editingMessageType: UnifiedChatMessage.MessageType? = nil

    // Onboarding states
    @State private var showOnboarding = true
    @State private var onboardingOpacity: Double = 0.0
    @State private var onboardingTimer: Timer?
    @AppStorage("ambientModeOnboardingShown") private var onboardingShownCount: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var isPresentedModally = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var appStateCoordinator: AppStateCoordinator
    
    // Settings
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("showLiveTranscriptionBubble") private var showLiveTranscriptionBubble = true
    @AppStorage("alwaysShowInput") private var alwaysShowInput = false
    
    // Voice mode state
    @State private var isVoiceModeEnabled = true
    
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

    // Available books for reading plan selection (excludes current book context if present)
    private var availableBooksForPlan: [Book] {
        // Deduplicate by book ID (keep first occurrence, usually most recently added)
        var seenIds = Set<String>()
        return allBookModels
            .filter { $0.isInLibrary } // Only books actually in library
            .filter { $0.readingStatus == ReadingStatus.currentlyReading.rawValue || $0.readingStatus == ReadingStatus.wantToRead.rawValue }
            .filter { currentBookContext == nil || $0.id != currentBookContext?.id }
            .filter { book in
                if seenIds.contains(book.id) {
                    return false
                }
                seenIds.insert(book.id)
                return true
            }
            .map { $0.toBook() }
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

            // Double-tap hint pill (shows only once, above the stop button)
            VStack {
                Spacer()
                DoubleTapHintPill()
                    .padding(.bottom, 140)  // Position above the stop button
            }
            .zIndex(100)  // Ensure it's on top

            // Onboarding text overlay - only show when there's no empty state visible
            if showOnboarding && onboardingShownCount < 5 && !messages.isEmpty {
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 28) {
                        Text("Ambient Reading")
                            .font(.system(size: 32, weight: .regular, design: .default))
                            .foregroundStyle(.white)
                            .tracking(0.5)

                        Text("What are you reading today? Just say the\nbook title and lose yourself in the pages.")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(onboardingOpacity)
                .animation(.easeInOut(duration: 0.8), value: onboardingOpacity)
                .allowsHitTesting(false)
                .zIndex(200)
            }

            // Recommendation question flow overlay (for generic mode)
            if showRecommendationFlow {
                RecommendationQuestionFlow(
                    onComplete: { context in
                        handleRecommendationFlowComplete(context)
                    },
                    onDismiss: {
                        withAnimation(DesignSystem.Animation.springStandard) {
                            showRecommendationFlow = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(300)
            }

            // Reading plan/habit/challenge question flow overlay
            if let flowType = showReadingPlanFlow {
                ReadingPlanQuestionFlow(
                    flowType: flowType,
                    preselectedBook: currentBookContext,
                    availableBooks: availableBooksForPlan,
                    onComplete: { context in
                        handleReadingPlanFlowComplete(context)
                    },
                    onDismiss: {
                        withAnimation(DesignSystem.Animation.springStandard) {
                            showReadingPlanFlow = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(300)
            }
        }
        // Double tap gesture to show keyboard
        .onTapGesture(count: 2) {
            // Hide onboarding immediately on interaction
            if showOnboarding {
                fadeOutOnboarding()
            }

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
        // Top toolbar overlay
        .overlay(alignment: .top) {
            HStack {
                Spacer()

                // Only show offline status when actually offline
                if !OfflineQueueManager.shared.isOnline {
                    OfflineStatusPill()
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.top, 60) // Below status bar
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: OfflineQueueManager.shared.isOnline)
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
        .fullScreenCover(isPresented: $showingSessionSummary, onDismiss: {
            // Clean dismissal - coordinator handles everything
            EpilogueAmbientCoordinator.shared.dismiss()
            dismiss()
        }) {
            if let session = currentSession {
                AmbientSessionSummaryView(
                    session: session,
                    colorPalette: colorPalette,
                    onDismiss: {
                        // Just dismiss the sheet - the onDismiss handler above will handle navigation
                        #if DEBUG
                        print("✅ Done button tapped in session summary")
                        #endif
                        showingSessionSummary = false
                    }
                )
                .environment(\.modelContext, modelContext)
                .environmentObject(libraryViewModel)
                .environmentObject(notesViewModel)
            }
        }
        .onAppear {
            // Trigger micro-interaction for double-tap hint
            MicroInteractionManager.shared.enteredAmbientMode()

            // Check if we have an initial book from the coordinator
            if let initialBook = EpilogueAmbientCoordinator.shared.initialBook {
                currentBookContext = initialBook
                lastDetectedBookId = initialBook.localId
                #if DEBUG
                print("📚 Starting ambient mode with book: \(initialBook.title)")
                #endif

                // Check cache synchronously first for instant load
                Task { @MainActor in
                    if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: initialBook.localId.uuidString) {
                        #if DEBUG
                        print("✅ Instant cache hit for: \(initialBook.title)")
                        #endif
                        self.colorPalette = cachedPalette
                    }
                    // Then fetch if needed (this will also check cache)
                    await extractColorsForBook(initialBook)
                }

                // Clear the initial book from coordinator after using it
                EpilogueAmbientCoordinator.shared.initialBook = nil
            }

            // For generic mode (no book), default to text input (not voice)
            let isGenericMode = EpilogueAmbientCoordinator.shared.ambientMode.isGeneric

            // Initialize voice mode based on settings, but ALWAYS disable for generic mode
            if isGenericMode {
                // Generic mode is text-first - voice can be enabled by tapping the orb
                isVoiceModeEnabled = false
                inputMode = .textInput
                textFieldHeight = 44
                liveTranscription = ""
                voiceManager.transcribedText = ""
                containerBlur = 0
            } else {
                // Book mode uses voice setting preference
                isVoiceModeEnabled = !alwaysShowInput

                if !isVoiceModeEnabled {
                    inputMode = .textInput
                    textFieldHeight = 44
                    liveTranscription = ""
                    voiceManager.transcribedText = ""
                    containerBlur = 0
                }
            }
            
            startAmbientExperience()
            setupKeyboardObservers()
            
            // Auto-expand the first AI response if it exists
            if let firstAIResponse = messages.first(where: { !$0.isUser }) {
                expandedMessageIds.insert(firstAIResponse.id)
            }

            // Gradient already visible (starts at 1.0)

            // Handle onboarding
            if onboardingShownCount < 5 {
                showOnboarding = true
                // Fade in after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeIn(duration: 1.0)) {
                        onboardingOpacity = 1.0
                    }
                }

                // Start timer to fade out after 20 seconds
                onboardingTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { _ in
                    fadeOutOnboarding()
                }

                // Increment shown count
                onboardingShownCount += 1
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
        // Single unified listener for all content updates
        .onReceive(processor.$detectedContent) { newContent in
            // Handle new content items (questions, notes, quotes)
            if newContent.count > lastProcessedCount {
                let newItems = Array(newContent.suffix(newContent.count - lastProcessedCount))
                
                // Process questions immediately to create "Thinking..." message
                for item in newItems where item.type == .question {
                    // Check if we already have a message for this question
                    let hasMessage = messages.contains { msg in
                        !msg.isUser && msg.content.contains("**\(item.text)**")
                    }
                    
                    #if DEBUG
                    print("🔍 Checking for existing message for: \(item.text.prefix(30))... Found: \(hasMessage)")
                    #endif
                    
                    if !hasMessage {
                        // Create the "Thinking..." message immediately
                        let thinkingMessage = UnifiedChatMessage(
                            content: "**\(item.text)**",
                            isUser: false,
                            timestamp: Date(),
                            messageType: .text
                        )
                        messages.append(thinkingMessage)
                        
                        // Auto-expand the thinking message and collapse others
                        // Use a refined delay for perfect timing
                        let messageId = thinkingMessage.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            // Subtle haptic when new question appears
                            SensoryFeedback.light()
                            
                            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.825, blendDuration: 0)) {
                                #if DEBUG
                                print("📊 Before expansion: expanded IDs = \(expandedMessageIds.count)")
                                #endif
                                expandedMessageIds.removeAll()
                                expandedMessageIds.insert(messageId)
                                #if DEBUG
                                print("📊 After expansion: expanded IDs = \(expandedMessageIds.count), contains new message: \(expandedMessageIds.contains(messageId))")
                                #endif
                            }
                        }
                        
                        #if DEBUG
                        print("🔄 Created thinking message with ID: \(messageId) for: \(item.text.prefix(30))...")
                        #endif
                    }
                }
                
                // Process other content with delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    processAndSaveDetectedContent(newItems)
                }
                lastProcessedCount = newContent.count
            }
            
            // Handle progressive response updates immediately
            for item in newContent.suffix(5) where item.type == .question {
                if let response = item.response, !response.isEmpty && response != "Thinking..." {
                    // Clear the thinking indicator when streaming starts
                    if pendingQuestion != nil {
                        pendingQuestion = nil
                    }

                    // Use question text + response length as unique key
                    let responseKey = "\(item.text)_\(response.count)"

                    // Only update if this is a new response or longer than what we have
                    if !processedContentHashes.contains(responseKey) {
                        processedContentHashes.insert(responseKey)

                        // Find the message to update
                        if let existingMsgIndex = messages.lastIndex(where: { msg in
                            !msg.isUser && msg.content.contains("**\(item.text)**")
                        }) {
                            let currentMsg = messages[existingMsgIndex]
                            let messageId = currentMsg.id
                            
                            // Update streaming text for this message ID
                            let currentStreamingText = streamingResponses[messageId] ?? ""
                            
                            // Only update if we have more text
                            if response.count > currentStreamingText.count {
                                // Clean citations from response and fix spacing
                                let cleanedResponse = response
                                    .replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
                                    .replacingOccurrences(of: #"\.([A-Z])"#, with: ". $1", options: .regularExpression) // Add space after period before capital letter
                                    .replacingOccurrences(of: #"\?([A-Z])"#, with: "? $1", options: .regularExpression) // Add space after question mark
                                    .replacingOccurrences(of: #"\!([A-Z])"#, with: "! $1", options: .regularExpression) // Add space after exclamation
                                    .replacingOccurrences(of: "  ", with: " ") // Clean up any double spaces
                                
                                // Update the streaming text with buttery smooth animation
                                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.86, blendDuration: 0.25)) {
                                    streamingResponses[messageId] = cleanedResponse
                                }
                                
                                // Make sure the message stays expanded during streaming
                                if !expandedMessageIds.contains(messageId) {
                                    #if DEBUG
                                    print("⚠️ Message lost expansion during streaming, re-expanding...")
                                    #endif
                                    expandedMessageIds.insert(messageId)
                                }
                                
                                #if DEBUG
                                print("📝 Progressive update: \(response.count) chars (smooth), expanded: \(expandedMessageIds.contains(messageId))")
                                #endif
                                
                                // Also update the saved question in SwiftData
                                if let session = currentSession,
                                   let savedQuestion = (session.capturedQuestions ?? []).first(where: { $0.content == item.text }),
                                   savedQuestion.answer != response {
                                    savedQuestion.answer = response
                                    try? modelContext.save()
                                }
                            }
                        } else {
                            #if DEBUG
                            print("⚠️ No message found to update for: \(item.text.prefix(30))...")
                            #endif
                        }
                    }
                }
            }
        }
        .onReceive(bookDetector.$detectedBook) { book in
            // Smooth gradient transition when book changes
            if book?.localId != lastBookId {
                withAnimation(.easeOut(duration: 0.2)) {
                    gradientOpacity = 0.7 // Keep mostly visible
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    handleBookDetection(book)
                    lastBookId = book?.localId

                    // Fade back to full quickly
                    withAnimation(.easeIn(duration: 0.3)) {
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
            
            // Stop any active recording
            if isRecording {
                stopRecording()
            }
        }
        // Camera temporarily disabled due to memory issues
        /*
        .sheet(isPresented: $showImagePicker) {
            SnapshotTextSelector(
                isPresented: $showImagePicker,
                onQuoteSaved: { text, pageNumber in
                    // Save quote with attribution
                    saveQuoteWithAttribution(text, pageNumber: pageNumber)
                },
                onQuestionAsked: { text in
                    // Ask Perplexity about the selected text
                    Task {
                        await askPerplexityAboutText(text)
                    }
                }
            )
        }
        */
        .sheet(isPresented: $showQuoteHighlighter) {
            QuoteHighlighterView(
                image: capturedImage,
                extractedText: extractedText,
                onSave: saveHighlightedQuote
            )
        }
        .fullScreenCover(isPresented: $showVisualIntelligenceCapture) {
            // Direct to LiveTextQuoteCapture - no interstitial
            if #available(iOS 16.0, *) {
                LiveTextQuoteCapture(
                    bookContext: currentBookContext,
                    onQuoteSaved: { text, pageNumber in
                        saveQuoteFromVisualIntelligence(text, pageNumber: pageNumber)
                        showVisualIntelligenceCapture = false
                    },
                    onQuestionAsked: { question in
                        keyboardText = question
                        sendTextMessage()
                        showVisualIntelligenceCapture = false
                    }
                )
            }
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
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
        }
        .sheet(isPresented: $showPlanDetail) {
            if let plan = createdReadingPlan ?? activeReadingPlans.first {
                NavigationStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        AmbientChatGradientView()
                            .ignoresSafeArea()

                        ReadingPlanTimelineView(plan: plan)
                    }
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showPlanDetail = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("Pause Plan", systemImage: "pause.circle") {
                                    plan.pause()
                                    try? modelContext.save()
                                }
                                Divider()
                                Button("Delete Plan", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(plan)
                                    try? modelContext.save()
                                    createdReadingPlan = nil
                                    showPlanDetail = false
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                }
            }
        }
        .onReceive(voiceManager.$transcribedText) { text in
            // CRITICAL: Only update if actually recording AND voice mode is enabled
            guard isRecording && isVoiceModeEnabled else {
                // Clear everything when not recording or voice mode disabled
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
                #if DEBUG
                print("📝 Live transcription received: \(cleanedText)")
                #endif
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
            
            // Detect book mentions - but NOT in generic mode
            // Generic mode should stay generic unless user explicitly requests a book
            let isGenericMode = EpilogueAmbientCoordinator.shared.ambientMode.isGeneric
            if cleanedText.count > 5 && !isGenericMode {
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
        .onAppear {
            // Don't set isPresentedModally - let the close button handle dismissal
            isPresentedModally = false

            // Configure offline queue manager
            OfflineQueueManager.shared.configure(with: modelContext)

            // Load existing session context if continuing from a previous session
            loadExistingSessionIfAvailable()

            // Set up listener for queued questions being processed
            NotificationCenter.default.addObserver(
                forName: Notification.Name("QueuedQuestionProcessed"),
                object: nil,
                queue: .main
            ) { notification in
                if let question = notification.object as? QueuedQuestion,
                   let response = question.response,
                   let questionText = question.question {
                    // Update messages to show the answer
                    let answerMessage = UnifiedChatMessage(
                        content: "**\(questionText)**\n\n\(response)",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(answerMessage)
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: Notification.Name("QueuedQuestionProcessed"), object: nil)
        }
        // Local toast for ambient mode (since fullScreenCover covers ContentView's toast)
        .overlay(alignment: .top) {
            if showLocalToast {
                Text(localToastMessage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.2)))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 60)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showLocalToast = false
                            }
                        }
                    }
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
            
            // Voice responsive bottom gradient - show when voice mode is enabled
            VoiceResponsiveBottomGradient(
                colorPalette: colorPalette,
                audioLevel: audioLevel,
                isRecording: isRecording || isVoiceModeEnabled,
                bookContext: currentBookContext
            )
            .allowsHitTesting(false)
            .ignoresSafeArea(.all)
            .opacity(isVoiceModeEnabled || isRecording ? 1 : 0)
            .animation(.easeInOut(duration: 0.5), value: isVoiceModeEnabled)
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
                    
                    if !hasRealContent && !showRecommendationFlow && showReadingPlanFlow == nil {
                        if currentBookContext == nil {
                            // Generic ambient mode - beautiful liquid glass pills
                            GenericAmbientEmptyState(
                                onSuggestionTap: { suggestion in
                                    handleSuggestionTap(suggestion)
                                },
                                librarySize: libraryViewModel.books.count,
                                recentBookTitle: recentlyReadBookTitle
                            )
                            .opacity(isRecording ? 0.8 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: isRecording)
                        } else if let book = currentBookContext {
                            // Book-specific ambient mode - intelligent contextual pills
                            BookSpecificEmptyState(
                                book: book,
                                colorPalette: colorPalette,
                                currentPage: book.currentPage > 0 ? book.currentPage : nil,
                                hasNotes: currentBookHasNotes,
                                hasQuotes: currentBookHasQuotes,
                                onSuggestionTap: { suggestion in
                                    handleBookSuggestionTap(suggestion)
                                },
                                onCaptureQuote: {
                                    showImagePicker = true
                                }
                            )
                            .opacity(isRecording ? 0.8 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: isRecording)
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
                                    } else if case .bookRecommendations(let recommendations) = message.messageType {
                                        // Display book recommendations with interactive cards
                                        BookRecommendationsMessageView(
                                            recommendations: recommendations,
                                            introText: message.content,
                                            onAddToLibrary: { rec in
                                                addRecommendationToLibrary(rec)
                                            },
                                            onPurchase: { url in
                                                openPurchaseURL(url)
                                            }
                                        )
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    } else if case .conversationalResponse(let text, let followUps) = message.messageType {
                                        // Display conversational response with follow-up questions
                                        ConversationalResponseMessageView(
                                            text: text,
                                            followUpQuestions: followUps,
                                            onFollowUpTap: { question in
                                                // Send the follow-up question as user input
                                                SensoryFeedback.light()
                                                Task {
                                                    await sendMessage(question)
                                                }
                                            }
                                        )
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    } else if currentBookContext == nil {
                                        // Generic mode (no book context): Use chat bubble style (no numbered format)
                                        GenericModeChatBubble(
                                            message: message,
                                            isExpanded: expandedMessageIds.contains(message.id),
                                            onToggle: {
                                                SensoryFeedback.selection()
                                                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0)) {
                                                    if expandedMessageIds.contains(message.id) {
                                                        expandedMessageIds.remove(message.id)
                                                    } else {
                                                        expandedMessageIds.insert(message.id)
                                                    }
                                                }
                                            }
                                        )
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    } else if message.isUser {
                                        // Book mode: Skip user messages - AI responses contain embedded question
                                        // This prevents duplicate numbered items (user question + AI response with same question)
                                        EmptyView()
                                    } else {
                                        // Book mode: Use numbered thread format for AI responses only
                                        // AI responses contain both question and answer in format: **Question**\n\nAnswer
                                        let aiOnlyMessages = messages.filter { !$0.isUser }
                                        let aiIndex = aiOnlyMessages.firstIndex(where: { $0.id == message.id }) ?? 0

                                        AmbientMessageThreadView(
                                            message: message,
                                            index: aiIndex,
                                            totalMessages: aiOnlyMessages.count,
                                            isExpanded: expandedMessageIds.contains(message.id),
                                            streamingText: streamingResponses[message.id],
                                            relatedQuestions: relatedQuestionsMap[message.id] ?? [],
                                            onToggle: {
                                                // Refined haptic feedback
                                                SensoryFeedback.selection()

                                                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0)) {
                                                    if expandedMessageIds.contains(message.id) {
                                                        expandedMessageIds.remove(message.id)
                                                    } else {
                                                        expandedMessageIds.insert(message.id)
                                                    }
                                                }
                                            },
                                            onEdit: nil,  // AI responses don't have edit capability here
                                            onRelatedQuestionTap: { question in
                                                // Continue conversation with the tapped question
                                                handleRelatedQuestionTap(question)
                                            },
                                            showPaywall: $showPaywall
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        }
                    }

                    // Reading Plan Card - appears after AI generates plan
                    if let plan = createdReadingPlan {
                        ReadingPlanCard(
                            plan: plan,
                            onTap: {
                                showPlanDetail = true
                            },
                            onMarkComplete: {
                                plan.markDayComplete(plan.currentDayNumber)
                                SensoryFeedback.success()
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .id("reading-plan-card")
                    }

                    // Generic Mode typing indicator (V0 pattern)
                    if isGenericModeThinking && currentBookContext == nil {
                        GenericModeTypingIndicator()
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            .id("typing-indicator")
                    }

                    // Bottom spacer for input area - adjusted for keyboard mode
                    // Add more bottom padding to ensure content is scrollable above input
                    Color.clear
                        .frame(height: inputMode == .textInput ? 80 : 160)
                        .id("bottom")
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical) // Prevent excessive bouncing
            .scrollDismissesKeyboard(.immediately)
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
            Text("Ambient Reading")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))

            Text("What are you reading today? Just say the book title and lose yourself in the pages.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Generic Ambient Mode Helpers

    /// Get the title of a recently read book for suggestions
    private var recentlyReadBookTitle: String? {
        libraryViewModel.books
            .filter { $0.readingStatus == .currentlyReading }
            .first?.title ?? libraryViewModel.books.first?.title
    }

    /// Check if current book has notes (via BookModel lookup)
    private var currentBookHasNotes: Bool {
        guard let book = currentBookContext else { return false }
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.id == book.id }
        )
        guard let bookModel = try? modelContext.fetch(descriptor).first else { return false }
        return !(bookModel.notes?.isEmpty ?? true)
    }

    /// Check if current book has quotes (via BookModel lookup)
    private var currentBookHasQuotes: Bool {
        guard let book = currentBookContext else { return false }
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.id == book.id }
        )
        guard let bookModel = try? modelContext.fetch(descriptor).first else { return false }
        return !(bookModel.quotes?.isEmpty ?? true)
    }

    /// Handle tapping a suggestion pill - shows question flow for recommendations or populates input
    private func handleSuggestionTap(_ suggestion: String) {
        let lowercased = suggestion.lowercased()

        // Check for recommendation requests
        let isRecommendationRequest = lowercased.contains("read next") ||
                                       lowercased.contains("recommend") ||
                                       lowercased.contains("something like")

        // Check for reading habit flow
        let isHabitRequest = lowercased.contains("reading habit") ||
                             lowercased.contains("build a habit")

        // Check for reading challenge flow
        let isChallengeRequest = lowercased.contains("reading challenge") ||
                                  lowercased.contains("create a challenge")

        // Check for reading taste/patterns analysis
        let isAnalysisRequest = lowercased.contains("reading taste") ||
                                 lowercased.contains("reading patterns") ||
                                 lowercased.contains("analyze my")

        if isRecommendationRequest {
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = nil  // Dismiss any existing plan card
                showRecommendationFlow = true
            }
        } else if isHabitRequest {
            isKeyboardFocused = false // Dismiss keyboard before showing flow
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = nil  // Dismiss any existing plan card
                showReadingPlanFlow = .habit
            }
        } else if isChallengeRequest {
            isKeyboardFocused = false // Dismiss keyboard before showing flow
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = nil  // Dismiss any existing plan card
                showReadingPlanFlow = .challenge
            }
        } else if isAnalysisRequest {
            // Trigger reading taste analysis directly with library context
            triggerReadingTasteAnalysis()
        } else {
            // Populate the input bar with the suggestion text
            keyboardText = suggestion
            inputMode = .textInput
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isKeyboardFocused = true
            }
        }
    }

    /// Handle tapping a book-specific suggestion pill
    /// Uses a clean pattern similar to generic mode for reliable display
    private func handleBookSuggestionTap(_ suggestion: String) {
        guard let book = currentBookContext else {
            // Fallback to generic if no book context
            keyboardText = suggestion
            sendTextMessage()
            return
        }

        let lowercased = suggestion.lowercased()

        // Check for similar books request
        if lowercased.contains("similar") || lowercased.contains("like this") {
            // Show recommendation flow with book context
            withAnimation(DesignSystem.Animation.springStandard) {
                showRecommendationFlow = true
            }
            return
        }

        // Enhance the question with book context for better AI responses
        let enhancedQuestion: String
        if lowercased.contains("theme") {
            enhancedQuestion = "What are the main themes in \(book.title) by \(book.author)?"
        } else if lowercased.contains("about") {
            enhancedQuestion = "Tell me about \(book.author), the author of \(book.title)"
        } else if lowercased.contains("review my notes") {
            enhancedQuestion = "Summarize my notes for \(book.title)"
        } else if lowercased.contains("summarize where") {
            enhancedQuestion = "Summarize where I am in \(book.title) - I'm on page \(book.currentPage)"
        } else {
            enhancedQuestion = suggestion
        }

        // Use clean conversation pattern (like generic mode)
        sendToBookAIConversation(enhancedQuestion, book: book, displayQuestion: suggestion)
    }

    /// Clean book AI conversation - uses **Question**\n\nAnswer format for book mode UI
    private func sendToBookAIConversation(_ text: String, book: Book, displayQuestion: String) {
        // Ensure session exists
        startAmbientSessionIfNeeded()

        // Collapse previous messages
        withAnimation(DesignSystem.Animation.easeStandard) {
            expandedMessageIds.removeAll()
        }

        // Get AI response (will create combined Q&A message)
        Task {
            await getBookAIResponse(for: text, book: book, displayQuestion: displayQuestion)
        }
    }

    /// Get AI response for book context - creates **Question**\n\nAnswer format message
    private func getBookAIResponse(for question: String, book: Book, displayQuestion: String) async {
        // Create placeholder AI message with question shown while loading
        let aiMessage = UnifiedChatMessage(
            content: "**\(displayQuestion)**",  // Show question while loading
            isUser: false,
            timestamp: Date(),
            bookContext: book,
            messageType: .text
        )
        let messageId = aiMessage.id

        // Add message immediately so user sees their question
        await MainActor.run {
            messages.append(aiMessage)
            withAnimation(DesignSystem.Animation.easeStandard) {
                expandedMessageIds.insert(messageId)
            }
        }

        do {
            let service = OptimizedPerplexityService.shared
            var fullResponse = ""

            for try await response in service.streamSonarResponse(
                question,
                bookContext: book,
                enrichment: nil,
                sessionHistory: buildConversationHistory(),
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: book.currentPage > 0 ? book.currentPage : nil,
                customSystemPrompt: nil
            ) {
                // Clean the response
                fullResponse = response.text
                    .replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\.([A-Z])"#, with: ". $1", options: .regularExpression)
                    .replacingOccurrences(of: "  ", with: " ")

                await MainActor.run {
                    // Update message with Question + Answer format
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index] = UnifiedChatMessage(
                            id: messageId,
                            content: "**\(displayQuestion)**\n\n\(fullResponse)",
                            isUser: false,
                            timestamp: aiMessage.timestamp,
                            bookContext: book,
                            messageType: .text
                        )
                    }
                }
            }

            // Save to session
            await MainActor.run {
                saveQuestionToCurrentSession(question, response: fullResponse)
            }

        } catch {
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index] = UnifiedChatMessage(
                        id: messageId,
                        content: "**\(displayQuestion)**\n\nSorry, I couldn't get a response. Please try again.",
                        isUser: false,
                        timestamp: aiMessage.timestamp,
                        bookContext: book,
                        messageType: .text
                    )
                }
            }
        }
    }

    /// Handle tapping a related question pill to continue the conversation
    private func handleRelatedQuestionTap(_ question: String) {
        // Use the same flow as regular text input for consistency
        keyboardText = question
        sendTextMessage()
    }

    /// Get AI response specifically for book context questions
    private func getBookSpecificAIResponse(for question: String, book: Book) async {
        // Create AI response placeholder
        let aiMessage = UnifiedChatMessage(
            content: "",
            isUser: false,
            timestamp: Date(),
            bookContext: book,
            messageType: .text
        )
        let messageId = aiMessage.id

        do {
            let service = OptimizedPerplexityService.shared
            var fullResponse = ""
            var capturedRelatedQuestions: [String] = []
            var isFirstChunk = true

            // Use streaming with book context
            for try await response in service.streamSonarResponse(
                question,
                bookContext: book,
                enrichment: nil,
                sessionHistory: buildConversationHistory(),
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: book.currentPage > 0 ? book.currentPage : nil,
                customSystemPrompt: nil  // Let it use default book-aware prompt
            ) {
                fullResponse = response.text

                // Capture related questions when available (usually at end of stream)
                if !response.relatedQuestions.isEmpty {
                    capturedRelatedQuestions = response.relatedQuestions
                }

                await MainActor.run {
                    if isFirstChunk {
                        // Clear thinking indicator when streaming starts
                        pendingQuestion = nil

                        messages.append(aiMessage)
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(messageId)
                        }
                        isFirstChunk = false
                    }

                    // Update streaming message with proper format for the thread view
                    // Format: **Question**\n\nAnswer - this allows the view to parse question vs answer
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        let formattedContent = "**\(question)**\n\n\(fullResponse)"
                        messages[index] = UnifiedChatMessage(
                            id: messageId,
                            content: formattedContent,
                            isUser: false,
                            timestamp: aiMessage.timestamp,
                            bookContext: book,
                            messageType: .text
                        )
                    }
                }
            }

            // Store related questions for this message
            await MainActor.run {
                if !capturedRelatedQuestions.isEmpty {
                    relatedQuestionsMap[messageId] = capturedRelatedQuestions
                }
                saveQuestionToCurrentSession(question, response: fullResponse)
            }

        } catch {
            await MainActor.run {
                messages.append(UnifiedChatMessage(
                    content: "Sorry, I couldn't process that. Please try again.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: book,
                    messageType: .text
                ))
            }
        }
    }

    /// Ensures an ambient session exists for the current book
    private func startAmbientSessionIfNeeded() {
        guard currentSession == nil, let book = currentBookContext else { return }

        let newSession = AmbientSession()
        newSession.startTime = Date()
        newSession.bookModel = BookModel(from: book)
        modelContext.insert(newSession)
        currentSession = newSession

        do {
            try modelContext.save()
            #if DEBUG
            print("📚 Created ambient session for book: \(book.title)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to create session: \(error)")
            #endif
        }
    }

    /// Saves a question and response to the current session
    private func saveQuestionToCurrentSession(_ question: String, response: String) {
        guard let session = currentSession else {
            #if DEBUG
            print("⚠️ No current session to save question to")
            #endif
            return
        }

        // Get BookModel if we have book context
        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { $0.id == book.id }
            )
            bookModel = try? modelContext.fetch(descriptor).first
        }

        let capturedQuestion = CapturedQuestion(
            content: question,
            book: bookModel,
            pageNumber: currentBookContext?.currentPage,
            timestamp: Date(),
            source: .ambient
        )
        capturedQuestion.answer = response
        capturedQuestion.isAnswered = true
        capturedQuestion.ambientSession = session

        if session.capturedQuestions == nil {
            session.capturedQuestions = []
        }
        session.capturedQuestions?.append(capturedQuestion)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Saved question to session: \(question.prefix(50))...")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save question: \(error)")
            #endif
        }
    }

    /// Triggers the reading taste analysis flow
    private func triggerReadingTasteAnalysis() {
        // Build analysis prompt with library context
        let analysisPrompt = buildReadingTasteAnalysisPrompt()

        // Add user message
        let userMessage = UnifiedChatMessage(
            content: "Analyze my reading taste",
            isUser: true,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        messages.append(userMessage)

        // Get AI response
        isGenericModeThinking = true
        Task {
            await getGenericAIResponseWithCustomPrompt(
                userQuery: analysisPrompt,
                systemPrompt: buildReadingAnalysisSystemPrompt()
            )
        }
    }

    /// Build the prompt for reading taste analysis
    private func buildReadingTasteAnalysisPrompt() -> String {
        let libraryContext = buildLibraryContext()
        return """
        Based on my reading history, analyze my reading taste and patterns.

        \(libraryContext)

        Tell me:
        1. What themes and genres I gravitate toward
        2. My reading comfort zone vs. blind spots
        3. Authors or styles I might enjoy but haven't tried
        4. One surprising insight about my reading patterns
        """
    }

    /// System prompt specifically for reading analysis
    private func buildReadingAnalysisSystemPrompt() -> String {
        return """
        You are a literary analyst in the Epilogue reading app. Analyze the user's reading taste based on their library data.

        FORMAT:
        - Start with a brief, insightful summary of their reading identity (2-3 sentences)
        - Use clear sections with bold headers: **Themes You Love**, **Your Comfort Zone**, **Blind Spots**, **Try Next**
        - Keep each section to 2-3 bullet points max
        - End with ONE genuinely surprising or insightful observation

        RULES:
        - Be specific and reference actual books from their library
        - No generic advice - everything should feel personalized
        - No emojis
        - Be direct, insightful, occasionally witty
        - If they have few books, acknowledge this and focus on what patterns exist
        """
    }

    /// Handle completion of the recommendation question flow
    private func handleRecommendationFlowComplete(_ context: RecommendationContext) {
        // Hide the question flow
        withAnimation(DesignSystem.Animation.springStandard) {
            showRecommendationFlow = false
        }

        // Store context and send enhanced request
        recommendationContext = context

        // Build the enhanced prompt
        let enhancedPrompt = context.buildPromptContext()

        // Add user message
        let userMessage = UnifiedChatMessage(
            content: enhancedPrompt,
            isUser: true,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        messages.append(userMessage)

        // Get AI response with the context
        isGenericModeThinking = true
        Task {
            await getGenericAIResponse(for: enhancedPrompt)
        }
    }

    /// Handle completion of the reading plan question flow (habit or challenge)
    private func handleReadingPlanFlowComplete(_ context: ReadingPlanContext) {
        // Store context for later parsing
        readingPlanContext = context

        // Hide the question flow
        withAnimation(DesignSystem.Animation.springStandard) {
            showReadingPlanFlow = nil
        }

        // Create the plan directly from context (no AI chat needed)
        createReadingPlanFromContext(context)
    }

    /// Create a reading plan directly from the question flow context
    private func createReadingPlanFromContext(_ context: ReadingPlanContext) {
        let days = context.durationDays
        let planBook = context.selectedBook ?? currentBookContext

        // Use book title if selected, otherwise generic title
        let title: String
        let goal: String

        switch context.flowType {
        case .habit:
            title = planBook?.title ?? "\(days)-Day Reading Kickstart"
            goal = "Build a sustainable reading habit that fits your schedule"
        case .challenge:
            title = planBook?.title ?? "Reading Challenge"
            goal = context.challengeOrBlocker ?? "Complete your reading goal"
        }

        #if DEBUG
        print("📋 Creating reading plan: '\(title)' (type: \(context.flowType))")
        #endif

        let plan = ReadingHabitPlan(
            type: context.flowType == .habit ? .habit : .challenge,
            title: title,
            goal: goal
        )
        plan.preferredTime = context.timePreference
        plan.commitmentLevel = context.commitmentLevel
        plan.planDuration = context.planDuration
        if let book = planBook {
            plan.bookId = book.id
            plan.bookTitle = book.title
            plan.bookAuthor = book.author
            plan.bookCoverURL = book.coverImageURL
        }

        // Set notification preferences from onboarding
        plan.notificationsEnabled = context.notificationsEnabled
        if context.notificationsEnabled {
            plan.notificationTime = context.notificationTime
        }

        // Initialize days for both habit and challenge plans
        if context.flowType == .habit {
            plan.initializeDays(count: days)
        } else {
            plan.challengeType = context.planDuration
            plan.ambitionLevel = context.commitmentLevel
            plan.timeframe = context.timePreference
            plan.initializeDays(count: days) // Challenges also need days initialized
        }

        #if DEBUG
        print("📋 Plan configured - isActive: \(plan.isActive), days: \(plan.days?.count ?? 0)")
        #endif

        // Insert and save
        modelContext.insert(plan)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Reading plan saved successfully: \(plan.title) (id: \(plan.id))")
            #endif

            // Store reference and show the timeline directly
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = plan
                showPlanDetail = true  // Go directly to timeline view
            }

            // Provide haptic feedback
            SensoryFeedback.success()

            // Show local toast notification (visible in fullScreenCover)
            let toastMessage = context.flowType == .habit
                ? "Reading habit created! Find it in Reading Plans."
                : "Challenge created! Find it in Reading Plans."
            localToastMessage = toastMessage
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showLocalToast = true
            }

            // Ask user about notification preferences
            promptForNotifications(plan: plan)

        } catch {
            #if DEBUG
            print("❌ Failed to save reading plan: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            #endif

            // Show error toast (local for fullScreenCover visibility)
            localToastMessage = "Failed to create plan. Please try again."
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showLocalToast = true
            }
        }
    }

    /// Get AI response for reading plan and create structured plan from it
    private func getReadingPlanAIResponse(userQuery: String, context: ReadingPlanContext) async {
        // Create AI response message placeholder
        let aiMessage = UnifiedChatMessage(
            content: "",
            isUser: false,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        let messageId = aiMessage.id

        do {
            let service = OptimizedPerplexityService.shared
            let systemPrompt = buildReadingPlanSystemPrompt(for: context.flowType)

            var fullResponse = ""
            var isFirstChunk = true

            // Stream the response
            for try await response in service.streamSonarResponse(
                userQuery,
                bookContext: nil,
                enrichment: nil,
                sessionHistory: nil,
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: nil,
                customSystemPrompt: systemPrompt
            ) {
                fullResponse = response.text

                await MainActor.run {
                    if isFirstChunk {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isGenericModeThinking = false
                        }
                        messages.append(aiMessage)
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(messageId)
                        }
                        isFirstChunk = false
                    }

                    // Update streaming message
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index] = UnifiedChatMessage(
                            id: messageId,
                            content: fullResponse,
                            isUser: false,
                            timestamp: aiMessage.timestamp,
                            bookContext: nil,
                            messageType: .text
                        )
                    }
                }
            }

            // After streaming completes, parse and create the plan
            await MainActor.run {
                createReadingPlanFromResponse(fullResponse, context: context)
            }

        } catch {
            #if DEBUG
            print("❌ Reading plan AI response error: \(error)")
            #endif
            await MainActor.run {
                isGenericModeThinking = false
            }
        }
    }

    /// Parse AI response and create a ReadingHabitPlan
    private func createReadingPlanFromResponse(_ response: String, context: ReadingPlanContext) {
        let plan: ReadingHabitPlan?

        switch context.flowType {
        case .habit:
            plan = ReadingPlanParser.parseHabitPlan(from: response, context: context)
        case .challenge:
            plan = ReadingPlanParser.parseChallengePlan(from: response, context: context)
        }

        guard let plan = plan else {
            #if DEBUG
            print("⚠️ Could not parse reading plan from response")
            #endif
            return
        }

        // Save to SwiftData
        modelContext.insert(plan)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Reading plan saved: \(plan.title)")
            #endif

            // Store reference and show the card
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = plan
            }

            // Provide haptic feedback
            SensoryFeedback.success()

            // Ask user about notification preferences
            promptForNotifications(plan: plan)

        } catch {
            #if DEBUG
            print("❌ Failed to save reading plan: \(error)")
            #endif
        }
    }

    /// Update active reading plan progress from a completed ambient session
    private func updateReadingPlanFromSession(_ session: AmbientSession) {
        // Find an active reading plan
        guard let activePlan = activeReadingPlans.first else {
            #if DEBUG
            print("📚 No active reading plan to update")
            #endif
            return
        }

        // Need a start time to calculate duration
        guard let startTime = session.startTime else {
            #if DEBUG
            print("📚 Session has no start time, cannot record")
            #endif
            return
        }

        // Calculate session duration in minutes
        let sessionDuration: TimeInterval
        if let endTime = session.endTime {
            sessionDuration = endTime.timeIntervalSince(startTime)
        } else {
            sessionDuration = Date().timeIntervalSince(startTime)
        }

        let sessionMinutes = Int(sessionDuration / 60)

        // Only record if session was at least 1 minute
        guard sessionMinutes >= 1 else {
            #if DEBUG
            print("📚 Session too short to count: \(sessionMinutes) min")
            #endif
            return
        }

        #if DEBUG
        print("📚 Recording \(sessionMinutes) minutes to reading plan: \(activePlan.title)")
        #endif

        // Record the reading session to the plan
        activePlan.recordReading(minutes: sessionMinutes, fromAmbientSession: true)

        // Save the updated plan
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Reading plan progress updated - Day \(activePlan.currentDayNumber), \(activePlan.todayDay?.minutesRead ?? 0) mins today")
            #endif

            // Update the local reference if this is the same plan
            if createdReadingPlan?.id == activePlan.id {
                createdReadingPlan = activePlan
            }
        } catch {
            #if DEBUG
            print("❌ Failed to save reading plan progress: \(error)")
            #endif
        }
    }

    /// Prompt user to enable notifications for their reading plan
    private func promptForNotifications(plan: ReadingHabitPlan) {
        // Only prompt if user chose to enable notifications during onboarding
        guard plan.notificationsEnabled else {
            #if DEBUG
            print("🔔 Skipping notification prompt - user selected 'No reminders'")
            #endif
            return
        }

        Task {
            // Check current permission status
            let status = await ReadingPlanNotificationService.shared.checkPermissionStatus()

            switch status {
            case .notDetermined:
                // Request permission and schedule if granted
                let granted = await ReadingPlanNotificationService.shared.requestPermission()
                if granted {
                    try? modelContext.save()
                    await ReadingPlanNotificationService.shared.scheduleReminders(for: plan)

                    // Add a chat message about notifications
                    await MainActor.run {
                        addNotificationConfirmationMessage(for: plan)
                    }
                } else {
                    // User denied - update plan
                    plan.notificationsEnabled = false
                    try? modelContext.save()
                }

            case .authorized:
                // Already authorized, just schedule
                try? modelContext.save()
                await ReadingPlanNotificationService.shared.scheduleReminders(for: plan)

                await MainActor.run {
                    addNotificationConfirmationMessage(for: plan)
                }

            case .denied, .provisional, .ephemeral:
                // Can't send notifications - update plan
                plan.notificationsEnabled = false
                try? modelContext.save()
                #if DEBUG
                print("🔔 Notifications not available (status: \(status.rawValue))")
                #endif

            @unknown default:
                break
            }
        }
    }

    /// Add a chat message confirming notification setup
    private func addNotificationConfirmationMessage(for plan: ReadingHabitPlan) {
        let timeDescription: String
        if let preferredTime = plan.preferredTime {
            timeDescription = "around \(preferredTime.lowercased())"
        } else {
            timeDescription = "each day"
        }

        let message = UnifiedChatMessage(
            content: "I'll send you a gentle reminder \(timeDescription) to help you stay on track. You can adjust or turn off notifications anytime in Settings.",
            isUser: false,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        messages.append(message)
    }

    /// Build specialized system prompt for reading habit/challenge plans
    private func buildReadingPlanSystemPrompt(for flowType: ReadingPlanQuestionFlow.FlowType) -> String {
        let libraryContext = buildLibraryContext()

        switch flowType {
        case .habit:
            return """
            You are a reading coach in the Epilogue app. Create a personalized, actionable reading habit plan.

            \(libraryContext.isEmpty ? "" : "USER'S LIBRARY:\n\(libraryContext)\n")

            FORMAT YOUR RESPONSE EXACTLY LIKE THIS:

            **Your 7-Day Reading Kickstart**

            **The Goal**: [One clear, specific goal based on their answers]

            **Your Daily Ritual**:
            - **When**: [Specific time based on their preference]
            - **Where**: [Suggest a cozy spot]
            - **How long**: [Based on their commitment level]
            - **The trigger**: [A habit stack suggestion - "After I [existing habit], I will read"]

            **Week 1 Roadmap**:
            - Day 1-2: Start with just 5 pages, no pressure
            - Day 3-4: Increase to [their target]
            - Day 5-7: Establish the full routine

            **Your First Book**: [Suggest a specific book from their TBR or a new one that's easy to start]

            **One Pro Tip**: [Specific advice addressing their blocker]

            RULES:
            - Be specific, not generic. Reference their actual time preference and blockers.
            - Make it feel achievable, not overwhelming
            - If they mentioned being busy, emphasize small wins
            - If they struggle with focus, suggest audiobooks or short chapters
            - No emojis
            - End with an encouraging but not cheesy closing line
            """

        case .challenge:
            return """
            You are a reading challenge creator in the Epilogue app. Design an exciting, personalized reading challenge.

            \(libraryContext.isEmpty ? "" : "USER'S LIBRARY:\n\(libraryContext)\n")

            FORMAT YOUR RESPONSE EXACTLY LIKE THIS:

            **Your [Timeframe] Reading Challenge**

            **The Challenge**: [Clear challenge statement based on their goals]

            **Your Target**: [Specific number of books or pages based on ambition level]

            **The Rules**:
            1. [Rule based on their challenge type - e.g., "Each book must be from a different genre"]
            2. [Supporting rule]
            3. [Flexibility rule - one "wildcard" or skip allowed]

            **Milestone Checkpoints**:
            - [First milestone]: [Reward/celebration suggestion]
            - [Mid-point]: [Check-in activity]
            - [Final stretch]: [Motivation boost]

            **Starter Books**:
            1. **[Book Title]** by [Author] - [Why it fits the challenge]
            2. **[Book Title]** by [Author] - [Why it fits]
            3. **[Book Title]** by [Author] - [Why it fits]

            **Accountability Tip**: [One specific suggestion for staying on track]

            RULES:
            - Match intensity to their ambition level (Gentle = 3-5 books, Ambitious = 10+, All in = stretch goal)
            - If they want to explore genres, suggest specific genres to try
            - If they want to clear TBR, reference books from their want-to-read list
            - Make milestones feel rewarding, not arbitrary
            - No emojis
            - End with a rallying cry that matches their energy level
            """
        }
    }

    // MARK: - Clean Bottom Input Area
    @ViewBuilder
    private var bottomInputArea: some View {
        ZStack {
            // Removed invisible tap area that was blocking scrolling
            // Dismissal will be handled by scrollDismissesKeyboard instead
            
            VStack(spacing: 8) { // ← Tightened spacing between elements
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
                    // Only add spacer when in voice mode (centered orb)
                    if inputMode != .textInput && isVoiceModeEnabled {
                        Spacer()
                            .allowsHitTesting(false)
                    }
                    
                    // Single morphing container that expands/contracts
                    ZStack {
                        // Unified morphing background - always present, just changes shape
                        RoundedRectangle(
                            cornerRadius: inputMode == .textInput || !isVoiceModeEnabled ? 20 : 32,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.05)) // Slightly visible for glass to render properly
                        .frame(
                            width: inputMode == .textInput || !isVoiceModeEnabled ? geometry.size.width - 60 : 64,
                            height: inputMode == .textInput || !isVoiceModeEnabled ? textFieldHeight : 64
                        )
                        .blur(radius: containerBlur) // Ambient container blur
                        .glassEffect(.regular, in: .rect(cornerRadius: inputMode == .textInput || !isVoiceModeEnabled ? 20 : 32))
                        .allowsHitTesting(false)  // Glass background shouldn't block touches
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: inputMode)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: textFieldHeight)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isVoiceModeEnabled)
                        
                        // Content that transitions inside the morphing container
                        ZStack {
                            // Voice mode content (stop/waveform icon)
                                Button {
                                    if inputMode == .listening && isRecording {
                                        handleMicrophoneTap()
                                    } else if inputMode == .paused {
                                        // When paused, restart recording
                                        inputMode = .listening
                                        handleMicrophoneTap()
                                    } else {
                                        handleMicrophoneTap()
                                    }
                                } label: {
                                    if !isRecording && inputMode != .textInput {
                                        // Use ambient orb when not recording and not in text mode
                                        MetalShaderView(isPressed: .constant(false), size: CGSize(width: 64, height: 64))
                                            .frame(width: 64, height: 64)
                                            .clipShape(Circle())
                                    } else {
                                        // Use system icons for recording and keyboard mode
                                        Image(systemName: inputMode == .paused ? "keyboard" : (isRecording ? "stop.fill" : "waveform"))
                                            .font(.system(size: 28, weight: .medium, design: .rounded))
                                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                                            .frame(width: 64, height: 64)
                                            .contentTransition(.symbolEffect(.replace))
                                    }
                                }
                                .buttonStyle(.plain)
                                .opacity(inputMode == .textInput || !isVoiceModeEnabled ? 0 : 1)
                                .scaleEffect(inputMode == .textInput || !isVoiceModeEnabled ? 0.5 : 1)
                                .allowsHitTesting(!inputMode.isTextInput && isVoiceModeEnabled)
                                .accessibilityLabel(isRecording ? "Stop recording" : "Start voice recording")
                                .accessibilityHint("Double tap to \(isRecording ? "stop" : "start") voice input for ambient reading mode")
                                .accessibilityValue(isRecording ? "Recording" : "Ready")
                            
                            // Text input mode content - always present but with opacity control
                            Group {
                                // Camera feedback indicator
                                if cameraJustUsed && !isProcessingImage {
                                    HStack(spacing: 6) {
                                        Image(systemName: keyboardText.contains("Quote") ? "quote.bubble.fill" : "checkmark.circle.fill")
                                            .foregroundColor(keyboardText.contains("Quote") ? .blue : .green)
                                            .font(.system(size: 12))
                                        Text(keyboardText.contains("Quote") ? "Quote detected - ready to save" : "Page captured - question generated")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .animation(.easeInOut(duration: 0.3), value: cameraJustUsed)
                                    .padding(.bottom, 4)
                                }
                                
                                HStack(spacing: 8) {
                                    // Camera button for Visual Intelligence capture
                                    Button {
                                        showVisualIntelligenceCapture = true
                                    } label: {
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .frame(width: 32, height: 32)
                                            .background(
                                                Circle()
                                                    .fill(Color.white.opacity(0.05))
                                            )
                                            .contentShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Capture book page")
                                    .accessibilityHint("Double tap to open camera and capture a quote or page from your book")
                                    
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
                                }
                                .padding(.leading, 12)  // Proper padding for camera icon
                                .padding(.trailing, 12)
                                .padding(.vertical, 8)  // Dynamic vertical padding
                            }
                            .opacity(inputMode == .textInput || !isVoiceModeEnabled ? 1 : 0)
                            .blur(radius: inputMode == .textInput || !isVoiceModeEnabled ? 0 : 8)
                            .scaleEffect(inputMode == .textInput || !isVoiceModeEnabled ? 1 : 0.95)
                            .allowsHitTesting(inputMode == .textInput || !isVoiceModeEnabled)
                            // Single smooth animation - no delay, synchronized with container
                            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: inputMode)
                            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isVoiceModeEnabled)
                        }
                    }
                    .onAppear {
                        // Start subtle idle breathing animation
                        startContainerBreathing()
                    }
                    
                    // Right side button - morphs between ambient orb and submit arrow
                    if inputMode == .textInput || !isVoiceModeEnabled {
                        ZStack {
                            // Ambient orb when no text
                            if keyboardText.isEmpty {
                                // FIXED: Don't wrap AmbientOrbButton in another Button (nested button problem)
                                // AmbientOrbButton is already a Button internally - just pass action directly
                                AmbientOrbButton(size: 48) {
                                    // If voice mode is disabled, enable it first
                                    if !isVoiceModeEnabled {
                                        isVoiceModeEnabled = true
                                    }
                                    // Return to voice mode - ALL state changes in animation block for proper synchronization
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86, blendDuration: 0)) {
                                        isKeyboardFocused = false
                                        keyboardText = ""
                                        textFieldHeight = 44  // Reset to compact height
                                        inputMode = .listening
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        startRecording()
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityLabel("Start voice input")
                                .accessibilityHint("Double tap to switch to voice mode and start recording")
                            }
                            
                            // Submit arrow when text exists - with liquid glass
                            if !keyboardText.isEmpty {
                                Button {
                                    sendTextMessage()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.15))
                                            .frame(width: 48, height: 48)
                                            .glassEffect(in: Circle())
                                            .overlay {
                                                Circle()
                                                    .strokeBorder(
                                                        Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.3),
                                                        lineWidth: 0.5
                                                    )
                                            }

                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityLabel("Send message")
                                .accessibilityHint("Double tap to send your question to the AI")
                            }
                        }
                        .padding(.leading, 12)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: keyboardText.isEmpty)
                    }
                    
                    // Only add spacer when in voice mode (centered orb)
                    if inputMode != .textInput && isVoiceModeEnabled {
                        Spacer()
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height)
                .allowsHitTesting(true)  // Only allow hit testing on actual interactive elements
            }
            .frame(height: 100)
            .allowsHitTesting(true)  // Ensure only actual controls are interactive
        }
        .padding(.horizontal, 16)  // iOS 26 style - closer to edges
        .padding(.bottom, inputMode == .textInput || !isVoiceModeEnabled ? 1 : 24)  // Just 1pt above keyboard in text mode
        
        // Long press for quick keyboard - only when voice mode is enabled
        .onLongPressGesture(minimumDuration: 0.5) {
            if isVoiceModeEnabled {
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
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86, blendDuration: 0), value: inputMode)
        .animation(.spring(response: 0.5, dampingFraction: 0.86, blendDuration: 0), value: textFieldHeight)
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

            // Right side - Custom liquid glass toggle
            LiquidGlassInputToggle(isVoiceMode: $isVoiceModeEnabled)
                .onChange(of: isVoiceModeEnabled) { _, newValue in
                    SensoryFeedback.impact(newValue ? .light : .medium)

                    // If turning voice mode off, switch to text input
                    if !newValue {
                        if isRecording {
                            stopRecording()
                        }
                        inputMode = .textInput
                    } else {
                        // If turning voice mode on, switch to listening
                        inputMode = .listening
                        isKeyboardFocused = false
                    }
                }
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
                    
                    #if DEBUG
                    print("✅ Response update detected for: \(item.text.prefix(30))...")
                    #endif
                    
                    // Update the saved question in SwiftData with the answer
                    if let session = currentSession {
                        if let savedQuestion = (session.capturedQuestions ?? []).first(where: { $0.content == item.text }) {
                            savedQuestion.answer = response
                            try? modelContext.save()
                            #if DEBUG
                            print("✅ Updated saved question with answer")
                            #endif
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
                        
                        #if DEBUG
                        print("✅ Updated thinking message with response and expanded it")
                        #endif
                        #if DEBUG
                        print("   Message content: \(updatedMessage.content.prefix(100))...")
                        #endif
                        #if DEBUG
                        print("   Total messages: \(messages.count)")
                        #endif
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
                        
                        #if DEBUG
                        print("✅ Added new message with response and expanded it")
                        #endif
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
                #if DEBUG
                print("⚠️ Skipping duplicate: \(item.text.prefix(30))...")
                #endif
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
                                       (currentBookContext.map { context in
                                        context.title.lowercased().split(separator: " ").contains {
                                            questionLower.contains($0) && $0.count > 3
                                        }
                                       } ?? false)
                
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
                    
                    #if DEBUG
                    print("🎯 SAVE ANIMATION: Setting showSaveAnimation = true for Quote")
                    #endif
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSaveAnimation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            #if DEBUG
                            print("🎯 SAVE ANIMATION: Hiding save animation for Quote")
                            #endif
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
                    
                    if !responseExists, let response = item.response {
                        // Format the response with the question for context
                        let formattedResponse = "**\(item.text)**\n\n\(response)"
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
                        
                        // Expand the new message without collapsing others
                        // The thinking message should already be expanded
                        if !expandedMessageIds.contains(aiMessage.id) {
                            withAnimation(DesignSystem.Animation.easeStandard) {
                                expandedMessageIds.insert(aiMessage.id)
                            }
                        }
                        #if DEBUG
                        print("✅ Added AI response for question: \(item.text.prefix(30))...")
                        #endif
                    } else {
                        #if DEBUG
                        print("⚠️ Response already exists for question: \(item.text.prefix(30))...")
                        #endif
                    }
                } else {
                    // Question detected but no response yet
                    // The thinking message is already created in the onReceive listener
                    // The processor path (processQuestionDirectly) handles the AI response via
                    // OptimizedPerplexityService streaming. DO NOT trigger a second AI call here
                    // as it causes a race condition with duplicate/inconsistent message updates.
                    pendingQuestion = item.text
                    #if DEBUG
                    print("💭 Question awaiting processor response: \(item.text.prefix(30))...")
                    #endif
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
        let lowercased = quoteText.lowercased()
        
        // Extended list of quote introduction patterns
        let prefixesToRemove = [
            "i love this quote.",
            "i love this quote",
            "i like this quote.",
            "i like this quote",
            "this is my favorite quote",
            "my favorite quote",
            "favorite quote",
            "great quote",
            "this quote",
            "here's a quote",
            "here is a quote",
            "quote...",
            "quote:",
            "quote "
        ]
        
        // Remove prefixes
        for prefix in prefixesToRemove {
            if lowercased.hasPrefix(prefix) {
                quoteText = String(quoteText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove common separators after the prefix
                if quoteText.starts(with: ":") || quoteText.starts(with: "-") || quoteText.starts(with: ".") {
                    quoteText = String(quoteText.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                break
            }
        }
        
        // Special handling for famous quotes that might be referenced
        // For example: "All we have to do is decide what to do with the time given to us"
        // This is Gandalf from LOTR - detect and add attribution if known
        let gandalfQuotes = [
            "all we have to do is decide what to do with the time given to us",
            "all we have to decide is what to do with the time that is given us"
        ]
        
        if gandalfQuotes.contains(lowercased.trimmingCharacters(in: .whitespacesAndNewlines)) {
            // This is a Gandalf quote from LOTR
            // Note: We'll handle attribution later in the save process
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
            #if DEBUG
            print("⚠️ Quote already exists: \(quoteText.prefix(30))...")
            #endif
            
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
                    #if DEBUG
                    print("✅ Linked existing quote to current session")
                    #endif
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
                let newBookModel = BookModel(from: book)
                bookModel = newBookModel
                modelContext.insert(newBookModel)
            }
        }

        // Parse attribution from quote text itself
        // Common patterns: "quote text by Author", "quote text - Author", "quote text, Author", "quote text from Book"
        var quoteAuthor: String? = currentBookContext?.author
        var parsedBookTitle: String? = nil
        var attributionWasParsed = false

        let attributionPatterns = [
            // "by Author" or "by Author, Book"
            try? NSRegularExpression(pattern: "\\s+by\\s+([^,]+)(?:,\\s*(.+))?\\s*$", options: .caseInsensitive),
            // "- Author" or "- Author, Book"
            try? NSRegularExpression(pattern: "\\s*[-—–]\\s*([^,]+)(?:,\\s*(.+))?\\s*$", options: []),
            // ", Author" at the end
            try? NSRegularExpression(pattern: ",\\s+([^,]+)\\s*$", options: [])
        ]

        for pattern in attributionPatterns.compactMap({ $0 }) {
            let range = NSRange(quoteText.startIndex..., in: quoteText)
            if let match = pattern.firstMatch(in: quoteText, range: range) {
                // Extract author
                if let authorRange = Range(match.range(at: 1), in: quoteText) {
                    let extractedAuthor = String(quoteText[authorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extractedAuthor.isEmpty && extractedAuthor.count > 2 {
                        quoteAuthor = extractedAuthor
                        attributionWasParsed = true
                    }
                }

                // Extract book title if present (capture group 2)
                if match.numberOfRanges > 2, let bookRange = Range(match.range(at: 2), in: quoteText) {
                    let extractedBook = String(quoteText[bookRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extractedBook.isEmpty && extractedBook.count > 2 {
                        parsedBookTitle = extractedBook
                    }
                }

                // Remove attribution from quote text
                if let matchRange = Range(match.range, in: quoteText) {
                    quoteText = String(quoteText[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                break  // Only use first matching pattern
            }
        }

        // If we parsed a book title, try to find or create that book
        if let bookTitle = parsedBookTitle {
            let bookFetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.title == bookTitle
                }
            )

            if let existingBook = try? modelContext.fetch(bookFetchRequest).first {
                bookModel = existingBook
            } else if bookModel == nil {
                // Create a new book with the parsed info
                let newBookModel = BookModel(
                    id: UUID().uuidString,
                    title: bookTitle,
                    author: quoteAuthor ?? "Unknown"
                )
                modelContext.insert(newBookModel)
                bookModel = newBookModel
            }
        }

        let cleanedQuote = quoteText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for Gandalf quotes from LOTR
        if gandalfQuotes.contains(cleanedQuote) && currentBookContext?.title.lowercased().contains("lord of the rings") == true {
            quoteAuthor = "Gandalf"
        }
        
        let capturedQuote = CapturedQuote(
            text: quoteText,
            book: bookModel,
            author: quoteAuthor,
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
            #if DEBUG
            print("✅ Quote saved to SwiftData with session: \(quoteText.prefix(50))...")
            #endif
            SensoryFeedback.success()
            return capturedQuote
        } catch {
            #if DEBUG
            print("❌ Failed to save quote: \(error)")
            #endif
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
            #if DEBUG
            print("⚠️ Note already exists, skipping save: \(noteText.prefix(30))...")
            #endif
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
                let newBookModel = BookModel(from: book)
                bookModel = newBookModel
                modelContext.insert(newBookModel)
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
            #if DEBUG
            print("✅ Note saved to SwiftData with session: \(content.text.prefix(50))...")
            #endif
            SensoryFeedback.success()
            return capturedNote
        } catch {
            #if DEBUG
            print("❌ Failed to save note: \(error)")
            #endif
            return nil
        }
    }
    
    private func saveQuestionToSwiftData(_ content: AmbientProcessedContent) {
        // Use the raw text as-is for consistency
        let questionText = content.text

        // Ensure a session exists (create if needed)
        if currentSession == nil {
            startAmbientSessionIfNeeded()
        }

        // CRITICAL: Check for duplicate questions in current session
        guard let session = currentSession else {
            #if DEBUG
            print("⚠️ No session available for saving question")
            #endif
            return
        }
        
        // Check if question already exists in this session
        let isDuplicate = (session.capturedQuestions ?? []).contains { question in
            question.content == questionText
        }
        
        if isDuplicate {
            #if DEBUG
            print("⚠️ DUPLICATE QUESTION DETECTED - NOT SAVING: \(questionText)")
            #endif
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
                    #if DEBUG
                    print("📎 Linked existing question to session: \(questionText.prefix(30))...")
                    #endif
                }
            }
            
            // Update answer if we have a response
            if let response = content.response, existingQuestion.answer == nil {
                existingQuestion.answer = response
                existingQuestion.isAnswered = true
            }
            
            do {
                try modelContext.save()
                #if DEBUG
                print("✅ Updated existing question: \(questionText.prefix(30))...")
                #endif
                #if DEBUG
                print("   Session now has \((currentSession?.capturedQuestions ?? []).count) questions")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to update question: \(error)")
                #endif
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
                let newBookModel = BookModel(from: book)
                bookModel = newBookModel
                modelContext.insert(newBookModel)
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
            #if DEBUG
            print("✅ Question saved to SwiftData with session: \(questionText.prefix(50))...")
            #endif
            #if DEBUG
            print("   Session now has \((currentSession?.capturedQuestions ?? []).count) questions")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save question: \(error)")
            #endif
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
    
    private func fadeOutOnboarding() {
        onboardingTimer?.invalidate()
        onboardingTimer = nil

        withAnimation(.easeOut(duration: 0.8)) {
            onboardingOpacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showOnboarding = false
        }
    }

    private func startAmbientExperience() {
        // If voice mode is disabled, skip audio permissions and setup
        if !isVoiceModeEnabled {
            // Create session without audio setup
            let startTime = Date()
            sessionStartTime = startTime
            let session = AmbientSession(book: currentBookContext)
            session.startTime = startTime
            currentSession = session
            modelContext.insert(session)
            
            do {
                try modelContext.save()
                #if DEBUG
                print("✅ Initial session created (voice mode disabled)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to save initial session: \(error)")
                #endif
            }
            
            // Start book cover fade timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                withAnimation(.easeOut(duration: 2.0)) {
                    showBookCover = false
                }
            }
            
            return // Don't initialize any audio components
        }
        
        // Check permissions FIRST before creating session
        Task {
            // Check microphone permission
            let micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            let finalMicAuthorized = micAuthorized ? true : await AVAudioApplication.requestRecordPermission()
            
            // Check speech recognition permission  
            let speechStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            
            guard finalMicAuthorized && speechStatus == .authorized else {
                // Just log and return - no UI
                #if DEBUG
                print("❌ Permissions denied - Mic: \(finalMicAuthorized), Speech: \(speechStatus == .authorized)")
                #endif
                return
            }
            
            // Whisper will be loaded when needed by VoiceRecognitionManager
            // The voice manager handles model loading internally

            // CRITICAL: Load enrichment BEFORE creating session
            // This must happen FIRST so contextualStrings are ready when speech starts
            await voiceManager.loadEnrichmentForCurrentBook(modelContext: modelContext)

            // NOW we can create the session
            await MainActor.run {
                // Record when the session actually starts
                let startTime = Date()
                sessionStartTime = startTime

                // Create the session at the START
                let session = AmbientSession(book: currentBookContext)
                session.startTime = startTime // Use the actual start time
                currentSession = session
                modelContext.insert(session)

                // Save the session immediately so relationships can be established
                do {
                    try modelContext.save()
                    #if DEBUG
                    print("✅ Initial session created and saved")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Failed to save initial session: \(error)")
                    #endif
                }

                // Start book cover fade timer - fade after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    withAnimation(.easeOut(duration: 2.0)) {
                        showBookCover = false
                    }
                }

                processor.startSession()

                // Fade in onboarding text
                if showOnboarding {
                    onboardingOpacity = 1.0

                    // Start timer to fade out after 4 seconds
                    onboardingTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                        fadeOutOnboarding()
                    }
                }
                
                // Session is now active
                // isSessionActive = true // This property doesn't exist anymore
                
                // Start container breathing effect
                startContainerBreathing()
                
                // Auto-start recording after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    handleMicrophoneTap()
                }
            }
        }
    }
    
    private func handleMicrophoneTap() {
        // Don't do anything if voice mode is disabled
        guard isVoiceModeEnabled else { return }
        
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // Quick permission check before starting
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micStatus == .authorized else {
            #if DEBUG
            print("❌ Microphone permission not authorized")
            #endif
            return
        }
        
        // VoiceRecognitionManager handles Whisper loading internally
        
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

                // Update the message content (preserve the original ID)
                messages[index] = UnifiedChatMessage(
                    id: editingId,  // Preserve the original message ID
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

        // Check conversation limit BEFORE processing new messages
        // CRITICAL: Gandalf mode bypasses this check (already handled in canStartConversation)
        if !storeKit.canStartConversation() {
            SensoryFeedback.warning()
            showPaywall = true
            return
        }

        // GENERIC MODE: Route ALL input to AI conversation (no note/quote classification)
        // Check BOTH ambientMode AND currentBookContext - if there's a book context, use book mode
        // This handles edge cases like resuming from an existing session with a book
        let isGenericMode = EpilogueAmbientCoordinator.shared.ambientMode.isGeneric && currentBookContext == nil
        if isGenericMode {
            sendToGenericAIConversation(messageText)
            return
        }

        // Check for page mentions in typed text too
        detectPageMention(in: messageText)

        // Smart content type detection
        let contentType = determineContentType(messageText)
        
        #if DEBUG
        print("📝 Processing typed message: '\(messageText)' as \(contentType)")
        #endif

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

            // Save question to SwiftData immediately
            saveQuestionToSwiftData(content)

            // Set pendingQuestion to show scrolling text
            pendingQuestion = messageText

            // Use getBookSpecificAIResponse for book mode - it properly handles:
            // 1. Streaming with correct **question**\n\nanswer format
            // 2. Capturing related questions from Sonar for follow-up pills
            // 3. Clearing pendingQuestion when streaming starts
            if let book = currentBookContext {
                Task {
                    await getBookSpecificAIResponse(for: messageText, book: book)
                }
            } else {
                // Fallback to processor path if no book context (shouldn't happen in book mode)
                Task {
                    processor.detectedContent.append(content)
                    await processor.processQuestionDirectly(messageText, bookContext: currentBookContext)
                }
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
                    
                    #if DEBUG
                    print("✅ Quote saved to SwiftData: \(capturedQuote.text)")
                    #endif
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
                    
                    #if DEBUG
                    print("✅ Note saved to SwiftData: \(capturedNote.content)")
                    #endif
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

    // MARK: - Generic Mode AI Conversation
    /// Routes ALL input to AI in Generic mode - no note/quote classification
    private func sendToGenericAIConversation(_ text: String) {
        // 1. Add user message to display
        let userMessage = UnifiedChatMessage(
            content: text,
            isUser: true,
            timestamp: Date(),
            bookContext: nil,  // No book context in Generic mode
            messageType: .text
        )
        messages.append(userMessage)

        // 2. Show typing indicator (V0 pattern)
        withAnimation(.easeOut(duration: 0.2)) {
            isGenericModeThinking = true
        }

        #if DEBUG
        print("🤖 Generic Mode: Routing to AI conversation: '\(text)'")
        #endif

        // 3. Check for specialized flow intents (recommendations, reading plans, insights)
        let conversationFlows = AmbientConversationFlows.shared
        if let flowIntent = conversationFlows.detectFlowIntent(from: text) {
            #if DEBUG
            print("🎯 Detected flow intent: \(flowIntent)")
            #endif
            Task {
                await handleSpecializedFlow(flowIntent, userText: text)
            }
            return
        }

        // 4. Standard AI conversation for general questions
        Task {
            await getGenericAIResponse(for: text)
        }
    }

    /// Handles specialized conversation flows (recommendations, reading plans, insights)
    private func handleSpecializedFlow(_ flow: AmbientConversationFlows.ConversationFlow, userText: String) async {
        let conversationFlows = AmbientConversationFlows.shared
        let books = libraryViewModel.books

        switch flow {
        case .recommendation, .moodBasedRecommendation:
            // Start recommendation flow
            for await update in await conversationFlows.startRecommendationFlow(books: books) {
                await handleFlowUpdate(update)
            }

        case .readingPlan:
            // Generic plan request - show habit flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .habit
                }
            }

        case .readingHabit:
            // Show the reading habit question flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .habit
                }
            }

        case .readingChallenge:
            // Show the reading challenge question flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .challenge
                }
            }

        case .libraryInsights:
            // Generate library insights
            let insights = await conversationFlows.generateLibraryInsights(books: books)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                // Add insights as AI message
                let aiMessage = UnifiedChatMessage(
                    content: insights,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }
            }
        }
    }

    /// Handles flow updates from AmbientConversationFlows
    private func handleFlowUpdate(_ update: FlowUpdate) async {
        await MainActor.run {
            switch update {
            case .status(let statusText):
                // Update a status message or show progress
                #if DEBUG
                print("📊 Flow status: \(statusText)")
                #endif

            case .clarificationNeeded(let question):
                // Hide thinking, show clarification
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                let aiMessage = UnifiedChatMessage(
                    content: question.question,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }

            case .recommendations(let recs):
                // Hide thinking, show recommendations
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                // Convert RecommendationEngine.Recommendation to UnifiedChatMessage.BookRecommendation
                let bookRecs = recs.map { rec in
                    UnifiedChatMessage.BookRecommendation(
                        title: rec.title,
                        author: rec.author,
                        reason: rec.reasoning,
                        coverURL: rec.coverURL,
                        isbn: nil,  // RecommendationEngine doesn't provide ISBN
                        purchaseURL: nil
                    )
                }
                // Add as a recommendations message
                let aiMessage = UnifiedChatMessage(
                    content: formatRecommendationsText(recs),
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .bookRecommendations(bookRecs)
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }

            case .readingPlan(let journey):
                // Hide thinking, show reading plan
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                let journeyDescription = journey.userIntent ?? "your reading journey"
                let bookCount = journey.books?.count ?? 0
                let aiMessage = UnifiedChatMessage(
                    content: "I've created a reading plan for you! 📚\n\n**\(journeyDescription)**\n\n\(bookCount) books queued up for your journey. You can view and manage it in your Reading Journey section.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }

            case .insights(let insightsText):
                // Hide thinking, show insights
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                let aiMessage = UnifiedChatMessage(
                    content: insightsText,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }

            case .error(let errorMessage):
                // Hide thinking, show error
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                let aiMessage = UnifiedChatMessage(
                    content: "Sorry, I ran into an issue: \(errorMessage)",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
            }
        }
    }

    /// Formats recommendations into readable text
    private func formatRecommendationsText(_ recs: [RecommendationEngine.Recommendation]) -> String {
        if recs.isEmpty {
            return "I couldn't find specific recommendations right now. Try telling me more about what you're in the mood for!"
        }

        var text = "Based on your library, here are some books I think you'd love:\n\n"
        for (index, rec) in recs.prefix(5).enumerated() {
            text += "**\(index + 1). \(rec.title)** by \(rec.author)\n"
            text += "\(rec.reasoning)\n\n"
        }
        return text
    }

    /// Processes AI response for Generic mode conversations
    private func getGenericAIResponse(for text: String) async {
        // Create AI response message placeholder
        let aiMessage = UnifiedChatMessage(
            content: "",
            isUser: false,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        let messageId = aiMessage.id

        do {
            // Use the existing Perplexity service for streaming
            let service = OptimizedPerplexityService.shared

            var fullResponse = ""
            var isFirstChunk = true

            // Build the specialized Generic Mode system prompt
            let genericModePrompt = buildGenericModeSystemPrompt()

            // Build conversation history for context (last 10 messages)
            let conversationHistory = buildConversationHistory()

            // Use streamSonarResponse with custom system prompt for Generic mode
            for try await response in service.streamSonarResponse(
                text,
                bookContext: nil,  // No book context in Generic mode
                enrichment: nil,
                sessionHistory: conversationHistory,
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: nil,
                customSystemPrompt: genericModePrompt
            ) {
                fullResponse = response.text

                await MainActor.run {
                    // On first chunk, hide typing indicator and add the message
                    if isFirstChunk {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isGenericModeThinking = false
                        }
                        messages.append(aiMessage)
                        // Expand the new AI message
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(messageId)
                        }
                        isFirstChunk = false
                    }

                    // Update the streaming message content (preserve the original ID)
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index] = UnifiedChatMessage(
                            id: messageId,  // Preserve the original message ID
                            content: fullResponse,
                            isUser: false,
                            timestamp: aiMessage.timestamp,
                            bookContext: nil,
                            messageType: .text
                        )
                    }
                }
            }

        } catch {
            #if DEBUG
            print("❌ Generic AI response error: \(error)")
            #endif

            await MainActor.run {
                // Hide typing indicator on error
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }

                // Add error message
                messages.append(UnifiedChatMessage(
                    content: "Sorry, I couldn't process that. Please try again.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                ))
            }
        }
    }

    /// Processes AI response with a custom system prompt (for specialized flows like reading plans, analysis)
    private func getGenericAIResponseWithCustomPrompt(userQuery: String, systemPrompt: String) async {
        // Create AI response message placeholder
        let aiMessage = UnifiedChatMessage(
            content: "",
            isUser: false,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        let messageId = aiMessage.id

        do {
            let service = OptimizedPerplexityService.shared

            var fullResponse = ""
            var isFirstChunk = true

            // Use streamSonarResponse with the custom system prompt
            for try await response in service.streamSonarResponse(
                userQuery,
                bookContext: nil,
                enrichment: nil,
                sessionHistory: nil,
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: nil,
                customSystemPrompt: systemPrompt
            ) {
                fullResponse = response.text

                await MainActor.run {
                    if isFirstChunk {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isGenericModeThinking = false
                        }
                        messages.append(aiMessage)
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(messageId)
                        }
                        isFirstChunk = false
                    }

                    // Update streaming message (preserve ID)
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[index] = UnifiedChatMessage(
                            id: messageId,
                            content: fullResponse,
                            isUser: false,
                            timestamp: aiMessage.timestamp,
                            bookContext: nil,
                            messageType: .text
                        )
                    }
                }
            }

        } catch {
            #if DEBUG
            print("❌ Custom prompt AI response error: \(error)")
            #endif

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                messages.append(UnifiedChatMessage(
                    content: "Sorry, I couldn't process that. Please try again.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                ))
            }
        }
    }

    /// Builds the system prompt for Generic mode AI conversations
    private func buildGenericModeSystemPrompt() -> String {
        // Fetch user's library for personalized recommendations
        let libraryContext = buildLibraryContext()

        var prompt = """
        You are a book recommendation assistant in the Epilogue reading app.

        CRITICAL RULE: When asked for book recommendations, you MUST provide EXACTLY 3-5 book suggestions. Never give just 1 book. This is mandatory.
        """

        // Add personalized library context if available
        if !libraryContext.isEmpty {
            prompt += "\n\n" + libraryContext
        }

        prompt += """

        FORMAT (follow exactly):
        1. **Book Title** by Author Name - Brief 1-2 sentence description explaining why this book fits.
        2. **Book Title** by Author Name - Brief description.
        3. **Book Title** by Author Name - Brief description.
        [Continue to 4-5 if relevant]

        Then ask ONE follow-up question to refine future recommendations.

        RULES:
        - MINIMUM 3 books per recommendation request
        - Use markdown bold for titles: **Title**
        - Keep descriptions concise (1-2 sentences each)
        - End with a single follow-up question
        - No emojis
        - No phrases like "Great question!" or "Excellent choice!"
        - Be direct and helpful
        - NEVER recommend books the user has already read or owns
        - Base suggestions on their reading history and preferences
        """

        return prompt
    }

    /// Builds conversation history for AI context (last 10 messages)
    private func buildConversationHistory() -> [String] {
        // Get the last 10 messages (excluding the current one being responded to)
        let recentMessages = messages.suffix(10)

        return recentMessages.map { message in
            let role = message.isUser ? "User" : "Assistant"
            return "\(role): \(message.content)"
        }
    }

    /// Builds context from user's library for personalized recommendations
    private func buildLibraryContext() -> String {
        // Fetch books from SwiftData
        let fetchDescriptor = FetchDescriptor<BookModel>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )

        guard let books = try? modelContext.fetch(fetchDescriptor), !books.isEmpty else {
            return ""
        }

        // Categorize books by reading status
        let readBooks = books.filter { $0.readingStatus == ReadingStatus.read.rawValue }
        let currentlyReading = books.filter { $0.readingStatus == ReadingStatus.currentlyReading.rawValue }
        let wantToRead = books.filter { $0.readingStatus == ReadingStatus.wantToRead.rawValue }

        // Extract themes from read books (keyThemes is the AI-enriched themes array)
        let allThemes: [String] = readBooks.flatMap { $0.keyThemes ?? [] }
        let uniqueThemes = Array(Set(allThemes)).prefix(6)

        // Extract favorite authors (from highly rated books - userRating is Double 0-5)
        let ratedBooks = readBooks.filter { ($0.userRating ?? 0) >= 4.0 }
        let favoriteAuthors = Array(Set(ratedBooks.map { $0.author })).prefix(5)

        var context = "USER'S READING PROFILE:\n"

        // Books they've read (sample of recent ones)
        if !readBooks.isEmpty {
            let recentRead = readBooks.prefix(8).map { "\($0.title) by \($0.author)" }
            context += "Recently finished: \(recentRead.joined(separator: ", "))\n"
        }

        // Currently reading
        if !currentlyReading.isEmpty {
            let current = currentlyReading.prefix(3).map { "\($0.title) by \($0.author)" }
            context += "Currently reading: \(current.joined(separator: ", "))\n"
        }

        // Want to read (don't recommend these - they already want them)
        if !wantToRead.isEmpty {
            let tbr = wantToRead.prefix(5).map { $0.title }
            context += "Already on their TBR list (don't recommend): \(tbr.joined(separator: ", "))\n"
        }

        // Preferred themes
        if !uniqueThemes.isEmpty {
            context += "Themes they enjoy: \(uniqueThemes.joined(separator: ", "))\n"
        }

        // Favorite authors
        if !favoriteAuthors.isEmpty {
            context += "Favorite authors: \(favoriteAuthors.joined(separator: ", "))\n"
        }

        // Total library size for context
        context += "Library size: \(books.count) books (\(readBooks.count) read, \(currentlyReading.count) in progress, \(wantToRead.count) on TBR)\n"

        return context
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

        // Check conversation limit BEFORE sending
        if !storeKit.canStartConversation() {
            SensoryFeedback.warning()
            showPaywall = true
            return
        }

        // Hide onboarding on first interaction
        if showOnboarding {
            fadeOutOnboarding()
        }

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
    
    // MARK: - Visual Intelligence Live Text Selection
    // MARK: - Visual Intelligence Integration
    private func triggerVisualIntelligence() async {
        await MainActor.run {
            showImagePicker = true
        }
    }
    
    // MARK: - Quote Saving with Attribution
    private func saveQuoteWithAttribution(_ text: String, pageNumber: String?) {
        // Get current book if available
        let bookTitle = bookDetector.detectedBook?.title ?? "Unknown Book"
        let author = bookDetector.detectedBook?.author ?? ""
        
        // Create attributed quote
        var attributedText = text
        if let page = pageNumber {
            attributedText += "\n\n— \(bookTitle), p. \(page)"
        } else {
            attributedText += "\n\n— \(bookTitle)"
        }
        
        // Save as quote
        processSelectedQuote(attributedText)
    }
    
    // MARK: - Perplexity Integration
    private func askPerplexityAboutText(_ text: String) async {
        // Create a question about the text
        let question = "What does this passage mean: \"\(text)\""
        
        // Process through AI
        await getAIResponseForAmbientQuestion(question)
    }
    
    private func processSelectedQuote(_ selectedText: String) {
        // Show processing state
        isProcessingImage = true
        cameraJustUsed = true
        
        // Haptic feedback for quote capture
        SensoryFeedback.success()
        
        // Generate smart input based on selected text
        let smartInput = generateSmartQuestion(from: selectedText)
        
        // Update the input field
        withAnimation(.easeInOut(duration: 0.3)) {
            keyboardText = smartInput
        }
        
        // Reset states
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProcessingImage = false
        }
        
        // Reset camera indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                cameraJustUsed = false
            }
        }
        
        // If it's a perfect quote, save it immediately
        if detectIfQuote(selectedText) && selectedText.split(separator: " ").count <= 60 {
            saveExtractedQuote(selectedText)
        }
    }
    
    // MARK: - Visual Intelligence Photo Capture & OCR (Fallback)
    private func processImageForText(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        // Show processing state
        isProcessingImage = true
        cameraJustUsed = true
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                DispatchQueue.main.async {
                    self.isProcessingImage = false
                    // Show error feedback
                    SensoryFeedback.error()
                    self.keyboardText = "Couldn't read the text. Try better lighting."
                }
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let extractedText = recognizedStrings.joined(separator: " ")
            
            DispatchQueue.main.async {
                self.isProcessingImage = false
                self.extractedText = extractedText
                
                // Generate smart question based on extracted text
                let smartQuestion = self.generateSmartQuestion(from: extractedText)
                
                // Auto-populate the input field
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.keyboardText = smartQuestion
                }
                
                // Haptic feedback for success
                SensoryFeedback.success()
                
                // Auto-submit if it's a short quote
                if self.shouldAutoSubmit(extractedText) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.sendTextMessage()
                    }
                }
                
                // Reset camera state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        self.cameraJustUsed = false
                    }
                }
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            #if DEBUG
            print("Failed to perform OCR: \(error)")
            #endif
        }
    }
    
    // MARK: - Visual Intelligence Smart Question Generation
    
    private func generateSmartQuestion(from text: String) -> String {
        let truncated = String(text.prefix(300))
        let wordCount = text.split(separator: " ").count
        
        // QUOTE DETECTION - Primary focus
        // Check if this looks like a meaningful quote worth capturing
        let isLikelyQuote = detectIfQuote(text)
        
        if isLikelyQuote {
            // Format as a quote capture with context
            let cleanQuote = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Automatically save as quote if it's perfect length
            if wordCount >= 15 && wordCount <= 60 {
                // Auto-save the quote
                saveExtractedQuote(cleanQuote)
                return "💭 Quote saved: \"\(truncated)\"... - Add a note?"
            } else if wordCount < 100 {
                return "📖 Save this quote: \"\(truncated)\"... [Tap send to save]"
            }
        }
        
        // Detect content type and generate appropriate question
        if wordCount < 15 {
            // Very short - likely a title or heading
            return "What is the significance of '\(truncated)'?"
        } else if text.contains("\"") && wordCount < 50 {
            // Contains quotation marks - save as quote
            saveExtractedQuote(text)
            return "💭 Quote captured! Add your thoughts?"
        } else if text.contains(where: { ["thee", "thou", "thy", "hath", "doth"].contains(String($0)) }) {
            // Old English detected
            return "Translate to modern English: '\(truncated)...'"
        } else if text.contains("?") && wordCount < 100 {
            // Contains questions - philosophical passage
            return "What is the deeper meaning of: '\(truncated)...'"
        } else if text.contains(where: { ["said", "replied", "asked", "exclaimed"].contains(String($0)) }) {
            // Dialogue detected
            return "Analyze this dialogue: '\(truncated)...'"
        } else if currentBookContext?.title.contains("Hobbit") == true || currentBookContext?.title.contains("Lord") == true {
            // Context-aware for specific books
            return "How does this passage relate to the broader themes: '\(truncated)...'"
        } else {
            // Default - general explanation
            return "What does this passage mean: '\(truncated)...'"
        }
    }
    
    private func shouldAutoSubmit(_ text: String) -> Bool {
        // Don't auto-submit quotes - let user confirm or add notes
        return false
    }
    
    private func detectIfQuote(_ text: String) -> Bool {
        let wordCount = text.split(separator: " ").count
        
        // Indicators this is a quote worth capturing
        let quotableIndicators = [
            text.contains("\""),  // Has quotation marks
            text.contains("—"),    // Has em dash (often used in quotes)
            text.contains("..."),  // Has ellipsis
            wordCount >= 10 && wordCount <= 150,  // Good quote length
            text.contains(where: { ["love", "life", "death", "time", "hope", "fear", "dream", "heart", "soul", "truth", "beauty", "wisdom", "courage", "strength"].contains(String($0).lowercased()) }),  // Contains profound words
            text.first?.isUppercase == true && (text.last == "." || text.last == "!" || text.last == "?"),  // Complete sentence
        ]
        
        // If 2+ indicators, it's likely a quote
        return quotableIndicators.filter { $0 }.count >= 2
    }
    
    private func saveExtractedQuote(_ text: String) {
        // Save quote to SwiftData immediately
        let quote = CapturedQuote(
            text: text,
            book: currentBookContext.map { BookModel(from: $0) },
            author: currentBookContext?.author,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual  // User captured via camera
        )
        
        modelContext.insert(quote)
        
        do {
            try modelContext.save()
            #if DEBUG
            print("💭 Quote auto-saved from camera: \(text.prefix(50))...")
            #endif
            
            // Haptic feedback for saved quote
            SensoryFeedback.success()
            
            // Show toast
            NotificationCenter.default.post(
                name: Notification.Name("ShowToastMessage"),
                object: ["message": "Quote saved to \(currentBookContext?.title ?? "your collection")"]
            )
        } catch {
            #if DEBUG
            print("Failed to save quote: \(error)")
            #endif
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

    private func saveQuoteFromVisualIntelligence(_ text: String, pageNumber: Int?) {
        // Create the captured quote
        let capturedQuote = CapturedQuote(
            text: text,
            book: currentBookContext.map { BookModel(from: $0) },
            author: currentBookContext?.author,
            pageNumber: pageNumber,
            timestamp: Date(),
            source: .manual
        )

        // Add to current session only (not to processor.detectedContent to avoid duplication)
        if currentSession != nil {
            if currentSession?.capturedQuotes == nil {
                currentSession?.capturedQuotes = []
            }
            currentSession?.capturedQuotes?.append(capturedQuote)
        }

        // CRITICAL FIX: Insert into SwiftData so quote persists and appears in Notes view
        modelContext.insert(capturedQuote)

        // CRITICAL FIX: Save to SwiftData database
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Quote saved from Visual Intelligence to SwiftData: \(text.prefix(50))...")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save quote from Visual Intelligence: \(error)")
            #endif
            // Show error notification to user instead of false success
            NotificationCenter.default.post(
                name: Notification.Name("ShowToastMessage"),
                object: ["message": "Failed to save quote. Please try again."]
            )
            return  // Don't show success animation if save failed
        }

        // Add to messages
        let pageInfo = pageNumber.map { "from page \($0)" } ?? ""
        let message = UnifiedChatMessage(
            content: "**Quote captured \(pageInfo)**\n\n\(text)",
            isUser: false,
            timestamp: Date(),
            messageType: .quote(CapturedQuote(
                text: text,
                book: currentBookContext.map { BookModel(from: $0) },
                author: currentBookContext?.author,
                pageNumber: pageNumber,
                timestamp: Date(),
                source: .manual
            ))
        )
        messages.append(message)

        // Show save animation
        savedItemsCount += 1
        savedItemType = "Quote"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSaveAnimation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSaveAnimation = false
                savedItemType = nil
            }
        }

        // Haptic feedback
        SensoryFeedback.success()
    }

    // MARK: - Conversation Flow Handler
    /// Routes specialized queries to their proper handlers (reading plans, library insights, etc.)
    private func handleConversationFlow(_ flow: AmbientConversationFlows.ConversationFlow, originalText: String) async {
        let conversationFlows = AmbientConversationFlows.shared

        switch flow {
        case .recommendation:
            // Start recommendation flow
            updateOrAppendMessage(question: originalText, response: "Analyzing your library for recommendations...")
            let stream = await conversationFlows.startRecommendationFlow(books: libraryViewModel.books)
            for await update in stream {
                switch update {
                case .status(let status):
                    updateOrAppendMessage(question: originalText, response: status)
                case .clarificationNeeded(let question):
                    let options = question.options?.joined(separator: ", ") ?? ""
                    updateOrAppendMessage(question: originalText, response: question.question + (options.isEmpty ? "" : "\n\nOptions: " + options))
                case .recommendations(let recs):
                    let recText = recs.map { "**\($0.title)** by \($0.author)\n\($0.reasoning)" }.joined(separator: "\n\n")
                    updateOrAppendMessage(question: originalText, response: recText.isEmpty ? "No recommendations found based on your library." : recText)
                case .error(let error):
                    updateOrAppendMessage(question: originalText, response: error)
                default:
                    break
                }
            }

        case .readingPlan:
            // Start reading plan flow - returns a single FlowUpdate (clarification question)
            updateOrAppendMessage(question: originalText, response: "Creating your personalized reading plan...")
            let update = conversationFlows.startReadingPlanFlow(books: libraryViewModel.books)
            switch update {
            case .status(let status):
                updateOrAppendMessage(question: originalText, response: status)
            case .clarificationNeeded(let question):
                let options = question.options?.joined(separator: ", ") ?? ""
                updateOrAppendMessage(question: originalText, response: question.question + (options.isEmpty ? "" : "\n\nOptions: " + options))
            case .readingPlan(let plan):
                let planText = "**Your Reading Plan**\n\n" + (plan.books?.map { "• \($0.bookModel?.title ?? "Unknown")" }.joined(separator: "\n") ?? "No books in plan")
                updateOrAppendMessage(question: originalText, response: planText)
            case .error(let error):
                updateOrAppendMessage(question: originalText, response: error)
            default:
                break
            }

        case .libraryInsights:
            // Generate library insights
            updateOrAppendMessage(question: originalText, response: "Analyzing your reading patterns...")
            let insights = await conversationFlows.generateLibraryInsights(books: libraryViewModel.books)
            updateOrAppendMessage(question: originalText, response: insights)

        case .moodBasedRecommendation(let mood):
            // Handle mood-based recommendation
            updateOrAppendMessage(question: originalText, response: "Finding books for your \(mood) mood...")
            let stream = await conversationFlows.startRecommendationFlow(books: libraryViewModel.books)
            for await update in stream {
                switch update {
                case .status(let status):
                    updateOrAppendMessage(question: originalText, response: status)
                case .recommendations(let recs):
                    let recText = recs.map { "**\($0.title)** by \($0.author)\n\($0.reasoning)" }.joined(separator: "\n\n")
                    updateOrAppendMessage(question: originalText, response: recText.isEmpty ? "No recommendations found." : recText)
                default:
                    break
                }
            }

        case .readingHabit:
            // Show the reading habit question flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .habit
                }
            }

        case .readingChallenge:
            // Show the reading challenge question flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .challenge
                }
            }
        }
    }

    /// Helper to update existing thinking message or append new one
    private func updateOrAppendMessage(question: String, response: String) {
        if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && ($0.content.contains("**\(question)**") || $0.content == "Analyzing your library...") }) {
            let updatedMessage = UnifiedChatMessage(
                content: "**\(question)**\n\n\(response)",
                isUser: false,
                timestamp: messages[thinkingIndex].timestamp,
                bookContext: currentBookContext
            )
            messages[thinkingIndex] = updatedMessage
            expandedMessageIds.insert(updatedMessage.id)
        } else {
            let newMessage = UnifiedChatMessage(
                content: "**\(question)**\n\n\(response)",
                isUser: false,
                timestamp: Date(),
                bookContext: currentBookContext
            )
            messages.append(newMessage)
            expandedMessageIds.insert(newMessage.id)
        }
    }

    // MARK: - Conversational Mode Helpers

    /// Add a book recommendation to the user's library
    private func addRecommendationToLibrary(_ rec: UnifiedChatMessage.BookRecommendation) {
        Task { @MainActor in
            // Create BookModel directly with proper initialization
            let bookModel = BookModel(
                id: UUID().uuidString,
                title: rec.title,
                author: rec.author,
                publishedYear: nil,
                coverImageURL: rec.coverURL,
                isbn: rec.isbn,
                description: rec.reason,
                pageCount: nil,
                localId: UUID().uuidString
            )
            bookModel.isInLibrary = true
            bookModel.readingStatus = "want_to_read"
            bookModel.dateAdded = Date()

            modelContext.insert(bookModel)

            do {
                try modelContext.save()

                // Show success feedback
                SensoryFeedback.success()

                #if DEBUG
                print("📚 Added recommendation to library: \(rec.title) by \(rec.author)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to save recommendation: \(error)")
                #endif
                SensoryFeedback.error()
            }
        }
    }

    /// Open purchase URL in Safari
    private func openPurchaseURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)

        #if DEBUG
        print("🛒 Opening purchase URL: \(urlString)")
        #endif
    }

    /// Send a message (for follow-up questions)
    private func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = UnifiedChatMessage(
            content: text,
            isUser: true,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        messages.append(userMessage)

        // Add thinking indicator
        let thinkingMessage = UnifiedChatMessage(
            content: "**\(text)**",
            isUser: false,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        messages.append(thinkingMessage)
        expandedMessageIds.insert(thinkingMessage.id)

        // Get AI response
        await getAIResponse(for: text)
    }

    /// Parse conversational response to extract book recommendations and generate follow-ups
    private func parseConversationalResponse(_ response: String, originalQuestion: String) -> ConversationalResponseParsed {
        var recommendations: [UnifiedChatMessage.BookRecommendation] = []
        var cleanedText = response
        var followUps: [String] = []

        // Pattern to detect book recommendations: **Title** by Author
        let bookPattern = #"\*\*([^*]+)\*\*\s+by\s+([^(\n]+)"#
        if let regex = try? NSRegularExpression(pattern: bookPattern, options: []) {
            let matches = regex.matches(in: response, options: [], range: NSRange(response.startIndex..., in: response))

            for match in matches {
                if let titleRange = Range(match.range(at: 1), in: response),
                   let authorRange = Range(match.range(at: 2), in: response) {
                    let title = String(response[titleRange]).trimmingCharacters(in: .whitespaces)
                    let author = String(response[authorRange]).trimmingCharacters(in: .whitespaces)

                    // Extract reason (text following the book on the same line or next line)
                    let fullMatchRange = Range(match.range, in: response)!
                    let afterMatch = response[fullMatchRange.upperBound...]
                    let reason = extractReason(from: String(afterMatch))

                    let rec = UnifiedChatMessage.BookRecommendation(
                        title: title,
                        author: author,
                        reason: reason,
                        coverURL: nil, // Could be fetched from Google Books API
                        isbn: nil,
                        purchaseURL: nil
                    )
                    recommendations.append(rec)
                }
            }
        }

        // If we found recommendations, extract intro text
        let hasRecommendations = recommendations.count >= 2
        if hasRecommendations {
            // Get text before the first book mention
            if let firstBookIndex = response.range(of: "**")?.lowerBound {
                let introText = String(response[..<firstBookIndex])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                cleanedText = introText.isEmpty ? "Here are some books you might enjoy:" : introText
            }
        }

        // Generate follow-up questions based on context
        followUps = generateFollowUpQuestions(originalQuestion: originalQuestion, response: response)

        return ConversationalResponseParsed(
            cleanedText: cleanedText,
            recommendations: recommendations,
            followUps: followUps,
            hasRecommendations: hasRecommendations
        )
    }

    /// Extract reason text after a book recommendation
    private func extractReason(from text: String) -> String {
        // Get the first line or sentence after the book
        let lines = text.components(separatedBy: CharacterSet.newlines)
        if let firstLine = lines.first {
            let trimmed = firstLine
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "()-–"))
                .trimmingCharacters(in: .whitespaces)

            // Limit to a reasonable length
            if trimmed.count > 100 {
                return String(trimmed.prefix(100)) + "..."
            }
            return trimmed.isEmpty ? "Recommended for you" : trimmed
        }
        return "Recommended for you"
    }

    /// Generate contextual follow-up questions
    private func generateFollowUpQuestions(originalQuestion: String, response: String) -> [String] {
        var followUps: [String] = []
        let questionLower = originalQuestion.lowercased()
        let responseLower = response.lowercased()

        // Book recommendation context
        if responseLower.contains("recommend") || responseLower.contains("might enjoy") || responseLower.contains("you'd like") {
            followUps.append("Tell me more about one of these")
            followUps.append("Something more literary")
            followUps.append("Anything newer?")
        }
        // Reading habits context
        else if questionLower.contains("read") && questionLower.contains("next") {
            followUps.append("What genre am I in the mood for?")
            followUps.append("Based on my favorites")
            followUps.append("Something short")
        }
        // General conversation
        else {
            followUps.append("Tell me more")
            followUps.append("Any book recommendations?")
            followUps.append("What else should I know?")
        }

        // Check if AI asked a question - if so, don't add generic follow-ups
        if response.contains("?") {
            // AI asked a question, let user respond naturally
            return []
        }

        return Array(followUps.prefix(3))
    }

    private func getAIResponse(for text: String) async {
        let aiService = AICompanionService.shared
        let offlineQueue = OfflineQueueManager.shared
        let conversationFlows = AmbientConversationFlows.shared

        // MARK: - Check for conversation flow intents FIRST
        // This routes specialized queries (reading plans, library insights) to their proper handlers
        if let flowIntent = conversationFlows.detectFlowIntent(from: text) {
            await handleConversationFlow(flowIntent, originalText: text)
            return
        }

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

        // Check network status - if offline, queue the question
        if !offlineQueue.isOnline {
            await MainActor.run {
                offlineQueue.addQuestion(text, book: currentBookContext, sessionContext: currentSession?.id?.uuidString)

                // Update UI to show queued state
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let queuedMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\n📵 You're offline. This question has been queued and will be answered when you're back online.",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        bookContext: currentBookContext
                    )
                    messages[thinkingIndex] = queuedMessage
                } else {
                    let queuedMessage = UnifiedChatMessage(
                        content: "📵 You're offline. This question has been queued and will be answered when you're back online.",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(queuedMessage)
                }

                // Save question to current session
                if let session = currentSession {
                    let capturedQuestion = CapturedQuestion(
                        content: text,
                        book: currentBookContext.map { BookModel(from: $0) },
                        pageNumber: nil,
                        timestamp: Date(),
                        source: .manual
                    )
                    capturedQuestion.answer = "Queued for when you're back online"
                    capturedQuestion.isAnswered = false

                    if session.capturedQuestions == nil {
                        session.capturedQuestions = []
                    }
                    session.capturedQuestions?.append(capturedQuestion)
                    try? modelContext.save()
                }
            }
            return
        }

        do {
            // For generic mode (no book context), use conversational prompting
            let enhancedPrompt: String
            if currentBookContext == nil {
                enhancedPrompt = """
                You are a friendly reading companion having a conversation. Be warm, curious, and engaging.

                IMPORTANT FORMATTING RULES:
                1. Keep responses concise and conversational (2-3 short paragraphs max)
                2. When recommending books, list them clearly with:
                   - **Title** by Author
                   - A brief one-line reason why they'd enjoy it
                3. End with a follow-up question to continue the conversation
                4. Use natural paragraph breaks for readability

                User's message: \(text)
                """
            } else {
                enhancedPrompt = text
            }

            let response = try await aiService.processMessage(
                enhancedPrompt,
                bookContext: currentBookContext,
                conversationHistory: messages
            )

            await MainActor.run {
                // For generic mode, create conversational response with follow-ups
                if currentBookContext == nil {
                    // Parse response for potential book recommendations
                    let parsedResponse = parseConversationalResponse(response, originalQuestion: text)

                    // Update thinking message with conversational response
                    if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                        let updatedMessage = UnifiedChatMessage(
                            content: parsedResponse.cleanedText,
                            isUser: false,
                            timestamp: messages[thinkingIndex].timestamp,
                            bookContext: nil,
                            messageType: parsedResponse.hasRecommendations
                                ? .bookRecommendations(parsedResponse.recommendations)
                                : .conversationalResponse(text: parsedResponse.cleanedText, followUpQuestions: parsedResponse.followUps)
                        )
                        messages[thinkingIndex] = updatedMessage
                        expandedMessageIds.insert(updatedMessage.id)
                    } else {
                        let aiMessage = UnifiedChatMessage(
                            content: parsedResponse.cleanedText,
                            isUser: false,
                            timestamp: Date(),
                            bookContext: nil,
                            messageType: parsedResponse.hasRecommendations
                                ? .bookRecommendations(parsedResponse.recommendations)
                                : .conversationalResponse(text: parsedResponse.cleanedText, followUpQuestions: parsedResponse.followUps)
                        )
                        messages.append(aiMessage)
                        expandedMessageIds.insert(aiMessage.id)
                    }
                } else {
                    // Book mode - use existing behavior
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
                            withAnimation(DesignSystem.Animation.easeStandard) {
                                expandedMessageIds.insert(updatedMessage.id)
                            }
                        }
                    } else {
                        // No thinking message found - create with proper format
                        let aiMessage = UnifiedChatMessage(
                            content: "**\(text)**\n\n\(response)",
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext
                        )
                        messages.append(aiMessage)
                    }
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

                            // Record conversation usage (only counts when AI actually answers)
                            storeKit.recordConversation()

                            try? modelContext.save()
                            #if DEBUG
                            print("✅ Updated SwiftData question with answer for summary view")
                            #endif
                        }
                    }
                }
                pendingQuestion = nil
            }
        } catch {
            await MainActor.run {
                // Update thinking message to show error
                var errorContent: String

                // Check if it's a rate limit error
                if let perplexityError = error as? PerplexityError,
                   case .rateLimitExceeded(_, _) = perplexityError {
                    errorContent = """
                    **\(text)**

                    **Monthly Conversation Limit Reached.**

                    You've used all your free ambient conversations this month.

                    **Want unlimited conversations?**

                    Upgrade to Epilogue+ for unlimited ambient AI conversations.

                    [UPGRADE_BUTTON]
                    """
                } else {
                    // Check for rate limit in error description
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("rateLimitExceeded") || errorDesc.contains("rate limit") {
                        errorContent = """
                        **\(text)**

                        **Monthly Conversation Limit Reached.**

                        You've used all your free ambient conversations this month.

                        **Want unlimited conversations?**

                        Upgrade to Epilogue+ for unlimited ambient AI conversations.

                        [UPGRADE_BUTTON]
                        """
                    } else {
                        errorContent = "**\(text)**\n\nSorry, I couldn't process your message right now. Please try again."
                    }
                }

                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let updatedMessage = UnifiedChatMessage(
                        content: errorContent,
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        bookContext: currentBookContext
                    )
                    messages[thinkingIndex] = updatedMessage
                } else {
                    let errorMessage = UnifiedChatMessage(
                        content: errorContent,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(errorMessage)
                }
                pendingQuestion = nil
                #if DEBUG
                print("❌ Failed to process message: \(error)")
                #endif
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
            #if DEBUG
            print("🔑 AI Service configured: false")
            #endif
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
                    #if DEBUG
                    print("✅ Updated ambient question with AI response: \(text.prefix(30))...")
                    #endif
                }
                
                // CRITICAL: Update the saved question in SwiftData with the answer
                if let session = currentSession {
                    // Find the question in the current session's questions
                    if let question = (session.capturedQuestions ?? []).first(where: { $0.content == text }) {
                        question.answer = response
                        question.isAnswered = true

                        // Record conversation usage (only counts when AI actually answers)
                        storeKit.recordConversation()

                        try? modelContext.save()
                        #if DEBUG
                        print("✅ Updated SwiftData question with answer for summary view")
                        #endif
                        #if DEBUG
                        print("   Session has \((session.capturedQuestions ?? []).count) questions")
                        #endif
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
                       case .rateLimitExceeded(_, let resetTime) = perplexityError {
                        // Show rate limit message for Epilogue+ conversation limit
                        let storeKit = SimplifiedStoreKitManager.shared
                        let remaining = storeKit.conversationsRemaining() ?? 0

                        let calendar = Calendar.current
                        let now = Date()

                        // Calculate time until next month (first day of next month)
                        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now)!
                        let firstOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))!

                        let components = calendar.dateComponents([.day, .hour], from: now, to: firstOfNextMonth)
                        let daysUntilReset = components.day ?? 0
                        let hoursUntilReset = components.hour ?? 0

                        let resetTimeStr: String
                        if daysUntilReset > 0 {
                            resetTimeStr = "\(daysUntilReset)d \(hoursUntilReset)h"
                        } else {
                            resetTimeStr = "\(hoursUntilReset)h"
                        }

                        errorContent = """
                        **\(text)**

                        **Monthly Conversation Limit Reached.**

                        You've used all 8 of your free ambient conversations this month. Your limit resets in \(resetTimeStr) (on the 1st of next month).

                        Your question has been saved and you can try again when your limit resets.

                        **Want unlimited conversations?**

                        Upgrade to Epilogue+ for unlimited ambient AI conversations with your books.

                        [UPGRADE_BUTTON]
                        """
                    } else {
                        // Generic error message with better formatting
                        let errorDesc = error.localizedDescription
                        if errorDesc.contains("rateLimitExceeded") {
                            // Fallback for rate limit errors that don't match the pattern
                            errorContent = """
                            **\(text)**

                            **Monthly Conversation Limit Reached.**

                            You've used all your free ambient conversations this month.

                            **Want unlimited conversations?**

                            Upgrade to Epilogue+ for unlimited ambient AI conversations.

                            [UPGRADE_BUTTON]
                            """
                        } else {
                            errorContent = "**\(text)**\n\nSorry, I couldn't process your message right now. Please try again."
                        }
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
                #if DEBUG
                print("❌ Failed to get AI response: \(error)")
                #endif
            }
        }
    }
    
    private func handleBookDetection(_ book: Book?) {
        guard let book = book else { return }

        // CRITICAL: Don't auto-switch to book mode when in Generic mode
        // Generic mode should stay focused on general conversations, recommendations, etc.
        let isGenericMode = EpilogueAmbientCoordinator.shared.ambientMode.isGeneric
        if isGenericMode {
            #if DEBUG
            print("📚 Ignoring book detection in Generic mode - staying generic")
            #endif
            return
        }

        // CRITICAL: Prevent duplicate detections for the same book
        if lastDetectedBookId == book.localId {
            #if DEBUG
            print("📚 Ignoring duplicate book detection: \(book.title)")
            #endif
            return
        }
        
        // Also check if it's the same as current book context
        if currentBookContext?.localId == book.localId {
            #if DEBUG
            print("📚 Book already set as current context: \(book.title)")
            #endif
            return
        }
        
        #if DEBUG
        print("📚 Book detected: \(book.title)")
        #endif
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
                        #if DEBUG
                        print("📚 Updated session with first detected book: \(book.title)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("❌ Failed to update session with detected book: \(error)")
                        #endif
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
                            #if DEBUG
                            print("📖 Updated current page to: \(pageNumber)")
                            #endif
                            
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
        #if DEBUG
        print("🎨 Extracting colors for: \(book.title)")
        #endif

        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            #if DEBUG
            print("✅ Found cached palette for: \(book.title)")
            #endif
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.colorPalette = cachedPalette
                }
            }
            return
        }

        guard let coverURLString = book.coverImageURL else {
            #if DEBUG
            print("❌ No cover URL for: \(book.title)")
            #endif
            return
        }

        #if DEBUG
        print("🔗 Cover URL: \(coverURLString)")
        #endif

        // Use SharedBookCoverManager to load the image - this ensures proper zoom parameter
        // and consistent image quality across the app
        guard let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURLString) else {
            #if DEBUG
            print("❌ Failed to load cover image for: \(book.title)")
            #endif
            return
        }

        #if DEBUG
        print("📐 Image size: \(image.size)")
        #endif

        do {
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: image, imageSource: book.title)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.5)) {
                    self.colorPalette = palette
                    self.coverImage = image
                    #if DEBUG
                    print("✅ Color palette extracted for: \(book.title)")
                    print("  Primary: \(palette.primary)")
                    print("  Secondary: \(palette.secondary)")
                    #endif
                }
            }

            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
        } catch {
            #if DEBUG
            print("❌ Failed to extract colors: \(error)")
            #endif
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
        
        // Dismiss the view immediately using coordinator
        EpilogueAmbientCoordinator.shared.dismiss()
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
            
            // Debug: Log the session's questions before saving
            #if DEBUG
            print("📊 DEBUG: About to save session. Questions in session:")
            #endif
            for (i, q) in (session.capturedQuestions ?? []).enumerated() {
                #if DEBUG
                print("   \(i+1). \(q.content?.prefix(50) ?? "nil") - Answer: \(q.answer != nil ? "Yes" : "No")")
                #endif
            }
            
            // Force save to ensure all relationships are persisted
            do {
                try modelContext.save()
                #if DEBUG
                print("✅ Session saved with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
                #endif

                // Update reading habit plan if one is active
                updateReadingPlanFromSession(session)

            } catch {
                #if DEBUG
                print("❌ Failed to save session: \(error)")
                #endif
            }
            
            // Debug: Log what we're saving
            #if DEBUG
            print("📊 Session Summary Debug:")
            #endif
            #if DEBUG
            print("   Questions: \((session.capturedQuestions ?? []).count)")
            #endif
            for (i, q) in (session.capturedQuestions ?? []).enumerated() {
                #if DEBUG
                print("     \(i+1). \((q.content ?? "").prefix(50))... Answer: \(q.isAnswered ?? false ? "Yes" : "No")")
                #endif
            }
            #if DEBUG
            print("   Quotes: \((session.capturedQuotes ?? []).count)")
            #endif
            for (i, quote) in (session.capturedQuotes ?? []).enumerated() {
                #if DEBUG
                print("     \(i+1). \((quote.text ?? "").prefix(50))...")
                #endif
            }
            #if DEBUG
            print("   Notes: \((session.capturedNotes ?? []).count)")
            #endif
            for (i, note) in (session.capturedNotes ?? []).enumerated() {
                #if DEBUG
                print("     \(i+1). \((note.content ?? "").prefix(50))...")
                #endif
            }
            
            // Show summary if there's meaningful content
            if (session.capturedQuestions ?? []).count > 0 || (session.capturedQuotes ?? []).count > 0 || (session.capturedNotes ?? []).count > 0 {
                // Present the session summary sheet
                showingSessionSummary = true
                logger.info("📊 Showing session summary with \((session.capturedQuestions ?? []).count) questions, \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes")
            } else {
                // No meaningful content - delete the empty session
                logger.info("📊 No meaningful content in session, deleting empty session and dismissing")
                modelContext.delete(session)
                try? modelContext.save()
                EpilogueAmbientCoordinator.shared.dismiss()
            }
        } else {
            // No session - just dismiss
            logger.info("❌ No session found, dismissing")
            EpilogueAmbientCoordinator.shared.dismiss()
        }
    }
    
    private func createSession() -> AmbientSession {
        // Use existing session - it was created at start and items were added during saving
        guard let session = currentSession else {
            #if DEBUG
            print("❌ No current session found!")
            #endif
            return AmbientSession(book: currentBookContext)
        }
        
        // Just set the end time
        session.endTime = Date()
        
        // Validate session has content before saving
        let hasQuotes = (session.capturedQuotes ?? []).count > 0
        let hasNotes = (session.capturedNotes ?? []).count > 0
        let hasQuestions = (session.capturedQuestions ?? []).count > 0
        let hasContent = hasQuotes || hasNotes || hasQuestions
        
        #if DEBUG
        print("📊 Finalizing session with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
        #endif
        
        // Only save if there's actual content
        if hasContent {
            do {
                // Force save context to ensure all relationships are persisted
                if modelContext.hasChanges {
                    try modelContext.save()
                    #if DEBUG
                    print("✅ Session finalized in SwiftData with content")
                    #endif
                } else {
                    #if DEBUG
                    print("⚠️ No changes to save in model context")
                    #endif
                    // Force a save anyway to ensure persistence
                    session.endTime = Date() // Touch the session
                    try modelContext.save()
                }
            } catch {
                #if DEBUG
                print("❌ Failed to finalize session: \(error)")
                #endif
                // Try using safe save extension
                modelContext.safeSave()
            }
        } else {
            #if DEBUG
            print("⚠️ Session is empty, removing from context")
            #endif
            modelContext.delete(session)
            try? modelContext.save()
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
            #if DEBUG
            print("✅ Saved session for \(currentBookContext?.title ?? "unknown book") with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save session before book switch: \(error)")
            #endif
        }
    }
    
    private func loadExistingSessionIfAvailable() {
        // Check if we're continuing from an existing session
        if let existingSession = EpilogueAmbientCoordinator.shared.existingSession {
            #if DEBUG
            print("📖 Loading existing session with \((existingSession.capturedQuestions ?? []).count) questions")
            #endif

            // Load the book context
            if let bookModel = existingSession.bookModel {
                // Convert BookModel to Book
                if let book = libraryViewModel.books.first(where: { $0.id == bookModel.id }) {
                    currentBookContext = book
                    bookDetector.setCurrentBook(book)

                    // Load color palette
                    Task {
                        await extractColorsForBook(book)
                    }
                }
            }

            // Load conversation history into messages
            for question in existingSession.capturedQuestions ?? [] {
                if let content = question.content {
                    // Add the question
                    let questionMessage = UnifiedChatMessage(
                        content: content,
                        isUser: true,
                        timestamp: question.timestamp ?? Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(questionMessage)

                    // Add the answer if available
                    if let answer = question.answer {
                        let answerMessage = UnifiedChatMessage(
                            content: answer,
                            isUser: false,
                            timestamp: Date(timeInterval: 1, since: question.timestamp ?? Date()),
                            bookContext: currentBookContext
                        )
                        messages.append(answerMessage)
                    }
                }
            }

            // Continue the same session
            currentSession = existingSession
            currentSession?.startTime = Date() // Update start time for this continuation

            #if DEBUG
            print("✅ Loaded \(messages.count) messages from previous session")
            #endif
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
            #if DEBUG
            print("📚 Started new session for book: \(book.title)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to create new session: \(error)")
            #endif
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
                                #if DEBUG
                                print("📚 Started new session without book context")
                                #endif
                            } catch {
                                #if DEBUG
                                print("❌ Failed to create new session: \(error)")
                                #endif
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

                // Horizontal divider line
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(0.1), location: 0),
                        .init(color: Color.white.opacity(0.5), location: 0.5),
                        .init(color: Color.white.opacity(0.1), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Attribution section (author and book title)
                VStack(alignment: .leading, spacing: 6) {
                    if let author = quote.author {
                        Text(author.uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let bookTitle = quote.book?.title {
                        Text(bookTitle.uppercased())
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(.white.opacity(0.5))
                    }
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
    let streamingText: String?
    let relatedQuestions: [String]  // Follow-up suggestions from Sonar
    let onToggle: () -> Void
    let onEdit: ((String) -> Void)?
    let onRelatedQuestionTap: ((String) -> Void)?  // Continue conversation
    @Binding var showPaywall: Bool

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
                        .lineLimit(2)  // Allow question to wrap to 2 lines if needed
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Use streaming text if available, otherwise use message content
                    Group {
                        let displayContent: String = {
                            if let streaming = streamingText {
                                return "**\(extractContent(from: message.content).question)**\n\n\(streaming)"
                            } else {
                                return message.content
                            }
                        }()
                        let content = extractContent(from: displayContent)

                        // Show question text
                        Text(content.question)
                            .font(.system(size: 16, weight: .regular, design: .default))  // Match note cards
                            .foregroundStyle(.white.opacity(0.95)) // Match note cards opacity
                            .lineLimit(2)  // Allow question to wrap to 2 lines if needed
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
                // Use streaming text if available
                let displayContent: String = {
                    if let streaming = streamingText {
                        return "**\(extractContent(from: message.content).question)**\n\n\(streaming)"
                    } else {
                        return message.content
                    }
                }()
                let content = extractContent(from: displayContent)

                // If no answer yet, don't show anything special
                // The scrolling text is already shown above the input field
                if content.answer.isEmpty && streamingText == nil {
                    // Empty state - answer will appear here when ready
                } else {
                    // Show answer when ready with staggered fade-in
                    VStack(alignment: .leading, spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 0.5)

                        // Check if content has upgrade button
                        let hasUpgradeButton = content.answer.contains("[UPGRADE_BUTTON]")
                        let cleanAnswer = content.answer.replacingOccurrences(of: "[UPGRADE_BUTTON]", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

                        Text(formatResponseText(cleanAnswer))
                            .font(.custom("Georgia", size: 17))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 0)
                            .padding(.trailing, 20)
                            .padding(.vertical, 12)
                            .padding(.bottom, hasUpgradeButton ? 0 : 4)

                        // Upgrade button if present
                        if hasUpgradeButton {
                            Button {
                                SensoryFeedback.light()
                                showPaywall = true
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.15))
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(
                                                    Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.4),
                                                    lineWidth: 1.5
                                                )
                                        }

                                    Text("Upgrade to Epilogue+")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .frame(height: 48)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        }

                        // Related questions pills - continue the conversation
                        if !relatedQuestions.isEmpty, let onTap = onRelatedQuestionTap {
                            RelatedQuestionsPillRow(
                                questions: relatedQuestions,
                                onQuestionTap: onTap
                            )
                        }
                    }
                    .opacity(isExpanded ? answerOpacity : 0)
                    .blur(radius: isExpanded ? answerBlur : 8)
                    .onAppear {
                        // Show answer immediately without delay
                        hasShownAnswer = true
                        // Elegant fade-in with perfect timing
                        withAnimation(.timingCurve(0.32, 0, 0.67, 0, duration: 0.5)) {
                            answerOpacity = 1.0
                        }
                        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
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
        // CRITICAL FIX: Preserve original formatting, only clean markdown
        // DO NOT destroy line breaks, lists, or spacing
        let cleanText = text
            .replacingOccurrences(of: "**", with: "") // Remove markdown bold
            .replacingOccurrences(of: "##", with: "") // Remove markdown headers

        // Convert to AttributedString with markdown support
        // This preserves ALL original formatting including line breaks, lists, etc.
        do {
            return try AttributedString(markdown: cleanText)
        } catch {
            // Fallback if markdown parsing fails
            return AttributedString(cleanText)
        }
    }
}

// MARK: - Generic Mode Typing Indicator
/// Polished amber-tinted typing indicator with fluid wave animation
struct GenericModeTypingIndicator: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]
    @State private var timer: Timer?

    // Amber accent color matching app theme
    private let amberColor = Color(red: 1.0, green: 0.6, blue: 0.2)

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(amberColor)
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffsets[i])
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(amberColor.opacity(0.15)))

            Spacer()
        }
        .onAppear {
            startBounceAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startBounceAnimation() {
        // Staggered bounce for each dot
        for i in 0..<3 {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateDot(at: i)
            }
        }

        // Repeat the whole sequence
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            for i in 0..<3 {
                let delay = Double(i) * 0.15
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    animateDot(at: i)
                }
            }
        }
    }

    private func animateDot(at index: Int) {
        withAnimation(.easeOut(duration: 0.25)) {
            dotOffsets[index] = -6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.25)) {
                dotOffsets[index] = 0
            }
        }
    }
}

// MARK: - Generic Mode Chat Bubble
/// Amber-tinted chat bubble for Generic mode with proper markdown rendering
struct GenericModeChatBubble: View {
    let message: UnifiedChatMessage
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var messageOpacity: Double = 0
    @State private var messageScale: CGFloat = 0.95

    // Amber accent matching app theme
    private let amberColor = Color(red: 1.0, green: 0.6, blue: 0.2)

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if message.isUser {
                    // User message - right aligned with amber-tinted glass
                    Text(message.content)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(amberColor.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(amberColor.opacity(0.4), lineWidth: 1)
                        )
                } else {
                    // AI response - left aligned with amber glass tint
                    VStack(alignment: .leading, spacing: 12) {
                        // Rendered markdown content
                        GenericModeMarkdownText(
                            text: message.content,
                            isExpanded: isExpanded
                        )

                        // Expand indicator for long content
                        if !isExpanded && message.content.count > 300 {
                            HStack(spacing: 4) {
                                Text("Tap to expand")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(amberColor.opacity(0.7))
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16) // More vertical padding
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(amberColor.opacity(0.25), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggle()
                    }
                }
            }

            if !message.isUser {
                Spacer(minLength: 12)
            }
        }
        .padding(.vertical, 10) // More spacing between bubbles
        .opacity(messageOpacity)
        .scaleEffect(messageScale)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                messageOpacity = 1
                messageScale = 1
            }
        }
    }
}

// MARK: - Generic Mode Markdown Text Renderer
/// Renders markdown with proper formatting - strips all markdown symbols
struct GenericModeMarkdownText: View {
    let text: String
    let isExpanded: Bool

    // Amber accent
    private let amberColor = Color(red: 1.0, green: 0.6, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parsedBlocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
        .lineLimit(isExpanded ? nil : 8)
    }

    private var parsedBlocks: [MarkdownBlock] {
        parseMarkdown(text)
    }

    private enum MarkdownBlock {
        case paragraph(String)
        case numberedItem(Int, String, String?) // num, title, description
        case bulletItem(String)
    }

    private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentParagraph = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            guard !trimmed.isEmpty else {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(cleanAllMarkdown(currentParagraph)))
                    currentParagraph = ""
                }
                continue
            }

            // Check for numbered list patterns like "**1." or "1." or "**1. *Title*"
            if let numRange = trimmed.range(of: #"^\*{0,2}\d+\.?\*{0,2}\s+"#, options: .regularExpression) {
                // Flush paragraph
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(cleanAllMarkdown(currentParagraph)))
                    currentParagraph = ""
                }

                // Extract number
                let prefix = String(trimmed[numRange])
                if let digitMatch = prefix.range(of: #"\d+"#, options: .regularExpression) {
                    let num = Int(prefix[digitMatch]) ?? 1
                    let content = String(trimmed[numRange.upperBound...])

                    // Try to split into title and description
                    // Pattern: *Title* by Author - Description OR Title by Author\nDescription
                    let cleaned = cleanAllMarkdown(content)

                    // Check if there's a " by " pattern to split title from description
                    if let byRange = cleaned.range(of: " by ", options: .caseInsensitive) {
                        let title = String(cleaned[..<byRange.lowerBound])
                        let rest = String(cleaned[byRange.lowerBound...])
                        blocks.append(.numberedItem(num, title, rest))
                    } else {
                        blocks.append(.numberedItem(num, cleaned, nil))
                    }
                }
            }
            // Check for bullet list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(cleanAllMarkdown(currentParagraph)))
                    currentParagraph = ""
                }
                let content = String(trimmed.dropFirst(2))
                blocks.append(.bulletItem(cleanAllMarkdown(content)))
            }
            // Regular text - accumulate into paragraph
            else {
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmed
            }
        }

        // Flush remaining
        if !currentParagraph.isEmpty {
            blocks.append(.paragraph(cleanAllMarkdown(currentParagraph)))
        }

        return blocks
    }

    /// Strip ALL markdown formatting characters
    private func cleanAllMarkdown(_ text: String) -> String {
        var result = text
        // Remove bold markers
        result = result.replacingOccurrences(of: "**", with: "")
        // Remove italic markers (but be careful not to break contractions)
        result = result.replacingOccurrences(of: "*", with: "")
        // Remove code markers
        result = result.replacingOccurrences(of: "`", with: "")
        // Remove heading markers
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")
        // Remove footnote references like [1], [2], etc.
        let footnotePattern = "\\[\\d+\\]"
        if let regex = try? NSRegularExpression(pattern: footnotePattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        // Clean up extra spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

        case .numberedItem(let num, let title, let description):
            VStack(alignment: .leading, spacing: 8) {
                // Title line with number integrated
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(num). ")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(amberColor.opacity(0.6))

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 16)

                    // Minimal action icons - tighter, lighter
                    HStack(spacing: 16) {
                        Button {
                            SensoryFeedback.light()
                            NotificationCenter.default.post(
                                name: NSNotification.Name("AddBookToLibrary"),
                                object: title
                            )
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)

                        Button {
                            SensoryFeedback.light()
                            // Use user's preferred bookstore
                            BookstoreURLBuilder.shared.openBookstore(title: title, author: "")
                        } label: {
                            Image(systemName: "cart")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Description with author - softer, more space
                if let desc = description {
                    Text(desc)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineSpacing(3)
                        .padding(.leading, "\(num). ".count > 2 ? 20 : 16) // Align with title
                }
            }
            .padding(.vertical, 4) // Breathing room between items

        case .bulletItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(amberColor)
                    .frame(width: 6, height: 6)
                    .padding(.leading, 8)

                Text(text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}

