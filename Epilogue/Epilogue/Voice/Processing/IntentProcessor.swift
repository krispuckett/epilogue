import Foundation
import NaturalLanguage
import Combine

class IntentProcessor: ObservableObject {
    @Published var detectedIntent: VoiceIntent = .unknown
    @Published var entities: [String: String] = [:]
    @Published var confidence: Double = 0.0
    
    enum VoiceIntent {
        case unknown
        case addBook(title: String?, author: String?)
        case addNote(content: String)
        case addQuote(quote: String, source: String?)
        case searchLibrary(query: String)
        case readingProgress(book: String?, action: ProgressAction)
        case recommendation(genre: String?)
        case help
        
        enum ProgressAction {
            case update(page: Int)
            case check
            case finish
        }
    }
    
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    
    func processTranscription(_ text: String) async -> VoiceIntent {
        let lowercased = text.lowercased()
        entities.removeAll()
        
        // Extract entities
        await extractEntities(from: text)
        
        // Pattern matching for intents
        if let intent = matchAddBookIntent(lowercased) {
            detectedIntent = intent
            confidence = 0.9
        } else if let intent = matchAddNoteIntent(lowercased) {
            detectedIntent = intent
            confidence = 0.85
        } else if let intent = matchAddQuoteIntent(lowercased) {
            detectedIntent = intent
            confidence = 0.85
        } else if let intent = matchSearchIntent(lowercased) {
            detectedIntent = intent
            confidence = 0.8
        } else if let intent = matchProgressIntent(lowercased) {
            detectedIntent = intent
            confidence = 0.8
        } else if let intent = matchRecommendationIntent(lowercased) {
            detectedIntent = intent
            confidence = 0.75
        } else if matchHelpIntent(lowercased) {
            detectedIntent = .help
            confidence = 0.95
        } else {
            detectedIntent = .unknown
            confidence = 0.0
        }
        
        return detectedIntent
    }
    
    private func extractEntities(from text: String) async {
        tagger.string = text
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        let tags = tagger.tags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options)
        
        for (tag, range) in tags {
            if let tag = tag {
                let entity = String(text[range])
                
                switch tag {
                case .personalName:
                    entities["author"] = entity
                case .placeName, .organizationName:
                    entities["source"] = entity
                default:
                    break
                }
            }
        }
        
        // Extract numbers for page numbers
        let numberRegex = try? NSRegularExpression(pattern: "\\b\\d+\\b", options: [])
        if let matches = numberRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let number = String(text[range])
                    entities["number"] = number
                }
            }
        }
    }
    
    private func matchAddBookIntent(_ text: String) -> VoiceIntent? {
        let patterns = [
            "add (.+) by (.+) to my library",
            "add the book (.+) by (.+)",
            "add (.+) to my library",
            "i want to read (.+)",
            "i'm reading (.+)",
            "add book (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                
                var title: String?
                var author: String?
                
                if match.numberOfRanges > 1,
                   let titleRange = Range(match.range(at: 1), in: text) {
                    title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                }
                
                if match.numberOfRanges > 2,
                   let authorRange = Range(match.range(at: 2), in: text) {
                    author = String(text[authorRange]).trimmingCharacters(in: .whitespaces)
                }
                
                return .addBook(title: title, author: author ?? entities["author"])
            }
        }
        
        return nil
    }
    
    private func matchAddNoteIntent(_ text: String) -> VoiceIntent? {
        let patterns = [
            "note that (.+)",
            "make a note (.+)",
            "remember that (.+)",
            "note to self (.+)",
            "add note (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                
                if match.numberOfRanges > 1,
                   let contentRange = Range(match.range(at: 1), in: text) {
                    let content = String(text[contentRange]).trimmingCharacters(in: .whitespaces)
                    return .addNote(content: content)
                }
            }
        }
        
        return nil
    }
    
    private func matchAddQuoteIntent(_ text: String) -> VoiceIntent? {
        let patterns = [
            "quote (.+) from (.+)",
            "add quote (.+) by (.+)",
            "save quote (.+)",
            "remember this quote (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                
                var quote: String?
                var source: String?
                
                if match.numberOfRanges > 1,
                   let quoteRange = Range(match.range(at: 1), in: text) {
                    quote = String(text[quoteRange]).trimmingCharacters(in: .whitespaces)
                }
                
                if match.numberOfRanges > 2,
                   let sourceRange = Range(match.range(at: 2), in: text) {
                    source = String(text[sourceRange]).trimmingCharacters(in: .whitespaces)
                }
                
                if let quote = quote {
                    return .addQuote(quote: quote, source: source ?? entities["source"])
                }
            }
        }
        
        return nil
    }
    
    private func matchSearchIntent(_ text: String) -> VoiceIntent? {
        let patterns = [
            "search for (.+) in my library",
            "find (.+) in my books",
            "do i have (.+)",
            "show me (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                
                if match.numberOfRanges > 1,
                   let queryRange = Range(match.range(at: 1), in: text) {
                    let query = String(text[queryRange]).trimmingCharacters(in: .whitespaces)
                    return .searchLibrary(query: query)
                }
            }
        }
        
        return nil
    }
    
    private func matchProgressIntent(_ text: String) -> VoiceIntent? {
        // Update progress
        if text.contains("page") || text.contains("chapter") {
            if let pageNumber = entities["number"],
               let page = Int(pageNumber) {
                let bookTitle = extractBookTitle(from: text)
                return .readingProgress(book: bookTitle, action: .update(page: page))
            }
        }
        
        // Check progress
        if text.contains("how far") || text.contains("progress") || text.contains("what page") {
            let bookTitle = extractBookTitle(from: text)
            return .readingProgress(book: bookTitle, action: .check)
        }
        
        // Finish book
        if text.contains("finished") || text.contains("done with") || text.contains("completed") {
            let bookTitle = extractBookTitle(from: text)
            return .readingProgress(book: bookTitle, action: .finish)
        }
        
        return nil
    }
    
    private func matchRecommendationIntent(_ text: String) -> VoiceIntent? {
        let patterns = [
            "recommend.*book",
            "what should i read",
            "suggest.*book",
            "recommendation"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil {
                
                // Extract genre if mentioned
                let genres = ["fiction", "non-fiction", "fantasy", "mystery", "romance", "thriller", "biography", "history", "science"]
                var detectedGenre: String?
                
                for genre in genres {
                    if text.contains(genre) {
                        detectedGenre = genre
                        break
                    }
                }
                
                return .recommendation(genre: detectedGenre)
            }
        }
        
        return nil
    }
    
    private func matchHelpIntent(_ text: String) -> Bool {
        let helpKeywords = ["help", "what can you do", "commands", "how do i", "tutorial"]
        return helpKeywords.contains { text.contains($0) }
    }
    
    private func extractBookTitle(from text: String) -> String? {
        // Try to extract book title from context
        let bookIndicators = ["book", "novel", "reading"]
        
        for indicator in bookIndicators {
            if let range = text.range(of: indicator) {
                let afterIndicator = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let words = afterIndicator.split(separator: " ")
                
                // Take up to 5 words as potential title
                let titleWords = words.prefix(5).joined(separator: " ")
                if !titleWords.isEmpty {
                    return titleWords
                }
            }
        }
        
        return nil
    }
}