import Foundation
import SwiftData
import SwiftUI

/// Handles SwiftData migrations and relationship fixes
@MainActor
final class SwiftDataMigrationService {
    static let shared = SwiftDataMigrationService()
    
    private init() {}
    
    /// Run all necessary migrations and fixes
    func runMigrations(modelContext: ModelContext) async {
        #if DEBUG
        print("🔧 Starting SwiftData migrations...")
        #endif
        
        // Fix orphaned sessions
        await fixOrphanedSessions(modelContext: modelContext)
        
        // Fix orphaned notes/quotes/questions
        await fixOrphanedCapturedItems(modelContext: modelContext)
        
        // Ensure all relationships are bidirectional
        await ensureBidirectionalRelationships(modelContext: modelContext)
        
        // Clean up duplicate books
        await removeDuplicateBooks(modelContext: modelContext)
        
        #if DEBUG
        print("✅ SwiftData migrations completed")
        #endif
    }
    
    /// Fix ambient sessions without books
    private func fixOrphanedSessions(modelContext: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<AmbientSession>(
                predicate: #Predicate { session in
                    session.bookModel == nil
                }
            )
            
            let orphanedSessions = try modelContext.fetch(descriptor)
            
            if !orphanedSessions.isEmpty {
                #if DEBUG
                print("📋 Found \(orphanedSessions.count) orphaned sessions")
                #endif
                
                // Try to match sessions to books based on content
                for session in orphanedSessions {
                    if let matchedBook = await findBookForSession(session, modelContext: modelContext) {
                        session.bookModel = matchedBook
                        #if DEBUG
                        print("  ✓ Linked session to book: \(matchedBook.title)")
                        #endif
                    } else {
                        // Create a "No Book" placeholder if needed
                        let noBook = await getOrCreateNoBook(modelContext: modelContext)
                        session.bookModel = noBook
                        #if DEBUG
                        print("  ✓ Linked session to 'No Book' placeholder")
                        #endif
                    }
                }
                
                try modelContext.save()
            }
        } catch {
            print("❌ Failed to fix orphaned sessions: \(error)")
        }
    }
    
    /// Fix orphaned captured items (notes, quotes, questions)
    private func fixOrphanedCapturedItems(modelContext: ModelContext) async {
        // Fix orphaned notes
        do {
            let notesDescriptor = FetchDescriptor<CapturedNote>(
                predicate: #Predicate { note in
                    note.book == nil && note.bookLocalId != nil
                }
            )
            
            let orphanedNotes = try modelContext.fetch(notesDescriptor)
            
            for note in orphanedNotes {
                if let bookLocalId = note.bookLocalId,
                   let book = try await findBookByLocalId(bookLocalId, modelContext: modelContext) {
                    note.book = book
                    print("  ✓ Relinked note to book: \(book.title)")
                }
            }
        } catch {
            print("❌ Failed to fix orphaned notes: \(error)")
        }
        
        // Fix orphaned quotes
        do {
            let quotesDescriptor = FetchDescriptor<CapturedQuote>(
                predicate: #Predicate { quote in
                    quote.book == nil && quote.bookLocalId != nil
                }
            )
            
            let orphanedQuotes = try modelContext.fetch(quotesDescriptor)
            
            for quote in orphanedQuotes {
                if let bookLocalId = quote.bookLocalId,
                   let book = try await findBookByLocalId(bookLocalId, modelContext: modelContext) {
                    quote.book = book
                    print("  ✓ Relinked quote to book: \(book.title)")
                }
            }
        } catch {
            print("❌ Failed to fix orphaned quotes: \(error)")
        }
        
        // Fix orphaned questions
        do {
            let questionsDescriptor = FetchDescriptor<CapturedQuestion>(
                predicate: #Predicate { question in
                    question.book == nil && question.bookLocalId != nil
                }
            )
            
            let orphanedQuestions = try modelContext.fetch(questionsDescriptor)
            
            for question in orphanedQuestions {
                if let bookLocalId = question.bookLocalId,
                   let book = try await findBookByLocalId(bookLocalId, modelContext: modelContext) {
                    question.book = book
                    print("  ✓ Relinked question to book: \(book.title)")
                }
            }
        } catch {
            print("❌ Failed to fix orphaned questions: \(error)")
        }
        
        try? modelContext.save()
    }
    
    /// Ensure all relationships are properly bidirectional
    private func ensureBidirectionalRelationships(modelContext: ModelContext) async {
        do {
            // Fetch all books
            let booksDescriptor = FetchDescriptor<BookModel>()
            let books = try modelContext.fetch(booksDescriptor)
            
            for book in books {
                // Ensure notes relationship
                if book.notes == nil {
                    book.notes = []
                }
                
                // Ensure quotes relationship
                if book.quotes == nil {
                    book.quotes = []
                }
                
                // Ensure questions relationship
                if book.questions == nil {
                    book.questions = []
                }
            }
            
            try modelContext.save()
            print("✅ Ensured bidirectional relationships for \(books.count) books")
            
        } catch {
            print("❌ Failed to ensure bidirectional relationships: \(error)")
        }
    }
    
    /// Remove duplicate books (same title and author)
    private func removeDuplicateBooks(modelContext: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<BookModel>(
                sortBy: [SortDescriptor(\.dateAdded)]
            )
            let allBooks = try modelContext.fetch(descriptor)
            
            // Group books by title + author
            var bookGroups: [String: [BookModel]] = [:]
            for book in allBooks {
                let key = "\(book.title.lowercased())_\(book.author.lowercased())"
                if bookGroups[key] == nil {
                    bookGroups[key] = []
                }
                bookGroups[key]?.append(book)
            }
            
            // Find and merge duplicates
            var duplicatesRemoved = 0
            for (_, books) in bookGroups where books.count > 1 {
                // Keep the oldest one (first added)
                let bookToKeep = books[0]
                let duplicates = Array(books.dropFirst())
                
                for duplicate in duplicates {
                    // Transfer relationships to the keeper
                    await mergeBookRelationships(from: duplicate, to: bookToKeep, modelContext: modelContext)
                    
                    // Delete the duplicate
                    modelContext.delete(duplicate)
                    duplicatesRemoved += 1
                }
            }
            
            if duplicatesRemoved > 0 {
                try modelContext.save()
                print("✅ Removed \(duplicatesRemoved) duplicate books")
            }
            
        } catch {
            print("❌ Failed to remove duplicate books: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func findBookForSession(_ session: AmbientSession, modelContext: ModelContext) async -> BookModel? {
        // Try to find book based on captured items in the session
        if let firstQuote = session.capturedQuotes?.first,
           let book = firstQuote.book {
            return book
        }
        
        if let firstNote = session.capturedNotes?.first,
           let book = firstNote.book {
            return book
        }
        
        // Try content analysis if available
        // This would need more sophisticated matching logic
        
        return nil
    }
    
    private func findBookByLocalId(_ localId: String, modelContext: ModelContext) async throws -> BookModel? {
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { book in
                book.localId == localId
            }
        )
        
        let books = try modelContext.fetch(descriptor)
        return books.first
    }
    
    private func getOrCreateNoBook(modelContext: ModelContext) async -> BookModel {
        // Check if "No Book" already exists
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { book in
                book.title == "No Book Selected"
            }
        )
        
        if let existingNoBook = try? modelContext.fetch(descriptor).first {
            return existingNoBook
        }
        
        // Create "No Book" placeholder
        let noBook = BookModel(
            id: "no-book",
            title: "No Book Selected",
            author: "Unknown",
            description: "Placeholder for sessions without a book"
        )
        
        modelContext.insert(noBook)
        try? modelContext.save()
        
        return noBook
    }
    
    private func mergeBookRelationships(from source: BookModel, to target: BookModel, modelContext: ModelContext) async {
        // Transfer notes
        if let notes = source.notes {
            for note in notes {
                note.book = target
                note.bookLocalId = target.localId
            }
        }
        
        // Transfer quotes
        if let quotes = source.quotes {
            for quote in quotes {
                quote.book = target
                quote.bookLocalId = target.localId
            }
        }
        
        // Transfer questions
        if let questions = source.questions {
            for question in questions {
                question.book = target
                question.bookLocalId = target.localId
            }
        }
        
        // Update reading status if target is not being read
        if target.readingStatus == "unread" && source.readingStatus != "unread" {
            target.readingStatus = source.readingStatus
            target.currentPage = max(target.currentPage, source.currentPage)
        }
    }
}

// MARK: - Migration Runner View Modifier

struct RunMigrationsOnAppear: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var hasMigrated = false
    
    func body(content: Content) -> some View {
        content
            .task {
                guard !hasMigrated else { return }
                hasMigrated = true
                
                await SwiftDataMigrationService.shared.runMigrations(
                    modelContext: modelContext
                )
            }
    }
}

extension View {
    func runSwiftDataMigrations() -> some View {
        modifier(RunMigrationsOnAppear())
    }
}