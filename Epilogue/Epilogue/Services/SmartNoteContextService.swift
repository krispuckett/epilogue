import Foundation
import NaturalLanguage

/// Smart context detection for notes using NLP
@MainActor
class SmartNoteContextService {
    static let shared = SmartNoteContextService()

    // Character/concept mappings for popular books
    private let bookContextMappings: [String: [String]] = [
        "The Lord of the Rings": ["aragorn", "frodo", "gandalf", "ring", "hobbit", "shire", "mordor", "sauron", "fellowship"],
        "Harry Potter": ["harry", "hermione", "ron", "dumbledore", "voldemort", "hogwarts", "wizard", "magic"],
        "1984": ["winston", "julia", "big brother", "oceania", "thoughtcrime", "doublethink"],
        "The Great Gatsby": ["gatsby", "daisy", "nick", "tom", "green light", "west egg", "east egg"],
        "Atomic Habits": ["habit", "routine", "system", "1% better", "compound", "identity"],
        "Sapiens": ["homo sapiens", "cognitive revolution", "agricultural revolution", "yuval"],
        "The Anxious Generation": ["anxiety", "social media", "smartphones", "gen z", "mental health"],
        "Dune": ["paul", "atreides", "spice", "melange", "arrakis", "fremen", "sandworm"],
        "Pride and Prejudice": ["elizabeth", "darcy", "bennet", "wickham", "pemberley"],
        "The Hobbit": ["bilbo", "thorin", "smaug", "lonely mountain", "precious"]
    ]

    /// Detect book context from text using NLP
    func detectBookContext(from text: String, library: [Book]) -> Book? {
        let lowercased = text.lowercased()

        // First check for direct title mentions
        for book in library {
            if lowercased.contains(book.title.lowercased()) {
                return book
            }
        }

        // Use NLP to extract entities
        let tagger = NLTagger(tagSchemes: [.nameType, .lemma])
        tagger.string = text

        var detectedEntities = Set<String>()

        // Extract person names and places
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .personalName || tag == .placeName {
                let entity = String(text[tokenRange]).lowercased()
                detectedEntities.insert(entity)
            }
            return true
        }

        // Check against known character/concept mappings
        var bestMatch: (book: Book, score: Int)?

        for (bookTitle, keywords) in bookContextMappings {
            var score = 0

            // Check text for keywords
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    score += 2
                }
            }

            // Check detected entities
            for entity in detectedEntities {
                if keywords.contains(entity) {
                    score += 3
                }
            }

            // Find book in library
            if score > 0 {
                if let book = library.first(where: { $0.title.contains(bookTitle) }) {
                    if bestMatch == nil || score > bestMatch!.score {
                        bestMatch = (book, score)
                    }
                }
            }
        }

        // Return best match if confidence is high enough
        if let match = bestMatch, match.score >= 3 {
            return match.book
        }

        return nil
    }

    /// Enhance command with detected book context
    func enhanceCommand(_ text: String, library: [Book], currentBook: Book?) -> String {
        let lowercased = text.lowercased()

        // Don't enhance if it's already a command or looks like a book title
        if lowercased.starts(with: "add") ||
           lowercased.starts(with: "search") ||
           lowercased.starts(with: "find") ||
           lowercased.starts(with: "quote") ||
           lowercased.starts(with: "note") ||
           lowercased.contains(" by ") {  // Likely a book title with author
            return text
        }

        // Check if text is likely just a book title (not in library)
        let bookExists = library.contains { book in
            book.title.lowercased() == lowercased ||
            book.title.lowercased().contains(lowercased) ||
            lowercased.contains(book.title.lowercased())
        }

        // If it doesn't match any existing book and doesn't look like a note, return as-is
        // This allows it to be treated as a potential book search
        if !bookExists && !isNoteIntent(text) && !text.contains("\"") {
            return text  // Let CommandParser handle it as potential book search
        }

        // If we're viewing a book, add context for notes
        if let currentBook = currentBook {
            // If the text doesn't mention another book, assume it's about current book
            let mentionsOtherBook = library.contains { otherBook in
                otherBook.localId != currentBook.localId &&
                lowercased.contains(otherBook.title.lowercased())
            }

            if !mentionsOtherBook && isNoteIntent(text) {
                // Add book context if it's a note
                if lowercased.starts(with: "note") {
                    return text // Already has note prefix
                }
                // Otherwise make it a note about this book
                return "note: \(text)"
            }
        }

        // Try to detect book context from the text for notes
        if isNoteIntent(text) {
            if let detectedBook = detectBookContext(from: text, library: library) {
                // Add book context
                if !text.lowercased().starts(with: "note") {
                    return "note about \(detectedBook.title): \(text)"
                }
            }
        }

        return text
    }

    /// Check if text is requesting a note
    func isNoteIntent(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let noteKeywords = ["note", "remember", "thought", "idea", "observation", "insight"]
        return noteKeywords.contains { lowercased.contains($0) }
    }

    /// Check if text is a quote
    func isQuoteIntent(_ text: String) -> Bool {
        // Check for quotation marks or quote keywords
        return text.contains("\"") ||
               text.contains("\u{201C}") || // Left double quote
               text.contains("\u{201D}") || // Right double quote
               text.lowercased().contains("quote")
    }
}