import SwiftUI

// MARK: - Companion-Aware Empty State
/// Enhanced book-specific empty state powered by the Reading Companion.
/// Shows intelligent, proactive suggestions based on book analysis.

struct CompanionAwareEmptyState: View {
    let book: Book
    let colorPalette: ColorPalette?
    let currentPage: Int?
    let hasNotes: Bool
    let hasQuotes: Bool
    let onSuggestionTap: (String) -> Void
    let onCaptureQuote: () -> Void
    let onCompanionResponse: (String) -> Void  // For AI responses

    @State private var isVisible = false
    @State private var companionSuggestions: [CompanionSuggestionEngine.SuggestionPill] = []
    @State private var isCompanionReady = false
    @State private var isGeneratingResponse = false

    private let companion = ReadingCompanion.shared
    private let suggestionEngine = CompanionSuggestionEngine.shared

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Companion badge for intimidating books
            if let profile = companion.activeBookProfile, profile.needsPreparation {
                companionBadge(for: profile)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : -10)
            }

            // Reading Companion suggestions (proactive, smart)
            if isCompanionReady && !companionSuggestions.isEmpty {
                companionSuggestionsView
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 10)
            }

            // Standard book suggestions (always available)
            standardSuggestionsView
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

    // MARK: - Companion Badge

    @ViewBuilder
    private func companionBadge(for profile: BookIntelligence.BookProfile) -> some View {
        let mode = profile.companionMode

        HStack(spacing: 8) {
            Image(systemName: iconForMode(mode))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colorForMode(mode))

            Text(titleForMode(mode, book: profile.book))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(colorForMode(mode).opacity(0.15))
        }
        .overlay {
            Capsule()
                .strokeBorder(colorForMode(mode).opacity(0.3), lineWidth: 1)
        }
        .padding(.bottom, 8)
    }

    private func iconForMode(_ mode: BookIntelligence.CompanionMode) -> String {
        switch mode {
        case .guide: return "map.fill"
        case .coach: return "figure.walk"
        case .companion: return "bubble.left.and.bubble.right.fill"
        case .observer: return "eye.fill"
        }
    }

    private func colorForMode(_ mode: BookIntelligence.CompanionMode) -> Color {
        switch mode {
        case .guide: return .orange
        case .coach: return .blue
        case .companion: return .green
        case .observer: return .gray
        }
    }

    private func titleForMode(_ mode: BookIntelligence.CompanionMode, book: BookModel) -> String {
        switch mode {
        case .guide:
            return "I'm here to guide you"
        case .coach:
            return "I can help if you need"
        case .companion:
            return "Reading companion ready"
        case .observer:
            return "Enjoying \(book.title)"
        }
    }

    // MARK: - Companion Suggestions View

    private var companionSuggestionsView: some View {
        VStack(spacing: 10) {
            ForEach(Array(companionSuggestions.enumerated()), id: \.element.id) { index, pill in
                CompanionSuggestionPillButton(
                    pill: pill,
                    delay: Double(index) * 0.08,
                    isLoading: isGeneratingResponse
                ) {
                    Task {
                        await handleCompanionPillTap(pill)
                    }
                }
            }
        }
    }

    // MARK: - Standard Suggestions View

    private var standardSuggestions: [StandardSuggestion] {
        var items: [StandardSuggestion] = []

        // Capture quote is always available
        items.append(StandardSuggestion(
            text: "Capture a quote",
            icon: "quote.opening",
            isSpecialAction: true
        ))

        // Add note
        items.append(StandardSuggestion(
            text: "Add a thought",
            icon: "note.text",
            isSpecialAction: false
        ))

        // Only show if companion isn't providing similar suggestions
        if companionSuggestions.isEmpty {
            // Theme exploration
            items.append(StandardSuggestion(
                text: "What are the main themes?",
                icon: nil,
                isSpecialAction: false
            ))

            // Author context
            let authorLastName = book.author.components(separatedBy: " ").last ?? "the author"
            items.append(StandardSuggestion(
                text: "Tell me about \(authorLastName)",
                icon: nil,
                isSpecialAction: false
            ))
        }

        return Array(items.prefix(3))
    }

    private var standardSuggestionsView: some View {
        HStack(spacing: 10) {
            ForEach(Array(standardSuggestions.enumerated()), id: \.element.text) { index, suggestion in
                StandardPillButton(
                    text: suggestion.text,
                    icon: suggestion.icon,
                    delay: Double(index) * 0.06 + 0.3
                ) {
                    SensoryFeedback.light()
                    if suggestion.isSpecialAction {
                        if suggestion.text.contains("quote") {
                            onCaptureQuote()
                        }
                    } else {
                        onSuggestionTap(suggestion.text)
                    }
                }
            }
        }
    }

    // MARK: - Companion Activation

    private func activateCompanion() async {
        // Convert Book to BookModel for the companion
        let bookModel = BookModel(from: book)

        // Calculate progress
        let progress: Double
        if let currentPage = currentPage, let totalPages = book.pageCount, totalPages > 0 {
            progress = Double(currentPage) / Double(totalPages)
        } else {
            progress = 0
        }

        // Generate suggestions
        companionSuggestions = await suggestionEngine.generateSuggestions(
            for: bookModel,
            progress: progress,
            lastMessage: nil,
            isNewSession: true
        ).filter { pill in
            // Filter to only companion-style suggestions (not actions)
            if case .companionSuggestion = pill.action {
                return true
            }
            return false
        }

        isCompanionReady = true

        #if DEBUG
        print("📚 Companion activated with \(companionSuggestions.count) proactive suggestions")
        #endif
    }

    private func handleCompanionPillTap(_ pill: CompanionSuggestionEngine.SuggestionPill) async {
        SensoryFeedback.light()
        isGeneratingResponse = true

        if let response = await suggestionEngine.onPillTapped(pill) {
            onCompanionResponse(response)
        }

        // Refresh suggestions after interaction
        let bookModel = BookModel(from: book)
        let progress = calculateProgress()

        companionSuggestions = await suggestionEngine.generateSuggestions(
            for: bookModel,
            progress: progress,
            lastMessage: nil,
            isNewSession: false
        ).filter { pill in
            if case .companionSuggestion = pill.action {
                return true
            }
            return false
        }

        isGeneratingResponse = false
    }

    private func calculateProgress() -> Double {
        if let currentPage = currentPage, let totalPages = book.pageCount, totalPages > 0 {
            return Double(currentPage) / Double(totalPages)
        }
        return 0
    }
}

// MARK: - Supporting Views

private struct StandardSuggestion: Equatable {
    let text: String
    let icon: String?
    var isSpecialAction: Bool = false
}

private struct CompanionSuggestionPillButton: View {
    let pill: CompanionSuggestionEngine.SuggestionPill
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
                        .scaleEffect(0.8)
                        .tint(.white.opacity(0.7))
                } else if let icon = pill.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(pill.style.iconColor)
                }

                Text(pill.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(pill.style.backgroundColor)
            }
            .overlay {
                Capsule()
                    .strokeBorder(pill.style.borderColor, lineWidth: 1)
            }
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

private struct StandardPillButton: View {
    let text: String
    let icon: String?
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
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.thin.interactive(), in: .capsule)
            .scaleEffect(isPressed ? 0.95 : 1)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
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
                isbn: nil
            ),
            colorPalette: nil,
            currentPage: 0,
            hasNotes: false,
            hasQuotes: false,
            onSuggestionTap: { print("Suggestion: \($0)") },
            onCaptureQuote: { print("Capture quote") },
            onCompanionResponse: { print("Response: \($0)") }
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Companion Empty State - Regular Book") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        CompanionAwareEmptyState(
            book: Book(
                id: "preview-normal",
                title: "Project Hail Mary",
                author: "Andy Weir",
                isbn: nil
            ),
            colorPalette: nil,
            currentPage: 150,
            hasNotes: true,
            hasQuotes: false,
            onSuggestionTap: { print("Suggestion: \($0)") },
            onCaptureQuote: { print("Capture quote") },
            onCompanionResponse: { print("Response: \($0)") }
        )
    }
    .preferredColorScheme(.dark)
}
