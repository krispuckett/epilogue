import SwiftUI
import SwiftData

struct CleanNotesView: View {
    @EnvironmentObject private var notesViewModel: NotesViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared

    @Query(sort: \CapturedNote.timestamp, order: .reverse) private var capturedNotes: [CapturedNote]
    @Query(sort: \CapturedQuote.timestamp, order: .reverse) private var capturedQuotes: [CapturedQuote]
    
    @State private var selectedFilter: FilterType = .all
    @State private var searchText = ""
    @State private var showEditSheet = false
    @State private var editingNote: CapturedNote?
    @State private var editingQuote: CapturedQuote?
    @State private var editedText = ""
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: Any?
    @State private var settingsButtonPressed = false
    @State private var showSearchBar = false
    @State private var showingSessionSummary = false
    @State private var selectedSessionNote: CapturedNote?
    @State private var selectedSessionQuote: CapturedQuote?
    @State private var collapsedSections: Set<String> = []
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var scrollOffset: CGFloat = 0
    @State private var quoteShareData: QuoteShareData?
    @Namespace private var animation

    struct QuoteShareData: Identifiable {
        let id = UUID()
        let text: String
        let author: String?
        let bookTitle: String?
    }
    
    // Toast notification state
    @State private var toastMessage = ""
    @State private var showingToast = false

    // Export state
    enum ExportContent: Identifiable {
        case singleNote(CapturedNote)
        case singleQuote(CapturedQuote)
        case batch(notes: [CapturedNote], quotes: [CapturedQuote])

        var id: String {
            switch self {
            case .singleNote(let note): return note.id?.uuidString ?? UUID().uuidString
            case .singleQuote(let quote): return quote.id?.uuidString ?? UUID().uuidString
            case .batch: return "batch_\(UUID().uuidString)"
            }
        }
    }

    @State private var exportContent: ExportContent?

    enum FilterType: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case notes = "Notes"
        case quotes = "Quotes"
        case byBook = "By Book"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .favorites: return "star.fill"
            case .notes: return "note.text"
            case .quotes: return "quote.opening"
            case .byBook: return "books.vertical"
            }
        }

        var description: String {
            switch self {
            case .all: return "All Items"
            case .favorites: return "Favorites"
            case .notes: return "Notes Only"
            case .quotes: return "Quotes Only"
            case .byBook: return "Group by Book"
            }
        }
    }
    
    // Combined items (unfiltered)
    private var allItems: [(date: Date, note: Note?, quote: CapturedQuote?)] {
        var items: [(date: Date, note: Note?, quote: CapturedQuote?)] = []
        
        // Add notes
        items += capturedNotes.map { capturedNote in
            (date: capturedNote.timestamp ?? Date(), note: capturedNote.toNote(), quote: nil)
        }
        
        // Add quotes
        items += capturedQuotes.map { (date: $0.timestamp ?? Date(), note: nil, quote: $0) }
        
        // Sort by date
        items.sort { $0.date > $1.date }
        
        return items
    }
    
    // Filtered items with search and filter
    private var filteredItems: [(date: Date, note: Note?, quote: CapturedQuote?)] {
        var items = allItems

        // Apply type filter
        switch selectedFilter {
        case .favorites:
            items = items.filter { item in
                if let note = item.note {
                    // Find the captured note and check if it's favorited
                    return capturedNotes.first(where: { $0.id == note.id })?.isFavorite == true
                } else if let quote = item.quote {
                    return quote.isFavorite == true
                }
                return false
            }
        case .notes:
            items = items.filter { $0.note != nil }
        case .quotes:
            items = items.filter { $0.quote != nil }
        case .all, .byBook:
            break
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter { item in
                if let note = item.note {
                    return note.content.lowercased().contains(query) ||
                           (note.bookTitle?.lowercased().contains(query) ?? false) ||
                           (note.author?.lowercased().contains(query) ?? false)
                } else if let quote = item.quote {
                    return (quote.text ?? "").lowercased().contains(query) ||
                           (quote.book?.title.lowercased().contains(query) ?? false) ||
                           (quote.author?.lowercased().contains(query) ?? false)
                }
                return false
            }
        }
        
        return items
    }
    
    // Group items by relative time or book
    private var groupedItems: [(String, [(date: Date, note: Note?, quote: CapturedQuote?)])] {
        if selectedFilter == .byBook {
            // Group by book
            var groups: [String: [(date: Date, note: Note?, quote: CapturedQuote?)]] = [:]
            
            for item in filteredItems {
                let section: String
                if let note = item.note, let bookTitle = note.bookTitle {
                    section = bookTitle
                } else if let quote = item.quote, let bookTitle = quote.book?.title {
                    section = bookTitle
                } else {
                    section = "No Book"
                }
                
                if groups[section] == nil {
                    groups[section] = []
                }
                groups[section]?.append(item)
            }
            
            // Sort by book name, with "No Book" last
            return groups.sorted { (lhs, rhs) in
                if lhs.key == "No Book" { return false }
                if rhs.key == "No Book" { return true }
                return lhs.key < rhs.key
            }
        } else {
            // Group by time
            let calendar = Calendar.current
            let now = Date()
            
            var groups: [String: [(date: Date, note: Note?, quote: CapturedQuote?)]] = [:]
            
            for item in filteredItems {
                let section: String
                
                if calendar.isDateInToday(item.date) {
                    section = "Today"
                } else if calendar.isDateInYesterday(item.date) {
                    section = "Yesterday"
                } else if item.date > now.addingTimeInterval(-7 * 24 * 60 * 60) {
                    section = "This Week"
                } else if item.date > now.addingTimeInterval(-30 * 24 * 60 * 60) {
                    section = "This Month"
                } else {
                    section = "Earlier"
                }
                
                if groups[section] == nil {
                    groups[section] = []
                }
                groups[section]?.append(item)
            }
            
            // Order sections
            let sectionOrder = ["Today", "Yesterday", "This Week", "This Month", "Earlier"]
            var result: [(String, [(date: Date, note: Note?, quote: CapturedQuote?)])] = []
            
            for section in sectionOrder {
                if let items = groups[section] {
                    result.append((section, items))
                }
            }
            
            return result
        }
    }
    
    @ViewBuilder
    private var searchBarView: some View {
        if showSearchBar {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.4))
                
                TextField("Search notes and quotes", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Search notes and quotes")
                    .accessibilityHint("Type to search through your notes and quotes")
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.textQuaternary)
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Double tap to clear search text")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .padding(.bottom, 20)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Permanent ambient gradient background
                AmbientChatGradientView()
                    .opacity(0.4)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                
                // Subtle darkening overlay for better readability
                Color.black.opacity(0.15)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Progressive Search Bar
                        searchBarView
                        
                        // Content
                        if filteredItems.isEmpty {
                            emptyState
                        } else {
                            contentSections
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                
                // Toast overlay
                if showingToast {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignSystem.Colors.primaryAccent)
                            
                            Text(toastMessage)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .glassEffect(in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            DesignSystem.Colors.primaryAccent.opacity(0.3),
                                            DesignSystem.Colors.primaryAccent.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                        .padding(.bottom, 100)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingToast)
                }
            }
                .navigationTitle("Notes")
                .navigationBarTitleDisplayMode(.large)
            .onReceive(navigationCoordinator.$highlightedNoteID) { noteID in
                if let noteID = noteID {
                    // Find and scroll to the note
                    if let note = capturedNotes.first(where: { $0.id == noteID }) {
                        // Show edit sheet for the note
                        editingNote = note
                        editedText = note.content ?? ""
                        notesViewModel.isEditingNote = true
                        showEditSheet = true

                        // Clear the navigation flag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            navigationCoordinator.highlightedNoteID = nil
                        }
                    }
                }
            }
            .onReceive(navigationCoordinator.$highlightedQuoteID) { quoteID in
                if let quoteID = quoteID {
                    // Find and scroll to the quote
                    if let quote = capturedQuotes.first(where: { $0.id == quoteID }) {
                        // Show edit sheet for the quote
                        editingQuote = quote
                        editedText = quote.text ?? ""
                        notesViewModel.isEditingNote = true
                        showEditSheet = true

                        // Clear the navigation flag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            navigationCoordinator.highlightedQuoteID = nil
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CreateNewNote"))) { notification in
                #if DEBUG
                print("📝 CleanNotesView: Received CreateNewNote notification")
                #endif
                if let data = notification.object as? [String: Any],
                   let content = data["content"] as? String {
                    #if DEBUG
                    print("📝 Note content: \(content)")
                    #endif
                    let bookId = data["bookId"] as? String
                    let bookTitle = data["bookTitle"] as? String
                    let bookAuthor = data["bookAuthor"] as? String
                    #if DEBUG
                    print("📝 Book context: ID=\(bookId ?? "nil"), Title=\(bookTitle ?? "nil"), Author=\(bookAuthor ?? "nil")")
                    #endif
                    createNote(content: content, bookId: bookId, bookTitle: bookTitle, bookAuthor: bookAuthor)
                } else {
                    #if DEBUG
                    print("❌ Failed to parse notification data")
                    #endif
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SaveQuote"))) { notification in
                if let data = notification.object as? [String: Any],
                   let quote = data["quote"] as? String {
                    let attribution = data["attribution"] as? String
                    let bookId = data["bookId"] as? String
                    let bookTitle = data["bookTitle"] as? String
                    let bookAuthor = data["bookAuthor"] as? String
                    createQuote(content: quote, attribution: attribution?.isEmpty ?? true ? nil : attribution, 
                               bookId: bookId, bookTitle: bookTitle, bookAuthor: bookAuthor)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowToastMessage"))) { notification in
                if let data = notification.object as? [String: String],
                   let message = data["message"] {
                    showToast(message: message)
                }
            }
            .toolbar {
                // Push content to the right
                ToolbarSpacer(.flexible)
                
                // Search button
                ToolbarItem {
                    Button {
                        withAnimation(DesignSystem.Animation.springStandard) {
                            showSearchBar.toggle()
                            if !showSearchBar {
                                searchText = ""
                            }
                        }
                        SensoryFeedback.light()
                    } label: {
                        Image(systemName: showSearchBar ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(showSearchBar ? DesignSystem.Colors.primaryAccent : .white.opacity(0.8))
                            .symbolRenderingMode(.hierarchical)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(showSearchBar ? "Close search" : "Search notes")
                    .accessibilityHint("Double tap to \(showSearchBar ? "close" : "open") search bar")
                }
                
                // Fixed spacer between search and layout menu
                ToolbarSpacer(.fixed)
                
                // Layout/filter options menu
                ToolbarItem {
                    Menu {
                        // Filter type picker
                        Picker("View", selection: $selectedFilter.animation(DesignSystem.Animation.springStandard)) {
                            ForEach(FilterType.allCases, id: \.self) { filter in
                                Label(filter.description, systemImage: filter.icon)
                                    .tag(filter)
                            }
                        }
                        .pickerStyle(.inline)
                        .onChange(of: selectedFilter) { _, _ in
                            SensoryFeedback.light()
                            // Exit selection mode when switching filters
                            if isSelectionMode {
                                withAnimation(DesignSystem.Animation.springStandard) {
                                    isSelectionMode = false
                                    selectedItems.removeAll()
                                }
                            }
                        }

                        // Selection mode section
                        Section {
                            Button {
                                withAnimation(DesignSystem.Animation.springStandard) {
                                    isSelectionMode.toggle()
                                    if !isSelectionMode {
                                        selectedItems.removeAll()
                                    }
                                }
                                SensoryFeedback.medium()
                            } label: {
                                Label(
                                    isSelectionMode ? "Done Selecting" : "Select Items",
                                    systemImage: isSelectionMode ? "checkmark.circle" : "checkmark.circle.badge.xmark"
                                )
                            }

                            // Actions for selected items (only show when items are selected)
                            if isSelectionMode && !selectedItems.isEmpty {
                                Button {
                                    exportSelectedItems()
                                } label: {
                                    Label("Export \(selectedItems.count) Item\(selectedItems.count == 1 ? "" : "s")",
                                          systemImage: "doc.text")
                                }

                                Button(role: .destructive) {
                                    deleteSelectedItems()
                                } label: {
                                    Label("Delete \(selectedItems.count) Item\(selectedItems.count == 1 ? "" : "s")",
                                          systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedFilter.icon)
                                .font(.system(size: 18, weight: .medium))
                            if allItems.count > 0 {
                                Text("\(allItems.count)")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            }
                        }
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                        .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Filter and actions menu, \(allItems.count) total items")
                    .accessibilityHint("Double tap to filter notes and quotes or select multiple items")
                }
            }
        }
        .overlay {
            if showEditSheet {
                EditContentOverlay(
                    originalText: editingNote?.content ?? editingQuote?.text ?? "",
                    editedText: $editedText,
                    isPresented: $showEditSheet,
                    onSave: saveEdit
                )
            }
        }
        .onChange(of: showEditSheet) { _, newValue in
            if !newValue {
                notesViewModel.isEditingNote = false
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            let itemType = (itemToDelete as? CapturedNote) != nil ? "note" : "quote"
            Text("Are you sure you want to delete this \(itemType)? This action cannot be undone.")
        }
        .sheet(isPresented: $showingSessionSummary) {
            NavigationStack {
                if selectedSessionNote != nil || selectedSessionQuote != nil {
                    SessionSummaryPlaceholderView(
                        note: selectedSessionNote,
                        quote: selectedSessionQuote
                    )
                }
            }
        }
        .sheet(item: $quoteShareData) { data in
            QuoteShareSheet(
                quote: data.text,
                author: data.author,
                bookTitle: data.bookTitle
            )
        }
        .sheet(item: $exportContent) { content in
            switch content {
            case .singleNote(let note):
                MarkdownExportSheet(note: note, quote: nil, notes: [], quotes: [])
            case .singleQuote(let quote):
                MarkdownExportSheet(note: nil, quote: quote, notes: [], quotes: [])
            case .batch(let notes, let quotes):
                MarkdownExportSheet(note: nil, quote: nil, notes: notes, quotes: quotes)
            }
        }
    }

    // Removed headerView - now using navigation title
    // Removed filterPopoverButton - now integrated in toolbar
    
    private var contentSections: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(Array(groupedItems.enumerated()), id: \.0) { index, group in
                let section = group.0
                let items = group.1
                
                Section {
                    // Items in section with staggered animation (collapsible)
                    if !collapsedSections.contains(section) {
                        VStack(spacing: 12) {
                            ForEach(items, id: \.date) { item in
                                Group {
                                    if let note = item.note {
                                        noteCard(note: note)
                                            .id(note.id)
                                    } else if let quote = item.quote {
                                        quoteCard(quote: quote)
                                            .id(quote.id)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                } header: {
                    NoteStickyHeader(
                        section: section,
                        itemCount: items.count,
                        isCollapsible: selectedFilter == .byBook,
                        isCollapsed: collapsedSections.contains(section),
                        scrollOffset: scrollOffset,
                        onToggle: {
                            if selectedFilter == .byBook {
                                withAnimation(DesignSystem.Animation.springStandard) {
                                    if collapsedSections.contains(section) {
                                        collapsedSections.remove(section)
                                    } else {
                                        collapsedSections.insert(section)
                                    }
                                }
                                SensoryFeedback.light()
                            }
                        }
                    )
                }
            }
            
            // Bottom padding
            Color.clear
                .frame(height: 120)
        }
    }
    
    private func noteCard(note: Note) -> some View {
        let capturedNote = capturedNotes.first { $0.id == note.id }
        let isSelected = selectedItems.contains(note.id)

        return NoteCardView(note: note, capturedNote: capturedNote)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Note: \(note.content)")
            .accessibilityHint(isSelectionMode ? (isSelected ? "Selected, double tap to deselect" : "Double tap to select") : "Tap to show timestamp, long press for options")
            .overlay(alignment: .topLeading) {
                // Selection checkbox when in selection mode
                if isSelectionMode {
                    ZStack {
                        // Liquid glass background
                        Circle()
                            .fill(isSelected ? DesignSystem.Colors.primaryAccent.opacity(0.15) : Color.white.opacity(0.001))
                            .frame(width: 28, height: 28)
                            .glassEffect(.regular, in: .circle)
                        
                        // Checkmark icon
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.primaryAccent)
                        }
                    }
                    .padding(12)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.springQuick) {
                            if isSelected {
                                selectedItems.remove(note.id)
                            } else {
                                selectedItems.insert(note.id)
                            }
                        }
                        SensoryFeedback.light()
                    }
                }
            }
            .scaleEffect(isSelected ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.springQuick, value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    withAnimation(DesignSystem.Animation.springQuick) {
                        if isSelected {
                            selectedItems.remove(note.id)
                        } else {
                            selectedItems.insert(note.id)
                        }
                    }
                    SensoryFeedback.light()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if !isSelectionMode {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        isSelectionMode = true
                        selectedItems.insert(note.id)
                    }
                    SensoryFeedback.medium()
                }
            }
            .contextMenu {
                if !isSelectionMode {  // Only show context menu when NOT in selection mode
                    Button {
                        if let captured = capturedNote {
                            startEdit(note: captured)
                        }
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    Button {
                        shareNote(note)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button {
                        if let captured = capturedNote {
                            toggleNoteFavorite(captured)
                        }
                    } label: {
                        Label(
                            capturedNote?.isFavorite == true ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: capturedNote?.isFavorite == true ? "star.slash.fill" : "star.fill"
                        )
                    }

                    Divider()

                    Button {
                        if let captured = capturedNote {
                            print("📤 Exporting single note: \(captured.content?.prefix(50) ?? "")")
                            exportContent = .singleNote(captured)
                            print("📤 Export content set")
                        } else {
                            print("❌ No captured note found!")
                        }
                    } label: {
                        Label("Export Notes", systemImage: "doc.text")
                    }

                    Divider()

                    Button(role: .destructive) {
                        if let captured = capturedNote {
                            deleteNote(captured)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
    }
    
    private func quoteCard(quote: CapturedQuote) -> some View {
        // Convert CapturedQuote to Note for SimpleQuoteCard
        let note = Note(
            type: .quote,
            content: quote.text ?? "",
            bookId: nil,
            bookTitle: quote.book?.title,
            author: quote.author,
            pageNumber: quote.pageNumber,
            dateCreated: quote.timestamp ?? Date(),
            id: quote.id ?? UUID()
        )

        let isSelected = selectedItems.contains(quote.id ?? UUID())
        let accessibilityText = "\(quote.text ?? ""), \(quote.author.map { "by \($0)" } ?? "")"

        return SimpleQuoteCard(note: note, capturedQuote: quote)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quote: \(accessibilityText)")
            .accessibilityHint(isSelectionMode ? (isSelected ? "Selected, double tap to deselect" : "Double tap to select") : "Tap to show timestamp, long press for options")
            .overlay(alignment: .topLeading) {
                // Selection checkbox when in selection mode
                if isSelectionMode {
                    ZStack {
                        // Liquid glass background
                        Circle()
                            .fill(isSelected ? DesignSystem.Colors.primaryAccent.opacity(0.15) : Color.white.opacity(0.001))
                            .frame(width: 28, height: 28)
                            .glassEffect(.regular, in: .circle)
                        
                        // Checkmark icon
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.primaryAccent)
                        }
                    }
                    .padding(12)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.springQuick) {
                            if isSelected {
                                selectedItems.remove(quote.id ?? UUID())
                            } else {
                                selectedItems.insert(quote.id ?? UUID())
                            }
                        }
                        SensoryFeedback.light()
                    }
                }
            }
            .scaleEffect(isSelected ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.springQuick, value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    withAnimation(DesignSystem.Animation.springQuick) {
                        if isSelected {
                            selectedItems.remove(quote.id ?? UUID())
                        } else {
                            selectedItems.insert(quote.id ?? UUID())
                        }
                    }
                    SensoryFeedback.light()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if !isSelectionMode {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        isSelectionMode = true
                        selectedItems.insert(quote.id ?? UUID())
                    }
                    SensoryFeedback.medium()
                }
            }
            .onTapGesture(count: 2) {
                // Double tap to show session summary for ambient quotes
                if (quote.source as? String) == "ambient" {
                    selectedSessionQuote = quote
                    showingSessionSummary = true
                    SensoryFeedback.medium()
                }
            }
        .contextMenu {
                if !isSelectionMode {  // Only show context menu when NOT in selection mode
                    Button {
                        startEdit(quote: quote)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    Button {
                        shareQuote(quote)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button {
                        toggleQuoteFavorite(quote)
                    } label: {
                        Label(
                            quote.isFavorite == true ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: quote.isFavorite == true ? "star.slash.fill" : "star.fill"
                        )
                    }

                    Divider()

                    Button {
                        print("📤 Exporting single quote: \(quote.text?.prefix(50) ?? "")")
                        exportContent = .singleQuote(quote)
                        print("📤 Export content set")
                    } label: {
                        Label("Export Notes", systemImage: "doc.text")
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteQuote(quote)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Notes Yet", systemImage: "note.text")
                .foregroundStyle(.white)
        } description: {
            Text("Start capturing your thoughts, quotes, and questions from your reading journey")
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No notes yet. Start capturing your thoughts, quotes, and questions from your reading journey")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            if days == 1 { return "Yesterday" }
            if days < 7 { return "\(days) days ago" }
            if days < 30 { return "\(days / 7) weeks ago" }
            return formatDate(date)
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
    
    // MARK: - Edit Actions
    
    private func startEdit(note: CapturedNote) {
        editingNote = note
        editingQuote = nil
        editedText = note.content ?? ""
        notesViewModel.isEditingNote = true
        showEditSheet = true
        SensoryFeedback.light()
    }
    
    private func startEdit(quote: CapturedQuote) {
        editingQuote = quote
        editingNote = nil

        // Build editable text with quote + attribution
        var text = quote.text ?? ""
        if let author = quote.author {
            text += " by \(author)"
            if let bookTitle = quote.book?.title {
                text += ", \(bookTitle)"
            }
        } else if let bookTitle = quote.book?.title {
            text += " from \(bookTitle)"
        }

        editedText = text
        notesViewModel.isEditingNote = true
        showEditSheet = true
        SensoryFeedback.light()
    }
    
    private func saveEdit() {
        if let note = editingNote {
            note.content = editedText
            try? modelContext.save()
            SensoryFeedback.success()
        } else if let quote = editingQuote {
            // Parse attribution from the edited text using NLP
            var quoteText = editedText
            var quoteAuthor: String? = nil
            var parsedBookTitle: String? = nil

            // Attribution parsing patterns (same as AmbientModeView)
            let attributionPatterns = [
                // "by Author" or "by Author, Book"
                try? NSRegularExpression(pattern: "\\s+by\\s+([^,]+)(?:,\\s*(.+))?\\s*$", options: .caseInsensitive),
                // "from Book" or "from Book by Author"
                try? NSRegularExpression(pattern: "\\s+from\\s+(.+?)(?:\\s+by\\s+(.+))?\\s*$", options: .caseInsensitive),
                // "- Author" or "- Author, Book"
                try? NSRegularExpression(pattern: "\\s*[-—–]\\s*([^,]+)(?:,\\s*(.+))?\\s*$", options: []),
                // ", Author" at the end
                try? NSRegularExpression(pattern: ",\\s+([^,]+)\\s*$", options: [])
            ]

            for (index, pattern) in attributionPatterns.compactMap({ $0 }).enumerated() {
                let range = NSRange(quoteText.startIndex..., in: quoteText)
                if let match = pattern.firstMatch(in: quoteText, range: range) {
                    if index == 1 {
                        // "from Book" pattern - first capture is book, second is author
                        if let bookRange = Range(match.range(at: 1), in: quoteText) {
                            let extractedBook = String(quoteText[bookRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !extractedBook.isEmpty && extractedBook.count > 2 {
                                parsedBookTitle = extractedBook
                            }
                        }
                        if match.numberOfRanges > 2, let authorRange = Range(match.range(at: 2), in: quoteText) {
                            let extractedAuthor = String(quoteText[authorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !extractedAuthor.isEmpty && extractedAuthor.count > 2 {
                                quoteAuthor = extractedAuthor
                            }
                        }
                    } else {
                        // "by Author" pattern - first capture is author, second is book
                        if let authorRange = Range(match.range(at: 1), in: quoteText) {
                            let extractedAuthor = String(quoteText[authorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !extractedAuthor.isEmpty && extractedAuthor.count > 2 {
                                quoteAuthor = extractedAuthor
                            }
                        }
                        if match.numberOfRanges > 2, let bookRange = Range(match.range(at: 2), in: quoteText) {
                            let extractedBook = String(quoteText[bookRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !extractedBook.isEmpty && extractedBook.count > 2 {
                                parsedBookTitle = extractedBook
                            }
                        }
                    }

                    // Remove attribution from quote text
                    if let matchRange = Range(match.range, in: quoteText) {
                        quoteText = String(quoteText[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    break
                }
            }

            // Update quote text
            quote.text = quoteText

            // Update author
            quote.author = quoteAuthor

            // Update or create book if we have a parsed title
            if let bookTitle = parsedBookTitle {
                let descriptor = FetchDescriptor<BookModel>(
                    predicate: #Predicate { book in
                        book.title == bookTitle
                    }
                )

                if let existingBook = try? modelContext.fetch(descriptor).first {
                    quote.book = existingBook
                } else {
                    // Create new book
                    let newBook = BookModel(
                        id: UUID().uuidString,
                        title: bookTitle,
                        author: quoteAuthor ?? "Unknown"
                    )
                    modelContext.insert(newBook)
                    quote.book = newBook
                }
            }

            try? modelContext.save()
            SensoryFeedback.success()
        }
        cancelEdit()
    }
    
    private func cancelEdit() {
        editingNote = nil
        editingQuote = nil
        editedText = ""
        notesViewModel.isEditingNote = false
        showEditSheet = false
    }
    
    // MARK: - Delete Actions
    
    private func deleteItem() {
        if let note = itemToDelete as? CapturedNote {
            deleteNote(note)
        } else if let quote = itemToDelete as? CapturedQuote {
            deleteQuote(quote)
        }
        itemToDelete = nil
    }
    
    private func deleteNote(_ note: CapturedNote) {
        // Remove from Spotlight index
        if let noteId = note.id {
            Task {
                await SpotlightIndexingService.shared.deindexNote(noteId)
            }
        }

        modelContext.delete(note)
        try? modelContext.save()
        SensoryFeedback.success()
    }

    private func deleteQuote(_ quote: CapturedQuote) {
        // Remove from Spotlight index
        if let quoteId = quote.id {
            Task {
                await SpotlightIndexingService.shared.deindexQuote(quoteId)
            }
        }

        modelContext.delete(quote)
        try? modelContext.save()
        SensoryFeedback.success()
    }
    
    private func exportSelectedItems() {
        var selectedNotes: [CapturedNote] = []
        var selectedQuotes: [CapturedQuote] = []

        for id in selectedItems {
            if let note = capturedNotes.first(where: { $0.id == id }) {
                selectedNotes.append(note)
            } else if let quote = capturedQuotes.first(where: { $0.id == id }) {
                selectedQuotes.append(quote)
            }
        }

        print("📤 Exporting batch: \(selectedNotes.count) notes, \(selectedQuotes.count) quotes")
        exportContent = .batch(notes: selectedNotes, quotes: selectedQuotes)

        SensoryFeedback.success()
    }

    private func deleteSelectedItems() {
        for id in selectedItems {
            if let note = capturedNotes.first(where: { $0.id == id }) {
                // Remove from Spotlight index
                Task {
                    await SpotlightIndexingService.shared.deindexNote(id)
                }
                modelContext.delete(note)
            } else if let quote = capturedQuotes.first(where: { $0.id == id }) {
                // Remove from Spotlight index
                Task {
                    await SpotlightIndexingService.shared.deindexQuote(id)
                }
                modelContext.delete(quote)
            }
        }
        
        try? modelContext.save()
        
        withAnimation(DesignSystem.Animation.springStandard) {
            selectedItems.removeAll()
            isSelectionMode = false
        }
        
        SensoryFeedback.success()
    }
    
    // MARK: - Share Actions
    
    private func shareNote(_ note: Note) {
        let text = note.content
        var shareText = text
        
        if let bookTitle = note.bookTitle {
            shareText += "\n\n— From '\(bookTitle)'"
            if let author = note.author {
                shareText += " by \(author)"
            }
        }
        
        let activityController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
        
        SensoryFeedback.light()
    }
    
    private func shareQuote(_ quote: CapturedQuote) {
        #if DEBUG
        print("🔵 shareQuote called")
        #endif
        #if DEBUG
        print("🔵 Quote text: \(quote.text ?? "nil")")
        #endif
        #if DEBUG
        print("🔵 Quote author: \(quote.author ?? "nil")")
        #endif

        // Create share data struct - this ensures all data is captured atomically
        quoteShareData = QuoteShareData(
            text: quote.text ?? "No quote text",
            author: quote.author,
            bookTitle: quote.book?.title
        )

        #if DEBUG
        print("🔵 Created share data with text: \(quoteShareData?.text ?? "nil")")
        #endif

        SensoryFeedback.light()

        // Old plain text sharing (kept as fallback)
        /*
        var shareText = "\"\(quote.text)\""

        if let author = quote.author {
            shareText += "\n\n— \(author)"
        }
        
        if let book = quote.book {
            shareText += ", \(book.title)"
        }

        let activityController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityController, animated: true)
        }

        SensoryFeedback.light()
        */
    }
    
    // MARK: - Favorite Actions

    private func toggleNoteFavorite(_ note: CapturedNote) {
        withAnimation(DesignSystem.Animation.springStandard) {
            note.isFavorite = !(note.isFavorite ?? false)
        }
        try? modelContext.save()
        SensoryFeedback.success()
    }

    private func toggleQuoteFavorite(_ quote: CapturedQuote) {
        withAnimation(DesignSystem.Animation.springStandard) {
            quote.isFavorite = !(quote.isFavorite ?? false)
        }
        try? modelContext.save()
        SensoryFeedback.success()
    }

    // MARK: - Note/Quote Creation

    private func createNote(content: String, bookId: String? = nil, bookTitle: String? = nil, bookAuthor: String? = nil) {
        // Find or create BookModel if we have book context
        var bookModel: BookModel? = nil
        if let bookId = bookId, let bookTitle = bookTitle {
            // First, try to find an existing BookModel in SwiftData
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { book in
                    book.localId == bookId
                }
            )
            
            if let existingBookModel = try? modelContext.fetch(descriptor).first {
                // Use the existing BookModel from SwiftData
                bookModel = existingBookModel
            } else if let existingBook = libraryViewModel.books.first(where: { $0.localId.uuidString == bookId }) {
                // Create a new BookModel from the library book
                let newBookModel = BookModel(from: existingBook)
                modelContext.insert(newBookModel)
                bookModel = newBookModel
            }
        }

        let capturedNote = CapturedNote(content: content, book: bookModel)
        modelContext.insert(capturedNote)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Note saved successfully to SwiftData")
            #endif

            // Index for Spotlight search
            Task {
                await SpotlightIndexingService.shared.indexNote(capturedNote)
            }

            let message = bookTitle.map { "Note saved to \($0)" } ?? "Note saved successfully"
            showToast(message: message)
            SensoryFeedback.success()
        } catch {
            #if DEBUG
            print("❌ Failed to save note: \(error)")
            #endif
            #if DEBUG
            print("❌ Error details: \(error.localizedDescription)")
            #endif
            // Show error toast to user
            showToast(message: "Failed to save note")
        }
    }
    
    private func createQuote(content: String, attribution: String?, bookId: String? = nil, bookTitle: String? = nil, bookAuthor: String? = nil) {
        // Find or create BookModel if we have book context
        var bookModel: BookModel? = nil
        
        // First try to find existing book by ID
        if let bookId = bookId {
            // Try to find an existing BookModel in SwiftData
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { book in
                    book.localId == bookId
                }
            )
            
            if let existingBookModel = try? modelContext.fetch(descriptor).first {
                // Use the existing BookModel from SwiftData
                bookModel = existingBookModel
            } else if let existingBook = libraryViewModel.books.first(where: { $0.localId.uuidString == bookId }) {
                // Create a new BookModel from the library book
                let newBookModel = BookModel(from: existingBook)
                modelContext.insert(newBookModel)
                bookModel = newBookModel
            }
        }

        // If no bookModel yet but we have bookTitle, create a minimal BookModel
        // This handles quotes with book attribution but no selected book from library
        if bookModel == nil, let title = bookTitle {
            // First check if a BookModel with this title already exists
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { book in
                    book.title == title
                }
            )

            if let existingBookModel = try? modelContext.fetch(descriptor).first {
                bookModel = existingBookModel
            } else {
                let newBookModel = BookModel(
                    id: UUID().uuidString, // Generate a unique ID for quotes without library books
                    title: title,
                    author: bookAuthor ?? attribution ?? "Unknown"
                )
                modelContext.insert(newBookModel)
                bookModel = newBookModel
            }
        }

        let capturedQuote = CapturedQuote(
            text: content,
            book: bookModel,
            author: attribution,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual
        )

        modelContext.insert(capturedQuote)

        do {
            try modelContext.save()

            // Index for Spotlight search
            Task {
                await SpotlightIndexingService.shared.indexQuote(capturedQuote)
            }

            let message = bookTitle.map { "Quote saved to \($0)" } ?? "Quote saved successfully"
            showToast(message: message)
            SensoryFeedback.success()
        } catch {
            #if DEBUG
            print("Failed to save quote: \(error)")
            #endif
            // Show error toast to user
            showToast(message: "Failed to save quote")
        }
    }
    
    // MARK: - Toast
    
    private func showToast(message: String) {
        toastMessage = message
        showingToast = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showingToast = false
            }
        }
    }
}

// Extension removed - already exists in SwiftDataNotesBridge.swift
// EditContentSheet already exists in UnifiedChatView.swift

// MARK: - Sticky Header (Exactly Matching Chat Tab)
private struct NoteStickyHeader: View {
    let section: String
    let itemCount: Int
    let isCollapsible: Bool
    let isCollapsed: Bool
    let scrollOffset: CGFloat
    let onToggle: () -> Void
    
    @State private var minY: CGFloat = 0
    
    private var isPinned: Bool {
        minY < 150 && minY > -50  // Unpins when pushed up by next header
    }
    
    private var opacity: Double {
        // Fade out as it gets pushed up
        if minY < -30 {
            return 0.0
        } else if minY < 0 {
            return Double((minY + 30) / 30)
        } else {
            return 1.0
        }
    }
    
    var body: some View {
        HStack {
            // Section title - no button wrapper, just like chat tab
            Text(section.uppercased())
                .font(.system(
                    size: isPinned ? 15 : 13,
                    weight: isPinned ? .bold : .semibold
                ))
                .foregroundStyle(
                    isPinned ? .white : DesignSystem.Colors.textTertiary
                )
                .tracking(isPinned ? 1.4 : 1.2)
                .animation(DesignSystem.Animation.easeQuick, value: isPinned)
            
            Spacer()
            
            // Count - format like chat tab
            Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                .font(.system(
                    size: isPinned ? 12 : 11,
                    weight: .medium
                ))
                .foregroundStyle(
                    isPinned ? DesignSystem.Colors.primaryAccent : DesignSystem.Colors.textQuaternary
                )
                .animation(DesignSystem.Animation.easeQuick, value: isPinned)
        }
        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background {
            if isPinned {
                // Beautiful amber tinted glass effect that fades when pushed
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.10 * opacity))
                    .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .animation(DesignSystem.Animation.easeStandard, value: isPinned)
                    .animation(DesignSystem.Animation.easeQuick, value: opacity)
            } else {
                Color.clear
            }
        }
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: NoteScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).origin.y
                    )
            }
        )
        .onPreferenceChange(NoteScrollOffsetPreferenceKey.self) { value in
            minY = value
        }
    }
}

// MARK: - Preference Key for Scroll Offset
private struct NoteScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


// MARK: - Note Card View with Date Toggle
// MARK: - Enhanced Note Card with Smart Expansion
private struct NoteCardView: View {
    let note: Note
    let capturedNote: CapturedNote?

    // MARK: - State Management
    @State private var isExpanded = false
    @State private var showingDetailView = false
    @State private var showingSessionSummary = false
    @State private var contentHeight: CGFloat = 0

    // MARK: - Constants (Steve would approve these numbers)
    private let lineHeight: CGFloat = 27  // 16pt font + 6pt line spacing + 5pt padding
    private let previewLineLimit = 5
    private let mediumThreshold: CGFloat = 12  // lines
    private let longThreshold: CGFloat = 20    // lines

    // MARK: - Content Tier Detection
    private var approximateLineCount: Int {
        Int(ceil(contentHeight / lineHeight))
    }

    private var contentTier: ContentTier {
        let lines = approximateLineCount
        if lines <= previewLineLimit {
            return .short
        } else if lines <= Int(mediumThreshold) {
            return .medium(additionalLines: lines - previewLineLimit)
        } else {
            return .long(totalLines: lines)
        }
    }

    private var isMediumTier: Bool {
        if case .medium = contentTier {
            return true
        }
        return false
    }

    private enum ContentTier {
        case short
        case medium(additionalLines: Int)
        case long(totalLines: Int)

        var needsExpansionUI: Bool {
            switch self {
            case .short: return false
            case .medium, .long: return true
            }
        }
    }

    // MARK: - Header with Smart "Show Less" Button
    private var dateHeader: some View {
        HStack {
            Text(formatDate(note.dateCreated).uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(
                    (capturedNote?.source as? String) == "ambient"
                        ? DesignSystem.Colors.primaryAccent.opacity(0.6)
                        : .white.opacity(0.4)
                )

            Spacer()

            // Show "Show Less" pill when expanded
            if isExpanded && contentTier.needsExpansionUI {
                Button {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        isExpanded = false
                    }
                    SensoryFeedback.light()
                } label: {
                    HStack(spacing: 4) {
                        Text("Show Less")
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.05))
                    .overlay {
                        Capsule().stroke(DesignSystem.Colors.primaryAccent.opacity(0.3), lineWidth: 0.5)
                    }
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // Session pill for ambient notes
            if let session = capturedNote?.ambientSession, (capturedNote?.source as? String) == "ambient" {
                Button {
                    showingSessionSummary = true
                } label: {
                    HStack(spacing: 6) {
                        Text("SESSION")
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .kerning(1.0)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(DesignSystem.Colors.primaryAccent.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                            .stroke(DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    // MARK: - Content Text with Measurement
    private var contentText: some View {
        Text(note.content)
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(isExpanded ? nil : previewLineLimit)
            .lineSpacing(6)
            .background(
                // Hidden measurement view - Steve would appreciate this efficiency
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            // Measure full content height on first render
                            DispatchQueue.main.async {
                                contentHeight = geo.size.height
                            }
                        }
                        .onChange(of: note.content) { _, _ in
                            contentHeight = geo.size.height
                        }
                }
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Text Blur Fade Overlay (Medium Tier)
    @ViewBuilder
    private var textBlurFade: some View {
        if case .medium = contentTier, !isExpanded {
            // Duplicate the text with blur and gradient mask for smooth fade
            Text(note.content)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.leading)
                .lineLimit(previewLineLimit)
                .lineSpacing(6)
                .blur(radius: 3)
                .mask(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.8),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 90)
                )
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: - Expansion Indicator Pills
    @ViewBuilder
    private var expansionIndicator: some View {
        if contentTier.needsExpansionUI && !isExpanded {
            switch contentTier {
            case .medium(let additionalLines):
                // Glass pill for medium notes
                HStack(spacing: 4) {
                    Text("\(additionalLines) more line\(additionalLines == 1 ? "" : "s")")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                }
                .clipShape(Capsule())
                .transition(.opacity)
                .accessibilityLabel("Expand to show \(additionalLines) more lines")
                .accessibilityHint("Double tap to expand this note")

            case .long:
                // Prominent button for long notes
                Button {
                    showingDetailView = true
                    SensoryFeedback.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Text("View Full Note")
                            .font(.caption.weight(.medium))
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.primaryAccent.opacity(0.12))
                    .overlay {
                        Capsule().stroke(DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 0.5)
                    }
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityLabel("View full note in reading mode")
                .accessibilityHint("Double tap to open note in full-screen reading view")

            case .short:
                EmptyView()
            }
        }
    }

    // MARK: - Book Context
    private var bookContext: some View {
        Group {
            if let bookTitle = note.bookTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookTitle.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .kerning(0.8)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if let author = note.author {
                        Text(author.uppercased())
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(0.6)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Card Content Layout
    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - shows when expanded OR when date is tapped
            if isExpanded {
                dateHeader
            }

            // Content with overlay for text blur
            ZStack(alignment: .bottom) {
                contentText
                    .frame(maxHeight: isExpanded ? .infinity : nil)
                    .clipped()

                // Text blur fade for medium-length notes
                textBlurFade
            }

            // Expansion indicator - positioned naturally
            if !isExpanded && contentTier.needsExpansionUI {
                HStack {
                    Spacer()
                    expansionIndicator
                        .padding(.top, 4)
                    Spacer()
                }
            }

            bookContext
        }
    }

    // MARK: - Main Body
    var body: some View {
        cardContent
        .padding(DesignSystem.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .overlay(alignment: .leading) {
            // Golden favorite indicator
            if capturedNote?.isFavorite == true {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 2)
                    .padding(.vertical, 1)
                    .padding(.leading, 1)
            }
        }
        .animation(DesignSystem.Animation.springStandard, value: isExpanded)
        .animation(DesignSystem.Animation.springStandard, value: capturedNote?.isFavorite)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(makeAccessibilityLabel())
        .accessibilityHint(makeAccessibilityHint())
        .accessibilityAddTraits(.isButton)
        // Tap to expand (for short/medium notes)
        .onTapGesture {
            if case .long = contentTier {
                // Long notes open detail view
                showingDetailView = true
            } else if contentTier.needsExpansionUI {
                // Medium notes expand inline
                withAnimation(DesignSystem.Animation.springStandard) {
                    isExpanded.toggle()
                }
                SensoryFeedback.light()
            } else {
                // Short notes just show date
                withAnimation(DesignSystem.Animation.springStandard) {
                    isExpanded.toggle()
                }
                SensoryFeedback.light()
            }
        }
        // Long press for detail view (all tiers)
        .onLongPressGesture(minimumDuration: 0.5) {
            showingDetailView = true
            SensoryFeedback.impact(.medium)
        }
        // Detail view sheet for long notes
        .sheet(isPresented: $showingDetailView) {
            NoteDetailView(note: note, capturedNote: capturedNote)
        }
        // Session summary sheet
        .sheet(isPresented: $showingSessionSummary) {
            if let session = capturedNote?.ambientSession {
                NavigationStack {
                    AmbientSessionSummaryView(session: session, colorPalette: nil)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Accessibility Helpers
    private func makeAccessibilityLabel() -> String {
        var label = "Note"

        if let bookTitle = note.bookTitle {
            label += " from \(bookTitle)"
        }

        if isExpanded {
            label += ". Expanded"
        }

        return label
    }

    private func makeAccessibilityHint() -> String {
        switch contentTier {
        case .short:
            return "Double tap to show date and details"
        case .medium(let lines):
            if isExpanded {
                return "Double tap to collapse note"
            } else {
                return "Double tap to expand and show \(lines) more lines. Long press to view in full screen"
            }
        case .long:
            return "Double tap to view full note in reading mode. Long press for full screen view"
        }
    }
}