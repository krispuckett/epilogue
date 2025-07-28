import SwiftUI

struct ChatCommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var selectedBook: Book?
    @Binding var commandText: String
    
    @State private var searchText = ""
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // Book-focused commands
    struct Command {
        let icon: String
        let title: String
        let description: String?
        let action: CommandAction
        
        enum CommandAction {
            case switchBook
            case viewQuotes
            case viewNotes
            case askAI
            case clearContext
        }
    }
    
    let bookCommands = [
        Command(
            icon: "books.vertical",
            title: "Switch Book",
            description: "Change which book you're discussing",
            action: .switchBook
        ),
        Command(
            icon: "quote.opening",
            title: "View Quotes",
            description: "See quotes from this book",
            action: .viewQuotes
        ),
        Command(
            icon: "note.text",
            title: "View Notes",
            description: "See your notes from this book",
            action: .viewNotes
        ),
        Command(
            icon: "sparkles",
            title: "Ask AI",
            description: "Get insights about this passage",
            action: .askAI
        ),
        Command(
            icon: "xmark.circle",
            title: "Clear Book Context",
            description: nil,
            action: .clearContext
        )
    ]
    
    private var filteredCommands: [Command] {
        if searchText.isEmpty {
            return bookCommands
        }
        return bookCommands.filter { command in
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                
                TextField("Search commands or books...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        handleSubmit()
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
                            
                            if index < filteredCommands.count - 1 || !filteredBooks.isEmpty {
                                Divider()
                                    .foregroundStyle(.white.opacity(0.08))
                                    .padding(.leading, 60)
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
                            
                            if index < filteredBooks.count - 1 {
                                Divider()
                                    .foregroundStyle(.white.opacity(0.08))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    
                    // Empty state
                    if filteredCommands.isEmpty && filteredBooks.isEmpty && !searchText.isEmpty {
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
    }
    
    // MARK: - Command Row
    
    private func commandRow(command: Command) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: command.icon)
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.white.opacity(0.08))
                )
            
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
    
    // MARK: - Actions
    
    private func handleSubmit() {
        let totalItems = filteredCommands.count + filteredBooks.count
        guard totalItems > 0 else { return }
        
        // If only one result, select it
        if totalItems == 1 {
            if let command = filteredCommands.first {
                handleCommandSelection(command)
            } else if let book = filteredBooks.first {
                handleBookSelection(book)
            }
        }
    }
    
    private func handleCommandSelection(_ command: Command) {
        HapticManager.shared.lightTap()
        
        switch command.action {
        case .switchBook:
            // Show book list
            searchText = ""
        case .viewQuotes:
            commandText = "/quotes"
            dismiss()
        case .viewNotes:
            commandText = "/notes"
            dismiss()
        case .askAI:
            commandText = "/ask "
            dismiss()
        case .clearContext:
            selectedBook = nil
            dismiss()
        }
    }
    
    private func handleBookSelection(_ book: Book) {
        HapticManager.shared.lightTap()
        selectedBook = book
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
        
        VStack {
            Spacer()
            
            ChatCommandPalette(
                isPresented: .constant(true),
                selectedBook: .constant(nil),
                commandText: .constant("")
            )
            .environmentObject(LibraryViewModel())
            .padding()
        }
    }
}