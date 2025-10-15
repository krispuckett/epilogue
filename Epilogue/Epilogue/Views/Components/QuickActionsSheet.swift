import SwiftUI
import VisionKit

// MARK: - Standardized Search Field
struct StandardizedSearchField: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct QuickActionsSheet: View {
    @Binding var isPresented: Bool
    let onActionSelected: (String) -> Void
    
    @State private var searchText = ""
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @State private var showBookScanner = false
    
    // Command structure matching ChatCommandPalette
    struct Command {
        let icon: String
        let title: String
        let description: String?
        let action: CommandAction
        
        enum CommandAction {
            case newNote
            case newQuote
            case addBook
            case scanBook
            case search
            case ambientReading
        }
    }
    
    // Dynamic commands based on context
    var quickCommands: [Command] {
        var commands = [
            Command(
                icon: "note.text",
                title: "New Note",
                description: libraryViewModel.currentDetailBook.map { "Add note to \($0.title)" } ??
                    "Capture a thought or idea",
                action: .newNote
            ),
            Command(
                icon: "mic.circle",
                title: "Ambient Reading",
                description: "Start voice-powered reading session",
                action: .ambientReading
            ),
            Command(
                icon: "quote.opening",
                title: "New Quote",
                description: libraryViewModel.currentDetailBook.map { "Save quote from \($0.title)" } ??
                    "Save a meaningful passage",
                action: .newQuote
            ),
            Command(
                icon: "plus.circle",
                title: "Add Book",
                description: "Add a book to your library",
                action: .addBook
            ),
            Command(
                icon: "camera",
                title: "Scan Book Cover",
                description: "Add book by scanning its cover",
                action: .scanBook
            ),
            Command(
                icon: "magnifyingglass",
                title: "Search for Book",
                description: "Find and add books to your library",
                action: .search
            )
        ]

        // If we're in a book context, prioritize note taking
        if libraryViewModel.currentDetailBook != nil {
            // Move note to top
            return commands
        }

        return commands
    }
    
    private var filteredCommands: [Command] {
        if searchText.isEmpty {
            return quickCommands
        }
        return quickCommands.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            (command.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var filteredBooks: [Book] {
        if searchText.isEmpty || searchText.first == "/" {
            return []
        }
        return libraryViewModel.books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            book.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredNotes: [Note] {
        if searchText.isEmpty || searchText.first == "/" {
            return []
        }
        return notesViewModel.notes.filter { note in
            note.content.localizedCaseInsensitiveContains(searchText)
        }.prefix(5).map { $0 } // Limit to 5 notes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // Search bar - using standardized styles
            ZStack {
                StandardizedSearchField(
                    text: $searchText,
                    placeholder: "Search commands or books..."
                )
                .onSubmit {
                    handleSubmit()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            
            // Results
            ScrollView {
                VStack(spacing: 0) {
                    // Commands
                    if !filteredCommands.isEmpty {
                        ForEach(Array(filteredCommands.enumerated()), id: \.offset) { index, command in
                            commandRow(command: command)
                                .onTapGesture {
                                    handleCommandSelection(command)
                                }
                        }
                    }
                    
                    // Books
                    if !filteredBooks.isEmpty {
                        if !filteredCommands.isEmpty {
                            // Section separator
                            HStack {
                                Text("BOOKS")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                                Spacer()
                            }
                            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                            .padding(.vertical, 12)
                        }
                        
                        ForEach(Array(filteredBooks.enumerated()), id: \.element.id) { index, book in
                            bookRow(book: book)
                                .onTapGesture {
                                    handleBookSelection(book)
                                }
                        }
                    }
                    
                    // Notes
                    if !filteredNotes.isEmpty {
                        if !filteredCommands.isEmpty || !filteredBooks.isEmpty {
                            // Section separator
                            HStack {
                                Text("NOTES")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                                Spacer()
                            }
                            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                            .padding(.vertical, 12)
                        }
                        
                        ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                            noteRow(note: note)
                                .onTapGesture {
                                    handleNoteSelection(note)
                                }
                        }
                    }
                    
                    // Empty state
                    if filteredCommands.isEmpty && filteredBooks.isEmpty && filteredNotes.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
                            Text("No results found")
                                .font(.system(size: 15))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.top, 16)
            }
            .frame(maxHeight: 400)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 50 {
                        dismiss()
                    } else {
                        withAnimation(DesignSystem.Animation.springStandard) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            isFocused = true
        }
        .sheet(isPresented: $showBookScanner) {
            if #available(iOS 16.0, *) {
                PerfectBookScanner { book in
                    // Add book to library
                    libraryViewModel.addBook(book)

                    // Show success toast
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowBookAddedToast"),
                        object: ["message": "Added \(book.title)"]
                    )
                    SensoryFeedback.success()

                    showBookScanner = false
                }
                .onAppear {
                    #if DEBUG
                    print("🔷 QuickActionsSheet: Loading PERFECT SCANNER")
                    #endif
                }
            } else {
                BookScannerView()
                    .environmentObject(libraryViewModel)
                    .onAppear {
                        #if DEBUG
                        print("⚠️ QuickActionsSheet: Loading OLD SCANNER")
                        #endif
                    }
            }
        }
    }
    
    // MARK: - Command Row

    private func commandRow(command: Command) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: command.icon)
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 32, height: 32)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)

                if let description = command.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(command.description ?? command.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to \(command.title.lowercased())")
    }
    
    // MARK: - Book Row

    private func bookRow(book: Book) -> some View {
        HStack(spacing: 16) {
            // Book cover
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 32,
                height: 44
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .accessibilityHidden(true)

            // Book info
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title) by \(book.author)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view book details")
    }
    
    // MARK: - Note Row

    private func noteRow(note: Note) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: note.type == .quote ? "quote.opening" : "note.text")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 32, height: 32)

            // Note preview
            VStack(alignment: .leading, spacing: 2) {
                Text(note.content)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let bookTitle = note.bookTitle {
                    Text(bookTitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.type == .quote ? "Quote" : "Note"): \(note.content)\(note.bookTitle.map { " from \($0)" } ?? "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view \(note.type == .quote ? "quote" : "note") details")
    }
    
    // MARK: - Actions
    
    private func handleSubmit() {
        let totalItems = filteredCommands.count + filteredBooks.count + filteredNotes.count
        guard totalItems > 0 else { return }
        
        // If only one result, select it
        if totalItems == 1 {
            if let command = filteredCommands.first {
                handleCommandSelection(command)
            } else if let book = filteredBooks.first {
                handleBookSelection(book)
            } else if let note = filteredNotes.first {
                handleNoteSelection(note)
            }
        }
    }
    
    private func handleCommandSelection(_ command: Command) {
        SensoryFeedback.light()
        
        switch command.action {
        case .newNote:
            onActionSelected("note")
            dismiss()
        case .newQuote:
            onActionSelected("quote")
            dismiss()
        case .addBook:
            onActionSelected("addBook")
            dismiss()
        case .scanBook:
            showBookScanner = true
        case .search:
            onActionSelected("search")
            dismiss()
        case .ambientReading:
            // Start ambient reading with voice mode using simplified coordinator
            SimplifiedAmbientCoordinator.shared.openAmbientReading()
            dismiss()
        }
    }
    
    private func handleBookSelection(_ book: Book) {
        SensoryFeedback.light()
        // Navigate to book
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToBook"),
            object: book
        )
        dismiss()
    }
    
    private func handleNoteSelection(_ note: Note) {
        SensoryFeedback.light()
        // Navigate to note
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToNote"),
            object: note
        )
        dismiss()
    }
    
    private func dismiss() {
        isPresented = false
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        QuickActionsSheet(
            isPresented: .constant(true),
            onActionSelected: { action in
                #if DEBUG
                print("Selected: \(action)")
                #endif
            }
        )
        .environmentObject(LibraryViewModel())
    }
}