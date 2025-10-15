import Foundation
import SwiftData
import SwiftUI

// MARK: - Data Migration Service
/// Handles seamless migration from old schema (Book, Quote, Note) to new schema (BookModel, CapturedNote, CapturedQuote)
@MainActor
final class DataMigrationService {
    static let shared = DataMigrationService()
    
    private let migrationKey = "com.epilogue.dataMigrationCompleted.v2"
    private let migrationInProgressKey = "com.epilogue.dataMigrationInProgress"
    
    private init() {}
    
    /// Main migration entry point - checks and performs migration if needed
    func performMigrationIfNeeded(newContainer: ModelContainer) async {
        // Check if recovery is needed
        if MigrationRecovery.shared.shouldAttemptRecovery() {
            #if DEBUG
            print("🔄 Attempting migration recovery...")
            #endif
            MigrationRecovery.shared.resetMigrationState()
        }
        
        // Skip if already migrated
        if UserDefaults.standard.bool(forKey: migrationKey) {
            #if DEBUG
            print("✅ Data migration already completed")
            #endif
            return
        }
        
        // Prevent duplicate migrations
        if UserDefaults.standard.bool(forKey: migrationInProgressKey) {
            #if DEBUG
            print("⚠️ Migration already in progress, skipping")
            #endif
            return
        }
        
        // Create pre-migration backup
        MigrationRecovery.shared.createPreMigrationBackup()
        
        // Set migration in progress flag
        UserDefaults.standard.set(true, forKey: migrationInProgressKey)
        
        do {
            // Check if old data exists
            if await hasOldData() {
                #if DEBUG
                print("🔄 Old data detected, starting migration...")
                #endif
                let oldContainer = createOldSchemaContainer()
                try await migrateData(to: newContainer)
                
                // Validate migration results
                let validation = await MigrationRecovery.shared.validateMigrationResults(
                    oldContainer: oldContainer,
                    newContainer: newContainer
                )
                
                switch validation {
                case .success:
                    // Mark migration as complete
                    UserDefaults.standard.set(true, forKey: migrationKey)
                    #if DEBUG
                    print("✅ Migration completed and validated successfully")
                    #endif
                    
                case .dataLoss:
                    #if DEBUG
                    print("⚠️ Warning: \(validation.description)")
                    #endif
                    // Still mark as complete but log the issue
                    UserDefaults.standard.set(true, forKey: migrationKey)
                    
                default:
                    #if DEBUG
                    print("❌ Migration validation failed: \(validation.description)")
                    #endif
                    throw MigrationError.validationFailed
                }
            } else {
                #if DEBUG
                print("ℹ️ No old data found, skipping migration")
                #endif
                UserDefaults.standard.set(true, forKey: migrationKey)
            }
        } catch {
            #if DEBUG
            print("❌ Migration failed: \(error)")
            #endif
            // Don't mark as complete so it can be retried
            
            // Send a notification to user about migration failure
            await notifyUserOfMigrationFailure(error: error)
        }
        
        // Clear in-progress flag
        UserDefaults.standard.set(false, forKey: migrationInProgressKey)
    }
    
    /// Checks if there's any old data that needs migration
    private func hasOldData() async -> Bool {
        // Try to create a container with the old schema
        guard let oldContainer = createOldSchemaContainer() else {
            return false
        }
        
        let context = oldContainer.mainContext
        
        // Check for any old books
        let bookDescriptor = FetchDescriptor<LegacyBook>(
            predicate: nil,
            sortBy: []
        )
        
        do {
            let books = try context.fetch(bookDescriptor)
            return !books.isEmpty
        } catch {
            #if DEBUG
            print("⚠️ Error checking for old data: \(error)")
            #endif
            return false
        }
    }
    
    /// Creates a ModelContainer with the old schema
    private func createOldSchemaContainer() -> ModelContainer? {
        let oldSchema = Schema([
            LegacyBook.self,
            LegacyQuote.self,
            LegacyNote.self,
            LegacyAISession.self,
            LegacyAIMessage.self,
            LegacyUsageTracking.self,
            LegacyReadingSession.self
        ])
        
        let configuration = ModelConfiguration(
            schema: oldSchema,
            isStoredInMemoryOnly: false,
            allowsSave: false // Read-only access
        )
        
        do {
            return try ModelContainer(for: oldSchema, configurations: [configuration])
        } catch {
            #if DEBUG
            print("⚠️ Could not create old schema container: \(error)")
            #endif
            return nil
        }
    }
    
    /// Performs the actual data migration
    private func migrateData(to newContainer: ModelContainer) async throws {
        guard let oldContainer = createOldSchemaContainer() else {
            throw MigrationError.oldContainerCreationFailed
        }
        
        let oldContext = oldContainer.mainContext
        let newContext = newContainer.mainContext
        
        // Track migration statistics
        var stats = MigrationStats()
        
        // 1. Fetch all old books
        let bookDescriptor = FetchDescriptor<LegacyBook>(
            sortBy: [SortDescriptor(\.dateAdded)]
        )
        let oldBooks = try oldContext.fetch(bookDescriptor)
        stats.totalBooks = oldBooks.count
        
        #if DEBUG
        print("📚 Found \(oldBooks.count) books to migrate")
        #endif
        
        // 2. Migrate each book
        var bookMapping: [UUID: BookModel] = [:]
        
        for oldBook in oldBooks {
            do {
                let newBook = try migrateBook(oldBook, context: newContext)
                bookMapping[oldBook.id] = newBook
                stats.migratedBooks += 1
                
                // Migrate related data
                if let quotes = oldBook.quotes {
                    for oldQuote in quotes {
                        if let migratedQuote = try? migrateQuote(oldQuote, to: newBook, context: newContext) {
                            stats.migratedQuotes += 1
                        } else {
                            stats.failedQuotes += 1
                        }
                    }
                }
                
                if let notes = oldBook.notes {
                    for oldNote in notes {
                        if let migratedNote = try? migrateNote(oldNote, to: newBook, context: newContext) {
                            stats.migratedNotes += 1
                        } else {
                            stats.failedNotes += 1
                        }
                    }
                }
                
                // Migrate AI Sessions
                if let aiSessions = oldBook.aiSessions {
                    for oldSession in aiSessions {
                        if let _ = try? migrateAISession(oldSession, to: newBook, context: newContext) {
                            stats.migratedAISessions += 1
                        } else {
                            stats.failedAISessions += 1
                        }
                    }
                }
                
            } catch {
                #if DEBUG
                print("❌ Failed to migrate book '\(oldBook.title)': \(error)")
                #endif
                stats.failedBooks += 1
            }
        }
        
        // 3. Migrate orphaned quotes (quotes without books)
        await migrateOrphanedQuotes(oldContext: oldContext, newContext: newContext, stats: &stats)
        
        // 4. Migrate orphaned notes
        await migrateOrphanedNotes(oldContext: oldContext, newContext: newContext, stats: &stats)
        
        // 5. Save all changes
        try newContext.save()
        
        // 6. Log migration results
        logMigrationResults(stats)
        
        // 7. Verify migration
        try await verifyMigration(oldContainer: oldContainer, newContainer: newContainer, stats: stats)
    }
    
    /// Migrates a single book
    private func migrateBook(_ oldBook: LegacyBook, context: ModelContext) throws -> BookModel {
        // Create new book model
        let newBook = BookModel(
            id: oldBook.id.uuidString, // Use UUID as Google Books ID fallback
            title: oldBook.title,
            author: oldBook.author,
            publishedYear: oldBook.publicationYear.map { String($0) },
            coverImageURL: nil, // Will need to handle image migration separately
            isbn: oldBook.isbn,
            description: oldBook.bookDescription,
            pageCount: oldBook.totalPages,
            localId: oldBook.id.uuidString
        )
        
        // Map reading status
        newBook.readingStatus = mapReadingStatus(from: oldBook)
        newBook.currentPage = oldBook.currentPage ?? 0
        newBook.userRating = oldBook.rating
        newBook.userNotes = nil // Old model doesn't have this
        newBook.dateAdded = oldBook.dateAdded
        newBook.isInLibrary = true // All old books are in library
        
        // Insert into context
        context.insert(newBook)
        
        // Handle cover image data migration
        if let imageData = oldBook.coverImageData {
            Task.detached { [weak self] in
                await self?.migrateCoverImage(imageData: imageData, for: newBook)
            }
        }
        
        return newBook
    }
    
    /// Maps reading status from old progress-based system to new enum
    private func mapReadingStatus(from oldBook: LegacyBook) -> String {
        if oldBook.readingProgress >= 0.95 {
            return ReadingStatus.read.rawValue
        } else if oldBook.readingProgress > 0 {
            return ReadingStatus.currentlyReading.rawValue
        } else {
            return ReadingStatus.wantToRead.rawValue
        }
    }
    
    /// Migrates a quote
    private func migrateQuote(_ oldQuote: LegacyQuote, to newBook: BookModel, context: ModelContext) throws -> CapturedQuote {
        let newQuote = CapturedQuote(
            text: oldQuote.text,
            book: newBook,
            author: newBook.author,
            pageNumber: oldQuote.pageNumber,
            timestamp: oldQuote.dateCreated,
            source: .import_,
            notes: oldQuote.notes
        )
        
        // Map additional properties
        if oldQuote.isFavorite {
            newQuote.notes = (newQuote.notes ?? "") + " [Favorite]"
        }
        
        // Handle tags
        if !oldQuote.tags.isEmpty {
            let tagString = oldQuote.tags.joined(separator: ", ")
            newQuote.notes = (newQuote.notes ?? "") + " Tags: \(tagString)"
        }
        
        context.insert(newQuote)
        return newQuote
    }
    
    /// Migrates a note
    private func migrateNote(_ oldNote: LegacyNote, to newBook: BookModel, context: ModelContext) throws -> CapturedNote {
        let content = oldNote.title.isEmpty ? oldNote.content : "\(oldNote.title)\n\n\(oldNote.content)"
        
        let newNote = CapturedNote(
            content: content,
            book: newBook,
            pageNumber: oldNote.pageReference,
            timestamp: oldNote.dateCreated,
            source: .import_,
            tags: oldNote.tags
        )
        
        // Handle pinned notes
        if oldNote.isPinned {
            newNote.tags?.append("pinned")
        }
        
        context.insert(newNote)
        return newNote
    }
    
    /// Migrates cover image data to file system
    private func migrateCoverImage(imageData: Data, for book: BookModel) async {
        // Save to the same location where new system expects images
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagesPath = documentsPath.appendingPathComponent("BookCovers")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
        
        let imagePath = imagesPath.appendingPathComponent("\(book.localId).jpg")
        
        do {
            try imageData.write(to: imagePath)
            #if DEBUG
            print("✅ Migrated cover image for '\(book.title)'")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to migrate cover image for '\(book.title)': \(error)")
            #endif
        }
    }
    
    /// Migrates AI sessions
    private func migrateAISession(_ oldSession: LegacyAISession, to newBook: BookModel, context: ModelContext) throws -> AmbientSession {
        // Create new ambient session
        let newSession = AmbientSession()
        newSession.startTime = oldSession.dateCreated
        newSession.endTime = oldSession.lastAccessed
        newSession.bookModel = newBook
        
        // Initialize relationships if nil
        if newSession.capturedQuestions == nil {
            newSession.capturedQuestions = []
        }
        
        // Convert AI messages to captured questions/notes
        if let messages = oldSession.messages {
            for (index, message) in messages.enumerated() {
                if message.role == .user {
                    // User messages become questions
                    let question = CapturedQuestion(
                        content: message.content,
                        book: newBook,
                        timestamp: message.timestamp,
                        source: .import_
                    )
                    
                    // If there's a following assistant message, use it as the answer
                    if index + 1 < messages.count,
                       messages[index + 1].role == .assistant {
                        question.answer = messages[index + 1].content
                        question.isAnswered = true
                    }
                    
                    context.insert(question)
                    newSession.capturedQuestions?.append(question)
                }
            }
        }
        
        // Generate insight based on session type
        newSession.generatedInsight = "Migrated from \(oldSession.sessionType.rawValue) session: \(oldSession.title)"
        
        context.insert(newSession)
        return newSession
    }
    
    /// Migrates orphaned quotes
    private func migrateOrphanedQuotes(oldContext: ModelContext, newContext: ModelContext, stats: inout MigrationStats) async {
        do {
            let descriptor = FetchDescriptor<LegacyQuote>(
                predicate: #Predicate { quote in
                    quote.book == nil
                }
            )
            
            let orphanedQuotes = try oldContext.fetch(descriptor)
            
            if !orphanedQuotes.isEmpty {
                #if DEBUG
                print("📝 Found \(orphanedQuotes.count) orphaned quotes")
                #endif
                
                // Create or get "Unknown Book" for orphaned items
                let unknownBook = await getOrCreateUnknownBook(context: newContext)
                
                for quote in orphanedQuotes {
                    if let _ = try? migrateQuote(quote, to: unknownBook, context: newContext) {
                        stats.migratedQuotes += 1
                    } else {
                        stats.failedQuotes += 1
                    }
                }
            }
        } catch {
            #if DEBUG
            print("❌ Failed to migrate orphaned quotes: \(error)")
            #endif
        }
    }
    
    /// Migrates orphaned notes
    private func migrateOrphanedNotes(oldContext: ModelContext, newContext: ModelContext, stats: inout MigrationStats) async {
        do {
            let descriptor = FetchDescriptor<LegacyNote>(
                predicate: #Predicate { note in
                    note.book == nil
                }
            )
            
            let orphanedNotes = try oldContext.fetch(descriptor)
            
            if !orphanedNotes.isEmpty {
                #if DEBUG
                print("📋 Found \(orphanedNotes.count) orphaned notes")
                #endif
                
                // Create or get "Unknown Book" for orphaned items
                let unknownBook = await getOrCreateUnknownBook(context: newContext)
                
                for note in orphanedNotes {
                    if let _ = try? migrateNote(note, to: unknownBook, context: newContext) {
                        stats.migratedNotes += 1
                    } else {
                        stats.failedNotes += 1
                    }
                }
            }
        } catch {
            #if DEBUG
            print("❌ Failed to migrate orphaned notes: \(error)")
            #endif
        }
    }
    
    /// Gets or creates an "Unknown Book" for orphaned content
    private func getOrCreateUnknownBook(context: ModelContext) async -> BookModel {
        // Check if unknown book already exists
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { book in
                book.id == "unknown-book-migration"
            }
        )
        
        if let existingBook = try? context.fetch(descriptor).first {
            return existingBook
        }
        
        // Create unknown book
        let unknownBook = BookModel(
            id: "unknown-book-migration",
            title: "Unknown Book",
            author: "Unknown Author",
            description: "Placeholder for migrated content without associated books"
        )
        
        context.insert(unknownBook)
        return unknownBook
    }
    
    /// Verifies the migration was successful
    private func verifyMigration(oldContainer: ModelContainer, newContainer: ModelContainer, stats: MigrationStats) async throws {
        let oldContext = oldContainer.mainContext
        let newContext = newContainer.mainContext
        
        // Count old data
        let oldBookCount = try oldContext.fetchCount(FetchDescriptor<LegacyBook>())
        let oldQuoteCount = try oldContext.fetchCount(FetchDescriptor<LegacyQuote>())
        let oldNoteCount = try oldContext.fetchCount(FetchDescriptor<LegacyNote>())
        
        // Count new data
        let newBookCount = try newContext.fetchCount(FetchDescriptor<BookModel>())
        let newQuoteCount = try newContext.fetchCount(FetchDescriptor<CapturedQuote>())
        let newNoteCount = try newContext.fetchCount(FetchDescriptor<CapturedNote>())
        
        #if DEBUG
        print("""
        📊 Migration Verification:
        Books: \(oldBookCount) → \(newBookCount) (migrated: \(stats.migratedBooks), failed: \(stats.failedBooks))
        Quotes: \(oldQuoteCount) → \(newQuoteCount) (migrated: \(stats.migratedQuotes), failed: \(stats.failedQuotes))
        Notes: \(oldNoteCount) → \(newNoteCount) (migrated: \(stats.migratedNotes), failed: \(stats.failedNotes))
        """)
        #endif
        
        // Verify counts match (allowing for some failures)
        if stats.failedBooks == 0 && newBookCount != oldBookCount {
            throw MigrationError.bookCountMismatch(old: oldBookCount, new: newBookCount)
        }
    }
    
    /// Logs migration results
    private func logMigrationResults(_ stats: MigrationStats) {
        #if DEBUG
        print("""
        ✅ Migration Complete:
        - Books: \(stats.migratedBooks) migrated, \(stats.failedBooks) failed
        - Quotes: \(stats.migratedQuotes) migrated, \(stats.failedQuotes) failed
        - Notes: \(stats.migratedNotes) migrated, \(stats.failedNotes) failed
        """)
        #endif
        
        // Save stats to UserDefaults for potential debugging
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(stats) {
            UserDefaults.standard.set(data, forKey: "com.epilogue.migrationStats")
        }
    }
}

// MARK: - Supporting Types

private struct MigrationStats: Codable {
    var totalBooks = 0
    var migratedBooks = 0
    var failedBooks = 0
    var migratedQuotes = 0
    var failedQuotes = 0
    var migratedNotes = 0
    var failedNotes = 0
    var migratedAISessions = 0
    var failedAISessions = 0
    var timestamp = Date()
}

private enum MigrationError: LocalizedError {
    case oldContainerCreationFailed
    case bookCountMismatch(old: Int, new: Int)
    case validationFailed
    
    var errorDescription: String? {
        switch self {
        case .oldContainerCreationFailed:
            return "Failed to access old data for migration"
        case .bookCountMismatch(let old, let new):
            return "Book count mismatch after migration: \(old) → \(new)"
        case .validationFailed:
            return "Migration validation failed"
        }
    }
}

// MARK: - User Notification

extension DataMigrationService {
    private func notifyUserOfMigrationFailure(error: Error) async {
        // Store error for display in UI
        UserDefaults.standard.set(error.localizedDescription, forKey: "com.epilogue.migrationError")
        
        // Log detailed error
        #if DEBUG
        print("""
        ❌ MIGRATION FAILURE DETAILS:
        Error: \(error)
        Description: \(error.localizedDescription)
        Time: \(Date())

        Please contact support if this persists.
        """)
        #endif
    }
}

// MARK: - SwiftUI View Modifier

struct DataMigrationModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var migrationTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .task {
                // Run migration in background
                migrationTask = Task {
                    let container = modelContext.container
                    await DataMigrationService.shared.performMigrationIfNeeded(newContainer: container)
                }
            }
            .onDisappear {
                migrationTask?.cancel()
            }
    }
}

extension View {
    func runDataMigration() -> some View {
        modifier(DataMigrationModifier())
    }
}