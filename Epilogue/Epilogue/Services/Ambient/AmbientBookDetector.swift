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
        print("📚 Book detection started")
    }
    
    func stopDetection() {
        isDetecting = false
        print("📚 Book detection stopped")
    }
    
    // MARK: - Natural Language Processing
    
    func detectBookInText(_ text: String) {
        guard isDetecting else { 
            print("📚 Book detection not active")
            return 
        }
        
        print("📚 Detecting book in text: \(text)")
        let lowercased = text.lowercased()
        
        // Check for trigger phrases
        let containsTrigger = bookTriggerPhrases.contains { lowercased.contains($0) }
        
        if containsTrigger {
            // Extract potential book title
            if let bookTitle = extractBookTitle(from: text) {
                findBookInLibrary(title: bookTitle)
            }
            
            // Also check against known books
            checkAgainstKnownBooks(text)
        }
    }
    
    private func extractBookTitle(from text: String) -> String? {
        let lowercased = text.lowercased()
        
        // Pattern: "reading [book title]"
        if let range = lowercased.range(of: "reading ") {
            let afterReading = String(text[range.upperBound...])
            
            // Extract until common delimiters
            let delimiters = CharacterSet(charactersIn: ",.!?;:")
            if let endIndex = afterReading.rangeOfCharacter(from: delimiters) {
                return String(afterReading[..<endIndex.lowerBound]).trimmingCharacters(in: .whitespaces)
            } else {
                // Take first few words
                let words = afterReading.split(separator: " ").prefix(5)
                return words.joined(separator: " ")
            }
        }
        
        // Pattern: quotes around title
        let quotePatterns = ["\"", "\u{201C}", "'"]
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
        print("📚 Checking against \(libraryBooks.count) known books")
        
        for book in libraryBooks {
            // Check title match
            let titleLower = book.title.lowercased()
            if lowercased.contains(titleLower) {
                print("📚 Found exact match: \(book.title)")
                setDetectedBook(book, confidence: 0.9)
                return
            }
            
            // Check partial title match (at least 3 words)
            let titleWords = titleLower.split(separator: " ")
            if titleWords.count >= 3 {
                let matchingWords = titleWords.filter { lowercased.contains($0) }
                if Double(matchingWords.count) / Double(titleWords.count) > 0.6 {
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
    
    private func setDetectedBook(_ book: Book, confidence: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.detectedBook = book
            self?.confidence = confidence
            
            print("📖 Book detected: \(book.title) (confidence: \(Int(confidence * 100))%)")
            
            // Haptic feedback for successful detection
            if confidence > 0.7 {
                HapticManager.shared.lightTap()
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
            print("📚 Loaded \(libraryBooks.count) books for detection")
        }
    }
    
    func updateLibrary(_ books: [Book]) {
        libraryBooks = books
        print("📚 Updated library with \(books.count) books for detection")
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