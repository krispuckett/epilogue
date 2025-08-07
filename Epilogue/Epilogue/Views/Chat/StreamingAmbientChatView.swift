import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "StreamingAmbientChat")

// MARK: - Streaming Chat Message
struct StreamingChatMessage: Identifiable {
    let id = UUID()
    let type: MessageType
    var content: String
    let timestamp: Date
    var isComplete: Bool
    let bookContext: String?
    var metadata: MessageMetadata?
    
    enum MessageType {
        case userQuestion
        case aiResponse
        case systemNotification
        case sessionSummary
        case contentCluster
    }
    
    struct MessageMetadata {
        let model: String?
        let responseTime: TimeInterval?
        let confidence: Float?
        let wasFromCache: Bool
        let streamId: UUID?
    }
}

// MARK: - Streaming Ambient Chat View
struct StreamingAmbientChatView: View {
    @StateObject private var aiService = OptimizedAIResponseService.shared
    @StateObject private var sessionManager = AmbientSessionManager()
    @State private var messages: [StreamingChatMessage] = []
    @State private var activeStreamingMessages: [UUID: StreamingChatMessage] = [:]
    
    let bookContext: Book?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with session info
            sessionHeaderView
            
            Divider()
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        // Show active streaming messages
                        ForEach(Array(activeStreamingMessages.values), id: \.id) { message in
                            StreamingMessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    // Auto-scroll to latest message
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: activeStreamingMessages.count) { _ in
                    // Auto-scroll when streaming starts
                    if let streamingMessage = activeStreamingMessages.values.first {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(streamingMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Session controls
            sessionControlsView
        }
        .background(Color.black.opacity(0.001))
        .onAppear {
            setupNotificationObservers()
            loadRecentSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AIStreamingUpdate"))) { notification in
            handleStreamingUpdate(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AIResponseComplete"))) { notification in
            handleResponseComplete(notification)
        }
    }
    
    // MARK: - Header View
    
    private var sessionHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(bookContext?.title ?? "Ambient Reading")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let author = bookContext?.author {
                    Text("by \(author)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Session stats
            sessionStatsView
        }
        .padding()
    }
    
    private var sessionStatsView: some View {
        HStack(spacing: 12) {
            // Questions count
            Label("\(sessionManager.currentSession?.totalQuestions ?? 0)", systemImage: "questionmark.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
            
            // AI responses count
            Label("\(sessionManager.currentSession?.totalAIResponses ?? 0)", systemImage: "brain.head.profile")
                .font(.caption)
                .foregroundColor(.green)
            
            // Session duration
            if let session = sessionManager.currentSession {
                Label(formatDuration(session.duration), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Session Controls
    
    private var sessionControlsView: some View {
        HStack(spacing: 16) {
            // Cache performance indicator
            cachePerformanceView
            
            Spacer()
            
            // Export session button
            Button(action: exportSession) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .disabled(messages.isEmpty)
            
            // Clear session button
            Button(action: clearSession) {
                Label("Clear", systemImage: "trash")
                    .font(.caption)
            }
            .disabled(messages.isEmpty)
        }
        .padding()
    }
    
    private var cachePerformanceView: some View {
        HStack(spacing: 8) {
            // Cache hit rate indicator
            let hitRate = sessionManager.currentSession?.cacheHitRate ?? 0
            Circle()
                .fill(hitRate > 0.7 ? Color.green : hitRate > 0.4 ? Color.orange : Color.red)
                .frame(width: 8, height: 8)
            
            Text("\(Int(hitRate * 100))% cache")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Average response time
            if let avgTime = sessionManager.currentSession?.averageResponseTime {
                Text("~\(String(format: "%.1f", avgTime))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Message Views
    
    struct MessageBubbleView: View {
        let message: StreamingChatMessage
        
        var body: some View {
            HStack {
                if message.type == .userQuestion {
                    Spacer()
                    userMessageBubble
                } else {
                    aiMessageBubble
                    Spacer()
                }
            }
        }
        
        private var userMessageBubble: some View {
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .foregroundColor(.white)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .cornerRadius(16)
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
        }
        
        private var aiMessageBubble: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.content)
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                        
                        // Metadata
                        if let metadata = message.metadata {
                            metadataView(metadata)
                        }
                    }
                }
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity * 0.85, alignment: .leading)
        }
        
        private func formatTimestamp(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        private func metadataView(_ metadata: StreamingChatMessage.MessageMetadata) -> some View {
            HStack(spacing: 8) {
                if metadata.wasFromCache {
                    Label("Cache", systemImage: "memorychip")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                if let model = metadata.model {
                    Text(model.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if let time = metadata.responseTime {
                    Text("\(String(format: "%.1f", time))s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let confidence = metadata.confidence {
                    ConfidenceIndicator(confidence: confidence)
                }
            }
        }
    }
    
    struct StreamingMessageView: View {
        let message: StreamingChatMessage
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.content)
                                .padding(12)
                                .background(Color.secondary.opacity(0.1))
                                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    // Streaming indicator
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                        .scaleEffect(1.02)
                                        .opacity(message.isComplete ? 0 : 1)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: message.isComplete)
                                )
                        }
                    }
                    
                    // Streaming indicator
                    if !message.isComplete {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(1.0)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: message.isComplete
                                    )
                            }
                            Text("Thinking...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 24)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity * 0.85, alignment: .leading)
        }
    }
    
    struct ConfidenceIndicator: View {
        let confidence: Float
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(confidence > Float(index) * 0.33 ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }
    
    // MARK: - Notification Handling
    
    private func setupNotificationObservers() {
        // Listen for immediate questions
        NotificationCenter.default.publisher(for: Notification.Name("ImmediateQuestionDetected"))
            .compactMap { $0.object as? [String: Any] }
            .sink { data in
                if let question = data["question"] as? String {
                    addUserMessage(question)
                }
            }
            .store(in: &sessionManager.cancellables)
    }
    
    private func handleStreamingUpdate(_ notification: Notification) {
        guard let data = notification.object as? [String: Any],
              let streamId = data["streamId"] as? UUID,
              let text = data["text"] as? String else { return }
        
        if var message = activeStreamingMessages[streamId] {
            message.content = text
            activeStreamingMessages[streamId] = message
        } else {
            // Create new streaming message
            let message = StreamingChatMessage(
                type: .aiResponse,
                content: text,
                timestamp: Date(),
                isComplete: false,
                bookContext: bookContext?.title,
                metadata: nil
            )
            activeStreamingMessages[streamId] = message
        }
    }
    
    private func handleResponseComplete(_ notification: Notification) {
        guard let aiResponse = notification.object as? AIResponse else { return }
        
        // Find and complete streaming message
        for (streamId, var streamingMessage) in activeStreamingMessages {
            if streamingMessage.content.contains(aiResponse.answer.prefix(20)) {
                streamingMessage.isComplete = true
                streamingMessage.content = aiResponse.answer
                streamingMessage.metadata = StreamingChatMessage.MessageMetadata(
                    model: aiResponse.model.displayName,
                    responseTime: aiResponse.responseTime,
                    confidence: aiResponse.confidence,
                    wasFromCache: !aiResponse.isStreaming,
                    streamId: streamId
                )
                
                // Move to permanent messages
                messages.append(streamingMessage)
                activeStreamingMessages.removeValue(forKey: streamId)
                break
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addUserMessage(_ content: String) {
        let message = StreamingChatMessage(
            type: .userQuestion,
            content: content,
            timestamp: Date(),
            isComplete: true,
            bookContext: bookContext?.title
        )
        messages.append(message)
    }
    
    private func loadRecentSession() {
        // Load recent session data if available
        if let session = sessionManager.currentSession {
            // Convert session content to chat messages
            for content in session.allContent {
                let messageType: StreamingChatMessage.MessageType = switch content.type {
                case .question: .userQuestion
                default: .aiResponse
                }
                
                let message = StreamingChatMessage(
                    type: messageType,
                    content: content.text,
                    timestamp: content.timestamp,
                    isComplete: true,
                    bookContext: content.bookContext,
                    metadata: content.aiResponse.map { response in
                        StreamingChatMessage.MessageMetadata(
                            model: response.model,
                            responseTime: response.responseTime,
                            confidence: response.confidence,
                            wasFromCache: response.wasFromCache,
                            streamId: nil
                        )
                    }
                )
                messages.append(message)
            }
        }
    }
    
    private func exportSession() {
        // Export session to Notes app or share sheet
        guard !messages.isEmpty else { return }
        
        let sessionText = generateSessionExport()
        
        let activityVC = UIActivityViewController(
            activityItems: [sessionText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func generateSessionExport() -> String {
        var export = ""
        
        // Session header
        export += "# Ambient Reading Session\n"
        if let book = bookContext {
            export += "**Book:** \(book.title)\n"
            export += "**Author:** \(book.author)\n"
        }
        export += "**Date:** \(formatTimestamp(Date()))\n"
        export += "**Duration:** \(formatDuration(sessionManager.currentSession?.duration ?? 0))\n\n"
        
        // Messages
        export += "## Conversation\n\n"
        for message in messages {
            let prefix = message.type == .userQuestion ? "**Q:**" : "**A:**"
            export += "\(prefix) \(message.content)\n\n"
        }
        
        // Session stats
        if let session = sessionManager.currentSession {
            export += "## Session Statistics\n"
            export += "- Questions Asked: \(session.totalQuestions)\n"
            export += "- AI Responses: \(session.totalAIResponses)\n"
            export += "- Average Response Time: \(String(format: "%.1f", session.averageResponseTime))s\n"
            export += "- Cache Hit Rate: \(Int(session.cacheHitRate * 100))%\n"
        }
        
        return export
    }
    
    private func clearSession() {
        messages.removeAll()
        activeStreamingMessages.removeAll()
        sessionManager.clearCurrentSession()
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Ambient Session Manager

@MainActor
class AmbientSessionManager: ObservableObject {
    @Published var currentSession: OptimizedAmbientSession?
    var cancellables = Set<AnyCancellable>()
    
    func startNewSession(bookContext: Book?) {
        currentSession = OptimizedAmbientSession(
            startTime: Date(),
            bookContext: bookContext,
            metadata: SessionMetadata()
        )
    }
    
    func endCurrentSession() {
        currentSession?.endTime = Date()
        saveSession()
    }
    
    func clearCurrentSession() {
        currentSession = nil
    }
    
    private func saveSession() {
        // Save session to persistent storage
        // Implementation would depend on your data persistence strategy
    }
}

// MARK: - Preview

#Preview {
    StreamingAmbientChatView(bookContext: nil)
}