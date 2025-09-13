import SwiftUI
import SwiftData

// MARK: - Voice Note Button Overlay (Minimal)
struct VoiceNoteButtonOverlay: View {
    @Binding var showVoiceRecording: Bool
    
    var body: some View {
        EmptyView() // Minimal implementation since original was deleted
    }
}

// MARK: - Glass Toast Modifier (Minimal)
struct GlassToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isShowing {
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        .padding(.vertical, 12)
                        .glassEffect()
                        .clipShape(Capsule())
                        .padding(.top, 50)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isShowing = false
                                }
                            }
                        }
                }
            }
    }
}

extension View {
    func glassToast(isShowing: Binding<Bool>, message: String) -> some View {
        modifier(GlassToastModifier(isShowing: isShowing, message: message))
    }
}

struct ContentView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @StateObject private var ambientCoordinator = EpilogueAmbientCoordinator.shared
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @AppStorage("useNewAmbientMode") private var useNewAmbient = true // Set to false to use old implementation
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var showCommandPalette = false
    @State private var showCommandInput = false
    @State private var commandText = ""
    @FocusState private var isInputFocused: Bool
    @State private var selectedDetent: PresentationDetent = .height(300)
    @Namespace private var animation
    @State private var showPrivacySettings = false
    @State private var showBookScanner = false
    @StateObject private var bookScanner = BookScannerService.shared
    @State private var showVoiceRecording = false
    @State private var showNoQuotesToast = false
    @State private var showingLibraryCommandPalette = false
    @State private var showGlassToast = false
    @State private var toastMessage = ""
    @State private var showBookSearch = false
    @State private var bookSearchQuery = ""
    @State private var pendingBookSearch = false  // Track pending search
    @State private var batchBookTitles: [String] = []
    @State private var currentBatchIndex = 0
    @State private var showBatchBookSearch = false
    
    // Command processing
    @Environment(\.modelContext) private var modelContext
    @Query private var capturedNotes: [CapturedNote]
    @Query private var capturedQuotes: [CapturedQuote]
    
    // Command processing manager - will be set up properly in body
    
    init() {
        print("🏠 DEBUG: ContentView init")
        
        // Customize tab bar appearance for iOS 26
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        mainContent
            .overlay(alignment: .bottom) {
                commandInputOverlay
            }
            .interruptibleAnimation(.snappy, value: showCommandInput)
            .interruptibleAnimation(.smooth, value: selectedTab)
            .preferredColorScheme(.dark)
            .withErrorHandling()
            .sheet(isPresented: $showPrivacySettings) {
                NavigationStack {
                    PrivacySettingsView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showPrivacySettings = false
                                }
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showBookScanner) {
                BookScannerView()
                    .environmentObject(libraryViewModel)
            }
            .sheet(isPresented: $bookScanner.showSearchResults) {
                BookSearchSheet(
                    searchQuery: bookScanner.extractedText,
                    onBookSelected: { book in
                        libraryViewModel.addBook(book)
                        HapticManager.shared.bookOpen()
                        bookScanner.reset()
                    }
                )
            }
            .sheet(isPresented: $showBookSearch, onDismiss: {
                // Clean up when sheet is dismissed
                pendingBookSearch = false
                bookSearchQuery = ""
            }) {
                BookSearchSheet(
                    searchQuery: bookSearchQuery,
                    onBookSelected: { book in
                        libraryViewModel.addBook(book)
                        HapticManager.shared.bookOpen()
                        
                        // Show success toast
                        toastMessage = "Added \"\(book.title)\" to library"
                        showGlassToast = true
                        
                        showBookSearch = false
                        // bookSearchQuery will be cleared in onDismiss
                    }
                )
            }
            .sheet(isPresented: $showBatchBookSearch) {
                BatchBookSearchSheet(
                    bookTitles: $batchBookTitles,
                    onBookSelected: { book in
                        libraryViewModel.addBook(book)
                        HapticManager.shared.bookOpen()
                        
                        let remaining = batchBookTitles.count - 1
                        if remaining > 0 {
                            toastMessage = "Added \"\(book.title)\". \(remaining) more to add..."
                        } else {
                            toastMessage = "Added \"\(book.title)\" - batch complete!"
                        }
                        showGlassToast = true
                    },
                    onComplete: {
                        batchBookTitles.removeAll()
                        showBatchBookSearch = false
                    }
                )
            }
            .overlay {
                BookScannerLoadingOverlay()
            }
            .overlay {
                VoiceNoteButtonOverlay(showVoiceRecording: $showVoiceRecording)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartVoiceNote"))) { _ in
                HapticManager.shared.voiceModeStart()
                showVoiceRecording = true
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShareQuote"))) { notification in
                if let quote = notification.object as? Note {
                    ShareQuoteService.shareQuote(quote)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowNoQuotesToast"))) { _ in
                showNoQuotesToast = true
                SensoryFeedback.warning()
            }
            .glassToast(
                isShowing: $showNoQuotesToast,
                message: "No quotes to share yet"
            )
            .glassToast(
                isShowing: $showGlassToast,
                message: toastMessage
            )
            .onAppear {
                // Show onboarding for new users
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                RefinedOnboardingView {
                    hasCompletedOnboarding = true
                    showOnboarding = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToBook"))) { notification in
                if notification.object is Book {
                    selectedTab = 0  // Switch to library tab
                    // TODO: Implement scrolling to specific book in LibraryView
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToNote"))) { notification in
                if notification.object is Note {
                    selectedTab = 1  // Switch to notes tab
                    // NotesView will handle the scrolling and editing
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToTab"))) { notification in
                if let tabIndex = notification.object as? Int {
                    selectedTab = tabIndex
                    // Also update navigation coordinator
                    switch tabIndex {
                    case 0: navigationCoordinator.selectedTab = .library
                    case 1: navigationCoordinator.selectedTab = .notes
                    case 2: navigationCoordinator.selectedTab = .chat
                    default: break
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowBookScanner"))) { _ in
                showBookScanner = true
                showCommandInput = false
                showingLibraryCommandPalette = false
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowBookSearch"))) { notification in
                if let query = notification.object as? String {
                    print("📚 Received ShowBookSearch with query: '\(query)'")
                    bookSearchQuery = query
                    pendingBookSearch = true  // Mark as pending
                    
                    // Dismiss command input with animation
                    withAnimation(DesignSystem.Animation.springStandard) {
                        showCommandInput = false
                        showingLibraryCommandPalette = false
                    }
                    commandText = ""
                    isInputFocused = false
                    
                    // Use onChange to trigger sheet after state settles
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        if pendingBookSearch && !bookSearchQuery.isEmpty {
                            print("📚 Opening sheet with query: '\(bookSearchQuery)'")
                            pendingBookSearch = false
                            showBookSearch = true
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowBatchBookSearch"))) { notification in
                if let titles = notification.object as? [String], !titles.isEmpty {
                    // Start batch processing
                    batchBookTitles = titles
                    currentBatchIndex = 0
                    
                    // Show toast for batch operation
                    toastMessage = "Adding \(titles.count) books to library..."
                    showGlassToast = true
                    
                    // Show the batch search sheet
                    showBatchBookSearch = true
                    
                    // Dismiss command input if it's open
                    showCommandInput = false
                    commandText = ""
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowCommandInput"))) { _ in
                showCommandInput = true
                HapticManager.shared.commandPaletteOpen()
                // Focus the input immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowGlassToast"))) { notification in
                if let info = notification.object as? [String: Any],
                   let message = info["message"] as? String {
                    toastMessage = message
                    showGlassToast = true
                }
            }
            .simplifiedAmbientPresentation()  // Only use simplified ambient mode
            .environmentObject(libraryViewModel)
            .environmentObject(notesViewModel)
            .onAppear {
                // Defer cache cleaning to background after launch
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    ResponseCache.shared.cleanExpiredEntries()
                }
                
                // Prepare only essential haptic generators
                SensoryFeedback.light() // Prepare the most used one
            }
    }
    
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Background
            DesignSystem.Colors.surfaceBackground
                .ignoresSafeArea()
            
            // Native TabView with automatic blur - DO NOT MODIFY
            TabView(selection: $selectedTab) {
                NavigationStack {
                    LibraryView()
                }
                .tabItem {
                    Label {
                        Text("Library")
                    } icon: {
                        Image("glass-book-open")
                            .renderingMode(.original)
                    }
                }
                .tag(0)
                
                NavigationStack {
                    CleanNotesView()
                }
                .tabItem {
                    Label {
                        Text("Notes")
                    } icon: {
                        Image("glass-feather")
                            .renderingMode(.original)
                    }
                }
                .tag(1)
                
                ChatViewWrapper()
                .tabItem {
                    Label {
                        Text("Chat")
                    } icon: {
                        Image("glass-msgs")
                            .renderingMode(.original)
                    }
                }
                .tag(2)
            }
            .tint(DesignSystem.Colors.primaryAccent)
            .environmentObject(libraryViewModel)
            .environmentObject(notesViewModel)
            .environmentObject(navigationCoordinator)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .toolbar {
                // Privacy settings button (only on Library tab)
                if selectedTab == 0 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showPrivacySettings = true
                        } label: {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 18))
                                .foregroundStyle(DesignSystem.Colors.primaryAccent)
                        }
                        .sensoryFeedback(.impact(flexibility: .soft), trigger: showPrivacySettings)
                    }
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // No need for manual haptic feedback - sensoryFeedback handles it
                
                // Sync with navigation coordinator
                switch newValue {
                case 0: navigationCoordinator.selectedTab = .library
                case 1: navigationCoordinator.selectedTab = .notes
                case 2: navigationCoordinator.selectedTab = .chat
                default: break
                }
            }
            .onChange(of: navigationCoordinator.selectedTab) { oldValue, newValue in
                // Sync from navigation coordinator
                switch newValue {
                case .library: selectedTab = 0
                case .notes: selectedTab = 1
                case .chat: selectedTab = 2
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Enhanced Quick Actions Bar with advanced gestures
                if !showCommandInput && !notesViewModel.isEditingNote {
                    EnhancedQuickActionsBar()
                        .environmentObject(libraryViewModel)
                        .environmentObject(notesViewModel)
                        .padding(.bottom, 56) // 4-6px above tab bar
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
            }
            
        }
        .fullScreenCover(isPresented: $ambientCoordinator.isActive) {
            // Use the NEW AmbientModeView with beautiful chat interface
            AmbientModeView()
                .environmentObject(libraryViewModel)
                .environmentObject(notesViewModel)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .interactiveDismissDisabled()
                .onAppear {
                    print("🎨 AMBIENT MODE: Beautiful gradient experience launched!")
                }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Haptic feedback on tab change
            SensoryFeedback.selection()
            
            // Sync with navigation coordinator
            switch newValue {
            case 0: navigationCoordinator.selectedTab = .library
            case 1: navigationCoordinator.selectedTab = .notes
            case 2: navigationCoordinator.selectedTab = .chat
            default: break
            }
        }
        .onChange(of: navigationCoordinator.selectedTab) { oldValue, newValue in
            // Sync from navigation coordinator
            switch newValue {
            case .library: selectedTab = 0
            case .notes: selectedTab = 1
            case .chat: selectedTab = 2
            }
        }
    }
    
    @ViewBuilder
    private var commandInputOverlay: some View {
        if showCommandInput {
            ZStack(alignment: .bottom) {
                // Invisible tap catcher - no visual backdrop
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss on any tap outside
                        isInputFocused = false
                        commandText = ""
                        showingLibraryCommandPalette = false
                        withAnimation(SmoothAnimationType.smooth.animation) {
                            showCommandInput = false
                        }
                    }
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Command palette (if showing)
                    if showingLibraryCommandPalette {
                        LibraryCommandPalette(
                            isPresented: $showingLibraryCommandPalette,
                            commandText: $commandText
                        )
                        .environmentObject(libraryViewModel)
                        .environmentObject(notesViewModel)
                        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                        .padding(.bottom, 16) // Above input bar
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98, anchor: .bottom).combined(with: .opacity),
                            removal: .scale(scale: 0.98, anchor: .bottom).combined(with: .opacity)
                        ))
                        .zIndex(100)
                        .onDisappear {
                            // Ensure quick actions reappear when command palette is dismissed
                            showCommandInput = false
                        }
                    }
                    
                    // Input bar
                    UniversalInputBar(
                        messageText: $commandText,
                        showingCommandPalette: .constant(false),
                        isInputFocused: $isInputFocused,
                        context: .quickActions,
                        onSend: {
                            processInlineCommand()
                        },
                        onMicrophoneTap: {
                            // Handle voice input if needed
                        },
                        onCommandTap: {
                            // Toggle command palette
                            SensoryFeedback.light()
                            withAnimation(DesignSystem.Animation.springStandard) {
                                showingLibraryCommandPalette.toggle()
                            }
                        },
                        isRecording: .constant(false),
                        colorPalette: nil
                    )
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.bottom, 16) // Above tab bar
                }
            }
            .interruptibleAnimation(.smooth, value: showingLibraryCommandPalette)
            .onAppear {
                // Immediately focus the input field
                isInputFocused = true
            }
        }
    }
    
    private func processInlineCommand() {
        let trimmedText = commandText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else {
            dismissCommandInput()
            return
        }
        
        // Check if this is a book search command (don't dismiss if it is)
        let intent = CommandParser.parse(trimmedText, books: libraryViewModel.books, notes: notesViewModel.notes)
        let isBookSearch = if case .searchLibrary = intent { true } else { false }
        
        // Create and use command processor
        let processor = CommandProcessingManager(
            modelContext: modelContext,
            libraryViewModel: libraryViewModel,
            notesViewModel: notesViewModel
        )
        processor.processInlineCommand(trimmedText)
        
        // Provide haptic feedback
        SensoryFeedback.success()
        
        // Only dismiss if not a book search (book search will dismiss after sheet shows)
        if !isBookSearch {
            dismissCommandInput()
        } else {
            // For book search, just clear the text but keep the overlay
            // It will be dismissed when the sheet appears
            commandText = ""
            isInputFocused = false
        }
    }
    
    private func dismissCommandInput() {
        isInputFocused = false
        commandText = ""
    }
    
    private func processNextBatchBook() {
        guard !batchBookTitles.isEmpty else {
            // Batch complete
            currentBatchIndex = 0
            return
        }
        
        let nextTitle = batchBookTitles.removeFirst()
        
        // Add a small delay between searches to prevent UI issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            bookSearchQuery = nextTitle
            showBookSearch = true
        }
        withAnimation(SmoothAnimationType.smooth.animation) {
            showCommandInput = false
        }
    }
    
    // MARK: - Helper Functions
    // Note: Command processing logic moved to CommandProcessingManager
}

#Preview {
    ContentView()
}