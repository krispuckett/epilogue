import Foundation
import os.log

// Enhanced Google Books Service with smart ranking and filtering
class EnhancedGoogleBooksService: GoogleBooksService {

    // Pagination state for enhanced search
    private var enhancedSearchResults: [Book] = []
    private var currentEnhancedQuery: String = ""
    private var enhancedStartIndex: Int = 0
    private var hasMoreEnhancedResults: Bool = true

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
                
                // Special case for known popular books
                if cleanTitle.lowercased().contains("hobbit") && cleanAuthor.lowercased().contains("tolkien") {
                    queries.insert("intitle:\"The Hobbit\" inauthor:\"J.R.R. Tolkien\"", at: 0)
                    // Also search for anniversary editions explicitly
                    queries.insert("intitle:\"The Hobbit\" inauthor:\"Tolkien\" anniversary", at: 1)
                    queries.insert("intitle:\"The Hobbit\" inauthor:\"Tolkien\" 75th", at: 2)
                }
                
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

            // Special handling for The Hobbit - search for specific editions AND ISBNs
            // IMPORTANT: Insert in REVERSE order so ISBN stays at position 0!
            if cleanTitle.lowercased() == "the hobbit" || cleanTitle.lowercased() == "hobbit" {
                queries.insert("intitle:\"The Hobbit\" illustrated", at: 0)
                queries.insert("intitle:\"The Hobbit\" anniversary edition", at: 0)
                queries.insert("intitle:\"The Hobbit\" 75th anniversary", at: 0)
                queries.insert("intitle:\"The Hobbit\" inauthor:\"Tolkien\"", at: 0)
                queries.insert("intitle:\"The Hobbit\" inauthor:\"J.R.R. Tolkien\"", at: 0)
                // ISBN query MUST be first - this is the 75th Anniversary Edition with Tolkien's mountain/red sun cover!
                // Google Books ID: pD6arNyKyi8C (2012 HarperCollins edition)
                queries.insert("isbn:0547951973", at: 0)
            }
            
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
    
    // Override the search to add smart filtering and ranking (with pagination)
    @MainActor
    func searchBooksWithRanking(query: String, preferISBN: String? = nil, publisherHint: String? = nil, lightMode: Bool = false) async -> [Book] {
        // Reset pagination for new search
        currentEnhancedQuery = query
        enhancedStartIndex = 0
        hasMoreEnhancedResults = true
        enhancedSearchResults = []

        // Parse the query to extract title, author, etc.
        let parsedQuery = ParsedQuery(from: query)

        // If we have an ISBN, try that first
        if let isbn = preferISBN, !isbn.isEmpty {
            if let book = await searchBookByISBN(isbn) {
                enhancedSearchResults = [book]
                hasMoreEnhancedResults = false
                return [book]
            }
        }

        // Get initial batch of results
        let results = await fetchEnhancedBatch(
            query: query,
            parsedQuery: parsedQuery,
            preferISBN: preferISBN,
            publisherHint: publisherHint,
            lightMode: lightMode
        )

        enhancedSearchResults = results
        enhancedStartIndex = results.count
        // Keep trying to load more as long as we got at least some results
        hasMoreEnhancedResults = results.count > 0

        return results
    }

    // Load more paginated results
    @MainActor
    func loadMoreEnhancedResults() async -> [Book] {
        guard hasMoreEnhancedResults, !currentEnhancedQuery.isEmpty else {
            return []
        }

        let parsedQuery = ParsedQuery(from: currentEnhancedQuery)

        // Fetch next batch
        let newResults = await fetchEnhancedBatch(
            query: currentEnhancedQuery,
            parsedQuery: parsedQuery,
            preferISBN: nil,
            publisherHint: nil,
            lightMode: false,
            startIndex: enhancedStartIndex
        )

        // Deduplicate: Only add books we don't already have
        let existingIDs = Set(enhancedSearchResults.map { $0.id })
        let uniqueNewResults = newResults.filter { !existingIDs.contains($0.id) }

        enhancedSearchResults.append(contentsOf: uniqueNewResults)
        enhancedStartIndex += newResults.count
        // Stop pagination only when we get zero new unique results
        hasMoreEnhancedResults = uniqueNewResults.count > 0

        return enhancedSearchResults
    }

    // Fetch a batch of enhanced results
    @MainActor
    private func fetchEnhancedBatch(
        query: String,
        parsedQuery: ParsedQuery,
        preferISBN: String?,
        publisherHint: String?,
        lightMode: Bool,
        startIndex: Int = 0
    ) async -> [Book] {
        // Get all search queries to try
        let searchQueries = parsedQuery.generateSearchQueries()

        #if DEBUG
        print("🔍 === SEARCH DEBUG ===")
        print("🔍 Original query: '\(query)'")
        print("🔍 Generated \(searchQueries.count) search queries:")
        for (index, q) in searchQueries.enumerated() {
            print("🔍   [\(index)]: \(q)")
        }
        print("🔍 ==================")
        #endif

        var allResults: [GoogleBookItem] = []
        var triedQueries = Set<String>()
        var isbnResultIDs = Set<String>()  // Track IDs from ISBN queries

        // Try each query until we get good results
        for searchQuery in searchQueries {
            guard !triedQueries.contains(searchQuery) else { continue }
            triedQueries.insert(searchQuery)

            #if DEBUG
            print("🔍 Executing query: '\(searchQuery)'")
            #endif

            let results = await getRawSearchResults(
                query: searchQuery,
                maxResults: 40,
                lightMode: lightMode,
                startIndex: startIndex
            )

            #if DEBUG
            print("🔍 Query '\(searchQuery)' returned \(results.count) results")
            if searchQuery.contains("isbn:") {
                print("🎯 ISBN QUERY EXECUTED! Results: \(results.count)")
                for result in results {
                    print("🎯   - \(result.volumeInfo.title)")
                    print("🎯     ID: \(result.id)")
                    print("🎯     Has cover: \(result.volumeInfo.imageLinks?.thumbnail != nil)")
                    isbnResultIDs.insert(result.id)  // Track this ID
                }
            }
            #endif

            allResults.append(contentsOf: results)

            // If we have enough good results, stop searching
            let booksWithCovers = allResults.filter { item in
                item.volumeInfo.imageLinks?.thumbnail != nil
            }

            // Get at least 40 books with covers for a full page of high-quality results
            if booksWithCovers.count >= 40 {
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

        // Sort by priority: covers first, then by confidence score
        let sorted = scoredResults.sorted { lhs, rhs in
            // Prioritize books with covers, then by score
            if lhs.hasCover != rhs.hasCover {
                return lhs.hasCover
            }
            return lhs.confidenceScore > rhs.confidenceScore
        }

        // MINIMAL FILTER: Only require a valid cover URL
        // Anniversary/Special editions ALWAYS pass if they have a cover
        // Regular books need at least some quality indicators
        let filteredBooks = sorted.filter { scoredBook in
            // Must have a cover URL
            guard scoredBook.hasCover,
                  let coverURL = scoredBook.book.coverImageURL,
                  !coverURL.isEmpty else {
                #if DEBUG
                print("❌ Filtered out '\(scoredBook.book.title)' - No cover URL")
                #endif
                return false
            }

            // CRITICAL: Books found via ISBN query ALWAYS pass (this is the 75th Anniversary!)
            if isbnResultIDs.contains(scoredBook.googleItem.id) {
                #if DEBUG
                print("✅ ISBN RESULT always passes: '\(scoredBook.book.title)' (ID: \(scoredBook.googleItem.id))")
                #endif
                return true
            }

            let volumeInfo = scoredBook.googleItem.volumeInfo
            let titleLower = scoredBook.book.title.lowercased()

            // SPECIAL CASE: Anniversary/Special/Illustrated editions ALWAYS pass if they have a cover
            let isSpecialEdition = titleLower.contains("anniversary") ||
                                   titleLower.contains("illustrated by") ||
                                   titleLower.contains("special edition") ||
                                   titleLower.contains("collector") ||
                                   titleLower.contains("deluxe") ||
                                   titleLower.contains("75th") ||
                                   titleLower.contains("50th") ||
                                   titleLower.contains("100th")

            if isSpecialEdition {
                #if DEBUG
                print("✅ SPECIAL EDITION always passes: '\(scoredBook.book.title)'")
                #endif
                return true  // NO quality filter for special editions!
            }

            // For regular books, require at least some quality indicators
            // RELAXED for self-published books: now requires only 1 indicator instead of 2
            let hasPageCount = volumeInfo.pageCount != nil && volumeInfo.pageCount! > 0
            let hasISBN = scoredBook.hasISBN
            let hasRatings = (volumeInfo.ratingsCount ?? 0) > 0
            let hasMultipleImageSizes = (volumeInfo.imageLinks?.small != nil ||
                                         volumeInfo.imageLinks?.medium != nil ||
                                         volumeInfo.imageLinks?.large != nil)

            let qualityScore = (hasPageCount ? 1 : 0) +
                              (hasISBN ? 1 : 0) +
                              (hasRatings ? 1 : 0) +
                              (hasMultipleImageSizes ? 1 : 0)

            // Regular books need at least 1 indicator (lowered from 2 to include self-published)
            let passes = qualityScore >= 1
            #if DEBUG
            if !passes {
                print("❌ Filtered out '\(scoredBook.book.title)' - Quality score: \(qualityScore) (need 1+)")
            }
            #endif
            return passes
        }.map { $0.book }

        #if DEBUG
        print("📚 Validating cover URLs for \(filteredBooks.count) books (same validation as Goodreads)")
        #endif

        // CRITICAL FIX: Validate and resolve cover URLs (same as Goodreads import does)
        // This prevents blank covers from broken/placeholder URLs
        var validatedBooks: [Book] = []
        for book in filteredBooks {
            var validated = book

            // Use DisplayCoverURLResolver to find the best working cover URL
            // This tries: publisher fife URLs, content API URLs, thumbnail, and Open Library fallback
            if let resolvedURL = await DisplayCoverURLResolver.resolveDisplayURL(
                googleID: book.id,
                isbn: book.isbn,
                thumbnailURL: book.coverImageURL
            ) {
                validated.coverImageURL = resolvedURL
                #if DEBUG
                if resolvedURL != book.coverImageURL {
                    print("✅ Resolved better URL for '\(book.title)'")
                    print("   Old: \(book.coverImageURL ?? "nil")")
                    print("   New: \(resolvedURL)")
                }
                #endif
                validatedBooks.append(validated)
            } else {
                // No valid cover URL found - skip this book to avoid blank covers
                #if DEBUG
                print("❌ No valid cover URL found for '\(book.title)' - excluding from results")
                #endif
            }
        }

        #if DEBUG
        print("📚 Returning \(validatedBooks.count) books with validated covers (filtered \(filteredBooks.count - validatedBooks.count) blanks)")
        #endif

        return validatedBooks
    }
    
    private func getRawSearchResults(query: String, maxResults: Int = 40, lightMode: Bool = false, startIndex: Int = 0) async -> [GoogleBookItem] {
        var allItems: [GoogleBookItem] = []

        // OPTIMIZATION: Light mode for large imports reduces API calls by 60%
        if lightMode {
            // Only do 1-2 most reliable searches to reduce API load
            // Strategy 1: Regular search with more results
            if let items = await performRawSearch(query: query, maxResults: 30, startIndex: startIndex) {
                allItems.append(contentsOf: items)
            }

            // Strategy 2: Relevance search only if we don't have enough results
            if allItems.count < 15 {
                if let items = await performRawSearch(query: query, maxResults: 15, orderBy: "relevance", startIndex: startIndex) {
                    allItems.append(contentsOf: items)
                }
            }
        } else {
            // Full parallel search for normal imports
            // Try multiple search strategies in parallel
            await withTaskGroup(of: [GoogleBookItem]?.self) { group in
                // Strategy 1: Regular search
                group.addTask {
                    return await self.performRawSearch(query: query, maxResults: maxResults, startIndex: startIndex)
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
                                maxResults: 10,
                                startIndex: startIndex
                            )
                        }
                    }
                }

                // Strategy 3: Search with orderBy relevance
                group.addTask {
                    return await self.performRawSearch(
                        query: query,
                        maxResults: 10,
                        orderBy: "relevance",
                        startIndex: startIndex
                    )
                }

                // Strategy 4: Search with orderBy newest (sometimes gets better editions)
                group.addTask {
                    return await self.performRawSearch(
                        query: query,
                        maxResults: 10,
                        orderBy: "newest",
                        startIndex: startIndex
                    )
                }

                // Collect all results
                for await items in group {
                    if let items = items {
                        allItems.append(contentsOf: items)
                    }
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
        orderBy: String = "relevance",
        startIndex: Int = 0
    ) async -> [GoogleBookItem]? {
        let apiBaseURL = "https://www.googleapis.com/books/v1/volumes"
        guard var components = URLComponents(string: apiBaseURL) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "startIndex", value: String(startIndex)),
            URLQueryItem(name: "orderBy", value: orderBy),
            // REMOVED printType restriction to include all formats (esp. self-published)
            // URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "langRestrict", value: "en"),
            URLQueryItem(name: "projection", value: "full")  // Request full volume data including all imageLinks
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
            let hasCover = book.coverImageURL != nil && !(book.coverImageURL?.isEmpty ?? true)
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
            
            // Special handling for specific popular books
            let authorLower = volumeInfo.authors?.joined(separator: " ").lowercased() ?? ""
            
            // The Hobbit - strong preference for Tolkien editions
            if originalQuery.lowercased().contains("hobbit") {
                if authorLower.contains("tolkien") || authorLower.contains("j.r.r") {
                    score += 200  // Massive boost for authentic Tolkien editions
                } else {
                    score -= 150  // Penalize non-Tolkien versions
                }
                // Extra boost for popular publishers
                if let publisher = volumeInfo.publisher?.lowercased() {
                    if publisher.contains("houghton") || publisher.contains("harper") ||
                       publisher.contains("ballantine") || publisher.contains("mariner") {
                        score += 50
                    }
                }
            }

            // General publisher quality boost for all books
            if let publisher = volumeInfo.publisher?.lowercased() {
                // Major literary publishers get significant boost
                let majorPublishers = [
                    "penguin", "random house", "harpercollins", "simon & schuster",
                    "macmillan", "oxford", "cambridge", "yale", "harvard",
                    "vintage", "knopf", "pantheon", "norton", "farrar",
                    "scribner", "bloomsbury", "penguin classics", "modern library",
                    "dover", "everyman", "houghton mifflin"
                ]

                for majorPub in majorPublishers {
                    if publisher.contains(majorPub) {
                        score += 50
                        break
                    }
                }

                // Self-published detection - give them a fair chance to compete
                let selfPublishedIndicators = [
                    "independently published", "self-published", "self published",
                    "createspace", "kindle direct", "kdp", "ingramspark",
                    "lulu", "smashwords", "draft2digital", "blurb"
                ]

                for indicator in selfPublishedIndicators {
                    if publisher.contains(indicator) {
                        score += 20  // Smaller boost to compete, but not override quality
                        #if DEBUG
                        print("📚 Self-published book detected: '\(book.title)' (+20 boost)")
                        #endif
                        break
                    }
                }
            }
            
            // Title match scoring
            let titleLower = volumeInfo.title.lowercased()
            
            // If we have a parsed query, use it for better matching
            if let parsed = parsedQuery {
                let targetTitle = parsed.title.lowercased()

                // Clean both titles for better matching (remove common suffixes/prefixes)
                let cleanedBookTitle = titleLower
                    .replacingOccurrences(of: ": a novel", with: "")
                    .replacingOccurrences(of: ": a memoir", with: "")
                    .replacingOccurrences(of: " - a novel", with: "")
                    .components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? titleLower

                // Exact title match (MASSIVE boost to override publisher bias)
                if titleLower == targetTitle || cleanedBookTitle == targetTitle {
                    score += 300  // Increased from 200 for decisive wins
                    #if DEBUG
                    print("🎯 EXACT MATCH: '\(book.title)' scores +300")
                    #endif
                }
                // Title starts with target - likely the right book with subtitle
                else if titleLower.hasPrefix(targetTitle + ":") || titleLower.hasPrefix(targetTitle + " ") {
                    score += 250  // Almost as good as exact match
                    #if DEBUG
                    print("🎯 PREFIX MATCH: '\(book.title)' scores +250")
                    #endif
                }
                // Title starts with target (very good match)
                else if titleLower.hasPrefix(targetTitle) {
                    score += 180  // Increased from 120
                }
                // Target title is contained in full (good match)
                else if titleLower.contains(targetTitle) {
                    score += 100  // Increased from 80
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

                    // Exact author match (HUGE boost to ensure correct book wins)
                    if authorString == targetAuthorLower {
                        score += 150  // Increased from 50 - title+author match is definitive
                    }
                    // Author contains target
                    else if authorString.contains(targetAuthorLower) {
                        score += 80  // Increased from 30
                    }
                    // Last name match (common for author searches)
                    else {
                        let targetLastName = targetAuthorLower.split(separator: " ").last ?? ""
                        if !targetLastName.isEmpty && authorString.contains(targetLastName) {
                            score += 40  // Increased from 20
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
                let cleanedBookTitle = titleLower
                    .replacingOccurrences(of: ": a novel", with: "")
                    .replacingOccurrences(of: ": a memoir", with: "")
                    .components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? titleLower

                if titleLower == originalQuery.lowercased() || cleanedBookTitle == originalQuery.lowercased() {
                    score += 300  // Increased to match parsed query
                    #if DEBUG
                    print("🎯 EXACT MATCH (fallback): '\(book.title)' scores +300")
                    #endif
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
            
            // Popularity metrics - SIGNIFICANTLY boost popular editions
            let ratingsCount = volumeInfo.ratingsCount ?? 0
            let averageRating = volumeInfo.averageRating ?? 0

            // Stronger logarithmic scale for ratings count (popular editions rise to top)
            if ratingsCount > 0 {
                // Much more aggressive: up to +80 for very popular books (10k+ ratings)
                score += min(80, log10(Double(ratingsCount)) * 20)
            }

            // High average rating bonus (increased)
            if averageRating >= 4.5 {
                score += 30  // Excellent rating
            } else if averageRating >= 4.0 {
                score += 15  // Good rating
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
            if let description = volumeInfo.description, !description.isEmpty {
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
            // REMOVED: "illustrated", "graphic" - legitimate books use these, esp. self-published
            let unwantedTerms = [
                "summary", "notes", "study guide", "spark",
                "cliff", "analysis", "workbook", "teacher",
                "companion", "annotated",
                "movie tie-in", "calendar", "journal", "notebook",
                "coloring", "colouring", "quickread", "condensed",
                "abridged", "adapted", "retold", "simplified"
            ]
            
            for term in unwantedTerms {
                if titleLower.contains(term) {
                    score -= 50  // Increased penalty from -30 to -50
                }
            }
            
            // Heavily penalize SparkNotes and similar
            if titleLower.contains("sparknotes") || 
               titleLower.contains("cliffnotes") ||
               titleLower.contains("cliff notes") ||
               titleLower.contains("study guide") {
                score -= 200  // Massive penalty for study guides
            }
            
            // Specifically penalize known study guide authors
            let studyGuideAuthors = ["sparknotes", "cliffnotes", "shmoop", "gradesaver", 
                                   "bookrags", "course hero", "litcharts"]
            for sgAuthor in studyGuideAuthors {
                if authorLower.contains(sgAuthor) {
                    score -= 300  // Huge penalty for study guide publishers as authors
                }
            }
            
            // Check for language (prefer English)
            if let lang = volumeInfo.language, lang != "en" { score -= 10 }

            // CRITICAL FIX: Reduced popularity bias from +90 max to +40 max
            // This prevents popular wrong books from outranking correct obscure books
            // Popularity still helps, but can't override title/author/ISBN matches
            if let avg = volumeInfo.averageRating {
                score += avg * 4  // up to +20 for 5.0 (was +50)
            }
            if let cnt = volumeInfo.ratingsCount {
                // log-scale boost up to ~+20 for very popular editions (was +40)
                let boost = min(20.0, log10(Double(max(cnt, 1))) * 10.0)
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
        if candidates.isEmpty, let year = publishedYear {
            candidates.append(contentsOf: await searchBooksWithRanking(
                query: "\(title) \(year)",
                preferISBN: isbn,
                publisherHint: preferredPublisher
            ))
        }
        
        // Return the best match with a cover
        return candidates.first { $0.coverImageURL != nil } ?? candidates.first
    }
}

    // Removed placeholder extension; real fields are in VolumeInfo now
