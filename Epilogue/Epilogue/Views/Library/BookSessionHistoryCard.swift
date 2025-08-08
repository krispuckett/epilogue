import SwiftUI

struct BookSessionHistoryCard: View {
    let book: Book
    @State private var sessions: [SessionHistoryData] = []
    @State private var isExpanded = false
    @State private var selectedSession: SessionHistoryData?
    @State private var showingFullSession = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Reading Sessions", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !sessions.isEmpty {
                    Text("\(sessions.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded && !sessions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sessions.prefix(5), id: \.id) { session in
                        SessionRowView(session: session) {
                            selectedSession = session
                            showingFullSession = true
                        }
                    }
                    
                    if sessions.count > 5 {
                        Text("+ \(sessions.count - 5) more sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            } else if isExpanded && sessions.isEmpty {
                Text("No reading sessions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            loadSessions()
        }
        .sheet(isPresented: $showingFullSession) {
            if let session = selectedSession {
                FullSessionView(session: session, book: book)
            }
        }
    }
    
    private func loadSessions() {
        sessions = SessionHistoryData.loadForBook(book.id)
            .sorted { $0.startTime > $1.startTime } // Most recent first
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
        NavigationView {
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
                        
                        ForEach(session.allContent, id: \.timestamp) { content in
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
                            
                            ForEach(session.clusters, id: \.topic) { cluster in
                                HStack {
                                    Text(cluster.topic)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(cluster.itemCount) items")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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