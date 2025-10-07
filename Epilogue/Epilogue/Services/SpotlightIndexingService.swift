import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers
import SwiftUI

/// Service for indexing books, notes, and quotes in iOS Spotlight Search
@MainActor
class SpotlightIndexingService {
    static let shared = SpotlightIndexingService()

    private init() {}

    // MARK: - Domain Identifiers

    private enum Domain {
        static let books = "com.epilogue.books"
        static let notes = "com.epilogue.notes"
        static let quotes = "com.epilogue.quotes"
    }

    // MARK: - Book Indexing

    /// Index a book for Spotlight search
    func indexBook(_ book: Book, coverImage: UIImage? = nil) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        // Basic info
        attributeSet.title = book.title
        attributeSet.contentDescription = book.description ?? "by \(book.author)"
        attributeSet.displayName = book.title

        // Author as creator
        attributeSet.creator = book.author

        // Keywords for better search
        var keywords = [book.title, book.author]
        if let isbn = book.isbn {
            keywords.append(isbn)
        }
        if let year = book.publishedYear {
            keywords.append(year)
        }
        keywords.append(book.readingStatus.rawValue)
        attributeSet.keywords = keywords

        // Cover image as thumbnail
        if let coverImage = coverImage,
           let thumbnailData = coverImage.jpegData(compressionQuality: 0.7) {
            attributeSet.thumbnailData = thumbnailData
        }

        // Reading progress info
        if let pageCount = book.pageCount {
            attributeSet.comment = "Page \(book.currentPage) of \(pageCount)"
        }

        // Rating
        if let rating = book.userRating {
            attributeSet.rating = NSNumber(value: rating)
        }

        // Date added
        attributeSet.contentCreationDate = book.dateAdded
        attributeSet.contentModificationDate = book.dateAdded

        // Deep link URL
        let deepLinkURL = "epilogue://book/\(book.id)"
        attributeSet.contentURL = URL(string: deepLinkURL)

        // Create searchable item
        let item = CSSearchableItem(
            uniqueIdentifier: "book-\(book.id)",
            domainIdentifier: Domain.books,
            attributeSet: attributeSet
        )

        // Index the item
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("❌ Spotlight: Failed to index book '\(book.title)': \(error.localizedDescription)")
            } else {
                print("✅ Spotlight: Indexed book '\(book.title)'")
            }
        }
    }

    /// Index multiple books at once
    func indexBooks(_ books: [Book], coverImages: [String: UIImage] = [:]) {
        let items = books.map { book -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

            attributeSet.title = book.title
            attributeSet.contentDescription = book.description ?? "by \(book.author)"
            attributeSet.displayName = book.title
            attributeSet.creator = book.author

            var keywords = [book.title, book.author]
            if let isbn = book.isbn {
                keywords.append(isbn)
            }
            if let year = book.publishedYear {
                keywords.append(year)
            }
            keywords.append(book.readingStatus.rawValue)
            attributeSet.keywords = keywords

            if let coverImage = coverImages[book.id],
               let thumbnailData = coverImage.jpegData(compressionQuality: 0.7) {
                attributeSet.thumbnailData = thumbnailData
            }

            if let pageCount = book.pageCount {
                attributeSet.comment = "Page \(book.currentPage) of \(pageCount)"
            }

            if let rating = book.userRating {
                attributeSet.rating = NSNumber(value: rating)
            }

            attributeSet.contentCreationDate = book.dateAdded
            attributeSet.contentModificationDate = book.dateAdded

            let deepLinkURL = "epilogue://book/\(book.id)"
            attributeSet.contentURL = URL(string: deepLinkURL)

            return CSSearchableItem(
                uniqueIdentifier: "book-\(book.id)",
                domainIdentifier: Domain.books,
                attributeSet: attributeSet
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("❌ Spotlight: Failed to batch index books: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight: Indexed \(books.count) books")
            }
        }
    }

    /// Remove a book from Spotlight index
    func deindexBook(_ bookId: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["book-\(bookId)"]) { error in
            if let error = error {
                print("❌ Spotlight: Failed to deindex book: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight: Deindexed book \(bookId)")
            }
        }
    }

    // MARK: - Note Indexing

    /// Index a note for Spotlight search
    func indexNote(_ note: CapturedNote) {
        guard let content = note.content, !content.isEmpty else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        // Note content as title
        let preview = content.prefix(100)
        attributeSet.title = String(preview)
        attributeSet.contentDescription = content
        attributeSet.textContent = content

        // Book context
        if let book = note.book {
            attributeSet.creator = "Note from \(book.title)"
            attributeSet.keywords = [book.title, book.author, "note"]
            attributeSet.relatedUniqueIdentifier = "book-\(book.id)"
        } else {
            attributeSet.keywords = ["note"]
        }

        // Timestamp
        if let timestamp = note.timestamp {
            attributeSet.contentCreationDate = timestamp
            attributeSet.contentModificationDate = timestamp
        }

        // Deep link
        if let noteId = note.id {
            let deepLinkURL = "epilogue://note/\(noteId.uuidString)"
            attributeSet.contentURL = URL(string: deepLinkURL)
        }

        let item = CSSearchableItem(
            uniqueIdentifier: "note-\(note.id?.uuidString ?? UUID().uuidString)",
            domainIdentifier: Domain.notes,
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("❌ Spotlight: Failed to index note: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight: Indexed note")
            }
        }
    }

    /// Remove a note from Spotlight index
    func deindexNote(_ noteId: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["note-\(noteId.uuidString)"]) { error in
            if let error = error {
                print("❌ Spotlight: Failed to deindex note: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight: Deindexed note")
            }
        }
    }

    // MARK: - Quote Indexing

    /// Index a quote for Spotlight search
    func indexQuote(_ quote: CapturedQuote) {
        guard let text = quote.text, !text.isEmpty else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        // Quote text as title
        let preview = text.prefix(100)
        attributeSet.title = "\"\(preview)...\""
        attributeSet.contentDescription = text
        attributeSet.textContent = text

        // Attribution
        if let author = quote.author {
            attributeSet.creator = author
            attributeSet.keywords = [author, "quote"]
        } else {
            attributeSet.keywords = ["quote"]
        }

        // Book context
        if let book = quote.book {
            attributeSet.keywords?.append(contentsOf: [book.title, book.author])
            attributeSet.relatedUniqueIdentifier = "book-\(book.id)"
        }

        // Page number
        if let pageNumber = quote.pageNumber {
            attributeSet.comment = "Page \(pageNumber)"
        }

        // Timestamp
        if let timestamp = quote.timestamp {
            attributeSet.contentCreationDate = timestamp
            attributeSet.contentModificationDate = timestamp
        }

        // Deep link
        if let quoteId = quote.id {
            let deepLinkURL = "epilogue://quote/\(quoteId.uuidString)"
            attributeSet.contentURL = URL(string: deepLinkURL)
        }

        let item = CSSearchableItem(
            uniqueIdentifier: "quote-\(quote.id?.uuidString ?? UUID().uuidString)",
            domainIdentifier: Domain.quotes,
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("❌ Spotlight: Failed to index quote: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight: Indexed quote")
            }
        }
    }

    /// Remove a quote from Spotlight index
    func deindexQuote(_ quoteId: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["quote-\(quoteId.uuidString)"]) { error in
            if let error = error {
                print("❌ Spotlight: Failed to deindex quote: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight: Deindexed quote")
            }
        }
    }

    // MARK: - Bulk Operations

    /// Reindex all books, notes, and quotes (call on app launch or after major changes)
    func reindexAll(books: [Book], notes: [CapturedNote], quotes: [CapturedQuote]) {
        print("🔍 Spotlight: Starting full reindex...")

        // Clear existing indices
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                print("❌ Spotlight: Failed to clear index: \(error.localizedDescription)")
            }
        }

        // Reindex books
        indexBooks(books)

        // Reindex notes
        for note in notes {
            indexNote(note)
        }

        // Reindex quotes
        for quote in quotes {
            indexQuote(quote)
        }

        print("✅ Spotlight: Reindexed \(books.count) books, \(notes.count) notes, \(quotes.count) quotes")
    }

    /// Clear all Spotlight indices
    func clearAllIndices() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                print("❌ Spotlight: Failed to clear all indices: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight: Cleared all indices")
            }
        }
    }
}
