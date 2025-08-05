import SwiftUI

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
        }
    }
    
    let quickCommands = [
        Command(
            icon: "note.text",
            title: "New Note",
            description: "Capture a thought or idea",
            action: .newNote
        ),
        Command(
            icon: "quote.opening",
            title: "New Quote",
            description: "Save a meaningful passage",
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
            title: "Search",
            description: "Search your library and notes",
            action: .search
        )
    ]
    
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
            .padding(.horizontal, 16)
            
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
                            .padding(.horizontal, 16)
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
                            .padding(.horizontal, 16)
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
                                .foregroundStyle(.white.opacity(0.3))
                            Text("No results found")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.top, 16)
            }
            .frame(maxHeight: 400)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            isFocused = true
        }
        .sheet(isPresented: $showBookScanner) {
            BookScannerView()
                .environmentObject(libraryViewModel)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
        HapticManager.shared.lightTap()
        
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
        }
    }
    
    private func handleBookSelection(_ book: Book) {
        HapticManager.shared.lightTap()
        // Navigate to book
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToBook"),
            object: book
        )
        dismiss()
    }
    
    private func handleNoteSelection(_ note: Note) {
        HapticManager.shared.lightTap()
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
                print("Selected: \(action)")
            }
        )
        .environmentObject(LibraryViewModel())
    }
}