import SwiftUI

// MARK: - Generic Ambient Empty State

/// Minimal liquid glass pill empty state for generic ambient mode
/// Shows intelligent suggestions that populate the input bar
struct GenericAmbientEmptyState: View {
    let onSuggestionTap: (String) -> Void
    let librarySize: Int
    let recentBookTitle: String?

    @State private var isVisible = false

    // Intelligent suggestions based on context
    private var suggestions: [String] {
        var items: [String] = []

        // Core recommendation (always shown)
        items.append("What should I read next?")

        // Personalized similarity suggestion
        if let recentBook = recentBookTitle {
            items.append("Something like \(recentBook)")
        }

        // Actionable goal-oriented suggestions
        items.append("Help me build a reading habit")
        items.append("Create a reading challenge")

        // Library insights (only if enough books)
        if librarySize >= 5 {
            items.append("Analyze my reading taste")
        }

        return items
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Centered pills
            VStack(spacing: 10) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    SuggestionPill(
                        text: suggestion,
                        delay: Double(index) * 0.08
                    ) {
                        SensoryFeedback.light()
                        onSuggestionTap(suggestion)
                    }
                }
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Suggestion Pill

/// Minimal centered pill button with liquid glass
private struct SuggestionPill: View {
    let text: String
    let delay: Double
    let action: () -> Void

    @State private var isVisible = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .capsule)
                .scaleEffect(isPressed ? 0.96 : 1)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Book-Specific Empty State

/// Enhanced book-specific empty state with intelligent, contextual pills
/// Matches the clean liquid glass style of generic ambient mode
struct BookSpecificEmptyState: View {
    let book: Book
    let colorPalette: ColorPalette?  // Kept for API compatibility but not used for tinting
    let currentPage: Int?
    let hasNotes: Bool
    let hasQuotes: Bool
    let onSuggestionTap: (String) -> Void
    let onCaptureQuote: () -> Void  // Special action for quote capture

    @State private var isVisible = false

    /// Intelligent suggestions based on book context
    private var suggestions: [BookSuggestion] {
        var items: [BookSuggestion] = []

        // Always show capture quote as a primary action
        items.append(BookSuggestion(
            text: "Capture a quote",
            isSpecialAction: true
        ))

        // Contextual based on reading progress
        if let page = currentPage, page > 0 {
            items.append(BookSuggestion(text: "Summarize where I am"))
        }

        // Theme exploration
        items.append(BookSuggestion(text: "What are the main themes?"))

        // Author context
        let authorLastName = book.author.components(separatedBy: " ").last ?? "the author"
        items.append(BookSuggestion(text: "Tell me about \(authorLastName)"))

        // If they have notes, offer to discuss them
        if hasNotes {
            items.append(BookSuggestion(text: "Review my notes"))
        }

        // Similar books recommendation
        items.append(BookSuggestion(text: "Books similar to this"))

        // Limit to 5 suggestions max
        return Array(items.prefix(5))
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Centered pills - matching generic ambient style
            VStack(spacing: 10) {
                ForEach(Array(suggestions.enumerated()), id: \.element.text) { index, suggestion in
                    SuggestionPill(
                        text: suggestion.text,
                        delay: Double(index) * 0.08
                    ) {
                        SensoryFeedback.light()
                        if suggestion.isSpecialAction {
                            onCaptureQuote()
                        } else {
                            onSuggestionTap(suggestion.text)
                        }
                    }
                }
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

/// Model for book-specific suggestions
private struct BookSuggestion: Equatable {
    let text: String
    var isSpecialAction: Bool = false
}

// MARK: - Related Questions Pills Row

/// Horizontal scrolling row of smaller follow-up question pills
/// Appears below AI responses to continue the conversation
struct RelatedQuestionsPillRow: View {
    let questions: [String]
    let onQuestionTap: (String) -> Void

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Subtle label
            Text("CONTINUE EXPLORING")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.0)
                .opacity(isVisible ? 1 : 0)

            // Horizontal scroll of compact pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(questions.prefix(4).enumerated()), id: \.offset) { index, question in
                        RelatedQuestionPill(
                            text: question,
                            delay: Double(index) * 0.06
                        ) {
                            SensoryFeedback.light()
                            onQuestionTap(question)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.top, 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                isVisible = true
            }
        }
    }
}

/// Compact pill for related questions - smaller than main suggestions
private struct RelatedQuestionPill: View {
    let text: String
    let delay: Double
    let action: () -> Void

    @State private var isVisible = false
    @State private var isPressed = false

    // Truncate long questions for compact display
    private var displayText: String {
        if text.count > 45 {
            return String(text.prefix(42)) + "..."
        }
        return text
    }

    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            Text(displayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: .capsule)
                .scaleEffect(isPressed ? 0.95 : 1)
                .opacity(isVisible ? 1 : 0)
                .offset(x: isVisible ? 0 : 15)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Related Questions Pills") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        VStack {
            Spacer()

            RelatedQuestionsPillRow(
                questions: [
                    "What are the main themes?",
                    "How does the author's style compare?",
                    "Who are the key characters?",
                    "What inspired this work?"
                ],
                onQuestionTap: { question in
                    print("Tapped: \(question)")
                }
            )
            .padding(.horizontal, 20)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Generic Empty State") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        GenericAmbientEmptyState(
            onSuggestionTap: { suggestion in
                print("Tapped: \(suggestion)")
            },
            librarySize: 25,
            recentBookTitle: "The Great Gatsby"
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Book-Specific Empty State") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        BookSpecificEmptyState(
            book: Book(
                id: "preview-lotr",
                title: "The Lord of the Rings",
                author: "J.R.R. Tolkien",
                isbn: nil
            ),
            colorPalette: nil,
            currentPage: 150,
            hasNotes: true,
            hasQuotes: false,
            onSuggestionTap: { suggestion in
                print("Tapped: \(suggestion)")
            },
            onCaptureQuote: {
                print("Capture quote tapped")
            }
        )
    }
    .preferredColorScheme(.dark)
}
