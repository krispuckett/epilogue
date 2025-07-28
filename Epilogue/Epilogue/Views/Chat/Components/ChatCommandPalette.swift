import SwiftUI

struct ChatCommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var selectedBook: Book?
    @Binding var commandText: String
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var isAnimatingIn = false
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // Chat-specific commands
    enum ChatCommand: String, CaseIterable {
        case summarize = "summarize"
        case export = "export"
        case search = "search"
        
        var icon: String {
            switch self {
            case .summarize: return "doc.text.magnifyingglass"
            case .export: return "square.and.arrow.up"
            case .search: return "magnifyingglass"
            }
        }
        
        var title: String {
            switch self {
            case .summarize: return "Summarize Conversation"
            case .export: return "Export Chat"
            case .search: return "Search Messages"
            }
        }
        
        var subtitle: String {
            switch self {
            case .summarize: return "Get an AI summary of this chat"
            case .export: return "Save conversation as markdown"
            case .search: return "Find messages in this chat"
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
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            // Search field with iOS-native styling
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                
                TextField("Search commands or books", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
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
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
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
            .frame(maxHeight: 320)
        }
        .frame(maxWidth: 420)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        .scaleEffect(isAnimatingIn ? 1 : 0.95)
        .opacity(isAnimatingIn ? 1 : 0)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow downward drag
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 50 {
                        // Dismiss if dragged far enough
                        dismiss()
                    } else {
                        // Snap back to position
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
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
            // Icon with circular background like Menu style
            Image(systemName: command.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.white.opacity(isSelected ? 0.15 : 0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.9))
                
                Text(command.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .white.opacity(0.5))
            }
            
            Spacer()
            
            // Selection checkmark like native iOS menus
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.08))
                    .padding(.horizontal, 12)
            }
        }
    }
    
    // MARK: - Book Row
    
    private func bookRow(book: Book, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            if let coverURL = book.coverImageURL {
                SharedBookCoverView(coverURL: coverURL, width: 30, height: 44)
                    .cornerRadius(3)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.08))
                    .frame(width: 30, height: 44)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.9))
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if book.localId == selectedBook?.localId {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.08))
                    .padding(.horizontal, 12)
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
        case .summarize:
            // Trigger summarization (future feature)
            commandText = "Summarize this conversation"
            dismiss()
        case .export:
            // Trigger export (future feature)
            commandText = "Export chat to markdown"
            dismiss()
        case .search:
            // Open search (future feature)
            commandText = "Search: "
            dismiss()
        }
    }
    
    private func handleBookSelection(_ book: Book) {
        HapticManager.shared.lightTap()
        print("📚 ChatCommandPalette: Selected book \(book.title)")
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