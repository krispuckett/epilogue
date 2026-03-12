import Foundation
import os.log

// Enhanced Google Books Service with smart ranking and filtering
class EnhancedGoogleBooksService: GoogleBooksService {

    // Pagination state for enhanced search
    private var enhancedSearchResults: [Book] = []
    private var currentEnhancedQuery: String = ""
    private var enhancedStartIndex: Int = 0
    private var hasMoreEnhancedResults: Bool = true

    // Search result cache — avoids duplicate API calls for the same query
    private var searchCache: [String: [Book]] = [:]

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

        // Extract a 4-digit year (1900-2099) from anywhere in a string, return the year and the string with it removed
        private static func extractYear(from text: String) -> (year: String, remainder: String)? {
            let pattern = #"\b(19\d{2}|20\d{2})\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else { return nil }
            let year = String(text[range])
            let remainder = text.replacingCharacters(in: range, with: "")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (year, remainder)
        }

        init(from query: String) {
            self.originalQuery = query

            // Parse "Title by Author" format
            if query.contains(" by ") {
                let parts = query.components(separatedBy: " by ")
                let rawTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)

                if parts.count > 1 {
                    let authorPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

                    // Extract year from author part first (e.g., "Mendelsohn 2025")
                    if let extracted = Self.extractYear(from: authorPart) {
                        self.year = extracted.year
                        self.author = extracted.remainder.isEmpty ? nil : extracted.remainder
                    }
                    // Then check title part for year (e.g., "The Odyssey 2025 by Homer")
                    else if let extracted = Self.extractYear(from: rawTitle) {
                        self.year = extracted.year
                        self.author = authorPart
                        self.title = extracted.remainder
                        return
                    } else {
                        self.author = authorPart
                        self.year = nil
                    }
                } else {
                    self.author = nil
                    self.year = nil
                }

                // Strip year from title if it ended up there
                if let yr = self.year, let extracted = Self.extractYear(from: rawTitle), extracted.year == yr {
                    self.title = extracted.remainder
                } else {
                    self.title = rawTitle
                }
            }
            // Parse comma-separated format: "Title, Author"
            else if query.contains(", ") {
                let parts = query.components(separatedBy: ", ")
                let rawTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let rawAuthor = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil

                // Extract year from either part
                if let author = rawAuthor, let extracted = Self.extractYear(from: author) {
                    self.year = extracted.year
                    self.author = extracted.remainder.isEmpty ? nil : extracted.remainder
                } else if let extracted = Self.extractYear(from: rawTitle) {
                    self.year = extracted.year
                    self.title = extracted.remainder
                    self.author = rawAuthor
                    return
                } else {
                    self.year = nil
                    self.author = rawAuthor
                }

                if let yr = self.year, let extracted = Self.extractYear(from: rawTitle), extracted.year == yr {
                    self.title = extracted.remainder
                } else {
                    self.title = rawTitle
                }
            }
            // No clear separation — check for trailing year (e.g., "The Odyssey 2025")
            else {
                if let extracted = Self.extractYear(from: query) {
                    self.year = extracted.year
                    self.title = extracted.remainder
                } else {
                    self.title = query
                    self.year = nil
                }
                self.author = nil
            }
        }
        
        // Generate optimized search queries for Google Books API
        // Keep it lean — max 4 queries to conserve API quota
        func generateSearchQueries() -> [String] {
            var queries: [String] = []

            let cleanTitle = title
                .replacingOccurrences(of: ":", with: " ")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let author = author {
                let cleanAuthor = author
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Best query: title + author in author field (+ year if available)
                if let year = year {
                    queries.append("intitle:\"\(cleanTitle)\" inauthor:\"\(cleanAuthor)\" \(year)")
                }
                queries.append("intitle:\"\(cleanTitle)\" inauthor:\"\(cleanAuthor)\"")

                // Critical fallback: name as FREE TEXT (not inauthor:)
                // This catches translators, editors, foreword writers — anyone in subtitle/description
                // e.g. "The Odyssey" by Mendelsohn → Homer is author, Mendelsohn is in subtitle
                if let year = year {
                    queries.append("intitle:\"\(cleanTitle)\" \"\(cleanAuthor)\" \(year)")
                }
                queries.append("intitle:\"\(cleanTitle)\" \"\(cleanAuthor)\"")
            }

            // Title + year — critical for disambiguating classic works with many editions
            if let year = year {
                queries.append("intitle:\"\(cleanTitle)\" \(year)")
            }

            // Fallback: just title (handles most cases well)
            queries.append("intitle:\"\(cleanTitle)\"")

            // Final fallback: raw query as-is
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

        // Return cached results if available (same query = instant)
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespaces)
        if let cached = searchCache[cacheKey] {
            enhancedSearchResults = cached
            enhancedStartIndex = cached.count
            hasMoreEnhancedResults = cached.count >= 10
            return cached
        }

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
        hasMoreEnhancedResults = results.count > 0

        // Cache for instant re-query
        if !results.isEmpty {
            searchCache[cacheKey] = results
        }

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

        // Try each query until we get good results (stop if quota exhausted)
        for searchQuery in searchQueries {
            guard !isQuotaExhausted else { break }
            guard !triedQueries.contains(searchQuery) else { continue }
            triedQueries.insert(searchQuery)

            #if DEBUG
            print("🔍 Executing query: '\(searchQuery)'")
            #endif

            let results = await getRawSearchResults(
                query: searchQuery,
                maxResults: 20,
                lightMode: lightMode,
                startIndex: startIndex
            )

            #if DEBUG
            print("🔍 Query '\(searchQuery)' returned \(results.count) results")
            #endif

            allResults.append(contentsOf: results)

            // If we have enough results, stop searching (conserve API quota)
            if allResults.count >= 20 {
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

        // Only filter out clear junk (study guides, spam) — identified by very negative scores.
        // Everything else is shown, ranked by confidence. Books with covers sort first.
        let topResults = sorted
            .filter { $0.confidenceScore > -100 }  // Only reject extreme junk
            .prefix(20)
            .map { $0.book }

        #if DEBUG
        print("📚 Returning \(topResults.count) books (from \(sorted.count) scored)")
        #endif

        return topResults
    }
    
    private func getRawSearchResults(query: String, maxResults: Int = 40, lightMode: Bool = false, startIndex: Int = 0) async -> [GoogleBookItem] {
        var allItems: [GoogleBookItem] = []

        // Single relevance search — one API call instead of 4
        // This dramatically reduces quota usage
        if let items = await performRawSearch(query: query, maxResults: maxResults, startIndex: startIndex) {
            allItems.append(contentsOf: items)
        }

        // Only fetch more if we got very few results and haven't hit quota
        if allItems.count < 5 && !isQuotaExhausted && !lightMode {
            if let items = await performRawSearch(query: query, maxResults: 20, orderBy: "newest", startIndex: startIndex) {
                allItems.append(contentsOf: items)
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
    
    /// Tracks whether we've hit API quota limits this session
    private(set) var isQuotaExhausted = false

    private func performRawSearch(
        query: String,
        maxResults: Int,
        orderBy: String = "relevance",
        startIndex: Int = 0
    ) async -> [GoogleBookItem]? {
        // Don't bother calling if we already know quota is exhausted
        guard !isQuotaExhausted else { return nil }

        let apiBaseURL = "https://www.googleapis.com/books/v1/volumes"
        guard var components = URLComponents(string: apiBaseURL) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: GoogleBooksAPIKey),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "startIndex", value: String(startIndex)),
            URLQueryItem(name: "orderBy", value: orderBy),
            URLQueryItem(name: "langRestrict", value: "en"),
            URLQueryItem(name: "projection", value: "full")
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check for rate limiting (429)
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                isQuotaExhausted = true
                os_log(.fault, log: OSLog.default, "Google Books API quota exceeded (429)")
                return nil
            }

            let decoded = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
            return decoded.items ?? []
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

        return items.compactMap { item in
            var score = 0.0
            let volumeInfo = item.volumeInfo
            let book = item.book
            let titleLower = volumeInfo.title.lowercased()
            let subtitleLower = volumeInfo.subtitle?.lowercased() ?? ""
            let authorLower = volumeInfo.authors?.joined(separator: " ").lowercased() ?? ""
            let descriptionLower = volumeInfo.description?.lowercased() ?? ""

            // --- Cover & ISBN ---
            let hasCover = book.coverImageURL != nil && !(book.coverImageURL?.isEmpty ?? true)
            if hasCover { score += 40 }

            let hasISBN = book.isbn != nil
            if hasISBN { score += 15 }
            if let preferredISBN, book.isbn == preferredISBN { score += 100 }

            // --- Title matching ---
            if let parsed = parsedQuery {
                let target = parsed.title.lowercased()
                let cleaned = titleLower
                    .replacingOccurrences(of: ": a novel", with: "")
                    .replacingOccurrences(of: ": a memoir", with: "")
                    .components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? titleLower

                if titleLower == target || cleaned == target {
                    score += 300  // Exact match
                } else if titleLower.hasPrefix(target + ":") || titleLower.hasPrefix(target + " ") {
                    score += 250  // Title with subtitle
                } else if titleLower.hasPrefix(target) {
                    score += 180
                } else if titleLower.contains(target) {
                    score += 100
                } else {
                    let targetWords = Set(target.split(separator: " ").map(String.init))
                    let bookWords = Set(titleLower.split(separator: " ").map(String.init))
                    score += Double(targetWords.intersection(bookWords).count * 10)
                }

                // Author match — also checks subtitle & description for translators/editors
                if let targetAuthor = parsed.author {
                    let targetLower = targetAuthor.lowercased()
                    if authorLower == targetLower {
                        score += 150
                    } else if authorLower.contains(targetLower) {
                        score += 80
                    } else if let lastName = targetLower.split(separator: " ").last, authorLower.contains(lastName) {
                        score += 40
                    }
                    // Translator/editor/contributor: name in subtitle (e.g. "A New Translation by Daniel Mendelsohn")
                    else if subtitleLower.contains(targetLower) {
                        score += 120
                    } else if let lastName = targetLower.split(separator: " ").last, subtitleLower.contains(lastName) {
                        score += 80
                    }
                    // Last resort: name appears in description
                    else if descriptionLower.contains(targetLower) {
                        score += 40
                    } else if let lastName = targetLower.split(separator: " ").last, descriptionLower.contains(lastName) {
                        score += 20
                    }
                }

                // Year match — heavy boost when user explicitly specified a year
                if let year = parsed.year {
                    if let pubDate = volumeInfo.publishedDate, pubDate.contains(year) {
                        score += 200  // Strong boost: exact year match
                    } else if volumeInfo.publishedDate != nil {
                        score -= 50   // Penalize wrong year when user asked for a specific one
                    }
                }
            } else {
                // Simple word-based matching
                for word in queryWords where titleLower.contains(word) { score += 5 }
                for word in queryWords where authorLower.contains(word) { score += 3 }

                let cleaned = titleLower.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? titleLower
                if titleLower == originalQuery.lowercased() || cleaned == originalQuery.lowercased() {
                    score += 300
                }
            }

            // --- Popularity ---
            let ratingsCount = volumeInfo.ratingsCount ?? 0
            let averageRating = volumeInfo.averageRating ?? 0
            if ratingsCount > 0 { score += min(60, log10(Double(ratingsCount)) * 15) }
            if averageRating >= 4.0 { score += 15 }

            // --- Quality signals ---
            if let pageCount = volumeInfo.pageCount {
                score += pageCount < 50 ? -20 : 5
            }
            if volumeInfo.publishedDate != nil { score += 5 }
            if let desc = volumeInfo.description, !desc.isEmpty { score += 5 }

            // --- Publisher ---
            if let publisher = volumeInfo.publisher?.lowercased() {
                let majorPublishers = [
                    "penguin", "random house", "harpercollins", "simon",
                    "macmillan", "hachette", "scholastic", "vintage",
                    "knopf", "doubleday", "bantam", "tor", "ace",
                    "oxford", "cambridge", "norton", "farrar", "scribner",
                    "bloomsbury", "houghton mifflin"
                ]
                if majorPublishers.contains(where: { publisher.contains($0) }) { score += 30 }

                if let hint = publisherHint?.lowercased(), !hint.isEmpty {
                    if publisher.contains(hint) || hint.contains(publisher) { score += 12 }
                }
            }

            // --- Junk penalties ---
            let junkTerms = [
                "summary", "study guide", "sparknotes", "cliffnotes", "cliff notes",
                "workbook", "teacher", "coloring", "colouring", "quickread",
                "condensed", "abridged", "retold", "simplified"
            ]
            for term in junkTerms where titleLower.contains(term) { score -= 100 }

            let junkAuthors = ["sparknotes", "cliffnotes", "shmoop", "gradesaver", "bookrags", "litcharts"]
            for author in junkAuthors where authorLower.contains(author) { score -= 300 }

            if let lang = volumeInfo.language, lang != "en" { score -= 10 }

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
