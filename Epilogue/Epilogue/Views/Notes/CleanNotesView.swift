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
    @Namespace private var animation
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case notes = "Notes"
        case quotes = "Quotes"
        case byBook = "By Book"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .notes: return "note.text"
            case .quotes: return "quote.opening"
            case .byBook: return "books.vertical"
            }
        }
        
        var description: String {
            switch self {
            case .all: return "All Items"
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
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.textQuaternary)
                    }
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
                        showEditSheet = true

                        // Clear the navigation flag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            navigationCoordinator.highlightedQuoteID = nil
                        }
                    }
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
                            
                            // Delete selected button (only show when items are selected)
                            if isSelectionMode && !selectedItems.isEmpty {
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
                    
                    Button {
                        shareNote(note)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
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
        
        return SimpleQuoteCard(note: note, capturedQuote: quote)
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
                    
                    Button {
                        shareQuote(quote)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
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
        ModernEmptyStates.noNotes
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 100)
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
        editedText = quote.text ?? ""
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
            quote.text = editedText
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
        modelContext.delete(note)
        try? modelContext.save()
        SensoryFeedback.success()
    }
    
    private func deleteQuote(_ quote: CapturedQuote) {
        modelContext.delete(quote)
        try? modelContext.save()
        SensoryFeedback.success()
    }
    
    private func deleteSelectedItems() {
        for id in selectedItems {
            if let note = capturedNotes.first(where: { $0.id == id }) {
                modelContext.delete(note)
            } else if let quote = capturedQuotes.first(where: { $0.id == id }) {
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
private struct NoteCardView: View {
    let note: Note
    let capturedNote: CapturedNote?
    @State private var showDate = false
    
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
            
            // Session pill for ambient notes - shows with date on tap
            if let session = capturedNote?.ambientSession, (capturedNote?.source as? String) == "ambient" {
                NavigationLink(destination: AmbientSessionSummaryView(session: session, colorPalette: nil)) {
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
                .buttonStyle(PlainButtonStyle())
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
    
    private var contentText: some View {
        Text(note.content)
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(5)  // Limit to 5 lines max, expandable on tap
            .lineSpacing(6)
    }
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show header when date is toggled on
            if showDate {
                dateHeader
            }
            
            contentText
            
            bookContext
        }
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
        .animation(DesignSystem.Animation.springStandard, value: showDate)
        .onTapGesture {
            withAnimation(DesignSystem.Animation.springStandard) {
                showDate.toggle()
            }
            SensoryFeedback.light()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}