import SwiftUI
import SwiftData

// MARK: - Scrolling Book Messages for Loading State
struct ScrollingBookMessages: View {
    @State private var currentMessageIndex = 0
    @State private var opacity: Double = 1.0
    @State private var usedIndices: Set<Int> = []
    @State private var cyclingTimer: Timer?

    let messages = [
        // Literary and bookish phrases
        "Reading between the lines...",
        "Consulting the archives...",
        "Searching ancient texts...",
        "Analyzing the narrative...",
        "Cross-referencing chapters...",
        "Studying the lore...",
        "Unraveling the story...",
        "Decoding the metaphors...",
        "Following the plot threads...",
        "Examining character arcs...",
        "Parsing the prose...",
        "Exploring the themes...",
        "Mapping the world...",
        "Tracing the timeline...",
        "Uncovering hidden meanings...",
        "Connecting the dots...",
        "Diving into the subtext...",
        "Illuminating the passage...",
        "Consulting my notes...",
        "Checking the appendices...",
        "Reviewing the canon...",
        "Scanning the margins...",
        "Flipping through pages...",
        "Pondering the symbolism...",
        "Seeking wisdom...",
        "Gathering insights...",
        "Weaving understanding...",
        "Building connections...",
        "Finding the answer...",
        "Contemplating deeply..."
    ]

    var body: some View {
        Text(messages[currentMessageIndex])
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.4), value: opacity)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false) // Keep text on single line
            .onAppear {
                // Start with a random message
                currentMessageIndex = Int.random(in: 0..<messages.count)
                usedIndices.insert(currentMessageIndex)
                startCycling()
            }
            .onDisappear {
                cyclingTimer?.invalidate()
                cyclingTimer = nil
            }
    }

    private func startCycling() {
        cyclingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Get next random message, avoiding recently used ones
                let nextIndex = getNextRandomIndex()
                currentMessageIndex = nextIndex
                usedIndices.insert(nextIndex)

                // Reset used indices if we've used more than half
                if usedIndices.count > messages.count / 2 {
                    let currentIndex = currentMessageIndex
                    usedIndices.removeAll()
                    usedIndices.insert(currentIndex)
                }

                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                }
            }
        }
    }

    private func getNextRandomIndex() -> Int {
        var availableIndices = Array(0..<messages.count).filter { !usedIndices.contains($0) }

        // If all have been used, reset and exclude current
        if availableIndices.isEmpty {
            availableIndices = Array(0..<messages.count).filter { $0 != currentMessageIndex }
        }

        return availableIndices.randomElement() ?? 0
    }
}

// MARK: - Ambient Message Thread View (Minimal Style)
// MARK: - Quote View for Live Ambient Mode
struct AmbientQuoteView: View {
    let quote: CapturedQuote
    let index: Int
    let onEdit: (String) -> Void

    @State private var quoteOpacity: Double = 0.3
    @State private var quoteBlur: Double = 12
    @State private var quoteScale: CGFloat = 0.96

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                // Quote icon
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))

                    Text("QUOTE")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1.2)

                    Spacer()
                }

                // Quote text with elegant typography - TAPPABLE FOR EDITING
                Text(quote.text ?? "")
                    .font(.custom("Georgia", size: 16))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        SensoryFeedback.light()
                        onEdit(quote.text ?? "")
                    }

                // Horizontal divider line
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(0.1), location: 0),
                        .init(color: Color.white.opacity(0.5), location: 0.5),
                        .init(color: Color.white.opacity(0.1), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Attribution section (author and book title)
                VStack(alignment: .leading, spacing: 6) {
                    if let author = quote.author {
                        Text(author.uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let bookTitle = quote.book?.title {
                        Text(bookTitle.uppercased())
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
        .opacity(quoteOpacity)
        .blur(radius: quoteBlur)
        .scaleEffect(quoteScale)
        .onAppear {
            // Check for reduced motion preference
            let reduceMotion = UIAccessibility.isReduceMotionEnabled

            if reduceMotion {
                // Simple fade for accessibility
                withAnimation(.easeOut(duration: 0.3)) {
                    quoteOpacity = 1.0
                }
            } else {
                // Sophisticated blur revelation for quotes
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.5)) {
                    quoteOpacity = 1.0
                    quoteBlur = 0
                    quoteScale = 1.0
                }
            }
        }
    }
}

// MARK: - Note View for Live Ambient Mode
struct AmbientNoteView: View {
    let note: CapturedNote
    let index: Int
    let onEdit: (String) -> Void

    @State private var noteOpacity: Double = 0.3
    @State private var noteBlur: Double = 12
    @State private var noteScale: CGFloat = 0.96

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Index number
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 24)

                // Note content with icon
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                            .foregroundStyle(.yellow.opacity(0.8))

                        Text("Note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.yellow.opacity(0.8))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    Text(note.content ?? "")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                SensoryFeedback.light()
                onEdit(note.content ?? "")
            }
        }
        .padding(.vertical, 16)
        .opacity(noteOpacity)
        .blur(radius: noteBlur)
        .scaleEffect(noteScale)
        .onAppear {
            // Check for reduced motion preference
            let reduceMotion = UIAccessibility.isReduceMotionEnabled

            if reduceMotion {
                // Simple fade for accessibility
                withAnimation(.easeOut(duration: 0.3)) {
                    noteOpacity = 1.0
                }
            } else {
                // Sophisticated blur revelation animation
                withAnimation(
                    .timingCurve(0.215, 0.61, 0.355, 1, duration: 0.8)
                ) {
                    noteOpacity = 1.0
                    noteBlur = 0
                    noteScale = 1.0
                }
            }
        }
    }
}

struct AmbientMessageThreadView: View {
    let message: UnifiedChatMessage
    let index: Int
    let totalMessages: Int
    let isExpanded: Bool
    let streamingText: String?
    let relatedQuestions: [String]  // Follow-up suggestions from Sonar
    let onToggle: () -> Void
    let onEdit: ((String) -> Void)?
    let onRelatedQuestionTap: ((String) -> Void)?  // Continue conversation
    @Binding var showPaywall: Bool

    @State private var messageOpacity: Double = 0.3
    @State private var messageBlur: Double = 12
    @State private var messageScale: CGFloat = 0.96
    @State private var showThinkingParticles = false
    @State private var answerOpacity: Double = 0
    @State private var answerBlur: Double = 8
    @State private var hasShownAnswer = false

    // Check if this is the first AI response in the session
    private var isFirstAIResponse: Bool {
        // Simplified check - you can make this more robust based on your needs
        !message.isUser && index < 2
    }

    private var animationDelay: Double {
        if message.isUser {
            return 0 // User messages appear immediately
        } else {
            return isFirstAIResponse ? 0.6 : 0.4 // AI responses have delay
        }
    }

    private var animationDuration: Double {
        isFirstAIResponse ? 0.8 : 0.6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thinking particles for AI messages (before message appears)
            if !message.isUser && showThinkingParticles {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(DesignSystem.Colors.textQuaternary)
                            .frame(width: 4, height: 4)
                            .blur(radius: 1)
                            .scaleEffect(showThinkingParticles ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: showThinkingParticles
                            )
                    }
                }
                .padding(.leading, 40)
                .opacity(messageOpacity < 1 ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: messageOpacity)
            }

            // Question/response row with blur revelation
            HStack(alignment: .center, spacing: 16) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 24)

                if message.isUser {
                    Text(message.content)
                        .font(.system(size: 16, weight: .regular, design: .default))  // Match note cards
                        .foregroundStyle(.white.opacity(0.95)) // Match note cards opacity
                        .lineLimit(2)  // Allow question to wrap to 2 lines if needed
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Use streaming text if available, otherwise use message content
                    Group {
                        let displayContent: String = {
                            if let streaming = streamingText {
                                return "**\(extractContent(from: message.content).question)**\n\n\(streaming)"
                            } else {
                                return message.content
                            }
                        }()
                        let content = extractContent(from: displayContent)

                        // Show question text
                        Text(content.question)
                            .font(.system(size: 16, weight: .regular, design: .default))  // Match note cards
                            .foregroundStyle(.white.opacity(0.95)) // Match note cards opacity
                            .lineLimit(2)  // Allow question to wrap to 2 lines if needed
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !message.isUser {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textQuaternary)
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .opacity(messageOpacity)
            .blur(radius: messageBlur) // No extra blur when collapsed
            .scaleEffect(messageScale)
            .onTapGesture {
                if message.isUser {
                    // Edit user questions
                    if let onEdit = onEdit {
                        SensoryFeedback.light()
                        onEdit(message.content)
                    }
                } else {
                    // Toggle expansion for AI responses
                    onToggle()
                }
            }
            .onAppear {
                // Check for reduced motion preference
                let reduceMotion = UIAccessibility.isReduceMotionEnabled

                if reduceMotion {
                    // Simple fade for accessibility
                    withAnimation(.easeOut(duration: 0.3).delay(animationDelay)) {
                        messageOpacity = 1.0
                    }
                } else {
                    // Show thinking particles for AI messages
                    if !message.isUser {
                        showThinkingParticles = true
                    }

                    // Sophisticated blur revelation animation
                    withAnimation(
                        .timingCurve(0.215, 0.61, 0.355, 1, duration: animationDuration)
                        .delay(animationDelay)
                    ) {
                        messageOpacity = 1.0
                        messageBlur = 0
                        messageScale = 1.0
                        showThinkingParticles = false
                    }
                }
            }

            // Answer (expandable for AI responses) with blur transition
            if !message.isUser && isExpanded {
                // Use streaming text if available
                let displayContent: String = {
                    if let streaming = streamingText {
                        return "**\(extractContent(from: message.content).question)**\n\n\(streaming)"
                    } else {
                        return message.content
                    }
                }()
                let content = extractContent(from: displayContent)

                // If no answer yet, don't show anything special
                // The scrolling text is already shown above the input field
                if content.answer.isEmpty && streamingText == nil {
                    // Empty state - answer will appear here when ready
                } else {
                    // Show answer when ready with staggered fade-in
                    VStack(alignment: .leading, spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 0.5)

                        // Check if content has upgrade button
                        let hasUpgradeButton = content.answer.contains("[UPGRADE_BUTTON]")
                        let cleanAnswer = content.answer.replacingOccurrences(of: "[UPGRADE_BUTTON]", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

                        // Use streaming text view for polished materializing effect
                        StreamingTextView(
                            text: formatResponseText(cleanAnswer),
                            isStreaming: streamingText != nil
                        )
                        .padding(.leading, 0)
                        .padding(.trailing, 20)
                        .padding(.vertical, 12)
                        .padding(.bottom, hasUpgradeButton ? 0 : 4)

                        // Upgrade button if present
                        if hasUpgradeButton {
                            Button {
                                SensoryFeedback.light()
                                showPaywall = true
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.15))
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(
                                                    Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.4),
                                                    lineWidth: 1.5
                                                )
                                        }

                                    Text("Upgrade to Epilogue+")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .frame(height: 48)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        }

                        // Related questions pills - continue the conversation
                        if !relatedQuestions.isEmpty, let onTap = onRelatedQuestionTap {
                            RelatedQuestionsPillRow(
                                questions: relatedQuestions,
                                onQuestionTap: onTap
                            )
                        }
                    }
                    .opacity(isExpanded ? answerOpacity : 0)
                    .blur(radius: isExpanded ? answerBlur : 8)
                    .onAppear {
                        // Show answer immediately without delay
                        hasShownAnswer = true
                        // Elegant fade-in with perfect timing
                        withAnimation(.timingCurve(0.32, 0, 0.67, 0, duration: 0.5)) {
                            answerOpacity = 1.0
                        }
                        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
                            answerBlur = 0
                        }
                    }
                    .onChange(of: isExpanded) { _, newValue in
                        // Handle collapse/expand without animation after first show
                        if hasShownAnswer {
                            answerOpacity = newValue ? 1.0 : 0
                            answerBlur = newValue ? 0 : 8
                        }
                    }
                }
            }
        }
    }

    private func extractContent(from text: String) -> (question: String, answer: String) {
        // Check if the content is formatted with question and answer
        if text.contains("**") && text.contains("\n\n") {
            let parts = text.components(separatedBy: "\n\n")
            if parts.count >= 2 {
                let question = parts[0].replacingOccurrences(of: "**", with: "")
                let answer = parts.dropFirst().joined(separator: "\n\n")
                return (question, answer)
            }
        }
        // Otherwise return the full text as the question
        return (text, "")
    }

    private func formatResponseText(_ text: String) -> AttributedString {
        // CRITICAL FIX: Preserve original formatting, only clean markdown
        // DO NOT destroy line breaks, lists, or spacing
        let cleanText = text
            .replacingOccurrences(of: "**", with: "") // Remove markdown bold
            .replacingOccurrences(of: "##", with: "") // Remove markdown headers

        // Convert to AttributedString with markdown support
        // This preserves ALL original formatting including line breaks, lists, etc.
        do {
            return try AttributedString(markdown: cleanText)
        } catch {
            // Fallback if markdown parsing fails
            return AttributedString(cleanText)
        }
    }
}

// MARK: - Generic Mode Typing Indicator
/// Polished amber-tinted typing indicator with fluid wave animation
struct GenericModeTypingIndicator: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]
    @State private var timer: Timer?

    // Amber accent color matching app theme
    private let amberColor = Color(red: 1.0, green: 0.6, blue: 0.2)

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(amberColor)
                        .frame(width: 8, height: 8)
                        .offset(y: dotOffsets[i])
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(amberColor.opacity(0.15)))

            Spacer()
        }
        .onAppear {
            startBounceAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startBounceAnimation() {
        // Staggered bounce for each dot
        for i in 0..<3 {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateDot(at: i)
            }
        }

        // Repeat the whole sequence
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            for i in 0..<3 {
                let delay = Double(i) * 0.15
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    animateDot(at: i)
                }
            }
        }
    }

    private func animateDot(at index: Int) {
        withAnimation(.easeOut(duration: 0.25)) {
            dotOffsets[index] = -6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.25)) {
                dotOffsets[index] = 0
            }
        }
    }
}

// MARK: - Generic Mode Chat Bubble
/// Amber-tinted chat bubble for Generic mode with proper markdown rendering
struct GenericModeChatBubble: View {
    let message: UnifiedChatMessage
    let isExpanded: Bool
    let streamingText: String?  // v0 best practice: separate streaming text from message content
    let onToggle: () -> Void

    @State private var messageOpacity: Double = 0
    @State private var messageScale: CGFloat = 0.95

    // Amber accent matching app theme
    private let amberColor = Color(red: 1.0, green: 0.6, blue: 0.2)

    // Display streaming text if available, otherwise message content
    private var displayContent: String {
        streamingText ?? message.content
    }

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if message.isUser {
                    // User message - right aligned with amber-tinted glass
                    Text(message.content)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(nil) // Allow full text to wrap
                        .fixedSize(horizontal: false, vertical: true) // Prevent truncation
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(amberColor.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(amberColor.opacity(0.4), lineWidth: 1)
                        )
                } else {
                    // AI response - left aligned with amber glass tint
                    VStack(alignment: .leading, spacing: 12) {
                        // Rendered markdown content with streaming effects
                        GenericModeStreamingText(
                            text: displayContent,
                            isStreaming: streamingText != nil,
                            isExpanded: isExpanded
                        )
                        .fixedSize(horizontal: false, vertical: true) // Ensure full content shows

                        // Expand indicator for long content
                        if !isExpanded && displayContent.count > 300 {
                            HStack(spacing: 4) {
                                Text("Tap to expand")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(amberColor.opacity(0.7))
                            .padding(.top, 4)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true) // Allow VStack to grow
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16) // More vertical padding
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(amberColor.opacity(0.25), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggle()
                    }
                }
            }

            if !message.isUser {
                Spacer(minLength: 12)
            }
        }
        .padding(.vertical, 10) // More spacing between bubbles
        .opacity(messageOpacity)
        .scaleEffect(messageScale)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                messageOpacity = 1
                messageScale = 1
            }
        }
    }
}

// MARK: - Streaming Text View
/// Polished streaming text with materializing fade effect
/// Shows text with trailing content fading in smoothly as it streams
struct StreamingTextView: View {
    let attributedText: AttributedString
    let isStreaming: Bool
    let lineSpacing: CGFloat

    init(
        text: AttributedString,
        isStreaming: Bool,
        lineSpacing: CGFloat = 8
    ) {
        self.attributedText = text
        self.isStreaming = isStreaming
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        Text(attributedText)
            .font(.system(size: 17, design: .serif))  // SF Serif
            .foregroundStyle(.white.opacity(0.85))
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .mask {
                if isStreaming {
                    // Gradient mask fades trailing content for materializing effect
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .white,
                                .white,
                                .white,
                                .white.opacity(0.9),
                                .white.opacity(0.6),
                                .white.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: geo.size.width, height: geo.size.height + 20)
                    }
                } else {
                    Rectangle()
                }
            }
    }
}

// MARK: - Generic Mode Streaming Text
/// Streaming-aware markdown text for generic mode chat bubbles
struct GenericModeStreamingText: View {
    let text: String
    let isStreaming: Bool
    let isExpanded: Bool

    var body: some View {
        GenericModeMarkdownText(text: text, isExpanded: isExpanded)
            .mask {
                if isStreaming {
                    // Gradient mask fades trailing content for materializing effect
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .white,
                                .white,
                                .white,
                                .white.opacity(0.85),
                                .white.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: geo.size.width, height: geo.size.height + 16)
                    }
                } else {
                    Rectangle()
                }
            }
    }
}

// MARK: - Generic Mode Markdown Text Renderer
/// Renders markdown with proper formatting - strips all markdown symbols
struct GenericModeMarkdownText: View {
    let text: String
    let isExpanded: Bool

    // Amber accent
    private let amberColor = Color(red: 1.0, green: 0.6, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parsedBlocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
        // Always show full content - parent handles collapse state
        .fixedSize(horizontal: false, vertical: true)
    }

    private var parsedBlocks: [MarkdownBlock] {
        parseMarkdown(text)
    }

    private enum MarkdownBlock {
        case paragraph(String)
        case numberedItem(Int, String, String?) // num, title, description
        case bulletItem(String)
    }

    private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentParagraph = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            guard !trimmed.isEmpty else {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(cleanAllMarkdown(currentParagraph)))
                    currentParagraph = ""
                }
                continue
            }

            // Check for numbered list patterns like "**1." or "1." or "**1. *Title*"
            if let numRange = trimmed.range(of: #"^\*{0,2}\d+\.?\*{0,2}\s+"#, options: .regularExpression) {
                // Flush paragraph
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(cleanAllMarkdown(currentParagraph)))
                    currentParagraph = ""
                }

                // Extract number
                let prefix = String(trimmed[numRange])
                if let digitMatch = prefix.range(of: #"\d+"#, options: .regularExpression) {
                    let num = Int(prefix[digitMatch]) ?? 1
                    let content = String(trimmed[numRange.upperBound...])

                    // Try to split into title and description
                    // Pattern: *Title* by Author - Description OR Title by Author\nDescription
                    let cleaned = cleanAllMarkdown(content)

                    // Check if there's a " by " pattern to split title from description
                    if let byRange = cleaned.range(of: " by ", options: .caseInsensitive) {
                        let title = String(cleaned[..<byRange.lowerBound])
                        let rest = String(cleaned[byRange.lowerBound...])
                        blocks.append(.numberedItem(num, title, rest))
                    } else {
                        blocks.append(.numberedItem(num, cleaned, nil))
                    }
                }
            }
            // Check for bullet list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(cleanAllMarkdown(currentParagraph)))
                    currentParagraph = ""
                }
                let content = String(trimmed.dropFirst(2))
                blocks.append(.bulletItem(cleanAllMarkdown(content)))
            }
            // Regular text - accumulate into paragraph
            else {
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmed
            }
        }

        // Flush remaining
        if !currentParagraph.isEmpty {
            blocks.append(.paragraph(cleanAllMarkdown(currentParagraph)))
        }

        return blocks
    }

    /// Strip ALL markdown formatting characters
    private func cleanAllMarkdown(_ text: String) -> String {
        var result = text
        // Remove bold markers
        result = result.replacingOccurrences(of: "**", with: "")
        // Remove italic markers (but be careful not to break contractions)
        result = result.replacingOccurrences(of: "*", with: "")
        // Remove code markers
        result = result.replacingOccurrences(of: "`", with: "")
        // Remove heading markers
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")
        // Remove footnote references like [1], [2], etc.
        let footnotePattern = "\\[\\d+\\]"
        if let regex = try? NSRegularExpression(pattern: footnotePattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        // Clean up extra spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

        case .numberedItem(let num, let title, let description):
            // Check if this looks like a book recommendation (contains " by " for author)
            let looksLikeBookRecommendation = title.contains(" by ") ||
                                              (description?.contains(" by ") ?? false)

            VStack(alignment: .leading, spacing: 8) {
                // Title line with number integrated
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(num). ")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(amberColor.opacity(0.6))

                    Text(title)
                        .font(.system(size: 16, weight: looksLikeBookRecommendation ? .semibold : .regular))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    // Only show action icons for actual book recommendations
                    if looksLikeBookRecommendation {
                        HStack(spacing: 16) {
                            Button {
                                SensoryFeedback.light()
                                NotificationCenter.default.post(
                                    name: .addBookToLibrary,
                                    object: title
                                )
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            .buttonStyle(.plain)

                            Button {
                                SensoryFeedback.light()
                                // Use user's preferred bookstore
                                BookstoreURLBuilder.shared.openBookstore(title: title, author: "")
                            } label: {
                                Image(systemName: "cart")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Description - softer, more space
                if let desc = description {
                    Text(desc)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, "\(num). ".count > 2 ? 20 : 16) // Align with title
                }
            }
            .padding(.vertical, 4) // Breathing room between items

        case .bulletItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(amberColor)
                    .frame(width: 6, height: 6)
                    .padding(.leading, 8)

                Text(text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}
