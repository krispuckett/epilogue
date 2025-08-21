import SwiftUI
import SwiftData

// MARK: - Proper Chat View (Fixed Implementation)
struct ProperChatView: View {
    @Query(sort: \AmbientSession.startTime, order: .reverse) 
    private var sessions: [AmbientSession]
    
    @State private var searchText = ""
    @State private var showingNewChat = false
    @State private var selectedSession: AmbientSession?
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    private var filteredSessions: [AmbientSession] {
        if searchText.isEmpty {
            return sessions
        }
        
        return sessions.filter { session in
            // Search in content
            let searchContent = (session.capturedQuestions.map(\.content) +
                               session.capturedQuotes.map(\.text) +
                               session.capturedNotes.map(\.content)).joined(separator: " ")
            
            // Search in book title
            let bookTitle = session.bookModel?.title ?? ""
            
            return searchContent.localizedCaseInsensitiveContains(searchText) ||
                   bookTitle.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var groupedSessions: [(date: Date, sessions: [AmbientSession])] {
        Dictionary(grouping: filteredSessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
        .map { (date: $0.key, sessions: $0.value.sorted { $0.startTime > $1.startTime }) }
        .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ZStack {
            // Match LibraryView background
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            if sessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .sheet(item: $selectedSession) { session in
            if let bookModel = session.bookModel {
                // Create proper book reference
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
                NavigationStack {
                    UnifiedChatView(preSelectedBook: book)
                }
            } else {
                NavigationStack {
                    UnifiedChatView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowCommandInput"))) { _ in
            // Start new chat when command palette triggers it
            showingNewChat = true
        }
        .fullScreenCover(isPresented: $showingNewChat) {
            NavigationStack {
                UnifiedChatView()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
        
            Text("No conversations yet")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            
            Text("Tap + to start a reading session")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
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
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 20)
                        
                        // Sessions for this day
                        ForEach(group.sessions) { session in
                            ProperSessionCard(
                                session: session,
                                onTap: {
                                    selectedSession = session
                                }
                            )
                            .environmentObject(libraryViewModel)
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
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

// MARK: - Proper Session Card (Matching Ambient Summary Style)
struct ProperSessionCard: View {
    let session: AmbientSession
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var coverImage: UIImage?
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    private var bookTitle: String {
        session.bookModel?.title ?? "Reading Session"
    }
    
    private var bookAuthor: String {
        session.bookModel?.author ?? ""
    }
    
    private var keyInsight: String {
        if let firstQuestion = session.capturedQuestions.first {
            return firstQuestion.content
        } else if let firstQuote = session.capturedQuotes.first {
            return "\"\(firstQuote.text)\""
        } else if let firstNote = session.capturedNotes.first {
            return firstNote.content
        }
        return "Session with \(bookTitle)"
    }
    
    private var sessionMetrics: [String] {
        var metrics: [String] = []
        if session.capturedQuestions.count > 0 {
            metrics.append("\(session.capturedQuestions.count) question\(session.capturedQuestions.count == 1 ? "" : "s")")
        }
        if session.capturedQuotes.count > 0 {
            metrics.append("\(session.capturedQuotes.count) quote\(session.capturedQuotes.count == 1 ? "" : "s")")
        }
        if session.capturedNotes.count > 0 {
            metrics.append("\(session.capturedNotes.count) note\(session.capturedNotes.count == 1 ? "" : "s")")
        }
        return metrics
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.startTime, relativeTo: Date())
    }
    
    private var sessionDuration: String {
        let duration = session.endTime.timeIntervalSince(session.startTime)
        let minutes = Int(duration / 60)
        if minutes < 1 {
            return "< 1m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
    
    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Top row: Book info and time
                HStack(alignment: .top) {
                    // Book cover
                    Group {
                        if let coverURL = session.bookModel?.coverImageURL,
                           let url = URL(string: coverURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure(_), .empty:
                                    bookPlaceholder
                                @unknown default:
                                    bookPlaceholder
                                }
                            }
                            .frame(width: 48, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            bookPlaceholder
                                .frame(width: 48, height: 72)
                        }
                    }
                    
                    // Book details and metrics
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bookTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        if !bookAuthor.isEmpty {
                            Text(bookAuthor)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        
                        // Time and duration
                        HStack(spacing: 8) {
                            Text(timeAgo)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                            
                            Text("·")
                            
                            Text(sessionDuration)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Spacer()
                }
                
                // Key insight
                Text(keyInsight)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Metrics badges
                if !sessionMetrics.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(sessionMetrics, id: \.self) { metric in
                            Text(metric)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity) {
            // Action handled by button
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
    
    private var bookPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.white.opacity(0.1))
            .overlay {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.3))
            }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ProperChatView()
            .preferredColorScheme(.dark)
    }
}