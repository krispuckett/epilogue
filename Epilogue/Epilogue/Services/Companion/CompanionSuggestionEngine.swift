import Foundation
import SwiftUI

// MARK: - Companion Suggestion Engine
/// Bridges the Reading Companion system with the existing ambient mode UI.
/// Generates contextual suggestions that appear as tappable pills.

@MainActor
@Observable
final class CompanionSuggestionEngine {
    static let shared = CompanionSuggestionEngine()

    // Dependencies
    private let companion = ReadingCompanion.shared
    private let bookIntelligence = BookIntelligence.shared
    private let promptLibrary = CompanionPromptLibrary.shared

    // State
    private(set) var activeSuggestions: [SuggestionPill] = []
    private(set) var isCompanionActive: Bool = false

    private init() {}

    // MARK: - Suggestion Pill

    struct SuggestionPill: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let icon: String?
        let style: PillStyle
        let action: PillAction
        let priority: Int

        static func == (lhs: SuggestionPill, rhs: SuggestionPill) -> Bool {
            lhs.id == rhs.id
        }
    }

    enum PillStyle {
        case companion      // Reading companion suggestions (warm, helpful)
        case question       // Questions about the book
        case action         // Actions like save quote, add note
        case celebration    // Progress milestones
        case standard       // Generic suggestions

        var backgroundColor: Color {
            switch self {
            case .companion:
                return Color.orange.opacity(0.15)
            case .question:
                return Color.blue.opacity(0.15)
            case .action:
                return Color.green.opacity(0.15)
            case .celebration:
                return Color.purple.opacity(0.15)
            case .standard:
                return Color.white.opacity(0.08)
            }
        }

        var borderColor: Color {
            switch self {
            case .companion:
                return Color.orange.opacity(0.3)
            case .question:
                return Color.blue.opacity(0.3)
            case .action:
                return Color.green.opacity(0.3)
            case .celebration:
                return Color.purple.opacity(0.3)
            case .standard:
                return Color.white.opacity(0.15)
            }
        }

        var iconColor: Color {
            switch self {
            case .companion:
                return Color.orange
            case .question:
                return Color.blue
            case .action:
                return Color.green
            case .celebration:
                return Color.purple
            case .standard:
                return Color.white.opacity(0.7)
            }
        }
    }

    enum PillAction {
        case companionSuggestion(ReadingCompanion.CompanionSuggestion)
        case askQuestion(prompt: String)
        case captureQuote
        case addNote
        case showProgress
        case custom(handler: () -> Void)
    }

    // MARK: - Main Interface

    /// Generate suggestions for the current reading context
    func generateSuggestions(
        for book: BookModel?,
        progress: Double,
        lastMessage: String?,
        isNewSession: Bool
    ) async -> [SuggestionPill] {
        var pills: [SuggestionPill] = []

        // If we have a book, activate the companion
        if let book = book {
            if isNewSession {
                await companion.onBookOpened(book)
                isCompanionActive = true
            } else {
                await companion.onProgressUpdated(progress)
            }

            // Get companion suggestions and convert to pills
            let companionPills = convertCompanionSuggestions()
            pills.append(contentsOf: companionPills)
        }

        // Add contextual question pills
        if let lastMessage = lastMessage {
            let questionPills = generateQuestionPills(basedOn: lastMessage, book: book)
            pills.append(contentsOf: questionPills)
        }

        // Add action pills if appropriate
        let actionPills = generateActionPills(book: book, progress: progress)
        pills.append(contentsOf: actionPills)

        // Sort by priority and limit to 4
        pills.sort { $0.priority > $1.priority }
        activeSuggestions = Array(pills.prefix(4))

        return activeSuggestions
    }

    /// Generate suggestions for generic ambient mode (no book context)
    func generateGenericSuggestions() -> [SuggestionPill] {
        isCompanionActive = false

        return [
            SuggestionPill(
                text: "What should I read next?",
                icon: "book.fill",
                style: .question,
                action: .askQuestion(prompt: "Based on my reading history, what should I read next?"),
                priority: 3
            ),
            SuggestionPill(
                text: "Help me find a book",
                icon: "magnifyingglass",
                style: .standard,
                action: .askQuestion(prompt: "I'm looking for a book recommendation. Can you help?"),
                priority: 2
            ),
            SuggestionPill(
                text: "Analyze my reading",
                icon: "chart.bar.fill",
                style: .standard,
                action: .askQuestion(prompt: "What patterns do you see in my reading history?"),
                priority: 1
            )
        ]
    }

    // MARK: - Conversion Methods

    private func convertCompanionSuggestions() -> [SuggestionPill] {
        return companion.pendingSuggestions.enumerated().map { index, suggestion in
            SuggestionPill(
                text: suggestion.headline,
                icon: iconForSuggestionType(suggestion.type),
                style: .companion,
                action: .companionSuggestion(suggestion),
                priority: 10 - index  // Higher priority for first suggestions
            )
        }
    }

    private func iconForSuggestionType(_ type: ReadingCompanion.SuggestionType) -> String {
        switch type {
        case .preparation:
            return "book.closed.fill"
        case .approach:
            return "signpost.right.fill"
        case .context:
            return "globe"
        case .characterGuide:
            return "person.2.fill"
        case .structureGuide:
            return "list.bullet.rectangle"
        case .checkIn:
            return "bubble.left.and.bubble.right.fill"
        case .encouragement:
            return "hands.clap.fill"
        case .clarification:
            return "questionmark.circle.fill"
        case .progressCelebration:
            return "star.fill"
        case .insight:
            return "lightbulb.fill"
        case .pacing:
            return "gauge.medium"
        }
    }

    // MARK: - Question Pills

    private func generateQuestionPills(basedOn lastMessage: String, book: BookModel?) -> [SuggestionPill] {
        var pills: [SuggestionPill] = []
        let messageLower = lastMessage.lowercased()

        // If we just discussed a character
        if messageLower.contains("who is") || messageLower.contains("character") {
            if let characterName = extractCharacterName(from: lastMessage) {
                pills.append(SuggestionPill(
                    text: "What happens to \(characterName)?",
                    icon: "person.fill.questionmark",
                    style: .question,
                    action: .askQuestion(prompt: "Without major spoilers, what's \(characterName)'s role in the story?"),
                    priority: 5
                ))
            }
        }

        // If we discussed a theme
        if messageLower.contains("theme") || messageLower.contains("meaning") || messageLower.contains("symbolism") {
            pills.append(SuggestionPill(
                text: "More examples of this theme",
                icon: "text.magnifyingglass",
                style: .question,
                action: .askQuestion(prompt: "Can you give me more examples of this theme from the book?"),
                priority: 4
            ))
        }

        // If confusion was expressed
        if messageLower.contains("confused") || messageLower.contains("don't understand") || messageLower.contains("lost") {
            pills.append(SuggestionPill(
                text: "Let me explain differently",
                icon: "arrow.triangle.2.circlepath",
                style: .question,
                action: .askQuestion(prompt: "Can you explain that in a different way?"),
                priority: 6
            ))
        }

        return pills
    }

    private func extractCharacterName(from message: String) -> String? {
        let patterns = ["who is ", "about ", "character "]
        let messageLower = message.lowercased()

        for pattern in patterns {
            if let range = messageLower.range(of: pattern) {
                let afterPattern = String(message[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "?", with: "")

                // Take first 2-3 words as name
                let words = afterPattern.split(separator: " ").prefix(3)
                if !words.isEmpty {
                    return words.map { $0.capitalized }.joined(separator: " ")
                }
            }
        }

        return nil
    }

    // MARK: - Action Pills

    private func generateActionPills(book: BookModel?, progress: Double) -> [SuggestionPill] {
        var pills: [SuggestionPill] = []

        // Always available actions
        pills.append(SuggestionPill(
            text: "Capture quote",
            icon: "quote.opening",
            style: .action,
            action: .captureQuote,
            priority: 2
        ))

        pills.append(SuggestionPill(
            text: "Add note",
            icon: "note.text",
            style: .action,
            action: .addNote,
            priority: 1
        ))

        return pills
    }

    // MARK: - Event Handlers

    /// Call when user taps a companion suggestion pill
    func onPillTapped(_ pill: SuggestionPill) async -> String? {
        switch pill.action {
        case .companionSuggestion(let suggestion):
            companion.onSuggestionEngaged(suggestion)
            return await companion.generateResponse(for: suggestion)

        case .askQuestion(let prompt):
            // Return the prompt for the caller to send to AI
            return prompt

        case .captureQuote, .addNote, .showProgress:
            // These are handled by the UI directly
            return nil

        case .custom(let handler):
            handler()
            return nil
        }
    }

    /// Call when user dismisses a suggestion
    func onPillDismissed(_ pill: SuggestionPill) {
        if case .companionSuggestion(let suggestion) = pill.action {
            companion.onSuggestionDismissed(suggestion)
        }
        activeSuggestions.removeAll { $0.id == pill.id }
    }

    /// Call when user asks a question manually
    func onUserQuestion(_ question: String) {
        companion.onUserQuestion(question)
    }

    /// Call when reading session ends
    func onSessionEnded() {
        companion.onSessionEnded()
        isCompanionActive = false
        activeSuggestions = []
    }
}

// MARK: - SwiftUI Pill View

struct CompanionPillView: View {
    let pill: CompanionSuggestionEngine.SuggestionPill
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if let icon = pill.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(pill.style.iconColor)
                }

                Text(pill.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(pill.style.backgroundColor)
            }
            .overlay {
                Capsule()
                    .strokeBorder(pill.style.borderColor, lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Companion Pills Container

struct CompanionPillsView: View {
    let pills: [CompanionSuggestionEngine.SuggestionPill]
    let onPillTap: (CompanionSuggestionEngine.SuggestionPill) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pills) { pill in
                    CompanionPillView(pill: pill) {
                        onPillTap(pill)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 16)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pills.count)
    }
}

// MARK: - Preview

#Preview("Companion Pills") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            CompanionPillsView(pills: [
                CompanionSuggestionEngine.SuggestionPill(
                    text: "Want a spoiler-free intro?",
                    icon: "book.closed.fill",
                    style: .companion,
                    action: .askQuestion(prompt: ""),
                    priority: 3
                ),
                CompanionSuggestionEngine.SuggestionPill(
                    text: "How should I approach this?",
                    icon: "signpost.right.fill",
                    style: .companion,
                    action: .askQuestion(prompt: ""),
                    priority: 2
                ),
                CompanionSuggestionEngine.SuggestionPill(
                    text: "Capture quote",
                    icon: "quote.opening",
                    style: .action,
                    action: .captureQuote,
                    priority: 1
                )
            ], onPillTap: { _ in })
        }
    }
    .preferredColorScheme(.dark)
}
