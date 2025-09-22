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
                                    // Clean input field that looks like placeholder
                                    TextField(placeholderText, text: $searchText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                                    .tint(themeManager.currentTheme.primaryAccent)
                                    .lineLimit(1...3)  // Allow some expansion when collapsed
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

                        // Right side buttons
                        HStack(spacing: 14) {
                            // In Notes tab, always show up arrow. Otherwise show submit/orb
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
                                // Submit button when there's text - with liquid glass
                                if shouldShowSubmitButton {
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
                                    .transition(.scale.combined(with: .opacity))
                                }

                                // Ambient orb (always shown except in Notes tab)
                                Button {
                                    startAmbientMode()
                                } label: {
                                    AmbientOrbButton(size: 36) {
                                        // Action handled by parent
                                    }
                                    .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

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
                // Glass effect matching ambient mode
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.001)) // Nearly invisible for glass
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .clipShape(RoundedRectangle(cornerRadius: 20)) // CLIP CONTENT TO CARD BOUNDS
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryAccent.opacity(0.25),
                                    themeManager.currentTheme.primaryAccent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: themeManager.currentTheme.primaryAccent.opacity(0.15), radius: 16, y: 6)
                .padding(.horizontal, 20)
                .padding(.bottom, 20) // Closer to bottom since action bar is hidden
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
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
        isFocused = true
        SensoryFeedback.light()
    }

    private func collapseCard() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isExpanded = false
        }
        SensoryFeedback.light()
    }

    private func processInput() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Parse command
        if trimmed.hasPrefix("note:") || trimmed.hasPrefix("n:") {
            let noteContent = trimmed.replacingOccurrences(of: "note:", with: "")
                             .replacingOccurrences(of: "n:", with: "")
                             .trimmingCharacters(in: .whitespaces)
            createNote(noteContent)
        } else if trimmed.hasPrefix("\"") {
            createQuote(trimmed)
        } else if trimmed.lowercased().contains("book") || trimmed.lowercased().contains("add") {
            // Book search
            showBookSearch = true
        } else {
            // Default to note - check if we're in notes tab
            if navigationCoordinator.selectedTab == .notes {
                // Always create a note in notes tab
                createNote(trimmed)
            } else if trimmed.contains("?") {
                // Question - could trigger AI
                createNote(trimmed)
            } else {
                // Default to note
                createNote(trimmed)
            }
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

    private func createNote(_ text: String) {
        // Use selected book context if available, otherwise current detail book
        let book = selectedBookContext ?? libraryViewModel.currentDetailBook
        let note = Note(
            type: .note,
            content: text.isEmpty ? "New note" : text,
            bookId: book?.localId,
            bookTitle: book?.title,
            author: book?.author,
            pageNumber: nil
        )
        notesViewModel.addNote(note)
        SensoryFeedback.success()
    }

    private func createQuote(_ text: String) {
        let content = text.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let book = selectedBookContext ?? libraryViewModel.currentDetailBook
        let quote = Note(
            type: .quote,
            content: content,
            bookId: book?.localId,
            bookTitle: book?.title,
            author: book?.author,
            pageNumber: nil
        )
        notesViewModel.addNote(quote)
        SensoryFeedback.success()
    }

    private func startAmbientMode() {
        if let currentBook = libraryViewModel.currentDetailBook {
            SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
        } else {
            SimplifiedAmbientCoordinator.shared.openAmbientReading()
        }
        collapseCard()
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