import Foundation
import SwiftUI
import Combine
import SwiftData
import BackgroundTasks
import OSLog

// MARK: - Enhanced Trending Books Service
@MainActor
final class EnhancedTrendingBooksService: ObservableObject {
    static let shared = EnhancedTrendingBooksService()
    
    private let logger = Logger(subsystem: "com.epilogue.app", category: "TrendingBooks")
    private let perplexitySearch = PerplexitySearchService.shared
    private let googleBooksService = EnhancedGoogleBooksService()
    
    // Known book covers that often fail from Google Books
    private let knownBookCovers: [String: String] = [
        "onyx storm": "9781649376695",
        "just for the summer": "9781538704431",
        "the god of the woods": "9780593715925",
        "the women": "9781250178633",
        "funny story": "9780593441282",
        "the housemaid": "9781538742570",
        "fourth wing": "9781649374615",
        "holly stephen king": "9781668016138",
        "icebreaker": "9781668026038",
        "the love hypothesis": "9780593336823",
        "beach read": "9781984806734",
        "happy place": "9780593441275",
        "it ends with us": "9781501110368",
        "the seven husbands of evelyn hugo": "9781501161933",
        "the spanish love deception": "9781668002520",
        "the midnight library": "9780525559474",
        "atomic habits": "9780735211292",
        "the body keeps the score": "9780143127741",
        "spare prince harry": "9780593593806",
        "the wager": "9780385534260",
        "the creative act": "9780593652886",
        "the light we carry": "9780593237465"
    ]
    
    @Published var trendingCategories: [TrendingCategory] = []
    @Published var isLoading = false
    @Published var selectedCategory: TrendingCategory.CategoryType = .nytFiction
    @Published var lastUpdateTime: Date?
    
    // Background task identifier
    static let refreshTaskIdentifier = "com.epilogue.trending.refresh"
    
    // Cache duration
    private let cacheDuration: TimeInterval = 14 * 24 * 60 * 60 // 14 days
    
    private init() {
        loadCachedCategories()
        registerBackgroundTasks()
        
        // Load only the selected category on startup
        Task {
            // Check if we have cached data for the selected category
            let hasSelectedCategory = trendingCategories.contains { $0.type == selectedCategory }
            if !hasSelectedCategory || needsRefresh {
                await refreshTrendingBooks(for: selectedCategory)
            }
        }
    }
    
    // MARK: - Trending Category Model
    struct TrendingCategory: Identifiable {
        let id = UUID()
        let type: CategoryType
        let books: [Book]
        let lastUpdated: Date
        let sourceDescription: String?
        
        enum CategoryType: String, CaseIterable, Codable {
            case nytFiction = "NYT Fiction"
            case nytNonfiction = "NYT Nonfiction"
            case amazonTop = "Amazon Top Books"
            case goodreadsChoice = "Goodreads Choice"
            case bookTok = "BookTok Trending"
            case seasonal = "Seasonal Picks"
            
            var icon: String {
                switch self {
                case .nytFiction, .nytNonfiction: return "newspaper.fill"
                case .amazonTop: return "cart.fill"
                case .goodreadsChoice: return "star.fill"
                case .bookTok: return "play.rectangle.fill"
                case .seasonal: return "calendar"
                }
            }
            
            var searchQuery: String {
                switch self {
                case .nytFiction:
                    return "New York Times bestseller fiction current week \(Calendar.current.component(.year, from: Date()))"
                case .nytNonfiction:
                    return "New York Times bestseller nonfiction current week \(Calendar.current.component(.year, from: Date()))"
                case .amazonTop:
                    return "Amazon best selling books current month \(Date().formatted(.dateTime.month(.wide))) \(Calendar.current.component(.year, from: Date()))"
                case .goodreadsChoice:
                    return "Goodreads Choice Awards winners \(Calendar.current.component(.year, from: Date())) popular books"
                case .bookTok:
                    return "BookTok trending viral books TikTok recommendations current"
                case .seasonal:
                    return seasonalSearchQuery()
                }
            }
            
            private func seasonalSearchQuery() -> String {
                let month = Calendar.current.component(.month, from: Date())
                let year = Calendar.current.component(.year, from: Date())
                
                switch month {
                case 12, 1, 2:
                    return "best winter reading cozy books fireplace \(year)"
                case 3, 4, 5:
                    return "spring reading list new releases \(year)"
                case 6, 7, 8:
                    return "beach reads summer books vacation \(year)"
                case 9, 10, 11:
                    return "fall reading thriller mystery books \(year)"
                default:
                    return "trending books \(year)"
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func refreshTrendingBooks(for category: TrendingCategory.CategoryType? = nil) async {
        logger.info("Starting trending books refresh for: \(category?.rawValue ?? "all categories")")
        isLoading = true
        
        let categoriesToRefresh = category != nil ? [category!] : TrendingCategory.CategoryType.allCases
        var newCategories: [TrendingCategory] = []
        
        for categoryType in categoriesToRefresh {
            if let trendingCategory = await fetchTrendingCategory(categoryType) {
                newCategories.append(trendingCategory)
                logger.info("Successfully fetched \(trendingCategory.books.count) books for \(categoryType.rawValue)")
            } else {
                logger.error("Failed to fetch trending category: \(categoryType.rawValue)")
                // Use fallback books when API fails
                if let fallbackCategory = await fetchFallbackTrendingCategory(categoryType) {
                    newCategories.append(fallbackCategory)
                    logger.info("Using fallback books for \(categoryType.rawValue)")
                }
            }
        }
        
        // Update or merge with existing categories
        if category != nil {
            // Single category update - ensure we update the right category
            var updatedCategories = trendingCategories.filter { $0.type != category }
            updatedCategories.append(contentsOf: newCategories)
            trendingCategories = updatedCategories
        } else {
            // Full refresh
            trendingCategories = newCategories
        }
        
        isLoading = false
        lastUpdateTime = Date()
        logger.info("Trending books refresh complete. Total categories: \(self.trendingCategories.count)")
        
        // Save to cache
        await saveCachedCategories()
    }
    
    func getBooksForCurrentCategory() -> [Book] {
        let books = trendingCategories.first { $0.type == selectedCategory }?.books ?? []
        logger.info("Getting books for \(self.selectedCategory.rawValue): \(books.count) books found")
        if !books.isEmpty {
            logger.info("Books: \(books.map { $0.title }.joined(separator: ", "))")
        }
        return books
    }
    
    /// Clear all cached categories - useful for debugging
    func clearCache() {
        logger.info("Clearing all cached trending categories")
        UserDefaults.standard.removeObject(forKey: "CachedTrendingCategories")
        trendingCategories = []
    }
    
    // MARK: - Private Methods
    
    private func fetchTrendingCategory(_ type: TrendingCategory.CategoryType) async -> TrendingCategory? {
        logger.info("Fetching trending books for category: \(type.rawValue)")
        
        // Get model context for caching
        guard let modelContext = try? ModelContainer(for: CachedSearchResult.self).mainContext else {
            logger.error("Failed to create model context for trending books")
            return nil
        }
        
        var bookQueries: [String] = []
        
        // Try Perplexity search if API key is configured
        if UserDefaults.standard.string(forKey: "perplexityAPIKey") != nil {
            do {
                // Search using Perplexity with trusted book domains
                let searchResults = try await perplexitySearch.searchBooks(
                    query: type.searchQuery,
                    additionalDomains: getAdditionalDomains(for: type),
                    modelContext: modelContext
                )
                
                // Extract book title/author pairs from search results
                bookQueries = extractBookQueries(from: searchResults, limit: 6)
            } catch {
                logger.warning("Perplexity search failed: \(error.localizedDescription)")
            }
        } else {
            logger.info("No Perplexity API key configured, using fallback queries")
        }
        
        logger.info("Extracted \(bookQueries.count) book queries from search results")
        
        // Fallback to predefined queries if search didn't return enough results
        if bookQueries.isEmpty {
            // If no queries from search, use all fallback queries
            bookQueries = getFallbackQueries(for: type)
            logger.info("Using all \(bookQueries.count) fallback queries for \(type.rawValue)")
        } else if bookQueries.count < 6 {
            // Add more fallback queries to reach 6 total
            let fallbacks = getFallbackQueries(for: type)
            let needed = min(6 - bookQueries.count, fallbacks.count)
            bookQueries.append(contentsOf: fallbacks.prefix(needed))
            logger.info("Added \(needed) fallback queries. Total: \(bookQueries.count)")
        }
        
        // Fetch book details from Google Books
        var books: [Book] = []
        
        await withTaskGroup(of: Book?.self) { group in
            for query in bookQueries {
                group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        
                        self.logger.info("🔍 Searching for: \(query)")
                        
                        // Check if this is a known problematic book
                        let queryLower = query.lowercased()
                        var preferredISBN: String? = nil
                        for (bookTitle, isbn) in self.knownBookCovers {
                            if queryLower.contains(bookTitle) {
                                preferredISBN = isbn
                                self.logger.info("🎯 Using known ISBN \(isbn) for: \(query)")
                                break
                            }
                        }
                        
                        // Use enhanced service for better results
                        let searchResults = await self.googleBooksService.searchBooksWithRanking(
                            query: query,
                            preferISBN: preferredISBN
                        )
                        
                        self.logger.info("📚 Found \(searchResults.count) results for: \(query)")
                        
                        // Pick the first result with a valid cover
                        for (index, book) in searchResults.prefix(3).enumerated() {
                            self.logger.info("   [\(index)] \(book.title) - Initial Cover: \(book.coverImageURL ?? "none")")
                            
                            // Just verify we have a valid book
                            if !book.id.isEmpty {
                                var updatedBook = book
                                
                                // Always use DisplayCoverURLResolver to get the best URL
                                // This is what GoodreadsCleanImporter does
                                if let resolvedURL = await DisplayCoverURLResolver.resolveDisplayURL(
                                    googleID: book.id,
                                    isbn: book.isbn,
                                    thumbnailURL: book.coverImageURL
                                ) {
                                    updatedBook.coverImageURL = resolvedURL
                                    self.logger.info("✅ Resolved cover URL for \(book.title): \(resolvedURL)")
                                    return updatedBook
                                } else {
                                    self.logger.warning("⚠️ Could not resolve display URL for: \(book.title)")
                                    // Still return the book even without a cover
                                    return updatedBook
                                }
                            }
                        }
                        
                        // If no good cover found, try using the first result and get fallback cover
                        if var firstBook = searchResults.first {
                            self.logger.warning("⚠️ No good cover found in Google Books for: \(query)")
                            
                            // Try Open Library fallback
                            if let fallbackURL = await BookCoverFallbackService.shared.getFallbackCoverURL(for: firstBook) {
                                firstBook.coverImageURL = fallbackURL
                                self.logger.info("✅ Found fallback cover from Open Library")
                            }
                            
                            return firstBook
                        }
                        
                        return nil
                    }
                }
                
                for await book in group {
                    if let book = book {
                        books.append(book)
                    }
                }
            }
            
            // Filter out books without essential info
            books = books.filter { book in
                !book.title.isEmpty && !book.author.isEmpty
            }
            
        return TrendingCategory(
            type: type,
            books: Array(books.prefix(6)), // Limit to 6 for grid
            lastUpdated: Date(),
            sourceDescription: nil
        )
    }
    
    private func extractBookQueries(from searchResults: [SearchResult], limit: Int) -> [String] {
        var queries: [String] = []
        
        for result in searchResults {
            // Extract book titles and authors from snippets and titles
            let text = "\(result.title) \(result.snippet)"
            
            // Common patterns in book listings
            let patterns = [
                // "Title" by Author
                "\"([^\"]+)\"\\s+by\\s+([A-Za-z\\s\\.]+)",
                // Title by Author (without quotes)
                "([A-Z][^by]+)\\s+by\\s+([A-Za-z\\s\\.]+)",
                // 1. Title - Author
                "\\d+\\.\\s*([^-]+)\\s*-\\s*([A-Za-z\\s\\.]+)",
                // Author, Title
                "([A-Za-z\\s\\.]+),\\s*([^,]+)"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    
                    for match in matches {
                        if match.numberOfRanges >= 3,
                           let titleRange = Range(match.range(at: 1), in: text),
                           let authorRange = Range(match.range(at: 2), in: text) {
                            
                            let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            let author = String(text[authorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Clean up common artifacts
                            let cleanTitle = title
                                .replacingOccurrences(of: "...", with: "")
                                .replacingOccurrences(of: "—", with: "")
                                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                            
                            let cleanAuthor = author
                                .replacingOccurrences(of: "...", with: "")
                                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                            
                            if !cleanTitle.isEmpty && !cleanAuthor.isEmpty {
                                queries.append("\(cleanTitle) \(cleanAuthor)")
                                
                                if queries.count >= limit {
                                    return queries
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return queries
    }
    
    private func getAdditionalDomains(for type: TrendingCategory.CategoryType) -> [String] {
        switch type {
        case .nytFiction, .nytNonfiction:
            return ["nytimes.com/books/best-sellers"]
        case .amazonTop:
            return ["amazon.com/charts"]
        case .goodreadsChoice:
            return ["goodreads.com/choiceawards"]
        case .bookTok:
            return ["booktok.com", "tiktok.com", "buzzfeed.com/books"]
        case .seasonal:
            return ["oprahdaily.com", "bookbub.com", "epicreads.com"]
        }
    }
    
    private func fetchFallbackBooksForCategory(_ type: TrendingCategory.CategoryType) async -> [Book] {
        logger.info("Fetching fallback books for category: \(type.rawValue)")
        
        let queries = getFallbackQueries(for: type)
        var books: [Book] = []
        
        await withTaskGroup(of: Book?.self) { group in
            for query in queries.prefix(6) {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    
                    self.logger.info("🔍 Searching fallback: \(query)")
                    
                    // Check if this is a known problematic book
                    let queryLower = query.lowercased()
                    var preferredISBN: String? = nil
                    for (bookTitle, isbn) in self.knownBookCovers {
                        if queryLower.contains(bookTitle) {
                            preferredISBN = isbn
                            break
                        }
                    }
                    
                    // Use enhanced service for better results
                    let searchResults = await self.googleBooksService.searchBooksWithRanking(
                        query: query,
                        preferISBN: preferredISBN
                    )
                    
                    // Pick the first result with resolved cover
                    for book in searchResults.prefix(3) {
                        var updatedBook = book
                        
                        // Always use DisplayCoverURLResolver
                        if let resolvedURL = await DisplayCoverURLResolver.resolveDisplayURL(
                            googleID: book.id,
                            isbn: book.isbn,
                            thumbnailURL: book.coverImageURL
                        ) {
                            updatedBook.coverImageURL = resolvedURL
                            return updatedBook
                        }
                    }
                    
                    // Return first result even without cover
                    return searchResults.first
                }
            }
            
            for await book in group {
                if let book = book {
                    books.append(book)
                }
            }
        }
        
        return books
    }
    
    private func getFallbackQueries(for type: TrendingCategory.CategoryType) -> [String] {
        switch type {
        case .nytFiction:
            return [
                "Fourth Wing Rebecca Yarros",
                "Holly Stephen King", 
                "The Woman in Me Britney Spears",
                "The Heaven & Earth Grocery Store James McBride",
                "The Exchange John Grisham",
                "Tom Lake Ann Patchett"
            ]
        case .nytNonfiction:
            return [
                "The Wager David Grann",
                "The Creative Act Rick Rubin",
                "Spare Prince Harry",
                "The Light We Carry Michelle Obama",
                "Atomic Habits James Clear",
                "The Body Keeps the Score Bessel van der Kolk"
            ]
        case .amazonTop:
            return [
                "Onyx Storm Rebecca Yarros",
                "The Women Kristin Hannah",
                "Funny Story Emily Henry",
                "The Housemaid Freida McFadden",
                "Just for the Summer Abby Jimenez",
                "The God of the Woods Liz Moore"
            ]
        case .goodreadsChoice:
            return [
                "Happy Place Emily Henry",
                "The Rachel Incident Caroline O'Donoghue",
                "Holly Stephen King",
                "Fourth Wing Rebecca Yarros",
                "The Woman in Me Britney Spears",
                "Tom Lake Ann Patchett"
            ]
        case .bookTok:
            return [
                "Icebreaker Hannah Grace",
                "The Love Hypothesis Ali Hazelwood",
                "It Ends with Us Colleen Hoover",
                "The Seven Husbands of Evelyn Hugo Taylor Jenkins Reid",
                "The Spanish Love Deception Elena Armas",
                "Beach Read Emily Henry"
            ]
        case .seasonal:
            let month = Calendar.current.component(.month, from: Date())
            switch month {
            case 12, 1, 2: // Winter
                return [
                    "The Midnight Library Matt Haig",
                    "The Snow Child Eowyn Ivey",
                    "Winter Garden Kristin Hannah",
                    "The Bear and the Nightingale Katherine Arden",
                    "The Lion the Witch and the Wardrobe C.S. Lewis",
                    "The Book Thief Markus Zusak"
                ]
            case 6, 7, 8: // Summer
                return [
                    "Beach Read Emily Henry",
                    "The Summer I Turned Pretty Jenny Han",
                    "The Seven Husbands of Evelyn Hugo Taylor Jenkins Reid",
                    "People We Meet on Vacation Emily Henry",
                    "Malibu Rising Taylor Jenkins Reid",
                    "Summer Sisters Judy Blume"
                ]
            default: // Spring/Fall
                return [
                    "The Secret History Donna Tartt",
                    "Where the Crawdads Sing Delia Owens",
                    "The Night Circus Erin Morgenstern",
                    "All the Light We Cannot See Anthony Doerr",
                    "The Great Gatsby F. Scott Fitzgerald",
                    "Pride and Prejudice Jane Austen"
                ]
            }
        }
    }
    
    // MARK: - Fallback Method
    
    private func fetchFallbackTrendingCategory(_ type: TrendingCategory.CategoryType) async -> TrendingCategory? {
        logger.info("Fetching fallback books for category: \(type.rawValue)")
        
        let fallbackQueries = getFallbackQueries(for: type)
        var books: [Book] = []
        
        // Search for each fallback book
        await withTaskGroup(of: Book?.self) { group in
            for query in fallbackQueries.prefix(6) {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    
                    // Check if this is a known book
                    let queryLower = query.lowercased()
                    var preferredISBN: String? = nil
                    for (bookTitle, isbn) in self.knownBookCovers {
                        if queryLower.contains(bookTitle) {
                            preferredISBN = isbn
                            self.logger.info("Using known ISBN \(isbn) for fallback: \(query)")
                            break
                        }
                    }
                    
                    // Search with enhanced service
                    let searchResults = await self.googleBooksService.searchBooksWithRanking(
                        query: query,
                        preferISBN: preferredISBN
                    )
                    
                    // Get first result with resolved cover
                    for book in searchResults.prefix(3) {
                        var updatedBook = book
                        
                        // Always use DisplayCoverURLResolver
                        if let resolvedURL = await DisplayCoverURLResolver.resolveDisplayURL(
                            googleID: book.id,
                            isbn: preferredISBN ?? book.isbn,
                            thumbnailURL: book.coverImageURL
                        ) {
                            updatedBook.coverImageURL = resolvedURL
                            self.logger.info("Resolved fallback cover for \(book.title): \(resolvedURL)")
                            return updatedBook
                        }
                    }
                    
                    // Try first book even without cover
                    if let firstBook = searchResults.first {
                        self.logger.warning("Using book without resolved cover: \(firstBook.title)")
                        return firstBook
                    }
                    return nil
                }
            }
            
            for await book in group {
                if let book = book {
                    books.append(book)
                }
            }
        }
        
        guard !books.isEmpty else {
            logger.error("No fallback books found for \(type.rawValue)")
            return nil
        }
        
        logger.info("Created fallback category \(type.rawValue) with \(books.count) books")
        return TrendingCategory(
            type: type,
            books: Array(books.prefix(6)),
            lastUpdated: Date(),
            sourceDescription: "Curated selection"
        )
    }
    
    // MARK: - Background Task Management
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60) // 7 days
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled background refresh for trending books")
        } catch {
            logger.error("Failed to schedule background refresh: \(error)")
        }
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleBackgroundRefresh()
        
        // Don't refresh if user is actively reading
        // Check if there's an active ambient session
        let isActivelyReading = UserDefaults.standard.bool(forKey: "isInAmbientMode")
        if isActivelyReading {
            task.setTaskCompleted(success: true)
            return
        }
        
        Task {
            await refreshTrendingBooks()
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Caching
    
    private func loadCachedCategories() {
        guard let data = UserDefaults.standard.data(forKey: "CachedTrendingCategories"),
              let decoded = try? JSONDecoder().decode([CachedTrendingData].self, from: data) else {
            logger.info("No cached trending categories found")
            return
        }
        
        let now = Date()
        trendingCategories = decoded.compactMap { cached in
            // Check if cache is still valid (reduced to 7 days for fresher content)
            let maxCacheDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
            if now.timeIntervalSince(cached.lastUpdated) < maxCacheDuration {
                logger.info("Loading cached category: \(cached.type.rawValue) with \(cached.books.count) books")
                return TrendingCategory(
                    type: cached.type,
                    books: cached.books,
                    lastUpdated: cached.lastUpdated,
                    sourceDescription: cached.sourceDescription
                )
            } else {
                logger.info("Skipping stale cached category: \(cached.type.rawValue)")
            }
            return nil
        }
        
        lastUpdateTime = trendingCategories.first?.lastUpdated
        logger.info("Loaded \(self.trendingCategories.count) cached categories")
    }
    
    private func saveCachedCategories() async {
        let cached = trendingCategories.map { category in
            CachedTrendingData(
                type: category.type,
                books: category.books,
                lastUpdated: category.lastUpdated,
                sourceDescription: category.sourceDescription
            )
        }
        
        if let encoded = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(encoded, forKey: "CachedTrendingCategories")
        }
    }
    
    // MARK: - Cache Model
    struct CachedTrendingData: Codable {
        let type: TrendingCategory.CategoryType
        let books: [Book]
        let lastUpdated: Date
        let sourceDescription: String?
    }
}

// MARK: - Extensions
extension EnhancedTrendingBooksService {
    // Check if refresh is needed
    var needsRefresh: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > cacheDuration
    }
    
    // Get description for current category
    func getCurrentCategoryDescription() -> String? {
        trendingCategories.first { $0.type == selectedCategory }?.sourceDescription
    }
}