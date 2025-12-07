import Foundation
import UIKit

// MARK: - Preset Bookstores

/// Available preset bookstore options
enum PresetBookstore: String, CaseIterable, Identifiable {
    case amazon = "Amazon"
    case bookshop = "Bookshop.org"
    case barnesNoble = "Barnes & Noble"
    case appleBooks = "Apple Books"
    case kobo = "Kobo"
    case librofm = "Libro.fm"
    case thriftbooks = "ThriftBooks"
    case betterWorldBooks = "Better World Books"
    case custom = "Custom"

    var id: String { rawValue }

    /// Description shown in settings
    var subtitle: String {
        switch self {
        case .amazon: return "World's largest online bookstore"
        case .bookshop: return "Supports local independent bookstores"
        case .barnesNoble: return "Major US book retailer"
        case .appleBooks: return "Apple's digital bookstore"
        case .kobo: return "eBooks and audiobooks"
        case .librofm: return "Audiobooks supporting indie stores"
        case .thriftbooks: return "Affordable used books"
        case .betterWorldBooks: return "Used books, free shipping, donates to literacy"
        case .custom: return "Use your own bookstore URL"
        }
    }

    /// SF Symbol icon for the bookstore
    var icon: String {
        switch self {
        case .amazon: return "cart"
        case .bookshop: return "building.columns"
        case .barnesNoble: return "book"
        case .appleBooks: return "apple.logo"
        case .kobo: return "ipad"
        case .librofm: return "headphones"
        case .thriftbooks: return "leaf"
        case .betterWorldBooks: return "globe.americas"
        case .custom: return "link"
        }
    }

    /// URL template for ISBN-based lookup (nil if not supported)
    var isbnTemplate: String? {
        switch self {
        case .amazon: return "https://www.amazon.com/dp/{isbn}"
        case .bookshop: return "https://bookshop.org/book/{isbn}"
        case .barnesNoble: return "https://www.barnesandnoble.com/w/?ean={isbn}"
        case .appleBooks: return nil  // Apple Books doesn't support direct ISBN links
        case .kobo: return "https://www.kobo.com/search?query={isbn}"
        case .librofm: return "https://libro.fm/search?q={isbn}"
        case .thriftbooks: return "https://www.thriftbooks.com/browse/?b.search={isbn}"
        case .betterWorldBooks: return "https://www.betterworldbooks.com/search/results?q={isbn}"
        case .custom: return nil  // User provides their own
        }
    }

    /// URL template for search-based lookup
    var searchTemplate: String {
        switch self {
        case .amazon: return "https://www.amazon.com/s?k={query}&i=stripbooks"
        case .bookshop: return "https://bookshop.org/search?keywords={query}"
        case .barnesNoble: return "https://www.barnesandnoble.com/s/{query}"
        case .appleBooks: return "https://books.apple.com/us/search?term={query}"
        case .kobo: return "https://www.kobo.com/search?query={query}"
        case .librofm: return "https://libro.fm/search?q={query}"
        case .thriftbooks: return "https://www.thriftbooks.com/browse/?b.search={query}"
        case .betterWorldBooks: return "https://www.betterworldbooks.com/search/results?q={query}"
        case .custom: return ""  // User provides their own
        }
    }
}

// MARK: - Bookstore URL Builder

/// Builds bookstore URLs based on user preference
final class BookstoreURLBuilder {
    static let shared = BookstoreURLBuilder()

    private let defaults = UserDefaults.standard

    // UserDefaults keys
    private let bookstoreKey = "preferredBookstore"
    private let customURLKey = "customBookstoreURL"

    private init() {}

    // MARK: - Preference Management

    /// Get the user's preferred bookstore
    var preferredBookstore: PresetBookstore {
        get {
            guard let rawValue = defaults.string(forKey: bookstoreKey),
                  let bookstore = PresetBookstore(rawValue: rawValue) else {
                return .amazon  // Default to Amazon
            }
            return bookstore
        }
        set {
            defaults.set(newValue.rawValue, forKey: bookstoreKey)
        }
    }

    /// Get/set custom URL template (for custom bookstore option)
    /// Should contain {query} placeholder, optionally {title}, {author}, {isbn}
    var customURLTemplate: String {
        get {
            defaults.string(forKey: customURLKey) ?? ""
        }
        set {
            defaults.set(newValue, forKey: customURLKey)
        }
    }

    // MARK: - URL Generation

    /// Build a bookstore URL for a book
    /// - Parameters:
    ///   - title: Book title
    ///   - author: Book author
    ///   - isbn: ISBN (optional, preferred if available)
    /// - Returns: URL string to the bookstore page for this book
    func buildURL(title: String, author: String, isbn: String? = nil) -> String {
        let bookstore = preferredBookstore

        // For custom bookstore, use user's template
        if bookstore == .custom {
            return buildCustomURL(title: title, author: author, isbn: isbn)
        }

        // Try ISBN-based URL first if available
        if let isbn = isbn, !isbn.isEmpty, let isbnTemplate = bookstore.isbnTemplate {
            return isbnTemplate.replacingOccurrences(of: "{isbn}", with: isbn)
        }

        // Fall back to search URL
        let query = "\(title) \(author)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        return bookstore.searchTemplate.replacingOccurrences(of: "{query}", with: query)
    }

    /// Build URL from custom template
    private func buildCustomURL(title: String, author: String, isbn: String?) -> String {
        var url = customURLTemplate

        // Replace placeholders
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedAuthor = author.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedQuery = "\(title) \(author)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        url = url.replacingOccurrences(of: "{title}", with: encodedTitle)
        url = url.replacingOccurrences(of: "{author}", with: encodedAuthor)
        url = url.replacingOccurrences(of: "{query}", with: encodedQuery)

        if let isbn = isbn {
            url = url.replacingOccurrences(of: "{isbn}", with: isbn)
        }

        return url
    }

    /// Build URL directly from a URL object (convenience)
    func buildURL(for book: Book) -> String {
        buildURL(title: book.title, author: book.author, isbn: book.isbn)
    }
}

// MARK: - URL Extension for Opening

extension BookstoreURLBuilder {
    /// Open the bookstore URL in Safari
    func openBookstore(title: String, author: String, isbn: String? = nil) {
        let urlString = buildURL(title: title, author: author, isbn: isbn)
        guard let url = URL(string: urlString) else { return }

        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}
