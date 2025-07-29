import SwiftUI
import SwiftData
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

// DEPRECATED: This view is replaced by UnifiedChatView
// Keeping temporarily for reference during migration
struct ChatConversationView: View {
    let thread: ChatThread
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    
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
    @State private var scrollOffset: CGFloat = 0
    @State private var isVoiceModeActive = false
    @State private var voiceTranscript = ""
    
    // Computed property for the accent color to use
    private var accentColor: Color {
        // Use warm amber as the default accent color
        return Color(red: 1.0, green: 0.55, blue: 0.26)
    }
    
    // Try to get cover URL from thread or find matching book in library
    private var effectiveCoverURL: String? {
        if let url = thread.bookCoverURL {
            return url
        }
        
        // Fallback: try to find book in library by ID or title
        if let bookId = thread.bookId,
           let book = libraryViewModel.books.first(where: { $0.localId == bookId }) {
            return book.coverImageURL
        } else if let title = thread.bookTitle,
                  let book = libraryViewModel.books.first(where: { $0.title == title }) {
            return book.coverImageURL
        }
        
        return nil
    }
    
    var body: some View {
        ZStack {
            // Background based on chat type
            if thread.bookId != nil {
                // Book chat - book-specific gradient background
                BookCentricBackground(
                    bookCoverURL: effectiveCoverURL,
                    bookTitle: thread.bookTitle,
                    bookAuthor: thread.bookAuthor,
                    showBookCover: thread.messages.isEmpty,
                    animationPhase: $animationPhase
                )
                .ignoresSafeArea()
            } else {
                // General discussion background
                AmbientBackground(animationPhase: $animationPhase, orbPositions: $orbPositions)
            }
            
            // Messages ScrollView with padding for header
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Spacer for collapsed header
                        Color.clear
                            .frame(height: scrollOffset < 50 ? 350 : 110)
                            .modifier(ScrollOffsetModifier(offset: $scrollOffset))
                        
                        
                        // Thread start indicator - with clear chat on long press
                        VStack(spacing: 4) {
                            Text("Conversation started \(thread.createdDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            
                            if thread.messages.count > 2 {
                                Text("Hold to clear")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1.5, maximumDistance: .infinity) {
                            HapticManager.shared.mediumTap()
                            showingClearConfirmation = true
                        } onPressingChanged: { _ in
                            // Empty to prevent visual feedback
                        }
                        
                        // Messages
                        ForEach(thread.messages) { message in
                            ThreadMessageCard(
                                message: message,
                                namespace: animation,
                                accentColor: thread.bookId != nil ? accentColor : Color(red: 1.0, green: 0.55, blue: 0.26)
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
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: thread.messages.count) { _, _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .coordinateSpace(name: "scroll")
            }
            
            // Collapsed navigation header overlay
            VStack {
                CollapsedNavigationHeader(
                    title: thread.bookTitle ?? "General Discussion",
                    subtitle: thread.bookAuthor,
                    coverURL: effectiveCoverURL,
                    scrollOffset: $scrollOffset
                )
                
                Spacer()
            }
            
        }
        .safeAreaInset(edge: .bottom) {
            ThreadInputField(
                text: $messageText,
                thread: thread,
                isInputFocused: $isInputFocused,
                onSend: sendMessage,
                onVoiceMode: { isVoiceModeActive = true },
                accentColor: thread.bookId != nil ? accentColor : Color(red: 1.0, green: 0.55, blue: 0.26)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationBarHidden(true)
        .overlay {
            if isVoiceModeActive {
                VoiceModeOverlay(
                    isActive: $isVoiceModeActive,
                    transcript: $voiceTranscript,
                    thread: thread,
                    onSendTranscript: { transcript in
                        messageText = transcript
                        sendMessage()
                    }
                )
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
            // Limit messages to prevent memory issues
            if thread.messages.count > 100 {
                // Keep only the last 50 messages
                let messagesToKeep = Array(thread.messages.suffix(50))
                thread.messages = messagesToKeep
            }
        }
        .onDisappear {
            // Additional cleanup on disappear
            if thread.messages.count > 50 {
                let messagesToKeep = Array(thread.messages.suffix(50))
                thread.messages = messagesToKeep
            }
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
                
                // Get response from Perplexity (with caching)
                let response = try await PerplexityService.cachedChat(
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
    let accentColor: Color
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
                                    .fill(accentColor)
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
                        .stroke(accentColor.opacity(glowOpacity), lineWidth: 2)
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
    let onVoiceMode: () -> Void
    let accentColor: Color
    
    @State private var showSuggestions = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Suggestions (appear above input when plus button is tapped)
            if showSuggestions {
                ThreadSmartSuggestions(thread: thread, onSelectSuggestion: { suggestion in
                    text = suggestion
                    showSuggestions = false
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Input field - iMessage style
            HStack(spacing: 8) {
                // Plus button (left side)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSuggestions.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.tint(Color.white.opacity(0.1)), in: Circle())
                }
                
                // Input field container with glass effect
                HStack(spacing: 0) {
                    // Question mark icon
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(accentColor)
                        .font(.system(size: 20, weight: .medium))
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                    
                    // Text field
                    ZStack(alignment: .leading) {
                        if text.isEmpty {
                            Text(thread.bookId == nil ? "Ask about books..." : "Discuss \(thread.bookTitle ?? "this book")...")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))
                        }
                        
                        TextField("", text: $text, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .focused($isInputFocused)
                            .lineLimit(1...5)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit {
                                onSend()
                            }
                            .onChange(of: text) { _, newValue in
                                // Hide suggestions when user starts typing
                                if !newValue.isEmpty && showSuggestions {
                                    showSuggestions = false
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    
                    // Voice mode button inside input field
                    Button(action: onVoiceMode) {
                        Image(systemName: "waveform")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.orange)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                    }
                    .padding(.trailing, 12)
                }
                .frame(minHeight: 36)
                .glassEffect(.regular.tint(accentColor.opacity(0.15)), in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.3),
                                    accentColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                
                // Send button (appears when there's text)
                if !text.isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, accentColor)
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSuggestions)
    }
}

// MARK: - Thread Smart Suggestions
struct ThreadSmartSuggestions: View {
    let thread: ChatThread
    let onSelectSuggestion: (String) -> Void
    
    var suggestions: [(String, String, String)] {
        if thread.bookId == nil {
            return [
                ("Next Read", "book", "What should I read next?"),
                ("Similar", "books.vertical", "Recommend books like Harry Potter"),
                ("Classics", "text.book.closed", "Tell me about classic literature"),
                ("Sci-Fi", "sparkles", "What are the best sci-fi novels?")
            ]
        } else {
            return [
                ("Themes", "lightbulb", "What are the main themes?"),
                ("Character", "person.text.rectangle", "Analyze the protagonist"),
                ("Ending", "text.alignright", "Discuss the ending"),
                ("Compare", "books.vertical", "Compare to similar books")
            ]
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestions, id: \.2) { (title, icon, suggestion) in
                    Button {
                        onSelectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(title)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.tint(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3)), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.5),
                                            Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2), radius: 8, y: 4)
                    }
                }
            }
        }
        .frame(height: 40)
    }
}

// MARK: - Book-Centric Background
struct BookCentricBackground: View {
    let bookCoverURL: String?
    let bookTitle: String?
    let bookAuthor: String?
    let showBookCover: Bool
    @Binding var animationPhase: Double
    @State private var colorPalette: ColorPalette?
    @State private var gradientPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base dark background
            Color.black
                .ignoresSafeArea()
            
            // Book-specific gradient
            if let palette = colorPalette {
                ZStack {
                    // Top gradient
                    LinearGradient(
                        stops: [
                            .init(color: enhanceColor(palette.primary), location: 0.0),
                            .init(color: enhanceColor(palette.secondary), location: 0.2),
                            .init(color: enhanceColor(palette.accent).opacity(0.6), location: 0.4),
                            .init(color: Color.clear, location: 0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .blur(radius: 50)
                    .scaleEffect(y: 0.8 + gradientPhase * 0.3)
                    .offset(y: -150 + gradientPhase * 40)
                    
                    // Bottom gradient (mirrored)
                    LinearGradient(
                        stops: [
                            .init(color: enhanceColor(palette.accent), location: 0.0),
                            .init(color: enhanceColor(palette.secondary), location: 0.2),
                            .init(color: enhanceColor(palette.primary).opacity(0.6), location: 0.4),
                            .init(color: Color.clear, location: 0.7)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .ignoresSafeArea()
                    .blur(radius: 50)
                    .scaleEffect(y: 0.8 + gradientPhase * 0.3)
                    .offset(y: 150 - gradientPhase * 40)
                }
            } else {
                // Default amber gradient while loading
                EnhancedAmberGradient(
                    phase: gradientPhase,
                    audioLevel: 0,
                    isListening: false,
                    voiceFrequency: 0.5,
                    voiceIntensity: 0.0,
                    voiceRhythm: 0.0
                )
            }
            
            // Book cover in center (only when no messages)
            if showBookCover {
                VStack(spacing: 20) {
                    Spacer()
                    
                    if let coverURL = bookCoverURL {
                        SharedBookCoverView(coverURL: coverURL, width: 120, height: 168)
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                            .opacity(showBookCover ? 1.0 : 0.0)
                            .scaleEffect(showBookCover ? 1.0 : 0.8)
                            .animation(.easeInOut(duration: 0.8), value: showBookCover)
                    }
                    
                    // Book title and author
                    VStack(spacing: 8) {
                        if let title = bookTitle {
                            Text(title)
                                .font(.system(size: 24, weight: .medium, design: .serif))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        
                        if let author = bookAuthor {
                            Text(author)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .opacity(showBookCover ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8).delay(0.2), value: showBookCover)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
            }
            
            // Subtle overlay for readability
            Color.black.opacity(0.1)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            startGradientAnimation()
            if let coverURL = bookCoverURL {
                Task {
                    await extractBookColors(coverURL)
                }
            }
        }
        .onChange(of: bookCoverURL) { _, newURL in
            if let newURL = newURL {
                Task {
                    await extractBookColors(newURL)
                }
            } else {
                colorPalette = nil
            }
        }
    }
    
    private func startGradientAnimation() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            gradientPhase = 1
        }
    }
    
    private func extractBookColors(_ coverURL: String) async {
        let highQualityURL = coverURL
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "&zoom=5", with: "")
            .replacingOccurrences(of: "&zoom=4", with: "")
            .replacingOccurrences(of: "&zoom=3", with: "")
            .replacingOccurrences(of: "&zoom=2", with: "")
            .replacingOccurrences(of: "&zoom=1", with: "")
            .replacingOccurrences(of: "zoom=5", with: "")
            .replacingOccurrences(of: "zoom=4", with: "")
            .replacingOccurrences(of: "zoom=3", with: "")
            .replacingOccurrences(of: "zoom=2", with: "")
            .replacingOccurrences(of: "zoom=1", with: "")
        
        guard let url = URL(string: highQualityURL),
              let data = try? await URLSession.shared.data(from: url).0,
              let image = UIImage(data: data) else { return }
        
        let extractor = OKLABColorExtractor()
        if let extractedPalette = try? await extractor.extractPalette(from: image, imageSource: "BookCover") {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.2)) {
                    self.colorPalette = extractedPalette
                }
            }
        }
    }
    
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost vibrancy for background
        saturation = min(saturation * 1.6, 1.0)
        brightness = max(brightness, 0.5)
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
}
