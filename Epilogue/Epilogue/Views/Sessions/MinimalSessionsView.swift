import SwiftUI
import SwiftData

// MARK: - Minimal Sessions View (Redesigned)
struct MinimalSessionsView: View {
    @Query(sort: \AmbientSession.startTime, order: .reverse) 
    private var sessions: [AmbientSession]
    
    @State private var searchText = ""
    @State private var showingNewChat = false
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    private var filteredSessions: [AmbientSession] {
        if searchText.isEmpty {
            return sessions
        }
        
        return sessions.filter { session in
            let searchContent = (session.capturedQuestions.map(\.content) +
                               session.capturedQuotes.map(\.text) +
                               session.capturedNotes.map(\.content)).joined(separator: " ")
            return searchContent.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var groupedSessions: [(date: Date, sessions: [AmbientSession])] {
        Dictionary(grouping: filteredSessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
        .map { (date: $0.key, sessions: $0.value) }
        .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ZStack {
            // Clean dark background like LibraryView
            DesignSystem.Colors.surfaceBackground
                .ignoresSafeArea()
            
            if sessions.isEmpty {
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
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .fullScreenCover(isPresented: $showingNewChat) {
            NavigationStack {
                UnifiedChatView()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        ModernEmptyStates.noSessions
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
                        ForEach(group.sessions) { session in
                            MinimalSessionCard(session: session)
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
    let session: AmbientSession
    @State private var isPressed = false
    @State private var showingDetail = false
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    private var book: Book? {
        guard let bookModel = session.bookModel else { return nil }
        return libraryViewModel.books.first { $0.id == bookModel.id }
    }
    
    private var keyInsight: String {
        if let firstQuestion = session.capturedQuestions.first {
            return firstQuestion.content
        } else if let firstQuote = session.capturedQuotes.first {
            return "\"\(firstQuote.text)\""
        } else if let firstNote = session.capturedNotes.first {
            return firstNote.content
        }
        return "Reading session"
    }
    
    private var sessionMetrics: String {
        let items = [
            session.capturedQuestions.isEmpty ? nil : "\(session.capturedQuestions.count) questions",
            session.capturedQuotes.isEmpty ? nil : "\(session.capturedQuotes.count) quotes",
            session.capturedNotes.isEmpty ? nil : "\(session.capturedNotes.count) notes"
        ].compactMap { $0 }
        
        return items.isEmpty ? "Empty session" : items.joined(separator: " · ")
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.startTime, relativeTo: Date())
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
        .sheet(isPresented: $showingDetail) {
            if let book = book {
                NavigationStack {
                    UnifiedChatView(preSelectedBook: book)
                }
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