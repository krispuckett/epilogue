import SwiftUI
import SwiftData

// MARK: - Session History Data Model
struct SessionHistoryData: Identifiable {
    let id: UUID
    let bookId: String?
    let bookTitle: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let questionCount: Int
    let quoteCount: Int
    let insightCount: Int
    let mood: String
    let clusters: [String] // Simplified for now
    let allContent: [ContentSummary]
    let sessionType: String
    
    init(id: UUID = UUID(), bookId: String? = nil, bookTitle: String, startTime: Date, endTime: Date, duration: TimeInterval, questionCount: Int = 0, quoteCount: Int = 0, insightCount: Int = 0, mood: String = "neutral", clusters: [String] = [], allContent: [ContentSummary] = [], sessionType: String = "Reading") {
        self.id = id
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.questionCount = questionCount
        self.quoteCount = quoteCount
        self.insightCount = insightCount
        self.mood = mood
        self.clusters = clusters
        self.allContent = allContent
        self.sessionType = sessionType
    }
    
    // MARK: - Static Methods
    static func loadForBook(_ bookId: String) -> [SessionHistoryData] {
        let allSessions = loadAll()
        return allSessions.filter { $0.bookId == bookId }
    }
    
    static func loadAll() -> [SessionHistoryData] {
        // For now, return empty array - this would load from persistent storage
        return []
    }
    
    static func saveAll(_ sessions: [SessionHistoryData]) {
        // For now, no-op - this would save to persistent storage
    }
    
    // MARK: - Nested Types
    struct ContentSummary: Identifiable {
        let id = UUID()
        let type: String
        let text: String
        let timestamp: Date
        
        init(type: String, text: String, timestamp: Date = Date()) {
            self.type = type
            self.text = text
            self.timestamp = timestamp
        }
    }
}

struct BookSessionHistoryCard: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [AmbientSession]
    @State private var isExpanded = false
    @State private var selectedSession: AmbientSession?
    @State private var showingFullSession = false
    
    // Filter sessions for this book
    private var bookSessions: [AmbientSession] {
        allSessions.filter { session in
            session.bookModel?.id == book.id || 
            session.bookModel?.isbn == book.isbn ||
            session.bookModel?.title == book.title
        }.sorted { $0.startTime > $1.startTime }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with cleaner design
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.16))
                    
                    Text("Reading Sessions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !bookSessions.isEmpty {
                        Text("\(bookSessions.count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.1))
                            )
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded && !bookSessions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(bookSessions.prefix(5), id: \.id) { session in
                        AmbientSessionRow(session: session) {
                            selectedSession = session
                            showingFullSession = true
                        }
                    }
                    
                    if bookSessions.count > 5 {
                        HStack {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("\(bookSessions.count - 5) more sessions")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if isExpanded && bookSessions.isEmpty {
                Text("No reading sessions yet")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .italic()
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingFullSession) {
            if let session = selectedSession {
                AmbientSessionSummaryView(session: session, colorPalette: nil)
            }
        }
    }
}

struct SessionRowView: View {
    let session: SessionHistoryData
    let onTap: () -> Void
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.startTime)
    }
    
    private var durationText: String {
        let minutes = Int(session.duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        if session.questionCount > 0 {
                            Label("\(session.questionCount)", systemImage: "questionmark.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        if session.quoteCount > 0 {
                            Label("\(session.quoteCount)", systemImage: "quote.bubble")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        if session.insightCount > 0 {
                            Label("\(session.insightCount)", systemImage: "lightbulb")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Text(durationText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FullSessionView: View {
    let session: SessionHistoryData
    let book: Book
    @Environment(\.dismiss) private var dismiss
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: session.startTime)
    }
    
    private var durationText: String {
        let minutes = Int(session.duration / 60)
        if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            }
            return "\(hours) hour\(hours > 1 ? "s" : "") \(remainingMinutes) minutes"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Session Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formattedDate)
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            Label(durationText, systemImage: "clock")
                            
                            if session.questionCount > 0 {
                                Label("\(session.questionCount) questions", systemImage: "questionmark.circle")
                            }
                            
                            if session.quoteCount > 0 {
                                Label("\(session.quoteCount) quotes", systemImage: "quote.bubble")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Chat History
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Conversation")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(session.allContent) { content in
                            ChatHistoryBubble(content: content)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Session Stats
                    if !session.clusters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Topics Discussed")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(session.clusters, id: \.self) { topic in
                                HStack {
                                    Text(topic)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Reading Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: shareSession) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func shareSession() {
        var text = "# Reading Session: \(book.title)\n"
        text += "Date: \(formattedDate)\n"
        text += "Duration: \(durationText)\n\n"
        
        text += "## Conversation\n\n"
        
        for content in session.allContent {
            let prefix = content.type == "question" ? "Q:" : 
                        content.type == "quote" ? "Quote:" :
                        content.type == "insight" ? "Insight:" : ""
            text += "\(prefix) \(content.text)\n\n"
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

struct ChatHistoryBubble: View {
    let content: SessionHistoryData.ContentSummary
    
    private var icon: String {
        switch content.type {
        case "question": return "questionmark.circle.fill"
        case "quote": return "quote.bubble.fill"
        case "insight": return "lightbulb.fill"
        case "reflection": return "brain.head.profile"
        case "connection": return "link.circle.fill"
        default: return "text.bubble.fill"
        }
    }
    
    private var color: Color {
        switch content.type {
        case "question": return .blue
        case "quote": return .green
        case "insight": return .orange
        case "reflection": return .purple
        case "connection": return .mint
        default: return .gray
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: content.timestamp)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(content.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    BookSessionHistoryCard(book: Book(
        id: "test",
        title: "Test Book",
        author: "Test Author",
        coverImageURL: nil,
        localId: UUID()
    ))
}
// MARK: - Ambient Session Row
struct AmbientSessionRow: View {
    let session: AmbientSession
    let onTap: () -> Void
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.startTime, relativeTo: Date())
    }
    
    private var durationText: String {
        let minutes = Int(session.duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
    }
    
    private var sessionSummary: String {
        // Generate a smart summary based on content
        if !session.capturedQuestions.isEmpty {
            return session.capturedQuestions.first?.content ?? "Discussion session"
        } else if !session.capturedQuotes.isEmpty {
            return "Captured \(session.capturedQuotes.count) quotes"
        } else if !session.capturedNotes.isEmpty {
            return session.capturedNotes.first?.content ?? "Reading session"
        } else {
            return "Reading session"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Time and duration header
                HStack {
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 3, height: 3)
                    
                    Text(durationText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                
                // Summary text
                Text(sessionSummary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Content indicators
                HStack(spacing: 16) {
                    if session.capturedQuestions.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                            Text("\(session.capturedQuestions.count)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.blue.opacity(0.8))
                    }
                    
                    if session.capturedQuotes.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 11))
                            Text("\(session.capturedQuotes.count)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.purple.opacity(0.8))
                    }
                    
                    if session.capturedNotes.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                            Text("\(session.capturedNotes.count)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.green.opacity(0.8))
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
