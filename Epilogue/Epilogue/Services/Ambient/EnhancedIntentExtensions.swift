import Foundation

// MARK: - Extended Intent Types for Generative Actions

extension EnhancedIntent.IntentType {
    // Generative actions
    static func generateTemplate(_ request: TemplateRequest) -> Self {
        .ambient // Placeholder - will be handled by AmbientActionRouter
    }

    static func createJourney(_ request: JourneyRequest) -> Self {
        .ambient // Placeholder - will be handled by AmbientActionRouter
    }

    static func addBook(_ request: BookRequest) -> Self {
        .ambient // Placeholder - will be handled by AmbientActionRouter
    }

    static func analyzePatterns() -> Self {
        .ambient // Placeholder - will be handled by AmbientActionRouter
    }
}

// MARK: - Request Types

struct TemplateRequest: Equatable {
    let type: TemplateType
    let bookTitle: String

    static func == (lhs: TemplateRequest, rhs: TemplateRequest) -> Bool {
        lhs.type == rhs.type && lhs.bookTitle == rhs.bookTitle
    }
}

struct JourneyRequest: Equatable {
    let theme: String?
    let mood: String?
    let author: String?
    let basedOnBooks: [String]

    static func == (lhs: JourneyRequest, rhs: JourneyRequest) -> Bool {
        lhs.theme == rhs.theme &&
        lhs.mood == rhs.mood &&
        lhs.author == rhs.author &&
        lhs.basedOnBooks == rhs.basedOnBooks
    }
}

struct BookRequest: Equatable {
    let title: String
    let author: String?

    static func == (lhs: BookRequest, rhs: BookRequest) -> Bool {
        lhs.title == rhs.title && lhs.author == rhs.author
    }
}

// MARK: - Enhanced Intent Detector Extension

extension EnhancedIntentDetector {
    /// Detect generative action intents
    func detectGenerativeIntent(from text: String) -> GenerativeIntent? {
        let lowercased = text.lowercased()

        // Template generation
        if let templateIntent = detectTemplateIntent(lowercased, originalText: text) {
            return .template(templateIntent)
        }

        // Journey creation
        if let journeyIntent = detectJourneyIntent(lowercased) {
            return .journey(journeyIntent)
        }

        // Book addition
        if let bookIntent = detectBookIntent(lowercased, originalText: text) {
            return .addBook(bookIntent)
        }

        // Pattern analysis
        if detectPatternAnalysisIntent(lowercased) {
            return .analyzePatterns
        }

        return nil
    }

    private func detectTemplateIntent(_ lowercased: String, originalText: String) -> TemplateRequest? {
        // Character map patterns
        let characterPatterns = [
            "character map", "character tracker", "character list",
            "track characters", "characters in"
        ]

        // Reading guide patterns
        let guidePatterns = [
            "reading guide", "guide for reading", "help me read",
            "context for", "background for"
        ]

        // Theme tracker patterns
        let themePatterns = [
            "theme tracker", "track themes", "themes in",
            "thematic", "explore themes"
        ]

        var templateType: TemplateType?

        if characterPatterns.contains(where: { lowercased.contains($0) }) {
            templateType = .characters
        } else if guidePatterns.contains(where: { lowercased.contains($0) }) {
            templateType = .guide
        } else if themePatterns.contains(where: { lowercased.contains($0) }) {
            templateType = .themes
        }

        guard let type = templateType else { return nil }

        // Extract book title
        let bookTitle = extractBookTitle(from: originalText) ?? "current book"

        return TemplateRequest(type: type, bookTitle: bookTitle)
    }

    private func detectJourneyIntent(_ lowercased: String) -> JourneyRequest? {
        let journeyPatterns = [
            "create a journey", "reading journey", "reading plan",
            "what should i read", "recommend a reading order",
            "help me plan"
        ]

        guard journeyPatterns.contains(where: { lowercased.contains($0) }) else {
            return nil
        }

        // Extract preferences
        var theme: String?
        var mood: String?
        var author: String?

        // Theme extraction
        if lowercased.contains("about") || lowercased.contains("theme") {
            // Extract theme after "about" or "theme"
            if let range = lowercased.range(of: "about ") {
                theme = String(lowercased[range.upperBound...])
                    .components(separatedBy: CharacterSet.punctuationCharacters)
                    .first?
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        // Mood extraction
        let moodKeywords = ["epic", "hopeful", "dark", "light", "heavy", "fun", "serious"]
        mood = moodKeywords.first { lowercased.contains($0) }

        // Author extraction
        if lowercased.contains("by ") {
            if let range = lowercased.range(of: "by ") {
                author = String(lowercased[range.upperBound...])
                    .components(separatedBy: CharacterSet.punctuationCharacters)
                    .first?
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return JourneyRequest(
            theme: theme,
            mood: mood,
            author: author,
            basedOnBooks: []
        )
    }

    private func detectBookIntent(_ lowercased: String, originalText: String) -> BookRequest? {
        let addPatterns = [
            "add the book", "add to library", "add this book",
            "i want to read", "add to my library"
        ]

        guard addPatterns.contains(where: { lowercased.contains($0) }) else {
            return nil
        }

        // Extract book title
        guard let title = extractBookTitle(from: originalText) else {
            return nil
        }

        // Extract author if mentioned
        var author: String?
        if lowercased.contains(" by ") {
            if let range = lowercased.range(of: " by ") {
                author = String(lowercased[range.upperBound...])
                    .components(separatedBy: CharacterSet.punctuationCharacters)
                    .first?
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return BookRequest(title: title, author: author)
    }

    private func detectPatternAnalysisIntent(_ lowercased: String) -> Bool {
        let patterns = [
            "reading pattern", "why can't i read", "reading habit",
            "read more consistently", "my reading", "analyze my"
        ]

        return patterns.contains(where: { lowercased.contains($0) })
    }

    private func extractBookTitle(from text: String) -> String? {
        // Look for quoted text
        if let range = text.range(of: #""([^"]+)""#, options: .regularExpression) {
            let quoted = String(text[range])
            return quoted.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }

        // Look for "for [book]" pattern
        if let range = text.lowercased().range(of: "for ") {
            let afterFor = String(text[range.upperBound...])
            let title = afterFor
                .components(separatedBy: CharacterSet.punctuationCharacters)
                .first?
                .trimmingCharacters(in: .whitespaces)
            return title
        }

        return nil
    }
}

// MARK: - Generative Intent Enum

enum GenerativeIntent {
    case template(TemplateRequest)
    case journey(JourneyRequest)
    case addBook(BookRequest)
    case analyzePatterns
}
