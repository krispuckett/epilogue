import SwiftUI

// MARK: - Command Intent
enum CommandIntent {
    case addBook(query: String)
    case createQuote(text: String)
    case createNote(text: String)
    case searchLibrary(query: String)
    case searchNotes(query: String)
    case searchAll(query: String)
    case existingBook(book: Book)
    case existingNote(note: Note)
    case unknown
    
    // New intelligent commands with @mentions and multi-step
    case createNoteWithBook(text: String, book: Book) // Note with @book mention
    case createQuoteWithBook(text: String, book: Book) // Quote with @book mention
    case multiStepCommand([ChainedCommand]) // Complex multi-step operations
    case createReminder(text: String, date: Date) // Reminders with natural language
    case setReadingGoal(book: Book, pagesPerDay: Int) // Reading goals
    case batchAddBooks([String]) // Add multiple books at once
    
    var icon: String {
        switch self {
        case .addBook, .batchAddBooks:
            return "plus.circle"
        case .createQuote, .createQuoteWithBook:
            return "quote.opening"
        case .createNote, .createNoteWithBook:
            return "note.text"
        case .searchLibrary, .existingBook:
            return "magnifyingglass"
        case .searchNotes, .existingNote:
            return "doc.text.magnifyingglass"
        case .searchAll:
            return "magnifyingglass.circle"
        case .multiStepCommand:
            return "arrow.triangle.branch"
        case .createReminder:
            return "bell.badge"
        case .setReadingGoal:
            return "target"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .addBook, .batchAddBooks:
            return Color(red: 0.6, green: 0.4, blue: 0.8) // Purple for new books
        case .createQuote, .createNote, .createQuoteWithBook, .createNoteWithBook:
            return Color(red: 1.0, green: 0.55, blue: 0.26) // Orange for notes
        case .searchLibrary, .existingBook, .searchNotes, .existingNote, .searchAll:
            return Color(red: 0.4, green: 0.6, blue: 0.9) // Blue for search
        case .multiStepCommand:
            return Color(red: 0.9, green: 0.3, blue: 0.5) // Pink for complex
        case .createReminder:
            return Color(red: 0.5, green: 0.8, blue: 0.4) // Green for reminders
        case .setReadingGoal:
            return Color(red: 0.95, green: 0.75, blue: 0.2) // Gold for goals
        case .unknown:
            return .gray
        }
    }
    
    var actionText: String {
        switch self {
        case .addBook:
            return "Add Book"
        case .createQuote, .createQuoteWithBook:
            return "Save Quote"
        case .createNote, .createNoteWithBook:
            return "Save Note"
        case .searchLibrary:
            return "Search Books"
        case .searchNotes:
            return "Search Notes"
        case .searchAll:
            return "Search All"
        case .existingBook:
            return "Open Book"
        case .existingNote:
            return "View Note"
        case .batchAddBooks:
            return "Add Multiple Books"
        case .multiStepCommand:
            return "Execute Commands"
        case .createReminder:
            return "Set Reminder"
        case .setReadingGoal:
            return "Set Goal"
        case .unknown:
            return "Enter"
        }
    }
    
    var displayName: String {
        switch self {
        case .addBook:
            return "Add Book"
        case .createQuote, .createQuoteWithBook:
            return "New Quote"
        case .createNote, .createNoteWithBook:
            return "New Note"
        case .searchLibrary:
            return "Search Library"
        case .searchNotes:
            return "Search Notes"
        case .searchAll:
            return "Search Everything"
        case .existingBook:
            return "Found in Library"
        case .existingNote:
            return "Found Note"
        case .batchAddBooks:
            return "Add Multiple Books"
        case .multiStepCommand:
            return "Multi-Step Command"
        case .createReminder:
            return "Set Reminder"
        case .setReadingGoal:
            return "Reading Goal"
        case .unknown:
            return "Command"
        }
    }
}

// MARK: - Equatable Conformance
extension CommandIntent: Equatable {
    static func == (lhs: CommandIntent, rhs: CommandIntent) -> Bool {
        switch (lhs, rhs) {
        case (.addBook(let a), .addBook(let b)):
            return a == b
        case (.createQuote(let a), .createQuote(let b)):
            return a == b
        case (.createNote(let a), .createNote(let b)):
            return a == b
        case (.searchLibrary(let a), .searchLibrary(let b)):
            return a == b
        case (.searchNotes(let a), .searchNotes(let b)):
            return a == b
        case (.searchAll(let a), .searchAll(let b)):
            return a == b
        case (.existingBook(let a), .existingBook(let b)):
            return a.id == b.id
        case (.existingNote(let a), .existingNote(let b)):
            return a.id == b.id
        case (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

// MARK: - Command Parser
struct CommandParser {
    static func parse(_ input: String, books: [Book] = [], notes: [Note] = []) -> CommandIntent {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let lowercased = trimmed.lowercased()
        print("CommandParser: Parsing input: '\(input)' (lowercased: '\(lowercased)')")
        print("CommandParser: Available books count: \(books.count)")
        print("CommandParser: Available notes count: \(notes.count)")
        
        // FIRST: Check for @book mentions
        if input.contains("@") {
            let (cleanText, mentionedBook) = BookMentionParser.extractBookContext(from: input, books: books)
            
            if let book = mentionedBook {
                // Determine intent type with book context
                if lowercased.contains("note") || lowercased.contains("thought") {
                    return .createNoteWithBook(text: cleanText, book: book)
                } else if lowercased.contains("quote") || cleanText.contains("\"") {
                    return .createQuoteWithBook(text: cleanText, book: book)
                }
                // Default to note with book
                return .createNoteWithBook(text: cleanText, book: book)
            }
        }
        
        // SECOND: Check for multi-step commands
        if lowercased.contains(" and ") || lowercased.contains(" & ") {
            let chainedCommands = MultiStepCommandParser.parse(input, books: books)
            if !chainedCommands.isEmpty {
                return .multiStepCommand(chainedCommands)
            }
        }
        
        // THIRD: Check for reminders
        if lowercased.contains("remind") || lowercased.contains("reminder") {
            if let date = NaturalLanguageDateParser.parse(from: input) {
                // Extract the reminder text (what comes after "remind me to" or before the time)
                var reminderText = input
                    .replacingOccurrences(of: "remind me to ", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "remind me ", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "reminder: ", with: "", options: .caseInsensitive)
                
                // Clean up time references from the text
                reminderText = reminderText
                    .replacingOccurrences(of: #"in \d+ minutes?"#, with: "", options: [.regularExpression, .caseInsensitive])
                    .replacingOccurrences(of: #"in \d+ hours?"#, with: "", options: [.regularExpression, .caseInsensitive])
                    .replacingOccurrences(of: #"in \d+ days?"#, with: "", options: [.regularExpression, .caseInsensitive])
                    .replacingOccurrences(of: "tomorrow", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "tonight", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                
                if reminderText.isEmpty {
                    reminderText = "Time to read!"
                }
                
                return .createReminder(text: reminderText, date: date)
            } else {
                // Date parsing failed but it's clearly a reminder intent
                print("Warning: Reminder detected but date parsing failed for: \(input)")
                // Don't fall through to other intents
                return .unknown
            }
        }
        
        // FOURTH: Check for reading goals
        if lowercased.contains("goal") || lowercased.contains("pages per day") || lowercased.contains("pages daily") {
            let goalCommands = MultiStepCommandParser.parse(input, books: books)
            for command in goalCommands {
                if case .setReadingGoal(let book, let pages) = command {
                    return .setReadingGoal(book: book, pagesPerDay: pages)
                }
            }
        }
        
        // Debug: Print first few book titles
        if books.count > 0 {
            print("CommandParser: First book: '\(books[0].title)'")
            if books.count > 1 {
                print("CommandParser: Books in library: \(books.prefix(3).map { $0.title }.joined(separator: ", "))")
            }
        }
        
        // Empty input
        if trimmed.isEmpty {
            print("CommandParser: Empty input, returning .unknown")
            return .unknown
        }
        
        // Phase 1: Check for exact matches with existing books
        if let matchedBook = findExistingBook(input: trimmed, books: books) {
            print("CommandParser: Found existing book match: '\(matchedBook.title)'")
            return .existingBook(book: matchedBook)
        }
        
        // Phase 2: Check for exact matches with existing notes
        if let matchedNote = findExistingNote(input: trimmed, notes: notes) {
            print("CommandParser: Found existing note match")
            return .existingNote(note: matchedNote)
        }
        
        // Phase 3: Smart Quote Detection (check quotes BEFORE notes!)
        if isLikelyQuote(input: trimmed) {
            print("CommandParser: Detected quote pattern")
            return .createQuote(text: input)
        }
        
        // Phase 4: Note Detection (check after quotes)
        if isLikelyNote(input: trimmed) {
            print("CommandParser: Detected note pattern")
            return .createNote(text: input)
        }
        
        // Phase 5: Smart Book Title Detection - Check for "by" pattern first
        if trimmed.lowercased().contains(" by ") {
            let query = cleanBookQuery(from: input)
            print("CommandParser: Detected 'by' pattern for book, query: '\(query)'")
            return .addBook(query: query)
        }
        
        // Phase 6: Advanced Book Title Detection with ML-like scoring
        let bookScore = calculateBookTitleScore(input: trimmed)
        let noteScore = calculateNoteScore(input: trimmed)
        
        print("CommandParser: Scores - Book: \(bookScore), Note: \(noteScore)")
        
        // If book score is significantly higher than note score, it's likely a book
        if bookScore > noteScore && bookScore > 0.4 {
            let query = cleanBookQuery(from: input)
            print("CommandParser: Detected book title (score: \(bookScore)), query: '\(query)'")
            return .addBook(query: query)
        }
        
        // Phase 6.5: Smart lowercase book title detection
        // Many users type book titles in lowercase - be smart about it
        if trimmed.count >= 3 && trimmed.count <= 100 && !trimmed.contains("?") {
            // Check if it matches common book title patterns
            if matchesBookTitlePattern(input: trimmed) {
                let query = cleanBookQuery(from: input)
                print("CommandParser: Detected book title via pattern matching, query: '\(query)'")
                return .addBook(query: query)
            }
        }
        
        // Phase 6: Explicit Commands
        // Book additions - explicit commands
        if lowercased.starts(with: "add book") ||
           lowercased.starts(with: "reading ") ||
           lowercased.starts(with: "finished ") ||
           lowercased.starts(with: "i'm reading ") ||
           lowercased.starts(with: "currently reading ") {
            let query = cleanBookQuery(from: input)
            print("CommandParser: Detected explicit book command, query: '\(query)'")
            return .addBook(query: query)
        }
        
        // Search patterns
        if lowercased.starts(with: "search ") {
            let query = String(input.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            if lowercased.starts(with: "search notes") || lowercased.starts(with: "search note") {
                return .searchNotes(query: String(input.dropFirst(12)).trimmingCharacters(in: .whitespaces))
            } else if lowercased.starts(with: "search books") || lowercased.starts(with: "search library") {
                return .searchLibrary(query: query)
            } else {
                return .searchAll(query: query)
            }
        }
        
        // Default: If no clear intent, check if it might be a search
        if trimmed.count < 50 && !trimmed.contains(".") && !trimmed.contains("?") {
            // One more attempt to find books with very loose matching
            if trimmed.count >= 2 {
                for book in books {
                    if book.title.lowercased().contains(trimmed.lowercased()) || 
                       book.author.lowercased().contains(trimmed.lowercased()) {
                        print("CommandParser: Found book in final search: '\(book.title)'")
                        return .existingBook(book: book)
                    }
                }
            }
            
            print("CommandParser: Short input without punctuation, returning .searchAll")
            return .searchAll(query: input)
        }
        
        // Very long text defaults to note
        if trimmed.count > 50 {
            print("CommandParser: Long text, defaulting to .createNote")
            return .createNote(text: input)
        }
        
        print("CommandParser: Falling back to .unknown")
        return .unknown
    }
    
    // MARK: - Smart Detection Heuristics
    
    private static func isLikelyBookTitle(input: String) -> Bool {
        // Book Title Detection:
        // - 1-10 words (more flexible)
        // - Contains "by [Author Name]"
        // - Doesn't start with lowercase (unless single word)
        // - Not a question
        // - Not a common note pattern
        
        let words = input.split(separator: " ")
        let wordCount = words.count
        
        // More flexible word count - even single word could be a book title
        guard wordCount >= 1 && wordCount <= 10 else { return false }
        
        // Check if it's a question
        if input.contains("?") { return false }
        
        // Single word book titles are common (e.g., "Dune", "1984", "Beloved")
        if wordCount == 1 {
            // If it's a single capitalized word, it's likely a book title
            if let firstChar = input.first, firstChar.isUppercase {
                return true
            }
        }
        
        // Check if starts with lowercase (for multi-word inputs)
        if wordCount > 1, let firstChar = input.first, firstChar.isLowercase { 
            return false 
        }
        
        // Check for "by Author" pattern - strong indicator
        if input.lowercased().contains(" by ") {
            return true
        }
        
        // For 1-3 word inputs, be more lenient
        if wordCount <= 3 {
            // If first word is capitalized, assume it's a book
            if let firstWord = words.first, 
               let firstChar = firstWord.first,
               firstChar.isUppercase {
                return true
            }
        }
        
        // For longer inputs, check if most words are capitalized (title case)
        let capitalizedWords = words.filter { word in
            guard let first = word.first else { return false }
            return first.isUppercase || word.count <= 3 // Allow short words like "of", "the"
        }
        
        // If more than half the words are capitalized, likely a title
        return Double(capitalizedWords.count) / Double(words.count) > 0.5
    }
    
    private static func isLikelyQuote(input: String) -> Bool {
        // Quote Detection:
        // - Reaction phrase followed by text
        // - Starts with quotation marks
        // - Or contains "..."
        // - Or is > 50 characters without being a question
        // - Has quote attribution pattern
        
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let lowercased = trimmed.lowercased()
        
        // NEW: Check for reaction-based quote patterns
        let reactionPhrases = [
            "this is beautiful", "i love this", "listen to this", 
            "oh wow", "this is amazing", "here's a great line",
            "check this out", "this part", "the author says",
            "this is incredible", "this is perfect", "yes exactly",
            "this speaks to me", "this is so good", "love this",
            "wow listen to this", "oh my god", "oh my gosh",
            "this is powerful", "this is profound", "this is brilliant"
        ]
        
        // Check if input starts with reaction phrase and has substantial text after
        for phrase in reactionPhrases {
            if lowercased.starts(with: phrase) && trimmed.count > phrase.count + 10 {
                // There's text after the reaction phrase - likely a quote
                return true
            }
        }
        
        // Check for quotation marks
        if trimmed.hasPrefix("\"") || trimmed.hasPrefix("\u{201C}") ||
           trimmed.hasPrefix("'") || trimmed.hasPrefix("\u{2018}") {
            return true
        }
        
        // Check for quote attribution format
        if isQuoteFormat(input) || hasQuoteAttribution(input) {
            return true
        }
        
        // Check for ellipsis
        if trimmed.contains("...") {
            return true
        }
        
        // Long text that's not a question might be a quote
        if trimmed.count > 50 && !trimmed.contains("?") && !isLikelyNote(input: trimmed) {
            // Check if it reads like a quote (more formal language)
            let hasQuoteLikeStructure = trimmed.contains(",") || trimmed.contains(";") || trimmed.contains("—")
            return hasQuoteLikeStructure
        }
        
        return false
    }
    
    private static func isLikelyNote(input: String) -> Bool {
        // Note Detection:
        // - Starts with "note:", "thought:", "re:"
        // - Or is a complete sentence with punctuation
        // - Or references a page number
        // - Or starts with common note patterns
        
        let lowercased = input.lowercased()
        
        // Explicit note prefixes
        let notePrefixes = ["note:", "note -", "thought:", "idea:", "reminder:", "todo:", "re:", "regarding:"]
        for prefix in notePrefixes {
            if lowercased.starts(with: prefix) {
                return true
            }
        }
        
        // Check for page references
        if lowercased.contains("page ") || lowercased.contains("p. ") || lowercased.contains("pg ") {
            return true
        }
        
        // Check if it's a complete sentence (ends with punctuation)
        let lastChar = input.last
        if lastChar == "." || lastChar == "!" {
            // But not if it looks like a book title
            if !isLikelyBookTitle(input: input) {
                return true
            }
        }
        
        // Informal language patterns that suggest notes
        let notePatterns = ["i think", "i want", "i feel", "i believe", "i need", "i wish", "i love", "i hate", 
                          "remember", "todo", "need to", "should", "must", "don't forget", "my thoughts", "my opinion"]
        for pattern in notePatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private static func findExistingBook(input: String, books: [Book]) -> Book? {
        let searchTerms = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
        
        print("CommandParser: Searching for book with terms: \(searchTerms)")
        
        // First, try exact title match
        if let book = books.first(where: { $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == input.lowercased() }) {
            print("CommandParser: Found exact match: '\(book.title)'")
            return book
        }
        
        // Then try to find books that contain all search terms
        if searchTerms.count > 0 {
            for book in books {
                let titleLower = book.title.lowercased()
                let authorLower = book.author.lowercased()
                
                // Check if all search terms are in the title
                let allTermsInTitle = searchTerms.allSatisfy { term in
                    titleLower.contains(term)
                }
                
                if allTermsInTitle {
                    print("CommandParser: Found book by title match: '\(book.title)'")
                    return book
                }
                
                // Check if search contains "by" and the author name matches after "by"
                if let byIndex = searchTerms.firstIndex(of: "by"), byIndex < searchTerms.count - 1 {
                    let authorSearchTerms = Array(searchTerms.suffix(from: byIndex + 1))
                    let authorSearchString = authorSearchTerms.joined(separator: " ")
                    
                    if authorLower.contains(authorSearchString) || authorSearchString.count >= 3 && authorLower.hasPrefix(authorSearchString) {
                        print("CommandParser: Found book by author match: '\(book.title)' by '\(book.author)'")
                        return book
                    }
                }
            }
        }
        
        // Finally, try single partial match if input is long enough
        if input.count >= 3 {
            if let book = books.first(where: { $0.title.lowercased().contains(input.lowercased()) }) {
                print("CommandParser: Found book by partial match: '\(book.title)'")
                return book
            }
        }
        
        print("CommandParser: No book match found for: '\(input)'")
        return nil
    }
    
    private static func findExistingNote(input: String, notes: [Note]) -> Note? {
        let searchTerms = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
        
        print("CommandParser: Searching for note with terms: \(searchTerms)")
        print("CommandParser: Available notes count: \(notes.count)")
        
        // Debug: Print all note contents to find the issue
        if notes.count > 0 {
            print("CommandParser: All notes:")
            for (index, note) in notes.enumerated() {
                print("  \(index): [Note - \(note.content.count) characters] (type: \(note.type))")
            }
        }
        
        // First, try exact content match
        if let note = notes.first(where: { $0.content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == input.lowercased() }) {
            print("CommandParser: Found exact note match")
            return note
        }
        
        // Then try to find notes that contain all search terms
        if searchTerms.count > 0 {
            for note in notes {
                let contentLower = note.content.lowercased()
                
                // Check if all search terms are in the content
                let allTermsInContent = searchTerms.allSatisfy { term in
                    contentLower.contains(term)
                }
                
                if allTermsInContent {
                    print("CommandParser: Found note match: '\(note.content.prefix(50))...'")
                    return note
                }
                
                // Also check if it's a partial match of the beginning
                if contentLower.hasPrefix(input.lowercased()) {
                    print("CommandParser: Found note by prefix match: '\(note.content.prefix(50))...'")
                    return note
                }
            }
        }
        
        // Finally, try partial match if input is long enough (reduced threshold)
        if input.count >= 3 {
            if let note = notes.first(where: { $0.content.lowercased().contains(input.lowercased()) }) {
                print("CommandParser: Found note by partial match: '\(note.content.prefix(50))...'")
                return note
            }
        }
        
        print("CommandParser: No note match found for: '\(input)'")
        return nil
    }
    
    static func cleanBookQuery(from input: String) -> String {
        var query = input
        
        // Remove common prefixes
        let prefixes = ["add book ", "add the book ", "add the ", "add ", "reading ", "finished ", "book: ", "i'm reading ", "currently reading "]
        for prefix in prefixes {
            if query.lowercased().starts(with: prefix) {
                query = String(query.dropFirst(prefix.count))
                break
            }
        }
        
        // Clean up the query
        query = query.trimmingCharacters(in: .whitespaces)
        
        // Remove trailing punctuation
        if query.hasSuffix(".") || query.hasSuffix(",") || query.hasSuffix("!") || query.hasSuffix("?") {
            query = String(query.dropLast())
        }
        
        return query
    }
    
    private static func containsActionKeywords(_ text: String) -> Bool {
        let actionKeywords = ["add", "new", "create", "quote", "note", "thought"]
        return actionKeywords.contains { text.contains($0) }
    }
    
    // Check if text matches quote format: "content" - author
    private static func isQuoteFormat(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // Check for "content" - author format
        let quotePattern = #"^["\u{201C}].*["\u{201D}]\s*[-–—]\s*.+"#
        if let regex = try? NSRegularExpression(pattern: quotePattern, options: []) {
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                return true
            }
        }
        
        // Also check for simple quoted text
        return (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
               (trimmed.hasPrefix("\u{201C}") && trimmed.hasSuffix("\u{201D}"))
    }
    
    // Parse quote content and attribution
    static func parseQuote(_ text: String) -> (content: String, author: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let lowercased = trimmed.lowercased()
        
        // Remove "quote:" prefix if present
        var workingText = trimmed
        if workingText.lowercased().hasPrefix("quote:") {
            workingText = String(workingText.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        }
        
        // NEW: Handle reaction-based quotes
        let reactionPhrases = [
            "this is beautiful", "i love this", "listen to this", 
            "oh wow", "this is amazing", "here's a great line",
            "check this out", "this part", "the author says",
            "this is incredible", "this is perfect", "yes exactly",
            "this speaks to me", "this is so good", "love this",
            "wow listen to this", "oh my god", "oh my gosh",
            "this is powerful", "this is profound", "this is brilliant"
        ]
        
        // Check if it starts with a reaction phrase
        for phrase in reactionPhrases {
            if lowercased.starts(with: phrase) && workingText.count > phrase.count + 10 {
                // Extract everything after the reaction
                if let phraseRange = workingText.lowercased().range(of: phrase) {
                    workingText = String(workingText[phraseRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    
                    // Clean up common filler words
                    let fillerWords = ["um", "uh", "umm", "uhh", "...", "okay", "so", "like"]
                    for filler in fillerWords {
                        if workingText.lowercased().starts(with: filler + " ") {
                            workingText = String(workingText.dropFirst(filler.count + 1)).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
                break
            }
        }
        
        // First try to match quoted text with attribution: "content" author, book, page
        let quotePatterns = [
            "^\"(.+?)\"\\s*(.+)$",                          // Regular double quotes
            "^[\u{201C}](.+?)[\u{201D}]\\s*(.+)$",         // Smart quotes
            "^'(.+?)'\\s*(.+)$",                            // Single quotes
            "^[\u{2018}](.+?)[\u{2019}]\\s*(.+)$"          // Smart single quotes
        ]
        
        for pattern in quotePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(location: 0, length: workingText.utf16.count)
                if let match = regex.firstMatch(in: workingText, options: [], range: range) {
                    if let contentRange = Range(match.range(at: 1), in: workingText),
                       let attributionRange = Range(match.range(at: 2), in: workingText) {
                        // Extract the quote content (without quotes)
                        var quoteContent = String(workingText[contentRange]).trimmingCharacters(in: .whitespaces)
                        
                        // Clean any trailing dashes that might have been included
                        while quoteContent.hasSuffix("-") || quoteContent.hasSuffix("—") || quoteContent.hasSuffix("–") {
                            quoteContent = String(quoteContent.dropLast()).trimmingCharacters(in: .whitespaces)
                        }
                        let attribution = String(workingText[attributionRange]).trimmingCharacters(in: .whitespaces)
                        
                        // Parse the attribution (e.g., "Ryan Holiday, The Obstacle is the Way, pg 40")
                        let parts = attribution.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        
                        var author: String? = nil
                        var bookTitle: String? = nil
                        var pageNumber: Int? = nil
                        
                        if parts.indices.contains(0) {
                            author = parts[0]
                        }
                        if parts.indices.contains(1) {
                            bookTitle = parts[1]
                        }
                        if parts.indices.contains(2) {
                            let pageStr = parts[2]
                            // Extract page number from strings like "pg 30", "p. 30", "page 30"
                            if let pageMatch = pageStr.range(of: #"\d+"#, options: .regularExpression) {
                                pageNumber = Int(pageStr[pageMatch])
                            }
                        }
                        
                        // Format with our special separator
                        if let author = author {
                            var result = author
                            if let book = bookTitle {
                                result += "|||BOOK|||" + book
                            }
                            if let page = pageNumber {
                                result += "|||PAGE|||" + String(page)
                            }
                            return (content: quoteContent, author: result)
                        }
                        
                        return (content: quoteContent, author: author)
                    }
                }
            }
        }
        
        // Check if it's a quote without quotation marks but with attribution
        if hasQuoteAttribution(workingText) && !workingText.contains("\"") && !workingText.contains("\u{201C}") {
            // Parse pattern: "quote content author, book, page"
            // Split by commas first
            let parts = workingText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            if parts.count >= 2 {
                // Try to find where the quote ends and author begins
                // Look for capital letters that might indicate author name
                let firstPart = parts[0]
                
                // Split by spaces and find potential author name start
                let words = firstPart.split(separator: " ")
                var quoteEndIndex = words.count
                
                // Work backwards to find where author might start
                // (usually the last 1-2 capitalized words before the comma)
                for i in stride(from: words.count - 1, through: 0, by: -1) {
                    let word = String(words[i])
                    if word.first?.isUppercase == true && i < words.count - 1 {
                        // Check if this and next word could be author name
                        if i > 0 {  // Make sure there's content before
                            quoteEndIndex = i
                            break
                        }
                    }
                }
                
                // Extract quote and author
                let quoteWords = words.prefix(quoteEndIndex)
                let authorWords = words.suffix(from: quoteEndIndex)
                
                if !quoteWords.isEmpty && !authorWords.isEmpty {
                    let content = quoteWords.joined(separator: " ")
                    let author = authorWords.joined(separator: " ")
                    
                    // Reconstruct attribution with remaining parts
                    var attributionParts = [author]
                    if parts.count > 1 {
                        attributionParts.append(contentsOf: parts.suffix(from: 1))
                    }
                    let fullAttribution = attributionParts.joined(separator: ", ")
                    
                    return processAttribution(content: content, attribution: fullAttribution)
                }
            }
        }
        
        // Try to parse "content" - author format or "content" author format
        // First try with dash separator
        let quoteWithDashPattern = #"^["\u{201C}](.+?)["\u{201D}]\s*[-–—]\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: quoteWithDashPattern, options: []) {
            let range = NSRange(location: 0, length: workingText.utf16.count)
            if let match = regex.firstMatch(in: workingText, options: [], range: range) {
                if let contentRange = Range(match.range(at: 1), in: workingText),
                   let authorRange = Range(match.range(at: 2), in: workingText) {
                    var content = String(workingText[contentRange]).trimmingCharacters(in: .whitespaces)
                    
                    // Clean any trailing dashes
                    while content.hasSuffix("-") || content.hasSuffix("—") || content.hasSuffix("–") {
                        content = String(content.dropLast()).trimmingCharacters(in: .whitespaces)
                    }
                    let author = String(workingText[authorRange]).trimmingCharacters(in: .whitespaces)
                    
                    // Process the author part which might contain book and page
                    return processAttribution(content: content, attribution: author)
                }
            }
        }
        
        // Try without dash - just "content" followed by attribution
        let quoteWithoutDashPattern = #"^["\u{201C}](.+?)["\u{201D}]\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: quoteWithoutDashPattern, options: []) {
            let range = NSRange(location: 0, length: workingText.utf16.count)
            if let match = regex.firstMatch(in: workingText, options: [], range: range) {
                if let contentRange = Range(match.range(at: 1), in: workingText),
                   let authorRange = Range(match.range(at: 2), in: workingText) {
                    var content = String(workingText[contentRange]).trimmingCharacters(in: .whitespaces)
                    
                    // Clean any trailing dashes
                    while content.hasSuffix("-") || content.hasSuffix("—") || content.hasSuffix("–") {
                        content = String(content.dropLast()).trimmingCharacters(in: .whitespaces)
                    }
                    let author = String(workingText[authorRange]).trimmingCharacters(in: .whitespaces)
                    
                    // Process the author part which might contain book and page
                    return processAttribution(content: content, attribution: author)
                }
            }
        }
        
        // Check for simple dash attribution without quotes
        if let dashRange = workingText.range(of: " — ") ?? workingText.range(of: " - ") {
            let content = String(workingText[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let attribution = String(workingText[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Remove quotes if present
            var cleanContent = content
            if (cleanContent.hasPrefix("\"") && cleanContent.hasSuffix("\"")) ||
               (cleanContent.hasPrefix("\u{201C}") && cleanContent.hasSuffix("\u{201D}")) {
                cleanContent = String(cleanContent.dropFirst().dropLast())
            }
            
            // Process the attribution using helper function
            return processAttribution(content: cleanContent, attribution: attribution)
        }
        
        // If no author pattern, just extract content
        var content = workingText
        
        // Remove surrounding quotes if present
        if (content.hasPrefix("\"") && content.hasSuffix("\"")) ||
           (content.hasPrefix("\u{201C}") && content.hasSuffix("\u{201D}")) {
            content = String(content.dropFirst().dropLast())
        }
        
        return (content, nil)
    }
    
    // Check if text has quote attribution pattern
    private static func hasQuoteAttribution(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // Check for patterns like "text author, book, page"
        // Must have at least one comma to indicate author and book
        let commaCount = trimmed.filter { $0 == "," }.count
        if commaCount >= 1 {
            // Check if it contains page indicators
            let lowercased = trimmed.lowercased()
            if lowercased.contains("pg ") || lowercased.contains("page ") || lowercased.contains("p. ") {
                return true
            }
            // Or if it has author, book pattern (at least 2 parts)
            let parts = trimmed.split(separator: ",")
            if parts.count >= 2 && !parts[0].isEmpty && !parts[1].isEmpty {
                return true
            }
        }
        
        return false
    }
    
    // Helper function to process attribution that might contain author, book, and page
    private static func processAttribution(content: String, attribution: String) -> (content: String, author: String?) {
        // Check if attribution contains commas (e.g., "Seneca, On the Shortness of Life, pg 30")
        let parts = attribution.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        if parts.count >= 2 {
            let author = parts[0]
            var book = parts[1]
            var pageInfo: String? = nil
            
            // Check if we have page info in the last part
            if parts.count >= 3 {
                let lastPart = parts[2]
                // Check for page patterns: "p. 47", "page 47", "pg 47", or just "47"
                if lastPart.lowercased().hasPrefix("p.") || 
                   lastPart.lowercased().hasPrefix("page") || 
                   lastPart.lowercased().hasPrefix("pg") ||
                   Int(lastPart) != nil {
                    pageInfo = lastPart
                } else {
                    // If not a page number, it might be part of the book title
                    book = "\(book), \(lastPart)"
                }
            }
            
            // Format with our special separator including page if present
            var result = "\(author)|||BOOK|||\(book)"
            if let page = pageInfo {
                result += "|||PAGE|||\(page)"
            }
            return (content, result)
        }
        
        // No commas, just return the attribution as author
        return (content, attribution.isEmpty ? nil : attribution)
    }
}

// MARK: - Suggestion Model
struct CommandSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let intent: CommandIntent
    let description: String?
    
    init(text: String, icon: String, intent: CommandIntent, description: String? = nil) {
        self.text = text
        self.icon = icon
        self.intent = intent
        self.description = description
    }
    
    static func suggestions(for input: String) -> [CommandSuggestion] {
        guard !input.isEmpty else { return [] }
        
        var suggestions: [CommandSuggestion] = []
        
        // Search suggestions
        suggestions.append(CommandSuggestion(
            text: "Search everywhere for \"\(input)\"",
            icon: "magnifyingglass.circle",
            intent: .searchAll(query: input)
        ))
        
        suggestions.append(CommandSuggestion(
            text: "Search notes for \"\(input)\"",
            icon: "doc.text.magnifyingglass",
            intent: .searchNotes(query: input)
        ))
        
        suggestions.append(CommandSuggestion(
            text: "Search books for \"\(input)\"",
            icon: "magnifyingglass",
            intent: .searchLibrary(query: input)
        ))
        
        // Suggest adding as book if it looks like a title
        if !input.lowercased().starts(with: "quote") && !input.lowercased().starts(with: "note") {
            suggestions.append(CommandSuggestion(
                text: "Add \"\(input)\" to library",
                icon: "plus.circle",
                intent: .addBook(query: input)
            ))
        }
        
        // Suggest quote if contains quotation marks
        if input.contains("\"") {
            suggestions.append(CommandSuggestion(
                text: "Save as quote",
                icon: "quote.opening",
                intent: .createQuote(text: input)
            ))
        }
        
        // Always offer note option
        suggestions.append(CommandSuggestion(
            text: "Save as note",
            icon: "note.text",
            intent: .createNote(text: input)
        ))
        
        return suggestions
    }
}

// MARK: - Extension with NLP Scoring Functions
extension CommandParser {
    
    static func calculateBookTitleScore(input: String) -> Double {
        var score = 0.0
        let words = input.split(separator: " ")
        let wordCount = words.count
        
        // Title length scoring (books typically have 1-8 words)
        if wordCount >= 1 && wordCount <= 3 {
            score += 0.3
        } else if wordCount <= 8 {
            score += 0.2
        } else if wordCount > 15 {
            score -= 0.2
        }
        
        // Check for capitalization (even if not perfect)
        let capitalizedWords = words.filter { $0.first?.isUppercase == true }.count
        if capitalizedWords > 0 {
            score += Double(capitalizedWords) / Double(wordCount) * 0.3
        }
        
        // Common book title words
        let bookTitleIndicators = [
            "the", "of", "and", "a", "an", "in", "on", "at", "to", "for",
            "book", "novel", "story", "tale", "chronicles", "adventures",
            "memoir", "biography", "history", "guide", "handbook"
        ]
        
        for word in words {
            if bookTitleIndicators.contains(String(word).lowercased()) {
                score += 0.05
            }
        }
        
        // Classic book title patterns
        let patterns = [
            "the .* of .*",  // "The Lord of the Rings"
            "a .* of .*",    // "A Tale of Two Cities"
            ".* and .*",     // "Pride and Prejudice"
            "the .*'s .*",   // "The Hitchhiker's Guide"
            ".* war$",       // "World War Z", "Cold War"
            ".* part .*",    // "Part One", "Part Two"
        ]
        
        for pattern in patterns {
            if input.lowercased().range(of: pattern, options: .regularExpression) != nil {
                score += 0.2
                break
            }
        }
        
        // Popular book words
        let popularBookWords = ["harry", "potter", "lord", "rings", "game", "thrones", 
                               "hunger", "games", "twilight", "hobbit", "narnia", 
                               "pride", "prejudice", "gatsby", "mockingbird",
                               "1984", "fahrenheit", "brave", "world", "odyssey",
                               "iliad", "quixote", "moby", "dick", "war", "peace"]
        
        for word in words {
            if popularBookWords.contains(String(word).lowercased()) {
                score += 0.15
            }
        }
        
        // Numbers often appear in book titles
        if words.contains(where: { $0.rangeOfCharacter(from: .decimalDigits) != nil }) {
            score += 0.1
        }
        
        // Ends with a number (common for series)
        if let lastWord = words.last, Int(lastWord) != nil {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    static func calculateNoteScore(input: String) -> Double {
        var score = 0.0
        let lowercased = input.lowercased()
        
        // Note indicators
        if lowercased.starts(with: "remember") || lowercased.starts(with: "don't forget") ||
           lowercased.starts(with: "todo") || lowercased.starts(with: "reminder") ||
           lowercased.starts(with: "note to self") || lowercased.starts(with: "important") {
            score += 0.5
        }
        
        // Questions are often notes
        if input.contains("?") {
            score += 0.3
        }
        
        // Personal pronouns suggest notes
        let personalPronouns = ["i ", "me ", "my ", "we ", "our ", "i'm ", "i've ", "i'll "]
        for pronoun in personalPronouns {
            if lowercased.contains(pronoun) {
                score += 0.1
                break
            }
        }
        
        // Action verbs suggest notes
        let actionVerbs = ["need to", "should", "must", "have to", "want to", "going to"]
        for verb in actionVerbs {
            if lowercased.contains(verb) {
                score += 0.2
                break
            }
        }
        
        // URLs or email patterns suggest notes
        if input.contains("http://") || input.contains("https://") || 
           input.contains("www.") || input.contains("@") || input.contains(".com") {
            score += 0.4
        }
        
        // Very long text is likely a note
        if input.count > 100 {
            score += 0.3
        }
        
        return min(score, 1.0)
    }
    
    static func matchesBookTitlePattern(input: String) -> Bool {
        let lowercased = input.lowercased()
        let words = lowercased.split(separator: " ")
        
        // Single word that could be a book title
        if words.count == 1 && input.count >= 3 {
            // Famous single-word books
            let singleWordBooks = ["dune", "emma", "dracula", "frankenstein", "hamlet", 
                                  "macbeth", "othello", "beloved", "atonement", "middlesex",
                                  "americanah", "pachinko", "circe", "hamnet", "klara"]
            if singleWordBooks.contains(lowercased) {
                return true
            }
        }
        
        // Common book title structures (even in lowercase)
        let bookPatterns = [
            // Series patterns
            "^.+ book (one|two|three|four|five|\\d+)$",
            "^.+ volume (i|ii|iii|iv|v|\\d+)$",
            "^.+ part (one|two|three|\\d+)$",
            
            // Common title patterns
            "^the .+$",                    // "the hobbit"
            "^a .+ (of|in|at|on) .+$",    // "a game of thrones"
            "^.+'s .+$",                   // "harry's adventure"
            "^.+ and the .+$",             // "harry and the stone"
            
            // Genre patterns
            "^.+ (chronicles|adventures|tales|story|stories)$",
            "^(autobiography|biography|memoir|diary) of .+$",
            "^.+ (handbook|guide|manual)$",
            
            // Classic structures
            "^(life|death|birth|rise|fall|return) of .+$",
            "^.+ (rising|falling|returns|begins|ends)$"
        ]
        
        for pattern in bookPatterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Check if it's likely a book series mention
        if lowercased.contains("series") || lowercased.contains("trilogy") || 
           lowercased.contains("book") || lowercased.contains("novel") {
            return true
        }
        
        // If 2-5 words and doesn't look like a sentence, probably a title
        if words.count >= 2 && words.count <= 5 {
            // Check if it lacks typical sentence structure
            let sentenceIndicators = ["is", "are", "was", "were", "can", "will", "would", 
                                     "should", "could", "have", "has", "had", "do", "does", "did"]
            let hasSentenceStructure = words.contains { sentenceIndicators.contains(String($0)) }
            
            if !hasSentenceStructure && !input.contains("?") && !input.contains("!") {
                return true
            }
        }
        
        return false
    }
}
