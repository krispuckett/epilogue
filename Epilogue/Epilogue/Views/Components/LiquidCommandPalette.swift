import SwiftUI
import SwiftData

// MARK: - Main Component
struct LiquidCommandPalette: View {
    // MARK: - State Properties (Minimal)
    @Binding var isPresented: Bool
    @State private var commandText = ""
    @State private var detectedIntent: CommandIntent = .unknown
    @FocusState private var isFocused: Bool
    @State private var showQuickActions = false
    @State private var showBookSearch = false
    @State private var showBookScanner = false
    @State private var isListening = false
    @StateObject private var voiceManager = VoiceRecognitionManager()
    
    // MARK: - Environment
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @Environment(\.modelContext) private var modelContext
    
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
    
    // MARK: - Quick Action Definition
    struct QuickAction {
        let icon: String
        let title: String
        let description: String
        let action: () -> Void
    }
    
    // MARK: - Computed Properties
    private var quickActions: [QuickAction] {
        [
            QuickAction(
                icon: "note.text",
                title: "New Note",
                description: "Add a quick thought",
                action: {
                    commandText = "note: "
                    showQuickActions = false
                    isFocused = true
                }
            ),
            QuickAction(
                icon: "quote.opening",
                title: "New Quote",
                description: "Save a memorable quote",
                action: {
                    commandText = "\""
                    showQuickActions = false
                    isFocused = true
                }
            ),
            QuickAction(
                icon: "book",
                title: "Add Book",
                description: "Add to your library",
                action: {
                    commandText = "add book "
                    showQuickActions = false
                    isFocused = true
                }
            ),
            QuickAction(
                icon: "barcode.viewfinder",
                title: "Scan Book Cover",
                description: "Scan ISBN or cover",
                action: {
                    showQuickActions = false
                    showBookScanner = true
                }
            ),
            QuickAction(
                icon: "magnifyingglass",
                title: "Search",
                description: "Find in your library",
                action: {
                    commandText = "search "
                    showQuickActions = false
                    isFocused = true
                }
            )
        ]
    }
    
    private var currentGlowColor: Color {
        detectedIntent.color
    }
    
    private var placeholderText: String {
        if isListening {
            return "Listening..."
        }
        
        if editingNote != nil {
            return "Edit your note..."
        }
        
        switch detectedIntent {
        case .addBook:
            return "Adding new book..."
        case .createQuote:
            return "Creating quote..."
        case .createNote:
            return "Creating note..."
        case .searchLibrary, .existingBook:
            return "Found in your library"
        case .searchNotes, .existingNote:
            return "Searching notes..."
        case .searchAll:
            return "Searching everything..."
        case .unknown:
            return "What's on your mind?"
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Invisible backdrop
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissPalette()
                }
            
            VStack {
                Spacer()
                
                // Main input bar
                inputBarView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            
            // Quick actions modal
            if showQuickActions {
                quickActionsModal
            }
        }
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            cleanup()
        }
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(
                searchQuery: {
                    if case .addBook(let query) = detectedIntent {
                        return query
                    }
                    return commandText
                }(),
                onBookSelected: { book in
                    libraryViewModel.addBook(book)
                    HapticManager.shared.success()
                    dismissPalette()
                }
            )
        }
        .fullScreenCover(isPresented: $showBookScanner) {
            BookScannerView()
                .environmentObject(libraryViewModel)
        }
    }
    
    // MARK: - View Components
    
    private var inputBarView: some View {
        HStack(spacing: 8) {
            // Plus button
            Button {
                HapticManager.shared.lightTap()
                withAnimation(.easeInOut(duration: 0.2)) {
                    showQuickActions.toggle()
                }
            } label: {
                Image(systemName: showQuickActions ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(showQuickActions ? currentGlowColor.opacity(0.2) : Color.white.opacity(0.1)), in: Circle())
            }
            
            // Input field container
            HStack(spacing: 0) {
                // Dynamic icon
                Image(systemName: iconForIntent(detectedIntent))
                    .foregroundStyle(currentGlowColor)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 36)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                
                // Text field
                ZStack(alignment: .leading) {
                    if commandText.isEmpty {
                        Text(placeholderText)
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 16))
                            .lineLimit(1)
                    }
                    
                    TextField("", text: $commandText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .focused($isFocused)
                        .lineLimit(1...5)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.done)
                        .onChange(of: commandText) { _, newValue in
                            handleTextChange(newValue)
                        }
                        .onSubmit {
                            executeCommand()
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                
                // Action buttons
                HStack(spacing: 8) {
                    // Voice button
                    Button {
                        if isListening {
                            stopListening()
                        } else {
                            startListening()
                        }
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isListening ? currentGlowColor : currentGlowColor.opacity(0.7))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    
                    // Send button
                    if !commandText.isEmpty && detectedIntent != .unknown {
                        Button(action: executeCommand) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white, currentGlowColor)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.trailing, 12)
            }
            .frame(minHeight: 36)
            .glassEffect(.regular.tint(currentGlowColor.opacity(0.15)), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                currentGlowColor.opacity(0.3),
                                currentGlowColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        }
    }
    
    private var quickActionsModal: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showQuickActions = false
                    }
                }
            
            // Modal content
            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                
                // Actions list
                VStack(spacing: 8) {
                    ForEach(quickActions, id: \.title) { action in
                        quickActionRow(action)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 100) // Space for input bar
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func quickActionRow(_ action: QuickAction) -> some View {
        Button {
            HapticManager.shared.lightTap()
            action.action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: action.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Text(action.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        if let initialContent = initialContent {
            commandText = initialContent
            detectedIntent = CommandParser.parse(initialContent, books: libraryViewModel.books, notes: notesViewModel.notes)
        }
        isFocused = true
    }
    
    private func cleanup() {
        isFocused = false
        showQuickActions = false
        if isListening {
            voiceManager.stopListening()
            isListening = false
        }
    }
    
    private func handleTextChange(_ newValue: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            detectedIntent = CommandParser.parse(newValue, books: libraryViewModel.books, notes: notesViewModel.notes)
        }
    }
    
    private func iconForIntent(_ intent: CommandIntent) -> String {
        switch intent {
        case .addBook:
            return "book.badge.plus.fill"
        case .createNote:
            return "plus"
        case .createQuote:
            return "quote.opening"
        case .searchLibrary, .searchAll, .searchNotes:
            return "magnifyingglass"
        case .existingBook:
            return "book.fill"
        case .existingNote:
            return "note.text"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    private func dismissPalette() {
        isFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isPresented = false
        }
    }
    
    private func executeCommand() {
        guard detectedIntent != .unknown else { return }
        
        HapticManager.shared.mediumTap()
        
        if let editingNote = editingNote, let onUpdate = onUpdate {
            switch detectedIntent {
            case .createNote(let text):
                updateNote(from: text, editingNote: editingNote, onUpdate: onUpdate)
            case .createQuote(let text):
                updateQuote(from: text, editingNote: editingNote, onUpdate: onUpdate)
            default:
                break
            }
            return
        }
        
        switch detectedIntent {
        case .createNote(let text):
            createNote(from: text)
        case .createQuote(let text):
            createQuote(from: text)
        case .addBook(_):
            showBookSearch = true
        case .searchLibrary(_), .searchNotes(_), .searchAll(_):
            HapticManager.shared.success()
            dismissPalette()
        case .existingBook(let book):
            HapticManager.shared.success()
            dismissPalette()
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToBook"),
                    object: book
                )
            }
        case .existingNote(let note):
            HapticManager.shared.success()
            dismissPalette()
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToNote"),
                    object: note
                )
            }
        default:
            break
        }
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
        
        let note = Note(
            type: .note,
            content: content,
            bookId: nil,
            bookTitle: nil,
            author: nil,
            pageNumber: nil
        )
        notesViewModel.addNote(note)
        HapticManager.shared.success()
        
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
            if parts.count >= 3 {
                author = parts[0]
                if parts[1] == "BOOK" && parts.count > 2 {
                    bookTitle = parts[2]
                }
                if parts.count > 4 && parts[3] == "PAGE" {
                    let pageStr = parts[4].trimmingCharacters(in: .whitespaces)
                    pageNumber = Int(pageStr.replacingOccurrences(of: "p.", with: "")
                        .replacingOccurrences(of: "page", with: "")
                        .replacingOccurrences(of: "pg", with: "")
                        .trimmingCharacters(in: .whitespaces))
                }
            } else {
                author = attr
            }
        }
        
        let quote = Note(
            type: .quote,
            content: content,
            bookId: nil,
            bookTitle: bookTitle,
            author: author,
            pageNumber: pageNumber
        )
        notesViewModel.addNote(quote)
        HapticManager.shared.success()
        
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
    
    // MARK: - Voice Recognition Methods
    
    private func startListening() {
        isFocused = false
        HapticManager.shared.mediumTap()
        isListening = true
        
        if commandText.isEmpty {
            commandText = ""
        }
        
        voiceManager.startAmbientListening()
        
        // Simple timer to update text
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor in
                if !isListening {
                    timer.invalidate()
                    return
                }
                
                let recognizedText = voiceManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !recognizedText.isEmpty && recognizedText != commandText {
                    commandText = recognizedText
                    withAnimation(.easeInOut(duration: 0.2)) {
                        detectedIntent = CommandParser.parse(commandText, books: libraryViewModel.books, notes: notesViewModel.notes)
                    }
                }
            }
        }
    }
    
    private func stopListening() {
        HapticManager.shared.lightTap()
        isListening = false
        voiceManager.stopListening()
        
        if !commandText.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}