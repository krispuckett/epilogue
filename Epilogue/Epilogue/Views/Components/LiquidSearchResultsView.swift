import SwiftUI

struct LiquidSearchResultsView: View {
    let searchText: String
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @StateObject private var historyManager = CommandHistoryManager.shared
    
    @State private var detectedBook: Book?
    @State private var detectedNote: Note?
    @State private var showRecentCommands = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 8) {
            // Show recent commands when focused but not typing
            if searchText.isEmpty && showRecentCommands && !historyManager.recentCommands.isEmpty {
                ForEach(Array(historyManager.recentCommands.prefix(3).enumerated()), id: \.element.id) { index, command in
                    RecentCommandCard(
                        command: command,
                        opacity: 1.0 - (Double(index) * 0.2),
                        scale: 1.0 - (CGFloat(index) * 0.05),
                        action: {
                            // Handle tapping recent command
                            handleRecentCommand(command)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }
            
            // Show detected book as a card (only after search)
            if hasSearched, let book = detectedBook {
                BookResultCard(book: book) {
                    handleBookTap(book)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            // Show detected note as a card (only after search)
            if hasSearched, let note = detectedNote {
                NoteResultCard(note: note) {
                    handleNoteTap(note)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: searchText)
        .onChange(of: searchText) { _, newValue in
            // Cancel previous search
            searchTask?.cancel()
            
            if newValue.isEmpty {
                detectedBook = nil
                detectedNote = nil
                hasSearched = false
                showRecentCommands = true
            } else {
                showRecentCommands = false
                
                // Debounce search - wait 500ms before searching
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    if !Task.isCancelled {
                        hasSearched = true
                        performSmartSearch(newValue)
                    }
                }
            }
        }
        .onAppear {
            showRecentCommands = true
        }
    }
    
    // MARK: - Public Search Method
    
    func triggerSearch() {
        hasSearched = true
        performSmartSearch(searchText)
    }
    
    // MARK: - Search Logic
    
    private func performSmartSearch(_ query: String) {
        // Hide recent commands when typing
        if !query.isEmpty {
            showRecentCommands = false
        }
        
        // Clear results if query is too short (require at least 3 chars to reduce bouncing)
        guard query.count >= 3 else {
            detectedBook = nil
            detectedNote = nil
            return
        }
        
        // Parse the intent (for command history tracking)
        _ = CommandParser.parse(query, books: libraryViewModel.books, notes: notesViewModel.notes)
        
        // Show cards based on what we find
        withAnimation(DesignSystem.Animation.springStandard) {
            // Check for exact book match first
            if let book = libraryViewModel.books.first(where: { 
                $0.title.localizedCaseInsensitiveContains(query) || 
                $0.author.localizedCaseInsensitiveContains(query) 
            }) {
                detectedBook = book
                detectedNote = nil
            }
            // Check for note match
            else if let note = notesViewModel.notes.first(where: { 
                $0.content.localizedCaseInsensitiveContains(query) 
            }) {
                detectedNote = note
                detectedBook = nil
            }
            // Nothing found
            else {
                detectedBook = nil
                detectedNote = nil
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleRecentCommand(_ command: RecentCommand) {
        SensoryFeedback.light()
        
        // Re-execute the recent command based on its type
        switch command.intentType {
        case "book":
            // Search for the book
            if let book = libraryViewModel.books.first(where: { 
                $0.title.localizedCaseInsensitiveContains(command.text) 
            }) {
                handleBookTap(book)
            } else {
                // Open book search
                NotificationCenter.default.post(
                    name: Notification.Name("ShowBookSearch"),
                    object: command.text
                )
            }
        case "note", "quote":
            // Find the note
            if let note = notesViewModel.notes.first(where: { 
                $0.content.localizedCaseInsensitiveContains(command.text) 
            }) {
                handleNoteTap(note)
            }
        default:
            break
        }
    }
    
    private func handleBookTap(_ book: Book) {
        SensoryFeedback.light()
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToBook"),
            object: book
        )
    }
    
    private func handleNoteTap(_ note: Note) {
        SensoryFeedback.light()
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToNote"),
            object: note
        )
    }
}

// MARK: - Book Result Card (Simplified)

struct BookResultCard: View {
    let book: Book
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Book cover
                SharedBookCoverView(
                    coverURL: book.coverImageURL,
                    width: 40,
                    height: 56
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                
                // Book info
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text("by \(book.author)")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.inlinePadding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .fill(DesignSystem.Colors.surfaceBackground) // Dark charcoal matching NotesView
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.springStandard, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
}

// MARK: - Note Result Card (Simplified)

struct NoteResultCard: View {
    let note: Note
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Type indicator
                HStack {
                    Image(systemName: note.type == .quote ? "quote.opening" : "note.text")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    
                    Text(note.type == .quote ? "Quote" : "Note")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(note.formattedDate)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                
                // Content preview
                Text(note.content)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Book context if available
                if let bookTitle = note.bookTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 11))
                        Text(bookTitle)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(DesignSystem.Spacing.inlinePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .fill(DesignSystem.Colors.surfaceBackground) // Dark charcoal matching NotesView
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.springStandard, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            LiquidSearchResultsView(searchText: "")
                .environmentObject(LibraryViewModel())
                .environmentObject(NotesViewModel())
                .padding()
        }
    }
}