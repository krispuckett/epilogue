import SwiftUI
import SwiftData

// MARK: - Session Wrapper for Unified Display
enum SessionType: Identifiable {
    case ambient(AmbientSession)
    case quick(ReadingSession)

    var id: UUID {
        switch self {
        case .ambient(let session):
            return session.id ?? UUID()
        case .quick(let session):
            return session.id
        }
    }

    var startDate: Date {
        switch self {
        case .ambient(let session):
            return session.startTime ?? Date()
        case .quick(let session):
            return session.startDate
        }
    }

    var endDate: Date? {
        switch self {
        case .ambient(let session):
            return session.endTime
        case .quick(let session):
            return session.endDate
        }
    }

    var duration: TimeInterval {
        switch self {
        case .ambient(let session):
            return session.duration
        case .quick(let session):
            return session.currentDuration
        }
    }

    var bookModel: BookModel? {
        switch self {
        case .ambient(let session):
            return session.bookModel
        case .quick(let session):
            return session.bookModel
        }
    }

    var isAmbient: Bool {
        if case .ambient = self { return true }
        return false
    }
}

// MARK: - Minimal Sessions View (Redesigned)
struct MinimalSessionsView: View {
    // Paginated session data - only load recent 50 sessions for performance
    @State private var ambientSessions: [AmbientSession] = []
    @State private var quickSessions: [ReadingSession] = []

    @State private var searchText = ""
    @State private var showingNewChat = false

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel

    private var allSessions: [SessionType] {
        var sessions: [SessionType] = []
        sessions.append(contentsOf: ambientSessions.map { .ambient($0) })
        sessions.append(contentsOf: quickSessions.filter { $0.endDate != nil }.map { .quick($0) })
        return sessions.sorted { $0.startDate > $1.startDate }
    }

    private var filteredSessions: [SessionType] {
        if searchText.isEmpty {
            return allSessions
        }

        return allSessions.filter { sessionType in
            switch sessionType {
            case .ambient(let session):
                let questions = (session.capturedQuestions ?? []).compactMap { $0.content }
                let quotes = (session.capturedQuotes ?? []).compactMap { $0.text }
                let notes = (session.capturedNotes ?? []).compactMap { $0.content }
                let searchContent = (questions + quotes + notes).joined(separator: " ")
                return searchContent.localizedCaseInsensitiveContains(searchText)
            case .quick:
                // Quick sessions don't have searchable content yet
                return false
            }
        }
    }

    private var groupedSessions: [(date: Date, sessions: [SessionType])] {
        Dictionary(grouping: filteredSessions) { sessionType in
            Calendar.current.startOfDay(for: sessionType.startDate)
        }
        .map { (date: $0.key, sessions: $0.value) }
        .sorted { $0.date > $1.date }
    }
    
    var body: some View {
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
            
            if allSessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
            
            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    newChatButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .onChange(of: showingNewChat) { _, showing in
            // Launch generic ambient mode via coordinator
            if showing {
                EpilogueAmbientCoordinator.shared.launchGenericMode()
                showingNewChat = false
            }
        }
        .onAppear {
            loadRecentSessions()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Sessions Yet", systemImage: "bubble.left.and.bubble.right")
                .foregroundStyle(.white)
        } description: {
            Text("Start an ambient reading session to capture your thoughts and reflections as you explore your books")
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Sessions List
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupedSessions, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        // Date header
                        Text(formatDateHeader(group.date))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        
                        // Sessions for this day
                        ForEach(group.sessions) { sessionType in
                            MinimalSessionCard(sessionType: sessionType)
                                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        }
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - New Chat Button
    private var newChatButton: some View {
        Button {
            SensoryFeedback.medium()
            showingNewChat = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
    
    // MARK: - Helper Functions

    private func loadRecentSessions() {
        // Load recent 50 ambient sessions with pagination
        var ambientDescriptor = FetchDescriptor<AmbientSession>(
            sortBy: [SortDescriptor(\AmbientSession.startTime, order: .reverse)]
        )
        ambientDescriptor.fetchLimit = 50
        ambientSessions = (try? modelContext.fetch(ambientDescriptor)) ?? []

        // Load recent 50 quick reading sessions with pagination
        var quickDescriptor = FetchDescriptor<ReadingSession>(
            sortBy: [SortDescriptor(\ReadingSession.startDate, order: .reverse)]
        )
        quickDescriptor.fetchLimit = 50
        quickSessions = (try? modelContext.fetch(quickDescriptor)) ?? []

        #if DEBUG
        print("📊 [MinimalSessionsView] Loaded \(ambientSessions.count) ambient sessions, \(quickSessions.count) quick sessions")
        #endif
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
}

// MARK: - Minimal Session Card
struct MinimalSessionCard: View {
    let sessionType: SessionType
    @State private var isPressed = false
    @State private var showingDetail = false
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    private var book: Book? {
        guard let bookModel = sessionType.bookModel else { return nil }
        return libraryViewModel.books.first { $0.id == bookModel.id }
    }

    private var keyInsight: String {
        switch sessionType {
        case .ambient(let session):
            if let firstQuestion = (session.capturedQuestions ?? []).first {
                return firstQuestion.content ?? ""
            } else if let firstQuote = (session.capturedQuotes ?? []).first {
                return "\"\(firstQuote.text ?? "")\""
            } else if let firstNote = (session.capturedNotes ?? []).first {
                return firstNote.content ?? ""
            }
            return "Reading session"
        case .quick:
            return "Quick Reading Session"
        }
    }

    private var sessionMetrics: String {
        switch sessionType {
        case .ambient(let session):
            let items = [
                (session.capturedQuestions ?? []).isEmpty ? nil : "\((session.capturedQuestions ?? []).count) questions",
                (session.capturedQuotes ?? []).isEmpty ? nil : "\((session.capturedQuotes ?? []).count) quotes",
                (session.capturedNotes ?? []).isEmpty ? nil : "\((session.capturedNotes ?? []).count) notes"
            ].compactMap { $0 }
            return items.isEmpty ? "Empty session" : items.joined(separator: " · ")
        case .quick(let session):
            let minutes = Int(session.currentDuration / 60)
            let pagesText = session.pagesRead > 0 ? "\(session.pagesRead) pages" : "No pages tracked"
            return "\(minutes)m · \(pagesText)"
        }
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: sessionType.startDate, relativeTo: Date())
    }
    
    var body: some View {
        Button {
            SensoryFeedback.light()
            showingDetail = true
        } label: {
            HStack(spacing: 16) {
                // Book cover or placeholder
                if let book = book, let coverURL = book.coverImageURL, let url = URL(string: coverURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 44, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 66)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
                        }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Book title and time
                    HStack {
                        Text(book?.title ?? "Unknown Book")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(timeAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    
                    // Key insight
                    Text(keyInsight)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                    
                    // Metrics
                    Text(sessionMetrics)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Spacer(minLength: 0)
            }
            .padding(DesignSystem.Spacing.inlinePadding)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color.white.opacity(0.05))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity) {
            // Action handled by button
        } onPressingChanged: { pressing in
            withAnimation(DesignSystem.Animation.springStandard) {
                isPressed = pressing
            }
        }
        .onChange(of: showingDetail) { _, showing in
            // Launch ambient mode via coordinator
            if showing {
                switch sessionType {
                case .ambient:
                    if let book = book {
                        EpilogueAmbientCoordinator.shared.launchBookMode(book: book)
                    }
                case .quick:
                    // For quick sessions, just launch generic mode
                    if let book = book {
                        EpilogueAmbientCoordinator.shared.launchBookMode(book: book)
                    }
                }
                showingDetail = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MinimalSessionsView()
            .preferredColorScheme(.dark)
    }
}