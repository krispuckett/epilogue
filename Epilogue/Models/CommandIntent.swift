import SwiftUI

// MARK: - Command Intent
enum CommandIntent: Equatable {
    case addBook(query: String)
    case createQuote(text: String)
    case createNote(text: String)
    case searchLibrary(query: String)
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
            return "Search"
        case .unknown:
            return "Enter"
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
           isQuoteFormat(input) {
            return .createQuote(text: input)
        }
        
        // Notes
        if lowercased.starts(with: "note:") ||
           lowercased.starts(with: "thought:") ||
           lowercased.starts(with: "idea:") {
            return .createNote(text: input)
        }
        
        // Library search (default for simple text)
        if !containsActionKeywords(lowercased) {
            return .searchLibrary(query: input)
        }
        
        return .unknown
    }
    
    private static func cleanBookQuery(from input: String) -> String {
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
        
        // Try to parse "content" - author format or "content" author format
        // First try with dash separator
        let quoteWithDashPattern = #"^["\u{201C}](.+?)["\u{201D}]\s*[-–—]\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: quoteWithDashPattern, options: []) {
            let range = NSRange(location: 0, length: workingText.utf16.count)
            if let match = regex.firstMatch(in: workingText, options: [], range: range) {
                if let contentRange = Range(match.range(at: 1), in: workingText),
                   let authorRange = Range(match.range(at: 2), in: workingText) {
                    let content = String(workingText[contentRange]).trimmingCharacters(in: .whitespaces)
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
                    let content = String(workingText[contentRange]).trimmingCharacters(in: .whitespaces)
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
        
        // Always suggest searching library
        suggestions.append(CommandSuggestion(
            text: "Search for \"\(input)\" in library",
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