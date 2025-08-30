import Foundation
import SwiftUI
import Combine

// MARK: - Book Mention Detection
struct BookMention: Identifiable {
    let id = UUID()
    let text: String
    let book: Book
    let range: NSRange
}

class BookMentionParser: ObservableObject {
    @Published var detectedMentions: [BookMention] = []
    @Published var suggestions: [Book] = []
    
    // MARK: - Real-time Detection
    static func detectMentions(in text: String, books: [Book]) -> [BookMention] {
        var mentions: [BookMention] = []
        let pattern = #"@(\w+(?:\s+\w+)*)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return mentions
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let mentionText = String(text[range])
            
            // Find best matching book using fuzzy search
            if let book = findBestMatch(mentionText, in: books) {
                mentions.append(BookMention(
                    text: mentionText,
                    book: book,
                    range: match.range
                ))
            }
        }
        
        return mentions
    }
    
    // MARK: - Fuzzy Matching
    static func findBestMatch(_ query: String, in books: [Book]) -> Book? {
        let lowercasedQuery = query.lowercased()
        
        // First try exact match
        if let exactMatch = books.first(where: { 
            $0.title.lowercased() == lowercasedQuery ||
            $0.title.lowercased().replacingOccurrences(of: "the ", with: "") == lowercasedQuery
        }) {
            return exactMatch
        }
        
        // Then try prefix match
        if let prefixMatch = books.first(where: {
            $0.title.lowercased().hasPrefix(lowercasedQuery)
        }) {
            return prefixMatch
        }
        
        // Finally, use fuzzy matching with scoring
        let matches = books.compactMap { book -> (Book, Double)? in
            let score = fuzzyScore(query: lowercasedQuery, target: book.title.lowercased())
            return score > 0.6 ? (book, score) : nil
        }
        
        return matches.max(by: { $0.1 < $1.1 })?.0
    }
    
    // MARK: - Fuzzy Scoring Algorithm
    private static func fuzzyScore(query: String, target: String) -> Double {
        // Handle common abbreviations
        let abbreviations: [String: [String]] = [
            "lotr": ["lord of the rings", "fellowship", "two towers", "return of the king"],
            "hp": ["harry potter"],
            "got": ["game of thrones"],
            "asoiaf": ["a song of ice and fire"]
        ]
        
        // Check abbreviations first
        if let expansions = abbreviations[query] {
            for expansion in expansions {
                if target.contains(expansion) {
                    return 1.0
                }
            }
        }
        
        // Calculate word-based similarity
        let queryWords = Set(query.split(separator: " ").map(String.init))
        let targetWords = Set(target.split(separator: " ").map(String.init))
        
        let intersection = queryWords.intersection(targetWords)
        let union = queryWords.union(targetWords)
        
        if union.isEmpty { return 0 }
        
        // Jaccard similarity with boost for matching all query words
        let baseScore = Double(intersection.count) / Double(union.count)
        let allQueryWordsFound = queryWords.isSubset(of: targetWords)
        
        return allQueryWordsFound ? min(1.0, baseScore * 1.5) : baseScore
    }
    
    // MARK: - Live Suggestions
    static func getSuggestions(for partialMention: String, books: [Book], limit: Int = 5) -> [Book] {
        guard !partialMention.isEmpty else { return [] }
        
        let lowercased = partialMention.lowercased()
        
        // Score and sort all books
        let scored = books.compactMap { book -> (Book, Double)? in
            var score = 0.0
            let title = book.title.lowercased()
            
            // Exact prefix gets highest score
            if title.hasPrefix(lowercased) {
                score = 1.0
            }
            // Word prefix match
            else if title.split(separator: " ").contains(where: { $0.hasPrefix(lowercased) }) {
                score = 0.8
            }
            // Contains match
            else if title.contains(lowercased) {
                score = 0.6
            }
            // Fuzzy match
            else {
                score = fuzzyScore(query: lowercased, target: title)
            }
            
            return score > 0.3 ? (book, score) : nil
        }
        
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
    
    // MARK: - Text Processing
    static func replaceMention(in text: String, mention: BookMention, with bookTitle: String) -> String {
        guard let range = Range(mention.range, in: text) else { return text }
        var newText = text
        newText.replaceSubrange(range, with: "@\(bookTitle)")
        return newText
    }
    
    // MARK: - Extract Book Context
    static func extractBookContext(from text: String, books: [Book]) -> (String, Book?) {
        let mentions = detectMentions(in: text, books: books)
        
        guard let firstMention = mentions.first else {
            return (text, nil)
        }
        
        // Remove the @mention from the text
        let cleanText = text.replacingOccurrences(
            of: "@\(firstMention.text)",
            with: "",
            options: .caseInsensitive
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (cleanText, firstMention.book)
    }
}

// MARK: - SwiftUI View for Mention Suggestions
struct BookMentionSuggestionsView: View {
    let suggestions: [Book]
    let onSelect: (Book) -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(suggestions, id: \.localId) { book in
                Button {
                    onSelect(book)
                } label: {
                    HStack {
                        // Book cover or placeholder
                        if let coverURL = book.coverImageURL, let url = URL(string: coverURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                            }
                            .frame(width: 30, height: 45)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                                .frame(width: 30, height: 45)
                                .overlay(
                                    Text(String(book.title.prefix(1)))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(DesignSystem.Colors.primaryAccent)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(book.author)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}