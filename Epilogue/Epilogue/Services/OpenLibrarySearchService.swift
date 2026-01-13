import Foundation
import os.log

/// Service for searching books via Open Library API
/// Used as a fallback when Google Books returns no relevant results
@MainActor
class OpenLibrarySearchService {
    static let shared = OpenLibrarySearchService()

    private init() {}

    // MARK: - Search

    /// Search Open Library for books matching the query
    /// - Parameters:
    ///   - query: Search query (title, author, or both)
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of Book objects matching the query
    func searchBooks(query: String, limit: Int = 20) async -> [Book] {
        guard !query.isEmpty else { return [] }

        // Build search URL
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "fields", value: "key,title,author_name,first_publish_year,isbn,cover_i,number_of_pages_median,subject")
        ]

        guard let url = components?.url else {
            os_log(.error, "OpenLibrary: Failed to build search URL")
            return []
        }

        #if DEBUG
        print("📚 OpenLibrary: Searching for '\(query)'")
        #endif

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                os_log(.error, "OpenLibrary: Bad response status")
                return []
            }

            let searchResponse = try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data)

            #if DEBUG
            print("📚 OpenLibrary: Found \(searchResponse.numFound) total results, returning \(searchResponse.docs.count)")
            #endif

            // Map results to Book objects, filtering out those without covers
            let books = searchResponse.docs.compactMap { mapToBook($0) }

            #if DEBUG
            print("📚 OpenLibrary: Mapped \(books.count) books with covers")
            #endif

            return books

        } catch {
            os_log(.error, "OpenLibrary: Search error - %@", error.localizedDescription)
            return []
        }
    }

    // MARK: - Mapping

    /// Map Open Library document to Book struct
    private func mapToBook(_ doc: OpenLibraryDoc) -> Book? {
        // Require a cover image for quality results
        guard let coverId = doc.cover_i else {
            return nil
        }

        // Build cover URL (L = large)
        let coverURL = "https://covers.openlibrary.org/b/id/\(coverId)-L.jpg"

        // Extract first ISBN if available
        let isbn = doc.isbn?.first

        // Build author string
        let author = doc.author_name?.joined(separator: ", ") ?? "Unknown Author"

        // Use Open Library key as ID (e.g., "/works/OL12345W")
        // Prefix with "ol:" to distinguish from Google Books IDs
        let id = "ol:\(doc.key.replacingOccurrences(of: "/works/", with: ""))"

        return Book(
            id: id,
            title: doc.title,
            author: author,
            publishedYear: doc.first_publish_year.map { String($0) },
            coverImageURL: coverURL,
            isbn: isbn,
            description: nil, // Open Library search doesn't include description
            pageCount: doc.number_of_pages_median
        )
    }
}

// MARK: - Open Library Response Models

struct OpenLibrarySearchResponse: Codable {
    let numFound: Int
    let docs: [OpenLibraryDoc]
}

struct OpenLibraryDoc: Codable {
    let key: String // e.g., "/works/OL12345W"
    let title: String
    let author_name: [String]?
    let first_publish_year: Int?
    let isbn: [String]?
    let cover_i: Int? // Cover ID for building cover URL
    let number_of_pages_median: Int?
    let subject: [String]?
}
