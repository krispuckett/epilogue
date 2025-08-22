import SwiftUI
import SwiftData

// MARK: - Refined Chat Sessions View
struct ChatSessionsViewRefined: View {
    @Query(sort: \AmbientSession.startTime, order: .reverse) 
    private var sessions: [AmbientSession]
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedGrouping: SessionGrouping = .books
    @State private var selectedSession: AmbientSession?
    @State private var expandedSessions = Set<UUID>()
    @State private var colorPalettes: [String: ColorPalette] = [:]
    @State private var showingFilterPopover = false
    @State private var selectedFilter: SessionFilter = .all
    @State private var hasMigratedSessions = false
    @State private var isSelectionMode = false
    @State private var selectedSessionIds = Set<UUID>()
    @State private var showingDeleteAlert = false
    @State private var sessionToDelete: AmbientSession?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    enum SessionGrouping: String, CaseIterable {
        case books = "Books"
        case timeline = "Timeline"
        
        var icon: String {
            switch self {
            case .books: return "books.vertical"
            case .timeline: return "clock"
            }
        }
    }
    
    enum SessionFilter: String, CaseIterable {
        case all = "All"
        case questions = "Questions"
        case quotes = "Quotes"
        case notes = "Notes"
        
        var icon: String {
            switch self {
            case .all: return "circle.grid.3x3"
            case .questions: return "questionmark.circle"
            case .quotes: return "quote.bubble"
            case .notes: return "note.text"
            }
        }
    }
    
    private var filteredSessions: [AmbientSession] {
        var filtered = sessions
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { session in
                let content = (session.capturedQuestions.map(\.content) +
                              session.capturedQuotes.map(\.text) +
                              session.capturedNotes.map(\.content)).joined(separator: " ")
                let bookTitle = session.bookModel?.title ?? ""
                
                return content.localizedCaseInsensitiveContains(searchText) ||
                       bookTitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .questions:
            filtered = filtered.filter { !$0.capturedQuestions.isEmpty }
        case .quotes:
            filtered = filtered.filter { !$0.capturedQuotes.isEmpty }
        case .notes:
            filtered = filtered.filter { !$0.capturedNotes.isEmpty }
        }
        
        return filtered
    }
    
    var body: some View {
        ZStack {
            // LibraryView background
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Content based on grouping
                switch selectedGrouping {
                case .books:
                    bookGroupedView
                case .timeline:
                    timelineGroupedView
                }
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .searchable(text: $searchText, isPresented: $isSearching, placement: .navigationBarDrawer(displayMode: .automatic))
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                AmbientSessionSummaryView(
                    session: session,
                    colorPalette: colorPalettes[session.bookModel?.id ?? ""]
                )
            }
        }
        .alert("Delete Sessions", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedSessions()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedSessionIds.count) session\(selectedSessionIds.count == 1 ? "" : "s")? This action cannot be undone.")
        }
        .onAppear {
            print("🔍 ChatSessionsViewRefined appeared with \(sessions.count) sessions")
            
            // Migrate orphaned sessions on first appearance
            if !hasMigratedSessions {
                Task {
                    await SessionMigrationService.shared.migrateOrphanedSessions(
                        modelContext: modelContext,
                        libraryViewModel: libraryViewModel
                    )
                    hasMigratedSessions = true
                    
                    // Load color palettes after migration completes
                    await MainActor.run {
                        loadColorPalettes()
                    }
                }
            } else {
                // Only load palettes if we've already migrated
                loadColorPalettes()
            }
        }
    }
    
    // MARK: - Toolbar (Matching Notes view exactly)
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                // Edit/Done button - always visible
                if !filteredSessions.isEmpty {
                    if isSelectionMode {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelectionMode = false
                                selectedSessionIds.removeAll()
                            }
                            HapticManager.shared.lightTap()
                        } label: {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        }
                        
                        if !selectedSessionIds.isEmpty {
                            Button {
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                        }
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSelectionMode = true
                            }
                            HapticManager.shared.lightTap()
                        } label: {
                            Text("Edit")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                
                // Search button - simple like Notes
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSearching.toggle()
                        if !isSearching {
                            searchText = ""
                        }
                    }
                    HapticManager.shared.lightTap()
                } label: {
                    if isSearching {
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
                
                // Filter selector - simple menu like Notes
                Menu {
                    // View options
                    Section("View") {
                        ForEach(SessionGrouping.allCases, id: \.self) { grouping in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedGrouping = grouping
                                }
                                HapticManager.shared.lightTap()
                            } label: {
                                Label {
                                    HStack {
                                        Text(grouping.rawValue)
                                        Spacer()
                                        if selectedGrouping == grouping {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                    }
                                } icon: {
                                    Image(systemName: grouping.icon)
                                }
                            }
                        }
                    }
                    
                    Section("Filter") {
                        ForEach(SessionFilter.allCases, id: \.self) { filter in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedFilter = filter
                                }
                                HapticManager.shared.lightTap()
                            } label: {
                                Label {
                                    HStack {
                                        Text(filter.rawValue)
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
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedFilter.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(filteredSessions.count)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                
                // Migration button (if needed)
                if sessions.contains(where: { $0.bookModel == nil }) {
                    Button {
                        Task {
                            print("🔄 Manual migration triggered")
                            await SessionMigrationService.shared.migrateOrphanedSessions(
                                modelContext: modelContext,
                                libraryViewModel: libraryViewModel
                            )
                            loadColorPalettes()
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
                }
            }
        }
    }
    
    // MARK: - Book Grouped View
    private var bookGroupedView: some View {
        ScrollView {
            if filteredSessions.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text("No Reading Sessions Yet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("Start an ambient reading session to capture\nyour thoughts, questions, and favorite quotes")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 24) {
                    ForEach(groupSessionsByBook(), id: \.book.id) { group in
                        BookSessionGroupWithSelection(
                            book: group.book,
                            sessions: group.sessions,
                            colorPalette: colorPalettes[group.book.id],
                            expandedSessions: $expandedSessions,
                            isSelectionMode: isSelectionMode,
                            selectedSessionIds: $selectedSessionIds,
                            onSelectSession: { session in
                                if isSelectionMode {
                                    toggleSessionSelection(session)
                                } else {
                                    selectedSession = session
                                }
                            },
                            onDeleteSession: { session in
                                sessionToDelete = session
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 100)
            }
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Timeline Grouped View
    private var timelineGroupedView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(Array(filteredSessions.enumerated()), id: \.1.id) { index, session in
                    IntelligentSessionCard(
                        session: session,
                        colorPalette: colorPalettes[session.bookModel?.id ?? ""],
                        isExpanded: expandedSessions.contains(session.id),
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedSessionIds.contains(session.id),
                        onTap: {
                            if isSelectionMode {
                                toggleSessionSelection(session)
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if expandedSessions.contains(session.id) {
                                        expandedSessions.remove(session.id)
                                    } else {
                                        expandedSessions.insert(session.id)
                                    }
                                }
                            }
                        },
                        onSelect: {
                            selectedSession = session
                        },
                        onDelete: {
                            sessionToDelete = session
                            showingDeleteAlert = true
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Helper Functions
    private func toggleSessionSelection(_ session: AmbientSession) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            if selectedSessionIds.contains(session.id) {
                selectedSessionIds.remove(session.id)
            } else {
                selectedSessionIds.insert(session.id)
            }
        }
        HapticManager.shared.lightTap()
    }
    
    private func deleteSelectedSessions() {
        for sessionId in selectedSessionIds {
            if let session = sessions.first(where: { $0.id == sessionId }) {
                modelContext.delete(session)
            }
        }
        
        do {
            try modelContext.save()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSessionIds.removeAll()
                isSelectionMode = false
            }
            HapticManager.shared.success()
        } catch {
            print("❌ Failed to delete sessions: \(error)")
        }
    }
    
    private func groupSessionsByBook() -> [(book: Book, sessions: [AmbientSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.bookModel?.id ?? ""
        }
        
        return grouped.compactMap { bookId, sessions in
            guard let bookModel = sessions.first?.bookModel else { return nil }
            
            // Convert HTTP to HTTPS for cover URLs
            var secureCoverURL = bookModel.coverImageURL
            if let coverURL = bookModel.coverImageURL, coverURL.hasPrefix("http://") {
                secureCoverURL = coverURL.replacingOccurrences(of: "http://", with: "https://")
            }
            
            let book = Book(
                id: bookModel.id,
                title: bookModel.title,
                author: bookModel.author,
                publishedYear: bookModel.publishedYear,
                coverImageURL: secureCoverURL,
                isbn: bookModel.isbn,
                description: bookModel.desc,
                pageCount: bookModel.pageCount
            )
            
            return (book: book, sessions: sessions.sorted { $0.startTime > $1.startTime })
        }
        .sorted { $0.sessions.first?.startTime ?? Date() > $1.sessions.first?.startTime ?? Date() }
    }
    
    
    private func loadColorPalettes() {
        print("🎨 Loading color palettes for unique books")
        
        // Get unique book IDs to avoid duplicate processing
        var uniqueBookIds = Set<String>()
        for session in sessions {
            if let bookId = session.bookModel?.id {
                uniqueBookIds.insert(bookId)
            }
        }
        
        print("   Found \(uniqueBookIds.count) unique books from \(sessions.count) sessions")
        
        // Only process books we haven't already processed
        for bookId in uniqueBookIds {
            // Skip if we already have this palette
            if colorPalettes[bookId] != nil {
                continue
            }
            
            guard let session = sessions.first(where: { $0.bookModel?.id == bookId }),
                  let bookModel = session.bookModel,
                  let coverURL = bookModel.coverImageURL else { continue }
            
            // Convert HTTP to HTTPS
            let secureURL = coverURL.hasPrefix("http://") 
                ? coverURL.replacingOccurrences(of: "http://", with: "https://") 
                : coverURL
            
            guard let url = URL(string: secureURL) else { continue }
            
            // Use a single task with proper memory management
            Task { @MainActor in
                // Check again if we already have this palette (race condition prevention)
                if colorPalettes[bookId] != nil { return }
                
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    
                    // Use autoreleasepool to ensure image memory is freed
                    await withCheckedContinuation { continuation in
                        autoreleasepool {
                            if let uiImage = UIImage(data: data) {
                                let extractor = OKLABColorExtractor()
                                Task {
                                    if let palette = try? await extractor.extractPalette(from: uiImage) {
                                        await MainActor.run {
                                            colorPalettes[bookId] = palette
                                        }
                                    }
                                    continuation.resume()
                                }
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                } catch {
                    print("Failed to load palette for \(bookModel.title): \(error)")
                }
            }
        }
    }
}

// MARK: - Book Session Group With Selection
struct BookSessionGroupWithSelection: View {
    let book: Book
    let sessions: [AmbientSession]
    let colorPalette: ColorPalette?
    @Binding var expandedSessions: Set<UUID>
    let isSelectionMode: Bool
    @Binding var selectedSessionIds: Set<UUID>
    let onSelectSession: (AmbientSession) -> Void
    let onDeleteSession: (AmbientSession) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Book header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.lightTap()
            }) {
                HStack(spacing: 12) {
                    // Book cover with HTTPS conversion
                    if let coverURL = book.coverImageURL {
                        let secureURL = coverURL.hasPrefix("http://") 
                            ? coverURL.replacingOccurrences(of: "http://", with: "https://") 
                            : coverURL
                        
                        if let url = URL(string: secureURL) {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white.opacity(0.1))
                            }
                            .frame(width: 40, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    } else {
                        // Fallback when no cover URL
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3),
                                    Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 40, height: 60)
                            .overlay {
                                Text(String(book.title.prefix(2)))
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text("\(sessions.count) sessions")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Sessions
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(sessions.prefix(5)) { session in
                        IntelligentSessionCard(
                            session: session,
                            colorPalette: colorPalette,
                            isExpanded: expandedSessions.contains(session.id),
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedSessionIds.contains(session.id),
                            onTap: {
                                if isSelectionMode {
                                    onSelectSession(session)
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        if expandedSessions.contains(session.id) {
                                            expandedSessions.remove(session.id)
                                        } else {
                                            expandedSessions.insert(session.id)
                                        }
                                    }
                                }
                            },
                            onSelect: {
                                onSelectSession(session)
                            },
                            onDelete: {
                                onDeleteSession(session)
                            }
                        )
                    }
                    
                    if sessions.count > 5 {
                        Button(action: {
                            // TODO: Show all sessions
                        }) {
                            Text("Show \(sessions.count - 5) more")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Intelligent Session Card
struct IntelligentSessionCard: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    let isExpanded: Bool
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    private var intelligentTitle: String {
        // Always use book title as the primary title
        return session.bookModel?.title ?? "Reading Session"
    }
    
    private var sessionSummary: String {
        // Create an intelligent summary based on the session content
        let questions = session.capturedQuestions
        let quotes = session.capturedQuotes
        let notes = session.capturedNotes
        
        // Priority 1: Look for the most impactful question
        if !questions.isEmpty {
            // Find questions with answers for better context
            if let answeredQuestion = questions.first(where: { question in
                if let answer = question.answer, !answer.isEmpty {
                    return true
                }
                return false
            }) {
                return "\(answeredQuestion.content)"
            }
            if let firstQuestion = questions.first {
                return "\(firstQuestion.content)"
            }
        }
        
        // Priority 2: Look for meaningful quotes
        if !quotes.isEmpty {
            if let longestQuote = quotes.max(by: { $0.text.count < $1.text.count }) {
                let preview = String(longestQuote.text.prefix(120))
                return "\"\(preview)\(longestQuote.text.count > 120 ? "..." : "\"")"
            }
        }
        
        // Priority 3: Look for notes with substance
        if !notes.isEmpty {
            if let longestNote = notes.max(by: { $0.content.count < $1.content.count }) {
                return "\(longestNote.content)"
            }
        }
        
        // Fallback to a generic summary based on content counts
        let totalItems = questions.count + quotes.count + notes.count
        if totalItems > 0 {
            return "\(totalItems) captured insights from this session"
        }
        
        return "New reading session"
    }
    
    private var metrics: [String] {
        var items: [String] = []
        if session.capturedQuestions.count > 0 {
            items.append("\(session.capturedQuestions.count) QUESTIONS")
        }
        if session.capturedQuotes.count > 0 {
            items.append("\(session.capturedQuotes.count) QUOTES")
        }
        if session.capturedNotes.count > 0 {
            items.append("\(session.capturedNotes.count) NOTES")
        }
        return items
    }
    
    private var timeDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let dateStr = formatter.string(from: session.startTime)
        
        let duration = session.endTime.timeIntervalSince(session.startTime)
        let minutes = Int(duration / 60)
        let durationStr = minutes < 60 ? "\(minutes)m" : "\(minutes/60)h \(minutes%60)m"
        
        var components: [String] = [dateStr, durationStr]
        
        // Add content counts
        if session.capturedQuotes.count > 0 {
            components.append("\(session.capturedQuotes.count) quotes")
        }
        if session.capturedNotes.count > 0 {
            components.append("\(session.capturedNotes.count) notes")
        }
        
        return components.joined(separator: " · ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with book title and time
                    HStack {
                        // Selection checkbox when in selection mode
                        if isSelectionMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white.opacity(0.3))
                                .contentShape(Circle())
                                .padding(.trailing, 8)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(intelligentTitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(1)
                            
                            Text(timeDisplay)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    
                    // Session preview (always show)
                    Text(sessionSummary)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: !isExpanded)
                    
                    // Metrics with cleaner design
                    if !metrics.isEmpty {
                        HStack(spacing: 20) {
                            ForEach(metrics, id: \.self) { metric in
                                Text(metric)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .tracking(1.0)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded actions with iOS 26 glass design
            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 0.5)
                    
                    HStack(spacing: 10) {
                        Button(action: onSelect) {
                            HStack(spacing: 6) {
                                Image(systemName: "eye")
                                    .font(.system(size: 13, weight: .medium))
                                Text("View")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Button(action: {
                            HapticManager.shared.mediumTap()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Continue")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.08))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}