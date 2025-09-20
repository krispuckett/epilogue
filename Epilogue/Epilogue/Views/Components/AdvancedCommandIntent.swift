import SwiftUI

// MARK: - Advanced Command Intent with NLP - Perplexity Style
struct AdvancedCommandIntent: View {
    @Binding var isPresented: Bool
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel

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
            suggestions.append((
                text: "Search",
                action: {
                    performSearch(query: inputText)
                }
            ))
        }

        return Array(suggestions.prefix(3)) // Limit to 3 suggestions
    }

    var body: some View {
        ZStack {
            // Gradient background matching themes
            VStack {
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primaryAccent.opacity(0.15),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)

                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Main container - ultra minimal Perplexity style
                VStack(spacing: 12) {
                // Quick actions as pills - only when empty
                if inputText.isEmpty {
                    HStack(spacing: 12) {
                        // Add book pill
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: nil)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.8))

                                Text("Add book")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.9))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0.06)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .glassEffect(.regular, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            }
                            .shadow(color: Color.white.opacity(0.05), radius: 8, y: 2)
                        }
                        .buttonStyle(.plain)

                        // Scan pill
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: Notification.Name("ShowEnhancedBookScanner"), object: nil)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.8))

                                Text("Scan")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.9))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0.06)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .glassEffect(.regular, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            }
                            .shadow(color: Color.white.opacity(0.05), radius: 8, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    }
                }

                // Intelligent suggestions - amber tinted glass pills
                if !inputText.isEmpty && !intelligentSuggestions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(intelligentSuggestions.enumerated()), id: \.offset) { _, suggestion in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                suggestion.action()
                            } label: {
                                Text(suggestion.text)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.08))
                                    )
                                    .glassEffect(.regular, in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(
                                                DesignSystem.Colors.primaryAccent.opacity(0.3),
                                                lineWidth: 0.5
                                            )
                                    }
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 4)

                // Clean input field at BOTTOM with liquid glass and persistent button
                HStack(spacing: 12) {
                    // Text input with glass background - matching ambient session
                    HStack(spacing: 0) {
                        TextField("", text: $inputText, prompt: Text("What's on your mind?")
                            .foregroundStyle(Color.white.opacity(0.4)), axis: .vertical)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.white)
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .lineLimit(1...3)
                            .tint(DesignSystem.Colors.primaryAccent)
                            .fixedSize(horizontal: false, vertical: true)
                            .onSubmit {
                                if !inputText.isEmpty {
                                    handleSubmit()
                                }
                            }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                isInputFocused ?
                                DesignSystem.Colors.primaryAccent.opacity(0.2) :
                                Color.white.opacity(0.08),
                                lineWidth: 0.5
                            )
                    }

                    // Submit button - persistent orb outside field
                    Button {
                        if !inputText.isEmpty {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            handleSubmit()
                        } else {
                            isInputFocused = true
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    inputText.isEmpty ?
                                    DesignSystem.Colors.primaryAccent.opacity(0.2) :
                                    DesignSystem.Colors.primaryAccent
                                )
                                .frame(width: 40, height: 40)
                                .glassEffect(.regular, in: Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            DesignSystem.Colors.primaryAccent.opacity(0.3),
                                            lineWidth: 0.5
                                        )
                                }

                            Image(systemName: inputText.isEmpty ? "magnifyingglass" : "arrow.up")
                                .font(.system(size: 18, weight: inputText.isEmpty ? .medium : .semibold))
                                .foregroundStyle(
                                    inputText.isEmpty ?
                                    DesignSystem.Colors.primaryAccent.opacity(0.8) :
                                    .white
                                )
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.interactiveSpring(response: 0.3), value: inputText.isEmpty)
                }
                .padding(.horizontal, 20)
            }
                .padding(.bottom, 8)
        }
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.hidden) // We have our own
        .presentationCornerRadius(32)
        .presentationBackground(Color.clear)
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
            performSearch(query: trimmed)
        }
    }

    private func searchAndAddBook(title: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Pass the title as search query
            NotificationCenter.default.post(
                name: Notification.Name("ShowBookSearch"),
                object: ["query": title]
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
}