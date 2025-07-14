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
        
        // Quotes
        if lowercased.starts(with: "quote:") ||
           lowercased.starts(with: "\"") ||
           (lowercased.contains("page ") && lowercased.contains("\"")) {
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