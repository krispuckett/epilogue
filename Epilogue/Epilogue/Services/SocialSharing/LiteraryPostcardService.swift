import Foundation
import SwiftUI
import SwiftData
import OSLog

// MARK: - Literary Postcard Service
/// Detects shareable moments and generates beautiful literary postcards.
/// Moments include: book completion, great sessions, favorited quotes, milestones.

@MainActor
@Observable
final class LiteraryPostcardService {
    static let shared = LiteraryPostcardService()

    private let logger = Logger(subsystem: "com.epilogue", category: "LiteraryPostcard")

    // MARK: - Shareable Moment Types

    enum ShareableMoment: Equatable {
        case bookCompleted(book: BookModel)
        case sessionReflection(reflection: String, bookTitle: String, bookAuthor: String)
        case favoriteQuote(quote: CapturedQuote)
        case readingMilestone(book: BookModel, milestone: ReadingMilestone)
        case thematicConnection(theme: String, books: [String])

        var momentType: String {
            switch self {
            case .bookCompleted: return "completion"
            case .sessionReflection: return "reflection"
            case .favoriteQuote: return "quote"
            case .readingMilestone: return "milestone"
            case .thematicConnection: return "connection"
            }
        }
    }

    enum ReadingMilestone: String {
        case quarterway = "25%"
        case halfway = "50%"
        case threequarters = "75%"
        case ninetyPercent = "90%"

        var celebrationText: String {
            switch self {
            case .quarterway: return "A quarter of the way through"
            case .halfway: return "Halfway there"
            case .threequarters: return "The home stretch"
            case .ninetyPercent: return "Almost finished"
            }
        }
    }

    private init() {}

    // MARK: - Moment Detection

    /// Check if a book completion should trigger a shareable moment
    func detectBookCompletionMoment(book: BookModel) -> ShareableMoment? {
        guard book.readingStatus == ReadingStatus.read.rawValue else { return nil }
        return .bookCompleted(book: book)
    }

    /// Check for reading milestones
    func detectMilestone(book: BookModel, previousProgress: Double, newProgress: Double) -> ShareableMoment? {
        guard let pageCount = book.pageCount, pageCount > 0 else { return nil }

        let milestones: [(Double, ReadingMilestone)] = [
            (0.25, .quarterway),
            (0.50, .halfway),
            (0.75, .threequarters),
            (0.90, .ninetyPercent)
        ]

        for (threshold, milestone) in milestones {
            if previousProgress < threshold && newProgress >= threshold {
                return .readingMilestone(book: book, milestone: milestone)
            }
        }

        return nil
    }

    /// Detect if a session reflection is shareable (high engagement)
    func detectShareableSession(
        reflection: String,
        questionCount: Int,
        duration: TimeInterval,
        book: BookModel?
    ) -> ShareableMoment? {
        // Only suggest sharing if it was a meaningful session
        guard questionCount >= 3 || duration > 600 else { return nil } // 10+ min or 3+ questions
        guard !reflection.isEmpty else { return nil }

        return .sessionReflection(
            reflection: reflection,
            bookTitle: book?.title ?? "Reading Session",
            bookAuthor: book?.author ?? ""
        )
    }

    // MARK: - Postcard Generation

    /// Generate a postcard for a book completion
    func generateCompletionPostcard(book: BookModel) async -> PostcardContent {
        let systemPrompt = """
        Generate a brief, literary reflection (2-3 sentences max) on finishing a book.
        Be warm and genuine, not generic. Capture what lingers after the final page.
        No emojis. No cliches like "what a journey" or "page-turner."
        """

        let userPrompt = """
        I just finished "\(book.title)" by \(book.author).
        \(book.smartSynopsis ?? "")
        Themes: \(book.keyThemes?.joined(separator: ", ") ?? "")

        Write a brief reflection on finishing this book that could be shared.
        """

        do {
            let reflection = try await ClaudeService.shared.subscriberChat(
                message: userPrompt,
                systemPrompt: systemPrompt,
                maxTokens: 150
            )

            return PostcardContent(
                headline: "Finished",
                bookTitle: book.title,
                bookAuthor: book.author,
                bodyText: reflection,
                coverImageURL: book.coverImageURL,
                momentType: .bookCompleted(book: book)
            )
        } catch {
            logger.error("Failed to generate completion postcard: \(error)")
            return PostcardContent(
                headline: "Finished",
                bookTitle: book.title,
                bookAuthor: book.author,
                bodyText: "Another story closes, another world lingers.",
                coverImageURL: book.coverImageURL,
                momentType: .bookCompleted(book: book)
            )
        }
    }

    /// Generate a postcard for a session reflection
    func generateSessionPostcard(
        reflection: String,
        bookTitle: String,
        bookAuthor: String,
        coverImageURL: String?
    ) -> PostcardContent {
        // Trim reflection if too long
        let trimmedReflection = reflection.count > 280
            ? String(reflection.prefix(277)) + "..."
            : reflection

        return PostcardContent(
            headline: "Reading Tonight",
            bookTitle: bookTitle,
            bookAuthor: bookAuthor,
            bodyText: trimmedReflection,
            coverImageURL: coverImageURL,
            momentType: .sessionReflection(reflection: reflection, bookTitle: bookTitle, bookAuthor: bookAuthor)
        )
    }

    /// Generate a postcard for a milestone
    func generateMilestonePostcard(book: BookModel, milestone: ReadingMilestone) -> PostcardContent {
        let bodyText: String
        switch milestone {
        case .quarterway:
            bodyText = "The world is opening up. Characters are taking shape. I'm in."
        case .halfway:
            bodyText = "Halfway through and the story has its hooks in me."
        case .threequarters:
            bodyText = "Everything is building toward something. I can feel it."
        case .ninetyPercent:
            bodyText = "Savoring these final pages."
        }

        return PostcardContent(
            headline: milestone.celebrationText,
            bookTitle: book.title,
            bookAuthor: book.author,
            bodyText: bodyText,
            coverImageURL: book.coverImageURL,
            momentType: .readingMilestone(book: book, milestone: milestone)
        )
    }
}

// MARK: - Postcard Content Model

struct PostcardContent: Identifiable {
    let id = UUID()
    let headline: String
    let bookTitle: String
    let bookAuthor: String
    let bodyText: String
    let coverImageURL: String?
    let momentType: LiteraryPostcardService.ShareableMoment
    let createdAt = Date()

    var attributionText: String {
        "\(bookTitle) by \(bookAuthor)"
    }
}

// MARK: - Postcard Themes

enum PostcardTheme: String, CaseIterable, Identifiable {
    case warm = "Warm"
    case twilight = "Twilight"
    case forest = "Forest"
    case ocean = "Ocean"
    case midnight = "Midnight"
    case rose = "Rose"

    var id: String { rawValue }

    var gradientColors: [Color] {
        switch self {
        case .warm:
            return [
                Color(red: 0.95, green: 0.85, blue: 0.75),
                Color(red: 0.85, green: 0.65, blue: 0.55)
            ]
        case .twilight:
            return [
                Color(red: 0.55, green: 0.45, blue: 0.75),
                Color(red: 0.35, green: 0.25, blue: 0.55)
            ]
        case .forest:
            return [
                Color(red: 0.35, green: 0.55, blue: 0.45),
                Color(red: 0.2, green: 0.4, blue: 0.35)
            ]
        case .ocean:
            return [
                Color(red: 0.35, green: 0.55, blue: 0.75),
                Color(red: 0.2, green: 0.35, blue: 0.55)
            ]
        case .midnight:
            return [
                Color(red: 0.15, green: 0.15, blue: 0.25),
                Color(red: 0.08, green: 0.08, blue: 0.15)
            ]
        case .rose:
            return [
                Color(red: 0.85, green: 0.65, blue: 0.7),
                Color(red: 0.65, green: 0.45, blue: 0.55)
            ]
        }
    }

    var textColor: Color {
        switch self {
        case .warm, .rose:
            return Color(red: 0.15, green: 0.12, blue: 0.1)
        case .twilight, .forest, .ocean, .midnight:
            return Color(red: 0.98, green: 0.97, blue: 0.96)
        }
    }

    var secondaryTextColor: Color {
        textColor.opacity(0.7)
    }
}
