import Foundation
import SwiftUI
import Combine

// MARK: - Google Books API Models
struct GoogleBooksResponse: Codable {
    let items: [GoogleBookItem]?
    let totalItems: Int
}

struct GoogleBookItem: Codable, Identifiable {
    let id: String
    let volumeInfo: VolumeInfo
    
    var book: Book {
        // Get the best available image URL - prefer extraLarge if available
        var imageURL = volumeInfo.imageLinks?.extraLarge
            ?? volumeInfo.imageLinks?.large 
            ?? volumeInfo.imageLinks?.medium 
            ?? volumeInfo.imageLinks?.small 
            ?? volumeInfo.imageLinks?.thumbnail
        
        // Enhance Google Books image URL for higher resolution
        if let url = imageURL {
            imageURL = enhanceGoogleBooksImageURL(url)
        }
        
        return Book(
            id: id,
            title: volumeInfo.title,
            author: volumeInfo.authors?.joined(separator: ", ") ?? "Unknown Author",
            publishedYear: volumeInfo.publishedYear,
            coverImageURL: imageURL,
            isbn: volumeInfo.industryIdentifiers?.first { $0.type.contains("ISBN") }?.identifier,
            description: volumeInfo.description,
            pageCount: volumeInfo.pageCount,
            localId: UUID()
        )
    }
    
    private func enhanceGoogleBooksImageURL(_ urlString: String) -> String {
        // FIXED: Remove zoom parameter entirely to get full cover
        // zoom=3 was causing cropped images showing only part of the cover
        
        var enhanced = urlString
        
        // IMPORTANT: Convert HTTP to HTTPS for App Transport Security
        enhanced = enhanced.replacingOccurrences(of: "http://", with: "https://")
        
        // Remove ALL zoom parameters if present
        if let regex = try? NSRegularExpression(pattern: "&zoom=\\d", options: []) {
            let range = NSRange(location: 0, length: enhanced.utf16.count)
            enhanced = regex.stringByReplacingMatches(in: enhanced, options: [], range: range, withTemplate: "")
        }
        
        // Remove zoom parameter at start of query string too
        enhanced = enhanced.replacingOccurrences(of: "?zoom=1&", with: "?")
        enhanced = enhanced.replacingOccurrences(of: "?zoom=2&", with: "?")
        enhanced = enhanced.replacingOccurrences(of: "?zoom=3&", with: "?")
        enhanced = enhanced.replacingOccurrences(of: "?zoom=4&", with: "?")
        enhanced = enhanced.replacingOccurrences(of: "?zoom=5&", with: "?")
        
        // Add width parameter only (NO ZOOM!)
        if enhanced.contains("?") {
            enhanced += "&w=1080&source=gbs_api"
        } else {
            enhanced += "?w=1080&source=gbs_api"
        }
        
        // Also remove edge curl parameter if present (makes covers look cleaner)
        enhanced = enhanced.replacingOccurrences(of: "&edge=curl", with: "")
        enhanced = enhanced.replacingOccurrences(of: "?edge=curl", with: "?")
        
        return enhanced
    }
}

struct VolumeInfo: Codable {
    let title: String
    let authors: [String]?
    let publishedDate: String?
    let description: String?
    let pageCount: Int?
    let imageLinks: ImageLinks?
    let industryIdentifiers: [IndustryIdentifier]?
    
    var publishedYear: String? {
        guard let publishedDate = publishedDate else { return nil }
        // Extract year from various date formats (YYYY, YYYY-MM, YYYY-MM-DD)
        let components = publishedDate.split(separator: "-")
        return components.first.map(String.init)
    }
}

struct ImageLinks: Codable {
    let thumbnail: String?
    let small: String?
    let medium: String?
    let large: String?
    let extraLarge: String?
}

struct IndustryIdentifier: Codable {
    let type: String
    let identifier: String
}

// MARK: - Book Model
struct Book: Identifiable, Codable, Equatable {
    let id: String  // Google Books ID
    let localId: UUID  // Local UUID for linking
    let title: String
    let author: String
    var authors: [String] {
        // Split author string by common separators
        author.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    let publishedYear: String?
    var coverImageURL: String?
    let isbn: String?
    let description: String?
    let pageCount: Int?
    
    // For local storage
    var isInLibrary: Bool = false
    var readingStatus: ReadingStatus = .wantToRead
    var currentPage: Int = 0
    var userRating: Int?
    var userNotes: String?
    var dateAdded: Date = Date()
    
    init(id: String, title: String, author: String, publishedYear: String? = nil, coverImageURL: String? = nil, isbn: String? = nil, description: String? = nil, pageCount: Int? = nil, localId: UUID = UUID()) {
        self.id = id
        self.localId = localId
        self.title = title
        self.author = author
        self.publishedYear = publishedYear
        self.coverImageURL = coverImageURL
        self.isbn = isbn
        self.description = description
        self.pageCount = pageCount
    }
    
    // Custom decoding to handle migration from old model without localId
    enum CodingKeys: String, CodingKey {
        case id, localId, title, author, publishedYear, coverImageURL, isbn, description, pageCount
        case isInLibrary, readingStatus, currentPage, userRating, userNotes, dateAdded
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        // If localId doesn't exist in saved data, generate a new one
        localId = try container.decodeIfPresent(UUID.self, forKey: .localId) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        publishedYear = try container.decodeIfPresent(String.self, forKey: .publishedYear)
        coverImageURL = try container.decodeIfPresent(String.self, forKey: .coverImageURL)
        isbn = try container.decodeIfPresent(String.self, forKey: .isbn)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount)
        
        isInLibrary = try container.decodeIfPresent(Bool.self, forKey: .isInLibrary) ?? false
        readingStatus = try container.decodeIfPresent(ReadingStatus.self, forKey: .readingStatus) ?? .wantToRead
        currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage) ?? 0
        userRating = try container.decodeIfPresent(Int.self, forKey: .userRating)
        userNotes = try container.decodeIfPresent(String.self, forKey: .userNotes)
        dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(localId, forKey: .localId)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encodeIfPresent(publishedYear, forKey: .publishedYear)
        try container.encodeIfPresent(coverImageURL, forKey: .coverImageURL)
        try container.encodeIfPresent(isbn, forKey: .isbn)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(pageCount, forKey: .pageCount)
        
        try container.encode(isInLibrary, forKey: .isInLibrary)
        try container.encode(readingStatus, forKey: .readingStatus)
        try container.encode(currentPage, forKey: .currentPage)
        try container.encodeIfPresent(userRating, forKey: .userRating)
        try container.encodeIfPresent(userNotes, forKey: .userNotes)
        try container.encode(dateAdded, forKey: .dateAdded)
    }
}

// MARK: - Google Books API Service
@MainActor
class GoogleBooksService: ObservableObject {
    private let baseURL = "https://www.googleapis.com/books/v1/volumes"
    private let session = URLSession.shared
    
    @Published var searchResults: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func searchBookByISBN(_ isbn: String) async -> Book? {
        print("GoogleBooksAPI: Searching for ISBN: \(isbn)")
        
        // For ISBN search, we need to use the direct ISBN query without intitle
        // Build URL directly for ISBN search
        guard var components = URLComponents(string: baseURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(isbn)"),
            URLQueryItem(name: "maxResults", value: "1")
        ]
        
        guard let url = components.url else { return nil }
        print("GoogleBooksAPI: ISBN search URL: \(url)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("GoogleBooksAPI: ISBN search failed with status")
                return nil
            }
            
            let decoder = JSONDecoder()
            let googleResponse = try decoder.decode(GoogleBooksResponse.self, from: data)
            
            if let item = googleResponse.items?.first {
                let book = item.book
                print("GoogleBooksAPI: Found book via ISBN: \(book.title)")
                return book
            }
        } catch {
            print("GoogleBooksAPI: ISBN search error: \(error)")
        }
        
        return nil
    }
    
    func searchBooks(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { 
            print("GoogleBooksAPI: Empty query")
            return 
        }
        
        print("GoogleBooksAPI: Starting search for: '\(query)'")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            searchResults = []
        }
        
        do {
            let books = try await performSearch(query: query)
            print("GoogleBooksAPI: Found \(books.count) books")
            
            await MainActor.run {
                searchResults = books
                isLoading = false
            }
        } catch {
            print("GoogleBooksAPI: Search failed with error: \(error)")
            
            await MainActor.run {
                errorMessage = error.localizedDescription
                searchResults = []
                isLoading = false
            }
        }
    }
    
    private func performSearch(query: String) async throws -> [Book] {
        // Clean and encode the query
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        guard cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) != nil else {
            throw APIError.invalidQuery
        }
        
        // Check if this is an ISBN search
        if cleanQuery.lowercased().hasPrefix("isbn:") {
            // Direct ISBN search - use as-is
            return try await performDirectSearch(query: cleanQuery)
        }
        
        // Enhanced search query building with smart interpretation
        var searchQuery = cleanQuery
        
        // Smart query enhancement based on input
        if cleanQuery.lowercased().contains(" by ") {
            // Handle "Title by Author" format
            let parts = cleanQuery.split(separator: " by ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            if parts.count == 2 {
                let title = parts[0].trimmingCharacters(in: .whitespaces)
                let author = parts[1].trimmingCharacters(in: .whitespaces)
                
                // Handle common author abbreviations
                let expandedAuthor = expandAuthorName(author)
                
                // Use intitle and inauthor for precise results
                searchQuery = "intitle:\"\(title)\" inauthor:\"\(expandedAuthor)\""
            }
        } else if cleanQuery.lowercased().contains(" and ") {
            // Handle queries with "and" - might be multiple authors or title with "and"
            // Keep as-is for broader search
            searchQuery = cleanQuery
        } else if cleanQuery.split(separator: " ").count == 1 && cleanQuery.count < 20 {
            // Single word - likely a famous book title
            searchQuery = "intitle:\(cleanQuery)"
        } else if detectsSeriesNumber(in: cleanQuery) {
            // Handle series books (e.g., "Harry Potter 2", "Hunger Games book 1")
            searchQuery = formatSeriesQuery(cleanQuery)
        } else if cleanQuery.count > 100 {
            // Very long query - probably extracted text with noise
            // Try to extract the most important parts
            searchQuery = extractKeyTerms(from: cleanQuery)
        } else {
            // General book title - use quotes for exact matching if short
            if cleanQuery.split(separator: " ").count <= 5 {
                searchQuery = "intitle:\"\(cleanQuery)\""
            } else {
                searchQuery = cleanQuery
            }
        }
        
        // Build URL with parameters
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "maxResults", value: "40"), // Get more results to filter
            URLQueryItem(name: "orderBy", value: "relevance"),
            URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "langRestrict", value: "en")  // English books
        ]
        
        guard let url = components.url else {
            print("GoogleBooksAPI: Invalid URL")
            throw APIError.invalidURL
        }
        
        // Validate the URL for security
        guard URLValidator.isValidAPIURL(url) else {
            print("GoogleBooksAPI: URL validation failed")
            throw APIError.invalidURL
        }
        
        print("GoogleBooksAPI: Making search request to URL: \(url)")
        
        // Perform the request with error handling
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            print("GoogleBooksAPI: Network request failed: \(error)")
            throw APIError.invalidResponse
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        // Parse the response
        let decoder = JSONDecoder()
        let googleResponse = try decoder.decode(GoogleBooksResponse.self, from: data)
        
        // Convert to Book models and filter out books without basic info
        var books: [Book] = googleResponse.items?.compactMap { item in
            let book = item.book
            // Filter out books without title or author
            guard !book.title.isEmpty, !book.author.isEmpty else { return nil }
            
            // Filter out movie companion books and visual companions
            let titleLower = book.title.lowercased()
            let unwantedKeywords = ["visual companion", "movie", "film", "motion picture", "official", "art of", "making of", "screenplay", "script"]
            for keyword in unwantedKeywords {
                if titleLower.contains(keyword) {
                    return nil
                }
            }
            
            return book
        } ?? []
        
        // Improve ranking based on query match
        let queryLower = cleanQuery.lowercased()
        let queryWords = queryLower.split(separator: " ").map(String.init)
        
        // Score and sort results
        books = books.sorted { book1, book2 in
            let score1 = scoreBook(book1, query: queryLower, queryWords: queryWords)
            let score2 = scoreBook(book2, query: queryLower, queryWords: queryWords)
            return score1 > score2
        }
        
        // Take top 20 results after scoring
        return Array(books.prefix(20))
    }
    
    private func scoreBook(_ book: Book, query: String, queryWords: [String]) -> Int {
        var score = 0
        let titleLower = book.title.lowercased()
        let authorLower = book.author.lowercased()
        let queryLower = query.lowercased()
        
        // Remove common noise words from comparison
        let cleanTitle = titleLower
            .replacingOccurrences(of: ": a novel", with: "")
            .replacingOccurrences(of: " (", with: " ")
            .replacingOccurrences(of: ")", with: "")
        
        // Exact title match gets highest score
        if cleanTitle == queryLower || titleLower == queryLower {
            score += 1000
        }
        
        // Title starts with query (very strong signal)
        if titleLower.hasPrefix(queryLower) {
            score += 800
        }
        
        // Title contains exact query
        if titleLower.contains(queryLower) {
            score += 500
        }
        
        // Check for ISBN in query
        if queryLower.hasPrefix("isbn:") {
            // For ISBN searches, exact match is critical
            let isbn = queryLower.replacingOccurrences(of: "isbn:", with: "")
            if let bookISBN = book.isbn, bookISBN == isbn {
                score += 2000 // Highest priority for exact ISBN match
            }
        }
        
        // All query words in title (in order)
        var lastIndex = titleLower.startIndex
        var allWordsInOrder = true
        var wordMatchCount = 0
        for word in queryWords {
            if let range = titleLower.range(of: word, range: lastIndex..<titleLower.endIndex) {
                lastIndex = range.upperBound
                score += 50
                wordMatchCount += 1
            } else if titleLower.contains(word) {
                // Word exists but not in order
                score += 25
                wordMatchCount += 1
                allWordsInOrder = false
            } else {
                allWordsInOrder = false
            }
        }
        
        // Bonus for having all words
        if wordMatchCount == queryWords.count {
            score += 200
        }
        
        if allWordsInOrder && wordMatchCount == queryWords.count {
            score += 300
        }
        
        // Author match for "by" queries
        if queryLower.contains(" by ") {
            let parts = queryLower.split(separator: " by ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let authorQuery = parts[1]
                if authorLower.contains(authorQuery) {
                    score += 400
                }
                if authorLower == authorQuery {
                    score += 200
                }
                
                // Check title match when author is specified
                let titleQuery = parts[0]
                if titleLower.contains(titleQuery) {
                    score += 300
                }
            }
        }
        
        // Penalize titles with unwanted keywords
        let unwantedKeywords = ["study guide", "cliff notes", "sparknotes", "summary", "analysis", 
                              "teacher", "student", "workbook", "companion", "movie", "film"]
        for keyword in unwantedKeywords {
            if titleLower.contains(keyword) {
                score -= 200
            }
        }
        
        // Penalize overly long titles (often compilations or special editions)
        if book.title.count > 80 {
            score -= 100
        } else if book.title.count > 60 {
            score -= 50
        }
        
        // Boost books with cover images
        if book.coverImageURL != nil {
            score += 30
        }
        
        // Boost popular/classic books (those with more pages tend to be full novels)
        if let pageCount = book.pageCount {
            if pageCount > 200 && pageCount < 1000 {
                score += 50
            } else if pageCount >= 100 && pageCount <= 200 {
                score += 25
            }
        }
        
        // Boost books with descriptions (usually means it's a real book)
        if book.description != nil && !book.description!.isEmpty {
            score += 20
        }
        
        return score
    }
    
    // MARK: - Smart Query Helpers
    
    private func expandAuthorName(_ author: String) -> String {
        // Expand common author abbreviations
        var expanded = author
        
        // Handle J.R.R. Tolkien, J.K. Rowling, etc.
        let abbreviations = [
            "jrr": "j.r.r.",
            "jk": "j.k.",
            "cs": "c.s.",
            "hg": "h.g.",
            "pg": "p.g.",
            "rr": "r.r.",
            "grrm": "george r.r. martin",
            "jd": "j.d.",
            "hp": "h.p.",
            "ts": "t.s.",
            "ee": "e.e."
        ]
        
        let lowerAuthor = author.lowercased()
        for (abbr, full) in abbreviations {
            if lowerAuthor == abbr || lowerAuthor.starts(with: abbr + " ") {
                expanded = expanded.replacingOccurrences(of: abbr, with: full, options: .caseInsensitive)
            }
        }
        
        // Handle common name patterns
        if lowerAuthor == "tolkien" {
            return "j.r.r. tolkien"
        } else if lowerAuthor == "rowling" {
            return "j.k. rowling"
        } else if lowerAuthor == "martin" && !lowerAuthor.contains("george") {
            return "george r.r. martin"
        } else if lowerAuthor == "lewis" && !lowerAuthor.contains("c.s.") {
            return "c.s. lewis"
        }
        
        return expanded
    }
    
    private func detectsSeriesNumber(in query: String) -> Bool {
        let patterns = [
            "\\d+$",                    // Ends with number
            "book \\d+",                // "book 1", "book 2"
            "volume \\d+",              // "volume 1"
            "part \\d+",                // "part 1"
            "#\\d+",                    // "#1", "#2"
            "(one|two|three|four|five|six|seven|eight|nine|ten)$"  // Written numbers
        ]
        
        let lower = query.lowercased()
        for pattern in patterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func formatSeriesQuery(_ query: String) -> String {
        // Handle series queries intelligently
        let lower = query.lowercased()
        
        // Extract series name and number
        if let match = lower.range(of: "\\s+(\\d+|book \\d+|#\\d+|part \\d+|volume \\d+)$", options: .regularExpression) {
            let seriesName = String(query[..<match.lowerBound])
            let seriesNumber = String(query[match.lowerBound...]).trimmingCharacters(in: .whitespaces)
            
            // Format for better Google Books results
            return "intitle:\"\(seriesName)\" \(seriesNumber)"
        }
        
        // Handle written numbers
        let numberMap = [
            "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
            "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10"
        ]
        
        for (written, digit) in numberMap {
            if lower.hasSuffix(" \(written)") {
                let seriesName = String(query.dropLast(written.count + 1))
                return "intitle:\"\(seriesName)\" \(digit)"
            }
        }
        
        return "intitle:\(query)"
    }
    
    // New helper function for direct search
    private func performDirectSearch(query: String) async throws -> [Book] {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "40"),
            URLQueryItem(name: "orderBy", value: "relevance"),
            URLQueryItem(name: "printType", value: "books")
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        print("GoogleBooksAPI: Direct search URL: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let googleResponse = try decoder.decode(GoogleBooksResponse.self, from: data)
        
        let books = googleResponse.items?.compactMap { $0.book } ?? []
        return Array(books.prefix(20))
    }
    
    // Extract key terms from long/noisy text
    private func extractKeyTerms(from text: String) -> String {
        // Common words to ignore
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", 
                           "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
                           "have", "has", "had", "do", "does", "did", "will", "would", "could",
                           "should", "may", "might", "must", "can", "introduction", "new", "edition"])
        
        // Split into words and filter
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { word in
                !word.isEmpty && 
                !stopWords.contains(word) &&
                word.count > 2 &&
                !word.contains(where: { $0.isNumber })
            }
        
        // Take the first few significant words
        let keyWords = Array(words.prefix(5))
        
        // If we have an author name pattern (capitalized words), prioritize it
        let capitalizedWords = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.first?.isUppercase == true && $0.count > 2 }
            .prefix(3)
        
        if !capitalizedWords.isEmpty {
            return capitalizedWords.joined(separator: " ")
        }
        
        return keyWords.joined(separator: " ")
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidQuery
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}