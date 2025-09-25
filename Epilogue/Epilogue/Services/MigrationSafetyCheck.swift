import Foundation
import SwiftData
import SwiftUI

/// Post-migration safety check service to ensure data integrity
@MainActor
final class MigrationSafetyCheck {
    static let shared = MigrationSafetyCheck()
    
    private init() {}
    
    /// Runs comprehensive safety checks after migration
    func runSafetyChecks(modelContext: ModelContext) async {
        print("🔍 Running post-migration safety checks...")
        
        var issues: [SafetyIssue] = []
        
        // Check 1: Verify all books have valid data
        issues.append(contentsOf: await checkBooksIntegrity(modelContext: modelContext))
        
        // Check 2: Verify relationships are intact
        issues.append(contentsOf: await checkRelationships(modelContext: modelContext))
        
        // Check 3: Ensure no duplicate books
        issues.append(contentsOf: await checkForDuplicates(modelContext: modelContext))
        
        // Check 4: Verify cover images
        issues.append(contentsOf: await checkCoverImages(modelContext: modelContext))
        
        // Check 5: Ensure critical fields have defaults
        issues.append(contentsOf: await checkDefaultValues(modelContext: modelContext))
        
        // Report results
        if issues.isEmpty {
            print("✅ All safety checks passed!")
        } else {
            print("⚠️ Found \(issues.count) issues during safety check:")
            for issue in issues {
                print("  - \(issue.description)")
            }
            
            // Attempt auto-fixes for recoverable issues
            await attemptAutoFixes(issues: issues, modelContext: modelContext)
        }
    }
    
    /// Check books have required fields
    private func checkBooksIntegrity(modelContext: ModelContext) async -> [SafetyIssue] {
        var issues: [SafetyIssue] = []
        
        do {
            let descriptor = FetchDescriptor<BookModel>()
            let books = try modelContext.fetch(descriptor)
            
            for book in books {
                // Check for empty critical fields
                if book.title.isEmpty {
                    issues.append(.emptyTitle(bookId: book.id))
                }
                
                if book.author.isEmpty {
                    issues.append(.emptyAuthor(bookId: book.id))
                }
                
                if book.id.isEmpty {
                    issues.append(.emptyId(bookLocalId: book.localId))
                }
                
                // Check for invalid reading status
                if ReadingStatus(rawValue: book.readingStatus) == nil {
                    issues.append(.invalidReadingStatus(bookId: book.id, status: book.readingStatus))
                }
            }
        } catch {
            issues.append(.fetchError(entity: "BookModel", error: error))
        }
        
        return issues
    }
    
    /// Check relationships are properly set
    private func checkRelationships(modelContext: ModelContext) async -> [SafetyIssue] {
        var issues: [SafetyIssue] = []
        
        // Check notes
        do {
            let notesDescriptor = FetchDescriptor<CapturedNote>()
            let notes = try modelContext.fetch(notesDescriptor)
            
            for note in notes {
                if note.book == nil && note.bookLocalId != nil {
                    issues.append(.orphanedNote(noteId: note.id ?? UUID()))
                }
            }
        } catch {
            issues.append(.fetchError(entity: "CapturedNote", error: error))
        }
        
        // Check quotes
        do {
            let quotesDescriptor = FetchDescriptor<CapturedQuote>()
            let quotes = try modelContext.fetch(quotesDescriptor)
            
            for quote in quotes {
                if quote.book == nil && quote.bookLocalId != nil {
                    issues.append(.orphanedQuote(quoteId: quote.id ?? UUID()))
                }
            }
        } catch {
            issues.append(.fetchError(entity: "CapturedQuote", error: error))
        }
        
        // Check questions
        do {
            let questionsDescriptor = FetchDescriptor<CapturedQuestion>()
            let questions = try modelContext.fetch(questionsDescriptor)
            
            for question in questions {
                if question.book == nil && question.bookLocalId != nil {
                    issues.append(.orphanedQuestion(questionId: question.id ?? UUID()))
                }
            }
        } catch {
            issues.append(.fetchError(entity: "CapturedQuestion", error: error))
        }
        
        return issues
    }
    
    /// Check for duplicate books
    private func checkForDuplicates(modelContext: ModelContext) async -> [SafetyIssue] {
        var issues: [SafetyIssue] = []
        
        do {
            let descriptor = FetchDescriptor<BookModel>()
            let books = try modelContext.fetch(descriptor)
            
            // Group by title + author
            var bookGroups: [String: [BookModel]] = [:]
            for book in books {
                let key = "\(book.title.lowercased())_\(book.author.lowercased())"
                if bookGroups[key] == nil {
                    bookGroups[key] = []
                }
                bookGroups[key]?.append(book)
            }
            
            // Find duplicates
            for (key, duplicates) in bookGroups where duplicates.count > 1 {
                issues.append(.duplicateBooks(key: key, count: duplicates.count))
            }
        } catch {
            issues.append(.fetchError(entity: "BookModel", error: error))
        }
        
        return issues
    }
    
    /// Check cover images exist
    private func checkCoverImages(modelContext: ModelContext) async -> [SafetyIssue] {
        var issues: [SafetyIssue] = []
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagesPath = documentsPath.appendingPathComponent("BookCovers")
        
        do {
            let descriptor = FetchDescriptor<BookModel>()
            let books = try modelContext.fetch(descriptor)
            
            for book in books {
                // Check if book should have a cover image
                if book.coverImageURL != nil {
                    // Check if local file exists for migrated books
                    let imagePath = imagesPath.appendingPathComponent("\(book.localId).jpg")
                    if !FileManager.default.fileExists(atPath: imagePath.path) {
                        // It's okay if it's a URL - just log it
                        if book.coverImageURL?.hasPrefix("http") == false {
                            issues.append(.missingCoverImage(bookId: book.id, title: book.title))
                        }
                    }
                }
            }
        } catch {
            issues.append(.fetchError(entity: "BookModel", error: error))
        }
        
        return issues
    }
    
    /// Check default values are set
    private func checkDefaultValues(modelContext: ModelContext) async -> [SafetyIssue] {
        var issues: [SafetyIssue] = []
        
        do {
            let descriptor = FetchDescriptor<BookModel>()
            let books = try modelContext.fetch(descriptor)
            
            for book in books {
                // These should never be nil due to defaults, but check anyway
                if book.localId.isEmpty {
                    issues.append(.missingLocalId(bookId: book.id))
                }
            }
        } catch {
            issues.append(.fetchError(entity: "BookModel", error: error))
        }
        
        return issues
    }
    
    /// Attempt to fix recoverable issues
    private func attemptAutoFixes(issues: [SafetyIssue], modelContext: ModelContext) async {
        print("🔧 Attempting to auto-fix recoverable issues...")
        
        var fixedCount = 0
        
        for issue in issues {
            switch issue {
            case .emptyAuthor(let bookId):
                if let book = try? fetchBook(by: bookId, context: modelContext) {
                    book.author = "Unknown Author"
                    fixedCount += 1
                }
                
            case .invalidReadingStatus(let bookId, _):
                if let book = try? fetchBook(by: bookId, context: modelContext) {
                    book.readingStatus = ReadingStatus.wantToRead.rawValue
                    fixedCount += 1
                }
                
            case .missingLocalId(let bookId):
                if let book = try? fetchBook(by: bookId, context: modelContext) {
                    book.localId = UUID().uuidString
                    fixedCount += 1
                }
                
            default:
                // Some issues can't be auto-fixed
                continue
            }
        }
        
        if fixedCount > 0 {
            do {
                try modelContext.save()
                print("✅ Auto-fixed \(fixedCount) issues")
            } catch {
                print("❌ Failed to save auto-fixes: \(error)")
            }
        }
    }
    
    /// Helper to fetch a book by ID
    private func fetchBook(by id: String, context: ModelContext) throws -> BookModel? {
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { book in
                book.id == id
            }
        )
        return try context.fetch(descriptor).first
    }
}

// MARK: - Safety Issue Types

private enum SafetyIssue {
    case emptyTitle(bookId: String)
    case emptyAuthor(bookId: String)
    case emptyId(bookLocalId: String)
    case invalidReadingStatus(bookId: String, status: String)
    case orphanedNote(noteId: UUID)
    case orphanedQuote(quoteId: UUID)
    case orphanedQuestion(questionId: UUID)
    case duplicateBooks(key: String, count: Int)
    case missingCoverImage(bookId: String, title: String)
    case missingLocalId(bookId: String)
    case fetchError(entity: String, error: Error)
    
    var description: String {
        switch self {
        case .emptyTitle(let bookId):
            return "Book \(bookId) has empty title"
        case .emptyAuthor(let bookId):
            return "Book \(bookId) has empty author"
        case .emptyId(let bookLocalId):
            return "Book with localId \(bookLocalId) has empty ID"
        case .invalidReadingStatus(let bookId, let status):
            return "Book \(bookId) has invalid reading status: \(status)"
        case .orphanedNote(let noteId):
            return "Note \(noteId) has no associated book"
        case .orphanedQuote(let quoteId):
            return "Quote \(quoteId) has no associated book"
        case .orphanedQuestion(let questionId):
            return "Question \(questionId) has no associated book"
        case .duplicateBooks(let key, let count):
            return "Found \(count) duplicate books for: \(key)"
        case .missingCoverImage(let bookId, let title):
            return "Book '\(title)' (\(bookId)) missing cover image file"
        case .missingLocalId(let bookId):
            return "Book \(bookId) missing localId"
        case .fetchError(let entity, let error):
            return "Failed to fetch \(entity): \(error.localizedDescription)"
        }
    }
}