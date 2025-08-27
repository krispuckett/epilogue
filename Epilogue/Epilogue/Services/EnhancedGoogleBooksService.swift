import Foundation

// Enhanced Google Books Service with smart ranking and filtering
class EnhancedGoogleBooksService: GoogleBooksService {
    
    struct ScoredBook {
        let book: Book
        let googleItem: GoogleBookItem
        let confidenceScore: Double
        let hasCover: Bool
        let hasISBN: Bool
        let ratingsCount: Int
        let averageRating: Double
    }
    
    // Override the search to add smart filtering and ranking
    func searchBooksWithRanking(query: String, preferISBN: String? = nil) async -> [Book] {
        // First do the regular search
        await searchBooks(query: query)
        
        // If we have no results, try alternative searches
        if searchResults.isEmpty && preferISBN != nil {
            // Try ISBN search directly
            if let book = await searchBookByISBN(preferISBN!) {
                return [book]
            }
        }
        
        // Get the raw Google Books results for scoring
        let rawResults = await getRawSearchResults(query: query, maxResults: 40)
        
        // Score and rank the results
        let scoredResults = rankBooks(
            rawResults,
            originalQuery: query,
            preferredISBN: preferISBN
        )
        
        // Return top results, prioritizing books with covers
        return scoredResults
            .sorted { $0.confidenceScore > $1.confidenceScore }
            .prefix(20)
            .map { $0.book }
    }
    
    private func getRawSearchResults(query: String, maxResults: Int = 40) async -> [GoogleBookItem] {
        var allItems: [GoogleBookItem] = []
        
        // Try multiple search strategies in parallel
        await withTaskGroup(of: [GoogleBookItem]?.self) { group in
            // Strategy 1: Regular search
            group.addTask {
                return await self.performRawSearch(query: query, maxResults: maxResults)
            }
            
            // Strategy 2: If it looks like title + author, search each separately
            if query.contains(" by ") || query.split(separator: " ").count > 2 {
                let words = query.split(separator: " ")
                if words.count > 1 {
                    // Search by likely title (first few words)
                    let titleQuery = words.prefix(min(3, words.count - 1)).joined(separator: " ")
                    group.addTask {
                        return await self.performRawSearch(
                            query: "intitle:\(titleQuery)",
                            maxResults: 10
                        )
                    }
                }
            }
            
            // Strategy 3: Search with orderBy relevance
            group.addTask {
                return await self.performRawSearch(
                    query: query,
                    maxResults: 10,
                    orderBy: "relevance"
                )
            }
            
            // Strategy 4: Search with orderBy newest (sometimes gets better editions)
            group.addTask {
                return await self.performRawSearch(
                    query: query,
                    maxResults: 10,
                    orderBy: "newest"
                )
            }
            
            // Collect all results
            for await items in group {
                if let items = items {
                    allItems.append(contentsOf: items)
                }
            }
        }
        
        // Remove duplicates by ID
        var seen = Set<String>()
        return allItems.filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }
    }
    
    private func performRawSearch(
        query: String,
        maxResults: Int,
        orderBy: String = "relevance"
    ) async -> [GoogleBookItem]? {
        let apiBaseURL = "https://www.googleapis.com/books/v1/volumes"
        guard var components = URLComponents(string: apiBaseURL) else { return nil }
        
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "orderBy", value: orderBy),
            URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "langRestrict", value: "en")
        ]
        
        guard let url = components.url else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
            return response.items ?? []
        } catch {
            print("Search error: \(error)")
            return nil
        }
    }
    
    private func rankBooks(
        _ items: [GoogleBookItem],
        originalQuery: String,
        preferredISBN: String?
    ) -> [ScoredBook] {
        let queryWords = originalQuery.lowercased().split(separator: " ")
        
        return items.compactMap { item in
            var score = 0.0
            let volumeInfo = item.volumeInfo
            let book = item.book
            
            // Check for cover
            let hasCover = book.coverImageURL != nil && !book.coverImageURL!.isEmpty
            if hasCover {
                score += 30 // Significant boost for having a cover
            }
            
            // Check for ISBN
            let hasISBN = book.isbn != nil
            if hasISBN {
                score += 10
                
                // Exact ISBN match gets huge boost
                if let preferredISBN = preferredISBN,
                   book.isbn == preferredISBN {
                    score += 100
                }
            }
            
            // Title match scoring
            let titleLower = volumeInfo.title.lowercased()
            for word in queryWords {
                if titleLower.contains(word) {
                    score += 5
                }
            }
            
            // Exact title match
            if titleLower == originalQuery.lowercased() {
                score += 50
            }
            
            // Author match (if provided)
            if let authors = volumeInfo.authors {
                let authorString = authors.joined(separator: " ").lowercased()
                for word in queryWords {
                    if authorString.contains(word) {
                        score += 3
                    }
                }
            }
            
            // Popularity metrics
            let ratingsCount = volumeInfo.ratingsCount ?? 0
            let averageRating = volumeInfo.averageRating ?? 0
            
            // Logarithmic scale for ratings count (popular books score higher)
            if ratingsCount > 0 {
                score += min(20, log10(Double(ratingsCount)) * 5)
            }
            
            // High average rating bonus
            if averageRating >= 4.0 {
                score += 10
            }
            
            // Page count (filter out previews/samples)
            if let pageCount = volumeInfo.pageCount {
                if pageCount < 50 {
                    score -= 20 // Likely a preview or sample
                } else {
                    score += 5
                }
            }
            
            // Published date (prefer books with dates)
            if volumeInfo.publishedDate != nil {
                score += 5
            }
            
            // Description exists
            if volumeInfo.description != nil && !volumeInfo.description!.isEmpty {
                score += 5
            }
            
            // Publisher quality (major publishers score higher)
            if let publisher = volumeInfo.publisher?.lowercased() {
                let majorPublishers = [
                    "penguin", "random house", "harpercollins", "simon",
                    "macmillan", "hachette", "scholastic", "vintage",
                    "knopf", "doubleday", "bantam", "tor", "ace"
                ]
                
                if majorPublishers.contains(where: { publisher.contains($0) }) {
                    score += 10
                }
            }
            
            // Penalize if title contains unwanted terms
            let unwantedTerms = [
                "summary", "notes", "study guide", "spark",
                "cliff", "analysis", "workbook", "teacher"
            ]
            
            for term in unwantedTerms {
                if titleLower.contains(term) {
                    score -= 30
                }
            }
            
            // Check for language (prefer English)
            if volumeInfo.language != "en" {
                score -= 10
            }
            
            return ScoredBook(
                book: book,
                googleItem: item,
                confidenceScore: score,
                hasCover: hasCover,
                hasISBN: hasISBN,
                ratingsCount: ratingsCount,
                averageRating: averageRating
            )
        }
    }
    
    // Special method for import that tries multiple strategies
    func findBestMatch(
        title: String,
        author: String,
        isbn: String? = nil,
        publishedYear: String? = nil
    ) async -> Book? {
        // Try ISBN first if available
        if let isbn = isbn, !isbn.isEmpty {
            if let book = await searchBookByISBN(isbn) {
                // Verify it's the right book
                if book.title.lowercased().contains(title.lowercased().prefix(10)) {
                    return book
                }
            }
        }
        
        // Try multiple search strategies
        var candidates: [Book] = []
        
        // Strategy 1: Title and author
        candidates.append(contentsOf: await searchBooksWithRanking(
            query: "intitle:\"\(title)\" inauthor:\"\(author)\"",
            preferISBN: isbn
        ))
        
        // Strategy 2: Just title (sometimes author names don't match)
        if candidates.isEmpty {
            candidates.append(contentsOf: await searchBooksWithRanking(
                query: title,
                preferISBN: isbn
            ))
        }
        
        // Strategy 3: Title with year
        if candidates.isEmpty && publishedYear != nil {
            candidates.append(contentsOf: await searchBooksWithRanking(
                query: "\(title) \(publishedYear!)",
                preferISBN: isbn
            ))
        }
        
        // Return the best match with a cover
        return candidates.first { $0.coverImageURL != nil } ?? candidates.first
    }
}

// Extend VolumeInfo to include more metadata
extension VolumeInfo {
    var ratingsCount: Int? {
        // This would need to be added to the VolumeInfo struct
        // For now, return nil
        return nil
    }
    
    var averageRating: Double? {
        // This would need to be added to the VolumeInfo struct
        // For now, return nil
        return nil
    }
    
    var publisher: String? {
        // This would need to be added to the VolumeInfo struct
        // For now, return nil
        return nil
    }
    
    var language: String? {
        // This would need to be added to the VolumeInfo struct
        return "en"
    }
}