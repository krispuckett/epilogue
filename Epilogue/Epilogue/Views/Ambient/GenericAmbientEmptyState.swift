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

/// Enhanced book-specific empty state with minimal pills
struct BookSpecificEmptyState: View {
    let book: Book
    let colorPalette: ColorPalette?
    let onSuggestionTap: (String) -> Void

    @State private var isVisible = false

    private var accentColor: Color {
        colorPalette?.primary ?? DesignSystem.Colors.primaryAccent
    }

    private var suggestions: [String] {
        [
            "What's the main theme?",
            "Tell me about the author",
            "Capture a quote",
            "Summarize where I left off"
        ]
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Book header
            VStack(spacing: 12) {
                // Book icon with palette color glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    accentColor.opacity(0.4),
                                    accentColor.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 15)

                    Image(systemName: "book.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, accentColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text("by \(book.author)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)

            // Centered pills
            VStack(spacing: 10) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    BookSuggestionPill(
                        text: suggestion,
                        accentColor: accentColor,
                        delay: Double(index) * 0.08 + 0.15
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

// MARK: - Book Suggestion Pill

/// Minimal pill with liquid glass, tinted with book's accent color
private struct BookSuggestionPill: View {
    let text: String
    let accentColor: Color
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
                .glassEffect(.regular.interactive().tint(accentColor), in: .capsule)
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

// MARK: - Preview

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

        BookSpecificEmptyState(
            book: Book(
                id: "preview-lotr",
                title: "The Lord of the Rings",
                author: "J.R.R. Tolkien",
                isbn: nil
            ),
            colorPalette: nil,
            onSuggestionTap: { suggestion in
                print("Tapped: \(suggestion)")
            }
        )
    }
    .preferredColorScheme(.dark)
}
