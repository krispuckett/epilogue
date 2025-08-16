import SwiftUI
import SwiftData
import Combine

/// Handles command processing for the main ContentView
@MainActor
class CommandProcessingManager: ObservableObject {
    
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let libraryViewModel: LibraryViewModel
    private let notesViewModel: NotesViewModel
    
    init(modelContext: ModelContext, libraryViewModel: LibraryViewModel, notesViewModel: NotesViewModel) {
        self.modelContext = modelContext
        self.libraryViewModel = libraryViewModel
        self.notesViewModel = notesViewModel
    }
    
    // MARK: - Command Processing
    
    func processInlineCommand(_ commandText: String) {
        let intent = CommandParser.parse(commandText, books: libraryViewModel.books, notes: notesViewModel.notes)
        
        switch intent {
            case .createQuote(let text):
                // Parse the quote text to extract content and attribution
                let (content, attribution) = CommandParser.parseQuote(text)
                var author: String? = nil
                var bookTitle: String? = nil
                var pageNumber: Int? = nil
                
                if let attr = attribution {
                    let parts = attr.split(separator: "|||").map { String($0) }
                    if parts.count >= 1 {
                        author = parts[0]
                    }
                    if parts.count >= 2 && parts[1] == "BOOK" && parts.count >= 3 {
                        bookTitle = parts[2]
                    }
                    if let pageIdx = parts.firstIndex(of: "PAGE"), pageIdx + 1 < parts.count {
                        pageNumber = Int(parts[pageIdx + 1])
                    }
                }
                
                createQuote(content: content, author: author, bookTitle: bookTitle, pageNumber: pageNumber)
                
            case .createNote(let text):
                createNote(content: text)
                
            case .searchLibrary(let query):
                searchBooks(query: query)
                
            case .addBook(let query):
                // Open BookSearchSheet with the query
                NotificationCenter.default.post(
                    name: Notification.Name("ShowBookSearch"),
                    object: query
                )
                
            case .existingBook(let book):
                // Navigate to book
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToBook"),
                    object: book
                )
                
            case .existingNote(let note):
                // Navigate to note
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToNote"), 
                    object: note
                )
                
            case .searchNotes(let query), .searchAll(let query):
                // Post notification to trigger search
                NotificationCenter.default.post(
                    name: Notification.Name("SearchNotes"),
                    object: query
                )
                
            case .unknown:
                print("Unknown command: \(commandText)")
            }
    }
    
    // MARK: - Quote Creation
    
    private func createQuote(content: String, author: String?, bookTitle: String?, pageNumber: Int?) {
        // Create BookModel if we have book context
        var bookModel: BookModel? = nil
        if let bookTitle = bookTitle {
            // Try to find existing book or create one
            if let existingBook = libraryViewModel.books.first(where: { $0.title == bookTitle }) {
                bookModel = BookModel(from: existingBook)
            } else {
                // Create a new book entry
                let newBook = Book(
                    id: UUID().uuidString,
                    title: bookTitle,
                    author: author ?? "Unknown Author",
                    publishedYear: "",
                    coverImageURL: nil,
                    pageCount: nil,
                    localId: UUID()
                )
                bookModel = BookModel(from: newBook)
            }
            
            if let model = bookModel {
                modelContext.insert(model)
            }
        }
        
        // Create and save to SwiftData using CapturedQuote
        let capturedQuote = CapturedQuote(
            text: content,
            book: bookModel,
            author: author,
            pageNumber: pageNumber,
            timestamp: Date(),
            source: .manual
        )
        
        modelContext.insert(capturedQuote)
        
        // Save to SwiftData
        do {
            try modelContext.save()
            print("✅ Quote saved via command")
        } catch {
            print("Failed to save quote: \(error)")
        }
    }
    
    // MARK: - Note Creation
    
    private func createNote(content: String) {
        let capturedNote = CapturedNote(content: content, book: nil)
        modelContext.insert(capturedNote)
        
        do {
            try modelContext.save()
            print("✅ Note saved via command")
        } catch {
            print("Error saving note: \(error)")
        }
    }
    
    // MARK: - Book Operations
    
    private func searchBooks(query: String) {
        // Trigger book search
        NotificationCenter.default.post(
            name: Notification.Name("SearchBooks"),
            object: query
        )
    }
    
    private func openBook(title: String) {
        // Find and open book
        if let book = libraryViewModel.books.first(where: { $0.title.lowercased().contains(title.lowercased()) }) {
            NotificationCenter.default.post(
                name: Notification.Name("OpenBook"),
                object: book
            )
        }
    }
    
    private func addBook(title: String, author: String) {
        // Add book to library
        let newBook = Book(
            id: UUID().uuidString,
            title: title,
            author: author,
            publishedYear: "",
            coverImageURL: nil,
            pageCount: nil,
            localId: UUID()
        )
        
        libraryViewModel.addBook(newBook)
    }
    
    private func updateProgress(bookTitle: String, page: Int) {
        // Update book progress
        if let book = libraryViewModel.books.first(where: { $0.title.lowercased().contains(bookTitle.lowercased()) }) {
            libraryViewModel.updateBookProgress(book, currentPage: page)
        }
    }
}