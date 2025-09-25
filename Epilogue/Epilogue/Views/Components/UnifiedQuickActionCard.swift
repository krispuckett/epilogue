import SwiftUI

// MARK: - Unified Quick Action Card (Clean, No Microphone)
struct UnifiedQuickActionCard: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared

    // For sheets
    @State private var showBookSearch = false
    @State private var showBookScanner = false
    @State private var showPageScanner = false
    @State private var showTextCapture = false
    @State private var showRecentBooks = false
    @State private var showNotesSearch = false
    @State private var selectedBookContext: Book? = nil
    
    // Toast notification state
    @State private var showingToast = false
    @State private var toastMessage = ""

    var body: some View {
        ZStack {
            // Backdrop to dismiss
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    if isExpanded {
                        collapseCard()
                    } else {
                        isPresented = false
                    }
                }

            VStack {
                Spacer()

                // The actual card - matching reference screenshot style
                VStack(spacing: 0) {
                    // Main input row
                    HStack(spacing: 12) {
                        // Plus/X button with rotation animation
                        Button {
                            if !isExpanded {
                                expandCard()
                            } else {
                                collapseCard()
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                                .rotationEffect(.degrees(isExpanded ? 45 : 0)) // Rotate to X
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                        }

                        // Search/Input field - THE WHOLE AREA IS THE INPUT
                        VStack(spacing: 0) {
                            // Show selected book context as a tag
                            if let book = selectedBookContext {
                                HStack {
                                    Text(book.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedBookContext = nil
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    themeManager.currentTheme.primaryAccent.opacity(0.15)
                                )
                                .glassEffect(in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(
                                            themeManager.currentTheme.primaryAccent.opacity(0.3),
                                            lineWidth: 0.5
                                        )
                                }
                                .padding(.bottom, 8)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }

                            HStack {
                                if isExpanded {
                                    // Active text field when expanded - allows vertical expansion
                                    TextField(placeholderText, text: $searchText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                                    .tint(themeManager.currentTheme.primaryAccent)
                                    .lineLimit(1...5)  // Allow expansion up to 5 lines
                                    .focused($isFocused)
                                    .onSubmit {
                                        processInput()
                                    }
                                } else {
                                    // Clean input field matching ambient mode
                                    TextField(placeholderText, text: $searchText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(.white)
                                    .tint(themeManager.currentTheme.primaryAccent)
                                    .lineLimit(1...3)  // Allow multi-line even when collapsed
                                    .focused($isFocused)
                                    .onSubmit {
                                        if !searchText.isEmpty {
                                            processInput()
                                        }
                                    }
                            }

                                Spacer()
                            }
                        }

                        // Right side buttons - Morphing between ambient orb and submit
                        if navigationCoordinator.selectedTab == .notes {
                            // Always show liquid glass up arrow in Notes tab
                            Button {
                                processInput()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(themeManager.currentTheme.primaryAccent.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                        .glassEffect(in: Circle())
                                        .overlay {
                                            Circle()
                                                .strokeBorder(
                                                    themeManager.currentTheme.primaryAccent.opacity(0.3),
                                                    lineWidth: 0.5
                                                )
                                        }

                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(themeManager.currentTheme.primaryAccent)
                                }
                            }
                        } else {
                            // Morphing between ambient orb and submit button
                            ZStack {
                                // Ambient orb - shown when no text
                                Button {
                                    startAmbientMode()
                                } label: {
                                    AmbientOrbButton(size: 36) {
                                        // Action handled by parent
                                    }
                                    .allowsHitTesting(false)
                                }
                                .opacity(searchText.isEmpty ? 1 : 0)
                                .scaleEffect(searchText.isEmpty ? 1 : 0.8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: searchText.isEmpty)

                                // Submit button - shown when text exists
                                Button {
                                    processInput()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(themeManager.currentTheme.primaryAccent.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                            .glassEffect(in: Circle())
                                            .overlay {
                                                Circle()
                                                    .strokeBorder(
                                                        themeManager.currentTheme.primaryAccent.opacity(0.3),
                                                        lineWidth: 0.5
                                                    )
                                            }

                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .opacity(searchText.isEmpty ? 0 : 1)
                                .scaleEffect(searchText.isEmpty ? 0.8 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: !searchText.isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10) // Reduced padding to make it less tall

                    // Quick actions (only when expanded) - context aware
                    if isExpanded {
                        VStack(spacing: 0) {
                            Divider()
                                .background(Color.white.opacity(0.1))

                            // Quick action buttons - change based on context
                            VStack(spacing: 0) {
                                ForEach(contextualActions, id: \.title) { action in
                                    QuickActionRow(
                                        icon: action.icon,
                                        title: action.title,
                                        subtitle: action.subtitle,
                                        warmAmber: themeManager.currentTheme.primaryAccent,
                                        action: action.action
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                // Glass effect matching ambient mode with more pronounced rounded corners
                .background(
                    RoundedRectangle(cornerRadius: isExpanded ? 24 : 32, style: .continuous)
                        .fill(Color.white.opacity(0.001)) // Nearly invisible for glass
                )
                .glassEffect(.regular, in: .rect(cornerRadius: isExpanded ? 24 : 32))
                .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 24 : 32, style: .continuous)) // CLIP CONTENT TO CARD BOUNDS
                .overlay {
                    RoundedRectangle(cornerRadius: isExpanded ? 24 : 32, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryAccent.opacity(0.2),
                                    themeManager.currentTheme.primaryAccent.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: themeManager.currentTheme.primaryAccent.opacity(0.1), radius: 20, y: 8)
                .padding(.horizontal, 20)
                .padding(.bottom, 20) // Closer to bottom since action bar is hidden
            }
            
            // Glass Toast Overlay
            if showingToast {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(themeManager.currentTheme.primaryAccent)
                        
                        Text(toastMessage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.001))
                    )
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                themeManager.currentTheme.primaryAccent.opacity(0.3),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: themeManager.currentTheme.primaryAccent.opacity(0.15), radius: 20, y: 8)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        )
                    )
                }
                .padding(.bottom, 100) // Above tab bar
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingToast)
        .onAppear {
            // Focus immediately when appearing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(searchQuery: searchText) { book in
                libraryViewModel.addBook(book)
                showBookSearch = false
                showToast("Book added to library")
            }
        }
        .sheet(isPresented: $showBookScanner) {
            BookScannerView()
                .environmentObject(libraryViewModel)
        }
        .sheet(isPresented: $showTextCapture) {
            // Use AmbientTextCapture for OCR - exact same as ambient mode
            AmbientTextCapture(
                isPresented: $showTextCapture,
                bookContext: selectedBookContext ?? libraryViewModel.currentDetailBook,
                onQuoteSaved: { text, pageNumber in
                    // Handle the captured quote
                    let book = selectedBookContext ?? libraryViewModel.currentDetailBook
                    let quote = Note(
                        type: .quote,
                        content: text,
                        bookId: book?.localId,
                        bookTitle: book?.title,
                        author: book?.author,
                        pageNumber: pageNumber
                    )
                    notesViewModel.addNote(quote)
                    SensoryFeedback.success()
                    showTextCapture = false
                    showToast("Quote captured")
                },
                onQuestionAsked: { question in
                    // Handle question - could trigger AI chat
                    searchText = question
                    showTextCapture = false
                }
            )
        }
        .sheet(isPresented: $showRecentBooks) {
            // Recent books selector for quick note addition
            RecentBooksSheet(isPresented: $showRecentBooks) { selectedBook in
                withAnimation(.spring(response: 0.3)) {
                    selectedBookContext = selectedBook
                }
                isFocused = true
                showRecentBooks = false
            }
            .environmentObject(libraryViewModel)
        }
    }

    // MARK: - Computed Properties
    private var shouldShowSubmitButton: Bool {
        guard !searchText.isEmpty else { return false }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Show submit for actionable text (notes, quotes, questions)
        // Hide for book searches that aren't in library
        if trimmed.hasPrefix("note:") || trimmed.hasPrefix("n:") ||
           trimmed.hasPrefix("\"") ||
           trimmed.contains("?") ||
           (!trimmed.contains("book") && !trimmed.contains("add") && !trimmed.contains("search")) {
            return true
        }

        return false
    }

    private var placeholderText: String {
        // Shorter placeholder when collapsed, longer when expanded
        if !isExpanded {
            switch navigationCoordinator.selectedTab {
            case .library:
                return "Ask, capture, or type..."
            case .notes:
                return "Create a note, add a quote..."
            case .chat:
                return "Ask about your books..."
            }
        } else {
            switch navigationCoordinator.selectedTab {
            case .library:
                if libraryViewModel.currentDetailBook != nil {
                    return "Add a note, quote, or question about this book..."
                } else {
                    return "Add a book, search your library, or ask a question..."
                }
            case .notes:
                return "Create a note, add a quote, or search your thoughts..."
            case .chat:
                return "Ask about your books, notes, or reading insights..."
            }
        }
    }

    private struct QuickAction {
        let icon: String
        let title: String
        let subtitle: String
        let action: () -> Void
    }

    private var contextualActions: [QuickAction] {
        var actions: [QuickAction] = []

        switch navigationCoordinator.selectedTab {
        case .library:
            if let currentBook = libraryViewModel.currentDetailBook {
                // Book detail view actions
                actions.append(QuickAction(
                    icon: "camera.viewfinder",
                    title: "Scan Page",
                    subtitle: "Capture quote from \(currentBook.title)",
                    action: {
                        showTextCapture = true  // Use the same text capture as ambient mode
                        collapseCard()
                    }
                ))
                actions.append(QuickAction(
                    icon: "note.text",
                    title: "Book Note",
                    subtitle: "Add note about \(currentBook.title)",
                    action: {
                        searchText = "note: "
                        isFocused = true
                    }
                ))
                actions.append(QuickAction(
                    icon: "quote.opening",
                    title: "Add Quote",
                    subtitle: "Save a passage from this book",
                    action: {
                        searchText = "\""
                        isFocused = true
                    }
                ))
            } else {
                // Library view actions
                actions.append(QuickAction(
                    icon: "book",
                    title: "Add Book",
                    subtitle: "Search and add to library",
                    action: {
                        showBookSearch = true
                        collapseCard()
                    }
                ))
                actions.append(QuickAction(
                    icon: "camera",
                    title: "Scan Cover",
                    subtitle: "Add book by camera",
                    action: {
                        showBookScanner = true
                        collapseCard()
                    }
                ))
            }

        case .notes:
            // Notes view actions - just two functional options
            actions.append(QuickAction(
                icon: "clock.arrow.circlepath",
                title: "Recent Books",
                subtitle: "Add notes to recent reads",
                action: {
                    showRecentBooks = true
                    // Don't collapse card - keep it open for note entry
                }
            ))
            actions.append(QuickAction(
                icon: "camera.fill",
                title: "Capture from Photo",
                subtitle: "Extract text with OCR",
                action: {
                    showTextCapture = true
                    collapseCard()
                }
            ))

        case .chat:
            // Chat view actions
            actions.append(QuickAction(
                icon: "bubble.left.and.bubble.right",
                title: "Ask About Books",
                subtitle: "Get insights from your library",
                action: {
                    searchText = "What themes appear across my books?"
                    isFocused = true
                }
            ))
            actions.append(QuickAction(
                icon: "lightbulb",
                title: "Reading Insights",
                subtitle: "Discover patterns in your notes",
                action: {
                    searchText = "What are the key ideas from my recent reading?"
                    isFocused = true
                }
            ))
        }

        return actions
    }

    // MARK: - Actions
    private func expandCard() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isExpanded = true
        }
        // Don't refocus if already focused - this dismisses keyboard
        if !isFocused {
            isFocused = true
        }
        SensoryFeedback.light()
    }

    private func collapseCard() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isExpanded = false
        }
        SensoryFeedback.light()
    }

    // Helper function to parse quotes with attribution
    private func parseQuoteWithAttribution(_ text: String) -> (quote: String, author: String?, book: String?)? {
        // Common patterns for quotes with attribution:
        // "Quote" - Author
        // "Quote" — Author  
        // "Quote" - Author, Book
        // "Quote" ~ Author
        // Quote - Author (without quotes)
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern 1: Quoted text with dash separator  
        let quotePattern = "^[\"\\u{201C}](.+?)[\"\\u{201D}]?\\s*[-—~]\\s*(.+)$"
        if let quoteMatch = trimmed.range(of: quotePattern, options: .regularExpression) {
            let fullMatch = String(trimmed[quoteMatch])
            let components = fullMatch.components(separatedBy: CharacterSet(charactersIn: "-—~"))
            if components.count >= 2 {
                var quote = components[0].trimmingCharacters(in: .whitespaces)
                // Remove quotes manually
                let smartQuoteOpen = "\u{201C}" // "
                let smartQuoteClose = "\u{201D}" // "
                if quote.hasPrefix("\"") { quote.removeFirst() }
                if quote.hasSuffix("\"") { quote.removeLast() }
                if quote.hasPrefix(smartQuoteOpen) { quote.removeFirst() }
                if quote.hasSuffix(smartQuoteClose) { quote.removeLast() }
                quote = quote.trimmingCharacters(in: .whitespaces)
                let attribution = components[1].trimmingCharacters(in: .whitespaces)
                
                // Check if attribution contains book info (comma separated)
                if attribution.contains(",") {
                    let parts = attribution.split(separator: ",", maxSplits: 1)
                    let author = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let book = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    return (quote: quote, author: author, book: book)
                } else {
                    return (quote: quote, author: attribution, book: nil)
                }
            }
        }
        
        // Pattern 2: Non-quoted text with clear attribution pattern
        if trimmed.contains(" - ") || trimmed.contains(" — ") || trimmed.contains(" ~ ") {
            let separators = CharacterSet(charactersIn: "-—~")
            let components = trimmed.components(separatedBy: separators)
            if components.count >= 2 {
                let quote = components[0].trimmingCharacters(in: .whitespaces)
                let attribution = components[1].trimmingCharacters(in: .whitespaces)
                
                // Check if attribution contains book info
                if attribution.contains(",") {
                    let parts = attribution.split(separator: ",", maxSplits: 1)
                    let author = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let book = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    return (quote: quote, author: author, book: book)
                } else {
                    return (quote: quote, author: attribution, book: nil)
                }
            }
        }
        
        return nil
    }
    
    private func processInput() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // ULTRA-INTELLIGENT INTENT DETECTION
        // We anticipate what users mean, not just what they type
        
        // 1. Smart Quote Detection (multiple patterns)
        if let parsedQuote = parseQuoteWithAttribution(trimmed) {
            createQuoteWithAttribution(
                text: parsedQuote.quote,
                author: parsedQuote.author,
                bookTitle: parsedQuote.book
            )
        }
        // Quoted text - obvious quote intent
        else if trimmed.hasPrefix("\"") || trimmed.hasPrefix("\u{201C}") || 
                trimmed.hasPrefix("'") || trimmed.hasPrefix("\u{2018}") {
            createQuote(trimmed)
        }
        // Common quote-like phrases
        else if isLikelyQuote(trimmed) {
            createQuote(trimmed)
        }
        
        // 2. Book Search (only very explicit intents)
        else if isBookSearchIntent(trimmed) {
            showBookSearch = true
        }
        
        // 3. Questions and Thoughts
        else if trimmed.hasSuffix("?") {
            // Questions - could trigger AI assistant
            if shouldTriggerAI(trimmed) {
                // Future: Trigger AI
                createNote(trimmed) // For now, save as note
            } else {
                createNote(trimmed)
            }
        }
        
        // 4. Reading Progress Updates
        else if isReadingProgress(trimmed) {
            // Extract page number and update progress
            if let pageNumber = extractPageNumber(trimmed) {
                updateReadingProgress(pageNumber: pageNumber)
                createNote(trimmed) // Also save as note for history
            } else {
                createNote(trimmed)
            }
        }
        
        // 5. Ambient Mode Triggers
        else if trimmed.lowercased().contains("ambient") || 
                trimmed.lowercased() == "start reading" ||
                trimmed.lowercased() == "reading mode" {
            startAmbientMode()
            return // Don't save as note
        }
        
        // 6. Default: Smart Note Creation
        else {
            // Everything else becomes a note
            // This is the safest default - never lose user content
            createNote(trimmed)
        }
        
        // Collapse the card and dismiss completely after processing
        collapseCard()

        // Dismiss the entire card after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                isPresented = false
            }
        }

        // Clear text only after card is fully dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            searchText = ""
            selectedBookContext = nil
            isExpanded = false
        }
    }
    
    // Helper to detect book search intent more accurately
    private func isBookSearchIntent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Explicit book commands
        let bookCommands = [
            "add book", "add a book", "add new book",
            "search book", "search for book", "search books",
            "find book", "find a book", "find books",
            "new book", "get book", "lookup book"
        ]
        
        for command in bookCommands {
            if lowercased.hasPrefix(command) {
                return true
            }
        }
        
        // ISBN patterns
        if text.range(of: #"^\d{10}$|^\d{13}$|^978\d{10}$"#, options: .regularExpression) != nil {
            return true
        }
        
        return false
    }
    
    // Detect if text is likely a quote (without explicit quote marks)
    private func isLikelyQuote(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Famous quote beginnings
        let quoteStarters = [
            "to be or not to be",
            "i think therefore",
            "the only thing we have to fear",
            "ask not what your country",
            "i have a dream"
        ]
        
        for starter in quoteStarters {
            if lowercased.hasPrefix(starter) {
                return true
            }
        }
        
        // Poetic or philosophical language patterns
        let poeticWords = ["shall", "unto", "thou", "thy", "wherefore", "henceforth"]
        for word in poeticWords {
            if lowercased.contains(word) {
                return true
            }
        }
        
        return false
    }
    
    // Check if this question should trigger AI
    private func shouldTriggerAI(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // AI trigger patterns
        let aiTriggers = [
            "what does", "what do you think",
            "explain", "tell me about",
            "who is", "who was",
            "why did", "why does",
            "how does", "how did",
            "summarize", "summary of"
        ]
        
        for trigger in aiTriggers {
            if lowercased.contains(trigger) {
                return true
            }
        }
        
        return false
    }
    
    // Detect reading progress updates
    private func isReadingProgress(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Progress patterns
        let progressPatterns = [
            "page \\d+",
            "on page \\d+",
            "reading page \\d+",
            "finished page \\d+",
            "up to page \\d+",
            "chapter \\d+",
            "finished chapter"
        ]
        
        for pattern in progressPatterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    // Extract page number from text
    private func extractPageNumber(_ text: String) -> Int? {
        // Find page number pattern
        if let match = text.range(of: #"page\s+(\d+)"#, options: [.regularExpression, .caseInsensitive]) {
            let pageText = String(text[match])
            let numbers = pageText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Int(numbers)
        }
        
        return nil
    }
    
    // Update reading progress
    private func updateReadingProgress(pageNumber: Int) {
        if let book = selectedBookContext ?? libraryViewModel.currentDetailBook {
            // Update the book's current page
            if let index = libraryViewModel.books.firstIndex(where: { $0.id == book.id }) {
                libraryViewModel.books[index].currentPage = pageNumber
                libraryViewModel.updateBook(libraryViewModel.books[index])
            }
        }
    }

    private func createNote(_ text: String) {
        print("📝 UnifiedQuickActionCard: Creating note with text: \(text)")
        
        // Use selected book context if available, otherwise current detail book
        let book = selectedBookContext ?? libraryViewModel.currentDetailBook
        
        // Send notification to create note in SwiftData
        var noteData: [String: Any] = [
            "content": text.isEmpty ? "New note" : text
        ]
        
        // Add book context if available
        if let book = book {
            noteData["bookId"] = book.localId.uuidString
            noteData["bookTitle"] = book.title
            noteData["bookAuthor"] = book.author
            print("📝 Note has book context: \(book.title)")
        } else {
            print("📝 Note has no book context")
        }
        
        print("📝 Posting CreateNewNote notification with data: \(noteData)")
        
        // Post the notification with a small delay to ensure the view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: Notification.Name("CreateNewNote"),
                object: noteData
            )
        }
        
        SensoryFeedback.success()
        showToast("Note saved")
    }

    private func createQuote(_ text: String) {
        let content = text.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let book = selectedBookContext ?? libraryViewModel.currentDetailBook
        
        // Send notification to create quote in SwiftData
        var quoteData: [String: Any] = [
            "quote": content
        ]
        
        // Add book context if available
        if let book = book {
            quoteData["bookId"] = book.localId.uuidString
            quoteData["bookTitle"] = book.title
            quoteData["bookAuthor"] = book.author
        }
        
        // Post the notification with a small delay to ensure the view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: Notification.Name("SaveQuote"),
                object: quoteData
            )
        }
        
        SensoryFeedback.success()
        showToast("Quote saved")
    }
    
    private func createQuoteWithAttribution(text: String, author: String?, bookTitle: String?) {
        let book = selectedBookContext ?? libraryViewModel.currentDetailBook
        
        // Send notification to create quote in SwiftData
        var quoteData: [String: Any] = [
            "quote": text
        ]
        
        // Add attribution
        if let author = author {
            quoteData["attribution"] = author
        }
        
        // Add book context - prefer the parsed book title, then selected book
        if let bookTitle = bookTitle {
            // Use the parsed book title (e.g., "On the Shortness of Life")
            quoteData["bookTitle"] = bookTitle
            quoteData["bookAuthor"] = author // Author is both quote author and book author
        } else if let book = book {
            // Fall back to selected book context
            quoteData["bookId"] = book.localId.uuidString
            quoteData["bookTitle"] = book.title
            quoteData["bookAuthor"] = book.author
        } else if author != nil {
            // No book context, but we have an author
            // Just use the author for attribution
        }
        
        // Post the notification with a small delay to ensure the view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: Notification.Name("SaveQuote"),
                object: quoteData
            )
        }
        
        SensoryFeedback.success()
        showToast("Quote saved")
    }

    private func startAmbientMode() {
        if let currentBook = libraryViewModel.currentDetailBook {
            SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
        } else {
            SimplifiedAmbientCoordinator.shared.openAmbientReading()
        }
        collapseCard()
    }
    
    // MARK: - Toast Functions
    private func showToast(_ message: String) {
        toastMessage = message
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingToast = true
        }
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingToast = false
            }
        }
    }
}

// MARK: - Quick Action Row Component
struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let warmAmber: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(warmAmber)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(warmAmber.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        UnifiedQuickActionCard(isPresented: .constant(true))
            .environmentObject(LibraryViewModel())
            .environmentObject(NotesViewModel())
    }
}