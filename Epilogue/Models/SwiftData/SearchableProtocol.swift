import Foundation
import SwiftData

protocol SearchableContent {
    var searchableText: String { get }
    var searchableDate: Date { get }
    var searchableType: String { get }
}

extension Quote: SearchableContent {
    var searchableText: String {
        "\(text) \(notes ?? "") \(tags.joined(separator: " "))"
    }
    
    var searchableDate: Date {
        dateCreated
    }
    
    var searchableType: String {
        "Quote"
    }
}

extension Note: SearchableContent {
    var searchableText: String {
        "\(title) \(content) \(tags.joined(separator: " "))"
    }
    
    var searchableDate: Date {
        dateModified
    }
    
    var searchableType: String {
        "Note"
    }
}

struct SearchService {
    static func searchQuotes(
        _ searchText: String,
        in context: ModelContext,
        for book: Book? = nil
    ) throws -> [Quote] {
        let lowercasedSearch = searchText.lowercased()
        
        var descriptor = FetchDescriptor<Quote>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        
        if let book = book {
            descriptor.predicate = #Predicate<Quote> { quote in
                quote.book?.id == book.id &&
                (quote.text.localizedStandardContains(searchText) ||
                 (quote.notes != nil && quote.notes!.localizedStandardContains(searchText)) ||
                 quote.tags.contains { $0.localizedStandardContains(searchText) })
            }
        } else {
            descriptor.predicate = #Predicate<Quote> { quote in
                quote.text.localizedStandardContains(searchText) ||
                (quote.notes != nil && quote.notes!.localizedStandardContains(searchText)) ||
                quote.tags.contains { $0.localizedStandardContains(searchText) }
            }
        }
        
        return try context.fetch(descriptor)
    }
    
    static func searchNotes(
        _ searchText: String,
        in context: ModelContext,
        for book: Book? = nil
    ) throws -> [Note] {
        let lowercasedSearch = searchText.lowercased()
        
        var descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.dateModified, order: .reverse)]
        )
        
        if let book = book {
            descriptor.predicate = #Predicate<Note> { note in
                note.book?.id == book.id &&
                (note.title.localizedStandardContains(searchText) ||
                 note.content.localizedStandardContains(searchText) ||
                 note.tags.contains { $0.localizedStandardContains(searchText) })
            }
        } else {
            descriptor.predicate = #Predicate<Note> { note in
                note.title.localizedStandardContains(searchText) ||
                note.content.localizedStandardContains(searchText) ||
                note.tags.contains { $0.localizedStandardContains(searchText) }
            }
        }
        
        return try context.fetch(descriptor)
    }
    
    static func searchAll(
        _ searchText: String,
        in context: ModelContext,
        for book: Book? = nil
    ) throws -> (quotes: [Quote], notes: [Note]) {
        let quotes = try searchQuotes(searchText, in: context, for: book)
        let notes = try searchNotes(searchText, in: context, for: book)
        return (quotes, notes)
    }
}