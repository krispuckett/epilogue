import SwiftUI

struct NotesView: View {
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    
    @State private var selectedFilter: NoteType? = nil
    @State private var showingAddNote = false
    @State private var noteToEdit: Note? = nil
    @State private var editingNote: Note? = nil
    @State private var openOptionsNoteId: UUID? = nil
    @State private var highlightedNoteId: UUID? = nil
    @State private var scrollToNoteId: UUID? = nil
    @State private var contextMenuNote: Note? = nil
    @State private var contextMenuSourceRect: CGRect = .zero
    
    // View style toggle
    enum NotesViewStyle: String {
        case grid = "grid"
        case stack = "list"
        
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .stack: return "square.stack.3d.up"
            }
        }
    }
    @AppStorage("notesViewStyle") private var viewStyle: NotesViewStyle = .grid
    
    // Search states
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .all
    @State private var searchTokens: [SearchToken] = []
    @State private var searchDebounceTask: Task<Void, Never>?
    
    @Namespace private var commandPaletteNamespace
    @Namespace private var noteTransition
    
    // Search scopes
    enum SearchScope: String, CaseIterable {
        case all = "All"
        case quotes = "Quotes"
        case notes = "Notes"
        case books = "Books"
        
        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .quotes: return "quote.opening"
            case .notes: return "note.text"
            case .books: return "book.closed"
            }
        }
    }
    
    // Search tokens
    enum SearchToken: Identifiable, Hashable {
        case book(String)
        case tag(String)
        case type(NoteType)
        
        var id: String {
            switch self {
            case .book(let name): return "book:\(name)"
            case .tag(let tag): return "tag:\(tag)"
            case .type(let type): return "type:\(type.rawValue)"
            }
        }
        
        var displayText: String {
            switch self {
            case .book(let name): return "@\(name)"
            case .tag(let tag): return "#\(tag)"
            case .type(let type): return type == .quote ? "\"quote\"" : "note"
            }
        }
    }
    
    // Cached filtered notes to avoid expensive recomputation
    @State private var cachedFilteredNotes: [Note] = []
    @State private var lastFilterKey: String = ""
    
    // Filtered notes based on filter and search
    private var filteredNotes: [Note] {
        // Create a cache key from current filter state
        let filterKey = "\(selectedFilter?.rawValue ?? "nil")|\(searchScope.rawValue)|\(searchText)|\(searchTokens.map(\.id).joined(separator: ","))"
        
        // Return cached results if filter hasn't changed
        if filterKey == lastFilterKey && !cachedFilteredNotes.isEmpty {
            return cachedFilteredNotes
        }
        
        // Recompute and cache
        let result = computeFilteredNotes()
        cachedFilteredNotes = result
        lastFilterKey = filterKey
        return result
    }
    
    // Separated computation for clarity
    private func computeFilteredNotes() -> [Note] {
        var filtered = notesViewModel.notes
        
        // Apply type filter
        if let selectedFilter = selectedFilter {
            filtered = filtered.filter { $0.type == selectedFilter }
        }
        
        // Apply search scope
        switch searchScope {
        case .all:
            break // No additional filtering
        case .quotes:
            filtered = filtered.filter { $0.type == .quote }
        case .notes:
            filtered = filtered.filter { $0.type == .note }
        case .books:
            // Filter to only notes with book context
            filtered = filtered.filter { $0.bookTitle != nil }
        }
        
        // Apply search tokens
        for token in searchTokens {
            switch token {
            case .book(let bookName):
                filtered = filtered.filter { note in
                    note.bookTitle?.localizedCaseInsensitiveContains(bookName) ?? false
                }
            case .tag(let tag):
                // For now, search in content for hashtags
                filtered = filtered.filter { note in
                    note.content.localizedCaseInsensitiveContains("#\(tag)")
                }
            case .type(let type):
                filtered = filtered.filter { $0.type == type }
            }
        }
        
        // Apply search text (fuzzy search)
        if !searchText.isEmpty {
            let searchTerms = searchText.lowercased().components(separatedBy: .whitespaces)
            filtered = filtered.filter { note in
                let searchableText = "\(note.content) \(note.bookTitle ?? "") \(note.author ?? "")".lowercased()
                return searchTerms.allSatisfy { searchableText.contains($0) }
            }
        }
        
        return filtered.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    // Parse search text for tokens
    private func parseSearchTokens(from text: String) {
        var tokens: [SearchToken] = []
        let components = text.components(separatedBy: .whitespaces)
        
        for component in components {
            if component.hasPrefix("@") && component.count > 1 {
                let bookName = String(component.dropFirst())
                tokens.append(.book(bookName))
            } else if component.hasPrefix("#") && component.count > 1 {
                let tag = String(component.dropFirst())
                tokens.append(.tag(tag))
            } else if component.lowercased() == "type:quote" || component == "\"quote\"" {
                tokens.append(.type(.quote))
            } else if component.lowercased() == "type:note" {
                tokens.append(.type(.note))
            }
        }
        
        searchTokens = tokens
    }
    
    // Helper function to create note card view
    @ViewBuilder
    private func noteCardView(for note: Note) -> some View {
        NoteCard(
            note: note,
            isSelectionMode: false,
            isSelected: false,
            onSelectionToggle: { },
            openOptionsNoteId: $openOptionsNoteId,
            onContextMenuRequest: { note, rect in
                contextMenuNote = note
                contextMenuSourceRect = rect
            }
        )
        .environmentObject(notesViewModel)
        .matchedTransitionSource(id: note.id, in: noteTransition)
        .id(note.id)
        .overlay(highlightOverlay(for: note))
        .transition(.glassAppear)
        .onTapGesture(count: 2) {
            // Direct test - bypass the callback chain
            HapticManager.shared.mediumTap()
            contextMenuNote = note
            contextMenuSourceRect = CGRect(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2, width: 100, height: 100)
        }
    }
    
    // Helper function for highlight overlay
    @ViewBuilder
    private func highlightOverlay(for note: Note) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 1.5)
            .opacity(highlightedNoteId == note.id ? 0.8 : 0)
            .blur(radius: 0.5)
            .animation(.easeInOut(duration: 0.3), value: highlightedNoteId)
    }
    
    var body: some View {
        // Use the clean notes view for now
        CleanNotesView()
            .environmentObject(notesViewModel)
            .environmentObject(libraryViewModel)
    }
    
    // MARK: - Filter Pills Header
    @ViewBuilder
    private var filterPillsHeader: some View {
        HStack(spacing: 8) {
            FilterPill(
                title: "All",
                count: notesViewModel.notes.count,
                isActive: selectedFilter == nil,
                action: { selectedFilter = nil }
            )
            
            FilterPill(
                title: "Quote",
                count: notesViewModel.notes.filter { $0.type == .quote }.count,
                icon: "quote.opening",
                isActive: selectedFilter == .quote,
                action: { selectedFilter = selectedFilter == .quote ? nil : .quote }
            )
            
            FilterPill(
                title: "Note",
                count: notesViewModel.notes.filter { $0.type == .note }.count,
                icon: "note.text",
                isActive: selectedFilter == .note,
                action: { selectedFilter = selectedFilter == .note ? nil : .note }
            )
            
            Spacer()
            
            viewStyleToggleButton
        }
        .padding(.horizontal)
    }
    
    // MARK: - View Style Toggle Button
    @ViewBuilder
    private var viewStyleToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewStyle = viewStyle == .grid ? .stack : .grid
                HapticManager.shared.lightTap()
            }
        }) {
            Image(systemName: viewStyle.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 36, height: 36)
                .glassEffect(
                    .regular.tint(Color.white.opacity(0.05)),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
    
    // MARK: - Notes Grid Content
    @ViewBuilder
    private var notesGridContent: some View {
        if filteredNotes.isEmpty {
            EmptyNotesView(
                searchText: searchText,
                selectedFilter: selectedFilter,
                searchScope: searchScope
            )
            .frame(minHeight: 400)
            .padding(.top, 60)
        } else if viewStyle == .grid {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                ForEach(filteredNotes) { note in
                    noteCardView(for: note)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Add Note Toolbar Button
    @ViewBuilder
    private var addNoteToolbarButton: some View {
        GlassEffectContainer(spacing: 0) {
            Button(action: { showingAddNote = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    .frame(width: 44, height: 44)
            }
            .glassEffect(
                .regular,
                in: Circle()
            )
        }
    }
    
    // MARK: - Context Menu Overlay
    @ViewBuilder
    private var contextMenuOverlay: some View {
        if let contextMenuNote = contextMenuNote {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    self.contextMenuNote = nil
                }
            
            NoteContextMenu(
                note: contextMenuNote,
                sourceRect: contextMenuSourceRect,
                isPresented: Binding(
                    get: { self.contextMenuNote != nil },
                    set: { if !$0 { self.contextMenuNote = nil } }
                )
            )
            .environmentObject(notesViewModel)
            .zIndex(1000)
        }
    }
    
    // MARK: - Main Grid View (Simplified)
    var mainGridView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        filterPillsHeader
                        notesGridContent
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
                .onChange(of: scrollToNoteId) { _, noteId in
                    if let noteId = noteId {
                        withAnimation(SmoothAnimationType.smooth.animation) {
                            proxy.scrollTo(noteId, anchor: .center)
                        }
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            scrollToNoteId = nil
                        }
                    }
                }
            }
            
            contextMenuOverlay
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notes, quotes, and books")
        .searchScopes($searchScope) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Label(scope.rawValue, systemImage: scope.icon)
                    .tag(scope)
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled {
                    parseSearchTokens(from: newValue)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addNoteToolbarButton
            }
        }
        .sheet(isPresented: $showingAddNote) {
            LiquidCommandPalette(
                isPresented: $showingAddNote,
                animationNamespace: commandPaletteNamespace,
                bookContext: nil
            )
            .environmentObject(notesViewModel)
            .environmentObject(libraryViewModel)
        }
        .sheet(item: $noteToEdit) { note in
            LiquidCommandPalette(
                isPresented: .constant(true),
                animationNamespace: commandPaletteNamespace,
                initialContent: formatNoteForEditing(note),
                editingNote: note,
                onUpdate: { updatedNote in
                    notesViewModel.updateNote(updatedNote)
                    noteToEdit = nil
                },
                bookContext: nil  // No specific book context when editing existing notes
            )
            .environmentObject(notesViewModel)
            .environmentObject(libraryViewModel)
            .onDisappear {
                noteToEdit = nil
                notesViewModel.isEditingNote = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EditNote"))) { notification in
            if let note = notification.object as? Note {
                editingNote = note
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToNote"))) { notification in
            if let note = notification.object as? Note {
                // Scroll to and highlight the note
                scrollToNoteId = note.id
                highlightedNoteId = note.id
                
                // Remove highlight after a delay, then open for editing
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(SmoothAnimationType.gentle.animation) {
                        highlightedNoteId = nil
                    }
                    // Open the note for editing
                    editingNote = note
                }
            }
        }
        .sheet(item: $editingNote) { note in
            NoteEditSheet(note: note)
                .environmentObject(notesViewModel)
        }
        .sensoryFeedback(.impact, trigger: editingNote)
    }
    
    private func formatNoteForEditing(_ note: Note) -> String {
        switch note.type {
        case .note:
            return "note: \(note.content)"
        case .quote:
            var cleanContent = note.content.trimmingCharacters(in: .whitespaces)
            
            while cleanContent.hasSuffix("-") || cleanContent.hasSuffix("—") {
                cleanContent = String(cleanContent.dropLast()).trimmingCharacters(in: .whitespaces)
            }
            
            var formatted = "\"\(cleanContent)\""
            if let author = note.author {
                formatted += " - \(author)"
                if let bookTitle = note.bookTitle {
                    formatted += ", \(bookTitle)"
                    if let pageNumber = note.pageNumber {
                        formatted += ", p. \(pageNumber)"
                    }
                }
            }
            return formatted
        }
    }
}

// MARK: - Filter Type Definition
enum FilterType: String, CaseIterable {
    case all = "All"
    case notes = "Notes"
    case quotes = "Quotes"
}

// MARK: - Note Type to Filter Type Extension
extension NoteType {
    func toFilterType() -> FilterType {
        switch self {
        case .quote: return .quotes
        case .note: return .notes
        }
    }
}

// MARK: - Simple Filter Pill
struct FilterPill: View {
    let title: String
    let count: Int
    var icon: String? = nil
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text("(\(count))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(isActive ? .white : .white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassEffect(
                isActive ? 
                    .regular.tint(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3)) :
                    .regular.tint(Color.white.opacity(0.05)),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isActive ?
                            Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4) :
                            Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Empty State View
struct EmptyNotesView: View {
    let searchText: String
    let selectedFilter: NoteType?
    let searchScope: NotesView.SearchScope
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: emptyStateIcon)
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.5))
            
            // Title
            Text(emptyStateTitle)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            
            // Subtitle
            Text(emptyStateSubtitle)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            // Quick action suggestions
            if searchText.isEmpty && selectedFilter == nil {
                VStack(spacing: 12) {
                    Text("Quick Actions")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    HStack(spacing: 12) {
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("ShowCommandPalette"), object: nil)
                        } label: {
                            Label("Add Note", systemImage: "note.text.badge.plus")
                                .font(.system(size: 14))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .glassEffect(in: Capsule())
                        }
                        
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("ShowCommandPalette"), object: nil)
                        } label: {
                            Label("Add Quote", systemImage: "quote.opening")
                                .font(.system(size: 14))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .glassEffect(in: Capsule())
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
    }
    
    private var emptyStateIcon: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        } else if selectedFilter == .quote {
            return "quote.opening"
        } else if selectedFilter == .note {
            return "note.text"
        } else {
            return "note.text.badge.plus"
        }
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No results found"
        } else if selectedFilter == .quote {
            return "No quotes yet"
        } else if selectedFilter == .note {
            return "No notes yet"
        } else {
            return "Start capturing"
        }
    }
    
    private var emptyStateSubtitle: String {
        if !searchText.isEmpty {
            return "Try searching with different keywords or filters"
        } else if selectedFilter == .quote {
            return "Highlight memorable passages from your reading"
        } else if selectedFilter == .note {
            return "Jot down thoughts and reflections"
        } else {
            return "Capture quotes, notes, and thoughts from your reading journey"
        }
    }
}