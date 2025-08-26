import Foundation
import SwiftData
import UniformTypeIdentifiers

struct DataExportService {
    
    enum ExportFormat {
        case json
        case markdown
        case csv
    }
    
    enum ExportScope {
        case allBooks
        case singleBook(Book)
        case quotes([Quote])
        case notes([Note])
    }
    
    static func exportData(
        format: ExportFormat,
        scope: ExportScope,
        context: ModelContext
    ) throws -> Data {
        switch format {
        case .json:
            return try exportAsJSON(scope: scope, context: context)
        case .markdown:
            return try exportAsMarkdown(scope: scope, context: context)
        case .csv:
            return try exportAsCSV(scope: scope, context: context)
        }
    }
    
    // MARK: - JSON Export
    
    private static func exportAsJSON(scope: ExportScope, context: ModelContext) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        switch scope {
        case .allBooks:
            let books = try context.fetch(FetchDescriptor<Book>())
            let exportData = books.map { BookExportModel(from: $0) }
            return try encoder.encode(exportData)
            
        case .singleBook(let book):
            let exportData = BookExportModel(from: book)
            return try encoder.encode(exportData)
            
        case .quotes(let quotes):
            let exportData = quotes.map { QuoteExportModel(from: $0) }
            return try encoder.encode(exportData)
            
        case .notes(let notes):
            let exportData = notes.map { NoteExportModel(from: $0) }
            return try encoder.encode(exportData)
        }
    }
    
    // MARK: - Markdown Export
    
    private static func exportAsMarkdown(scope: ExportScope, context: ModelContext) throws -> Data {
        var markdown = ""
        
        switch scope {
        case .allBooks:
            let books = try context.fetch(FetchDescriptor<Book>())
            markdown = "# My Library\n\n"
            markdown += "Generated on: \(Date().formatted())\n\n"
            
            for book in books {
                markdown += bookToMarkdown(book)
                markdown += "\n---\n\n"
            }
            
        case .singleBook(let book):
            markdown = bookToMarkdown(book)
            
        case .quotes(let quotes):
            markdown = "# Quotes\n\n"
            for quote in quotes {
                markdown += quoteToMarkdown(quote)
                markdown += "\n\n"
            }
            
        case .notes(let notes):
            markdown = "# Notes\n\n"
            for note in notes {
                markdown += noteToMarkdown(note)
                markdown += "\n\n"
            }
        }
        
        return markdown.data(using: .utf8) ?? Data()
    }
    
    private static func bookToMarkdown(_ book: Book) -> String {
        var md = "# \(book.title)\n\n"
        md += "**Author:** \(book.author)\n\n"
        
        if let genre = book.genre {
            md += "**Genre:** \(genre)\n\n"
        }
        
        if let year = book.publicationYear {
            md += "**Published:** \(year)\n\n"
        }
        
        if let rating = book.rating {
            md += "**Rating:** \(String(repeating: "⭐", count: rating))\n\n"
        }
        
        md += "**Progress:** \(book.progressPercentage)%\n\n"
        
        if let description = book.bookDescription {
            md += "## Description\n\n\(description)\n\n"
        }
        
        if let quotes = book.quotes, !quotes.isEmpty {
            md += "## Quotes (\(quotes.count))\n\n"
            for quote in quotes.sorted(by: { $0.dateCreated > $1.dateCreated }) {
                md += quoteToMarkdown(quote)
                md += "\n\n"
            }
        }
        
        if let notes = book.notes, !notes.isEmpty {
            md += "## Notes (\(notes.count))\n\n"
            for note in notes.sorted(by: { $0.dateModified > $1.dateModified }) {
                md += noteToMarkdown(note)
                md += "\n\n"
            }
        }
        
        return md
    }
    
    private static func quoteToMarkdown(_ quote: Quote) -> String {
        var md = "> \(quote.text)\n"
        
        if let page = quote.pageNumber {
            md += "\n*Page \(page)*"
        }
        
        if let chapter = quote.chapter {
            md += " • *\(chapter)*"
        }
        
        if let notes = quote.notes {
            md += "\n\n**Note:** \(notes)"
        }
        
        if !quote.tags.isEmpty {
            md += "\n\n**Tags:** \(quote.tags.joined(separator: ", "))"
        }
        
        if quote.isFavorite {
            md += " ⭐"
        }
        
        return md
    }
    
    private static func noteToMarkdown(_ note: Note) -> String {
        var md = "### \(note.title)\n\n"
        md += note.content + "\n"
        
        if let page = note.pageReference {
            md += "\n*Page \(page)*"
        }
        
        if let chapter = note.chapterReference {
            md += " • *\(chapter)*"
        }
        
        if !note.tags.isEmpty {
            md += "\n\n**Tags:** \(note.tags.joined(separator: ", "))"
        }
        
        if note.isPinned {
            md += " 📌"
        }
        
        md += "\n\n*Last modified: \(note.dateModified.formatted())*"
        
        return md
    }
    
    // MARK: - CSV Export
    
    private static func exportAsCSV(scope: ExportScope, context: ModelContext) throws -> Data {
        var csv = ""
        
        switch scope {
        case .allBooks:
            csv = "Title,Author,Genre,Year,Rating,Progress,Quotes,Notes\n"
            let books = try context.fetch(FetchDescriptor<Book>())
            for book in books {
                csv += "\"\(book.title)\","
                csv += "\"\(book.author)\","
                csv += "\"\(book.genre ?? "")\","
                csv += "\(book.publicationYear ?? 0),"
                csv += "\(book.rating ?? 0),"
                csv += "\(book.progressPercentage),"
                csv += "\(book.quotes?.count ?? 0),"
                csv += "\(book.notes?.count ?? 0)\n"
            }
            
        case .singleBook(let book):
            csv = "Type,Content,Page,Chapter,Date,Tags\n"
            
            if let quotes = book.quotes {
                for quote in quotes {
                    csv += "Quote,"
                    csv += "\"\(quote.text.replacingOccurrences(of: "\"", with: "\"\""))\","
                    csv += "\(quote.pageNumber ?? 0),"
                    csv += "\"\(quote.chapter ?? "")\","
                    csv += "\"\(quote.dateCreated.formatted())\","
                    csv += "\"\(quote.tags.joined(separator: "; "))\"\n"
                }
            }
            
            if let notes = book.notes {
                for note in notes {
                    csv += "Note,"
                    csv += "\"\(note.title): \(note.content.replacingOccurrences(of: "\"", with: "\"\""))\","
                    csv += "\(note.pageReference ?? 0),"
                    csv += "\"\(note.chapterReference ?? "")\","
                    csv += "\"\(note.dateModified.formatted())\","
                    csv += "\"\(note.tags.joined(separator: "; "))\"\n"
                }
            }
            
        case .quotes(let quotes):
            csv = "Text,Book,Page,Chapter,Date,Tags,Favorite\n"
            for quote in quotes {
                csv += "\"\(quote.text.replacingOccurrences(of: "\"", with: "\"\""))\","
                csv += "\"\(quote.book?.title ?? "")\","
                csv += "\(quote.pageNumber ?? 0),"
                csv += "\"\(quote.chapter ?? "")\","
                csv += "\"\(quote.dateCreated.formatted())\","
                csv += "\"\(quote.tags.joined(separator: "; "))\","
                csv += "\(quote.isFavorite ? "Yes" : "No")\n"
            }
            
        case .notes(let notes):
            csv = "Title,Content,Book,Page,Chapter,Date,Tags,Pinned\n"
            for note in notes {
                csv += "\"\(note.title)\","
                csv += "\"\(note.content.replacingOccurrences(of: "\"", with: "\"\""))\","
                csv += "\"\(note.book?.title ?? "")\","
                csv += "\(note.pageReference ?? 0),"
                csv += "\"\(note.chapterReference ?? "")\","
                csv += "\"\(note.dateModified.formatted())\","
                csv += "\"\(note.tags.joined(separator: "; "))\","
                csv += "\(note.isPinned ? "Yes" : "No")\n"
            }
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
}

// MARK: - Export Models

struct BookExportModel: Codable {
    let id: UUID
    let title: String
    let author: String
    let isbn: String?
    let genre: String?
    let publicationYear: Int?
    let publisher: String?
    let description: String?
    let rating: Int?
    let readingProgress: Double
    let totalPages: Int?
    let currentPage: Int?
    let dateAdded: Date
    let lastOpened: Date?
    let quotes: [QuoteExportModel]
    let notes: [NoteExportModel]
    
    init(from book: Book) {
        self.id = book.id
        self.title = book.title
        self.author = book.author
        self.isbn = book.isbn
        self.genre = book.genre
        self.publicationYear = book.publicationYear
        self.publisher = book.publisher
        self.description = book.bookDescription
        self.rating = book.rating
        self.readingProgress = book.readingProgress
        self.totalPages = book.totalPages
        self.currentPage = book.currentPage
        self.dateAdded = book.dateAdded
        self.lastOpened = book.lastOpened
        self.quotes = book.quotes?.map { QuoteExportModel(from: $0) } ?? []
        self.notes = book.notes?.map { NoteExportModel(from: $0) } ?? []
    }
}

struct QuoteExportModel: Codable {
    let id: UUID
    let text: String
    let pageNumber: Int?
    let chapter: String?
    let dateCreated: Date
    let notes: String?
    let isFavorite: Bool
    let tags: [String]
    let bookTitle: String?
    
    init(from quote: Quote) {
        self.id = quote.id
        self.text = quote.text
        self.pageNumber = quote.pageNumber
        self.chapter = quote.chapter
        self.dateCreated = quote.dateCreated
        self.notes = quote.notes
        self.isFavorite = quote.isFavorite
        self.tags = quote.tags
        self.bookTitle = quote.book?.title
    }
}

struct NoteExportModel: Codable {
    let id: UUID
    let title: String
    let content: String
    let dateCreated: Date
    let dateModified: Date
    let tags: [String]
    let pageReference: Int?
    let chapterReference: String?
    let isPinned: Bool
    let bookTitle: String?
    
    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.content = note.content
        self.dateCreated = note.dateCreated
        self.dateModified = note.dateModified
        self.tags = note.tags
        self.pageReference = note.pageReference
        self.chapterReference = note.chapterReference
        self.isPinned = note.isPinned
        self.bookTitle = note.book?.title
    }
}