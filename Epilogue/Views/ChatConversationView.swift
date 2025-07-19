import SwiftUI
import SwiftData
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

struct ChatConversationView: View {
    let thread: ChatThread
    @Binding var showingThreadList: Bool
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
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
    
    // Book cover color extraction
    @State private var dominantColor: Color = Color(red: 0.11, green: 0.105, blue: 0.102)
    @State private var secondaryColor: Color = Color(red: 0.15, green: 0.14, blue: 0.135)
    
    // Computed property for the accent color to use
    private var accentColor: Color {
        // Check if dominant color is too dark (near black)
        let uiColor = UIColor(dominantColor)
        var brightness: CGFloat = 0
        uiColor.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        
        // If too dark, use secondary color or fallback
        if brightness < 0.3 {
            return secondaryColor != Color(red: 0.15, green: 0.14, blue: 0.135) ? secondaryColor : Color(red: 1.0, green: 0.55, blue: 0.26)
        }
        return dominantColor
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
            // Book-themed background with extracted colors
            if thread.bookId != nil {
                BookChatBackground(
                    dominantColor: dominantColor,
                    secondaryColor: secondaryColor,
                    animationPhase: $animationPhase
                )
            } else {
                // General discussion background
                AmbientBackground(animationPhase: $animationPhase, orbPositions: $orbPositions)
            }
            
            // Messages ScrollView with padding for header
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 20) {
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
                            HapticManager.shared.mediumImpact()
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
                    .padding(.top, 60) // Space for custom header
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: thread.messages.count) { _, _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Custom header overlay
            VStack {
                CustomChatHeader(
                    title: thread.bookTitle ?? "General Discussion",
                    onBack: { showingThreadList = true },
                    onClear: { showingClearConfirmation = true },
                    accentColor: thread.bookId != nil ? accentColor : Color(red: 1.0, green: 0.55, blue: 0.26)
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
                accentColor: thread.bookId != nil ? accentColor : Color(red: 1.0, green: 0.55, blue: 0.26)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationBarHidden(true)
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
            extractBookCoverColors()
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
    
    private func extractBookCoverColors() {
        guard let coverURL = effectiveCoverURL else { return }
        
        // Enhance URL for better quality
        var enhanced = coverURL.replacingOccurrences(of: "http://", with: "https://")
        if !enhanced.contains("zoom=") {
            enhanced += enhanced.contains("?") ? "&zoom=2" : "?zoom=2"
        }
        
        guard let url = URL(string: enhanced) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.extractColors(from: uiImage)
                }
            }
        }.resume()
    }
    
    private func extractColors(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        
        let context = CIContext()
        let size = CGSize(width: 50, height: 50)
        
        // Scale down for performance
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = ciImage
        scaleFilter.scale = Float(size.width / ciImage.extent.width)
        
        guard let outputImage = scaleFilter.outputImage else { return }
        
        // Extract colors
        let extent = outputImage.extent
        let bitmap = context.createCGImage(outputImage, from: extent)
        
        guard let cgImage = bitmap else { return }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let bitmapContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        bitmapContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Collect all colors with their frequencies
        var colorCounts: [UIColor: Int] = [:]
        
        for y in 0..<height {
            for x in 0..<width {
                let index = ((width * y) + x) * bytesPerPixel
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                // Quantize colors to reduce variations
                let quantizedR = round(r * 10) / 10
                let quantizedG = round(g * 10) / 10
                let quantizedB = round(b * 10) / 10
                
                let color = UIColor(red: quantizedR, green: quantizedG, blue: quantizedB, alpha: 1.0)
                colorCounts[color, default: 0] += 1
            }
        }
        
        // Sort colors by frequency and filter out very dark/light colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
            .compactMap { (color, _) -> (UIColor, CGFloat, CGFloat, CGFloat)? in
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                
                // Filter out very dark, very light, or desaturated colors
                if b > 0.2 && b < 0.95 && s > 0.2 {
                    return (color, h, s, b)
                }
                return nil
            }
        
        // Get primary and secondary colors
        if let firstColor = sortedColors.first {
            let (_, h1, s1, b1) = firstColor
            
            // Boost saturation for primary color
            let boostedS1 = min(s1 * 1.5, 1.0)
            let boostedB1 = min(b1 * 1.3, 0.85)
            
            withAnimation(.easeInOut(duration: 0.8)) {
                dominantColor = Color(hue: Double(h1), saturation: Double(boostedS1), brightness: Double(boostedB1))
            }
            
            // Look for a contrasting secondary color
            if sortedColors.count > 1 {
                // Find a color with different hue
                for i in 1..<min(sortedColors.count, 10) {
                    let (_, h2, s2, b2) = sortedColors[i]
                    let hueDiff = abs(h1 - h2)
                    
                    // If hue is different enough (at least 30 degrees on color wheel)
                    if hueDiff > 0.083 && hueDiff < 0.917 { // 30/360 and not opposite
                        let boostedS2 = min(s2 * 1.4, 1.0)
                        let boostedB2 = min(b2 * 1.2, 0.8)
                        
                        withAnimation(.easeInOut(duration: 0.8)) {
                            secondaryColor = Color(hue: Double(h2), saturation: Double(boostedS2), brightness: Double(boostedB2))
                        }
                        break
                    }
                }
            }
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
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
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
            .padding(.horizontal, 16)
        }
        .frame(height: 40)
        .padding(.bottom, 8)
    }
}

// MARK: - Custom Chat Header
struct CustomChatHeader: View {
    let title: String
    let onBack: () -> Void
    let onClear: () -> Void
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Chats")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .glassEffect(.clear.tint(accentColor.opacity(0.2)), in: RoundedRectangle(cornerRadius: 16))
            
            // Title with proper spacing and wrapping
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2) // Allow up to 2 lines
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.trailing, 100) // Add padding to balance the back button width
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Book Chat Background
struct BookChatBackground: View {
    let dominantColor: Color
    let secondaryColor: Color
    @Binding var animationPhase: Double
    
    var body: some View {
        ZStack {
            // Base midnight scholar background
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            // Ambient gradient background from book colors (matching BookDetailView)
            LinearGradient(
                colors: [
                    dominantColor.opacity(0.4),
                    secondaryColor.opacity(0.3),
                    dominantColor.opacity(0.2),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Radial glow at the top with secondary color accent
            RadialGradient(
                colors: [
                    secondaryColor == .clear ? dominantColor.opacity(0.3) : secondaryColor.opacity(0.4),
                    dominantColor.opacity(0.2),
                    Color.clear
                ],
                center: .top,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            
            // Subtle animated glow orbs
            ForEach(0..<2) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                index == 0 ? dominantColor.opacity(0.2) : secondaryColor.opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .offset(
                        x: sin(animationPhase + Double(index) * .pi) * 80,
                        y: cos(animationPhase + Double(index) * .pi) * 120
                    )
                    .opacity(0.6)
            }
        }
    }
}
