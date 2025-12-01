import Foundation

/// Filters enrichment data to prevent spoilers based on reading progress
class SpoilerSafeFilter {
    private let enrichment: BookEnrichment
    private let mode: UpdateMode

    init(enrichment: BookEnrichment, mode: UpdateMode = .conservative) {
        self.enrichment = enrichment
        self.mode = mode
    }

    // MARK: - Safe Boundary Calculation

    /// Calculate the safe chapter boundary based on progress and mode
    func safeBoundary(for progress: ReadingProgress) -> Int {
        let stated = progress.currentChapter ?? inferChapter(progress)

        switch mode {
        case .conservative:
            // 1 chapter behind for safety
            return max(1, stated - 1)
        case .current:
            return stated
        case .manual:
            // For manual mode, use stated progress
            return stated
        }
    }

    /// Infer chapter from page or percentage
    private func inferChapter(_ progress: ReadingProgress) -> Int {
        // Try page-based inference first
        if let currentPage = progress.currentPage {
            for chapter in enrichment.chapters {
                if let pageRange = chapter.approximatePages,
                   currentPage >= pageRange.start && currentPage <= pageRange.end {
                    return chapter.number
                }
            }
        }

        // Fall back to percentage
        let chapters = enrichment.totalChapters
        let inferred = Int(progress.percentComplete * Double(chapters))
        return max(1, inferred)
    }

    // MARK: - Content Filtering

    /// Get characters that are safe to show (introduced by boundary)
    func getSafeCharacters(boundary: Int) -> [Character] {
        enrichment.characters.filter { character in
            character.firstMention <= boundary
        }
    }

    /// Get chapters that are safe to show
    func getSafeChapters(boundary: Int) -> [Chapter] {
        enrichment.chapters.filter { chapter in
            chapter.number <= boundary
        }
    }

    /// Get themes that are safe to show (introduced by boundary)
    func getSafeThemes(boundary: Int) -> [Theme] {
        enrichment.themes.compactMap { theme in
            guard theme.firstIntroduced <= boundary else { return nil }

            // Filter key chapters to only those reached
            var safeTheme = theme
            let safeKeyChapters = theme.keyChapters.filter { $0 <= boundary }

            return Theme(
                name: theme.name,
                firstIntroduced: theme.firstIntroduced,
                description: theme.description,
                keyChapters: safeKeyChapters
            )
        }
    }

    /// Check if content at given chapter is safe to reveal
    func isSafe(chapter: Int, boundary: Int) -> Bool {
        return chapter <= boundary
    }
}

// MARK: - Revealable Protocol

protocol Revealable {
    var revealedAt: Int { get }
}

extension TemplateItem: Revealable {}
