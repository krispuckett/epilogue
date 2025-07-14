import Foundation
import SwiftUI

// MARK: - Google Books API Models
struct GoogleBooksResponse: Codable {
    let items: [GoogleBookItem]?
    let totalItems: Int
}

struct GoogleBookItem: Codable, Identifiable {
    let id: String
    let volumeInfo: VolumeInfo
    
    var book: Book {
        // Get the best available image URL
        let imageURL = volumeInfo.imageLinks?.large 
            ?? volumeInfo.imageLinks?.medium 
            ?? volumeInfo.imageLinks?.small 
            ?? volumeInfo.imageLinks?.thumbnail
        
        return Book(
            id: id,
            title: volumeInfo.title,
            author: volumeInfo.authors?.joined(separator: ", ") ?? "Unknown Author",
            publishedYear: volumeInfo.publishedYear,
            coverImageURL: imageURL,
            isbn: volumeInfo.industryIdentifiers?.first { $0.type.contains("ISBN") }?.identifier,
            description: volumeInfo.description,
            pageCount: volumeInfo.pageCount
        )
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
}

struct IndustryIdentifier: Codable {
    let type: String
    let identifier: String
}

// MARK: - Book Model
struct Book: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let publishedYear: String?
    var coverImageURL: String?
    let isbn: String?
    let description: String?
    let pageCount: Int?
    
    // For local storage
    var isInLibrary: Bool = false
    var readingStatus: ReadingStatus = .wantToRead
    var userRating: Int?
    var userNotes: String?
    var dateAdded: Date = Date()
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
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let books = try await performSearch(query: query)
            searchResults = books
        } catch {
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
        
        // Use simple, reliable search - Google Books API works better with plain text
        let searchQuery = cleanQuery
        
        // Build URL with parameters
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "orderBy", value: "relevance"),
            URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "langRestrict", value: "en")  // English books
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
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
        let books: [Book] = googleResponse.items?.compactMap { item in
            let book = item.book
            // Filter out books without title or author
            guard !book.title.isEmpty, !book.author.isEmpty else { return nil }
            
            // Filter out movie companion books and visual companions
            let titleLower = book.title.lowercased()
            let unwantedKeywords = ["visual companion", "movie", "film", "motion picture", "official", "art of", "making of"]
            for keyword in unwantedKeywords {
                if titleLower.contains(keyword) {
                    return nil
                }
            }
            
            return book
        } ?? []
        
        // Trust Google's relevance ranking, just filter out unwanted results
        return books
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