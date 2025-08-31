import SwiftUI
import SwiftData

// MARK: - Sessions Archive View
struct SessionsArchiveView: View {
    @Query(sort: \AmbientSession.startTime, order: .reverse) 
    private var sessions: [AmbientSession]
    
    @State private var selectedBook: Book?
    @State private var viewMode: ViewMode = .timeline
    @State private var expandedSessionId: UUID?
    @State private var searchText = ""
    @State private var showingSessionDetail: AmbientSession?
    @State private var continuingSession: AmbientSession?
    @State private var colorPalettes: [UUID: ColorPalette] = [:]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    enum ViewMode {
        case timeline
        case byBook
        case connections
        
        var icon: String {
            switch self {
            case .timeline: return "clock"
            case .byBook: return "books.vertical"
            case .connections: return "point.3.connected.trianglepath.dotted"
            }
        }
    }
    
    private var filteredSessions: [AmbientSession] {
        sessions.filter { session in
            if let selectedBook = selectedBook {
                guard session.bookModel?.id == selectedBook.id else { return false }
            }
            
            if !searchText.isEmpty {
                let searchContent = session.capturedQuestions.map(\.content).joined(separator: " ") +
                                  session.capturedQuotes.map(\.text).joined(separator: " ") +
                                  session.capturedNotes.map(\.content).joined(separator: " ")
                guard searchContent.localizedCaseInsensitiveContains(searchText) else { return false }
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient gradient background
                AmbientChatGradientView()
                    .opacity(0.6)
                    .ignoresSafeArea()
                
                // Darkening overlay for readability
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // View mode selector
                        viewModeSelector
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                            .padding(.vertical, 16)
                        
                        // Main content based on view mode
                        switch viewMode {
                        case .timeline:
                            timelineView
                        case .byBook:
                            bookGroupedView
                        case .connections:
                            connectionsView
                        }
                    }
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Reading Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .searchable(text: $searchText, prompt: "Search sessions...")
        }
        .sheet(item: $showingSessionDetail) { session in
            AmbientSessionSummaryView(
                session: session,
                colorPalette: colorPalettes[session.id]
            )
        }
        .fullScreenCover(item: $continuingSession) { session in
            UnifiedChatView(
                preSelectedBook: convertBookModelToBook(session.bookModel),
                startInVoiceMode: false,
                isAmbientMode: false
            )
            .environmentObject(libraryViewModel)
            .environmentObject(notesViewModel)
        }
        .onAppear {
            loadColorPalettes()
        }
    }
    
    // MARK: - View Mode Selector
    private var viewModeSelector: some View {
        HStack(spacing: 0) {
            ForEach([ViewMode.timeline, .byBook, .connections], id: \.self) { mode in
                Button {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        viewMode = mode
                    }
                    SensoryFeedback.light()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 20))
                        Text(String(describing: mode).capitalized)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(viewMode == mode ? .white : DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        if viewMode == mode {
                            Capsule()
                                .fill(.white.opacity(0.1))
                                .matchedGeometryEffect(id: "viewMode", in: viewModeNamespace)
                        }
                    }
                }
            }
        }
        .padding(4)
        .glassEffect(in: Capsule())
    }
    
    @Namespace private var viewModeNamespace
    
    // MARK: - Timeline View
    private var timelineView: some View {
        LazyVStack(spacing: 16) {
            ForEach(groupSessionsByDate()) { dayGroup in
                VStack(alignment: .leading, spacing: 12) {
                    // Date header
                    Text(dayGroup.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    
                    // Sessions for this day
                    ForEach(dayGroup.sessions) { session in
                        SessionTimelineCard(
                            session: session,
                            colorPalette: colorPalettes[session.id],
                            isExpanded: expandedSessionId == session.id,
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    expandedSessionId = expandedSessionId == session.id ? nil : session.id
                                }
                            },
                            onContinue: {
                                continuingSession = session
                            },
                            onViewDetail: {
                                showingSessionDetail = session
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    }
                }
            }
        }
    }
    
    // MARK: - Book Grouped View
    private var bookGroupedView: some View {
        LazyVStack(spacing: 24) {
            ForEach(groupSessionsByBook()) { bookGroup in
                VStack(alignment: .leading, spacing: 12) {
                    // Book header
                    HStack(spacing: 12) {
                        if let coverURL = bookGroup.book.coverImageURL,
                           let url = URL(string: coverURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 40, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bookGroup.book.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(bookGroup.sessions.count) sessions")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    
                    // Sessions for this book
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(bookGroup.sessions) { session in
                                SessionBookCard(
                                    session: session,
                                    colorPalette: colorPalettes[session.id],
                                    onContinue: {
                                        continuingSession = session
                                    },
                                    onViewDetail: {
                                        showingSessionDetail = session
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    }
                }
            }
        }
    }
    
    // MARK: - Connections View
    private var connectionsView: some View {
        VStack(spacing: 20) {
            // Temporal insights
            TemporalInsightsCard(sessions: sessions)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            
            // Character companions
            if !characterCompanions.isEmpty {
                CharacterCompanionsCard(companions: characterCompanions)
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            }
            
            // Theme connections
            ThemeConnectionsCard(sessions: sessions)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
    }
    
    // MARK: - Helper Functions
    private func groupSessionsByDate() -> [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredSessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        
        return grouped.map { DayGroup(date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    private func groupSessionsByBook() -> [BookGroup] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            session.bookModel?.id ?? ""
        }
        
        return grouped.compactMap { bookId, sessions in
            guard let bookModel = sessions.first?.bookModel,
                  let book = convertBookModelToBook(bookModel) else { return nil }
            return BookGroup(book: book, sessions: sessions.sorted { $0.startTime > $1.startTime })
        }
        .sorted { $0.book.title < $1.book.title }
    }
    
    private var characterCompanions: [CharacterCompanion] {
        var companions: [String: [AmbientSession]] = [:]
        
        for session in sessions {
            for question in session.capturedQuestions {
                let characters = extractCharacterNames(from: question.content)
                for character in characters {
                    companions[character, default: []].append(session)
                }
            }
        }
        
        return Array(companions.map { CharacterCompanion(name: $0.key, sessions: $0.value) }
            .sorted { $0.sessions.count > $1.sessions.count }
            .prefix(5))
    }
    
    private func extractCharacterNames(from text: String) -> [String] {
        // Simple extraction - would use NLP in production
        let commonCharacters = ["Elizabeth", "Darcy", "Gatsby", "Nick", "Frodo", "Gandalf", "Harry", "Hermione"]
        return commonCharacters.filter { text.contains($0) }
    }
    
    private func convertBookModelToBook(_ bookModel: BookModel?) -> Book? {
        guard let bookModel = bookModel else { return nil }
        return libraryViewModel.books.first { $0.id == bookModel.id }
    }
    
    private func loadColorPalettes() {
        for session in sessions {
            if let book = convertBookModelToBook(session.bookModel),
               let coverURL = book.coverImageURL,
               let url = URL(string: coverURL) {
                Task {
                    // Download image from URL
                    if let (data, _) = try? await URLSession.shared.data(from: url),
                       let uiImage = UIImage(data: data) {
                        let extractor = OKLABColorExtractor()
                        if let palette = try? await extractor.extractPalette(from: uiImage) {
                            await MainActor.run {
                                colorPalettes[session.id] = palette
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types
struct DayGroup: Identifiable {
    let id = UUID()
    let date: Date
    let sessions: [AmbientSession]
}

struct BookGroup: Identifiable {
    let id = UUID()
    let book: Book
    let sessions: [AmbientSession]
}

struct CharacterCompanion: Identifiable {
    let id = UUID()
    let name: String
    let sessions: [AmbientSession]
}

// MARK: - Preview
#Preview {
    SessionsArchiveView()
        .preferredColorScheme(.dark)
}