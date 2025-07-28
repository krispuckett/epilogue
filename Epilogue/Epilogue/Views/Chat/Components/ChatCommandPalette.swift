import SwiftUI

struct ChatCommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var selectedBook: Book?
    @Binding var commandText: String
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var isAnimatingIn = false
    @FocusState private var isFocused: Bool
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // Chat-specific commands
    enum ChatCommand: String, CaseIterable {
        case switchBook = "switch"
        case clearContext = "clear"
        case summarize = "summarize"
        case export = "export"
        case search = "search"
        
        var icon: String {
            switch self {
            case .switchBook: return "books.vertical"
            case .clearContext: return "xmark.circle"
            case .summarize: return "doc.text.magnifyingglass"
            case .export: return "square.and.arrow.up"
            case .search: return "magnifyingglass"
            }
        }
        
        var title: String {
            switch self {
            case .switchBook: return "Switch Book Context"
            case .clearContext: return "Clear Context"
            case .summarize: return "Summarize Conversation"
            case .export: return "Export Chat"
            case .search: return "Search Messages"
            }
        }
        
        var subtitle: String {
            switch self {
            case .switchBook: return "Change the book you're discussing"
            case .clearContext: return "Remove current book association"
            case .summarize: return "Get an AI summary of this chat"
            case .export: return "Save conversation as markdown"
            case .search: return "Find messages in this chat"
            }
        }
        
        var shortcut: String {
            switch self {
            case .switchBook: return "⌘B"
            case .clearContext: return "⌘⇧X"
            case .summarize: return "⌘S"
            case .export: return "⌘E"
            case .search: return "⌘F"
            }
        }
    }
    
    private var filteredCommands: [ChatCommand] {
        if searchText.isEmpty {
            return ChatCommand.allCases
        }
        return ChatCommand.allCases.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            command.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredBooks: [Book] {
        if !searchText.isEmpty && searchText.first != "/" {
            return libraryViewModel.books.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        return []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "command")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                TextField("Type a command or book name...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .focused($isFocused)
                    .onSubmit {
                        handleSelection()
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 0))
            
            Divider()
                .foregroundStyle(.white.opacity(0.1))
            
            // Results
            ScrollView {
                VStack(spacing: 0) {
                    // Commands section
                    if !filteredCommands.isEmpty {
                        if !filteredBooks.isEmpty {
                            sectionHeader("Commands")
                        }
                        
                        ForEach(Array(filteredCommands.enumerated()), id: \.element) { index, command in
                            commandRow(command: command, isSelected: selectedIndex == index)
                                .onTapGesture {
                                    handleCommandSelection(command)
                                }
                        }
                    }
                    
                    // Books section
                    if !filteredBooks.isEmpty {
                        sectionHeader("Books")
                            .padding(.top, filteredCommands.isEmpty ? 0 : 8)
                        
                        ForEach(Array(filteredBooks.enumerated()), id: \.element.id) { index, book in
                            bookRow(book: book, isSelected: selectedIndex == filteredCommands.count + index)
                                .onTapGesture {
                                    handleBookSelection(book)
                                }
                        }
                    }
                    
                    // Empty state
                    if filteredCommands.isEmpty && filteredBooks.isEmpty && !searchText.isEmpty {
                        emptyStateView
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)
        }
        .frame(maxWidth: 500)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .scaleEffect(isAnimatingIn ? 1 : 0.95)
        .opacity(isAnimatingIn ? 1 : 0)
        .onAppear {
            isFocused = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isAnimatingIn = true
            }
            
            // Process initial command text
            if commandText.hasPrefix("/") {
                searchText = String(commandText.dropFirst())
            }
        }
        .onDisappear {
            commandText = ""
        }
        .onKeyPress(.upArrow) {
            moveSelection(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(1)
            return .handled
        }
        .onKeyPress(.return) {
            handleSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
    
    // MARK: - Command Row
    
    private func commandRow(command: ChatCommand, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: command.icon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.9))
                
                Text(command.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .white.opacity(0.6))
            }
            
            Spacer()
            
            Text(command.shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.white.opacity(isSelected ? 0.3 : 0.2), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.1))
                    .padding(.horizontal, 8)
            }
        }
    }
    
    // MARK: - Book Row
    
    private func bookRow(book: Book, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            if let coverURL = book.coverImageURL {
                SharedBookCoverView(coverURL: coverURL, width: 32, height: 48)
                    .cornerRadius(4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.1))
                    .frame(width: 32, height: 48)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.9))
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if book.localId == selectedBook?.localId {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.1))
                    .padding(.horizontal, 8)
            }
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No results for \"\(searchText)\"")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Actions
    
    private func handleSelection() {
        let totalItems = filteredCommands.count + filteredBooks.count
        guard totalItems > 0 else { return }
        
        if selectedIndex < filteredCommands.count {
            handleCommandSelection(filteredCommands[selectedIndex])
        } else {
            let bookIndex = selectedIndex - filteredCommands.count
            if bookIndex < filteredBooks.count {
                handleBookSelection(filteredBooks[bookIndex])
            }
        }
    }
    
    private func handleCommandSelection(_ command: ChatCommand) {
        HapticManager.shared.lightTap()
        
        switch command {
        case .switchBook:
            // Show book picker
            searchText = ""
        case .clearContext:
            selectedBook = nil
            dismiss()
        case .summarize:
            // TODO: Trigger summarization
            dismiss()
        case .export:
            // TODO: Trigger export
            dismiss()
        case .search:
            // TODO: Open search
            dismiss()
        }
    }
    
    private func handleBookSelection(_ book: Book) {
        HapticManager.shared.lightTap()
        selectedBook = book
        dismiss()
    }
    
    private func moveSelection(_ direction: Int) {
        let totalItems = filteredCommands.count + filteredBooks.count
        guard totalItems > 0 else { return }
        
        selectedIndex = (selectedIndex + direction + totalItems) % totalItems
        HapticManager.shared.selectionChanged()
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isAnimatingIn = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ChatCommandPalette(
            isPresented: .constant(true),
            selectedBook: .constant(nil),
            commandText: .constant("/")
        )
        .environmentObject(LibraryViewModel())
        .padding()
    }
}