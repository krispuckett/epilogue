import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @StateObject private var ambientCoordinator = EpilogueAmbientCoordinator.shared
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @AppStorage("useNewAmbientMode") private var useNewAmbient = true // Set to false to use old implementation
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
    
    // Command processing
    @Environment(\.modelContext) private var modelContext
    @Query private var capturedNotes: [CapturedNote]
    @Query private var capturedQuotes: [CapturedQuote]
    
    // Command processing manager
    private var commandProcessor: CommandProcessingManager {
        CommandProcessingManager(
            modelContext: modelContext,
            libraryViewModel: libraryViewModel,
            notesViewModel: notesViewModel
        )
    }
    
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
            .sheet(isPresented: $showPrivacySettings) {
                NavigationView {
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
                HapticManager.shared.warning()
            }
            .glassToast(
                isShowing: $showNoQuotesToast,
                message: "No quotes to share yet"
            )
            .glassToast(
                isShowing: $showGlassToast,
                message: toastMessage
            )
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
                HapticManager.shared.lightTap() // Prepare the most used one
            }
    }
    
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(red: 0.11, green: 0.105, blue: 0.102)
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
                            .renderingMode(.template)
                    }
                }
                .tag(0)
                
                NavigationStack {
                    SwiftDataNotesView()
                }
                .tabItem {
                    Label {
                        Text("Notes")
                    } icon: {
                        Image("glass-feather")
                            .renderingMode(.template)
                    }
                }
                .tag(1)
                
                ChatViewWrapper()
                .tabItem {
                    Label {
                        Text("Chat")
                    } icon: {
                        Image("glass-msgs")
                            .renderingMode(.template)
                    }
                }
                .tag(2)
            }
            .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
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
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
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
                if selectedTab != 2 && !showCommandInput && !notesViewModel.isEditingNote {
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
            // Use UnifiedChatView in ambient mode for beautiful gradient interface
            UnifiedChatView(
                preSelectedBook: ambientCoordinator.preSelectedBook,
                startInVoiceMode: true,
                isAmbientMode: true
            )
            .environmentObject(libraryViewModel)
            .environmentObject(notesViewModel)
            .interactiveDismissDisabled()
            .onAppear {
                print("🎨 UNIFIED CHAT: Beautiful gradient ambient mode launched!")
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Haptic feedback on tab change
            HapticManager.shared.selectionChanged()
            
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
                        .padding(.horizontal, 16)
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
                            HapticManager.shared.lightTap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingLibraryCommandPalette.toggle()
                            }
                        },
                        isRecording: .constant(false),
                        colorPalette: nil
                    )
                    .padding(.horizontal, 16)
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
        
        // Delegate to command processor
        commandProcessor.processInlineCommand(trimmedText)
        
        // Provide haptic feedback and dismiss
        HapticManager.shared.success()
        dismissCommandInput()
    }
    
    private func dismissCommandInput() {
        isInputFocused = false
        commandText = ""
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