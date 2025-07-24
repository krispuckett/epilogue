import SwiftUI

// Test suite for CommandIntent detection
struct CommandIntentTests {
    static func runAllTests() {
        print("\n=== Running CommandIntent Tests ===\n")
        
        // Sample data for testing
        let sampleBooks = [
            Book(googleBooksId: nil, title: "The Hobbit", author: "J.R.R. Tolkien", description: "", coverImageURL: nil, pageCount: 300, categories: [], publishedDate: nil, publisher: nil, isbn: nil),
            Book(googleBooksId: nil, title: "Project Hail Mary", author: "Andy Weir", description: "", coverImageURL: nil, pageCount: 400, categories: [], publishedDate: nil, publisher: nil, isbn: nil),
            Book(googleBooksId: nil, title: "Pride and Prejudice", author: "Jane Austen", description: "", coverImageURL: nil, pageCount: 350, categories: [], publishedDate: nil, publisher: nil, isbn: nil)
        ]
        
        let sampleNotes = [
            Note(type: .quote, content: "Be brave, hobbits", bookId: nil, bookTitle: "The Lord of the Rings", author: "Gandalf", pageNumber: 42),
            Note(type: .note, content: "Remember to buy milk", bookId: nil, bookTitle: nil, author: nil, pageNumber: nil),
            Note(type: .quote, content: "It is a truth universally acknowledged", bookId: nil, bookTitle: "Pride and Prejudice", author: "Jane Austen", pageNumber: 1)
        ]
        
        // Test cases
        let testCases: [(input: String, expectedIntent: String, description: String)] = [
            // Book title patterns
            ("Surrender by Bono", "addBook", "Book with 'by' pattern"),
            ("The Great Gatsby", "addBook", "Title case book name"),
            ("reading 1984", "addBook", "Explicit 'reading' prefix"),
            ("add book Atomic Habits", "addBook", "Explicit 'add book' prefix"),
            
            // Existing book matches
            ("the hobbit", "existingBook", "Exact book match (case insensitive)"),
            ("Project Hail", "existingBook", "Partial book title match"),
            ("pride and prejudice", "existingBook", "Full book title match"),
            ("tolkien", "searchAll", "Author name alone should search"),
            
            // Quote patterns
            ("\"To be or not to be\"", "createQuote", "Quote with quotation marks"),
            (""Hello world"", "createQuote", "Quote with smart quotes"),
            ("Be brave", "existingNote", "Existing quote match"),
            ("It is a truth", "existingNote", "Partial quote match"),
            
            // Note patterns
            ("note: remember to call mom", "createNote", "Explicit note prefix"),
            ("thought: interesting idea about AI", "createNote", "Thought prefix"),
            ("This is a long text that should become a note because it's over 50 characters", "createNote", "Long text becomes note"),
            ("Remember to buy", "existingNote", "Partial note match"),
            
            // Search patterns
            ("search books", "searchLibrary", "Explicit book search"),
            ("search notes", "searchNotes", "Explicit note search"),
            ("search everything", "searchAll", "Explicit search all"),
            ("random short text", "searchAll", "Short text defaults to search"),
            
            // Edge cases
            ("", "unknown", "Empty input"),
            ("?", "unknown", "Single character"),
            ("by", "searchAll", "Just 'by' keyword"),
            ("add", "searchAll", "Incomplete command")
        ]
        
        var passed = 0
        var failed = 0
        
        for (input, expectedType, description) in testCases {
            let intent = CommandParser.parse(input, books: sampleBooks, notes: sampleNotes)
            let intentType = getIntentType(intent)
            
            if intentType == expectedType {
                print("✅ PASS: \(description)")
                print("   Input: '\(input)' → \(intentType)")
                passed += 1
            } else {
                print("❌ FAIL: \(description)")
                print("   Input: '\(input)'")
                print("   Expected: \(expectedType)")
                print("   Got: \(intentType)")
                failed += 1
            }
        }
        
        print("\n=== Test Results ===")
        print("Total: \(passed + failed)")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        print("Success Rate: \(Int((Double(passed) / Double(passed + failed)) * 100))%")
    }
    
    private static func getIntentType(_ intent: CommandIntent) -> String {
        switch intent {
        case .addBook: return "addBook"
        case .createQuote: return "createQuote"
        case .createNote: return "createNote"
        case .searchLibrary: return "searchLibrary"
        case .searchNotes: return "searchNotes"
        case .searchAll: return "searchAll"
        case .existingBook: return "existingBook"
        case .existingNote: return "existingNote"
        case .unknown: return "unknown"
        }
    }
}

// Extension to make testing easier
extension View {
    func runIntentTests() -> some View {
        self.onAppear {
            #if DEBUG
            CommandIntentTests.runAllTests()
            #endif
        }
    }
}