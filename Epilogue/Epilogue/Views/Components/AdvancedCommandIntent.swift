import SwiftUI

// MARK: - Advanced Command Intent - Clean Input Card Style
struct AdvancedCommandIntent: View {
    @Binding var isPresented: Bool
    @State private var inputText = ""
    @State private var showAddBookPopover = false
    @State private var showRealInput = false
    @FocusState private var isInputFocused: Bool

    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel

    private let warmAmber = Color(red: 1.0, green: 0.75, blue: 0.35)

    // Advanced NLP-based suggestions
    private var intelligentSuggestions: [(text: String, action: () -> Void)] {
        guard !inputText.isEmpty else { return [] }

        let lowercased = inputText.lowercased()
        var suggestions: [(text: String, action: () -> Void)] = []

        // Book title detection (handles lowercase titles)
        if lowercased.contains("add") || lowercased.starts(with: "\"") {
            // Extract potential book title
            let title = extractBookTitle(from: inputText)
            if !title.isEmpty {
                suggestions.append((
                    text: "Add book",
                    action: {
                        searchAndAddBook(title: title)
                    }
                ))
            }
        }

        // Smart intent detection
        if lowercased.contains("scan") || lowercased.contains("camera") || lowercased.contains("photo") {
            suggestions.append((
                text: "Scan book",
                action: {
                    openBookScanner()
                }
            ))
        }

        // Enhanced NLP for notes - detect book context from current view or text
        if lowercased.contains("note") || lowercased.contains("thought") || lowercased.contains("idea") ||
           lowercased.contains("love") || lowercased.contains("think") || lowercased.contains("feel") ||
           lowercased.contains("describe") || lowercased.contains("how") {

            // First check if we have a current book context
            if let currentBook = libraryViewModel.currentDetailBook {
                suggestions.append((
                    text: "Add note",
                    action: {
                        createNoteAbout(currentBook.title)
                    }
                ))
            } else if let bookContext = extractBookContext(from: inputText) {
                suggestions.append((
                    text: "Add note",
                    action: {
                        createNoteAbout(bookContext)
                    }
                ))
            } else if let inferredBook = inferBookFromContent(inputText) {
                suggestions.append((
                    text: "Add note",
                    action: {
                        createNoteAbout(inferredBook)
                    }
                ))
            } else {
                suggestions.append((
                    text: "Add note",
                    action: {
                        createNewNote()
                    }
                ))
            }
        }

        if lowercased.contains("quote") || lowercased.contains("passage") {
            suggestions.append((
                text: "Add quote",
                action: {
                    saveQuote()
                }
            ))
        }

        if lowercased.contains("read") || lowercased.contains("continue") {
            if let book = libraryViewModel.currentDetailBook {
                suggestions.append((
                    text: "Start reading",
                    action: {
                        startReading(book: book)
                    }
                ))
            } else {
                suggestions.append((
                    text: "Start reading",
                    action: {
                        startReading(book: nil)
                    }
                ))
            }
        }

        if lowercased.contains("find") || lowercased.contains("search") || lowercased.contains("show") {
            suggestions.append((
                text: "Search",
                action: {
                    performSearch(query: inputText)
                }
            ))
        }

        // Detect questions about books/characters - trigger ambient session
        if inputText.contains("?") ||
           lowercased.starts(with: "who") || lowercased.starts(with: "what") ||
           lowercased.starts(with: "where") || lowercased.starts(with: "when") ||
           lowercased.starts(with: "why") || lowercased.starts(with: "how") ||
           lowercased.contains("tell me about") || lowercased.contains("explain") {

            // Try to infer which book this question is about
            if let inferredBook = inferBookFromContent(inputText) {
                suggestions.insert((
                    text: "Ask question",
                    action: {
                        startAmbientSessionWithQuestion(bookTitle: inferredBook, question: inputText)
                    }
                ), at: 0)
            } else if let currentBook = libraryViewModel.currentDetailBook {
                suggestions.insert((
                    text: "Ask question",
                    action: {
                        startAmbientSessionWithQuestion(book: currentBook, question: inputText)
                    }
                ), at: 0)
            } else {
                suggestions.insert((
                    text: "Ask question",
                    action: {
                        startAmbientSessionWithQuestion(bookTitle: nil, question: inputText)
                    }
                ), at: 0)
            }
        }

        // Default suggestion if nothing specific matched
        if suggestions.isEmpty {
            // Check if this looks like a book title (doesn't match any commands)
            let lowercasedInput = inputText.lowercased()
            let bookExists = libraryViewModel.books.contains { book in
                book.title.lowercased().contains(lowercasedInput) ||
                book.author.lowercased().contains(lowercasedInput)
            }

            if !bookExists && !inputText.isEmpty {
                // Suggest searching for this as a new book
                suggestions.append((
                    text: "Search for book",
                    action: {
                        searchForBook(query: inputText)
                    }
                ))
            } else {
                suggestions.append((
                    text: "Search",
                    action: {
                        performSearch(query: inputText)
                    }
                ))
            }
        }

        return Array(suggestions.prefix(3)) // Limit to 3 suggestions
    }

    var body: some View {
        VStack(spacing: 16) {
            // Card with text display - NO INPUT FIELD VISIBLE
            HStack(spacing: 12) {
                // Plus button
                Button {
                    SensoryFeedback.light()
                    showAddBookPopover.toggle()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAddBookPopover, arrowEdge: .top) {
                    addBookPopover
                }

                // Just show the text - NO TextField visible
                HStack(spacing: 2) {
                    if inputText.isEmpty {
                        Text("Ask anything...")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.white.opacity(0.5))

                        // Blinking cursor after placeholder
                        Rectangle()
                            .fill(warmAmber)
                            .frame(width: 2, height: 20)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: true)
                    } else {
                        Text(inputText)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        // Cursor at end of text
                        Rectangle()
                            .fill(warmAmber)
                            .frame(width: 2, height: 20)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: true)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // This would trigger keyboard but we keep it looking like text
                    isInputFocused = true
                }

                // NO MICROPHONE - REMOVED COMPLETELY

                // Ambient orb only
                Button {
                    startAmbientMode()
                } label: {
                    AmbientOrbButton(size: 36) {
                        // Action handled by parent
                    }
                    .allowsHitTesting(false)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glassEffect(in: RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 20)

            // Hidden TextField for actual input - completely invisible
            TextField("", text: $inputText)
                .focused($isInputFocused)
                .opacity(0.0001) // Invisible but functional
                .frame(height: 1)
                .onSubmit {
                    handleSubmit()
                    isInputFocused = false
                }



            Spacer(minLength: 20)
        }
        .padding(.bottom, 8)
        .presentationDetents([.height(120)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color.clear) // NO BACKGROUND - let glass effect work
        .interactiveDismissDisabled(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
    }

    // MARK: - NLP Helpers
    private func extractBookTitle(from text: String) -> String {
        // Check for quoted text first
        if let range = text.range(of: "\"([^\"]+)\"", options: .regularExpression) {
            let quoted = String(text[range])
            return quoted.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }

        // Check for "add [title]" pattern
        let lowercased = text.lowercased()
        if lowercased.starts(with: "add ") {
            let title = String(text.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            return title
        }

        return ""
    }

    // Infer book from content mentions
    private func inferBookFromContent(_ text: String) -> String? {
        let lowercased = text.lowercased()

        // Common book/author references
        let bookReferences = [
            ("tolkien", "The Lord of the Rings"),
            ("frodo", "The Lord of the Rings"),
            ("gandalf", "The Lord of the Rings"),
            ("middle earth", "The Lord of the Rings"),
            ("shire", "The Hobbit"),
            ("bilbo", "The Hobbit"),
            ("harry potter", "Harry Potter"),
            ("hogwarts", "Harry Potter"),
            ("dumbledore", "Harry Potter"),
            ("1984", "1984"),
            ("big brother", "1984"),
            ("gatsby", "The Great Gatsby"),
            ("mockingbird", "To Kill a Mockingbird"),
            ("atticus", "To Kill a Mockingbird"),
            ("dune", "Dune"),
            ("arrakis", "Dune"),
            ("spice", "Dune"),
            ("lord of the rings", "The Lord of the Rings"),
            ("lotr", "The Lord of the Rings")
        ]

        for (keyword, bookTitle) in bookReferences {
            if lowercased.contains(keyword) {
                return bookTitle
            }
        }

        return nil
    }

    private func extractBookContext(from text: String) -> String? {
        // Look for "about [book]" or "for [book]" patterns
        let lowercased = text.lowercased()

        if let range = lowercased.range(of: "about ") {
            let context = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return context.isEmpty ? nil : context
        } else if let range = lowercased.range(of: "for ") {
            let context = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return context.isEmpty ? nil : context
        }

        return nil
    }

    // MARK: - Actions
    private func handleSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Use the first suggestion's action if available
        if let firstSuggestion = intelligentSuggestions.first {
            firstSuggestion.action()
        } else {
            // Default behavior: search for the text as a book title
            searchForBook(query: trimmed)
        }
    }

    private func searchForBook(query: String) {
        // Check if the book exists in library first
        let lowercasedQuery = query.lowercased()
        let bookExists = libraryViewModel.books.contains { book in
            book.title.lowercased().contains(lowercasedQuery) ||
            book.author.lowercased().contains(lowercasedQuery)
        }

        if !bookExists {
            // Book not in library, open book search with the query
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: Notification.Name("ShowBookSearch"),
                    object: query  // Pass the query string directly
                )
            }
        } else {
            // Book exists, perform regular search/filter
            performSearch(query: query)
        }
    }

    private func searchAndAddBook(title: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Pass the title as search query
            NotificationCenter.default.post(
                name: Notification.Name("ShowBookSearch"),
                object: title  // Changed to pass string directly, matching what LibraryView expects
            )
        }
    }

    private func openBookScanner() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: Notification.Name("ShowEnhancedBookScanner"), object: nil)
        }
    }

    private func createNoteAbout(_ context: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: Notification.Name("CreateNewNote"),
                object: ["context": context]
            )
        }
    }

    private func createNewNote() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: Notification.Name("CreateNewNote"), object: nil)
        }
    }

    private func saveQuote() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: Notification.Name("ShowQuoteCapture"), object: nil)
        }
    }

    private func startReading(book: Book?) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let book = book {
                SimplifiedAmbientCoordinator.shared.openAmbientReading(with: book)
            } else {
                SimplifiedAmbientCoordinator.shared.openAmbientReading()
            }
        }
    }

    private func performSearch(query: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: Notification.Name("PerformSearch"),
                object: ["query": query]
            )
        }
    }

    private func startAmbientSessionWithQuestion(book: Book? = nil, bookTitle: String? = nil, question: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // If we have a specific book, open ambient mode with it
            if let book = book {
                SimplifiedAmbientCoordinator.shared.openAmbientReading(with: book, initialQuestion: question)
            } else if let bookTitle = bookTitle {
                // Try to find the book in the library
                if let foundBook = libraryViewModel.books.first(where: {
                    $0.title.lowercased().contains(bookTitle.lowercased())
                }) {
                    SimplifiedAmbientCoordinator.shared.openAmbientReading(with: foundBook, initialQuestion: question)
                } else {
                    // Start ambient mode without a specific book but with the question
                    SimplifiedAmbientCoordinator.shared.openAmbientReading(initialQuestion: question)
                }
            } else {
                // Start ambient mode without a book but with the question
                SimplifiedAmbientCoordinator.shared.openAmbientReading(initialQuestion: question)
            }
        }
    }

    private func dismiss() {
        isInputFocused = false
        withAnimation(.interactiveSpring(response: 0.3)) {
            isPresented = false
        }
    }

    // MARK: - Add Book Popover - Proper iOS 26 Context Menu Style
    private var addBookPopover: some View {
        VStack(spacing: 0) {
            Button(action: {
                showAddBookPopover = false
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: nil)
                }
            }) {
                Label("Add Book", systemImage: "book")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: {
                showAddBookPopover = false
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: Notification.Name("ShowEnhancedBookScanner"), object: nil)
                }
            }) {
                Label("Scan Cover", systemImage: "camera")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 200)
        .glassEffect(in: .rect(cornerRadius: 12))
        .preferredColorScheme(.dark)
    }


    // MARK: - Ambient Mode
    private func startAmbientMode() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !inputText.isEmpty {
                // Start with the question
                SimplifiedAmbientCoordinator.shared.openAmbientReading(initialQuestion: inputText)
            } else if let currentBook = libraryViewModel.currentDetailBook {
                SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
            } else {
                SimplifiedAmbientCoordinator.shared.openAmbientReading()
            }
        }
    }
}