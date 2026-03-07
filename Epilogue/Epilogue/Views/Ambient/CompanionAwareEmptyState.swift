import SwiftUI

// MARK: - Companion-Aware Empty State
/// Enhanced book-specific empty state powered by the Reading Companion.
/// Uses clean liquid glass styling that matches the ambient mode design.

struct CompanionAwareEmptyState: View {
    let book: Book
    let colorPalette: ColorPalette?
    let currentPage: Int?
    let hasNotes: Bool
    let hasQuotes: Bool
    let onSuggestionTap: (String) -> Void
    let onCaptureQuote: () -> Void
    let onCompanionResponse: (String, String) -> Void  // (question, response)

    @State private var isVisible = false
    @State private var companionSuggestions: [String] = []
    @State private var isCompanionReady = false
    @State private var isGeneratingResponse = false
    @State private var loadingPillText: String? = nil

    private let companion = ReadingCompanion.shared

    /// Convert Book to BookModel for the companion system
    private var bookModel: BookModel {
        BookModel(
            id: book.id,
            title: book.title,
            author: book.author,
            publishedYear: book.publishedYear,
            coverImageURL: book.coverImageURL,
            isbn: book.isbn,
            description: book.description,
            pageCount: book.pageCount
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // All suggestions in clean glass pills
            VStack(spacing: 10) {
                // Companion suggestions (proactive, intelligent)
                ForEach(Array(companionSuggestions.enumerated()), id: \.element) { index, suggestion in
                    CleanGlassPill(
                        text: suggestion,
                        delay: Double(index) * 0.08,
                        isLoading: loadingPillText == suggestion
                    ) {
                        Task {
                            await handleCompanionSuggestionTap(suggestion)
                        }
                    }
                }

                // Standard suggestions
                ForEach(Array(standardSuggestions.enumerated()), id: \.element) { index, suggestion in
                    CleanGlassPill(
                        text: suggestion,
                        delay: Double(companionSuggestions.count + index) * 0.08 + 0.1,
                        isLoading: false
                    ) {
                        SensoryFeedback.light()
                        if suggestion.contains("quote") {
                            onCaptureQuote()
                        } else {
                            onSuggestionTap(suggestion)
                        }
                    }
                }
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)

            Spacer()
            Spacer()
        }
        .task {
            await activateCompanion()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }

    // MARK: - Suggestions

    private var standardSuggestions: [String] {
        var items: [String] = []

        // Capture quote is always available
        items.append("Capture a quote")

        // Only show generic suggestions if companion isn't providing them
        if companionSuggestions.isEmpty {
            items.append("What are the main themes?")

            let authorLastName = book.author.components(separatedBy: " ").last ?? "the author"
            items.append("Tell me about \(authorLastName)")
        }

        return items
    }

    // MARK: - Companion Activation

    private func activateCompanion() async {
        // Calculate progress
        let progress: Double
        if let currentPage = currentPage, let totalPages = book.pageCount, totalPages > 0 {
            progress = Double(currentPage) / Double(totalPages)
        } else {
            progress = 0
        }

        // Activate the companion for this book
        await companion.onBookOpened(bookModel)

        // Get suggestions based on book profile
        guard let profile = companion.activeBookProfile else {
            isCompanionReady = true
            return
        }

        // Build intelligent suggestions based on profile
        var suggestions: [String] = []

        // For intimidating books, offer proactive help
        if profile.needsPreparation {
            if progress < 0.05 {
                suggestions.append("Want a spoiler-free intro?")
                suggestions.append("How should I approach this?")

                // Add context if needed
                let essentialContext = profile.contextNeeds.filter { $0.importance == .essential }
                if !essentialContext.isEmpty {
                    suggestions.append("Give me some context")
                }
            } else if progress < 0.2 {
                suggestions.append("How's it going so far?")
            }
        }

        // Character help for complex casts
        let hasCharacterChallenge = profile.challenges.contains {
            $0.type == .largeCharacterCast || $0.type == .unfamiliarNames
        }
        if hasCharacterChallenge && progress < 0.25 {
            suggestions.append("Who should I keep track of?")
        }

        companionSuggestions = Array(suggestions.prefix(4))
        isCompanionReady = true

        #if DEBUG
        print("📚 Companion ready - \(companionSuggestions.count) suggestions for \(book.title)")
        #endif
    }

    private func handleCompanionSuggestionTap(_ suggestion: String) async {
        SensoryFeedback.light()
        loadingPillText = suggestion
        isGeneratingResponse = true

        // Generate AI response based on the suggestion
        let response = await companion.generateResponse(for: suggestionToCompanionSuggestion(suggestion))
        onCompanionResponse(suggestion, response)

        loadingPillText = nil
        isGeneratingResponse = false
    }

    private func suggestionToCompanionSuggestion(_ text: String) -> ReadingCompanion.CompanionSuggestion {
        // Map suggestion text to appropriate type
        let type: ReadingCompanion.SuggestionType
        let fullPrompt: String

        if text.contains("spoiler-free intro") {
            type = .preparation
            fullPrompt = "Give me a spoiler-free introduction to this book."
        } else if text.contains("approach") {
            type = .approach
            fullPrompt = "How should I approach reading this book?"
        } else if text.contains("context") {
            type = .context
            fullPrompt = "What historical or cultural context should I know?"
        } else if text.contains("track of") || text.contains("characters") {
            type = .characterGuide
            fullPrompt = "Who are the key characters I should track?"
        } else if text.contains("How's it going") {
            type = .checkIn
            fullPrompt = "I'm early in the book - any encouragement or tips?"
        } else {
            type = .clarification
            fullPrompt = text
        }

        return ReadingCompanion.CompanionSuggestion(
            type: type,
            headline: text,
            fullPrompt: fullPrompt,
            priority: .medium,
            context: ReadingCompanion.SuggestionContext(
                triggerReason: "User tapped suggestion",
                spoilerSafe: true,
                requiresAI: true
            ),
            expiresAfterProgress: nil
        )
    }
}

// MARK: - Clean Glass Pill

/// Minimal centered pill button with pure liquid glass - no colors
private struct CleanGlassPill: View {
    let text: String
    let delay: Double
    let isLoading: Bool
    let action: () -> Void

    @State private var isVisible = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white.opacity(0.7))
                }

                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(isLoading ? 0.6 : 0.9))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: .capsule)
            .scaleEffect(isPressed ? 0.96 : 1)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Companion Empty State - Intimidating Book") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        CompanionAwareEmptyState(
            book: Book(
                id: "preview-odyssey",
                title: "The Odyssey",
                author: "Homer",
                pageCount: 500
            ),
            colorPalette: nil,
            currentPage: 0,
            hasNotes: false,
            hasQuotes: false,
            onSuggestionTap: { print("Suggestion: \($0)") },
            onCaptureQuote: { print("Capture quote") },
            onCompanionResponse: { q, r in print("Q: \(q), R: \(r)") }
        )
    }
    .preferredColorScheme(.dark)
}
