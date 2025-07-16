import SwiftUI
import Combine

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let timestamp: Date
    let bookContext: Book?
    var isNew: Bool = true
}

// MARK: - Chat View
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var currentBook: Book? = nil
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
    
    var body: some View {
        ZStack {
            // Ambient background
            AmbientBackground(animationPhase: $animationPhase, orbPositions: $orbPositions)
            
            // Messages ScrollView
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Welcome message
                        if viewModel.messages.isEmpty {
                            WelcomeCard()
                                .padding(.top, 100)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                        
                        // Messages
                        ForEach(viewModel.messages) { message in
                            MessageCard(
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
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            LiteraryInputField(
                text: $messageText,
                currentBook: currentBook,
                isInputFocused: $isInputFocused,
                onSend: sendMessage
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .navigationTitle("Literary Companion")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startAmbientAnimation()
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            return 
        }
        
        let userMessage = ChatMessage(
            content: messageText,
            isUser: true,
            timestamp: Date(),
            bookContext: currentBook
        )
        
        HapticManager.shared.lightTap()
        viewModel.sendMessage(userMessage)
        messageText = ""
        isLoadingResponse = true
        
        // Get AI response from Perplexity
        Task {
            do {
                // Get response from Perplexity
                let response = try await PerplexityService.staticChat(
                    message: userMessage.content,
                    bookContext: currentBook
                )
                
                // Create AI message
                let aiMessage = ChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBook
                )
                
                viewModel.receiveMessage(aiMessage)
                isLoadingResponse = false
                
            } catch {
                print("❌ API Error: \(error.localizedDescription)")
                isLoadingResponse = false
                
                // Use fallback response
                let fallbackResponse = ChatMessage(
                    content: generateLiteraryResponse(to: userMessage.content),
                    isUser: false,
                    timestamp: Date(),
                    bookContext: currentBook
                )
                
                viewModel.receiveMessage(fallbackResponse)
            }
        }
    }
    
    private func startAmbientAnimation() {
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
            animationPhase = 2 * .pi
        }
    }
    
    // Temporary response generator
    private func generateLiteraryResponse(to message: String) -> String {
        let responses = [
            "That's a fascinating observation about the narrative structure. The way the author weaves themes throughout reminds me of Virginia Woolf's stream of consciousness technique.",
            "I find that passage particularly moving. The metaphor of light and shadow seems to represent the duality of human nature - a common thread in modernist literature.",
            "Your interpretation adds a new dimension to my understanding. Have you noticed how the author uses repetition to emphasize this theme?",
            "The character development here is remarkable. It echoes the psychological realism found in the works of Henry James.",
            "This reminds me of a similar theme in Borges' labyrinths - the idea that reality itself might be a construction of language and perception."
        ]
        return responses.randomElement() ?? "That's an intriguing perspective on the text."
    }
}

// MARK: - Ambient Background
struct AmbientBackground: View {
    @Binding var animationPhase: Double
    @Binding var orbPositions: [CGPoint]
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.031, green: 0.027, blue: 0.027), // #080707
                    Color(red: 0.11, green: 0.105, blue: 0.102)   // #1C1B1A
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating orbs
            ForEach(0..<3) { index in
                Circle()
                    .fill(orbGradient(for: index))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .opacity(0.4)
                    .position(orbPosition(for: index))
                    .animation(.easeInOut(duration: 20).repeatForever(autoreverses: true), value: animationPhase)
            }
        }
    }
    
    private func orbGradient(for index: Int) -> LinearGradient {
        let gradients = [
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.8, green: 0.4, blue: 0.2).opacity(0.6),
                Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3)
            ]), startPoint: .topLeading, endPoint: .bottomTrailing),
            
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.4, green: 0.3, blue: 0.6).opacity(0.5),
                Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.3)
            ]), startPoint: .topLeading, endPoint: .bottomTrailing),
            
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.2, green: 0.4, blue: 0.5).opacity(0.5),
                Color(red: 0.3, green: 0.5, blue: 0.6).opacity(0.3)
            ]), startPoint: .topLeading, endPoint: .bottomTrailing)
        ]
        
        return gradients[index % gradients.count]
    }
    
    private func orbPosition(for index: Int) -> CGPoint {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Figure-8 pattern with different phases
        let phase = animationPhase + (Double(index) * 2 * .pi / 3)
        let x = screenWidth * (0.5 + 0.3 * sin(phase))
        let y = screenHeight * (0.5 + 0.3 * sin(2 * phase))
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Welcome Card
struct WelcomeCard: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
            
            VStack(spacing: 12) {
                Text("Your Literary Companion")
                    .font(.custom("Georgia", size: 24))
                    .foregroundStyle(.white)
                
                Text("Discuss books, explore themes, and deepen your understanding")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

// MARK: - Message Card
struct MessageCard: View {
    let message: ChatMessage
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
                    // Book context pill if available
                    if let book = message.bookContext, !message.isUser {
                        HStack(spacing: 6) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 11))
                            Text(book.title)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.15))
                        )
                    }
                    
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
                        Text(message.content)
                            .font(message.isUser ? 
                                  .system(size: 16, weight: .regular, design: .default) :
                                  .custom("Georgia", size: 17))
                            .foregroundStyle(message.isUser ? .white : Color(red: 0.98, green: 0.97, blue: 0.96))
                            .lineSpacing(message.isUser ? 2 : 4)
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
            
            // Glow animation for new messages
            if message.isNew {
                withAnimation(.easeInOut(duration: 0.6)) {
                    glowOpacity = 0.6
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                    glowOpacity = 0
                }
            }
        }
    }
}

// MARK: - Literary Input Field
struct LiteraryInputField: View {
    @Binding var text: String
    let currentBook: Book?
    @FocusState.Binding var isInputFocused: Bool
    let onSend: () -> Void
    
    @State private var showSuggestions = false
    @State private var textEditorHeight: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 8) {
            // Suggestions (appear above input when focused)
            if showSuggestions && isInputFocused {
                SmartSuggestions(currentBook: currentBook)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Input field
            HStack(spacing: 12) {
                // Book context indicator
                if let book = currentBook {
                    Image(systemName: "book.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Text editor
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Share your thoughts...")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 4)
                    }
                    
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .focused($isInputFocused)
                        .frame(minHeight: 40, maxHeight: 120)
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
            .padding(.vertical, 12)
            .glassEffect(in: Capsule())
            .overlay {
                Capsule()
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

// MARK: - Smart Suggestions
struct SmartSuggestions: View {
    let currentBook: Book?
    
    var suggestions: [String] {
        if let book = currentBook {
            return [
                "What themes stand out in \(book.title)?",
                "Analyze the character development",
                "Discuss the writing style"
            ]
        } else {
            return [
                "Recommend a book based on my interests",
                "What should I read next?",
                "Tell me about a classic novel"
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
                            .glassEffect(in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Chat View Model
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    
    func sendMessage(_ message: ChatMessage) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            messages.append(message)
        }
    }
    
    func receiveMessage(_ message: ChatMessage) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            messages.append(message)
        }
    }
    
    func updateLastMessage(content: String) {
        guard !messages.isEmpty else { return }
        
        withAnimation(.easeOut(duration: 0.1)) {
            messages[messages.count - 1].content = content
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ChatView()
    }
    .preferredColorScheme(.dark)
}