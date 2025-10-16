import Foundation
import SwiftUI
import Combine

@MainActor
class ResponseOrchestrator: ObservableObject {
    @Published var isProcessing = false
    @Published var responseText = ""
    @Published var actionResult: ActionResult?
    
    private let intentProcessor = IntentProcessor()
    private let synthesizer = VoiceSynthesizer()
    
    enum ActionResult {
        case success(message: String)
        case error(message: String)
        case needsConfirmation(action: String, onConfirm: () async -> Void)
    }
    
    func processVoiceCommand(_ transcription: String, context: AppContext) async {
        isProcessing = true
        responseText = ""
        
        // Process intent
        let intent = await intentProcessor.processTranscription(transcription)
        
        // Execute action based on intent
        switch intent {
        case .addBook(let title, let author):
            await handleAddBook(title: title, author: author, context: context)
            
        case .addNote(let content):
            await handleAddNote(content: content, context: context)
            
        case .addQuote(let quote, let source):
            await handleAddQuote(quote: quote, source: source, context: context)
            
        case .searchLibrary(let query):
            await handleSearch(query: query, context: context)
            
        case .readingProgress(let book, let action):
            await handleReadingProgress(book: book, action: action, context: context)
            
        case .recommendation(let genre):
            await handleRecommendation(genre: genre, context: context)
            
        case .help:
            await handleHelp()
            
        case .unknown:
            await handleUnknownIntent()
        }
        
        isProcessing = false
    }
    
    // MARK: - Intent Handlers
    
    private func handleAddBook(title: String?, author: String?, context: AppContext) async {
        guard let title = title else {
            responseText = "I need a book title to add it to your library."
            actionResult = .error(message: "Missing book title")
            return
        }
        
        responseText = "Searching for \"\(title)\""
        if let author = author {
            responseText += " by \(author)"
        }
        
        // Trigger book search
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("VoiceAddBook"),
                object: ["title": title, "author": author ?? ""]
            )
        }
        
        // Simulate search delay
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        responseText = "I found several matches. Please select the correct edition from the search results."
        actionResult = .success(message: "Book search initiated")
        
        // Speak response
        await synthesizer.speak(responseText)
    }
    
    private func handleAddNote(content: String, context: AppContext) async {
        responseText = "Adding note: \"\(content)\""
        
        let note = Note(
            type: .note,
            content: content,
            dateCreated: Date()
        )
        
        await MainActor.run {
            context.notesViewModel.addNote(note)
        }
        
        responseText = "Note added successfully."
        actionResult = .success(message: "Note saved")
        
        await synthesizer.speak("Note saved.")
    }
    
    private func handleAddQuote(quote: String, source: String?, context: AppContext) async {
        var fullResponse = "Adding quote: \"\(quote)\""
        if let source = source {
            fullResponse += " from \(source)"
        }
        responseText = fullResponse
        
        let note = Note(
            type: .quote,
            content: quote,
            author: source,
            dateCreated: Date()
        )
        
        await MainActor.run {
            context.notesViewModel.addNote(note)
        }
        
        responseText = "Quote saved to your collection."
        actionResult = .success(message: "Quote saved")
        
        await synthesizer.speak("Quote saved.")
    }
    
    private func handleSearch(query: String, context: AppContext) async {
        responseText = "Searching your library for \"\(query)\"..."
        
        let results = await searchLibrary(query: query, in: context.libraryViewModel.books)
        
        if results.isEmpty {
            responseText = "I couldn't find any books matching \"\(query)\" in your library."
            actionResult = .error(message: "No results found")
        } else if results.count == 1 {
            let book = results[0]
            responseText = "Found \"\(book.title)\" by \(book.author) in your library."
            actionResult = .success(message: "Found 1 book")
            
            // Navigate to book
            NotificationCenter.default.post(name: Notification.Name("NavigateToBook"), object: book)
        } else {
            responseText = "Found \(results.count) books matching \"\(query)\". "
            let titles = results.prefix(3).map { $0.title }.joined(separator: ", ")
            responseText += "Including: \(titles)"
            actionResult = .success(message: "Found \(results.count) books")
        }
        
        await synthesizer.speak(responseText)
    }
    
    private func handleReadingProgress(book: String?, action: IntentProcessor.VoiceIntent.ProgressAction, context: AppContext) async {
        switch action {
        case .update(let page):
            guard let bookTitle = book else {
                responseText = "Which book are you reading?"
                actionResult = .error(message: "Book not specified")
                return
            }
            
            if let foundBook = findBook(title: bookTitle, in: context.libraryViewModel.books) {
                await MainActor.run {
                    context.libraryViewModel.updateBookProgress(foundBook, currentPage: page)
                }
                
                let progress = Int((Double(page) / Double(foundBook.pageCount ?? 1)) * 100)
                responseText = "Updated \"\(foundBook.title)\" to page \(page). You're \(progress)% through the book."
                actionResult = .success(message: "Progress updated")
            } else {
                responseText = "I couldn't find \"\(bookTitle)\" in your library."
                actionResult = .error(message: "Book not found")
            }
            
        case .check:
            if let bookTitle = book,
               let foundBook = findBook(title: bookTitle, in: context.libraryViewModel.books) {
                let progress = Int((Double(foundBook.currentPage) / Double(foundBook.pageCount ?? 1)) * 100)
                responseText = "You're on page \(foundBook.currentPage) of \"\(foundBook.title)\", which is \(progress)% complete."
            } else {
                // Get currently reading books
                let readingBooks = context.libraryViewModel.books.filter { $0.currentPage > 0 }
                if readingBooks.isEmpty {
                    responseText = "You don't have any books in progress."
                } else {
                    responseText = "You're currently reading: "
                    let bookProgress = readingBooks.prefix(3).map { book in
                        let progress = Int((Double(book.currentPage) / Double(book.pageCount ?? 1)) * 100)
                        return "\"\(book.title)\" (\(progress)%)"
                    }.joined(separator: ", ")
                    responseText += bookProgress
                }
            }
            actionResult = .success(message: "Progress checked")
            
        case .finish:
            guard let bookTitle = book else {
                responseText = "Which book did you finish?"
                actionResult = .error(message: "Book not specified")
                return
            }
            
            if let foundBook = findBook(title: bookTitle, in: context.libraryViewModel.books) {
                await MainActor.run {
                    context.libraryViewModel.updateBookProgress(
                        foundBook,
                        currentPage: foundBook.pageCount ?? 0
                    )
                }
                
                responseText = "Congratulations on finishing \"\(foundBook.title)\"! I've marked it as complete."
                actionResult = .success(message: "Book completed")
            } else {
                responseText = "I couldn't find \"\(bookTitle)\" in your library."
                actionResult = .error(message: "Book not found")
            }
        }
        
        await synthesizer.speak(responseText)
    }
    
    private func handleRecommendation(genre: String?, context: AppContext) async {
        responseText = "Let me think about what you might enjoy..."
        
        // Simulate processing
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        if let genre = genre {
            responseText = "Based on your interest in \(genre), you might enjoy exploring similar titles in your library or discovering new books in that genre."
        } else {
            responseText = "Based on your reading history, I'd suggest exploring different genres to broaden your literary horizons."
        }
        
        actionResult = .success(message: "Recommendation provided")
        await synthesizer.speak(responseText)
    }
    
    private func handleHelp() async {
        responseText = """
        I can help you manage your library with voice commands. Try saying:
        
        • "Add [book title] by [author] to my library"
        • "Make a note that [your note]"
        • "Save quote [quote] from [source]"
        • "Search for [book or author]"
        • "I'm on page [number] of [book]"
        • "What's my reading progress?"
        • "I finished [book]"
        • "Recommend a book"
        
        Just say "Hey Epilogue" followed by your command.
        """
        
        actionResult = .success(message: "Help provided")
        await synthesizer.speak("I can help you add books, create notes, save quotes, track reading progress, and more. Just tell me what you'd like to do.")
    }
    
    private func handleUnknownIntent() async {
        responseText = "I didn't understand that command. Try saying 'help' to see what I can do."
        actionResult = .error(message: "Unknown command")
        await synthesizer.speak(responseText)
    }
    
    // MARK: - Helper Methods
    
    private func searchLibrary(query: String, in books: [Book]) async -> [Book] {
        let lowercasedQuery = query.lowercased()
        
        return books.filter { book in
            book.title.lowercased().contains(lowercasedQuery) ||
            book.author.lowercased().contains(lowercasedQuery)
        }
    }
    
    private func findBook(title: String, in books: [Book]) -> Book? {
        let lowercasedTitle = title.lowercased()
        
        // Try exact match first
        if let exactMatch = books.first(where: { $0.title.lowercased() == lowercasedTitle }) {
            return exactMatch
        }
        
        // Try contains match
        return books.first(where: { $0.title.lowercased().contains(lowercasedTitle) })
    }
}

// MARK: - App Context
struct AppContext {
    let libraryViewModel: LibraryViewModel
    let notesViewModel: NotesViewModel
}