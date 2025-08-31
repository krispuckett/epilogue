import SwiftUI
import SwiftData

struct AISessionView: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentSession: AISession?
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var sessionType: AISession.SessionType = .discussion
    
    var body: some View {
        NavigationStack {
            VStack {
                if let session = currentSession {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(session.messages ?? []) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                }
                                
                                if isLoading {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("AI is thinking...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                }
                            }
                            .padding()
                        }
                        .onChange(of: currentSession?.messages?.count) { _, _ in
                            withAnimation {
                                if let lastMessage = currentSession?.messages?.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Text("Start a new AI conversation about")
                            .font(.headline)
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Picker("Conversation Type", selection: $sessionType) {
                            ForEach(AISession.SessionType.allCases, id: \.self) { type in
                                Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        
                        Button("Start Conversation") {
                            createNewSession()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                if currentSession != nil {
                    HStack {
                        TextField("Type your message...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isLoading)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                        .disabled(messageText.isEmpty || isLoading)
                    }
                    .padding()
                }
            }
            .navigationTitle("AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if currentSession != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: createNewSession) {
                                Label("New Session", systemImage: "plus.message")
                            }
                            
                            Button(action: clearSession) {
                                Label("Clear Chat", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadOrCreateSession()
        }
    }
    
    private func loadOrCreateSession() {
        if let latestSession = book.aiSessions?.sorted(by: { $0.lastAccessed > $1.lastAccessed }).first {
            currentSession = latestSession
        }
    }
    
    private func createNewSession() {
        let session = AISession(
            title: "Chat about \(book.title)",
            book: book,
            sessionType: sessionType
        )
        
        modelContext.insert(session)
        currentSession = session
        
        // Add initial system message based on session type
        let systemPrompt = getSystemPrompt(for: sessionType)
        session.addMessage(role: .system, content: systemPrompt)
    }
    
    private func sendMessage() {
        guard let session = currentSession, !messageText.isEmpty else { return }
        
        session.addMessage(role: .user, content: messageText)
        let userMessage = messageText
        messageText = ""
        isLoading = true
        
        // Simulate AI response (replace with actual API call)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            session.addMessage(
                role: .assistant,
                content: "This is a simulated response about '\(userMessage)' related to \(book.title). In a real implementation, this would connect to an AI API."
            )
            isLoading = false
        }
    }
    
    private func clearSession() {
        if let session = currentSession {
            session.messages?.removeAll()
        }
    }
    
    private func getSystemPrompt(for type: AISession.SessionType) -> String {
        switch type {
        case .discussion:
            return "You are a helpful assistant discussing the book '\(book.title)' by \(book.author)."
        case .summary:
            return "You are helping to summarize key points from '\(book.title)'."
        case .analysis:
            return "You are providing literary analysis of '\(book.title)'."
        case .questions:
            return "You are answering questions about '\(book.title)'."
        case .characterAnalysis:
            return "You are analyzing characters from '\(book.title)'."
        case .themeExploration:
            return "You are exploring themes in '\(book.title)'."
        }
    }
}

struct MessageBubbleView: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(10)
                    .background(
                        message.isFromUser ? Color.blue : Color.gray.opacity(0.2)
                    )
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(12)
                
                if message.hasError, let error = message.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 300, alignment: message.isFromUser ? .trailing : .leading)
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
}

struct AISessionRowView: View {
    let session: AISession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.headline)
            
            HStack {
                Label(session.sessionType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(session.messageCount) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(session.lastAccessed, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AISessionView(book: Book(title: "Sample Book", author: "Sample Author"))
        .modelContainer(ModelContainer.previewContainer)
}