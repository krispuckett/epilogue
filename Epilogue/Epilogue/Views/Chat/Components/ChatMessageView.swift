import SwiftUI
import SwiftData

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToNote = Notification.Name("navigateToNote")
    static let navigateToQuote = Notification.Name("navigateToQuote")
}

struct ChatMessageView: View {
    let message: UnifiedChatMessage
    let currentBookContext: Book?
    let colorPalette: ColorPalette?
    @State private var isAnimatingIn = false
    @State private var showTypingIndicator = false
    @State private var glowAnimation = 0.0
    @State private var rotationAngle = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Context switch messages
            if message.isContextSwitch {
                contextSwitchView
                    .transition(.scale.combined(with: .opacity))
            } else if message.isSystemMessage {
                // System messages (centered, no bubble)
                systemMessageView
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Regular message layout
                HStack(alignment: .bottom, spacing: 8) {
                    if message.isUser {
                        Spacer(minLength: 20) // Reduced spacing for better balance
                    }
                    
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                        // Message content
                        messageContent
                        
                        // Metadata row
                        metadataRow
                    }
                    
                    if !message.isUser {
                        Spacer(minLength: 20) // Reduced spacing for better balance
                    }
                }
            }
        }
        .padding(.horizontal, 16) // Equal padding for all messages
        .scaleEffect(isAnimatingIn ? 1 : 0.95)
        .opacity(isAnimatingIn ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isAnimatingIn = true
            }
            
            // Show typing indicator for AI messages briefly
            if !message.isUser && !message.isContextSwitch {
                showTypingIndicator = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTypingIndicator = false
                }
            }
        }
    }
    
    // MARK: - Message Content
    
    @ViewBuilder
    private var messageContent: some View {
        if showTypingIndicator && !message.isUser {
            TypingIndicatorView()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        } else if message.isWhisperTranscription {
            whisperTranscriptionView
        } else if message.isUser {
            userMessageBubble
        } else {
            // Check message type for special content
            switch message.messageType {
            case .note(let note):
                MiniNoteCard(note: note) {
                    // Navigation will be handled by parent view
                    NotificationCenter.default.post(
                        name: .navigateToNote,
                        object: note
                    )
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.85)
            case .noteWithContext(let note, let context):
                NoteWithContextBubble(note: note, context: context) {
                    // Navigation will be handled by parent view
                    NotificationCenter.default.post(
                        name: .navigateToNote,
                        object: note
                    )
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.85)
            case .quote(let quote):
                MiniQuoteCard(quote: quote) {
                    // Navigation will be handled by parent view
                    NotificationCenter.default.post(
                        name: .navigateToQuote,
                        object: quote
                    )
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.85)
            default:
                aiMessageContent
            }
        }
    }
    
    // MARK: - User Message Bubble
    
    private var userMessageBubble: some View {
        Text(message.content)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
            .glassEffect(in: .rect(cornerRadius: 18))
            .overlay(alignment: .topTrailing) {
                // Subtle border
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
    
    // MARK: - AI Message Content
    
    private var aiMessageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book context indicator if different from current
            if let messageBook = message.bookContext,
               messageBook.localId != currentBookContext?.localId {
                bookContextIndicator(for: messageBook)
            }
            
            // Markdown rendered content
            MarkdownText(text: message.content, isUserMessage: false)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .leading)
        .padding(.horizontal, 8) // Increased padding for better readability
    }
    
    // MARK: - Whisper Transcription View
    
    private var whisperTranscriptionView: some View {
        let primaryColor = colorPalette?.adaptiveUIColor ?? Color.red
        
        return HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 12))
                .foregroundStyle(primaryColor)
            
            Text("Transcribing...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 16))
        .overlay {
            // Animated glowing border with angular gradient for smooth loop
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            primaryColor,
                            primaryColor.opacity(0.3),
                            primaryColor.opacity(0.1),
                            primaryColor.opacity(0.3),
                            primaryColor
                        ]),
                        center: .center,
                        startAngle: .degrees(rotationAngle),
                        endAngle: .degrees(rotationAngle + 360)
                    ),
                    lineWidth: 2
                )
                .blur(radius: 4)
                .shadow(color: primaryColor.opacity(0.5), radius: 8)
                .shadow(color: primaryColor.opacity(0.3), radius: 16)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
    
    // MARK: - System Message View
    
    private var systemMessageView: some View {
        Text(message.content)
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Context Switch View
    
    private var contextSwitchView: some View {
        HStack(spacing: 12) {
            // Left line
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(height: 1)
                .frame(maxWidth: 80)
            
            // Content
            if let book = message.bookContext {
                HStack(spacing: 8) {
                    if let coverURL = book.coverImageURL {
                        SharedBookCoverView(
                            coverURL: coverURL,
                            width: 20,
                            height: 28
                        )
                        .cornerRadius(3)
                    }
                    
                    Text("Switched to \(book.title)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Text("Cleared book context")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Right line
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(height: 1)
                .frame(maxWidth: 80)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Book Context Indicator
    
    private func bookContextIndicator(for book: Book) -> some View {
        HStack(spacing: 6) {
            if let coverURL = book.coverImageURL {
                SharedBookCoverView(
                    coverURL: coverURL,
                    width: 16,
                    height: 22
                )
                .cornerRadius(2)
            }
            
            Text(book.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            
            Image(systemName: "book.closed")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
    
    // MARK: - Metadata Row
    
    private var metadataRow: some View {
        HStack(spacing: 8) {
            if message.isUser {
                Spacer()
            }
            
            // Timestamp
            Text(message.timestamp, formatter: timestampFormatter)
                .font(.custom("SF Mono", size: 11))
                .foregroundStyle(.white.opacity(0.4))
            
            // Status indicators
            if message.isUser && message.isDelivered {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    // MARK: - Formatters
    
    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1 : 0.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                animationPhase = 2
            }
        }
    }
}

// MARK: - Extended Message Model

extension UnifiedChatMessage {
    var isContextSwitch: Bool {
        if case .contextSwitch = messageType {
            return true
        }
        // Fallback for legacy messages
        return content.hasPrefix("[Context Switch]")
    }
    
    var isSystemMessage: Bool {
        if case .system = messageType {
            return true
        }
        // Fallback for legacy messages
        return content.hasPrefix("[System]") || content.hasPrefix("Added ")
    }
    
    var isWhisperTranscription: Bool {
        if case .transcribing = messageType {
            return true
        }
        // Fallback for legacy messages
        return content.hasPrefix("[Transcribing]")
    }
    
    var isDelivered: Bool {
        // For now, always true - can be extended with real delivery status
        true
    }
}


// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            // User message
            ChatMessageView(
                message: UnifiedChatMessage(
                    content: "What are the main themes in this book?",
                    isUser: true,
                    timestamp: Date(),
                    bookContext: nil
                ),
                currentBookContext: nil,
                colorPalette: nil
            )
            
            // AI response with book context
            ChatMessageView(
                message: UnifiedChatMessage(
                    content: "The main themes include identity, memory, and the nature of consciousness. The author explores how memories shape our sense of self.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: Book(
                        id: "preview-1",
                        title: "The Memory Palace",
                        author: "John Doe",
                        coverImageURL: nil,
                        isbn: "1234567890",
                        pageCount: 300
                    )
                ),
                currentBookContext: nil,
                colorPalette: nil
            )
            
            // Context switch
            ChatMessageView(
                message: UnifiedChatMessage(
                    content: "[Context Switch]",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: Book(
                        id: "preview-2",
                        title: "Another Book",
                        author: "Jane Smith",
                        coverImageURL: nil,
                        isbn: "0987654321",
                        pageCount: 250
                    )
                ),
                currentBookContext: nil,
                colorPalette: nil
            )
        }
        .padding()
    }
}

// MARK: - Note With Context Bubble

struct NoteWithContextBubble: View {
    let note: CapturedNote
    let context: String
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User's thought as a note card
            MiniNoteCard(note: note, onTap: onTap)
            
            // Optional context in smaller, subdued style
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                
                Text(context)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
}