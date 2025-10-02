import Foundation
import NaturalLanguage
import SwiftData

/// On-device analysis of user's library to extract reading preferences
/// Uses Apple's Natural Language framework for privacy-first processing
@MainActor
class LibraryTasteAnalyzer {
    static let shared = LibraryTasteAnalyzer()

    private init() {}

    // MARK: - Taste Profile

    struct TasteProfile: Codable {
        let genres: [String: Int]          // Genre frequency map
        let authors: [String: Int]         // Author frequency map
        let themes: [String]               // Extracted themes/topics
        let readingLevel: ReadingLevel     // Complexity preference
        let preferredEra: Era?             // Publication era preference
        let topKeywords: [String]          // Most common keywords
        let createdAt: Date

        enum ReadingLevel: String, Codable {
            case contemporary = "Contemporary"
            case literary = "Literary"
            case academic = "Academic"
            case popular = "Popular Fiction"
        }

        enum Era: String, Codable {
            case classical = "Classical (Pre-1900)"
            case modern = "Modern (1900-1950)"
            case contemporary = "Contemporary (1950-2000)"
            case current = "Current (2000+)"
        }

        var isEmpty: Bool {
            genres.isEmpty && authors.isEmpty && themes.isEmpty
        }
    }

    // MARK: - Analysis

    func analyzeLibrary(books: [BookModel]) async -> TasteProfile {
        print("📊 Analyzing library of \(books.count) books...")

        // Extract genres
        let genreFrequency = extractGenres(from: books)

        // Extract authors
        let authorFrequency = extractAuthors(from: books)

        // Extract themes using NLTagger
        let themes = await extractThemes(from: books)

        // Determine reading level
        let readingLevel = determineReadingLevel(from: books)

        // Determine preferred era
        let preferredEra = determinePreferredEra(from: books)

        // Extract top keywords
        let keywords = await extractTopKeywords(from: books)

        let profile = TasteProfile(
            genres: genreFrequency,
            authors: authorFrequency,
            themes: themes,
            readingLevel: readingLevel,
            preferredEra: preferredEra,
            topKeywords: keywords,
            createdAt: Date()
        )

        print("✅ Taste profile created:")
        print("   Top genres: \(profile.genres.sorted(by: { $0.value > $1.value }).prefix(3).map { $0.key })")
        print("   Top authors: \(profile.authors.sorted(by: { $0.value > $1.value }).prefix(3).map { $0.key })")
        print("   Themes: \(profile.themes.prefix(5))")
        print("   Reading level: \(profile.readingLevel.rawValue)")

        return profile
    }

    // MARK: - Genre Extraction

    private func extractGenres(from books: [BookModel]) -> [String: Int] {
        var genreFrequency: [String: Int] = [:]

        for book in books {
            // Extract from title and author using keyword matching
            let text = "\(book.title) \(book.author)".lowercased()

            // Common genre indicators
            let genreKeywords: [String: [String]] = [
                "Fantasy": ["fantasy", "magic", "wizard", "dragon", "realm", "quest"],
                "Science Fiction": ["science fiction", "sci-fi", "space", "future", "alien", "robot"],
                "Mystery": ["mystery", "detective", "crime", "murder", "investigation"],
                "Romance": ["romance", "love", "heart", "passion"],
                "Thriller": ["thriller", "suspense", "conspiracy"],
                "Historical": ["history", "historical", "war", "century"],
                "Biography": ["biography", "memoir", "life of"],
                "Philosophy": ["philosophy", "philosophical", "ethics", "logic"],
                "Poetry": ["poetry", "poems", "verse"],
                "Literary Fiction": ["novel", "story", "tales"]
            ]

            for (genre, keywords) in genreKeywords {
                if keywords.contains(where: { text.contains($0) }) {
                    genreFrequency[genre, default: 0] += 1
                }
            }
        }

        return genreFrequency
    }

    // MARK: - Author Extraction

    private func extractAuthors(from books: [BookModel]) -> [String: Int] {
        var authorFrequency: [String: Int] = [:]

        for book in books {
            let author = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !author.isEmpty {
                authorFrequency[author, default: 0] += 1
            }
        }

        return authorFrequency
    }

    // MARK: - Theme Extraction (NLP)

    private func extractThemes(from books: [BookModel]) async -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        var themeSet = Set<String>()

        for book in books {
            let text = "\(book.title) \(book.author)"
            tagger.string = text

            // Extract nouns as themes
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
                if tag == .noun {
                    let word = String(text[range]).lowercased()
                    if word.count > 3 { // Filter short words
                        themeSet.insert(word.capitalized)
                    }
                }
                return true
            }
        }

        return Array(themeSet.prefix(10))
    }

    // MARK: - Reading Level Detection

    private func determineReadingLevel(from books: [BookModel]) -> TasteProfile.ReadingLevel {
        let titles = books.map { $0.title.lowercased() }

        // Literary indicators
        let literaryAuthors = ["shakespeare", "austen", "dickens", "woolf", "joyce", "faulkner", "morrison"]
        let hasLiterary = books.contains { book in
            literaryAuthors.contains(where: { book.author.lowercased().contains($0) })
        }

        // Academic indicators
        let academicKeywords = ["philosophy", "theory", "analysis", "critique", "study"]
        let hasAcademic = titles.contains { title in
            academicKeywords.contains(where: { title.contains($0) })
        }

        // Contemporary literary
        let contemporaryAuthors = ["murakami", "atwood", "rushdie", "smith", "franzen"]
        let hasContemporary = books.contains { book in
            contemporaryAuthors.contains(where: { book.author.lowercased().contains($0) })
        }

        if hasAcademic {
            return .academic
        } else if hasLiterary {
            return .literary
        } else if hasContemporary {
            return .contemporary
        } else {
            return .popular
        }
    }

    // MARK: - Era Detection

    private func determinePreferredEra(from books: [BookModel]) -> TasteProfile.Era? {
        var eraCount: [TasteProfile.Era: Int] = [:]

        for book in books {
            if let yearString = book.publishedYear,
               let year = Int(yearString.prefix(4)) {
                let era: TasteProfile.Era
                if year < 1900 {
                    era = .classical
                } else if year < 1950 {
                    era = .modern
                } else if year < 2000 {
                    era = .contemporary
                } else {
                    era = .current
                }
                eraCount[era, default: 0] += 1
            }
        }

        return eraCount.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Keyword Extraction

    private func extractTopKeywords(from books: [BookModel]) async -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        var keywordFrequency: [String: Int] = [:]

        // Combine all titles
        let allText = books.map { $0.title }.joined(separator: " ")
        tagger.string = allText

        // Extract and count lemmas
        tagger.enumerateTags(in: allText.startIndex..<allText.endIndex, unit: .word, scheme: .lemma) { tag, range in
            if let lemma = tag?.rawValue {
                let word = lemma.lowercased()
                if word.count > 3 && !isStopWord(word) {
                    keywordFrequency[word, default: 0] += 1
                }
            }
            return true
        }

        // Return top 10 keywords
        return keywordFrequency
            .sorted(by: { $0.value > $1.value })
            .prefix(10)
            .map { $0.key.capitalized }
    }

    private func isStopWord(_ word: String) -> Bool {
        let stopWords = Set(["book", "story", "tale", "novel", "about", "with", "from", "this", "that", "have", "been"])
        return stopWords.contains(word)
    }
}
