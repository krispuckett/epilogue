import Foundation
import SwiftData

// MARK: - Reading Progress Result
/// Snapshot of reading progress and pace for a book.
struct ReadingProgressResult {
    let currentPage: Int
    let totalPages: Int?
    let progressPercent: Int?
    let readingStatus: String
    let daysSinceAdded: Int
    let hasActiveSession: Bool

    /// Estimate pages remaining
    var pagesRemaining: Int? {
        guard let total = totalPages else { return nil }
        return max(0, total - currentPage)
    }
}

// MARK: - Reading Progress Provider
/// Provides reading progress data from SwiftData for AI context.
@MainActor
class ReadingProgressProvider {
    static let shared = ReadingProgressProvider()

    private init() {}

    /// Get reading progress for a book
    func getProgress(for book: BookModel) -> ReadingProgressResult {
        let daysSinceAdded = Calendar.current.dateComponents(
            [.day],
            from: book.dateAdded,
            to: Date()
        ).day ?? 0

        let progressPercent: Int?
        if let total = book.pageCount, total > 0 {
            progressPercent = min(100, (book.currentPage * 100) / total)
        } else {
            progressPercent = nil
        }

        // Check if there's an active reading session
        let hasActiveSession = (book.readingSessions ?? []).contains { session in
            session.endDate == nil
        }

        return ReadingProgressResult(
            currentPage: book.currentPage,
            totalPages: book.pageCount,
            progressPercent: progressPercent,
            readingStatus: book.readingStatus,
            daysSinceAdded: daysSinceAdded,
            hasActiveSession: hasActiveSession
        )
    }

    /// Build a prompt-friendly progress string
    func buildProgressContextString(for book: BookModel) -> String {
        let progress = getProgress(for: book)
        var parts: [String] = []

        parts.append("Reading status: \(progress.readingStatus)")
        parts.append("Current page: \(progress.currentPage)")

        if let total = progress.totalPages {
            parts.append("Total pages: \(total)")
        }

        if let percent = progress.progressPercent {
            parts.append("Progress: \(percent)%")
        }

        if let remaining = progress.pagesRemaining {
            parts.append("Pages remaining: \(remaining)")
        }

        if progress.daysSinceAdded > 0 {
            parts.append("In library for \(progress.daysSinceAdded) days")
        }

        return parts.joined(separator: "\n")
    }
}
