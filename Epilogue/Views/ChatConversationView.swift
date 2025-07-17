import SwiftUI
import SwiftData
import Combine

struct ChatConversationView: View {
    let thread: ChatThread
    @Binding var showingThreadList: Bool
    @Environment(\.modelContext) private var modelContext
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isLoadingResponse = false
    @Namespace private var animation
    
    // Ambient animation states
    @State private var animationPhase: Double = 0
    @State private var orbPositions: [CGPoint] = [
        CGPoint(x: 0.2, y: 0.3),
        CGPoint(x: 0.7, y: 0.5),
        CGPoint(x: 0.4, y: 0.8)
    ]
    
    @State private var showingClearConfirmation = false
    
    var body: some View {
        ZStack {
            // Ambient background
            AmbientBackground(animationPhase: $animationPhase, orbPositions: $orbPositions)
            
            // Messages ScrollView
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Thread start indicator - minimal
                        Text("Conversation started \(thread.createdDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity) // Ensure full width for proper centering
                        
                        // Messages
                        ForEach(thread.messages) { message in
                            ThreadMessageCard(
                                message: message,
                                namespace: animation
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95, anchor: message.isUser ? .bottomTrailing : .bottomLeading)
                                    .combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                            .id(message.id)
                        }
                    
                        // Spacer for input field
                        Color.clear
                            .frame(height: 100)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: thread.messages.count) { _, _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ThreadInputField(
                text: $messageText,
                thread: thread,
                isInputFocused: $isInputFocused,
                onSend: sendMessage
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .navigationTitle(thread.bookTitle ?? "General Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Chats") {
                    showingThreadList = true
                }
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .alert("Clear all messages?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Chat", role: .destructive) {
                clearChat()
            }
        } message: {
            Text("This will remove all messages from this conversation.")
        }
        .onAppear {
            startAmbientAnimation()
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let userMessage = ThreadedChatMessage(
            content: messageText,
            isUser: true,
            timestamp: Date(),
            bookTitle: thread.bookTitle,
            bookAuthor: thread.bookAuthor
        )
        
        HapticManager.shared.lightTap()
        
        // Add message to thread
        thread.messages.append(userMessage)
        thread.lastMessageDate = Date()
        
        messageText = ""
        isLoadingResponse = true
        
        // Show loading message immediately
        let loadingMessage = ThreadedChatMessage(
            content: "",
            isUser: false,
            timestamp: Date(),
            bookTitle: thread.bookTitle,
            bookAuthor: thread.bookAuthor
        )
        thread.messages.append(loadingMessage)
        
        // Save context
        try? modelContext.save()
        
        // Get AI response
        Task {
            do {
                // Create a Book object for context if needed
                var bookContext: Book? = nil
                if let bookId = thread.bookId,
                   let bookTitle = thread.bookTitle,
                   let bookAuthor = thread.bookAuthor {
                    bookContext = Book(
                        id: bookId.uuidString,
                        title: bookTitle,
                        author: bookAuthor,
                        localId: bookId
                    )
                }
                
                // Get response from Perplexity
                let response = try await PerplexityService.staticChat(
                    message: userMessage.content,
                    bookContext: bookContext
                )
                
                // Update the loading message with actual content
                if let lastMessage = thread.messages.last {
                    lastMessage.content = response
                    thread.lastMessageDate = Date()
                    try? modelContext.save()
                }
                
                isLoadingResponse = false
                
            } catch {
                print("❌ API Error: \(error.localizedDescription)")
                isLoadingResponse = false
                
                // Use fallback response
                if let lastMessage = thread.messages.last {
                    lastMessage.content = generateLiteraryResponse(to: userMessage.content)
                    thread.lastMessageDate = Date()
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func clearChat() {
        thread.messages.removeAll()
        thread.lastMessageDate = Date()
        try? modelContext.save()
    }
    
    private func startAmbientAnimation() {
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
            animationPhase = 2 * .pi
        }
    }
    
    private func generateLiteraryResponse(to message: String) -> String {
        if thread.bookId == nil {
            // General chat responses
            let responses = [
                "I'd be happy to recommend some books based on your interests. What genres or themes do you enjoy?",
                "Have you considered exploring contemporary literary fiction? Authors like Kazuo Ishiguro and Zadie Smith offer compelling narratives.",
                "Classic literature often provides timeless insights. Perhaps start with something accessible like 'To Kill a Mockingbird' or '1984'.",
                "If you're looking for something thought-provoking, I'd suggest exploring philosophical fiction like Sartre or Camus.",
                "Modern book clubs are gravitating toward diverse voices. Have you read anything by Chimamanda Ngozi Adichie or Haruki Murakami?"
            ]
            return responses.randomElement() ?? "I'd love to help you discover your next great read."
        } else {
            // Book-specific responses
            let responses = [
                "That's a fascinating observation about \(thread.bookTitle ?? "this book"). The narrative structure really does enhance the themes.",
                "I find the character development in \(thread.bookTitle ?? "this work") particularly compelling. Each character serves a distinct purpose.",
                "The author's use of symbolism throughout \(thread.bookTitle ?? "the text") adds layers of meaning worth exploring.",
                "Your interpretation adds depth to my understanding of \(thread.bookTitle ?? "this book"). Have you noticed similar patterns in other works?",
                "The themes in \(thread.bookTitle ?? "this narrative") resonate with contemporary issues in interesting ways."
            ]
            return responses.randomElement() ?? "That's an intriguing perspective on the text."
        }
    }
}

// MARK: - Thread Message Card
struct ThreadMessageCard: View {
    let message: ThreadedChatMessage
    let namespace: Namespace.ID
    @State private var isRevealed = false
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            
            ZStack {
                // Shadow layer
                if !message.isUser {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.2))
                        .offset(y: 4)
                        .blur(radius: 8)
                }
                
                // Content card
                VStack(alignment: .leading, spacing: 8) {
                    // Message content or loading indicator
                    if message.content.isEmpty && !message.isUser {
                        // Loading indicator for AI responses
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
                                    .frame(width: 6, height: 6)
                                    .opacity(isRevealed ? 1.0 : 0.3)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: isRevealed
                                    )
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        MarkdownText(text: message.content, isUserMessage: message.isUser)
                            .opacity(isRevealed ? 1 : 0)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .black, location: isRevealed ? 0 : 0),
                                        .init(color: .black, location: isRevealed ? 1 : 0),
                                        .init(color: .clear, location: isRevealed ? 1 : 0.1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    // Timestamp
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 4)
                }
                .padding(message.isUser ? 16 : 20)
                .frame(maxWidth: message.isUser ? 280 : .infinity, alignment: .leading)
                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
                .overlay {
                    // New message glow
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(glowOpacity), lineWidth: 2)
                        .blur(radius: 4)
                }
            }
            
            if !message.isUser { Spacer(minLength: 60) }
        }
        .onAppear {
            // Reveal animation
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                isRevealed = true
            }
        }
    }
}

// MARK: - Thread Input Field
struct ThreadInputField: View {
    @Binding var text: String
    let thread: ChatThread
    @FocusState.Binding var isInputFocused: Bool
    let onSend: () -> Void
    
    @State private var showSuggestions = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Suggestions (appear above input when focused)
            if showSuggestions && isInputFocused {
                ThreadSmartSuggestions(thread: thread)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Input field
            HStack(spacing: 12) {
                // Question icon (similar to command palette)
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                
                // Text editor
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(thread.bookId == nil ? "Ask about books..." : "Discuss \(thread.bookTitle ?? "this book")...")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 4)
                    }
                    
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .focused($isInputFocused)
                        .frame(height: 32) // Fixed initial height
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                
                // Send button
                if !text.isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56) // Consistent height with ChatInputBar
            .padding(.vertical, 12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSuggestions)
        .onChange(of: isInputFocused) { _, newValue in
            withAnimation {
                showSuggestions = newValue && text.isEmpty
            }
        }
        .onChange(of: text) { _, _ in
            withAnimation {
                showSuggestions = isInputFocused && text.isEmpty
            }
        }
    }
}

// MARK: - Thread Smart Suggestions
struct ThreadSmartSuggestions: View {
    let thread: ChatThread
    
    var suggestions: [String] {
        if thread.bookId == nil {
            return [
                "What should I read next?",
                "Recommend books like Harry Potter",
                "Tell me about classic literature",
                "What are the best sci-fi novels?"
            ]
        } else {
            return [
                "What are the main themes?",
                "Analyze the protagonist",
                "Discuss the ending",
                "Compare to similar books"
            ]
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        // Handle suggestion tap
                    }) {
                        Text(suggestion)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}