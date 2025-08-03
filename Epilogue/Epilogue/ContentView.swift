import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @State private var selectedTab = 0
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @State private var showCommandPalette = false
    @State private var showCommandInput = false
    @State private var commandText = ""
    @FocusState private var isInputFocused: Bool
    @State private var selectedDetent: PresentationDetent = .height(300)
    @Namespace private var animation
    @State private var showPrivacySettings = false
    @State private var showAdvancedActions = false
    @State private var quickActionScale: CGFloat = 1.0
    @State private var isLongPressing = false
    @State private var showBookScanner = false
    @StateObject private var bookScanner = BookScannerService.shared
    @State private var showVoiceRecording = false
    @State private var showNoQuotesToast = false
    @State private var showLiquidCommandPalette = false
    @State private var showingLibraryCommandPalette = false
    
    // Command processing
    @Environment(\.modelContext) private var modelContext
    @Query private var capturedNotes: [CapturedNote]
    @Query private var capturedQuotes: [CapturedQuote]
    
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
                advancedActionsOverlay
            }
            .overlay(alignment: .bottom) {
                commandInputOverlay
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCommandInput)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAdvancedActions)
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
                        HapticManager.shared.success()
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
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowLiquidCommandPalette"))) { _ in
                showingLibraryCommandPalette = false
                showLiquidCommandPalette = true
            }
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
                // Quick Add button positioned right above tab bar
                if selectedTab != 2 && !showCommandInput && !notesViewModel.isEditingNote {
                    // Quick Actions button
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                        Text("Quick Actions")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .scaleEffect(isLongPressing ? 0.95 : 1.0)
                    .glassEffect(in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    }
                    .matchedGeometryEffect(id: "quickActionsButton", in: animation)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                showCommandInput = true
                            }
                    )
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: showCommandInput)
                    .onLongPressGesture(
                        minimumDuration: 0.6,
                        maximumDistance: .infinity,
                        pressing: { pressing in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isLongPressing = pressing
                            }
                            if pressing {
                                print("🟡 Long press started")
                            }
                        },
                        perform: {
                            print("🔵 Long press detected! showAdvancedActions = true")
                            HapticManager.shared.mediumTap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showAdvancedActions = true
                            }
                        }
                    )
                    .padding(.bottom, 56) // 4-6px above tab bar
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
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
    private var advancedActionsOverlay: some View {
        if showAdvancedActions {
            ZStack {
                // Dark background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showAdvancedActions = false
                        }
                    }
                
                VStack {
                    Spacer()
                    AdvancedActionsMenu(
                        showAdvancedActions: $showAdvancedActions,
                        showBookScanner: $showBookScanner,
                        notesViewModel: notesViewModel
                    )
                    .padding(.bottom, 180) // Position above Quick Actions button
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity)
                    ))
                    .onAppear {
                        print("🟢 AdvancedActionsMenu appeared!")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var commandInputOverlay: some View {
        if showCommandInput {
            ZStack(alignment: .bottom) {
                // Backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if showingLibraryCommandPalette {
                            showingLibraryCommandPalette = false
                        } else {
                            isInputFocused = false
                            commandText = ""
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showCommandInput = false
                            }
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
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingLibraryCommandPalette)
            .onAppear {
                // Auto-focus the input field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
    }
    
    private func processInlineCommand() {
        let trimmedText = commandText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else {
            dismissCommandInput()
            return
        }
        
        // Parse the command
        let intent = CommandParser.parse(trimmedText, books: libraryViewModel.books, notes: [])
        
        switch intent {
        case .createQuote(let text):
            HapticManager.shared.success()
            createQuote(from: text)
            dismissCommandInput()
            
        case .createNote(let text):
            HapticManager.shared.success()
            createNote(from: text)
            dismissCommandInput()
            
        case .addBook(_):
            HapticManager.shared.lightTap()
            dismissCommandInput()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedTab = 0
            }
            
        case .searchLibrary(_), .searchAll(_):
            HapticManager.shared.lightTap()
            dismissCommandInput()
            selectedTab = 0
            
        case .searchNotes(_):
            HapticManager.shared.lightTap()
            dismissCommandInput()
            selectedTab = 1
            
        case .existingBook(let book):
            HapticManager.shared.selectionChanged()
            dismissCommandInput()
            selectedTab = 0
            navigationCoordinator.navigateToBook(book.id)
            
        case .existingNote(let note):
            HapticManager.shared.selectionChanged()
            dismissCommandInput()
            selectedTab = 1
            navigationCoordinator.highlightedNoteID = note.id
            
        case .unknown:
            HapticManager.shared.lightTap()
            dismissCommandInput()
            selectedTab = 0
        }
    }
    
    private func dismissCommandInput() {
        isInputFocused = false
        commandText = ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCommandInput = false
        }
    }
    
    // MARK: - Helper Functions
    
    private func createQuote(from text: String) {
        let parsedQuote = CommandParser.parseQuote(text)
        var author: String? = nil
        var bookTitle: String? = nil
        var pageNumber: Int? = nil
        
        // Parse the format: author|||BOOK|||bookTitle|||PAGE|||pageNumber
        if let authorString = parsedQuote.author {
            let parts = authorString.split(separator: "|||").map(String.init)
            var idx = 0
            
            if idx < parts.count {
                author = parts[idx]
                idx += 1
            }
            
            while idx < parts.count - 1 {
                if parts[idx] == "BOOK" && idx + 1 < parts.count {
                    bookTitle = parts[idx + 1]
                    idx += 2
                } else if parts[idx] == "PAGE" && idx + 1 < parts.count {
                    pageNumber = Int(parts[idx + 1])
                    idx += 2
                } else {
                    idx += 1
                }
            }
        }
        
        // Find book if title is provided
        var bookModel: BookModel? = nil
        if let bookTitle = bookTitle {
            let book = libraryViewModel.books.first { $0.title.localizedCaseInsensitiveContains(bookTitle) }
            if let book = book {
                // Convert Book to BookModel
                bookModel = BookModel(from: book)
            }
        }
        
        // Create the quote
        let capturedQuote = CapturedQuote(
            text: parsedQuote.content,
            book: bookModel,
            pageNumber: pageNumber
        )
        
        // Set attribution
        if let author = author {
            capturedQuote.author = author
        }
        
        modelContext.insert(capturedQuote)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving quote: \(error)")
        }
    }
    
    private func createNote(from text: String) {
        let capturedNote = CapturedNote(content: text, book: nil)
        modelContext.insert(capturedNote)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving note: \(error)")
        }
    }
}

// MARK: - Advanced Actions Menu

struct AdvancedActionsMenu: View {
    @Binding var showAdvancedActions: Bool
    @Binding var showBookScanner: Bool
    let notesViewModel: NotesViewModel
    
    @State private var actionOpacities: [Double] = [0, 0, 0]
    @State private var actionScales: [CGFloat] = [0.8, 0.8, 0.8]
    
    var body: some View {
        HStack(spacing: 12) {
            // Book Scan - Featured Action
            AdvancedActionButton(
                icon: "camera.viewfinder",
                label: "Scan Book",
                color: Color(red: 1.0, green: 0.55, blue: 0.26),
                isFeatured: true,
                action: {
                    HapticManager.shared.mediumTap()
                    showBookScanner = true
                    showAdvancedActions = false
                }
            )
            .opacity(actionOpacities[0])
            .scaleEffect(actionScales[0])
            
            // Voice Note
            AdvancedActionButton(
                icon: "waveform",
                label: "Voice Note",
                color: .white.opacity(0.9),
                action: {
                    HapticManager.shared.lightTap()
                    // Start voice recording
                    NotificationCenter.default.post(name: Notification.Name("StartVoiceNote"), object: nil)
                    showAdvancedActions = false
                }
            )
            .opacity(actionOpacities[1])
            .scaleEffect(actionScales[1])
            
            // Share Last Quote
            AdvancedActionButton(
                icon: "square.and.arrow.up",
                label: "Share Quote",
                color: .white.opacity(0.9),
                action: {
                    HapticManager.shared.lightTap()
                    // Share most recent quote
                    let quotes = notesViewModel.notes.filter { $0.type == .quote }
                    if let lastQuote = quotes.last {
                        NotificationCenter.default.post(
                            name: Notification.Name("ShareQuote"),
                            object: lastQuote
                        )
                    } else {
                        // No quotes to share
                        NotificationCenter.default.post(
                            name: Notification.Name("ShowNoQuotesToast"),
                            object: nil
                        )
                    }
                    showAdvancedActions = false
                }
            )
            .opacity(actionOpacities[2])
            .scaleEffect(actionScales[2])
        }
        .padding(.horizontal, 16)
        .onAppear {
            // Staggered animations
            for i in 0..<3 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(i) * 0.05)) {
                    actionOpacities[i] = 1.0
                    actionScales[i] = 1.0
                }
            }
        }
    }
}

struct AdvancedActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var isFeatured: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: isFeatured ? 24 : 20, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background {
                        if isFeatured {
                            // Featured glow effect
                            Circle()
                                .fill(color.opacity(0.15))
                                .blur(radius: 8)
                                .scaleEffect(1.5)
                        }
                    }
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isFeatured ? color.opacity(0.3) : Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(
                color: isFeatured ? color.opacity(0.2) : .black.opacity(0.1),
                radius: isFeatured ? 12 : 8,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

#Preview {
    ContentView()
}