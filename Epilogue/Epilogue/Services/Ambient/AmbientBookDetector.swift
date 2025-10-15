import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - AmbientBookDetector
// Natural language detection for book mentions in ambient mode
class AmbientBookDetector: ObservableObject {
    static let shared = AmbientBookDetector()
    
    @Published var detectedBook: Book?
    @Published var confidence: Double = 0.0
    @Published var isDetecting: Bool = false
    
    // Book library reference
    private var libraryBooks: [Book] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Detection patterns
    private let bookTriggerPhrases = [
        "i'm reading",
        "currently reading",
        "just started",
        "finished reading",
        "reading a book called",
        "this book",
        "the book",
        "reminds me of",
        "like in",
        "similar to",
        "chapter",
        "page"
    ]
    
    private let authorTriggerPhrases = [
        "by",
        "written by",
        "author",
        "wrote"
    ]
    
    private init() {
        setupObservers()
        loadLibrary()
    }
    
    // MARK: - Detection Control
    
    func startDetection() {
        isDetecting = true
        detectedBook = nil
        confidence = 0.0
        #if DEBUG
        print("📚 Book detection started")
        #endif
    }
    
    func stopDetection() {
        isDetecting = false
        #if DEBUG
        print("📚 Book detection stopped")
        #endif
    }
    
    func resetDetection() {
        detectedBook = nil
        confidence = 0.0
        #if DEBUG
        print("📚 Book detection reset")
        #endif
    }
    
    // MARK: - Natural Language Processing
    
    func detectBookInText(_ text: String) {
        guard isDetecting else { 
            #if DEBUG
            print("📚 Book detection not active")
            #endif
            return 
        }
        
        #if DEBUG
        print("📚 Detecting book in text: \(text)")
        #endif
        let lowercased = text.lowercased()
        
        // ALWAYS check against known books first (even without trigger phrases)
        checkAgainstKnownBooks(text)
        
        // If no book detected yet, check for trigger phrases
        if detectedBook == nil {
            let containsTrigger = bookTriggerPhrases.contains { lowercased.contains($0) }
            
            if containsTrigger || lowercased.contains("reading") {
                // Extract potential book title
                if let bookTitle = extractBookTitle(from: text) {
                    findBookInLibrary(title: bookTitle)
                }
            }
        }
    }
    
    private func extractBookTitle(from text: String) -> String? {
        let lowercased = text.lowercased()
        
        // SMART PATTERNS - like how ChatGPT understands context
        
        // Pattern 1: "reading [book title]" - but flexible
        let readingPatterns = ["reading ", "i'm reading ", "currently reading ", "just started ", "finishing "]
        for pattern in readingPatterns {
            if let range = lowercased.range(of: pattern) {
                let afterPattern = String(text[range.upperBound...])
                
                // Extract until common delimiters
                let delimiters = CharacterSet(charactersIn: ",.!?;:")
                if let endIndex = afterPattern.rangeOfCharacter(from: delimiters) {
                    let title = String(afterPattern[..<endIndex.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        return title
                    }
                } else {
                    // Take the rest as title
                    let title = afterPattern.trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty && title.count < 100 {
                        return title
                    }
                }
            }
        }
        
        // Pattern 2: Just saying the book title directly (most natural!)
        // Check if the ENTIRE text might be a book title
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it's short enough and doesn't look like a question/statement
        if trimmedText.count <= 50 && 
           !trimmedText.contains("?") && 
           !trimmedText.lowercased().starts(with: "who") &&
           !trimmedText.lowercased().starts(with: "what") &&
           !trimmedText.lowercased().starts(with: "when") &&
           !trimmedText.lowercased().starts(with: "where") &&
           !trimmedText.lowercased().starts(with: "why") &&
           !trimmedText.lowercased().starts(with: "how") {
            
            // Check if it matches a known book
            for book in libraryBooks {
                let bookTitleLower = book.title.lowercased()
                let textLower = trimmedText.lowercased()
                
                // Exact match or very close match
                if bookTitleLower == textLower ||
                   bookTitleLower.contains(textLower) ||
                   textLower.contains(bookTitleLower) {
                    return book.title  // Return the proper title
                }
                
                // Fuzzy match - at least 70% of words match
                let bookWords = Set(bookTitleLower.split(separator: " ").map(String.init))
                let textWords = Set(textLower.split(separator: " ").map(String.init))
                let intersection = bookWords.intersection(textWords)
                
                if !bookWords.isEmpty && 
                   Double(intersection.count) / Double(bookWords.count) >= 0.7 {
                    return book.title
                }
            }
            
            // Even if not in library, might still be a book title
            if trimmedText.split(separator: " ").count <= 10 {
                return trimmedText
            }
        }
        
        // Pattern 3: quotes around title
        let quotePatterns = ["\"", "\u{201C}", "'", "\u{201C}", "\u{201D}"]
        for quote in quotePatterns {
            if let firstQuote = text.range(of: quote),
               let secondQuote = text.range(of: quote, range: firstQuote.upperBound..<text.endIndex) {
                let title = String(text[firstQuote.upperBound..<secondQuote.lowerBound])
                if !title.isEmpty && title.count < 100 {
                    return title
                }
            }
        }
        
        return nil
    }
    
    private func checkAgainstKnownBooks(_ text: String) {
        let lowercased = text.lowercased()
        #if DEBUG
        print("📚 Checking against \(libraryBooks.count) known books")
        #endif
        
        // Debug: Print first few book titles to verify library contents
        if libraryBooks.count > 0 {
            #if DEBUG
            print("📚 Books in library: \(libraryBooks.prefix(6).map { $0.title }.joined(separator: ", "))")
            #endif
        }
        
        for book in libraryBooks {
            // Check title match
            let titleLower = book.title.lowercased()
            if lowercased.contains(titleLower) {
                #if DEBUG
                print("📚 Found exact match: \(book.title)")
                #endif
                setDetectedBook(book, confidence: 0.9)
                return
            }
            
            // Check for title without articles (a, an, the)
            let titleWithoutArticles = titleLower
                .replacingOccurrences(of: "^(a |an |the )", with: "", options: .regularExpression)
            let textWithoutArticles = lowercased
                .replacingOccurrences(of: "^(a |an |the )", with: "", options: .regularExpression)
            
            if textWithoutArticles.contains(titleWithoutArticles) || titleWithoutArticles.contains(textWithoutArticles) {
                #if DEBUG
                print("📚 Found match without articles: \(book.title)")
                #endif
                setDetectedBook(book, confidence: 0.85)
                return
            }
            
            // Special case for "Lord of the Rings" variations
            if titleLower.contains("lord of the rings") || titleLower.contains("fellowship") || titleLower.contains("two towers") || titleLower.contains("return of the king") {
                if lowercased.contains("lord") && lowercased.contains("rings") {
                    #if DEBUG
                    print("📚 Found Lord of the Rings match: \(book.title)")
                    #endif
                    setDetectedBook(book, confidence: 0.85)
                    return
                }
            }
            
            // Check partial title match (at least 2 significant words)
            let titleWords = titleLower.split(separator: " ").filter { $0.count > 3 } // Filter out small words
            if titleWords.count >= 2 {
                let matchingWords = titleWords.filter { lowercased.contains($0) }
                if Double(matchingWords.count) / Double(titleWords.count) > 0.5 {
                    #if DEBUG
                    print("📚 Found partial match: \(book.title)")
                    #endif
                    setDetectedBook(book, confidence: 0.7)
                    return
                }
            }
            
            // Check author match
            let author = book.author
            let authorLower = author.lowercased()
            if lowercased.contains(authorLower) {
                // Author mentioned, check if this book is also referenced
                let titleWords = titleLower.split(separator: " ").prefix(2)
                if titleWords.allSatisfy({ lowercased.contains($0) }) {
                    setDetectedBook(book, confidence: 0.8)
                    return
                }
            }
        }
    }
    
    private func findBookInLibrary(title: String) {
        let searchTitle = title.lowercased()
        
        // Exact match
        if let exactMatch = libraryBooks.first(where: { $0.title.lowercased() == searchTitle }) {
            setDetectedBook(exactMatch, confidence: 1.0)
            return
        }
        
        // Fuzzy match
        let matches = libraryBooks.compactMap { book -> (Book, Double)? in
            let similarity = calculateSimilarity(searchTitle, book.title.lowercased())
            return similarity > 0.6 ? (book, similarity) : nil
        }
        
        if let bestMatch = matches.max(by: { $0.1 < $1.1 }) {
            setDetectedBook(bestMatch.0, confidence: bestMatch.1)
        }
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        // Simple Jaccard similarity for words
        let words1 = Set(str1.split(separator: " ").map { String($0) })
        let words2 = Set(str2.split(separator: " ").map { String($0) })
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }
    
    // Public method to manually set the book context
    func setCurrentBook(_ book: Book) {
        // Set synchronously for immediate use
        self.detectedBook = book
        self.confidence = 1.0
        #if DEBUG
        print("📖 Book context set immediately: \(book.title)")
        #endif
        
        // Also trigger the async update for UI
        setDetectedBook(book, confidence: 1.0)
    }
    
    private func setDetectedBook(_ book: Book, confidence: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // CRITICAL: Only set if it's a different book to prevent duplicate triggers
            if self.detectedBook?.localId == book.localId {
                #if DEBUG
                print("📖 Book already detected: \(book.title) - skipping duplicate")
                #endif
                return
            }
            
            self.detectedBook = book
            self.confidence = confidence
            
            #if DEBUG
            print("📖 Book detected: \(book.title) (confidence: \(Int(confidence * 100))%)")
            #endif
            
            // Haptic feedback for successful detection
            if confidence > 0.7 {
                SensoryFeedback.light()
            }
        }
    }
    
    // MARK: - Library Management
    
    private func loadLibrary() {
        // Load from LibraryViewModel or SwiftData
        Task { @MainActor in
            let viewModel = LibraryViewModel()
            // ViewModel loads books automatically in init
            self.libraryBooks = viewModel.books
            #if DEBUG
            print("📚 Loaded \(libraryBooks.count) books for detection")
            #endif
        }
    }
    
    func updateLibrary(_ books: [Book]) {
        libraryBooks = books
        #if DEBUG
        print("📚 Updated library with \(books.count) books for detection")
        #endif
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Listen for book mentions from processor
        NotificationCenter.default.publisher(for: .bookMentionDetected)
            .compactMap { $0.userInfo?["text"] as? String }
            .sink { [weak self] text in
                self?.detectBookInText(text)
            }
            .store(in: &cancellables)
    }
}