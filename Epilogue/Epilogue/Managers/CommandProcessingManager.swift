import SwiftUI
import SwiftData
import Combine
import UserNotifications

/// Handles command processing for the main ContentView
@MainActor
class CommandProcessingManager: ObservableObject {
    
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let libraryViewModel: LibraryViewModel
    private let notesViewModel: NotesViewModel
    
    // MARK: - Batch Book Queue
    @Published var pendingBookSearches: [String] = []
    @Published var isProcessingBatchBooks = false
    
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
                
            case .createNoteWithBook(let text, let book):
                // Create note with book context
                createNoteWithBook(content: text, book: book)
                
            case .createQuoteWithBook(let text, let book):
                // Create quote with book context
                createQuoteWithBook(content: text, book: book)
                
            case .multiStepCommand(let commands):
                // Execute multi-step commands
                Task {
                    await executeMultiStepCommands(commands)
                }
                
            case .createReminder(let text, let date):
                // Create a reminder
                createReminder(text: text, date: date)
                
            case .setReadingGoal(let book, let pagesPerDay):
                // Set reading goal for book
                setReadingGoal(book: book, pagesPerDay: pagesPerDay)
                
            case .batchAddBooks(let titles):
                // Queue multiple books for sequential processing
                processBatchBookAdditions(titles)
                
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
            
            // Post success notification
            let bookInfo = bookTitle ?? "your collection"
            NotificationCenter.default.post(
                name: Notification.Name("ShowToastMessage"),
                object: ["message": "Quote saved to \(bookInfo)"]
            )
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
            
            // Post success notification
            NotificationCenter.default.post(
                name: Notification.Name("ShowToastMessage"),
                object: ["message": "Note saved successfully"]
            )
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
    
    // MARK: - New Command Implementations
    
    private func createNoteWithBook(content: String, book: Book) {
        // Create BookModel if needed
        var bookModel: BookModel? = nil
        
        let fetchRequest = FetchDescriptor<BookModel>(
            predicate: #Predicate { model in
                model.localId == book.localId.uuidString
            }
        )
        
        if let existingBook = try? modelContext.fetch(fetchRequest).first {
            bookModel = existingBook
        } else {
            bookModel = BookModel(from: book)
            modelContext.insert(bookModel!)
        }
        
        // Create note with book context
        let capturedNote = CapturedNote(
            content: content,
            book: bookModel,
            timestamp: Date(),
            source: .manual
        )
        
        modelContext.insert(capturedNote)
        
        do {
            try modelContext.save()
            print("✅ Note saved with book context: \(book.title)")
            
            // Post success notification
            NotificationCenter.default.post(
                name: Notification.Name("ShowToastMessage"),
                object: ["message": "Note saved to \(book.title)"]
            )
        } catch {
            print("Failed to save note: \(error)")
        }
    }
    
    private func createQuoteWithBook(content: String, book: Book) {
        // Create BookModel if needed
        var bookModel: BookModel? = nil
        
        let fetchRequest = FetchDescriptor<BookModel>(
            predicate: #Predicate { model in
                model.localId == book.localId.uuidString
            }
        )
        
        if let existingBook = try? modelContext.fetch(fetchRequest).first {
            bookModel = existingBook
        } else {
            bookModel = BookModel(from: book)
            modelContext.insert(bookModel!)
        }
        
        // Create quote with book context
        let capturedQuote = CapturedQuote(
            text: content,
            book: bookModel,
            author: book.author,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual
        )
        
        modelContext.insert(capturedQuote)
        
        do {
            try modelContext.save()
            print("✅ Quote saved with book context: \(book.title)")
            
            // Post success notification
            NotificationCenter.default.post(
                name: Notification.Name("ShowToastMessage"),
                object: ["message": "Quote saved from \(book.title)"]
            )
        } catch {
            print("Failed to save quote: \(error)")
        }
    }
    
    private func executeMultiStepCommands(_ commands: [ChainedCommand]) async {
        for command in commands {
            switch command {
            case .addBooks(let titles):
                for title in titles {
                    print("Adding book: \(title)")
                    // Post notification to show book search
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: Notification.Name("ShowBookSearch"),
                            object: title
                        )
                    }
                }
                
            case .markAsStatus(let titles, let status):
                print("Marking \(titles) as \(status)")
                // TODO: Implement status update
                
            case .setReadingGoal(let book, let pagesPerDay):
                await MainActor.run {
                    setReadingGoal(book: book, pagesPerDay: pagesPerDay)
                }
                
            case .createReminder(let text, let date):
                await MainActor.run {
                    createReminder(text: text, date: date)
                }
                
            case .batchNote(let note, let books):
                for book in books {
                    await MainActor.run {
                        createNoteWithBook(content: note, book: book)
                    }
                }
                
            case .compound(let subCommands):
                await executeMultiStepCommands(subCommands)
            }
        }
    }
    
    private func createReminder(text: String, date: Date) {
        // Create a reminder using UserNotifications
        let content = UNMutableNotificationContent()
        content.title = "Reading Reminder"
        content.body = text
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule reminder: \(error)")
            } else {
                print("✅ Reminder scheduled for \(date)")
                
                // Post success notification
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                NotificationCenter.default.post(
                    name: Notification.Name("ShowToastMessage"),
                    object: ["message": "Reminder set for \(formatter.string(from: date))"]
                )
            }
        }
    }
    
    private func setReadingGoal(book: Book, pagesPerDay: Int) {
        // Store reading goal in UserDefaults or SwiftData
        let goalKey = "readingGoal_\(book.localId)"
        UserDefaults.standard.set(pagesPerDay, forKey: goalKey)
        
        print("✅ Reading goal set: \(pagesPerDay) pages/day for \(book.title)")
        
        // Post notification to update UI
        NotificationCenter.default.post(
            name: Notification.Name("ReadingGoalSet"),
            object: ["book": book, "pagesPerDay": pagesPerDay]
        )
        
        // Post success toast
        NotificationCenter.default.post(
            name: Notification.Name("ShowToastMessage"),
            object: ["message": "Reading goal: \(pagesPerDay) pages/day for \(book.title)"]
        )
    }
    
    // MARK: - Batch Book Processing
    
    private func processBatchBookAdditions(_ titles: [String]) {
        // Store the list of books to add
        pendingBookSearches = titles
        isProcessingBatchBooks = true
        
        // Post notification with the entire batch
        NotificationCenter.default.post(
            name: Notification.Name("ShowBatchBookSearch"),
            object: titles
        )
        
        print("📚 Queued \(titles.count) books for batch addition: \(titles.joined(separator: ", "))")
        
        // Post success notification
        NotificationCenter.default.post(
            name: Notification.Name("ShowToastMessage"),
            object: ["message": "Adding \(titles.count) books to library..."]
        )
    }
    
    func processNextBookInQueue() {
        guard !pendingBookSearches.isEmpty else {
            isProcessingBatchBooks = false
            return
        }
        
        let nextBook = pendingBookSearches.removeFirst()
        
        // Show search for this book
        NotificationCenter.default.post(
            name: Notification.Name("ShowBookSearch"),
            object: nextBook
        )
        
        print("📖 Processing book search: \(nextBook). Remaining: \(pendingBookSearches.count)")
    }
    
    func clearBookQueue() {
        pendingBookSearches.removeAll()
        isProcessingBatchBooks = false
    }
}