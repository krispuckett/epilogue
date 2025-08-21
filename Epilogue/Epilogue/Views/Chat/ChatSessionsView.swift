import SwiftUI
import SwiftData

// MARK: - Chat Sessions View (Steve Jobs Worthy)
struct ChatSessionsView: View {
    @Query(sort: \AmbientSession.startTime, order: .reverse) 
    private var sessions: [AmbientSession]
    
    @State private var searchText = ""
    @State private var selectedGrouping: SessionGrouping = .byBook
    @State private var selectedSession: AmbientSession?
    @State private var showingNewSession = false
    @State private var expandedSessions = Set<UUID>()
    @State private var colorPalettes: [String: ColorPalette] = [:]
    @State private var bookCovers: [String: UIImage] = [:]
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    @Namespace private var cardAnimation
    @State private var scrollProxy: ScrollViewProxy?
    
    enum SessionGrouping: String, CaseIterable {
        case byBook = "Books"
        case byDate = "Timeline"
        case byInsight = "Insights"
        
        var icon: String {
            switch self {
            case .byBook: return "books.vertical"
            case .byDate: return "clock"
            case .byInsight: return "sparkle"
            }
        }
    }
    
    private var filteredSessions: [AmbientSession] {
        if searchText.isEmpty {
            return sessions
        }
        
        return sessions.filter { session in
            let content = (session.capturedQuestions.map(\.content) +
                          session.capturedQuotes.map(\.text) +
                          session.capturedNotes.map(\.content)).joined(separator: " ")
            let bookTitle = session.bookModel?.title ?? ""
            
            return content.localizedCaseInsensitiveContains(searchText) ||
                   bookTitle.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Ambient gradient background - the foundation
            ambientBackground
            
            // Main content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Elegant grouping selector
                        groupingSelector
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        
                        // Content based on grouping
                        Group {
                            switch selectedGrouping {
                            case .byBook:
                                bookGroupedSessions
                            case .byDate:
                                dateGroupedSessions
                            case .byInsight:
                                insightGroupedSessions
                            }
                        }
                        .padding(.bottom, 100) // Space for tab bar + action bar
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                AmbientSessionSummaryView(
                    session: session,
                    colorPalette: colorPalettes[session.bookModel?.id ?? ""]
                )
            }
        }
        .onAppear {
            loadColorPalettes()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowCommandInput"))) { _ in
            startNewSession()
        }
    }
    
    // MARK: - Ambient Background
    private var ambientBackground: some View {
        ZStack {
            // Base gradient
            if let firstSession = sessions.first,
               let palette = colorPalettes[firstSession.bookModel?.id ?? ""] {
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: 0.3,
                    audioLevel: 0
                )
                .ignoresSafeArea()
            } else {
                AmbientChatGradientView()
                    .opacity(0.5)
                    .ignoresSafeArea()
            }
            
            // Darkening for readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Grouping Selector (Clean, not tabs)
    private var groupingSelector: some View {
        HStack(spacing: 12) {
            ForEach(SessionGrouping.allCases, id: \.self) { grouping in
                GroupingChip(
                    grouping: grouping,
                    isSelected: selectedGrouping == grouping,
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedGrouping = grouping
                        }
                        HapticManager.shared.lightTap()
                    }
                )
            }
        }
    }
    
    // MARK: - Book Grouped Sessions
    private var bookGroupedSessions: some View {
        LazyVStack(spacing: 24) {
            ForEach(groupSessionsByBook(), id: \.book.id) { group in
                BookSessionGroup(
                    book: group.book,
                    sessions: group.sessions,
                    colorPalette: colorPalettes[group.book.id],
                    expandedSessions: $expandedSessions,
                    onSelectSession: { session in
                        selectedSession = session
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Date Grouped Sessions
    private var dateGroupedSessions: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(groupSessionsByDate(), id: \.date) { group in
                VStack(alignment: .leading, spacing: 12) {
                    // Date header
                    Text(formatDateHeader(group.date))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.5)
                    
                    ForEach(group.sessions) { session in
                        AmbientSessionCard(
                            session: session,
                            colorPalette: colorPalettes[session.bookModel?.id ?? ""],
                            isExpanded: expandedSessions.contains(session.id),
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if expandedSessions.contains(session.id) {
                                        expandedSessions.remove(session.id)
                                    } else {
                                        expandedSessions.insert(session.id)
                                    }
                                }
                            },
                            onSelect: {
                                selectedSession = session
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Insight Grouped Sessions (AI-powered)
    private var insightGroupedSessions: some View {
        LazyVStack(spacing: 24) {
            // Deep Questions
            if !questionsGroup.isEmpty {
                InsightGroup(
                    title: "Deep Questions",
                    icon: "questionmark.circle",
                    sessions: questionsGroup,
                    colorPalettes: colorPalettes,
                    expandedSessions: $expandedSessions,
                    onSelectSession: { selectedSession = $0 }
                )
            }
            
            // Key Quotes
            if !quotesGroup.isEmpty {
                InsightGroup(
                    title: "Memorable Quotes",
                    icon: "quote.bubble",
                    sessions: quotesGroup,
                    colorPalettes: colorPalettes,
                    expandedSessions: $expandedSessions,
                    onSelectSession: { selectedSession = $0 }
                )
            }
            
            // Reflections
            if !reflectionsGroup.isEmpty {
                InsightGroup(
                    title: "Personal Reflections",
                    icon: "sparkles",
                    sessions: reflectionsGroup,
                    colorPalettes: colorPalettes,
                    expandedSessions: $expandedSessions,
                    onSelectSession: { selectedSession = $0 }
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Functions
    private func groupSessionsByBook() -> [(book: Book, sessions: [AmbientSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.bookModel?.id ?? ""
        }
        
        return grouped.compactMap { bookId, sessions in
            guard let bookModel = sessions.first?.bookModel else { return nil }
            
            let book = Book(
                id: bookModel.id,
                title: bookModel.title,
                author: bookModel.author,
                publishedYear: bookModel.publishedYear,
                coverImageURL: bookModel.coverImageURL,
                isbn: bookModel.isbn,
                description: bookModel.desc,
                pageCount: bookModel.pageCount
            )
            
            return (book: book, sessions: sessions.sorted { $0.startTime > $1.startTime })
        }
        .sorted { $0.sessions.first?.startTime ?? Date() > $1.sessions.first?.startTime ?? Date() }
    }
    
    private func groupSessionsByDate() -> [(date: Date, sessions: [AmbientSession])] {
        Dictionary(grouping: filteredSessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
        .map { (date: $0.key, sessions: $0.value.sorted { $0.startTime > $1.startTime }) }
        .sorted { $0.date > $1.date }
    }
    
    private var questionsGroup: [AmbientSession] {
        filteredSessions.filter { !$0.capturedQuestions.isEmpty }
            .sorted { $0.capturedQuestions.count > $1.capturedQuestions.count }
    }
    
    private var quotesGroup: [AmbientSession] {
        filteredSessions.filter { !$0.capturedQuotes.isEmpty }
            .sorted { $0.capturedQuotes.count > $1.capturedQuotes.count }
    }
    
    private var reflectionsGroup: [AmbientSession] {
        filteredSessions.filter { !$0.capturedNotes.isEmpty }
            .sorted { $0.capturedNotes.count > $1.capturedNotes.count }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
    
    private func loadColorPalettes() {
        for session in sessions {
            guard let bookModel = session.bookModel,
                  let coverURL = bookModel.coverImageURL,
                  let url = URL(string: coverURL) else { continue }
            
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let uiImage = UIImage(data: data) {
                    let extractor = OKLABColorExtractor()
                    if let palette = try? await extractor.extractPalette(from: uiImage) {
                        await MainActor.run {
                            colorPalettes[bookModel.id] = palette
                            bookCovers[bookModel.id] = uiImage
                        }
                    }
                }
            }
        }
    }
    
    private func startNewSession() {
        // Navigate to new chat
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToTab"),
            object: nil,
            userInfo: ["tab": 2, "action": "newChat"]
        )
    }
}

// MARK: - Grouping Chip
struct GroupingChip: View {
    let grouping: ChatSessionsView.SessionGrouping
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: grouping.icon)
                    .font(.system(size: 14))
                Text(grouping.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(in: Capsule())
            .overlay {
                if isSelected {
                    Capsule()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Ambient Session Card (Beautiful like summary view)
struct AmbientSessionCard: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    let isExpanded: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    
    @State private var isPressed = false
    
    private var bookTitle: String {
        session.bookModel?.title ?? "Reading Session"
    }
    
    private var keyInsight: String {
        if let firstQuestion = session.capturedQuestions.first {
            return firstQuestion.content
        } else if let firstQuote = session.capturedQuotes.first {
            return "\"\(firstQuote.text)\""
        } else if let firstNote = session.capturedNotes.first {
            return firstNote.content
        }
        return "Session"
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let timeAgo = formatter.localizedString(for: session.startTime, relativeTo: Date())
        
        let duration = session.endTime.timeIntervalSince(session.startTime)
        let minutes = Int(duration / 60)
        let durationStr = minutes < 60 ? "\(minutes)m" : "\(minutes/60)h \(minutes%60)m"
        
        return "\(timeAgo) · \(durationStr)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bookTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Text(timeDisplay)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    
                    // Key insight
                    Text(keyInsight)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Metrics
                    if !metrics.isEmpty {
                        HStack(spacing: 16) {
                            ForEach(metrics, id: \.self) { metric in
                                Text(metric)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .tracking(1.2)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded actions
            if isExpanded {
                HStack(spacing: 0) {
                    Button(action: onSelect) {
                        HStack {
                            Spacer()
                            Text("View Session")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    Divider()
                        .frame(height: 20)
                        .overlay(.white.opacity(0.1))
                    
                    Button(action: {
                        // Continue session
                        HapticManager.shared.mediumTap()
                    }) {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - Book Session Group
struct BookSessionGroup: View {
    let book: Book
    let sessions: [AmbientSession]
    let colorPalette: ColorPalette?
    @Binding var expandedSessions: Set<UUID>
    let onSelectSession: (AmbientSession) -> Void
    
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
                    // Book cover
                    if let coverURL = book.coverImageURL,
                       let url = URL(string: coverURL) {
                        AsyncImage(url: url) { image in
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
                    ForEach(sessions.prefix(3)) { session in
                        AmbientSessionCard(
                            session: session,
                            colorPalette: colorPalette,
                            isExpanded: expandedSessions.contains(session.id),
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if expandedSessions.contains(session.id) {
                                        expandedSessions.remove(session.id)
                                    } else {
                                        expandedSessions.insert(session.id)
                                    }
                                }
                            },
                            onSelect: {
                                onSelectSession(session)
                            }
                        )
                    }
                    
                    if sessions.count > 3 {
                        Button(action: {
                            // Show all sessions
                        }) {
                            Text("Show \(sessions.count - 3) more")
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

// MARK: - Insight Group
struct InsightGroup: View {
    let title: String
    let icon: String
    let sessions: [AmbientSession]
    let colorPalettes: [String: ColorPalette]
    @Binding var expandedSessions: Set<UUID>
    let onSelectSession: (AmbientSession) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    Text("(\(sessions.count))")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Sessions
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(sessions.prefix(5)) { session in
                        AmbientSessionCard(
                            session: session,
                            colorPalette: colorPalettes[session.bookModel?.id ?? ""],
                            isExpanded: expandedSessions.contains(session.id),
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if expandedSessions.contains(session.id) {
                                        expandedSessions.remove(session.id)
                                    } else {
                                        expandedSessions.insert(session.id)
                                    }
                                }
                            },
                            onSelect: {
                                onSelectSession(session)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ChatSessionsView()
            .preferredColorScheme(.dark)
    }
}