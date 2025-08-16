import SwiftUI
import SwiftData

struct CleanNotesView: View {
    @EnvironmentObject private var notesViewModel: NotesViewModel
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \CapturedNote.timestamp, order: .reverse) private var capturedNotes: [CapturedNote]
    @Query(sort: \CapturedQuote.timestamp, order: .reverse) private var capturedQuotes: [CapturedQuote]
    
    @State private var selectedFilter: FilterType? = nil
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
    }
    
    // Combined items (unfiltered)
    private var allItems: [(date: Date, note: Note?, quote: CapturedQuote?)] {
        var items: [(date: Date, note: Note?, quote: CapturedQuote?)] = []
        
        // Add notes
        items += capturedNotes.map { (date: $0.timestamp, note: $0.toNote(), quote: nil) }
        
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
        case .all, .byBook, .none:
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background matching library
                Color(red: 0.11, green: 0.105, blue: 0.102)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Progressive Search Bar
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
                        }
                        
                        // Filter Pills under navigation
                        filterPills
                            .padding(.horizontal, 20)
                            .padding(.top, showSearchBar ? 8 : 16)
                            .padding(.bottom, 20)
                        
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
                        // Search button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSearchBar.toggle()
                                if !showSearchBar {
                                    searchText = ""
                                }
                            }
                            HapticManager.shared.lightTap()
                        } label: {
                            Image(systemName: showSearchBar ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(showSearchBar ? 0.1 : 0.05))
                                )
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Stats badge
                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                                .font(.system(size: 14))
                            Text("\(allItems.count)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: Capsule())
                        
                        // Settings button
                        GlassOrbSettingsButton(isPressed: $settingsButtonPressed) {
                            showingSettings = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditContentSheet(
                originalText: editingNote?.content ?? editingQuote?.text ?? "",
                editedText: $editedText,
                onSave: saveEdit,
                onCancel: cancelEdit
            )
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
            NavigationView {
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
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    filterPill(for: filter)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedFilter)
    }
    
    private func filterPill(for filter: FilterType) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedFilter = selectedFilter == filter ? nil : filter
            }
            HapticManager.shared.lightTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(filter.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(
                selectedFilter == filter || (selectedFilter == nil && filter == .all) 
                    ? .black 
                    : .white.opacity(0.7)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selectedFilter == filter || (selectedFilter == nil && filter == .all)
                    ? Color.white
                    : Color.white.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var contentSections: some View {
        VStack(spacing: 36) {
            ForEach(groupedItems.indices, id: \.self) { index in
                let section = groupedItems[index].0
                let items = groupedItems[index].1
                VStack(alignment: .leading, spacing: 20) {
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
                        HStack(alignment: .center, spacing: 8) {
                            if selectedFilter == .byBook {
                                Image(systemName: collapsedSections.contains(section) ? "chevron.right" : "chevron.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(width: 20)
                            }
                            
                            Text(section)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("(\(items.count))")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.white.opacity(0.4))
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selectedFilter != .byBook)
                    .padding(.horizontal, 20)
                    
                    // Items in section with staggered animation (collapsible)
                    if !collapsedSections.contains(section) {
                        VStack(spacing: 16) {
                            ForEach(items.indices, id: \.self) { itemIndex in
                                let item = items[itemIndex]
                                Group {
                                    if let note = item.note {
                                        noteCard(note: note)
                                    } else if let quote = item.quote {
                                        quoteCard(quote: quote)
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
        return noteCardContent(note: note)
            .contentShape(Rectangle())
            .onLongPressGesture {
                // Navigate to session summary if from ambient session
                if let captured = capturedNote, captured.source == .ambient {
                    selectedSessionNote = captured
                    showingSessionSummary = true
                    HapticManager.shared.mediumTap()
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    if let captured = capturedNote {
                        deleteNote(captured)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                
                Button {
                    if let captured = capturedNote {
                        shareNote(note)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(Color.blue)
                
                Button {
                    if let captured = capturedNote {
                        startEdit(note: captured)
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(Color.orange)
            }
    }
    
    private func noteCardContent(note: Note) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Timestamp header
            Text(formatDate(note.dateCreated))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
            
            // Content
            Text(note.content)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            // Book context if available
            if let bookTitle = note.bookTitle {
                HStack(spacing: 4) {
                    Text("re:")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(bookTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    if let author = note.author {
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text(author)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
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
        
        return SimpleQuoteCard(note: note)
            .contentShape(Rectangle())
            .onLongPressGesture {
                // Navigate to session summary if from ambient session
                if quote.source == .ambient {
                    selectedSessionQuote = quote
                    showingSessionSummary = true
                    HapticManager.shared.mediumTap()
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deleteQuote(quote)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                
                Button {
                    shareQuote(quote)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(Color.blue)
                
                Button {
                    startEdit(quote: quote)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(Color.orange)
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
        showEditSheet = true
        HapticManager.shared.lightTap()
    }
    
    private func startEdit(quote: CapturedQuote) {
        editingQuote = quote
        editingNote = nil
        editedText = quote.text
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