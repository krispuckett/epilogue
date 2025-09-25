import Foundation
import SwiftData
import CloudKit

/// Helps migrate local SwiftData store to CloudKit-enabled store
@MainActor
class CloudKitMigrationHelper {
    static let shared = CloudKitMigrationHelper()
    
    /// Check if we have local data that needs migration
    func hasLocalDataRequiringMigration() -> Bool {
        // Check if we previously used local-only storage
        let wasUsingCloudKit = UserDefaults.standard.bool(forKey: "isUsingCloudKit")
        
        // If we were already using CloudKit, no migration needed
        if wasUsingCloudKit {
            return false
        }
        
        // Check if there's an existing local store
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else {
            return false
        }
        
        // Check for various possible store files
        let possibleStoreFiles = [
            "default.store",
            "Model.sqlite",
            "default.store-shm",
            "default.store-wal",
            "Model.sqlite-shm",
            "Model.sqlite-wal"
        ]
        
        for fileName in possibleStoreFiles {
            let fileURL = appSupportURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                print("📱 Found local store file: \(fileName)")
                return true
            }
        }
        
        return false
    }
    
    /// Migrate data from local store to CloudKit
    func migrateToCloudKit(from localContainer: ModelContainer, to cloudContainer: ModelContainer) async throws {
        print("🔄 Starting migration to CloudKit...")
        
        let context = localContainer.mainContext
        let cloudContext = cloudContainer.mainContext
        
        // Migrate Books
        let books = try context.fetch(FetchDescriptor<BookModel>())
        print("📚 Found \(books.count) books to migrate")
        
        for book in books {
            let newBook = BookModel(
                id: book.id,
                title: book.title,
                author: book.author,
                publishedYear: book.publishedYear,
                coverImageURL: book.coverImageURL,
                isbn: book.isbn,
                description: book.desc,
                pageCount: book.pageCount,
                localId: book.localId
            )
            
            // Copy properties
            newBook.isInLibrary = book.isInLibrary
            newBook.readingStatus = book.readingStatus
            newBook.currentPage = book.currentPage
            newBook.userRating = book.userRating
            newBook.userNotes = book.userNotes
            newBook.dateAdded = book.dateAdded
            
            cloudContext.insert(newBook)
            
            // Migrate related data
            if let notes = book.notes {
                for note in notes {
                    let newNote = CapturedNote(
                        content: note.content ?? "",
                        book: newBook,
                        pageNumber: note.pageNumber,
                        timestamp: note.timestamp ?? Date(),
                        source: note.captureSource,
                        tags: note.tags ?? []
                    )
                    cloudContext.insert(newNote)
                }
            }
            
            if let quotes = book.quotes {
                for quote in quotes {
                    let newQuote = CapturedQuote(
                        text: quote.text ?? "",
                        book: newBook,
                        author: quote.author,
                        pageNumber: quote.pageNumber,
                        timestamp: quote.timestamp ?? Date(),
                        source: quote.captureSource,
                        notes: quote.notes
                    )
                    cloudContext.insert(newQuote)
                }
            }
            
            if let questions = book.questions {
                for question in questions {
                    let newQuestion = CapturedQuestion(
                        content: question.content ?? "",
                        book: newBook,
                        pageNumber: question.pageNumber,
                        timestamp: question.timestamp ?? Date(),
                        source: question.captureSource
                    )
                    newQuestion.answer = question.answer
                    newQuestion.isAnswered = question.isAnswered ?? false
                    cloudContext.insert(newQuestion)
                }
            }
        }
        
        // Save to CloudKit
        try cloudContext.save()
        
        print("✅ Migration completed successfully!")
        print("📊 Migrated:")
        print("   - \(books.count) books")
        
        // Mark that we're now using CloudKit
        UserDefaults.standard.set(true, forKey: "isUsingCloudKit")
        UserDefaults.standard.set(true, forKey: "hasCompletedCloudKitMigration")
    }
    
    /// Create a backup of local data before migration
    func createLocalBackup() throws -> URL {
        let fileManager = FileManager.default
        
        // Create backup directory
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = documentsURL.appendingPathComponent("EpilogueBackup_\(Date().timeIntervalSince1970)")
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        
        // Copy SwiftData files
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else {
            throw NSError(domain: "CloudKitMigration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find Application Support directory"])
        }
        
        let storeFiles = try fileManager.contentsOfDirectory(at: appSupportURL,
                                                            includingPropertiesForKeys: nil)
            .filter { url in
                let fileName = url.lastPathComponent
                return fileName.contains(".store") || fileName.contains(".sqlite")
            }
        
        for fileURL in storeFiles {
            let destURL = backupURL.appendingPathComponent(fileURL.lastPathComponent)
            try fileManager.copyItem(at: fileURL, to: destURL)
        }
        
        print("💾 Created backup at: \(backupURL.path)")
        return backupURL
    }
}