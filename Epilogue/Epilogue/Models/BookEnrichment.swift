import Foundation
import SwiftData

// MARK: - Book Enrichment Model

@Model
final class BookEnrichment {
    @Attribute(.unique) var id: UUID
    var bookID: UUID
    var enrichedDate: Date
    var source: String

    // Core data
    var charactersData: Data?  // Encoded [Character]
    var chaptersData: Data?    // Encoded [Chapter]
    var themesData: Data?      // Encoded [Theme]
    var structureData: Data?   // Encoded BookStructure

    // Metadata
    var totalChapters: Int
    var quality: String  // "full", "partial", "unavailable"
    var confidence: Double

    init(
        bookID: UUID,
        source: String = "sonar",
        characters: [Character] = [],
        chapters: [Chapter] = [],
        themes: [Theme] = [],
        structure: BookStructure? = nil,
        totalChapters: Int,
        quality: EnrichmentQuality = .full,
        confidence: Double = 1.0
    ) {
        self.id = UUID()
        self.bookID = bookID
        self.enrichedDate = Date()
        self.source = source
        self.totalChapters = totalChapters
        self.quality = quality.rawValue
        self.confidence = confidence

        // Encode arrays to Data
        self.charactersData = try? JSONEncoder().encode(characters)
        self.chaptersData = try? JSONEncoder().encode(chapters)
        self.themesData = try? JSONEncoder().encode(themes)
        self.structureData = try? JSONEncoder().encode(structure)
    }

    // Computed properties for easy access
    var characters: [Character] {
        get {
            guard let data = charactersData else { return [] }
            return (try? JSONDecoder().decode([Character].self, from: data)) ?? []
        }
        set {
            charactersData = try? JSONEncoder().encode(newValue)
        }
    }

    var chapters: [Chapter] {
        get {
            guard let data = chaptersData else { return [] }
            return (try? JSONDecoder().decode([Chapter].self, from: data)) ?? []
        }
        set {
            chaptersData = try? JSONEncoder().encode(newValue)
        }
    }

    var themes: [Theme] {
        get {
            guard let data = themesData else { return [] }
            return (try? JSONDecoder().decode([Theme].self, from: data)) ?? []
        }
        set {
            themesData = try? JSONEncoder().encode(newValue)
        }
    }

    var structure: BookStructure? {
        get {
            guard let data = structureData else { return nil }
            return try? JSONDecoder().decode(BookStructure.self, from: data)
        }
        set {
            structureData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Supporting Types

enum EnrichmentQuality: String, Codable {
    case full
    case partial
    case unavailable
}

struct Character: Codable, Identifiable {
    let id: UUID
    let name: String
    let firstMention: Int  // Chapter number
    let role: String
    let significance: String
    let connections: [String]

    init(
        name: String,
        firstMention: Int,
        role: String,
        significance: String,
        connections: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.firstMention = firstMention
        self.role = role
        self.significance = significance
        self.connections = connections
    }
}

struct Chapter: Codable, Identifiable {
    let id: UUID
    let number: Int
    let title: String?
    let summary: String
    let charactersIntroduced: [String]
    let plotPoints: [String]
    let themes: [String]
    let approximatePages: PageRange?

    init(
        number: Int,
        title: String? = nil,
        summary: String,
        charactersIntroduced: [String] = [],
        plotPoints: [String] = [],
        themes: [String] = [],
        approximatePages: PageRange? = nil
    ) {
        self.id = UUID()
        self.number = number
        self.title = title
        self.summary = summary
        self.charactersIntroduced = charactersIntroduced
        self.plotPoints = plotPoints
        self.themes = themes
        self.approximatePages = approximatePages
    }
}

struct PageRange: Codable {
    let start: Int
    let end: Int
}

struct Theme: Codable, Identifiable {
    let id: UUID
    let name: String
    let firstIntroduced: Int  // Chapter number
    let description: String
    let keyChapters: [Int]

    init(
        name: String,
        firstIntroduced: Int,
        description: String,
        keyChapters: [Int] = []
    ) {
        self.id = UUID()
        self.name = name
        self.firstIntroduced = firstIntroduced
        self.description = description
        self.keyChapters = keyChapters
    }
}

struct BookStructure: Codable {
    let type: StructureType
    let totalChapters: Int
    let divisions: [Division]
}

enum StructureType: String, Codable {
    case chapters
    case parts
    case books
    case mixed
}

struct Division: Codable, Identifiable {
    let id: UUID
    let name: String
    let chapterRange: PageRange

    init(name: String, chapterRange: PageRange) {
        self.id = UUID()
        self.name = name
        self.chapterRange = chapterRange
    }
}

// MARK: - Book Extension

extension Book {
    func getEnrichment(context: ModelContext) -> BookEnrichment? {
        let descriptor = FetchDescriptor<BookEnrichment>(
            predicate: #Predicate { $0.bookID == self.id }
        )
        return try? context.fetch(descriptor).first
    }

    var hasEnrichment: Bool {
        guard let context = modelContext else { return false }
        return getEnrichment(context: context) != nil
    }
}
