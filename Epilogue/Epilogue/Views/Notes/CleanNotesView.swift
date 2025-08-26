import SwiftUI
import SwiftData

struct CleanNotesView: View {
    @EnvironmentObject private var notesViewModel: NotesViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @Environment(\.modelContext) private var modelContext
    
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
    @State private var showingSettings = false
    @State private var showSearchBar = false
    @State private var showingSessionSummary = false
    @State private var selectedSessionNote: CapturedNote?
    @State private var selectedSessionQuote: CapturedQuote?
    @State private var collapsedSections: Set<String> = []
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<UUID> = []
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
            (date: capturedNote.timestamp, note: capturedNote.toNote(), quote: nil)
        }
        
        // Add quotes
        items += capturedQuotes.map { (date: $0.timestamp, note: nil, quote: $0) }
        
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
                    return quote.text.lowercased().contains(query) ||
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
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            }
            .padding(.horizontal, 20)
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
                // Dark background matching library
                Color(red: 0.11, green: 0.105, blue: 0.102)
                    .ignoresSafeArea()
                
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
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Selection mode button (only show when in selection mode)
                        if isSelectionMode {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isSelectionMode = false
                                    selectedItems.removeAll()
                                }
                                HapticManager.shared.lightTap()
                            } label: {
                                Text("Done")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                            }
                            
                            if !selectedItems.isEmpty {
                                Button {
                                    deleteSelectedItems()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                            }
                        }
                        // Search button - simple
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSearchBar.toggle()
                                if !showSearchBar {
                                    searchText = ""
                                }
                            }
                            HapticManager.shared.lightTap()
                        } label: {
                            if showSearchBar {
                                // Liquid glass close button with amber tint
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.15))
                                        .frame(width: 28, height: 28)
                                        .glassEffect()
                                    
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                                }
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        
                        // Filter selector - simple
                        Menu {
                            ForEach(FilterType.allCases, id: \.self) { filter in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedFilter = filter
                                    }
                                    HapticManager.shared.lightTap()
                                } label: {
                                    Label {
                                        HStack {
                                            Text(filter.description)
                                            Spacer()
                                            if selectedFilter == filter {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .semibold))
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: filter.icon)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: selectedFilter.icon)
                                    .font(.system(size: 12, weight: .medium))
                                Text("\(allItems.count)")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        // Settings button - simple
                        Button {
                            showingSettings = true
                            HapticManager.shared.lightTap()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.8))
                        }
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
        VStack(spacing: 24) {
            ForEach(Array(groupedItems.enumerated()), id: \.0) { index, group in
                let section = group.0
                let items = group.1
                VStack(alignment: .leading, spacing: 16) {
                    // Section Header (collapsible for By Book filter)
                    Button {
                        if selectedFilter == .byBook {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if collapsedSections.contains(section) {
                                    collapsedSections.remove(section)
                                } else {
                                    collapsedSections.insert(section)
                                }
                            }
                            HapticManager.shared.lightTap()
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            if selectedFilter == .byBook {
                                Image(systemName: collapsedSections.contains(section) ? "chevron.right" : "chevron.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(width: 20)
                            }
                            
                            // Book title with refined typography
                            Text(section.uppercased())
                                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                .kerning(0.6)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            // Count badge with monospaced font
                            Text("\(items.count)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selectedFilter != .byBook)
                    .padding(.horizontal, 20)
                    
                    // Items in section with staggered animation (collapsible)
                    if !collapsedSections.contains(section) {
                        VStack(spacing: 16) {
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
                                .padding(.horizontal, 20)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                }
            }
            
            // Bottom padding with subtle gradient fade
            LinearGradient(
                colors: [Color.clear, Color(red: 0.11, green: 0.105, blue: 0.102)],
                startPoint: .top,
                endPoint: .bottom
            )
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
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white.opacity(0.3))
                        .padding(12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                if isSelected {
                                    selectedItems.remove(note.id)
                                } else {
                                    selectedItems.insert(note.id)
                                }
                            }
                            HapticManager.shared.lightTap()
                        }
                }
            }
            .scaleEffect(isSelected ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        if isSelected {
                            selectedItems.remove(note.id)
                        } else {
                            selectedItems.insert(note.id)
                        }
                    }
                    HapticManager.shared.lightTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if !isSelectionMode {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelectionMode = true
                        selectedItems.insert(note.id)
                    }
                    HapticManager.shared.mediumTap()
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
            content: quote.text,
            bookId: nil,
            bookTitle: quote.book?.title,
            author: quote.author,
            pageNumber: quote.pageNumber,
            dateCreated: quote.timestamp,
            id: quote.id
        )
        
        let isSelected = selectedItems.contains(quote.id)
        
        return SimpleQuoteCard(note: note)
            .overlay(alignment: .topLeading) {
                // Selection checkbox when in selection mode
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white.opacity(0.3))
                        .padding(12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                if isSelected {
                                    selectedItems.remove(quote.id)
                                } else {
                                    selectedItems.insert(quote.id)
                                }
                            }
                            HapticManager.shared.lightTap()
                        }
                }
            }
            .scaleEffect(isSelected ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        if isSelected {
                            selectedItems.remove(quote.id)
                        } else {
                            selectedItems.insert(quote.id)
                        }
                    }
                    HapticManager.shared.lightTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if !isSelectionMode {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelectionMode = true
                        selectedItems.insert(quote.id)
                    }
                    HapticManager.shared.mediumTap()
                }
            }
            .onTapGesture(count: 2) {
                // Double tap to show session summary for ambient quotes
                if quote.source == .ambient {
                    selectedSessionQuote = quote
                    showingSessionSummary = true
                    HapticManager.shared.mediumTap()
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
        VStack(spacing: 24) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.1), Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                
                Image(systemName: "note.text")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.4), Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .scaleEffect(1.0)
            
            VStack(spacing: 12) {
                Text("Your thoughts await")
                    .font(.system(size: 24, weight: .semibold, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Capture quotes, notes, and reflections from your reading journey")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        editedText = note.content
        notesViewModel.isEditingNote = true
        showEditSheet = true
        HapticManager.shared.lightTap()
    }
    
    private func startEdit(quote: CapturedQuote) {
        editingQuote = quote
        editingNote = nil
        editedText = quote.text
        notesViewModel.isEditingNote = true
        showEditSheet = true
        HapticManager.shared.lightTap()
    }
    
    private func saveEdit() {
        if let note = editingNote {
            note.content = editedText
            try? modelContext.save()
            HapticManager.shared.success()
        } else if let quote = editingQuote {
            quote.text = editedText
            try? modelContext.save()
            HapticManager.shared.success()
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
        HapticManager.shared.success()
    }
    
    private func deleteQuote(_ quote: CapturedQuote) {
        modelContext.delete(quote)
        try? modelContext.save()
        HapticManager.shared.success()
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
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedItems.removeAll()
            isSelectionMode = false
        }
        
        HapticManager.shared.success()
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
        
        HapticManager.shared.lightTap()
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
        
        HapticManager.shared.lightTap()
    }
}

// Extension removed - already exists in SwiftDataNotesBridge.swift
// EditContentSheet already exists in UnifiedChatView.swift

// MARK: - Note Card View with Date Toggle
private struct NoteCardView: View {
    let note: Note
    let capturedNote: CapturedNote?
    @State private var showDate = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Timestamp header - shown on tap
            if showDate {
                Text(formatDate(note.dateCreated).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(
                        capturedNote?.source == .ambient 
                            ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6)
                            : .white.opacity(0.4)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            // Content with better typography
            Text(note.content)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(6)
            
            // Book context with refined styling (no divider line)
            if let bookTitle = note.bookTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookTitle.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .kerning(0.8)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    if let author = note.author {
                        Text(author.uppercased())
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(0.6)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.top, 12) // Add spacing instead of divider line
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showDate)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showDate.toggle()
            }
            HapticManager.shared.lightTap()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}