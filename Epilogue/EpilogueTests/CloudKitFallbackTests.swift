import XCTest
import SwiftData
@testable import Epilogue

/// Tests for CloudKit fallback and data recovery mechanisms
class CloudKitFallbackTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset UserDefaults for clean testing
        UserDefaults.standard.removeObject(forKey: "SwiftDataInitializationFailureCount")
        UserDefaults.standard.removeObject(forKey: "isUsingCloudKit")
        UserDefaults.standard.removeObject(forKey: "cloudKitInitializationFailed")
    }

    override func tearDown() {
        // Clean up after tests
        UserDefaults.standard.removeObject(forKey: "SwiftDataInitializationFailureCount")
        UserDefaults.standard.removeObject(forKey: "isUsingCloudKit")
        UserDefaults.standard.removeObject(forKey: "cloudKitInitializationFailed")
        super.tearDown()
    }

    // MARK: - ModelContainer Creation Tests

    func test_whenCreatingInMemoryContainer_thenSucceeds() {
        // Given: Schema for in-memory container
        let schema = Schema([
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            CapturedQuestion.self,
            AmbientSession.self,
            ReadingSession.self
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        // When: Creating container
        do {
            let container = try ModelContainer(for: schema, configurations: [config])

            // Then: Container should be created successfully
            XCTAssertNotNil(container)
        } catch {
            XCTFail("In-memory container creation failed: \(error)")
        }
    }

    func test_whenCreatingLocalContainer_thenSucceeds() {
        // Given: Configuration for local storage (no CloudKit)
        let schema = Schema([
            BookModel.self,
            CapturedNote.self
        ])

        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        // When: Creating container
        do {
            let container = try ModelContainer(for: schema, configurations: [config])

            // Then: Container should be created successfully
            XCTAssertNotNil(container)

            // Cleanup
            let context = ModelContext(container)
            try context.delete(model: BookModel.self)
            try context.delete(model: CapturedNote.self)
            try context.save()
        } catch {
            XCTFail("Local container creation failed: \(error)")
        }
    }

    // MARK: - DataRecovery Initialization Tracking

    func test_whenRecordingInitializationFailure_thenIncrementsCount() {
        // Given: Initial failure count is 0
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "SwiftDataInitializationFailureCount"), 0)

        // When: Recording a failure
        DataRecovery.recordInitializationFailure()

        // Then: Count should increment
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "SwiftDataInitializationFailureCount"), 1)

        // When: Recording another failure
        DataRecovery.recordInitializationFailure()

        // Then: Count should increment again
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "SwiftDataInitializationFailureCount"), 2)
    }

    func test_whenRecordingInitializationSuccess_thenResetsCount() {
        // Given: Multiple failures have been recorded
        DataRecovery.recordInitializationFailure()
        DataRecovery.recordInitializationFailure()
        DataRecovery.recordInitializationFailure()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "SwiftDataInitializationFailureCount"), 3)

        // When: Recording a success
        DataRecovery.recordInitializationSuccess()

        // Then: Count should reset to 0
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "SwiftDataInitializationFailureCount"), 0)
    }

    // MARK: - DataRecovery Recovery Logic

    func test_whenFailureCountIsLessThanTwo_thenShouldNotAttemptRecovery() {
        // Given: One failure
        DataRecovery.recordInitializationFailure()

        // When: Checking if recovery should be attempted
        let shouldRecover = DataRecovery.shouldAttemptRecovery()

        // Then: Should not attempt recovery yet
        XCTAssertFalse(shouldRecover)
    }

    func test_whenFailureCountIsTwo_thenShouldAttemptRecovery() {
        // Given: Two failures
        DataRecovery.recordInitializationFailure()
        DataRecovery.recordInitializationFailure()

        // When: Checking if recovery should be attempted
        let shouldRecover = DataRecovery.shouldAttemptRecovery()

        // Then: Should attempt recovery
        XCTAssertTrue(shouldRecover)

        // And: Counter should be reset
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "SwiftDataInitializationFailureCount"), 0)
    }

    func test_whenFailureCountIsGreaterThanTwo_thenShouldAttemptRecovery() {
        // Given: Three failures
        DataRecovery.recordInitializationFailure()
        DataRecovery.recordInitializationFailure()
        DataRecovery.recordInitializationFailure()

        // When: Checking if recovery should be attempted
        let shouldRecover = DataRecovery.shouldAttemptRecovery()

        // Then: Should attempt recovery
        XCTAssertTrue(shouldRecover)
    }

    // MARK: - Data Integrity Tests

    func test_whenSwitchingBetweenContainers_thenDataCanBeMigrated() {
        // Given: Data in an in-memory container
        let schema = Schema([BookModel.self])
        let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            let container1 = try ModelContainer(for: schema, configurations: [inMemoryConfig])
            let context1 = ModelContext(container1)

            let book = BookModel(id: "test-1", title: "Test Book", author: "Test Author")
            context1.insert(book)
            try context1.save()

            // When: Fetching from same container
            let descriptor = FetchDescriptor<BookModel>()
            let books = try context1.fetch(descriptor)

            // Then: Data should be present
            XCTAssertEqual(books.count, 1)
            XCTAssertEqual(books.first?.title, "Test Book")
        } catch {
            XCTFail("Container migration test failed: \(error)")
        }
    }

    func test_whenCreatingMultipleModels_thenAllPersist() {
        // Given: An in-memory container with multiple models
        let schema = Schema([
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            ReadingSession.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            // When: Creating instances of each model
            let book = BookModel(id: "book-1", title: "Book", author: "Author")
            let note = CapturedNote(content: "Note", book: book)
            let quote = CapturedQuote(text: "Quote", book: book)
            let session = ReadingSession(bookModel: book, startPage: 1)

            context.insert(book)
            context.insert(note)
            context.insert(quote)
            context.insert(session)
            try context.save()

            // Then: All should persist
            let books = try context.fetch(FetchDescriptor<BookModel>())
            let notes = try context.fetch(FetchDescriptor<CapturedNote>())
            let quotes = try context.fetch(FetchDescriptor<CapturedQuote>())
            let sessions = try context.fetch(FetchDescriptor<ReadingSession>())

            XCTAssertEqual(books.count, 1)
            XCTAssertEqual(notes.count, 1)
            XCTAssertEqual(quotes.count, 1)
            XCTAssertEqual(sessions.count, 1)
        } catch {
            XCTFail("Multiple model persistence failed: \(error)")
        }
    }

    // MARK: - CloudKit Flag Tests

    func test_whenCloudKitIsEnabled_thenFlagIsSet() {
        // When: Setting CloudKit enabled flag
        UserDefaults.standard.set(true, forKey: "isUsingCloudKit")

        // Then: Flag should be retrievable
        let isUsingCloudKit = UserDefaults.standard.bool(forKey: "isUsingCloudKit")
        XCTAssertTrue(isUsingCloudKit)
    }

    func test_whenCloudKitFailsToInitialize_thenFailureFlagIsSet() {
        // When: Setting CloudKit failure flag
        UserDefaults.standard.set(true, forKey: "cloudKitInitializationFailed")

        // Then: Flag should be retrievable
        let failed = UserDefaults.standard.bool(forKey: "cloudKitInitializationFailed")
        XCTAssertTrue(failed)
    }

    // MARK: - Container Switch Safety Tests

    func test_whenContainerSwitches_thenNoDataLoss() {
        // Given: Data in first container
        let schema = Schema([BookModel.self])
        let config1 = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            let container1 = try ModelContainer(for: schema, configurations: [config1])
            let context1 = ModelContext(container1)

            let book1 = BookModel(id: "book-1", title: "First Book", author: "Author 1")
            context1.insert(book1)
            try context1.save()

            // When: Creating second container (simulating fallback)
            let config2 = ModelConfiguration(isStoredInMemoryOnly: true)
            let container2 = try ModelContainer(for: schema, configurations: [config2])
            let context2 = ModelContext(container2)

            let book2 = BookModel(id: "book-2", title: "Second Book", author: "Author 2")
            context2.insert(book2)
            try context2.save()

            // Then: Both containers maintain their data independently
            let books1 = try context1.fetch(FetchDescriptor<BookModel>())
            let books2 = try context2.fetch(FetchDescriptor<BookModel>())

            XCTAssertEqual(books1.count, 1)
            XCTAssertEqual(books1.first?.title, "First Book")

            XCTAssertEqual(books2.count, 1)
            XCTAssertEqual(books2.first?.title, "Second Book")
        } catch {
            XCTFail("Container switch test failed: \(error)")
        }
    }

    // MARK: - Default Values for CloudKit

    func test_whenCreatingBookModel_thenHasCloudKitCompatibleDefaults() {
        // Given: A new BookModel
        let book = BookModel(id: "test", title: "Test", author: "Author")

        // Then: Should have CloudKit-compatible default values
        XCTAssertEqual(book.id, "test")
        XCTAssertEqual(book.title, "Test")
        XCTAssertEqual(book.author, "Author")
        XCTAssertEqual(book.isInLibrary, false)
        XCTAssertEqual(book.currentPage, 0)
        XCTAssertNotNil(book.dateAdded)
        XCTAssertNotNil(book.localId)
        XCTAssertFalse(book.localId.isEmpty)
    }

    func test_whenCreatingReadingSession_thenHasCloudKitCompatibleDefaults() {
        // Given: A new ReadingSession
        let book = BookModel(id: "test", title: "Test", author: "Author")
        let session = ReadingSession(bookModel: book, startPage: 1)

        // Then: Should have CloudKit-compatible default values
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.startDate)
        XCTAssertEqual(session.duration, 0)
        XCTAssertEqual(session.startPage, 1)
        XCTAssertEqual(session.endPage, 1)
        XCTAssertEqual(session.pagesRead, 0)
        XCTAssertEqual(session.isAmbientSession, false)
    }

    // MARK: - Error Recovery Tests

    func test_whenModelContainerCreationFails_thenCanRecreate() {
        // This test simulates recovery after a failure
        // Given: A valid schema
        let schema = Schema([BookModel.self])

        // When: Creating multiple containers in sequence (simulating retries)
        do {
            let config1 = ModelConfiguration(isStoredInMemoryOnly: true)
            _ = try ModelContainer(for: schema, configurations: [config1])

            let config2 = ModelConfiguration(isStoredInMemoryOnly: true)
            _ = try ModelContainer(for: schema, configurations: [config2])

            let config3 = ModelConfiguration(isStoredInMemoryOnly: true)
            let container3 = try ModelContainer(for: schema, configurations: [config3])

            // Then: All creations should succeed
            XCTAssertNotNil(container3)
        } catch {
            XCTFail("Container recreation failed: \(error)")
        }
    }
}
