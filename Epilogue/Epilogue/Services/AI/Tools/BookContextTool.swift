import Foundation
import SwiftData

// MARK: - Book Context Result
/// Codable snapshot of a book's enrichment metadata from SwiftData.
/// Used to inject grounded knowledge into AI system prompts.
struct BookContextResult: Codable {
    let title: String
    let author: String
    let synopsis: String?
    let characters: [String]
    let themes: [String]
    let setting: String?
    let tone: [String]
    let literaryStyle: String?
    let currentPage: Int
    let totalPages: Int?
    let seriesName: String?
    let seriesOrder: Int?
    let totalBooksInSeries: Int?
    let readingStatus: String

    /// Whether the book has been enriched with AI-generated metadata
    var isEnriched: Bool {
        synopsis != nil || !characters.isEmpty || !themes.isEmpty
    }

    /// Reading progress as a percentage (0-100), or nil if page count unknown
    var progressPercent: Int? {
        guard let total = totalPages, total > 0 else { return nil }
        return min(100, (currentPage * 100) / total)
    }
}

// MARK: - Book Context Provider
/// Extracts book context from a SwiftData BookModel for AI grounding.
/// This is the primary tool the AI uses to understand what the user is reading.
@MainActor
class BookContextProvider {
    static let shared = BookContextProvider()

    private init() {}

    /// Build a complete context snapshot from a BookModel
    func getContext(for book: BookModel) -> BookContextResult {
        BookContextResult(
            title: book.title,
            author: book.author,
            synopsis: book.smartSynopsis,
            characters: book.majorCharacters ?? [],
            themes: book.keyThemes ?? [],
            setting: book.setting,
            tone: book.tone ?? [],
            literaryStyle: book.literaryStyle,
            currentPage: book.currentPage,
            totalPages: book.pageCount,
            seriesName: book.seriesName,
            seriesOrder: book.seriesOrder,
            totalBooksInSeries: book.totalBooksInSeries,
            readingStatus: book.readingStatus
        )
    }

    /// Build a concise context string suitable for prompt injection
    func buildContextString(for book: BookModel) -> String {
        let ctx = getContext(for: book)
        var parts: [String] = []

        parts.append("Title: \(ctx.title)")
        parts.append("Author: \(ctx.author)")

        if let synopsis = ctx.synopsis {
            parts.append("Synopsis: \(synopsis)")
        }

        if !ctx.characters.isEmpty {
            parts.append("Key characters: \(ctx.characters.joined(separator: ", "))")
        }

        if !ctx.themes.isEmpty {
            parts.append("Themes: \(ctx.themes.joined(separator: ", "))")
        }

        if let setting = ctx.setting {
            parts.append("Setting: \(setting)")
        }

        if !ctx.tone.isEmpty {
            parts.append("Tone: \(ctx.tone.joined(separator: ", "))")
        }

        if let style = ctx.literaryStyle {
            parts.append("Literary style: \(style)")
        }

        if let series = ctx.seriesName, let order = ctx.seriesOrder {
            var seriesStr = "Series: \(series), Book \(order)"
            if let total = ctx.totalBooksInSeries {
                seriesStr += " of \(total)"
            }
            parts.append(seriesStr)
        }

        return parts.joined(separator: "\n")
    }
}
