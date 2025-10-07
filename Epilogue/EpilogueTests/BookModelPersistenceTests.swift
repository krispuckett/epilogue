import XCTest
import SwiftData
@testable import Epilogue

/// Tests for SwiftData persistence and data integrity of BookModel
class BookModelPersistenceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() {
        super.setUp()

        // Create an in-memory model container for testing
        let schema = Schema([
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            CapturedQuestion.self,
            AmbientSession.self,
            ReadingSession.self
        ])

        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create model container for testing: \(error)")
        }
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Basic Persistence Tests

    func test_whenSavingBook_thenCanFetchItBack() {
        // Given: A new book model
        let book = BookModel(
            id: "test-123",
            title: "The Hobbit",
            author: "J.R.R. Tolkien",
            publishedYear: "1937",
            coverImageURL: "https://example.com/cover.jpg",
            isbn: "9780547928227",
            description: "A fantasy novel",
            pageCount: 310
        )

        // When: Saving to context
        modelContext.insert(book)

        do {
            try modelContext.save()

            // Then: Should be able to fetch it back
            let descriptor = FetchDescriptor<BookModel>()
            let fetchedBooks = try modelContext.fetch(descriptor)

            XCTAssertEqual(fetchedBooks.count, 1, "Should fetch exactly one book")
            XCTAssertEqual(fetchedBooks.first?.title, "The Hobbit")
            XCTAssertEqual(fetchedBooks.first?.author, "J.R.R. Tolkien")
            XCTAssertEqual(fetchedBooks.first?.id, "test-123")
        } catch {
            XCTFail("Failed to save or fetch book: \(error)")
        }
    }

    func test_whenSavingMultipleBooks_thenCanFetchAll() {
        // Given: Multiple books
        let book1 = BookModel(id: "1", title: "Book One", author: "Author One")
        let book2 = BookModel(id: "2", title: "Book Two", author: "Author Two")
        let book3 = BookModel(id: "3", title: "Book Three", author: "Author Three")

        // When: Saving all to context
        modelContext.insert(book1)
        modelContext.insert(book2)
        modelContext.insert(book3)

        do {
            try modelContext.save()

            // Then: Should fetch all three
            let descriptor = FetchDescriptor<BookModel>()
            let fetchedBooks = try modelContext.fetch(descriptor)

            XCTAssertEqual(fetchedBooks.count, 3, "Should fetch all three books")
        } catch {
            XCTFail("Failed to save or fetch books: \(error)")
        }
    }

    // MARK: - Optional Fields Tests

    func test_whenOptionalFieldsAreNil_thenDoesNotCrash() {
        // Given: A book with minimal required fields only
        let book = BookModel(
            id: "minimal-book",
            title: "Minimal Book",
            author: "Unknown Author",
            publishedYear: nil,
            coverImageURL: nil,
            isbn: nil,
            description: nil,
            pageCount: nil
        )

        // When: Saving and fetching
        modelContext.insert(book)

        do {
            try modelContext.save()

            let descriptor = FetchDescriptor<BookModel>()
            let fetchedBooks = try modelContext.fetch(descriptor)

            // Then: Should handle nil fields gracefully
            XCTAssertNotNil(fetchedBooks.first)
            XCTAssertNil(fetchedBooks.first?.publishedYear)
            XCTAssertNil(fetchedBooks.first?.coverImageURL)
            XCTAssertNil(fetchedBooks.first?.isbn)
            XCTAssertNil(fetchedBooks.first?.desc)
            XCTAssertNil(fetchedBooks.first?.pageCount)
        } catch {
            XCTFail("Failed to handle nil optional fields: \(error)")
        }
    }

    // MARK: - Relationship Tests

    func test_whenAddingNotes_thenRelationshipPersists() {
        // Given: A book with notes
        let book = BookModel(id: "book-with-notes", title: "Test Book", author: "Test Author")
        let note1 = CapturedNote(content: "First note", book: book)
        let note2 = CapturedNote(content: "Second note", book: book)

        // When: Saving
        modelContext.insert(book)
        modelContext.insert(note1)
        modelContext.insert(note2)

        do {
            try modelContext.save()

            // Then: Relationship should persist
            let descriptor = FetchDescriptor<BookModel>()
            let fetchedBooks = try modelContext.fetch(descriptor)

            XCTAssertEqual(fetchedBooks.first?.notes?.count, 2, "Should have 2 notes")
            XCTAssertTrue(fetchedBooks.first?.notes?.contains(where: { $0.content == "First note" }) ?? false)
            XCTAssertTrue(fetchedBooks.first?.notes?.contains(where: { $0.content == "Second note" }) ?? false)
        } catch {
            XCTFail("Failed to persist notes relationship: \(error)")
        }
    }

    func test_whenAddingQuotes_thenRelationshipPersists() {
        // Given: A book with quotes
        let book = BookModel(id: "book-with-quotes", title: "Quotable Book", author: "Wise Author")
        let quote1 = CapturedQuote(text: "First quote", book: book)
        let quote2 = CapturedQuote(text: "Second quote", book: book)

        // When: Saving
        modelContext.insert(book)
        modelContext.insert(quote1)
        modelContext.insert(quote2)

        do {
            try modelContext.save()

            // Then: Relationship should persist
            let descriptor = FetchDescriptor<BookModel>()
            let fetchedBooks = try modelContext.fetch(descriptor)

            XCTAssertEqual(fetchedBooks.first?.quotes?.count, 2, "Should have 2 quotes")
        } catch {
            XCTFail("Failed to persist quotes relationship: \(error)")
        }
    }

    func test_whenDeletingBook_thenCascadeDeletesRelatedItems() {
        // Given: A book with notes, quotes, and sessions
        let book = BookModel(id: "book-to-delete", title: "Deletable Book", author: "Author")
        let note = CapturedNote(content: "Note", book: book)
        let quote = CapturedQuote(text: "Quote", book: book)
        let session = ReadingSession(bookModel: book, startPage: 1)

        modelContext.insert(book)
        modelContext.insert(note)
        modelContext.insert(quote)
        modelContext.insert(session)

        do {
            try modelContext.save()

            // When: Deleting the book
            modelContext.delete(book)
            try modelContext.save()

            // Then: Related items should be cascade deleted
            let noteDescriptor = FetchDescriptor<CapturedNote>()
            let quoteDescriptor = FetchDescriptor<CapturedQuote>()
            let sessionDescriptor = FetchDescriptor<ReadingSession>()

            let notes = try modelContext.fetch(noteDescriptor)
            let quotes = try modelContext.fetch(quoteDescriptor)
            let sessions = try modelContext.fetch(sessionDescriptor)

            XCTAssertEqual(notes.count, 0, "Notes should be cascade deleted")
            XCTAssertEqual(quotes.count, 0, "Quotes should be cascade deleted")
            XCTAssertEqual(sessions.count, 0, "Sessions should be cascade deleted")
        } catch {
            XCTFail("Cascade delete failed: \(error)")
        }
    }

    // MARK: - Cover URL Persistence Tests

    func test_whenCoverURLSet_thenPersistsCorrectly() {
        // Given: A book with a cover URL
        let coverURL = "https://books.google.com/books/cover.jpg"
        let book = BookModel(
            id: "book-with-cover",
            title: "Book With Cover",
            author: "Author",
            coverImageURL: coverURL
        )

        // When: Saving and fetching
        modelContext.insert(book)

        do {
            try modelContext.save()

            let descriptor = FetchDescriptor<BookModel>()
            let fetchedBooks = try modelContext.fetch(descriptor)

            // Then: Cover URL should persist
            XCTAssertEqual(fetchedBooks.first?.coverImageURL, coverURL)
            XCTAssertNotNil(fetchedBooks.first?.coverImageURL)
        } catch {
            XCTFail("Cover URL persistence failed: \(error)")
        }
    }

    // MARK: - asBook Conversion Tests

    func test_whenConvertingToBook_thenPreservesAllData() {
        // Given: A fully populated BookModel
        let bookModel = BookModel(
            id: "conversion-test",
            title: "Conversion Test Book",
            author: "Test Author",
            publishedYear: "2024",
            coverImageURL: "https://example.com/cover.jpg",
            isbn: "1234567890",
            description: "Test description",
            pageCount: 300
        )
        bookModel.userRating = 5
        bookModel.userNotes = "Great book!"
        bookModel.currentPage = 150
        bookModel.readingStatus = ReadingStatus.currentlyReading.rawValue

        // When: Converting to Book struct
        let book = bookModel.asBook

        // Then: All data should be preserved
        XCTAssertEqual(book.id, "conversion-test")
        XCTAssertEqual(book.title, "Conversion Test Book")
        XCTAssertEqual(book.author, "Test Author")
        XCTAssertEqual(book.publishedYear, "2024")
        XCTAssertEqual(book.coverImageURL, "https://example.com/cover.jpg")
        XCTAssertEqual(book.isbn, "1234567890")
        XCTAssertEqual(book.description, "Test description")
        XCTAssertEqual(book.pageCount, 300)
        XCTAssertEqual(book.userRating, 5)
        XCTAssertEqual(book.userNotes, "Great book!")
        XCTAssertEqual(book.currentPage, 150)
        XCTAssertEqual(book.readingStatus, .currentlyReading)
    }

    func test_whenConvertingFromBook_thenCreatesValidBookModel() {
        // Given: A Book struct
        var book = Book(
            id: "struct-test",
            title: "Struct Book",
            author: "Struct Author",
            publishedYear: "2023",
            coverImageURL: "https://example.com/cover.jpg",
            isbn: "0987654321",
            description: "Book description",
            pageCount: 250
        )
        book.userRating = 4
        book.isInLibrary = true

        // When: Creating BookModel from Book
        let bookModel = BookModel(from: book)

        // Then: BookModel should match Book data
        XCTAssertEqual(bookModel.id, "struct-test")
        XCTAssertEqual(bookModel.title, "Struct Book")
        XCTAssertEqual(bookModel.author, "Struct Author")
        XCTAssertEqual(bookModel.coverImageURL, "https://example.com/cover.jpg")
        XCTAssertEqual(bookModel.userRating, 4)
        XCTAssertEqual(bookModel.isInLibrary, true)
    }

    // MARK: - Reading Status Tests

    func test_whenSettingReadingStatus_thenPersistsCorrectly() {
        // Given: Books with different reading statuses
        let wantToReadBook = BookModel(id: "1", title: "Want to Read", author: "Author")
        wantToReadBook.readingStatus = ReadingStatus.wantToRead.rawValue

        let currentlyReadingBook = BookModel(id: "2", title: "Currently Reading", author: "Author")
        currentlyReadingBook.readingStatus = ReadingStatus.currentlyReading.rawValue

        let readBook = BookModel(id: "3", title: "Read", author: "Author")
        readBook.readingStatus = ReadingStatus.read.rawValue

        // When: Saving
        modelContext.insert(wantToReadBook)
        modelContext.insert(currentlyReadingBook)
        modelContext.insert(readBook)

        do {
            try modelContext.save()

            // Then: Reading statuses should persist
            let descriptor = FetchDescriptor<BookModel>()
            let books = try modelContext.fetch(descriptor)

            XCTAssertTrue(books.contains(where: { $0.readingStatus == ReadingStatus.wantToRead.rawValue }))
            XCTAssertTrue(books.contains(where: { $0.readingStatus == ReadingStatus.currentlyReading.rawValue }))
            XCTAssertTrue(books.contains(where: { $0.readingStatus == ReadingStatus.read.rawValue }))
        } catch {
            XCTFail("Reading status persistence failed: \(error)")
        }
    }

    // MARK: - Enrichment Tests

    func test_whenBookIsEnriched_thenIsEnrichedReturnsTrue() {
        // Given: An enriched book
        let book = BookModel(id: "enriched", title: "Enriched Book", author: "Author")
        book.smartSynopsis = "A thoughtful exploration of themes"
        book.keyThemes = ["friendship", "courage"]

        // When: Checking enrichment status
        let isEnriched = book.isEnriched

        // Then: Should be marked as enriched
        XCTAssertTrue(isEnriched)
    }

    func test_whenBookNotEnriched_thenIsEnrichedReturnsFalse() {
        // Given: A non-enriched book
        let book = BookModel(id: "not-enriched", title: "Plain Book", author: "Author")

        // When: Checking enrichment status
        let isEnriched = book.isEnriched

        // Then: Should not be marked as enriched
        XCTAssertFalse(isEnriched)
    }
}
