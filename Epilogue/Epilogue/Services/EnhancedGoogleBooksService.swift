import Foundation
import os.log

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
    
    // Smart query parsing for natural language searches
    struct ParsedQuery {
        let title: String
        let author: String?
        let year: String?
        let originalQuery: String
        
        init(from query: String) {
            self.originalQuery = query
            
            // Parse "Title by Author" format
            if query.contains(" by ") {
                let parts = query.components(separatedBy: " by ")
                self.title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if parts.count > 1 {
                    let authorPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Check if year is included (e.g., "Rob Bell 2011")
                    let components = authorPart.split(separator: " ")
                    if let lastComponent = components.last,
                       let yearValue = Int(String(lastComponent)),
                       yearValue > 1900 && yearValue < 2100 {
                        self.year = String(lastComponent)
                        self.author = components.dropLast().joined(separator: " ")
                    } else {
                        self.author = authorPart
                        self.year = nil
                    }
                } else {
                    self.author = nil
                    self.year = nil
                }
            }
            // Parse comma-separated format: "Title, Author"
            else if query.contains(", ") {
                let parts = query.components(separatedBy: ", ")
                self.title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                self.author = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                self.year = nil
            }
            // No clear separation, use the whole query as title
            else {
                self.title = query
                self.author = nil
                self.year = nil
            }
        }
        
        // Generate optimized search queries for Google Books API
        func generateSearchQueries() -> [String] {
            var queries: [String] = []
            
            // Clean title - remove special characters that might break the API
            let cleanTitle = title
                .replacingOccurrences(of: ":", with: " ")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let author = author {
                let cleanAuthor = author
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Most specific: exact title and author
                queries.append("intitle:\"\(cleanTitle)\" inauthor:\"\(cleanAuthor)\"")
                
                // Try without quotes for more results
                queries.append("intitle:\(cleanTitle) inauthor:\(cleanAuthor)")
                
                // Try with just first word of title and full author (handles subtitle variations)
                let firstWord = cleanTitle.split(separator: " ").first ?? ""
                if !firstWord.isEmpty {
                    queries.append("intitle:\(firstWord) inauthor:\"\(cleanAuthor)\"")
                }
                
                // Try with author's last name only
                let authorParts = cleanAuthor.split(separator: " ")
                if let lastName = authorParts.last {
                    queries.append("intitle:\"\(cleanTitle)\" inauthor:\(lastName)")
                }
            }
            
            // Fallback to just title
            queries.append("intitle:\"\(cleanTitle)\"")
            queries.append(cleanTitle)
            
            // If we have a year, add a query with year
            if let year = year {
                queries.append("\(cleanTitle) \(year)")
            }
            
            // Finally, try the original query as-is
            if !queries.contains(originalQuery) {
                queries.append(originalQuery)
            }
            
            return queries
        }
    }
    
    // Override the search to add smart filtering and ranking
    func searchBooksWithRanking(query: String, preferISBN: String? = nil, publisherHint: String? = nil) async -> [Book] {
        // Parse the query to extract title, author, etc.
        let parsedQuery = ParsedQuery(from: query)
        
        // If we have an ISBN, try that first
        if let isbn = preferISBN, !isbn.isEmpty {
            if let book = await searchBookByISBN(isbn) {
                return [book]
            }
        }
        
        // Get all search queries to try
        let searchQueries = parsedQuery.generateSearchQueries()
        var allResults: [GoogleBookItem] = []
        var triedQueries = Set<String>()
        
        // Try each query until we get good results
        for searchQuery in searchQueries {
            guard !triedQueries.contains(searchQuery) else { continue }
            triedQueries.insert(searchQuery)
            
            let results = await getRawSearchResults(query: searchQuery, maxResults: 20)
            allResults.append(contentsOf: results)
            
            // If we have enough good results, stop searching
            let booksWithCovers = allResults.filter { item in
                item.volumeInfo.imageLinks?.thumbnail != nil
            }
            
            if booksWithCovers.count >= 5 {
                break
            }
        }
        
        // Remove duplicates
        var seen = Set<String>()
        let uniqueResults = allResults.filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }
        
        // Score and rank the results
        let scoredResults = rankBooks(
            uniqueResults,
            originalQuery: query,
            preferredISBN: preferISBN,
            parsedQuery: parsedQuery,
            publisherHint: publisherHint
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
            os_log(.error, log: OSLog.default, "Search error: %@", error.localizedDescription)
            return nil
        }
    }

    // MARK: - Trending (Current Year)
    private static var trendingCache: (year: Int, books: [Book], timestamp: Date)?
    
    // Removed trending fetch from service for safety; UI fallbacks remain.

    // Fetch a single raw GoogleBookItem by ISBN (used for language checks)
    func fetchRawByISBN(_ isbn: String) async -> GoogleBookItem? {
        let query = "isbn:\(isbn)"
        if let items = await performRawSearch(query: query, maxResults: 1) {
            return items.first
        }
        return nil
    }
    
    private func rankBooks(
        _ items: [GoogleBookItem],
        originalQuery: String,
        preferredISBN: String?,
        parsedQuery: ParsedQuery? = nil,
        publisherHint: String? = nil
    ) -> [ScoredBook] {
        let queryWords = originalQuery.lowercased().split(separator: " ")
        let originalLower = originalQuery.lowercased()
        let isLOTRUmbrella = originalLower.contains("lord of the rings")

        return items.compactMap { item in
            var score = 0.0
            let volumeInfo = item.volumeInfo
            let book = item.book
            
            // Check for cover
            let hasCover = book.coverImageURL != nil && !book.coverImageURL!.isEmpty
            if hasCover { score += 40 }
            // Bigger images are preferred
            if let links = volumeInfo.imageLinks, (links.extraLarge ?? links.large ?? links.medium ?? links.small) != nil {
                score += 10
            }
            
            // Check for ISBN
            let hasISBN = book.isbn != nil
            if hasISBN {
                score += 15
                
                // Exact ISBN match gets huge boost
                if let preferredISBN = preferredISBN,
                   book.isbn == preferredISBN {
                    score += 100
                }
            }
            
            // Title match scoring
            let titleLower = volumeInfo.title.lowercased()
            
            // If we have a parsed query, use it for better matching
            if let parsed = parsedQuery {
                let targetTitle = parsed.title.lowercased()
                
                // Exact title match (huge boost)
                if titleLower == targetTitle {
                    score += 100
                }
                // Title starts with target (very good match)
                else if titleLower.hasPrefix(targetTitle) {
                    score += 70
                }
                // Target title is contained in full (good match)
                else if titleLower.contains(targetTitle) {
                    score += 50
                }
                // All words from target title are in book title
                else {
                    let targetWords = Set(targetTitle.split(separator: " ").map { String($0) })
                    let bookWords = Set(titleLower.split(separator: " ").map { String($0) })
                    let matchingWords = targetWords.intersection(bookWords)
                    score += Double(matchingWords.count * 10)
                }
                
                // Author match (if we parsed an author)
                if let targetAuthor = parsed.author,
                   let authors = volumeInfo.authors {
                    let targetAuthorLower = targetAuthor.lowercased()
                    let authorString = authors.joined(separator: " ").lowercased()
                    
                    // Exact author match
                    if authorString == targetAuthorLower {
                        score += 50
                    }
                    // Author contains target
                    else if authorString.contains(targetAuthorLower) {
                        score += 30
                    }
                    // Last name match (common for author searches)
                    else {
                        let targetLastName = targetAuthorLower.split(separator: " ").last ?? ""
                        if !targetLastName.isEmpty && authorString.contains(targetLastName) {
                            score += 20
                        }
                    }
                }
                
                // Year match bonus
                if let targetYear = parsed.year,
                   let pubDate = volumeInfo.publishedDate {
                    if pubDate.contains(targetYear) {
                        score += 15
                    }
                }
            } else {
                // Fallback to original word-based matching
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
                    score += 15
                }
                // Publisher hint from CSV (Goodreads). Light boost on substring match
                if let hint = publisherHint?.lowercased(), !hint.isEmpty {
                    if publisher.contains(hint) || hint.contains(publisher) {
                        score += 12
                    }
                }
            }
            
            // Penalize if title contains unwanted terms
            let unwantedTerms = [
                "summary", "notes", "study guide", "spark",
                "cliff", "analysis", "workbook", "teacher",
                "illustrated", "graphic", "companion", "annotated",
                "movie tie-in", "calendar", "journal", "notebook",
                "coloring", "colouring"
            ]
            
            for term in unwantedTerms {
                if titleLower.contains(term) {
                    score -= 30
                }
            }
            
            // Check for language (prefer English)
            if let lang = volumeInfo.language, lang != "en" { score -= 10 }

            // Popularity: boost high ratings and counts when available
            if let avg = volumeInfo.averageRating { score += avg * 10 } // up to +50 for 5.0
            if let cnt = volumeInfo.ratingsCount {
                // log-scale boost up to ~+40 for very popular editions
                let boost = min(40.0, log10(Double(max(cnt, 1))) * 20.0)
                score += boost
            }

            // Heuristic: For LOTR umbrella queries, demote per-volume titles
            if isLOTRUmbrella {
                let t = volumeInfo.title.lowercased()
                let perVolumeKeywords = [
                    "fellowship of the ring", "two towers", "return of the king",
                    "book 1", "book one", "book i", "#1", "part 1", "volume 1", "vol 1"
                ]
                if perVolumeKeywords.contains(where: { t.contains($0) }) {
                    score -= 40 // prefer omnibus/canonical LOTR title
                }
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
        publishedYear: String? = nil,
        preferredPublisher: String? = nil
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
            preferISBN: isbn,
            publisherHint: preferredPublisher
        ))
        
        // Strategy 2: Just title (sometimes author names don't match)
        if candidates.isEmpty {
            candidates.append(contentsOf: await searchBooksWithRanking(
                query: title,
                preferISBN: isbn,
                publisherHint: preferredPublisher
            ))
        }
        
        // Strategy 3: Title with year
        if candidates.isEmpty && publishedYear != nil {
            candidates.append(contentsOf: await searchBooksWithRanking(
                query: "\(title) \(publishedYear!)",
                preferISBN: isbn,
                publisherHint: preferredPublisher
            ))
        }
        
        // Return the best match with a cover
        return candidates.first { $0.coverImageURL != nil } ?? candidates.first
    }
}

    // Removed placeholder extension; real fields are in VolumeInfo now
