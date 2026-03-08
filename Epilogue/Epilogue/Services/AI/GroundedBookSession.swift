import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.epilogue", category: "GroundedBookSession")

// MARK: - Grounded Book Session
/// Bridges SwiftData book context providers with the AI system.
/// Builds rich, grounded system prompts from the user's actual library data
/// so the AI can answer questions about ANY book — not just hardcoded ones.
@MainActor
class GroundedBookSession {
    static let shared = GroundedBookSession()

    private init() {}

    // MARK: - Build Grounded System Prompt

    /// Build a comprehensive system prompt grounded in the user's actual SwiftData.
    /// This replaces hardcoded book knowledge with real enrichment data.
    ///
    /// - Parameters:
    ///   - book: The BookModel the user is currently reading
    ///   - modelContext: SwiftData context for cross-book queries
    /// - Returns: A prompt string to inject into the AI's instructions
    func buildGroundedPrompt(for book: BookModel, modelContext: ModelContext? = nil) -> String {
        var sections: [String] = []

        // 1. Book metadata from enrichment
        let bookContext = BookContextProvider.shared.buildContextString(for: book)
        if !bookContext.isEmpty {
            sections.append("BOOK INFORMATION (from user's library):\n\(bookContext)")
        }

        // 2. Spoiler guard based on reading progress
        let progress = ReadingProgressProvider.shared.getProgress(for: book)
        sections.append(buildSpoilerGuard(for: book, progress: progress))

        // 3. User's own captured content (quotes, notes, questions)
        let notesContext = UserNotesProvider.shared.buildNotesContextString(
            for: book,
            maxQuotes: 5,
            maxNotes: 5,
            maxQuestions: 3
        )
        if !notesContext.isEmpty {
            sections.append("READER'S OWN CONTENT:\n\(notesContext)")
        }

        // 4. Reading progress context
        let progressContext = ReadingProgressProvider.shared.buildProgressContextString(for: book)
        if !progressContext.isEmpty {
            sections.append("READING PROGRESS:\n\(progressContext)")
        }

        let prompt = sections.joined(separator: "\n\n")

        #if DEBUG
        let enrichmentStatus = book.isEnriched ? "enriched" : "NOT enriched"
        let notesCount = UserNotesProvider.shared.getNotes(for: book).totalItems
        logger.info("Built grounded prompt for '\(book.title)' (\(enrichmentStatus), \(notesCount) user items, \(prompt.count) chars)")
        #endif

        return prompt
    }

    // MARK: - Build Grounded Instructions

    /// Build complete AI instructions that combine grounded context with behavior rules.
    /// This is designed to be injected into the `setupSession()` instructions in SmartEpilogueAI.
    ///
    /// - Parameters:
    ///   - book: The BookModel the user is currently reading
    ///   - modelContext: SwiftData context for cross-book queries
    /// - Returns: Instructions string for the AI session
    func buildGroundedInstructions(for book: BookModel, modelContext: ModelContext? = nil) -> String {
        let groundedContext = buildGroundedPrompt(for: book, modelContext: modelContext)

        return """
        You are Epilogue's AI reading companion currently discussing '\(book.title)' by \(book.author).

        \(groundedContext)

        IMPORTANT: You are discussing THIS SPECIFIC BOOK. When asked any question about:
        - "the main character" or "protagonist" - answer about \(book.title)'s main character
        - "the plot" or "story" - answer about \(book.title)'s plot
        - "the ending" - answer about \(book.title)'s ending
        - "the theme" - answer about \(book.title)'s themes
        - Any character names - assume they're from \(book.title)
        """
    }

    // MARK: - Spoiler Guard

    /// Build spoiler protection instructions based on reading progress and series info.
    private func buildSpoilerGuard(for book: BookModel, progress: ReadingProgressResult) -> String {
        var guard_parts: [String] = []

        // Page-based spoiler guard
        guard_parts.append("SPOILER PROTECTION:")
        guard_parts.append("The reader is on page \(progress.currentPage)\(progress.totalPages.map { " of \($0)" } ?? "").")

        if let percent = progress.progressPercent {
            if percent < 25 {
                guard_parts.append("They are EARLY in the book. Be very careful about revealing plot developments.")
            } else if percent < 75 {
                guard_parts.append("They are partway through. Do not reveal events beyond their current position.")
            } else {
                guard_parts.append("They are near the end but may not have finished. Avoid revealing the conclusion.")
            }
        }

        guard_parts.append("Do NOT reveal any plot details, character fates, or events beyond the reader's current page.")

        // Series-based spoiler guard
        if let seriesName = book.seriesName, let order = book.seriesOrder {
            guard_parts.append("")
            guard_parts.append("SERIES SPOILER PROTECTION:")
            guard_parts.append("This is Book \(order) of the \"\(seriesName)\" series.")
            guard_parts.append("You may discuss events from Books 1-\(order) freely.")
            if order > 1 {
                guard_parts.append("Previous books in the series are safe to reference.")
            }
            guard_parts.append("NEVER reveal plot points, character fates, or twists from Book \(order + 1) or later.")
        }

        return guard_parts.joined(separator: "\n")
    }

    // MARK: - Enrichment Status Check

    /// Check if a book has sufficient enrichment data for grounded responses.
    /// When enrichment is missing, the AI will fall back to its general knowledge.
    func enrichmentStatus(for book: BookModel) -> EnrichmentStatus {
        if book.smartSynopsis != nil &&
           !(book.majorCharacters ?? []).isEmpty &&
           !(book.keyThemes ?? []).isEmpty {
            return .full
        } else if book.smartSynopsis != nil || !(book.keyThemes ?? []).isEmpty {
            return .partial
        } else {
            return .none
        }
    }

    enum EnrichmentStatus {
        case full     // Synopsis + characters + themes all present
        case partial  // Some enrichment data available
        case none     // No enrichment - will rely on AI's general knowledge

        var description: String {
            switch self {
            case .full: return "Fully enriched"
            case .partial: return "Partially enriched"
            case .none: return "Not enriched"
            }
        }
    }
}
