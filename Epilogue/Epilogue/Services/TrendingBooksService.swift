import Foundation
import SwiftUI
import Combine

// MARK: - Trending Books Service
@MainActor
class TrendingBooksService: ObservableObject {
    static let shared = TrendingBooksService()
    
    @Published var trendingBooks: [Book] = []
    @Published var isLoading = false
    @Published var currentFilter: TrendingFilter = .currentYear
    
    enum TrendingFilter: String, CaseIterable {
        case currentYear = "2025 Bestsellers"
        case allTimeFiction = "Classic Fiction"
        case allTimeNonFiction = "Essential Non-Fiction"
        case lastYear = "2024 Favorites"
        
        var icon: String {
            switch self {
            case .currentYear: return "flame.fill"
            case .allTimeFiction: return "book.fill"
            case .allTimeNonFiction: return "text.book.closed.fill"
            case .lastYear: return "clock.arrow.circlepath"
            }
        }
    }
    
    // MARK: - Current Year Bestsellers
    private let currentYearBestsellers = [
        "Fourth Wing Rebecca Yarros",
        "Holly Stephen King",
        "Tom Lake Ann Patchett",
        "The Woman in Me Britney Spears",
        "The Heaven & Earth Grocery Store James McBride",
        "The Exchange John Grisham"
    ]
    
    // MARK: - All-Time Fiction Classics
    private let allTimeFictionClassics = [
        "To Kill a Mockingbird Harper Lee",
        "1984 George Orwell",
        "Pride and Prejudice Jane Austen",
        "The Great Gatsby F. Scott Fitzgerald",
        "One Hundred Years of Solitude Gabriel García Márquez",
        "Brave New World Aldous Huxley"
    ]
    
    // MARK: - All-Time Non-Fiction Essentials
    private let allTimeNonFictionEssentials = [
        "Sapiens Yuval Noah Harari",
        "Thinking, Fast and Slow Daniel Kahneman",
        "The Power of Habit Charles Duhigg",
        "Educated Tara Westover",
        "Becoming Michelle Obama",
        "Atomic Habits James Clear"
    ]
    
    // MARK: - Last Year's Favorites
    private let lastYearFavorites = [
        "The Wager David Grann",
        "The Creative Act Rick Rubin",
        "Spare Prince Harry",
        "The Light We Carry Michelle Obama",
        "I'm Glad My Mom Died Jennette McCurdy",
        "The Body Keeps the Score Bessel van der Kolk"
    ]
    
    // MARK: - Fetch Trending Books
    func fetchTrendingBooks(for filter: TrendingFilter) async {
        isLoading = true
        currentFilter = filter
        
        let searchQueries: [String]
        
        switch filter {
        case .currentYear:
            searchQueries = currentYearBestsellers
        case .allTimeFiction:
            searchQueries = allTimeFictionClassics
        case .allTimeNonFiction:
            searchQueries = allTimeNonFictionEssentials
        case .lastYear:
            searchQueries = lastYearFavorites
        }
        
        var books: [Book] = []
        
        // Fetch books from Google Books API
        await withTaskGroup(of: Book?.self) { group in
            for query in searchQueries.prefix(6) { // Limit to 6 for the grid
                group.addTask {
                    await self.searchGoogleBooks(query: query)
                }
            }
            
            for await book in group {
                if let book = book {
                    books.append(book)
                }
            }
        }
        
        // Sort by the original order to maintain curated list
        let orderedBooks = searchQueries.prefix(6).compactMap { query in
            books.first { book in
                let searchTerms = query.lowercased().components(separatedBy: " ")
                let bookInfo = "\(book.title) \(book.author)".lowercased()
                return searchTerms.allSatisfy { bookInfo.contains($0) }
            }
        }
        
        await MainActor.run {
            self.trendingBooks = orderedBooks
            self.isLoading = false
        }
    }
    
    // MARK: - Google Books API Search
    private func searchGoogleBooks(query: String) async -> Book? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=\(encodedQuery)&maxResults=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
            
            guard let item = response.items?.first else { return nil }
            
            // Convert GoogleBookItem to Book
            return item.book
            
        } catch {
            #if DEBUG
            print("Error fetching book: \(error)")
            #endif
            return nil
        }
    }
}