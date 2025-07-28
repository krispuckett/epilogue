import SwiftUI

struct LiquidCommandPalette: View {
    @Binding var isPresented: Bool
    @State private var commandText = ""
    @State private var detectedIntent: CommandIntent = .unknown
    @FocusState private var isFocused: Bool
    @State private var showQuickSuggestions = false
    @State private var pillOpacities: [Double] = [0, 0, 0, 0]
    @State private var pillScales: [CGFloat] = [0.8, 0.8, 0.8, 0.8]
    @State private var currentGlowColor = Color(red: 1.0, green: 0.55, blue: 0.26) // Amber initial
    @State private var isAnimating = false
    @State private var showBookSearch = false
    @State private var textEditorHeight: CGFloat = 36
    @State private var noteToEdit: Note? = nil
    @State private var showPreview = false
    @State private var previewDelay: DispatchWorkItem?
    @State private var displayedIntent: CommandIntent = .unknown
    @State private var iconChangeDelay: DispatchWorkItem?
    @State private var showToast = false
    @State private var toastMessage = ""
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    // Animation namespace for matched geometry
    var animationNamespace: Namespace.ID
    
    let suggestions = [
        ("Note", "note: ", "Add a quick thought"),
        ("Quote", "\"", "Save a memorable quote"),
        ("Book", "add book ", "Add to your library"),
        ("Search", "search ", "Find in your library")
    ]
    
    // Optional initial content for editing
    let initialContent: String?
    let editingNote: Note?
    let onUpdate: ((Note) -> Void)?
    
    init(isPresented: Binding<Bool>, animationNamespace: Namespace.ID, initialContent: String? = nil, editingNote: Note? = nil, onUpdate: ((Note) -> Void)? = nil) {
        self._isPresented = isPresented
        self.animationNamespace = animationNamespace
        self.initialContent = initialContent
        self.editingNote = editingNote
        self.onUpdate = onUpdate
    }
    
    private var showActionButton: Bool {
        !commandText.isEmpty && detectedIntent != .unknown
    }
    
    private var placeholderText: String {
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
    
    var body: some View {
        ZStack {
            // Invisible backdrop to catch taps
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissPalette()
                }
            
            VStack {
                Spacer()
                
                // Quick suggestions pills floating above
                if showQuickSuggestions {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                                let (title, prefix, _) = suggestion
                                Button {
                                    commandText = prefix
                                    // Hide all pills with staggered animation
                                    for i in (0..<suggestions.count).reversed() {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(suggestions.count - i - 1) * 0.05)) {
                                            pillOpacities[i] = 0
                                            pillScales[i] = 0.8
                                        }
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showQuickSuggestions = false
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: iconForTitle(title))
                                            .font(.system(size: 14, weight: .medium))
                                        Text(title)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassEffect(.regular.tint(colorForTitle(title).opacity(0.4)), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        colorForTitle(title).opacity(0.5),
                                                        colorForTitle(title).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    }
                                    .shadow(color: colorForTitle(title).opacity(0.2), radius: 8, y: 4)
                                }
                                .opacity(pillOpacities[index])
                                .scaleEffect(pillScales[index])
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 40)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .padding(.bottom, 8)
                }
                
                // Preview for matched content
                if showPreview {
                    VStack(spacing: 0) {
                        switch detectedIntent {
                        case .existingBook(let book):
                            BookPreviewCard(book: book)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                        case .existingNote(let note):
                            NotePreviewCard(note: note)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                        default:
                            EmptyView()
                        }
                    }
                }
                
                // iMessage-style input bar
                HStack(spacing: 8) {
                    // Plus button (left side)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showQuickSuggestions.toggle()
                            if showQuickSuggestions {
                                // Show pills with staggered animation
                                for i in 0..<suggestions.count {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(Double(i) * 0.05)) {
                                        pillOpacities[i] = 1
                                        pillScales[i] = 1
                                    }
                                }
                            } else {
                                // Hide pills
                                for i in (0..<suggestions.count).reversed() {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(suggestions.count - i - 1) * 0.05)) {
                                        pillOpacities[i] = 0
                                        pillScales[i] = 0.8
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.tint(Color.white.opacity(0.1)), in: Circle())
                    }
                    
                    // Input field container with glass effect
                    HStack(spacing: 0) {
                        // Dynamic icon based on intent
                        Image(systemName: iconForIntent(displayedIntent))
                            .foregroundStyle(currentGlowColor)
                            .font(.system(size: 20, weight: .medium))
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayedIntent)
                        
                        // Text field
                        ZStack(alignment: .leading) {
                            if commandText.isEmpty {
                                Text(placeholderText)
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 16))
                            }
                            
                            TextField("", text: $commandText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .focused($isFocused)
                                .lineLimit(1...5)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .keyboardType(.default)
                                .submitLabel(.done)
                                .onChange(of: commandText) { _, newValue in
                                    // Hide suggestions when user starts typing
                                    if !newValue.isEmpty && showQuickSuggestions {
                                        showQuickSuggestions = false
                                        for i in (0..<suggestions.count).reversed() {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(suggestions.count - i - 1) * 0.05)) {
                                                pillOpacities[i] = 0
                                                pillScales[i] = 0.8
                                            }
                                        }
                                    }
                                    
                                    // Normalize smart quotes to regular quotes
                                    let normalizedText = newValue
                                        .replacingOccurrences(of: "\u{201C}", with: "\"")
                                        .replacingOccurrences(of: "\u{201D}", with: "\"")
                                        .replacingOccurrences(of: "\u{2018}", with: "'")
                                        .replacingOccurrences(of: "\u{2019}", with: "'")
                                    
                                    DispatchQueue.main.async {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            detectedIntent = CommandParser.parse(normalizedText, books: libraryViewModel.books, notes: notesViewModel.notes)
                                            updateGlowColor()
                                        }
                                        
                                        // Cancel previous icon change delay
                                        iconChangeDelay?.cancel()
                                        
                                        // Update icon with delay to prevent jumpiness
                                        let workItem = DispatchWorkItem {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                displayedIntent = detectedIntent
                                            }
                                        }
                                        iconChangeDelay = workItem
                                        // 0.3 second delay before changing icon
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                                    }
                                    
                                    // Cancel previous preview delay
                                    previewDelay?.cancel()
                                    
                                    // Show preview after a short delay for existing content
                                    if case .existingBook = detectedIntent {
                                        showPreview = false
                                        let workItem = DispatchWorkItem {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showPreview = true
                                            }
                                        }
                                        previewDelay = workItem
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                                    } else if case .existingNote = detectedIntent {
                                        showPreview = false
                                        let workItem = DispatchWorkItem {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showPreview = true
                                            }
                                        }
                                        previewDelay = workItem
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                                    } else {
                                        showPreview = false
                                    }
                                }
                                .onSubmit {
                                    executeCommand()
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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
                    
                    // Send button (appears when there's text and valid intent)
                    if showActionButton {
                        Button {
                            executeCommand()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white, currentGlowColor)
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            // Initialize with existing content if editing
            if let initialContent = initialContent {
                commandText = initialContent
                detectedIntent = CommandParser.parse(initialContent, books: libraryViewModel.books, notes: notesViewModel.notes)
                displayedIntent = detectedIntent // Set immediately on appear
                updateGlowColor()
            } else {
                commandText = ""
                detectedIntent = .unknown
                displayedIntent = .unknown
                currentGlowColor = Color(red: 1.0, green: 0.55, blue: 0.26)
            }
            
            // Auto-focus immediately
            isFocused = true
            
            // Pills are hidden initially - only show when plus button is tapped
        }
        .onDisappear {
            // Clear on dismiss
            isFocused = false
            isAnimating = false
            showQuickSuggestions = false
            // Reset pill states
            pillOpacities = [0, 0, 0, 0]
            pillScales = [0.8, 0.8, 0.8, 0.8]
            // Cancel any pending icon changes
            iconChangeDelay?.cancel()
            previewDelay?.cancel()
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
                    showSuccessToast(message: "Book added to library", icon: "book.badge.plus.fill", color: Color(red: 0.6, green: 0.4, blue: 0.8))
                    
                    // Delay dismissal to show toast
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismissPalette()
                    }
                }
            )
        }
        .glassToast(
            isShowing: $showToast,
            message: toastMessage
        )
    }
    
    private func iconForTitle(_ title: String) -> String {
        switch title {
        case "Note": return "note.text"
        case "Quote": return "quote.opening"
        case "Book": return "book"
        case "Search": return "magnifyingglass"
        default: return "circle"
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
    
    private func colorForTitle(_ title: String) -> Color {
        switch title {
        case "Note": return Color(red: 0.4, green: 0.6, blue: 0.9)
        case "Quote": return Color(red: 1.0, green: 0.55, blue: 0.26)
        case "Book": return Color(red: 0.6, green: 0.4, blue: 0.8)
        case "Search": return Color(red: 0.3, green: 0.7, blue: 0.5)
        default: return .gray
        }
    }
    
    private func updateGlowColor() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentGlowColor = detectedIntent.color
        }
    }
    
    private func dismissPalette() {
        guard !isAnimating else { return }
        
        isAnimating = true
        isFocused = false
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isPresented = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimating = false
        }
    }
    
    private func showSuccessToast(message: String, icon: String, color: Color) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }
    }
    
    private func executeCommand() {
        guard detectedIntent != .unknown else { return }
        
        HapticManager.shared.mediumTap()
        
        // Handle editing mode
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
        
        // Handle creation mode
        switch detectedIntent {
        case .createNote(let text):
            createNote(from: text)
        case .createQuote(let text):
            createQuote(from: text)
        case .addBook(let query):
            // Show book search sheet
            showBookSearch = true
        case .searchLibrary(let query):
            // TODO: Implement library search
            HapticManager.shared.success()
            dismissPalette()
        case .existingBook(let book):
            // Navigate to the book
            HapticManager.shared.success()
            dismissPalette()
            // Post notification to navigate to book
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToBook"),
                    object: book
                )
            }
        case .existingNote(let note):
            // Navigate to note
            HapticManager.shared.success()
            dismissPalette()
            // Post notification to navigate to note
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
    
    private func createNote(from text: String) {
        // Normalize smart quotes before processing
        let normalizedText = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        
        var content = normalizedText
        
        // Remove various note prefixes
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
        showSuccessToast(message: "Note saved", icon: "note.text", color: Color(red: 0.4, green: 0.6, blue: 0.9))
        
        // Delay dismissal to show toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismissPalette()
        }
    }
    
    private func createQuote(from text: String) {
        // Normalize smart quotes before parsing
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
        showSuccessToast(message: "Quote captured", icon: "quote.opening", color: Color(red: 1.0, green: 0.55, blue: 0.26))
        
        // Delay dismissal to show toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismissPalette()
        }
    }
    
    private func updateNote(from text: String, editingNote: Note, onUpdate: @escaping (Note) -> Void) {
        // Normalize smart quotes before processing
        let normalizedText = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        
        var content = normalizedText
        
        // Remove various note prefixes
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
        // Normalize smart quotes before parsing
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
}

// MARK: - Preview Cards
struct BookPreviewCard: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            // Book cover
            if let coverURL = book.coverImageURL {
                // Enhance the URL for better quality
                let enhancedURL = coverURL
                    .replacingOccurrences(of: "http://", with: "https://")
                    .appending(coverURL.contains("?") ? "&w=1080" : "?w=1080")
                
                if let url = URL(string: enhancedURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .tint(.white.opacity(0.5))
                            }
                    }
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
            } else {
                // No cover URL - show book icon
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.25, green: 0.25, blue: 0.3))
                    .frame(width: 40, height: 60)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.3))
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text("by \(book.author)")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.circle")
                        .font(.system(size: 12))
                    Text("Press Enter to open")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1)
        }
    }
}

struct NotePreviewCard: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: note.type == .quote ? "quote.opening" : "note.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                
                Text(note.type == .quote ? "Quote" : "Note")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(note.formattedDate)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Text(note.content)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            if let bookTitle = note.bookTitle {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 11))
                    Text(bookTitle)
                        .font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right.circle")
                    .font(.system(size: 12))
                Text("Press Enter to view")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            .padding(.top, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1)
        }
    }
}
