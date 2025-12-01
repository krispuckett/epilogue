import Foundation
import SwiftData

// MARK: - Generated Template Model

@Model
final class GeneratedTemplate {
    @Attribute(.unique) var id: UUID
    var bookID: UUID
    var type: String  // TemplateType.rawValue
    var createdDate: Date
    var lastUpdated: Date

    // Spoiler boundary
    var revealedThrough: Int  // Chapter number
    var updateMode: String    // UpdateMode.rawValue

    // Content
    var sectionsData: Data?   // Encoded [TemplateSection]

    // Metadata
    var enrichmentBased: Bool
    var userNotesData: Data?  // [String: String] encoded

    init(
        bookID: UUID,
        type: TemplateType,
        revealedThrough: Int,
        updateMode: UpdateMode = .conservative,
        sections: [TemplateSection] = [],
        enrichmentBased: Bool = true
    ) {
        self.id = UUID()
        self.bookID = bookID
        self.type = type.rawValue
        self.createdDate = Date()
        self.lastUpdated = Date()
        self.revealedThrough = revealedThrough
        self.updateMode = updateMode.rawValue
        self.enrichmentBased = enrichmentBased

        self.sectionsData = try? JSONEncoder().encode(sections)
        self.userNotesData = try? JSONEncoder().encode([String: String]())
    }

    // Computed properties
    var templateType: TemplateType {
        TemplateType(rawValue: type) ?? .characters
    }

    var updateModeValue: UpdateMode {
        UpdateMode(rawValue: updateMode) ?? .conservative
    }

    var sections: [TemplateSection] {
        get {
            guard let data = sectionsData else { return [] }
            return (try? JSONDecoder().decode([TemplateSection].self, from: data)) ?? []
        }
        set {
            sectionsData = try? JSONEncoder().encode(newValue)
            lastUpdated = Date()
        }
    }

    var userNotes: [String: String] {
        get {
            guard let data = userNotesData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            userNotesData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Template Types

enum TemplateType: String, Codable, CaseIterable {
    case characters = "Character Map"
    case plot = "Plot Timeline"
    case themes = "Theme Tracker"
    case guide = "Reading Guide"

    var systemImage: String {
        switch self {
        case .characters: return "person.2"
        case .plot: return "list.bullet"
        case .themes: return "lightbulb"
        case .guide: return "book"
        }
    }
}

enum UpdateMode: String, Codable {
    case conservative  // 1 chapter behind
    case current      // Match progress exactly
    case manual       // User triggers only

    var description: String {
        switch self {
        case .conservative:
            return "Conservative (recommended)\nShows 1 chapter behind your progress"
        case .current:
            return "Current\nShows exactly your current chapter"
        case .manual:
            return "Manual updates only\nYou choose when to reveal more"
        }
    }
}

// MARK: - Template Content

struct TemplateSection: Codable, Identifiable {
    let id: UUID
    let title: String
    var items: [TemplateItem]

    init(title: String, items: [TemplateItem] = []) {
        self.id = UUID()
        self.title = title
        self.items = items
    }
}

struct TemplateItem: Codable, Identifiable {
    let id: UUID
    let content: String
    let revealedAt: Int  // Chapter number
    var userNote: String?

    init(content: String, revealedAt: Int, userNote: String? = nil) {
        self.id = UUID()
        self.content = content
        self.revealedAt = revealedAt
        self.userNote = userNote
    }
}

// MARK: - Reading Progress

struct ReadingProgress {
    let currentChapter: Int?
    let currentPage: Int?
    let percentComplete: Double

    init(currentChapter: Int? = nil, currentPage: Int? = nil, percentComplete: Double = 0.0) {
        self.currentChapter = currentChapter
        self.currentPage = currentPage
        self.percentComplete = percentComplete
    }
}

// MARK: - Book Extension

extension Book {
    func getTemplates(context: ModelContext) -> [GeneratedTemplate] {
        let descriptor = FetchDescriptor<GeneratedTemplate>(
            predicate: #Predicate { $0.bookID == self.id },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func getTemplate(type: TemplateType, context: ModelContext) -> GeneratedTemplate? {
        let templates = getTemplates(context: context)
        return templates.first { $0.templateType == type }
    }

    var readingProgress: ReadingProgress {
        let percent = pageCount != nil && pageCount! > 0
            ? Double(currentPage) / Double(pageCount!)
            : 0.0

        return ReadingProgress(
            currentChapter: nil,  // We don't track this yet
            currentPage: currentPage,
            percentComplete: percent
        )
    }
}
