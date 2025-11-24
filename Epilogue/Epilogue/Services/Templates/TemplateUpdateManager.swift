import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "TemplateUpdate")

/// Manages template updates as user progresses through book
@MainActor
class TemplateUpdateManager {
    private let generator: TemplateGenerator
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.generator = TemplateGenerator(modelContext: modelContext)
        self.modelContext = modelContext
    }

    // MARK: - Update Detection

    /// Check if template needs updating based on reading progress
    func checkForUpdate(
        _ template: GeneratedTemplate,
        book: Book,
        enrichment: BookEnrichment
    ) -> UpdateRecommendation? {

        let progress = book.readingProgress
        let filter = SpoilerSafeFilter(
            enrichment: enrichment,
            mode: template.updateModeValue
        )
        let currentBoundary = filter.safeBoundary(for: progress)
        let gap = currentBoundary - template.revealedThrough

        guard gap > 0 else { return nil }

        // Check based on update mode
        switch template.updateModeValue {
        case .conservative:
            if gap >= 3 {
                return UpdateRecommendation(
                    template: template,
                    newBoundary: currentBoundary,
                    chaptersAdded: gap,
                    reason: "3 chapters ahead",
                    urgency: .medium
                )
            }

        case .current:
            if gap >= 1 {
                return UpdateRecommendation(
                    template: template,
                    newBoundary: currentBoundary,
                    chaptersAdded: gap,
                    reason: "New chapter available",
                    urgency: .medium
                )
            }

        case .manual:
            // For manual mode, suggest every 5 chapters
            if gap >= 5 {
                return UpdateRecommendation(
                    template: template,
                    newBoundary: currentBoundary,
                    chaptersAdded: gap,
                    reason: "\(gap) chapters ahead",
                    urgency: .low
                )
            }
        }

        return nil
    }

    /// Check all templates for a book
    func checkAllTemplates(
        for book: Book,
        enrichment: BookEnrichment
    ) -> [UpdateRecommendation] {
        let templates = book.getTemplates(context: modelContext)

        return templates.compactMap { template in
            checkForUpdate(template, book: book, enrichment: enrichment)
        }
    }

    // MARK: - Update Execution

    /// Update template to new boundary
    func updateTemplate(
        _ template: GeneratedTemplate,
        book: Book,
        enrichment: BookEnrichment,
        toChapter newBoundary: Int
    ) async throws {

        logger.info("📝 Updating \(template.templateType.rawValue) from Ch \(template.revealedThrough) to Ch \(newBoundary)")

        let progress = ReadingProgress(
            currentChapter: newBoundary,
            currentPage: book.currentPage,
            percentComplete: book.readingProgress.percentComplete
        )

        // Generate new content
        let updatedTemplate: GeneratedTemplate

        switch template.templateType {
        case .characters:
            updatedTemplate = try await generator.generateCharacterMap(
                for: book,
                enrichment: enrichment,
                progress: progress,
                mode: template.updateModeValue
            )

        case .guide:
            updatedTemplate = try await generator.generateReadingGuide(
                for: book,
                enrichment: enrichment,
                progress: progress,
                mode: template.updateModeValue
            )

        case .themes:
            updatedTemplate = try await generator.generateThemeTracker(
                for: book,
                enrichment: enrichment,
                progress: progress,
                mode: template.updateModeValue
            )

        case .plot:
            throw TemplateError.generationFailed
        }

        // Merge user notes from old template
        var mergedSections = updatedTemplate.sections
        for (index, section) in mergedSections.enumerated() {
            for (itemIndex, item) in section.items.enumerated() {
                // Find corresponding item in old template by content similarity
                if let oldSection = template.sections.first(where: { $0.title == section.title }),
                   let oldItem = oldSection.items.first(where: { itemsMatch($0, item) }),
                   let userNote = oldItem.userNote {
                    mergedSections[index].items[itemIndex].userNote = userNote
                }
            }
        }

        // Update template
        template.sections = mergedSections
        template.revealedThrough = newBoundary
        template.lastUpdated = Date()

        try modelContext.save()

        logger.info("✅ Updated template to Ch \(newBoundary)")
    }

    /// Change template update mode
    func changeUpdateMode(
        _ template: GeneratedTemplate,
        to mode: UpdateMode
    ) {
        template.updateMode = mode.rawValue
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func itemsMatch(_ item1: TemplateItem, _ item2: TemplateItem) -> Bool {
        // Simple content matching - could be more sophisticated
        let content1 = item1.content.lowercased().prefix(50)
        let content2 = item2.content.lowercased().prefix(50)
        return content1 == content2
    }
}

// MARK: - Update Recommendation

struct UpdateRecommendation: Identifiable {
    let id = UUID()
    let template: GeneratedTemplate
    let newBoundary: Int
    let chaptersAdded: Int
    let reason: String
    let urgency: Urgency

    enum Urgency {
        case low
        case medium
        case high
    }

    var description: String {
        """
        You're now on Chapter \(newBoundary)
        New content available for \(chaptersAdded) chapter\(chaptersAdded == 1 ? "" : "s")
        """
    }
}
