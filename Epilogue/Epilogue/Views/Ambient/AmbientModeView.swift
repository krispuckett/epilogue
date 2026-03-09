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

// MARK: - Fixed Ambient Mode View (Keeping Original Gradients!)
struct AmbientModeView: View {
    @StateObject var processor = TrueAmbientProcessor.shared
    @StateObject var voiceManager = VoiceRecognitionManager.shared
    @StateObject var bookDetector = AmbientBookDetector.shared
    @State private var microInteractionManager = MicroInteractionManager.shared
    @State private var themeManager = ThemeManager.shared
    @State var storeKit = SimplifiedStoreKitManager.shared

    // Namespace for matched geometry morphing animation
    @Namespace private var buttonMorphNamespace
    
    @State var messages: [UnifiedChatMessage] = []
    @State var currentBookContext: Book?
    @State var colorPalette: ColorPalette?
    @State var isRecording = false
    @State var liveTranscription: String = ""
    @State private var audioLevel: Float = 0
    @State private var messageText = ""
    @State var coverImage: UIImage?
    @FocusState private var isInputFocused: Bool
    @State private var showingCommandPalette = false
    @State private var scrollProxy: ScrollViewProxy?
    @State var detectionState: DetectionState = .idle
    @State var lastDetectedBookId: UUID?
    @State private var showingBookStrip = false
    @State private var showBookCoverInChat = true
    @State var savedItemsCount = 0
    @State var showSaveAnimation = false
    @State var savedItemType: String? = nil
    @State var showBookCover = false
    @State private var showBookSelector = false
    @State var bookCoverTimer: Timer?
    @State var expandedMessageIds = Set<UUID>()  // Track expanded messages individually
    @State var relatedQuestionsMap: [UUID: [String]] = [:]  // Related questions per AI message
    @State var showImagePicker = false
    @State var capturedImage: UIImage?
    @State var extractedText: String = ""
    @State var showQuoteHighlighter = false
    @State var cameraJustUsed = false
    @State var isProcessingImage = false
    @State var streamingResponses: [UUID: String] = [:]  // Track streaming text by message ID
    @State var processedContentHashes = Set<String>() // Deduplication
    @State var transcriptionFadeTimer: Timer?
    @State private var isTranscriptionDissolving = false
    @State var currentSession: AmbientSession?
    @State var showingSessionSummary = false
    @State var showPaywall = false
    @State var sessionStartTime: Date?
    @State private var isEditingTranscription = false
    @State private var editableTranscription = ""
    @FocusState private var isTranscriptionFocused: Bool
    // Removed: isWaitingForAIResponse and shouldCollapseThinking - now using inline thinking messages
    @State var pendingQuestion: String?
    @State var isGenericModeThinking = false  // Typing indicator for Generic mode
    @State var lastProcessedCount = 0
    @State var showRecommendationFlow = false  // Quick question flow for recommendations
    @State var recommendationContext: RecommendationContext? = nil  // Context from questions
    @State var showReadingPlanFlow: ReadingPlanQuestionFlow.FlowType? = nil  // Reading habit/challenge flow
    @State var readingPlanContext: ReadingPlanContext? = nil
    @State private var debounceTimer: Timer?
    @State var createdReadingPlan: ReadingHabitPlan? = nil  // Newly created plan to display
    @State var showPlanDetail = false  // Show full plan detail view
    @State var showLocalToast = false  // Local toast for ambient mode
    @State var localToastMessage = ""
    @Query(filter: #Predicate<ReadingHabitPlan> { $0.isActive == true }, sort: \ReadingHabitPlan.createdAt, order: .reverse)
    var activeReadingPlans: [ReadingHabitPlan]  // Query for active plans

    @Query(sort: \BookModel.dateAdded, order: .reverse)
    private var allBookModels: [BookModel]  // For book selection in reading plans
    
    // New keyboard input states
    @State var inputMode: AmbientInputMode = .listening
    @State var keyboardText = ""
    @State private var containerBlur: Double = 0
    @State private var submitBlurWave: Double = 0
    @State private var textFieldHeight: CGFloat = 44  // Track dynamic height, starts compact at single line
    @State private var lastCharacterCount: Int = 0
    @State private var breathingTimer: Timer?
    @State var showVisualIntelligenceCapture = false
    @Namespace private var morphingNamespace  // For smooth morphing animation
    @FocusState var isKeyboardFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var hasAppearedOnce = false  // Prevent keyboard auto-focus on initial load
    
    // Smooth gradient transitions - start visible
    @State private var gradientOpacity: Double = 1.0  // Start visible immediately
    @State private var lastBookId: UUID? = nil
    
    // Inline editing states
    @State var editingMessageId: UUID? = nil
    @State var editingMessageType: UnifiedChatMessage.MessageType? = nil

    // Onboarding states
    @State private var showOnboarding = true
    @State private var onboardingOpacity: Double = 0.0
    @State private var onboardingTimer: Timer?
    @AppStorage("ambientModeOnboardingShown") private var onboardingShownCount: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var isPresentedModally = false
    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(LibraryViewModel.self) var libraryViewModel
    @Environment(NotesViewModel.self) var notesViewModel
    @Environment(AppStateCoordinator.self) var appStateCoordinator
    
    // Settings
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("showLiveTranscriptionBubble") private var showLiveTranscriptionBubble = true
    @AppStorage("alwaysShowInput") private var alwaysShowInput = false
    
    // Voice mode state
    @State var isVoiceModeEnabled = true
    
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


            // Conversational recommendation flow overlay (for generic mode)
            if showRecommendationFlow {
                ConversationalRecommendationView(
                    books: libraryViewModel.books,
                    onMoodSelected: { mood in
                        handleMoodRecommendation(mood)
                    },
                    onStarterSelected: { prompt in
                        handleConversationStarterSelected(prompt)
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
                .environment(libraryViewModel)
                .environment(notesViewModel)
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
            // Skip auto-focus on initial load to let user see content first
            if newMode == .textInput && hasAppearedOnce {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isKeyboardFocused = true
                }
            } else if newMode != .textInput {
                isKeyboardFocused = false
            }

            // Mark that we've appeared - future mode changes will auto-focus
            if !hasAppearedOnce {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    hasAppearedOnce = true
                }
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
                                    Task {
                                        // Cancel notifications when pausing
                                        await ReadingPlanNotificationService.shared.cancelReminders(for: plan)
                                        plan.pause()
                                        try? modelContext.save()
                                    }
                                }
                                Divider()
                                Button("Delete Plan", systemImage: "trash", role: .destructive) {
                                    Task {
                                        // Cancel notifications before deleting the plan
                                        await ReadingPlanNotificationService.shared.cancelReminders(for: plan)
                                        modelContext.delete(plan)
                                        try? modelContext.save()
                                        createdReadingPlan = nil
                                        showPlanDetail = false
                                    }
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
        // Live Activity quick action deep links
        .onReceive(NotificationCenter.default.publisher(for: .ambientQuickAction)) { notification in
            guard let action = notification.object as? String else { return }
            switch action {
            case "voice-capture":
                // Switch to voice mode and start recording
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    isVoiceModeEnabled = true
                    inputMode = .listening
                }
                if !isRecording {
                    handleMicrophoneTap()
                }
            case "ocr":
                showImagePicker = true
            case "ai-chat":
                // Switch to text input and focus keyboard
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    inputMode = .textInput
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isKeyboardFocused = true
                }
            case "end-session":
                // Full session end: save, show summary, end Live Activity
                stopAndSaveSession()
            default:
                break
            }
        }
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
                forName: .queuedQuestionProcessed,
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
            NotificationCenter.default.removeObserver(self, name: .queuedQuestionProcessed, object: nil)
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
                    let ambientIntensity = gradientIntensity * (isRecording ? 0.9 + Double(audioLevel) * 0.3 : 0.85)
                    let ambientAudio: Float = isRecording ? audioLevel : 0

                    if AtmosphereEngine.isEnabled {
                        UnifiedAtmosphericGradient(
                            legacyPalette: palette,
                            preset: .atmospheric,
                            intensity: ambientIntensity,
                            audioLevel: ambientAudio
                        )
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                        .opacity(gradientOpacity)
                        .animation(.easeInOut(duration: 1.0), value: gradientOpacity)
                        .transition(.opacity)
                        .id(book.localId)
                    } else {
                        BookAtmosphericGradientView(
                            colorPalette: palette,
                            intensity: ambientIntensity,
                            audioLevel: ambientAudio
                        )
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                        .opacity(gradientOpacity)
                        .animation(.easeInOut(duration: 1.0), value: gradientOpacity)
                        .transition(.opacity)
                        .id(book.localId)
                    }
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

                            // Reading insights from knowledge graph
                            ReadingInsightsCard()
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .opacity(isRecording ? 0.6 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: isRecording)
                        } else if let book = currentBookContext {
                            // Book-specific ambient mode - powered by Reading Companion
                            CompanionAwareEmptyState(
                                book: book,
                                colorPalette: colorPalette,
                                currentPage: book.currentPage > 0 ? book.currentPage : nil,
                                hasNotes: currentBookHasNotes,
                                hasQuotes: currentBookHasQuotes,
                                onSuggestionTap: { suggestion in
                                    handleBookSuggestionTap(suggestion)
                                },
                                onCaptureQuote: {
                                    showVisualIntelligenceCapture = true
                                },
                                onCompanionResponse: { question, response in
                                    // Add companion response as formatted AI message
                                    let aiMessage = UnifiedChatMessage(
                                        content: "**\(question)**\n\n\(response)",
                                        isUser: false,
                                        timestamp: Date(),
                                        bookContext: currentBookContext
                                    )
                                    messages.append(aiMessage)
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
                                            streamingText: streamingResponses[message.id],
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
                        .frame(height: inputMode == .textInput ? 120 : 180)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        if let lastMessage = messages.last {
                            // Scroll to bottom of new message to show full content
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
            .onChange(of: isGenericModeThinking) { _, isThinking in
                // Scroll to typing indicator when it appears
                if isThinking && currentBookContext == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
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

    // MARK: - Clean Bottom Input Area
    @ViewBuilder
    private var bottomInputArea: some View {
        GlassEffectContainer {
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
                        // Unified morphing background - subtle dark fill, no glass overlay
                        RoundedRectangle(
                            cornerRadius: inputMode == .textInput || !isVoiceModeEnabled ? 20 : 32,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(inputMode == .textInput || !isVoiceModeEnabled ? 0.08 : 0))
                        .frame(
                            width: inputMode == .textInput || !isVoiceModeEnabled ? geometry.size.width - 60 : 64,
                            height: inputMode == .textInput || !isVoiceModeEnabled ? textFieldHeight : 64
                        )
                        .allowsHitTesting(false)
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
                                            .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.2))
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Circle()
                                                    .strokeBorder(
                                                        Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.4),
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
        .padding(.bottom, inputMode == .textInput || !isVoiceModeEnabled ? 8 : 24)  // Padding above home indicator
        
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
        } // GlassEffectContainer
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
        GlassEffectContainer {
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
        } // GlassEffectContainer
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

            // Start Live Activity for Dynamic Island dashboard
            startLiveActivityForSession()

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

                // Start Live Activity for Dynamic Island dashboard
                startLiveActivityForSession()

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
    
    // MARK: - Live Activity Integration (KRI-134)

    private func startLiveActivityForSession() {
        Task {
            // Save cover thumbnail to App Group container for widget access
            let coverPath = saveCoverForLiveActivity()
            let accentHex = colorPalette.flatMap { hexFromColor($0.accent) }

            // Pre-render the ambient orb with the book's accent color
            let orbPath = renderOrbForLiveActivity(accentHex: accentHex)

            await LiveActivityLifecycleManager.shared.startSession(
                coverImagePath: coverPath,
                orbImagePath: orbPath
            )
            // Set initial content with book title and cover accent color
            await LiveActivityLifecycleManager.shared.updateContent(
                bookTitle: currentBookContext?.title,
                coverAccentHex: accentHex
            )
        }
    }

    private func renderOrbForLiveActivity(accentHex: String?) -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.epilogue.app"
        ) else { return nil }

        let orbFileURL = containerURL.appendingPathComponent("ambient_orb.png")

        // Parse accent color for the shader theme
        let renderer = OrbMetalRenderer()
        if let hex = accentHex {
            let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
            if clean.count == 6, let rgb = UInt64(clean, radix: 16) {
                renderer.themeColor = SIMD3<Float>(
                    Float((rgb >> 16) & 0xFF) / 255.0,
                    Float((rgb >> 8) & 0xFF) / 255.0,
                    Float(rgb & 0xFF) / 255.0
                )
            }
        }

        // Render at 2x for retina quality (orb shown at ~22-28pt)
        guard let image = renderer.renderToImage(size: CGSize(width: 64, height: 64)),
              let pngData = image.pngData() else {
            #if DEBUG
            print("⚠️ Failed to render orb snapshot for Live Activity")
            #endif
            return nil
        }

        do {
            try pngData.write(to: orbFileURL)
            #if DEBUG
            print("✅ Live Activity: Orb snapshot saved to \(orbFileURL.path)")
            #endif
            return orbFileURL.path
        } catch {
            #if DEBUG
            print("❌ Failed to save orb snapshot: \(error)")
            #endif
            return nil
        }
    }

    private func saveCoverForLiveActivity() -> String? {
        guard let book = currentBookContext else { return nil }

        // Reuse the cover already cached by BookWidgetUpdater in the App Group container
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.epilogue.app"
        ) else { return nil }

        let coverPath = containerURL.appendingPathComponent("\(book.localId.uuidString)_cover.jpg")

        if FileManager.default.fileExists(atPath: coverPath.path) {
            #if DEBUG
            print("✅ Live Activity: Found existing widget cover at \(coverPath.path)")
            #endif
            return coverPath.path
        }

        // If not cached yet, trigger caching now and return nil (fallback to accent color)
        if let coverURL = book.coverImageURL {
            Task {
                let path = await cacheCoverToAppGroup(from: coverURL, bookID: book.localId.uuidString)
                if path != nil {
                    // Update the Live Activity with the cover path on next refresh
                    #if DEBUG
                    print("✅ Live Activity: Cover cached for next update")
                    #endif
                }
            }
        }

        return nil
    }

    private func cacheCoverToAppGroup(from urlString: String, bookID: String) async -> String? {
        guard let url = URL(string: urlString),
              let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.epilogue.app"
              ) else { return nil }

        let coverFileURL = containerURL.appendingPathComponent("\(bookID)_cover.jpg")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data),
               let jpegData = image.jpegData(compressionQuality: 0.8) {
                try jpegData.write(to: coverFileURL)
                return coverFileURL.path
            }
        } catch {
            #if DEBUG
            print("❌ Failed to cache cover for Live Activity: \(error)")
            #endif
        }
        return nil
    }

    private func hexFromColor(_ color: Color) -> String? {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
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
    
    func sendMessage(_ text: String) async {
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

    func sendTextMessage() {
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
