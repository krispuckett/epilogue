import Foundation

class ContextWindowManager {
    
    enum WindowSize {
        case minimal    // 500 tokens (~2000 chars)
        case small      // 1000 tokens (~4000 chars)
        case medium     // 2000 tokens (~8000 chars)
        case large      // 4000 tokens (~16000 chars)
        case maximum    // 8000 tokens (~32000 chars)
        
        var tokenLimit: Int {
            switch self {
            case .minimal: return 500
            case .small: return 1000
            case .medium: return 2000
            case .large: return 4000
            case .maximum: return 8000
            }
        }
        
        var characterLimit: Int {
            tokenLimit * 4 // Rough estimate: 1 token ≈ 4 characters
        }
    }
    
    // MARK: - Context Preparation
    
    func prepareMinimalContext(book: Book) -> String {
        var context = """
        Book: \(book.title)
        Author: \(book.author)
        """
        
        if let genre = book.genre {
            context += "\nGenre: \(genre)"
        }
        
        if let year = book.publicationYear {
            context += "\nPublished: \(year)"
        }
        
        if let description = book.bookDescription {
            let truncated = truncate(description, to: 200)
            context += "\nDescription: \(truncated)"
        }
        
        return context
    }
    
    func prepareModerateContext(book: Book, excerpts: [String]) -> String {
        var context = prepareMinimalContext(book: book)
        
        context += "\n\n--- Relevant Excerpts ---\n"
        
        let windowSize = WindowSize.small
        let remainingChars = windowSize.characterLimit - context.count
        let excerptBudget = remainingChars / max(excerpts.count, 1)
        
        for excerpt in excerpts {
            let truncated = truncate(excerpt, to: excerptBudget)
            context += "\n\(truncated)\n"
            
            if context.count >= windowSize.characterLimit {
                break
            }
        }
        
        return truncate(context, to: windowSize.characterLimit)
    }
    
    func prepareFullContext(book: Book, excerpts: [String]) -> String {
        var context = prepareMinimalContext(book: book)
        
        // Add quotes if available
        if let quotes = book.quotes, !quotes.isEmpty {
            context += "\n\n--- Key Quotes ---\n"
            let relevantQuotes = selectMostRelevant(quotes.compactMap { $0.text }, limit: 5)
            for quote in relevantQuotes {
                context += "• \(truncate(quote, to: 200))\n"
            }
        }
        
        // Add notes if available
        if let notes = book.notes, !notes.isEmpty {
            context += "\n\n--- Notes ---\n"
            let relevantNotes = notes.prefix(3)
            for note in relevantNotes {
                if let title = note.title, let content = note.content {
                    context += "\(title): \(truncate(content, to: 300))\n"
                }
            }
        }
        
        // Add provided excerpts
        if !excerpts.isEmpty {
            context += "\n\n--- Relevant Content ---\n"
            for excerpt in excerpts {
                context += "\(truncate(excerpt, to: 500))\n\n"
            }
        }
        
        let windowSize = WindowSize.large
        return truncate(context, to: windowSize.characterLimit)
    }
    
    // MARK: - Progressive Context Loading
    
    func prepareProgressiveContext(
        book: Book,
        stage: ProgressiveStage,
        previousContext: String? = nil
    ) -> String {
        
        switch stage {
        case .initial:
            // Quick answer with minimal context
            return prepareMinimalContext(book: book)
            
        case .expanded:
            // Add more details
            var context = previousContext ?? prepareMinimalContext(book: book)
            
            if let quotes = book.quotes?.prefix(3) {
                context += "\n\n--- Sample Quotes ---\n"
                for quote in quotes {
                    if let text = quote.text {
                        context += "• \(truncate(text, to: 150))\n"
                    }
                }
            }
            
            return context
            
        case .detailed:
            // Full context with all relevant information
            let relevantExcerpts = extractAllRelevantContent(from: book)
            return prepareFullContext(book: book, excerpts: relevantExcerpts)
        }
    }
    
    enum ProgressiveStage {
        case initial   // Quick response
        case expanded  // More detail
        case detailed  // Complete analysis
    }
    
    // MARK: - Smart Windowing
    
    func optimizeContextWindow(
        query: String,
        book: Book,
        targetTokens: Int
    ) -> String {
        
        // Calculate relevance scores for all content
        var scoredContent: [(content: String, score: Double, type: ContentType)] = []
        
        // Score quotes
        if let quotes = book.quotes {
            for quote in quotes {
                if let text = quote.text {
                    let score = calculateRelevance(text: text, query: query)
                    scoredContent.append((text, score, .quote))
                }
            }
        }
        
        // Score notes
        if let notes = book.notes {
            for note in notes {
                let content = (note.title ?? "") + " " + (note.content ?? "")
                let score = calculateRelevance(text: content, query: query)
                scoredContent.append((content, score, .note))
            }
        }
        
        // Sort by relevance
        scoredContent.sort { $0.score > $1.score }
        
        // Build context within token budget
        var context = prepareMinimalContext(book: book)
        let headerTokens = estimateTokens(for: context)
        var remainingTokens = targetTokens - headerTokens
        
        for (content, score, type) in scoredContent {
            if score < 0.3 { break } // Skip low relevance content
            
            let contentTokens = estimateTokens(for: content)
            if contentTokens <= remainingTokens {
                context += "\n\n[\(type.rawValue) - Relevance: \(Int(score * 100))%]\n"
                context += content
                remainingTokens -= contentTokens
            } else if remainingTokens > 100 {
                // Truncate to fit
                let truncated = truncateToTokens(content, maxTokens: remainingTokens - 50)
                context += "\n\n[\(type.rawValue) - Truncated]\n"
                context += truncated
                break
            }
        }
        
        return context
    }
    
    enum ContentType: String {
        case quote = "Quote"
        case note = "Note"
        case description = "Description"
        case metadata = "Metadata"
    }
    
    // MARK: - Relevance Calculation
    
    private func calculateRelevance(text: String, query: String) -> Double {
        let textLower = text.lowercased()
        let queryLower = query.lowercased()
        
        // Keyword matching
        let queryWords = Set(queryLower.split(separator: " ").map(String.init))
        let textWords = Set(textLower.split(separator: " ").map(String.init))
        
        let intersection = queryWords.intersection(textWords)
        let keywordScore = Double(intersection.count) / Double(queryWords.count)
        
        // Phrase matching
        var phraseScore = 0.0
        if textLower.contains(queryLower) {
            phraseScore = 1.0
        } else {
            // Check for partial phrase matches
            let queryPhrases = extractPhrases(from: queryLower)
            for phrase in queryPhrases {
                if textLower.contains(phrase) {
                    phraseScore = max(phraseScore, 0.5)
                }
            }
        }
        
        // Combine scores
        return (keywordScore * 0.6) + (phraseScore * 0.4)
    }
    
    private func extractPhrases(from text: String) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        guard words.count >= 2 else { return [] }
        
        var phrases: [String] = []
        for i in 0..<(words.count - 1) {
            phrases.append("\(words[i]) \(words[i + 1])")
        }
        
        return phrases
    }
    
    // MARK: - Content Selection
    
    private func selectMostRelevant(_ items: [String], limit: Int) -> [String] {
        // Simple selection - could be enhanced with relevance scoring
        return Array(items.prefix(limit))
    }
    
    private func extractAllRelevantContent(from book: Book) -> [String] {
        var content: [String] = []
        
        if let quotes = book.quotes {
            content.append(contentsOf: quotes.compactMap { $0.text })
        }
        
        if let notes = book.notes {
            content.append(contentsOf: notes.map { ($0.title ?? "") + ": " + ($0.content ?? "") })
        }
        
        return content
    }
    
    // MARK: - Token Estimation
    
    func estimateTokens(for text: String) -> Int {
        // Rough estimation: 1 token ≈ 4 characters
        // More sophisticated: account for whitespace and punctuation
        let words = text.split(separator: " ").count
        let characters = text.count
        
        // Average between word count and character/4 estimate
        return (words + (characters / 4)) / 2
    }
    
    // MARK: - Text Truncation
    
    private func truncate(_ text: String, to maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        
        let endIndex = text.index(text.startIndex, offsetBy: maxChars - 3)
        return String(text[..<endIndex]) + "..."
    }
    
    private func truncateToTokens(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        return truncate(text, to: maxChars)
    }
    
    // MARK: - Context Caching
    
    private var contextCache: [String: (context: String, timestamp: Date)] = [:]
    
    func getCachedContext(for key: String) -> String? {
        guard let cached = contextCache[key] else { return nil }
        
        // Cache expires after 5 minutes
        if Date().timeIntervalSince(cached.timestamp) > 300 {
            contextCache.removeValue(forKey: key)
            return nil
        }
        
        return cached.context
    }
    
    func cacheContext(_ context: String, for key: String) {
        contextCache[key] = (context, Date())
        
        // Clean old entries
        let now = Date()
        contextCache = contextCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) < 300
        }
    }
}