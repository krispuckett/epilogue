import Foundation
import SwiftData

// MARK: - Book DNA Service
/// Builds and updates BookDNA profiles from a reader's activity data.
/// Singleton — configure once at startup, then call update methods as sessions complete.

@MainActor
final class BookDNAService {
    static let shared = BookDNAService()
    private var container: ModelContainer?

    private init() {}

    // MARK: - Configuration

    func configure(with container: ModelContainer) {
        self.container = container
    }

    // MARK: - Public API

    /// Generate BookDNA for any books that have sessions but no existing BookDNA.
    func generateMissingDNAs(modelContext: ModelContext) {
        let bookDescriptor = FetchDescriptor<BookModel>()
        guard let allBooks = try? modelContext.fetch(bookDescriptor) else { return }

        let dnaDescriptor = FetchDescriptor<BookDNA>()
        let existingDNAs = (try? modelContext.fetch(dnaDescriptor)) ?? []
        let existingBookIds = Set(existingDNAs.map { $0.bookModelId })

        var generatedCount = 0
        for book in allBooks {
            // Skip books that already have a BookDNA
            if existingBookIds.contains(book.localId) { continue }

            // Only generate for books with some activity
            let sessions = book.sessions ?? []
            let quotes = book.quotes ?? []
            let notes = book.notes ?? []
            let questions = book.questions ?? []

            let hasActivity = !sessions.isEmpty || !quotes.isEmpty || !notes.isEmpty || !questions.isEmpty
            guard hasActivity else { continue }

            let dna = buildDNA(for: book, modelContext: modelContext)
            modelContext.insert(dna)
            generatedCount += 1
        }

        if generatedCount > 0 {
            try? modelContext.save()
            #if DEBUG
            print("🧬 BookDNA: Generated \(generatedCount) missing profiles")
            #endif
        }
    }

    /// Full rebuild/update of a BookDNA from all available data on a BookModel.
    func updateDNA(for bookModel: BookModel, modelContext: ModelContext) {
        let dna = getOrCreateDNA(for: bookModel, modelContext: modelContext)
        populateDNA(dna, from: bookModel)
        dna.lastUpdated = Date()
        try? modelContext.save()
    }

    /// Incremental update after a session ends — re-derives stats without a full rebuild.
    func generateAfterSession(for bookModel: BookModel, session: AmbientSession, modelContext: ModelContext) {
        // A session just finished, so do a full update (cheap enough for now)
        updateDNA(for: bookModel, modelContext: modelContext)
    }

    // MARK: - Core Logic

    /// Fetch existing BookDNA for a BookModel or create a new one.
    func getOrCreateDNA(for bookModel: BookModel, modelContext: ModelContext) -> BookDNA {
        let bookLocalId = bookModel.localId
        var descriptor = FetchDescriptor<BookDNA>(
            predicate: #Predicate { $0.bookModelId == bookLocalId }
        )
        descriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let dna = BookDNA(
            bookModelId: bookModel.localId,
            bookTitle: bookModel.title,
            bookAuthor: bookModel.author
        )
        modelContext.insert(dna)
        return dna
    }

    // MARK: - Private Helpers

    private func buildDNA(for bookModel: BookModel, modelContext: ModelContext) -> BookDNA {
        let dna = BookDNA(
            bookModelId: bookModel.localId,
            bookTitle: bookModel.title,
            bookAuthor: bookModel.author
        )
        populateDNA(dna, from: bookModel)
        return dna
    }

    private func populateDNA(_ dna: BookDNA, from bookModel: BookModel) {
        let sessions = bookModel.sessions ?? []
        let quotes = bookModel.quotes ?? []
        let notes = bookModel.notes ?? []
        let questions = bookModel.questions ?? []

        // --- Stats ---
        dna.sessionCount = sessions.count
        dna.totalHighlights = quotes.count
        dna.totalNotes = notes.count
        dna.totalQuestions = questions.count
        dna.bookTitle = bookModel.title
        dna.bookAuthor = bookModel.author

        // --- Total reading minutes ---
        let durations = sessions.map { $0.duration }
        let totalSeconds = durations.reduce(0, +)
        dna.totalReadingMinutes = totalSeconds / 60.0

        // --- Average session minutes ---
        if !sessions.isEmpty {
            dna.averageSessionMinutes = (totalSeconds / Double(sessions.count)) / 60.0
        }

        // --- Pace profile ---
        dna.paceProfile = derivePaceProfile(durations: durations)

        // --- Idea density (highlights per page, capped at 1.0) ---
        let pageCount = Double(bookModel.pageCount ?? 300)
        dna.ideaDensity = min(1.0, Double(quotes.count) / max(1.0, pageCount))

        // --- Discussion energy (questions per session, capped at 1.0) ---
        dna.discussionEnergy = min(1.0, Double(questions.count) / max(1.0, Double(sessions.count)))

        // --- Personal resonance (weighted combo) ---
        // Normalize sessionCount to 0-1 (10+ sessions = 1.0)
        let sessionScore = min(1.0, Double(sessions.count) / 10.0)
        dna.personalResonance = min(1.0,
            dna.ideaDensity * 0.35 +
            dna.discussionEnergy * 0.35 +
            sessionScore * 0.30
        )

        // --- Tone tags from BookModel ---
        if let tone = bookModel.tone {
            dna.toneTags = tone
        }

        // --- Theme weights from BookModel.keyThemes (equal weight initially) ---
        if let themes = bookModel.keyThemes, !themes.isEmpty {
            dna.themeWeights = themes.map { "\($0):1.0" }
        }

        // --- Memory clusters (top keywords from notes + quotes) ---
        dna.memoryClusters = extractMemoryClusters(notes: notes, quotes: quotes)

        // --- Top quote themes (top keywords from quotes only) ---
        dna.topQuoteThemes = extractTopKeywords(from: quotes.compactMap { $0.text }, limit: 5)
    }

    /// Derive pace profile from session durations (in seconds).
    private func derivePaceProfile(durations: [TimeInterval]) -> String {
        guard !durations.isEmpty else { return "moderate" }

        let avgMinutes = (durations.reduce(0, +) / Double(durations.count)) / 60.0

        // Check for high variance ("variable")
        if durations.count >= 3 {
            let mean = durations.reduce(0, +) / Double(durations.count)
            let variance = durations.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(durations.count)
            let stddev = sqrt(variance) / 60.0 // in minutes
            // If standard deviation > 50% of mean, it's variable
            if stddev > (avgMinutes * 0.5) && avgMinutes > 5 {
                return "variable"
            }
        }

        switch avgMinutes {
        case ..<15: return "fast"
        case 15..<30: return "moderate"
        default: return "meditative"
        }
    }

    /// Extract top keywords from notes and quotes combined.
    private func extractMemoryClusters(notes: [CapturedNote], quotes: [CapturedQuote]) -> [String] {
        var allText: [String] = []
        allText.append(contentsOf: notes.compactMap { $0.content })
        allText.append(contentsOf: quotes.compactMap { $0.text })
        return extractTopKeywords(from: allText, limit: 8)
    }

    /// Simple word-frequency keyword extraction. Returns top N significant words.
    private func extractTopKeywords(from texts: [String], limit: Int) -> [String] {
        var wordCounts: [String: Int] = [:]

        for text in texts {
            let words = text
                .lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count > 4 && !Self.stopWords.contains($0) }

            for word in words {
                wordCounts[word, default: 0] += 1
            }
        }

        return wordCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key.capitalized }
    }

    // Common English stop words to filter out of keyword extraction
    private static let stopWords: Set<String> = [
        "about", "above", "after", "again", "against", "being", "below",
        "between", "could", "doing", "during", "every", "first", "found",
        "great", "having", "itself", "large", "might", "never", "other",
        "other", "place", "point", "quite", "really", "right", "shall",
        "should", "since", "small", "still", "their", "there", "these",
        "thing", "think", "those", "three", "through", "today", "under",
        "until", "using", "value", "water", "where", "which", "while",
        "world", "would", "would", "years", "young"
    ]
}
