import SwiftUI
import SwiftData

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
            } else {
                // Regular message layout
                HStack(alignment: .bottom, spacing: 12) {
                    if message.isUser {
                        Spacer(minLength: 80) // Reduced from 60 to 80 for better right anchoring
                    }
                    
                    VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                        // Message content
                        messageContent
                        
                        // Metadata row
                        metadataRow
                    }
                    
                    if !message.isUser {
                        Spacer(minLength: 60)
                    }
                }
            }
        }
        .padding(.horizontal, message.isUser ? 16 : 20) // Less padding for user messages
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
            aiMessageContent
        }
    }
    
    // MARK: - User Message Bubble
    
    private var userMessageBubble: some View {
        Text(message.content)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 300, alignment: .trailing)
            .glassEffect(in: .rect(cornerRadius: 20))
            .overlay(alignment: .topTrailing) {
                // Subtle border
                RoundedRectangle(cornerRadius: 20)
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
                .frame(maxWidth: 300, alignment: .leading)
        }
        .padding(.horizontal, 4) // Minimal padding for clean look
    }
    
    // MARK: - Whisper Transcription View
    
    private var whisperTranscriptionView: some View {
        let primaryColor = colorPalette?.primary ?? Color.red
        
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
        // You can add a messageType enum to UnifiedChatMessage
        // For now, check if content starts with specific pattern
        content.hasPrefix("[Context Switch]")
    }
    
    var isWhisperTranscription: Bool {
        // Check if this is a transcription in progress
        content.hasPrefix("[Transcribing]")
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