import SwiftUI
import SwiftData

// MARK: - Main Component
struct LiquidCommandPalette: View {
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var transitionCoordinator = PaletteTransitionCoordinator()
    
    // MARK: - State Properties (Minimal)
    @Binding var isPresented: Bool
    @State private var commandText = ""
    @State private var showQuickActions = false
    @State private var showBookSearch = false
    @State private var bookSearchQuery = ""
    @State private var shouldShowSearchResults = false
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var contentOffset: CGFloat = 0
    
    // MARK: - Environment
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var capturedNotes: [CapturedNote]
    @Query private var capturedQuotes: [CapturedQuote]
    
    // Animation namespace
    var animationNamespace: Namespace.ID
    
    // Optional initial content
    let initialContent: String?
    let editingNote: Note?
    let onUpdate: ((Note) -> Void)?
    let bookContext: Book?
    
    init(isPresented: Binding<Bool>, animationNamespace: Namespace.ID, initialContent: String? = nil, editingNote: Note? = nil, onUpdate: ((Note) -> Void)? = nil, bookContext: Book? = nil) {
        self._isPresented = isPresented
        self.animationNamespace = animationNamespace
        self.initialContent = initialContent
        self.editingNote = editingNote
        self.onUpdate = onUpdate
        self.bookContext = bookContext
    }
    
    // MARK: - Helper Methods
    private func determineContext() -> InputContext {
        if let book = bookContext {
            return .bookDetail(book: book)
        }
        return .quickActions
    }
    
    private func handleMicrophoneTap() {
        if voiceManager.isListening {
            voiceManager.stopListening()
        } else {
            voiceManager.startAmbientListening()
        }
    }
    
    private func handleQuickAction(_ action: String) {
        // Light haptic feedback when command is selected
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        switch action {
        case "note":
            commandText = "note: "
            isFocused = true
        case "quote":
            commandText = "\""
            isFocused = true
        case "addBook":
            commandText = ""
            isFocused = true
        case "search":
            commandText = ""
            isFocused = true
        default:
            break
        }
        showQuickActions = false
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Backdrop with coordinated animation
                Color.black
                    .opacity(transitionCoordinator.backdropOpacity)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if showQuickActions {
                            transitionCoordinator.handleContentChange()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showQuickActions = false
                            }
                        } else {
                            dismissPalette()
                        }
                    }
                
                // Main content container with proper safe area handling
                VStack(spacing: 0) {
                    // Invisible spacer for top safe area + additional padding
                    Color.clear
                        .frame(height: max(geometry.safeAreaInsets.top + 44, 88))
                    
                    Spacer()
                    
                    // Content area
                    VStack(spacing: 0) {
                        // Show search results (including recent commands when empty)
                        if !showQuickActions && (commandText.count >= 3 || commandText.isEmpty) {
                            ScrollView {
                                LiquidSearchResultsView(searchText: commandText)
                                    .environmentObject(libraryViewModel)
                                    .environmentObject(notesViewModel)
                            }
                            .frame(maxHeight: 300)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8) // 8px above input bar
                            .transition(.smoothSlide)
                        }
                        
                        // Show command palette if active
                        if showQuickActions {
                            QuickActionsSheet(
                                isPresented: $showQuickActions,
                                onActionSelected: { action in
                                    handleQuickAction(action)
                                }
                            )
                            .environmentObject(libraryViewModel)
                            .environmentObject(notesViewModel)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16) // Above input bar
                            .transition(.glassAppear)
                        }
                        
                        // Universal Input Bar with matched geometry
                        UniversalInputBar(
                            messageText: $commandText,
                            showingCommandPalette: .constant(false),
                            isInputFocused: $isFocused,
                            context: determineContext(),
                            onSend: {
                                processCommand(commandText)
                            },
                            onMicrophoneTap: handleMicrophoneTap,
                            onCommandTap: {
                                withAnimation(SmoothAnimationType.bouncy.animation) {
                                    showQuickActions.toggle()
                                }
                            },
                            isRecording: .constant(voiceManager.isListening),
                            colorPalette: nil
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, max(16, geometry.safeAreaInsets.bottom + 8))
                        .matchedGeometryEffect(id: "inputBar", in: animationNamespace)
                    }
                    .offset(y: contentOffset)
                }
                .paletteTransition(transitionCoordinator)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .presentationBackground(.clear)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(0)
        .interactiveDismissDisabled(showQuickActions || transitionCoordinator.state == .appearing || transitionCoordinator.state == .dismissing)
        .onAppear {
            // Start the show transition
            transitionCoordinator.show()
            
            // Setup initial content if provided
            if let initial = initialContent {
                commandText = initial
            }
            
            // Coordinate keyboard with palette appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isFocused = true
            }
            
            // Subscribe to keyboard notifications
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                withAnimation(.easeOut(duration: 0.25)) {
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
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
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(
                searchQuery: bookSearchQuery,
                onBookSelected: { book in
                    // Add the book to library
                    libraryViewModel.addBook(book)
                    HapticManager.shared.bookOpen()
                    
                    // Navigate to the newly added book
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToBook"),
                        object: book
                    )
                    
                    // Close sheets
                    showBookSearch = false
                    dismissPalette()
                }
            )
        }
        .onChange(of: voiceManager.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                commandText = newValue
            }
        }
        .onDisappear {
            voiceManager.stopListening()
            // Handle interrupt if palette is being dismissed unexpectedly
            if transitionCoordinator.state != .hidden {
                transitionCoordinator.handleInterrupt()
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue && transitionCoordinator.state != .hidden {
                // External dismiss - coordinate the transition
                transitionCoordinator.dismiss()
            }
        }
        .onChange(of: showQuickActions) { _, _ in
            // Animate content changes
            transitionCoordinator.handleContentChange()
        }
    }
    
    
    
    
    // MARK: - Command Processing
    private func processCommand(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // Use CommandParser to detect intent with advanced NLP
        let intent = CommandParser.parse(trimmed, books: libraryViewModel.books, notes: notesViewModel.notes)
        
        print("🧠 LiquidCommandPalette: Processing command '\(trimmed)' with intent: \(intent)")
        
        // Handle editing note case
        if let editingNote = editingNote, let onUpdate = onUpdate {
            switch intent {
            case .createNote(let noteText):
                updateNote(from: noteText, editingNote: editingNote, onUpdate: onUpdate)
            case .createQuote(let quoteText):
                updateQuote(from: quoteText, editingNote: editingNote, onUpdate: onUpdate)
            default:
                break
            }
            return
        }
        
        // Handle regular commands with natural language understanding
        switch intent {
        case .createNote(let noteText):
            createNote(from: noteText)
        case .createQuote(let quoteText):
            createQuote(from: quoteText)
        case .addBook(let query):
            // Search for book using the query
            searchAndAddBook(query: query)
        case .searchLibrary(let query), .searchNotes(let query), .searchAll(let query):
            // Navigate to search with query
            performSearch(query: query, intent: intent)
        case .existingBook(let book):
            HapticManager.shared.bookOpen()
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToBook"),
                object: book
            )
            dismissPalette()
        case .existingNote(let note):
            HapticManager.shared.lightTap()
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToNote"),
                object: note
            )
            dismissPalette()
        case .unknown:
            // If unknown, try to be helpful based on content
            if trimmed.contains("\"") || trimmed.contains("“") || trimmed.contains("”") {
                // Contains quotes, likely a quote
                createQuote(from: trimmed)
            } else if trimmed.count < 50 && !trimmed.contains(" ") {
                // Short single word might be a book title
                searchAndAddBook(query: trimmed)
            } else if trimmed.count < 100 {
                // Medium length text could be book search
                searchAndAddBook(query: trimmed)
            } else {
                // Long text defaults to note
                createNote(from: trimmed)
            }
        }
    }
    
    // MARK: - Book Search & Add
    private func searchAndAddBook(query: String) {
        print("📚 Searching for book: \(query)")
        
        // Set the search query and show book search sheet
        bookSearchQuery = query
        showBookSearch = true
        
        HapticManager.shared.lightTap()
    }
    
    // MARK: - Search Navigation
    private func performSearch(query: String, intent: CommandIntent) {
        print("🔍 Performing search: \(query) with intent: \(intent)")
        
        // Navigate to appropriate search view
        switch intent {
        case .searchLibrary(_):
            NotificationCenter.default.post(
                name: Notification.Name("SearchLibrary"),
                object: query
            )
        case .searchNotes(_):
            NotificationCenter.default.post(
                name: Notification.Name("SearchNotes"),
                object: query
            )
        case .searchAll(_):
            NotificationCenter.default.post(
                name: Notification.Name("SearchAll"),
                object: query
            )
        default:
            break
        }
        
        // Haptic feedback for note saved
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismissPalette()
    }
    
    // MARK: - Note/Quote Creation Methods
    
    private func createNote(from text: String) {
        let normalizedText = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        
        var content = normalizedText
        
        let prefixes = ["note:", "note -", "note ", "thought:", "idea:", "reminder:", "todo:"]
        for prefix in prefixes {
            if content.lowercased().hasPrefix(prefix) {
                content = String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        content = content.trimmingCharacters(in: .whitespaces)
        
        // Create BookModel if we have book context
        var bookModel: BookModel? = nil
        if let book = bookContext {
            bookModel = BookModel(from: book)
            if let model = bookModel {
                modelContext.insert(model)
            }
        }
        
        // Create and save to SwiftData using CapturedNote
        let capturedNote = CapturedNote(
            content: content,
            book: bookModel,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual
        )
        
        modelContext.insert(capturedNote)
        
        // Also add to NotesViewModel for backward compatibility
        let note = Note(
            type: .note,
            content: content,
            bookId: bookContext?.localId,
            bookTitle: bookContext?.title,
            author: bookContext?.author,
            pageNumber: nil
        )
        notesViewModel.addNote(note)
        
        // Save to SwiftData
        do {
            try modelContext.save()
            print("✅ Note saved to SwiftData: \(content)")
        } catch {
            print("Failed to save note: \(error)")
        }
        
        // Haptic feedback for note saved
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Clear text immediately for better feedback
        commandText = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismissPalette()
        }
    }
    
    private func createQuote(from text: String) {
        let normalizedText = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        
        let (content, attribution) = CommandParser.parseQuote(normalizedText)
        
        var author: String? = nil
        var bookTitle: String? = nil
        var pageNumber: Int? = nil
        
        if let attr = attribution {
            let parts = attr.split(separator: "|||").map { String($0) }
            
            // Parse the format: author|||BOOK|||bookTitle|||PAGE|||pageNumber
            var idx = 0
            if idx < parts.count {
                author = parts[idx]
                idx += 1
            }
            
            // Check for BOOK marker
            if idx < parts.count && parts[idx] == "BOOK" {
                idx += 1
                if idx < parts.count {
                    bookTitle = parts[idx]
                    idx += 1
                }
            }
            
            // Check for PAGE marker
            if idx < parts.count && parts[idx] == "PAGE" {
                idx += 1
                if idx < parts.count {
                    let pageStr = parts[idx].trimmingCharacters(in: .whitespaces)
                    pageNumber = Int(pageStr.replacingOccurrences(of: "p.", with: "")
                        .replacingOccurrences(of: "page", with: "")
                        .replacingOccurrences(of: "pg", with: "")
                        .trimmingCharacters(in: .whitespaces))
                }
            }
        }
        
        // Create BookModel if we have book context
        var bookModel: BookModel? = nil
        if let book = bookContext {
            bookModel = BookModel(from: book)
            if let model = bookModel {
                modelContext.insert(model)
            }
        }
        
        // Create and save to SwiftData using CapturedQuote
        let capturedQuote = CapturedQuote(
            text: content,
            book: bookModel,
            author: author,
            pageNumber: pageNumber,
            timestamp: Date(),
            source: .manual
        )
        
        modelContext.insert(capturedQuote)
        
        // Also add to NotesViewModel for backward compatibility
        // Use the parsed values directly, bookContext info is already in CapturedQuote
        let quote = Note(
            type: .quote,
            content: content,
            bookId: bookContext?.localId,
            bookTitle: bookTitle,
            author: author,
            pageNumber: pageNumber
        )
        notesViewModel.addNote(quote)
        
        // Save to SwiftData
        do {
            try modelContext.save()
            print("✅ Quote saved to SwiftData: \(content)")
        } catch {
            print("Failed to save quote: \(error)")
        }
        
        // Haptic feedback for quote saved
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Clear text immediately for better feedback
        commandText = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismissPalette()
        }
    }
    
    private func updateNote(from text: String, editingNote: Note, onUpdate: @escaping (Note) -> Void) {
        let normalizedText = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        
        var content = normalizedText
        
        let prefixes = ["note:", "note -", "note ", "thought:", "idea:", "reminder:", "todo:"]
        for prefix in prefixes {
            if content.lowercased().hasPrefix(prefix) {
                content = String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        content = content.trimmingCharacters(in: .whitespaces)
        
        let updatedNote = Note(
            type: .note,
            content: content,
            bookId: editingNote.bookId,
            bookTitle: editingNote.bookTitle,
            author: editingNote.author,
            pageNumber: editingNote.pageNumber,
            dateCreated: editingNote.dateCreated,
            id: editingNote.id
        )
        
        onUpdate(updatedNote)
        // Haptic feedback for note saved
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismissPalette()
    }
    
    private func updateQuote(from text: String, editingNote: Note, onUpdate: @escaping (Note) -> Void) {
        let normalizedText = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        
        let (content, attribution) = CommandParser.parseQuote(normalizedText)
        
        var author: String? = nil
        var bookTitle: String? = nil
        var pageNumber: Int? = nil
        
        if let attr = attribution {
            let parts = attr.split(separator: "|||").map { String($0) }
            if parts.count >= 1 {
                author = parts[0]
            }
            if parts.count >= 2 {
                bookTitle = parts[1]
            }
            if parts.count >= 3 {
                let pageStr = parts[2].trimmingCharacters(in: .whitespaces)
                pageNumber = Int(pageStr.replacingOccurrences(of: "p.", with: "")
                    .replacingOccurrences(of: "page", with: "")
                    .replacingOccurrences(of: "pg", with: "")
                    .trimmingCharacters(in: .whitespaces))
            }
        }
        
        let updatedQuote = Note(
            type: .quote,
            content: content,
            bookId: editingNote.bookId,
            bookTitle: bookTitle ?? editingNote.bookTitle,
            author: author ?? editingNote.author,
            pageNumber: pageNumber ?? editingNote.pageNumber,
            dateCreated: editingNote.dateCreated,
            id: editingNote.id
        )
        
        onUpdate(updatedQuote)
        // Haptic feedback for note saved
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismissPalette()
    }
    
    private func dismissPalette() {
        // Use transition coordinator for coordinated dismiss
        transitionCoordinator.dismiss {
            isPresented = false
            isFocused = false
        }
    }
}

// MARK: - Presentation Wrapper
struct LiquidCommandPalettePresentation: View {
    @Binding var isPresented: Bool
    let animationNamespace: Namespace.ID
    let initialContent: String?
    let editingNote: Note?
    let onUpdate: ((Note) -> Void)?
    let bookContext: Book?
    @State private var showSheet = false
    
    var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented) {
                LiquidCommandPalette(
                    isPresented: $isPresented,
                    animationNamespace: animationNamespace,
                    initialContent: initialContent,
                    editingNote: editingNote,
                    onUpdate: onUpdate,
                    bookContext: bookContext
                )
                .presentationBackground(.ultraThinMaterial)
                .presentationBackgroundInteraction(.enabled)
                .presentationContentInteraction(.scrolls)
            }
    }
}
