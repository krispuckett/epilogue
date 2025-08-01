import SwiftUI
import SwiftData

// MARK: - Main Component
struct LiquidCommandPalette: View {
    // MARK: - State Properties (Minimal)
    @Binding var isPresented: Bool
    @State private var commandText = ""
    @State private var showQuickActions = false
    @State private var showBookSearch = false
    @State private var bookSearchQuery = ""
    @State private var shouldShowSearchResults = false
    @FocusState private var isFocused: Bool
    
    // MARK: - Environment
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @Environment(\.modelContext) private var modelContext
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
        // Implement voice recognition functionality here
        // This can integrate with existing voice manager if needed
    }
    
    private func handleQuickAction(_ action: String) {
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
        ZStack {
            // Show Universal Input Bar overlay when presented
            if isPresented {
                ZStack {
                    // Backdrop
                    Color.black.opacity(0.3)
                        .onTapGesture {
                            if showQuickActions {
                                showQuickActions = false
                            } else {
                                dismissPalette()
                            }
                        }
                        .ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
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
                            .transition(AnyTransition.asymmetric(
                                insertion: AnyTransition.move(edge: .bottom).combined(with: .opacity),
                                removal: AnyTransition.move(edge: .top).combined(with: .opacity)
                            ))
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
                            .padding(.bottom, 120) // Above input bar
                            .transition(AnyTransition.asymmetric(
                                insertion: AnyTransition.scale(scale: 0.98, anchor: .bottom).combined(with: .opacity),
                                removal: AnyTransition.scale(scale: 0.98, anchor: .bottom).combined(with: .opacity)
                            ))
                        }
                        
                        // Universal Input Bar
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showQuickActions.toggle()
                                }
                            },
                            isRecording: .constant(false),
                            colorPalette: nil
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
                .onAppear {
                    // Setup initial content if provided
                    if let initial = initialContent {
                        commandText = initial
                    }
                    isFocused = true
                }
            }
        }
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(
                searchQuery: bookSearchQuery,
                onBookSelected: { book in
                    // Add the book to library
                    libraryViewModel.addBook(book)
                    HapticManager.shared.success()
                    
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
            HapticManager.shared.success()
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToBook"),
                object: book
            )
            dismissPalette()
        case .existingNote(let note):
            HapticManager.shared.success()
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
        
        HapticManager.shared.success()
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
            modelContext.insert(bookModel!)
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
        
        HapticManager.shared.success()
        
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
            modelContext.insert(bookModel!)
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
        
        HapticManager.shared.success()
        
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
        HapticManager.shared.success()
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
        HapticManager.shared.success()
        dismissPalette()
    }
    
    private func dismissPalette() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}
