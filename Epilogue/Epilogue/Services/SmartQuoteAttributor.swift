import Foundation
import SwiftUI

// MARK: - Smart Quote Attributor

class SmartQuoteAttributor {
    static let shared = SmartQuoteAttributor()
    
    // MARK: - Common Author Aliases
    private let authorAliases: [String: String] = [
        // Classical Philosophy
        "seneca": "Lucius Annaeus Seneca",
        "marcus aurelius": "Marcus Aurelius",
        "aurelius": "Marcus Aurelius",
        "epictetus": "Epictetus",
        "plato": "Plato",
        "aristotle": "Aristotle",
        "socrates": "Socrates",
        
        // Modern Philosophy
        "nietzsche": "Friedrich Nietzsche",
        "kant": "Immanuel Kant",
        "hegel": "Georg Wilhelm Friedrich Hegel",
        "sartre": "Jean-Paul Sartre",
        "camus": "Albert Camus",
        "de beauvoir": "Simone de Beauvoir",
        "simone": "Simone de Beauvoir",
        
        // Literature
        "shakespeare": "William Shakespeare",
        "orwell": "George Orwell",
        "huxley": "Aldous Huxley",
        "wilde": "Oscar Wilde",
        "twain": "Mark Twain",
        "hemingway": "Ernest Hemingway",
        "fitzgerald": "F. Scott Fitzgerald",
        "tolkien": "J.R.R. Tolkien",
        "jrr tolkien": "J.R.R. Tolkien",
        "cs lewis": "C.S. Lewis",
        "lewis": "C.S. Lewis",
        
        // Historical Figures
        "mlk": "Martin Luther King Jr.",
        "martin luther king": "Martin Luther King Jr.",
        "gandhi": "Mahatma Gandhi",
        "churchill": "Winston Churchill",
        "lincoln": "Abraham Lincoln",
        "jefferson": "Thomas Jefferson",
        "franklin": "Benjamin Franklin",
        "einstein": "Albert Einstein",
        
        // Modern Authors
        "king": "Stephen King",
        "rowling": "J.K. Rowling",
        "jk rowling": "J.K. Rowling",
        "sanderson": "Brandon Sanderson",
        "martin": "George R.R. Martin",
        "grrm": "George R.R. Martin",
        "gaiman": "Neil Gaiman",
        
        // Business/Self-Help
        "carnegie": "Dale Carnegie",
        "covey": "Stephen Covey",
        "gladwell": "Malcolm Gladwell",
        "godin": "Seth Godin",
        "holiday": "Ryan Holiday",
        "clear": "James Clear",
        "newport": "Cal Newport"
    ]
    
    // MARK: - Page Context Patterns
    private let pageContextPatterns: [(pattern: String, calculator: (Int) -> PageRange)] = [
        ("near the beginning", { currentPage in PageRange(start: 1, end: min(50, currentPage)) }),
        ("at the beginning", { currentPage in PageRange(start: 1, end: 20) }),
        ("near the end", { totalPages in PageRange(start: max(1, totalPages - 50), end: totalPages) }),
        ("at the end", { totalPages in PageRange(start: max(1, totalPages - 20), end: totalPages) }),
        ("a few pages back", { currentPage in PageRange(start: max(1, currentPage - 10), end: currentPage - 1) }),
        ("previous page", { currentPage in PageRange(start: currentPage - 1, end: currentPage - 1) }),
        ("last page", { currentPage in PageRange(start: currentPage - 1, end: currentPage - 1) }),
        ("few pages ago", { currentPage in PageRange(start: max(1, currentPage - 15), end: currentPage - 2) }),
        ("earlier", { currentPage in PageRange(start: max(1, currentPage - 30), end: currentPage - 5) }),
        ("much earlier", { currentPage in PageRange(start: 1, end: max(1, currentPage - 30)) }),
        ("halfway through", { totalPages in PageRange(start: totalPages / 2 - 10, end: totalPages / 2 + 10) }),
        ("middle of the book", { totalPages in PageRange(start: totalPages / 2 - 20, end: totalPages / 2 + 20) })
    ]
    
    private init() {}
    
    // MARK: - Main Attribution Method
    
    func attributeQuote(
        text: String,
        rawAttribution: String? = nil,
        currentBook: Book? = nil,
        currentPage: Int? = nil
    ) -> AttributedQuote {
        
        var author: String? = nil
        var bookTitle: String? = nil
        var pageInfo: PageInfo? = nil
        var confidence: AttributionConfidence = .low
        var style: QuoteStyle = .unknown
        var context: String? = nil
        
        // Parse raw attribution if provided
        if let raw = rawAttribution {
            let parsed = parseAttribution(raw, currentBook: currentBook, currentPage: currentPage)
            author = parsed.author
            bookTitle = parsed.book
            pageInfo = parsed.pageInfo
        }
        
        // Fuzzy match author
        if let authorName = author {
            author = matchAuthor(authorName, currentBook: currentBook)
        } else if currentBook != nil {
            // Default to current book's author if no author specified
            author = currentBook?.author
        }
        
        // Detect quote style and add context
        let styleAnalysis = analyzeQuoteStyle(text)
        style = styleAnalysis.style
        context = styleAnalysis.context
        
        // Calculate confidence score
        confidence = calculateConfidence(
            hasAuthor: author != nil,
            hasBook: bookTitle != nil || currentBook != nil,
            hasPage: pageInfo != nil,
            styleDetected: style != .unknown
        )
        
        return AttributedQuote(
            text: text,
            author: author,
            bookTitle: bookTitle ?? currentBook?.title,
            pageInfo: pageInfo,
            confidence: confidence,
            style: style,
            context: context,
            timestamp: Date()
        )
    }
    
    // MARK: - Author Matching
    
    private func matchAuthor(_ input: String, currentBook: Book?) -> String {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check exact alias match
        if let fullName = authorAliases[lowercased] {
            return fullName
        }
        
        // Check if it's just a last name that matches current book's author
        if let bookAuthor = currentBook?.author {
            let authorParts = bookAuthor.split(separator: " ")
            if let lastName = authorParts.last,
               lowercased == lastName.lowercased() {
                return bookAuthor
            }
        }
        
        // Check partial matches in aliases
        for (alias, fullName) in authorAliases {
            if alias.contains(lowercased) || lowercased.contains(alias) {
                return fullName
            }
        }
        
        // Return original if no match found
        return input
    }
    
    // MARK: - Attribution Parsing
    
    private func parseAttribution(
        _ attribution: String,
        currentBook: Book?,
        currentPage: Int?
    ) -> (author: String?, book: String?, pageInfo: PageInfo?) {
        
        // Handle special separator format from CommandParser
        if attribution.contains("|||") {
            return parseSpecialFormat(attribution)
        }
        
        // Parse comma-separated format
        let parts = attribution.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        var author: String? = nil
        var book: String? = nil
        var pageInfo: PageInfo? = nil
        
        if parts.count >= 1 {
            author = parts[0]
        }
        
        if parts.count >= 2 {
            book = parts[1]
        }
        
        if parts.count >= 3 {
            let pageString = parts[2]
            pageInfo = parsePageInfo(pageString, currentBook: currentBook, currentPage: currentPage)
        }
        
        return (author, book, pageInfo)
    }
    
    private func parseSpecialFormat(_ attribution: String) -> (author: String?, book: String?, pageInfo: PageInfo?) {
        let parts = attribution.split(separator: "|||")
        
        var author: String? = nil
        var book: String? = nil
        var pageInfo: PageInfo? = nil
        
        for i in 0..<parts.count {
            let part = String(parts[i])
            
            if i == 0 {
                author = part
            } else if part == "BOOK" && i + 1 < parts.count {
                book = String(parts[i + 1])
            } else if part == "PAGE" && i + 1 < parts.count {
                let pageString = String(parts[i + 1])
                if let pageNum = Int(pageString.filter { $0.isNumber }) {
                    pageInfo = .exact(pageNum)
                }
            }
        }
        
        return (author, book, pageInfo)
    }
    
    // MARK: - Page Context Intelligence
    
    private func parsePageInfo(
        _ input: String,
        currentBook: Book?,
        currentPage: Int?
    ) -> PageInfo? {
        
        let lowercased = input.lowercased()
        
        // Check for exact page number
        if let pageNum = extractPageNumber(from: lowercased) {
            return .exact(pageNum)
        }
        
        // Check for chapter reference
        if let chapterNum = extractChapterNumber(from: lowercased),
           let pageNum = convertChapterToPage(chapterNum, book: currentBook) {
            return .chapter(chapterNum, estimatedPage: pageNum)
        }
        
        // Check for contextual references
        for (pattern, calculator) in pageContextPatterns {
            if lowercased.contains(pattern) {
                let reference = currentPage ?? currentBook?.currentPage ?? 1
                let totalPages = currentBook?.pageCount ?? reference
                let range = calculator(pattern.contains("end") ? totalPages : reference)
                return .range(range)
            }
        }
        
        // Check for percentage
        if let percentage = extractPercentage(from: lowercased),
           let totalPages = currentBook?.pageCount {
            let page = Int(Double(totalPages) * (percentage / 100.0))
            return .percentage(percentage, estimatedPage: page)
        }
        
        return nil
    }
    
    private func extractPageNumber(from text: String) -> Int? {
        let patterns = ["page\\s+(\\d+)", "p\\.\\s*(\\d+)", "pg\\s+(\\d+)"]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return Int(text[range])
            }
        }
        
        // Check for standalone number
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 && $0 < 10000 } // Reasonable page range
        
        return numbers.first
    }
    
    private func extractChapterNumber(from text: String) -> Int? {
        let patterns = ["chapter\\s+(\\d+)", "ch\\.?\\s*(\\d+)"]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return Int(text[range])
            }
        }
        
        return nil
    }
    
    private func extractPercentage(from text: String) -> Double? {
        let pattern = "(\\d+)\\s*%"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text),
           let percentage = Double(text[range]) {
            return percentage
        }
        return nil
    }
    
    private func convertChapterToPage(_ chapter: Int, book: Book?) -> Int? {
        // Simple estimation: assume ~20 pages per chapter
        // In a real implementation, this could use book metadata
        return chapter * 20
    }
    
    // MARK: - Quote Style Analysis
    
    private func analyzeQuoteStyle(_ text: String) -> (style: QuoteStyle, context: String?) {
        let lowercased = text.lowercased()
        
        // Philosophical indicators
        if containsPhilosophicalTerms(lowercased) {
            return (.philosophical, "Explores themes of existence, morality, or human nature")
        }
        
        // Poetic indicators
        if isLikelyPoetic(text) {
            return (.poetic, "Uses metaphorical language and rhythmic structure")
        }
        
        // Dialogue indicators
        if isLikelyDialogue(text) {
            return (.dialogue, "Character conversation or speech")
        }
        
        // Inspirational indicators
        if containsInspirationalTerms(lowercased) {
            return (.inspirational, "Motivational or uplifting message")
        }
        
        // Historical indicators
        if containsHistoricalMarkers(lowercased) {
            return (.historical, "Historical context or reference")
        }
        
        // Scientific indicators
        if containsScientificTerms(lowercased) {
            return (.scientific, "Scientific or technical content")
        }
        
        // Literary by default if well-structured
        if text.count > 50 && (text.contains(",") || text.contains(";")) {
            return (.literary, "Literary prose with complex structure")
        }
        
        return (.unknown, nil)
    }
    
    private func containsPhilosophicalTerms(_ text: String) -> Bool {
        let terms = ["virtue", "wisdom", "truth", "existence", "consciousness", "morality",
                     "ethics", "justice", "freedom", "soul", "mind", "reality", "purpose",
                     "meaning", "destiny", "fate", "good", "evil", "nature of", "essence"]
        return terms.contains { text.contains($0) }
    }
    
    private func containsInspirationalTerms(_ text: String) -> Bool {
        let terms = ["dream", "believe", "achieve", "success", "courage", "strength",
                     "persevere", "overcome", "possible", "impossible", "greatness",
                     "potential", "inspire", "motivation", "determination"]
        return terms.contains { text.contains($0) }
    }
    
    private func containsHistoricalMarkers(_ text: String) -> Bool {
        let markers = ["century", "war", "revolution", "empire", "kingdom", "era",
                       "historical", "ancient", "medieval", "renaissance", "modern"]
        return markers.contains { text.contains($0) }
    }
    
    private func containsScientificTerms(_ text: String) -> Bool {
        let terms = ["hypothesis", "theory", "experiment", "evidence", "data",
                     "observation", "phenomenon", "equation", "formula", "principle"]
        return terms.contains { text.contains($0) }
    }
    
    private func isLikelyPoetic(_ text: String) -> Bool {
        // Check for poetic devices
        let hasRepetition = detectRepetition(in: text)
        let hasRhythm = text.components(separatedBy: ",").count >= 3
        let hasMetaphor = text.contains(" like ") || text.contains(" as ")
        
        return hasRepetition || (hasRhythm && hasMetaphor)
    }
    
    private func isLikelyDialogue(_ text: String) -> Bool {
        // Check for dialogue markers
        return text.hasPrefix("\"") && text.hasSuffix("\"") ||
               text.contains(" said") || text.contains(" asked") ||
               text.contains(" replied") || text.contains(" exclaimed")
    }
    
    private func detectRepetition(in text: String) -> Bool {
        let words = text.split(separator: " ").map { $0.lowercased() }
        let wordCounts = Dictionary(words.map { ($0, 1) }, uniquingKeysWith: +)
        return wordCounts.values.contains { $0 >= 3 }
    }
    
    // MARK: - Confidence Calculation
    
    private func calculateConfidence(
        hasAuthor: Bool,
        hasBook: Bool,
        hasPage: Bool,
        styleDetected: Bool
    ) -> AttributionConfidence {
        
        let score = [hasAuthor, hasBook, hasPage, styleDetected]
            .filter { $0 }
            .count
        
        switch score {
        case 4:
            return .veryHigh
        case 3:
            return .high
        case 2:
            return .medium
        default:
            return .low
        }
    }
}

// MARK: - Supporting Types

struct AttributedQuote {
    let text: String
    let author: String?
    let bookTitle: String?
    let pageInfo: PageInfo?
    let confidence: AttributionConfidence
    let style: QuoteStyle
    let context: String?
    let timestamp: Date
    
    var formattedAttribution: String {
        var parts: [String] = []
        
        if let author = author {
            parts.append(author)
        }
        
        if let book = bookTitle {
            parts.append("*\(book)*")
        }
        
        if let page = pageInfo {
            parts.append(page.description)
        }
        
        return parts.isEmpty ? "" : parts.joined(separator: ", ")
    }
}

enum PageInfo: CustomStringConvertible {
    case exact(Int)
    case range(PageRange)
    case chapter(Int, estimatedPage: Int)
    case percentage(Double, estimatedPage: Int)
    
    var description: String {
        switch self {
        case .exact(let page):
            return "p. \(page)"
        case .range(let range):
            return "pp. \(range.start)-\(range.end)"
        case .chapter(let ch, let page):
            return "Ch. \(ch) (~p. \(page))"
        case .percentage(let pct, let page):
            return "\(Int(pct))% (~p. \(page))"
        }
    }
}

struct PageRange {
    let start: Int
    let end: Int
}

enum AttributionConfidence: String {
    case veryHigh = "Very High"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: Color {
        switch self {
        case .veryHigh:
            return .green
        case .high:
            return .blue
        case .medium:
            return .orange
        case .low:
            return .gray
        }
    }
    
    var opacity: Double {
        switch self {
        case .veryHigh:
            return 1.0
        case .high:
            return 0.85
        case .medium:
            return 0.7
        case .low:
            return 0.5
        }
    }
}

enum QuoteStyle {
    case philosophical
    case literary
    case poetic
    case dialogue
    case inspirational
    case historical
    case scientific
    case unknown
    
    var icon: String {
        switch self {
        case .philosophical:
            return "brain"
        case .literary:
            return "book"
        case .poetic:
            return "text.quote"
        case .dialogue:
            return "bubble.left.and.bubble.right"
        case .inspirational:
            return "star"
        case .historical:
            return "clock"
        case .scientific:
            return "atom"
        case .unknown:
            return "quote.opening"
        }
    }
    
    var description: String {
        switch self {
        case .philosophical:
            return "Philosophical"
        case .literary:
            return "Literary"
        case .poetic:
            return "Poetic"
        case .dialogue:
            return "Dialogue"
        case .inspirational:
            return "Inspirational"
        case .historical:
            return "Historical"
        case .scientific:
            return "Scientific"
        case .unknown:
            return "Quote"
        }
    }
}