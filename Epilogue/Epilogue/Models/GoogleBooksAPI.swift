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

enum ReadingStatus: String, CaseIterable, Codable {
    case wantToRead = "Want to Read"
    case currentlyReading = "Currently Reading"
    case finished = "Finished"
}

// MARK: - Google Books API Service
@MainActor
class GoogleBooksService: ObservableObject {
    private let baseURL = "https://www.googleapis.com/books/v1/volumes"
    private let session = URLSession.shared
    
    @Published var searchResults: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func searchBooks(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { 
            print("GoogleBooksAPI: Empty query")
            return 
        }
        
        print("GoogleBooksAPI: Starting search for: '\(query)'")
        isLoading = true
        errorMessage = nil
        
        do {
            let books = try await performSearch(query: query)
            print("GoogleBooksAPI: Found \(books.count) books")
            searchResults = books
        } catch {
            print("GoogleBooksAPI: Error - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            searchResults = []
        }
        
        isLoading = false
    }
    
    private func performSearch(query: String) async throws -> [Book] {
        // Clean and encode the query
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        guard cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) != nil else {
            throw APIError.invalidQuery
        }
        
        // Enhanced search query building
        var searchQuery = cleanQuery
        
        // If query contains "by", format it properly for Google Books
        if cleanQuery.lowercased().contains(" by ") {
            let parts = cleanQuery.split(separator: " by ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            if parts.count == 2 {
                // Use intitle and inauthor for more precise results
                searchQuery = "intitle:\(parts[0]) inauthor:\(parts[1])"
            }
        } else {
            // For single terms or titles without author, use intitle for better results
            searchQuery = "intitle:\(cleanQuery)"
        }
        
        // Build URL with parameters
        var components = URLComponents(string: baseURL)!
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
        
        print("GoogleBooksAPI: Making request to: \(url.absoluteString)")
        
        // Perform the request
        let (data, response) = try await session.data(from: url)
        
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
        
        // Exact title match gets highest score
        if titleLower == query {
            score += 1000
        }
        
        // Title starts with query
        if titleLower.hasPrefix(query) {
            score += 500
        }
        
        // Title contains exact query
        if titleLower.contains(query) {
            score += 300
        }
        
        // All query words in title (in order)
        var lastIndex = titleLower.startIndex
        var allWordsInOrder = true
        for word in queryWords {
            if let range = titleLower.range(of: word, range: lastIndex..<titleLower.endIndex) {
                lastIndex = range.upperBound
                score += 50
            } else {
                allWordsInOrder = false
            }
        }
        if allWordsInOrder {
            score += 200
        }
        
        // Author match for "by" queries
        if query.contains(" by ") {
            let parts = query.split(separator: " by ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let authorQuery = parts[1]
                if authorLower.contains(authorQuery) {
                    score += 300
                }
                if authorLower.hasPrefix(authorQuery) {
                    score += 100
                }
            }
        }
        
        // Penalize overly long titles (often compilations or special editions)
        if book.title.count > 50 {
            score -= 50
        }
        
        // Boost popular/classic books (those with more pages tend to be full novels)
        if let pageCount = book.pageCount, pageCount > 200 {
            score += 20
        }
        
        return score
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