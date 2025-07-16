import SwiftUI

// MARK: - Command Intent
enum CommandIntent: Equatable {
    case addBook(query: String)
    case createQuote(text: String)
    case createNote(text: String)
    case searchLibrary(query: String)
    case searchNotes(query: String)
    case searchAll(query: String)
    case unknown
    
    var icon: String {
        switch self {
        case .addBook:
            return "plus.circle"
        case .createQuote:
            return "quote.opening"
        case .createNote:
            return "note.text"
        case .searchLibrary:
            return "magnifyingglass"
        case .searchNotes:
            return "doc.text.magnifyingglass"
        case .searchAll:
            return "magnifyingglass.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .addBook:
            return .blue
        case .createQuote:
            return .purple
        case .createNote:
            return .green
        case .searchLibrary:
            return .orange
        case .searchNotes:
            return .blue
        case .searchAll:
            return .purple
        case .unknown:
            return .gray
        }
    }
    
    var actionText: String {
        switch self {
        case .addBook:
            return "Add Book"
        case .createQuote:
            return "Save Quote"
        case .createNote:
            return "Save Note"
        case .searchLibrary:
            return "Search Books"
        case .searchNotes:
            return "Search Notes"
        case .searchAll:
            return "Search All"
        case .unknown:
            return "Enter"
        }
    }
    
    var displayName: String {
        switch self {
        case .addBook:
            return "Add Book"
        case .createQuote:
            return "New Quote"
        case .createNote:
            return "New Note"
        case .searchLibrary:
            return "Search Library"
        case .searchNotes:
            return "Search Notes"
        case .searchAll:
            return "Search Everything"
        case .unknown:
            return "Command"
        }
    }
}

// MARK: - Command Parser
struct CommandParser {
    static func parse(_ input: String) -> CommandIntent {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Empty input
        if lowercased.isEmpty {
            return .unknown
        }
        
        // Book additions - be more specific to avoid false positives
        if lowercased.starts(with: "add book") ||
           lowercased.starts(with: "add the ") ||
           (lowercased.starts(with: "add ") && lowercased.count > 4) ||
           lowercased.starts(with: "reading ") ||
           lowercased.starts(with: "finished ") ||
           lowercased.starts(with: "i'm reading ") ||
           lowercased.starts(with: "currently reading ") ||
           (lowercased.contains(" by ") && !lowercased.contains("quote")) {
            
            let query = cleanBookQuery(from: input)
            return .addBook(query: query)
        }
        
        // Quotes - enhanced detection
        if lowercased.starts(with: "quote:") ||
           lowercased.starts(with: "\"") ||
           lowercased.starts(with: "\u{201C}") || // smart quote
           (lowercased.contains("page ") && lowercased.contains("\"")) ||
           isQuoteFormat(input) ||
           hasQuoteAttribution(input) {
            return .createQuote(text: input)
        }
        
        // Notes - enhanced detection
        if lowercased.starts(with: "note:") ||
           lowercased.starts(with: "note -") ||
           lowercased.starts(with: "note ") ||
           lowercased.starts(with: "thought:") ||
           lowercased.starts(with: "idea:") ||
           lowercased.starts(with: "reminder:") ||
           lowercased.starts(with: "todo:") {
            return .createNote(text: input)
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
        
        // Default to search all for simple text
        if !containsActionKeywords(lowercased) {
            return .searchAll(query: input)
        }
        
        return .unknown
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
        
        // Remove "quote:" prefix if present
        var workingText = trimmed
        if workingText.lowercased().hasPrefix("quote:") {
            workingText = String(workingText.dropFirst(6)).trimmingCharacters(in: .whitespaces)
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
                        
                        if parts.count >= 1 {
                            author = parts[0]
                        }
                        if parts.count >= 2 {
                            bookTitle = parts[1]
                        }
                        if parts.count >= 3 {
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
            var attribution = String(workingText[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            
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