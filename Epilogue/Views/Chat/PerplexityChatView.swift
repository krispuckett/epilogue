import SwiftUI
import Combine

struct PerplexityChatView: View {
    @StateObject private var viewModel: PerplexityChatViewModel
    @State private var messageText = ""
    @State private var isShowingCitations = false
    @State private var selectedCitation: Citation?
    @FocusState private var isInputFocused: Bool
    
    let book: BookModel?
    
    init(book: BookModel? = nil) {
        self.book = book
        self._viewModel = StateObject(wrappedValue: PerplexityChatViewModel(book: book))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with quota display
            ChatHeaderView(viewModel: viewModel)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                onCitationTap: { citation in
                                    selectedCitation = citation
                                    isShowingCitations = true
                                }
                            )
                            .id(message.id)
                        }
                        
                        if viewModel.isTyping {
                            TypingIndicatorView()
                                .id("typing")
                        }
                        
                        if viewModel.isStreaming {
                            StreamingBubbleView(
                                content: viewModel.streamingContent,
                                citations: viewModel.streamingCitations
                            )
                            .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isStreaming) { _, isStreaming in
                    if isStreaming {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input bar
            ChatInputBarView(
                text: $messageText,
                isLoading: viewModel.isProcessing,
                canSend: viewModel.canSendMessage,
                onSend: sendMessage,
                onModelToggle: viewModel.toggleModel
            )
            .focused($isInputFocused)
        }
        .navigationTitle(book?.title ?? "AI Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: viewModel.clearChat) {
                        Label("Clear Chat", systemImage: "trash")
                    }
                    
                    Button(action: viewModel.exportChat) {
                        Label("Export Chat", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Label("Model: \(viewModel.currentModel.rawValue)", systemImage: "cpu")
                    
                    Text("Tokens: \(viewModel.totalTokensUsed)")
                        .font(.caption)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingCitations) {
            CitationDetailView(citation: selectedCitation)
        }
        .alert("Quota Exceeded", isPresented: $viewModel.showQuotaAlert) {
            Button("OK") { }
            Button("Upgrade") {
                // Navigate to upgrade
            }
        } message: {
            Text("You've reached your daily limit of \(viewModel.dailyQuota) queries. Upgrade to Pro for unlimited access.")
        }
        .onAppear {
            viewModel.loadInitialContext()
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let text = messageText
        messageText = ""
        
        Task {
            await viewModel.sendMessage(text)
        }
    }
}

// MARK: - Chat Header

struct ChatHeaderView: View {
    @ObservedObject var viewModel: PerplexityChatViewModel
    
    var body: some View {
        HStack {
            if viewModel.isGandalfEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.purple)
                    Text("Gandalf Mode")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            } else if viewModel.isPro {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Pro")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            } else {
                QuotaIndicatorView(remaining: viewModel.queriesRemaining, total: 20)
            }
            
            Spacer()
            
            if !viewModel.isGandalfEnabled && !viewModel.isPro {
                Text("\(viewModel.queriesRemaining) queries left")
                    .font(.caption)
                    .foregroundColor(viewModel.queriesRemaining < 5 ? .orange : .secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }
}

struct QuotaIndicatorView: View {
    let remaining: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < remaining ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: ChatMessage
    let onCitationTap: (Citation) -> Void
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                
                if !message.citations.isEmpty {
                    CitationPillsView(
                        citations: message.citations,
                        onTap: onCitationTap
                    )
                }
                
                HStack(spacing: 4) {
                    if message.cached {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.tokenCount > 0 {
                        Text("• \(message.tokenCount) tokens")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Streaming Message

struct StreamingBubbleView: View {
    let content: String
    let citations: [Citation]
    @State private var showCursor = true
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(content)
                    
                    if showCursor {
                        Text("▊")
                            .foregroundColor(.blue)
                            .opacity(showCursor ? 1 : 0)
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(16)
                
                if !citations.isEmpty {
                    CitationPillsView(citations: citations) { _ in }
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                showCursor.toggle()
            }
        }
    }
}

// MARK: - Citation Pills

struct CitationPillsView: View {
    let citations: [Citation]
    let onTap: (Citation) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(citations) { citation in
                    Button(action: { onTap(citation) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link.circle.fill")
                                .font(.caption)
                            
                            Text(citation.source ?? citation.url)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationOffset == CGFloat(index) ? 1.3 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(16)
            
            Spacer()
        }
        .onAppear {
            animationOffset = 2
        }
    }
}

// MARK: - Input Bar

struct ChatInputBarView: View {
    @Binding var text: String
    let isLoading: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onModelToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onModelToggle) {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
            }
            
            HStack {
                TextField("Ask about this book...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .disabled(!canSend || isLoading)
                    .onSubmit(onSend)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(canSend && !text.isEmpty ? .blue : .gray)
                    }
                    .disabled(!canSend || text.isEmpty)
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .overlay(Divider(), alignment: .top)
    }
}

// MARK: - Citation Detail

struct CitationDetailView: View {
    let citation: Citation?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let citation = citation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(citation.title ?? "Citation")
                            .font(.headline)
                        
                        Text(citation.source ?? citation.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let snippet = citation.snippet {
                        Text(snippet)
                            .font(.body)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Link(destination: URL(string: citation.url)!) {
                        Label("Open in Safari", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Citation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class PerplexityChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var isTyping = false
    @Published var isStreaming = false
    @Published var streamingContent = ""
    @Published var streamingCitations: [Citation] = []
    @Published var queriesRemaining = 20
    @Published var isPro = false
    @Published var isGandalfEnabled = false
    @Published var showQuotaAlert = false
    @Published var currentModel: SonarModel = .small
    @Published var totalTokensUsed = 0
    
    private let book: BookModel?
    private let requestManager = PerplexityRequestManager.shared
    private var streamTask: Task<Void, Error>?
    
    let dailyQuota = 20
    
    var canSendMessage: Bool {
        !isProcessing && (isGandalfEnabled || isPro || queriesRemaining > 0)
    }
    
    init(book: BookModel?) {
        self.book = book
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        // Load API key
        if let apiKey = KeychainManager.shared.getPerplexityAPIKey() {
            Task {
                await requestManager.configure(apiKey: apiKey, isPro: isPro)
            }
        }
        
        // Check Gandalf mode
        isGandalfEnabled = UserDefaults.standard.bool(forKey: "gandalfMode")
        if isGandalfEnabled {
            Task {
                await requestManager.enableGandalf(true)
            }
        }
        
        // Load user tier
        isPro = UserDefaults.standard.bool(forKey: "isProUser")
        currentModel = isPro ? .medium : .small
        
        // Update queries remaining
        Task {
            queriesRemaining = await requestManager.getRemainingQueries()
        }
    }
    
    func loadInitialContext() {
        if let book = book {
            let welcomeMessage = ChatMessage(
                id: UUID(),
                content: "Hello! I'm here to help you explore '\(book.title)'. What would you like to know?",
                isUser: false,
                citations: [],
                timestamp: Date(),
                cached: false,
                tokenCount: 0
            )
            
            messages.append(welcomeMessage)
        }
    }
    
    func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = ChatMessage(
            id: UUID(),
            content: text,
            isUser: true,
            citations: [],
            timestamp: Date(),
            cached: false,
            tokenCount: 0
        )
        messages.append(userMessage)
        
        // Prepare API messages
        var apiMessages: [Epilogue.ChatMessage] = []
        
        if let book = book {
            apiMessages.append(Epilogue.ChatMessage(
                role: .system,
                content: "You are discussing the book '\(book.title)' by \(book.author)"
            ))
        }
        
        for message in messages.suffix(10) {
            apiMessages.append(Epilogue.ChatMessage(
                role: message.isUser ? .user : .assistant,
                content: message.content
            ))
        }
        
        // Stream response
        isStreaming = true
        streamingContent = ""
        streamingCitations = []
        
        streamTask = Task {
            do {
                for try await update in requestManager.streamRequest(
                    messages: apiMessages,
                    model: currentModel,
                    priority: isPro ? .high : .normal
                ) {
                    switch update {
                    case .started(let estimatedTokens):
                        print("Starting stream with ~\(estimatedTokens) tokens")
                        
                    case .content(let text, let total):
                        streamingContent = total
                        
                    case .citations(let citations):
                        streamingCitations = citations
                        
                    case .completed(let totalTokens, let cost):
                        let assistantMessage = ChatMessage(
                            id: UUID(),
                            content: streamingContent,
                            isUser: false,
                            citations: streamingCitations,
                            timestamp: Date(),
                            cached: false,
                            tokenCount: totalTokens
                        )
                        
                        messages.append(assistantMessage)
                        totalTokensUsed += totalTokens
                        
                        isStreaming = false
                        streamingContent = ""
                        streamingCitations = []
                        
                        queriesRemaining = await requestManager.getRemainingQueries()
                        
                        print("Completed: \(totalTokens) tokens, $\(String(format: "%.4f", cost))")
                    }
                }
            } catch {
                print("Stream error: \(error)")
                isStreaming = false
                
                let errorMessage = ChatMessage(
                    id: UUID(),
                    content: "Sorry, an error occurred: \(error.localizedDescription)",
                    isUser: false,
                    citations: [],
                    timestamp: Date(),
                    cached: false,
                    tokenCount: 0
                )
                messages.append(errorMessage)
                
                if error.localizedDescription.contains("quota") {
                    showQuotaAlert = true
                }
            }
        }
    }
    
    func toggleModel() {
        if isPro {
            currentModel = currentModel == .small ? .medium : .small
        }
    }
    
    func clearChat() {
        messages.removeAll()
        loadInitialContext()
    }
    
    func exportChat() {
        // Export implementation
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let citations: [Citation]
    let timestamp: Date
    let cached: Bool
    let tokenCount: Int
}

#Preview {
    NavigationStack {
        PerplexityChatView(book: nil)
    }
}