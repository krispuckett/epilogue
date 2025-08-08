import SwiftUI
import SwiftData

struct AmbientSessionSummaryView: View {
    let session: OptimizedAmbientSession
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var hasSaved = false
    
    private var sessionDuration: String {
        let minutes = Int(session.duration) / 60
        if minutes < 1 {
            return "Less than a minute"
        } else if minutes == 1 {
            return "1 minute"
        } else if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            }
            return "\(hours) hr \(remainingMinutes) min"
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient based on session mood
            LinearGradient(
                colors: [
                    session.metadata.mood.color.opacity(0.3),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Key Metrics
                    metricsSection
                    
                    // Content Clusters
                    if !session.clusters.isEmpty {
                        clustersSection
                    }
                    
                    // Key Insights
                    insightsSection
                    
                    // Auto-save indicator
                    autoSaveIndicator
                    
                    // Continue Reading
                    continueSection
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            autoSaveSession()
            markProgressIfNeeded()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Session complete icon with animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .scaleEffect(hasSaved ? 1.0 : 0.5)
                .opacity(hasSaved ? 1.0 : 0.3)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: hasSaved)
            
            Text("Reading Session Complete")
                .font(.title2)
                .fontWeight(.bold)
            
            if let book = session.bookContext {
                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("by \(book.author)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(sessionDuration)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
        }
        .padding(.top, 40)
    }
    
    private var metricsSection: some View {
        HStack(spacing: 16) {
            MetricCard(
                icon: "questionmark.circle.fill",
                value: "\(session.totalQuestions)",
                label: "Questions",
                color: .blue
            )
            
            MetricCard(
                icon: "quote.bubble.fill",
                value: "\(session.allContent.filter { $0.type == .quote }.count)",
                label: "Quotes",
                color: .green
            )
            
            MetricCard(
                icon: "lightbulb.fill",
                value: "\(session.allContent.filter { $0.type == .insight }.count)",
                label: "Insights",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    private var clustersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discussion Topics")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(session.clusters.prefix(5)), id: \.id) { cluster in
                        ClusterCard(cluster: cluster)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Moments")
                .font(.headline)
            
            // Top questions with AI responses
            let questionsWithResponses = session.allContent
                .filter { $0.type == .question && $0.aiResponse != nil }
                .prefix(3)
            
            if !questionsWithResponses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(questionsWithResponses), id: \.id) { content in
                        KeyMomentCard(content: content)
                    }
                }
            }
            
            // Best quotes
            let quotes = session.allContent
                .filter { $0.type == .quote }
                .sorted { $0.confidence > $1.confidence }
                .prefix(2)
            
            if !quotes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(quotes), id: \.id) { quote in
                        SessionQuoteCard(content: quote)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var autoSaveIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: hasSaved ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                .foregroundColor(hasSaved ? .green : .orange)
                .font(.caption)
            
            Text(hasSaved ? "Session saved to your library" : "Saving session...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var continueSection: some View {
        VStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Label("Continue Reading", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            
            Text("Your session has been automatically saved")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
    // MARK: - Auto-save Logic
    
    private func autoSaveSession() {
        guard !hasSaved else { return }
        
        Task {
            // Simulate processing
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Save to persistent storage
            await saveSessionToHistory()
            
            await MainActor.run {
                withAnimation {
                    hasSaved = true
                }
            }
        }
    }
    
    private func saveSessionToHistory() async {
        // This would save to SwiftData/CoreData
        // For now, we'll save to UserDefaults as a quick implementation
        
        let sessionData = SessionHistoryData(
            id: session.id,
            bookId: session.bookContext?.id,
            bookTitle: session.bookContext?.title ?? "Unknown Book",
            startTime: session.startTime,
            endTime: session.endTime ?? Date(),
            duration: session.duration,
            questionCount: session.totalQuestions,
            quoteCount: session.allContent.filter { $0.type == .quote }.count,
            insightCount: session.allContent.filter { $0.type == .insight }.count,
            mood: session.metadata.mood.rawValue,
            clusters: session.clusters.map { SessionHistoryData.ClusterSummary(topic: $0.topic, itemCount: $0.content.count) },
            allContent: session.allContent.map { SessionHistoryData.ContentSummary(type: $0.type.rawValue, text: $0.text, timestamp: $0.timestamp) }
        )
        
        // Get existing sessions
        var sessions = SessionHistoryData.loadAll()
        sessions.append(sessionData)
        
        // Keep only last 50 sessions
        if sessions.count > 50 {
            sessions = Array(sessions.suffix(50))
        }
        
        SessionHistoryData.saveAll(sessions)
    }
    
    private func markProgressIfNeeded() {
        // Automatically update reading progress if detected
        let progressDetector = IntelligentSessionProcessor.shared
        let transcriptions = session.rawTranscriptions.joined(separator: " ")
        let progressUpdates = progressDetector.detectProgressUpdates(content: transcriptions)
        
        if let lastProgress = progressUpdates.last {
            // Post notification to update book progress
            NotificationCenter.default.post(
                name: Notification.Name("AutoUpdateBookProgress"),
                object: [
                    "book": session.bookContext as Any,
                    "progress": lastProgress
                ]
            )
        }
    }
}

// MARK: - Component Views

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}

struct ClusterCard: View {
    let cluster: SessionCluster
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(cluster.topic, systemImage: cluster.mood.icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(cluster.mood.color)
            
            HStack(spacing: 12) {
                Label("\(cluster.questionCount)", systemImage: "questionmark.circle")
                Label("\(cluster.content.count)", systemImage: "text.bubble")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Text(formatDuration(cluster.duration))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 160)
        .background(cluster.mood.color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes) min"
    }
}

struct KeyMomentCard: View {
    let content: SessionContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(content.text)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            
            if let response = content.aiResponse {
                Text(response.answer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.leading, 20)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SessionQuoteCard: View {
    let content: SessionContent
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "quote.bubble.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(content.text)
                .font(.subheadline)
                .italic()
                .lineLimit(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Session History Data Model

struct SessionHistoryData: Codable {
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
    let clusters: [ClusterSummary]
    let allContent: [ContentSummary]
    
    struct ClusterSummary: Codable {
        let topic: String
        let itemCount: Int
    }
    
    struct ContentSummary: Codable {
        let type: String
        let text: String
        let timestamp: Date
    }
    
    static func loadAll() -> [SessionHistoryData] {
        guard let data = UserDefaults.standard.data(forKey: "AmbientSessionHistory"),
              let sessions = try? JSONDecoder().decode([SessionHistoryData].self, from: data) else {
            return []
        }
        return sessions
    }
    
    static func saveAll(_ sessions: [SessionHistoryData]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "AmbientSessionHistory")
        }
    }
    
    static func loadForBook(_ bookId: String?) -> [SessionHistoryData] {
        guard let bookId = bookId else { return [] }
        return loadAll().filter { $0.bookId == bookId }
    }
}

#Preview {
    AmbientSessionSummaryView(
        session: OptimizedAmbientSession(
            startTime: Date().addingTimeInterval(-1800),
            bookContext: nil,
            metadata: SessionMetadata()
        )
    )
}