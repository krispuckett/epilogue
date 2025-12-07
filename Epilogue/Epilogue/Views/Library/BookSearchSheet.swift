import SwiftUI
import SwiftData
import UIKit

// MARK: - Book Search Sheet (Matching Session Summary Design)
struct BookSearchSheet: View {
    enum Mode { case add, replace }
    enum ViewMode { case trending, forYou }

    let searchQuery: String
    let onBookSelected: (Book) -> Void
    var mode: Mode = .add
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var booksService = EnhancedGoogleBooksService()
    @StateObject private var trendingService = EnhancedTrendingBooksService.shared
    @State private var searchResults: [Book] = []
    @State private var isLoading = true
    @State private var searchError: String?
    @State private var refinedSearchQuery: String = ""
    @State private var hasAutoSearched = false
    @FocusState private var isSearchFocused: Bool

    // For You state
    @State private var viewMode: ViewMode = .trending
    @State private var forYouRecommendations: [RecommendationEngine.Recommendation] = []
    @State private var isLoadingForYou = false
    @State private var libraryBookCount = 0

    // Library size check for For You availability
    private var hasEnoughBooksForRecommendations: Bool {
        libraryBookCount >= 5
    }

    // Load book count efficiently (count only, no full fetch)
    private func loadLibraryBookCount() {
        let descriptor = FetchDescriptor<BookModel>()
        libraryBookCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient-style gradient background matching session summary
                ambientGradientBackground
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Mode toggle (Trending | For You)
                        if searchQuery.isEmpty && refinedSearchQuery.isEmpty {
                            modeToggle
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                        }

                        // Content based on view mode
                        if viewMode == .forYou {
                            forYouView
                                .padding(.top, 16)
                        } else {
                            // Original trending/search view
                            if isLoading {
                                loadingView
                                    .padding(.top, 100)
                            } else if let error = searchError {
                                errorView(error: error)
                            } else if searchResults.isEmpty {
                                // Show bestsellers when no search results and no query
                                if searchQuery.isEmpty && refinedSearchQuery.isEmpty {
                                    bestsellersView
                                        .padding(.top, 24)
                                } else {
                                    emptyStateView
                                }
                            } else {
                                resultsView
                                    .padding(.top, 24)
                            }
                        }
                    }
                    .padding(.bottom, 100) // Space for input bar
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(mode == .add ? "Add Book" : "Replace Book")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .safeAreaBar(edge: .bottom) {
                searchInputBar
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
        .onAppear {
            #if DEBUG
            print("📚 BookSearchSheet appeared with query: '\(searchQuery)'")
            #endif
            refinedSearchQuery = searchQuery
            loadLibraryBookCount() // Efficient count-only query
            if searchQuery.isEmpty {
                // Start not loading to show bestsellers immediately
                isLoading = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isSearchFocused = true }
            }
        }
        // Ensure first-open search reliably triggers
        .task(id: searchQuery) {
            guard !searchQuery.isEmpty, !hasAutoSearched else { return }
            hasAutoSearched = true
            await search(query: searchQuery)
        }
    }
    
    // MARK: - Ambient Gradient Background - MATCHING AMBIENT SESSION SUMMARY
    private var ambientGradientBackground: some View {
        ZStack {
            // Permanent ambient gradient background - EXACTLY LIKE SESSION SUMMARY
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            // Subtle darkening overlay for better readability
            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Search Input Bar (Bottom)
    private var searchInputBar: some View {
        HStack(spacing: 12) {
            // Main input bar with glass effect
            HStack(spacing: 0) {
                // Search icon on the left
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .frame(height: 36)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                
                // Text input
                ZStack(alignment: .leading) {
                    if refinedSearchQuery.isEmpty {
                        Text("Search for books")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .font(.system(size: 16))
                            .lineLimit(1)
                    }
                    
                    TextField("", text: $refinedSearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .accentColor(DesignSystem.Colors.primaryAccent)
                        .focused($isSearchFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)
                        .onSubmit {
                            if !refinedSearchQuery.isEmpty {
                                performSearchWithQuery(refinedSearchQuery)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                
                Spacer()
                    .frame(width: 12)
            }
            .frame(minHeight: 44)
            .glassEffect(in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            
            // Morphing orb button - search icon when empty, up arrow when has text
            Button {
                if !refinedSearchQuery.isEmpty {
                    // Submit the search
                    performSearchWithQuery(refinedSearchQuery)
                } else {
                    // Focus the search field
                    isSearchFocused = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .glassEffect()
                    
                    Image(systemName: refinedSearchQuery.isEmpty ? "magnifyingglass" : "arrow.up")
                        .font(.system(size: 18, weight: refinedSearchQuery.isEmpty ? .medium : .semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.bottom, 8)
        .animation(DesignSystem.Animation.springStandard, value: refinedSearchQuery.isEmpty)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            // Polished thinking indicator matching ambient mode
            BookSearchThinkingIndicator()

            Text(refinedSearchQuery.isEmpty ?
                 (searchQuery.isEmpty ? "Searching..." : "Searching for \"\(searchQuery)\"...") :
                 "Searching for \"\(refinedSearchQuery)\"...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.8))
                .symbolRenderingMode(.hierarchical)
            
            Text("Search Error")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(error)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - Bestsellers View
    private var bestsellersView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with Filter
            HStack {
                Text("TRENDING BOOKS")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Spacer()

                // Filter Menu
                Menu {
                    ForEach(EnhancedTrendingBooksService.TrendingCategory.CategoryType.allCases, id: \.self) { category in
                        Button(action: {
                            if trendingService.selectedCategory != category {
                                trendingService.selectedCategory = category
                                // Clear current books to show loading state
                                trendingService.isLoading = true
                                Task {
                                    // Always refresh to get category-specific books
                                    await trendingService.refreshTrendingBooks(for: category)
                                }
                            }
                        }) {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: trendingService.selectedCategory.icon)
                            .font(.caption)
                        Text(trendingService.selectedCategory.rawValue)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: Capsule())
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            // Loading or Grid
            if trendingService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(DesignSystem.Colors.primaryAccent)
                        .frame(height: 150)
                    Spacer()
                }
            } else {
                let books = trendingService.getBooksForCurrentCategory()
                if !books.isEmpty {
                    // Grid of dynamic trending books
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(books, id: \.id) { book in
                            BestsellerBookCard(book: book) {
                                #if DEBUG
                                print("🔥 DEBUG: Book selected from trending/bestsellers:")
                                #endif
                                #if DEBUG
                                print("   ID: \(book.id)")
                                #endif
                                #if DEBUG
                                print("   Title: \(book.title)")
                                #endif
                                #if DEBUG
                                print("   Author: \(book.author)")
                                #endif
                                #if DEBUG
                                print("   Cover URL: \(book.coverImageURL ?? "nil")")
                                #endif
                                onBookSelected(book)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                } else {
                    // Fallback to static books if service hasn't loaded yet
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(bestsellerBooks, id: \.id) { book in
                            BestsellerBookCard(book: book) {
                                #if DEBUG
                                print("📚 DEBUG: Book selected from static bestsellers:")
                                #endif
                                #if DEBUG
                                print("   ID: \(book.id)")
                                #endif
                                #if DEBUG
                                print("   Title: \(book.title)")
                                #endif
                                #if DEBUG
                                print("   Author: \(book.author)")
                                #endif
                                #if DEBUG
                                print("   Cover URL: \(book.coverImageURL ?? "nil")")
                                #endif
                                onBookSelected(book)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                }
            }
        }
        .task {
            // Load trending books if not already loaded
            if trendingService.getBooksForCurrentCategory().isEmpty {
                await trendingService.refreshTrendingBooks(for: trendingService.selectedCategory)
            }
        }
    }

    // Current bestsellers - 2025 with Google Books URLs
    private var bestsellerBooks: [Book] {
        [
            Book(
                id: "onyx-storm-2025",
                title: "Onyx Storm",
                author: "Rebecca Yarros",
                publishedYear: "2025",
                coverImageURL: "https://books.google.com/books/content?id=8u3PEAAAQBAJ&printsec=frontcover&img=1&zoom=1",
                isbn: "9781649375025"
            ),
            Book(
                id: "the-women-2024",
                title: "The Women",
                author: "Kristin Hannah",
                publishedYear: "2024",
                coverImageURL: "https://books.google.com/books/content?id=7pXEEAAAQBAJ&printsec=frontcover&img=1&zoom=1",
                isbn: "9781250178633"
            ),
            Book(
                id: "funny-story-2024",
                title: "Funny Story",
                author: "Emily Henry",
                publishedYear: "2024",
                coverImageURL: "https://books.google.com/books/content?id=rIPJEAAAQBAJ&printsec=frontcover&img=1&zoom=1",
                isbn: "9780593441282"
            ),
            Book(
                id: "the-housemaid-2024",
                title: "The Housemaid",
                author: "Freida McFadden",
                publishedYear: "2024",
                coverImageURL: "https://books.google.com/books/content?id=DFy8EAAAQBAJ&printsec=frontcover&img=1&zoom=1",
                isbn: "9781538742570"
            ),
            Book(
                id: "just-for-the-summer-2024",
                title: "Just for the Summer",
                author: "Abby Jimenez",
                publishedYear: "2024",
                coverImageURL: "https://books.google.com/books/content?id=PZPJEAAAQBAJ&printsec=frontcover&img=1&zoom=1",
                isbn: "9781538704431"
            ),
            Book(
                id: "the-god-of-the-woods-2024",
                title: "The God of the Woods",
                author: "Liz Moore",
                publishedYear: "2024",
                coverImageURL: "https://books.google.com/books/content?id=2zXOEAAAQBAJ&printsec=frontcover&img=1&zoom=1",
                isbn: "9780593449738"
            )
        ]
    }

    // MARK: - Empty State View (Minimal Design)
    private var emptyStateView: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                // Show appropriate message based on search state
                if !searchQuery.isEmpty || !refinedSearchQuery.isEmpty {
                    VStack(spacing: 12) {
                        // Dynamic message based on search progress
                        if isLoading {
                            Text("Searching...")
                                .font(.system(size: 32, weight: .semibold, design: .default))
                                .foregroundStyle(.white)
                        } else {
                            Text("Searching for")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.white.opacity(0.6))

                            Text("\"\(refinedSearchQuery.isEmpty ? searchQuery : refinedSearchQuery)\"")
                                .font(.system(size: 28, weight: .semibold, design: .default))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                // Minimal tips - monospace style
                VStack(alignment: .leading, spacing: 16) {
                    Text("SUGGESTIONS")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(1.2)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Try the author's name", systemImage: "person")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Label("Use fewer keywords", systemImage: "textformat.size.smaller")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Label("Check your spelling", systemImage: "textformat.abc")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.02))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, book in
                BookSearchResultRow(book: book, onAdd: {
                    #if DEBUG
                    print("🔍 DEBUG: Book selected from search results:")
                    #endif
                    #if DEBUG
                    print("   ID: \(book.id)")
                    #endif
                    #if DEBUG
                    print("   Title: \(book.title)")
                    #endif
                    #if DEBUG
                    print("   Author: \(book.author)")
                    #endif
                    #if DEBUG
                    print("   Cover URL: \(book.coverImageURL ?? "nil")")
                    #endif
                    onBookSelected(book)
                    dismiss()
                })
                .onAppear {
                    // Load more when approaching the end (5 items from bottom)
                    if index == searchResults.count - 5 {
                        Task {
                            await loadMoreSearchResults()
                        }
                    }
                }
            }

            // Loading indicator at bottom when loading more
            if booksService.isLoading && !searchResults.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(DesignSystem.Colors.primaryAccent)
                    Text("Loading more...")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 20)
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Search Functions
    private func performSearch() {
        Task {
            await search(query: searchQuery)
        }
    }
    
    private func performSearchWithQuery(_ query: String) {
        Task {
            await search(query: query)
        }
    }
    
    @MainActor
    private func search(query: String) async {
        #if DEBUG
        print("🔍 Starting search for: '\(query)'")
        #endif
        isLoading = true
        searchError = nil

        // Detect if the query is an ISBN
        let detectedISBN = detectISBN(from: query)

        #if DEBUG
        if let isbn = detectedISBN {
            print("📚 Detected ISBN: \(isbn) - using direct ISBN search")
        }
        #endif

        // Use enhanced search with smart ranking and filtering
        // If ISBN detected, pass it as preferISBN for direct lookup
        searchResults = await booksService.searchBooksWithRanking(
            query: query,
            preferISBN: detectedISBN
        )

        #if DEBUG
        print("📖 Found \(searchResults.count) enhanced results for: '\(query)'")
        #endif

        // Re-rank by visual similarity if we have a captured feature print
        if BookScannerService.shared.capturedFeaturePrint != nil {
            #if DEBUG
            print("🎨 Re-ranking results by cover similarity...")
            #endif
            searchResults = await BookScannerService.shared.reRankBooksWithFeaturePrint(searchResults)
        }

        if searchResults.isEmpty {
            // Try spell correction
            if let correctedQuery = spellCorrect(query), correctedQuery != query {
                #if DEBUG
                print("🔤 Trying spell correction: '\(correctedQuery)'")
                #endif
                searchResults = await booksService.searchBooksWithRanking(query: correctedQuery)
                #if DEBUG
                print("📖 Found \(searchResults.count) results after correction")
                #endif
            }
        }

        // Check for errors
        if let error = booksService.errorMessage {
            searchError = error
            #if DEBUG
            print("❌ Search error:  (error)")
            #endif
        }

        isLoading = false
    }

    @MainActor
    private func loadMoreSearchResults() async {
        #if DEBUG
        print("📚 Loading more search results...")
        #endif

        let newResults = await booksService.loadMoreEnhancedResults()

        // Only update if we got new results (don't clear existing results)
        if !newResults.isEmpty {
            searchResults = newResults
            #if DEBUG
            print("📖 Total results now: \(searchResults.count)")
            #endif
        } else {
            #if DEBUG
            print("📖 No more results available")
            #endif
        }
    }
    
    // MARK: - Spell Correction
    private func spellCorrect(_ query: String) -> String? {
        let commonMisspellings: [String: String] = [
            "odyssy": "odyssey",
            "odissey": "odyssey",
            "illiad": "iliad",
            "iliad": "iliad",
            "moby dic": "moby dick",
            "mobydick": "moby dick",
            "davinci code": "da vinci code",
            "davinci": "da vinci",
            "harry poter": "harry potter",
            "hary potter": "harry potter",
            "hunger game": "hunger games",
            "lord of the ring": "lord of the rings",
            "game of throne": "game of thrones",
            "1985": "1984",
            "farenheit": "fahrenheit",
            "farhenheit": "fahrenheit",
            "catcher and the rye": "catcher in the rye",
            "to kill a mocking bird": "to kill a mockingbird",
            "mockingbird": "to kill a mockingbird",
            "the alchemist": "alchemist",
            "alchemist": "the alchemist"
        ]
        
        let lowercaseQuery = query.lowercased()
        
        // Check exact matches first
        if let suggestion = commonMisspellings[lowercaseQuery] {
            return suggestion.split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
        
        // Check if query contains common misspellings
        for (misspelling, correction) in commonMisspellings {
            if lowercaseQuery.contains(misspelling) {
                let corrected = lowercaseQuery.replacingOccurrences(of: misspelling, with: correction)
                return corrected.split(separator: " ")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: " ")
            }
        }
        
        // Use Levenshtein distance for fuzzy matching
        for (misspelling, correction) in commonMisspellings {
            if levenshteinDistance(lowercaseQuery, misspelling) <= 2 {
                return correction.split(separator: " ")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: " ")
            }
        }
        
        return nil
    }
    
    // MARK: - Levenshtein Distance Algorithm
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }

    // MARK: - ISBN Detection
    /// Detects if a search query is an ISBN (10 or 13 digits) and returns cleaned ISBN
    private func detectISBN(from query: String) -> String? {
        // Remove common separators (hyphens, spaces)
        let cleanedQuery = query.replacingOccurrences(of: "-", with: "")
                                .replacingOccurrences(of: " ", with: "")
                                .trimmingCharacters(in: .whitespaces)

        // Check if it's all digits (ISBN-10 or ISBN-13)
        let digitsOnly = cleanedQuery.filter { $0.isNumber }

        // ISBN-10: 10 digits
        // ISBN-13: 13 digits (usually starts with 978 or 979)
        if digitsOnly.count == 10 || digitsOnly.count == 13 {
            // Make sure the cleaned query is mostly digits (allow for X in ISBN-10)
            let allowedChars = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "Xx"))
            if cleanedQuery.rangeOfCharacter(from: allowedChars.inverted) == nil {
                #if DEBUG
                print("📚 ISBN detected: \(digitsOnly) (length: \(digitsOnly.count))")
                #endif
                return digitsOnly
            }
        }

        // Also check if query contains "ISBN:" prefix
        if query.lowercased().hasPrefix("isbn:") || query.lowercased().hasPrefix("isbn ") {
            let isbnPart = String(query.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return detectISBN(from: isbnPart)  // Recursive call to clean it
        }

        return nil
    }

    // MARK: - Mode Toggle (Trending | For You)

    private var modeToggle: some View {
        HStack(spacing: 8) {
            // Trending button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewMode = .trending
                }
                SensoryFeedback.selection()
            } label: {
                Text("Trending")
                    .font(.system(size: 15, weight: viewMode == .trending ? .semibold : .medium))
                    .foregroundStyle(viewMode == .trending ? DesignSystem.Colors.primaryAccent : .white.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background {
                        if viewMode == .trending {
                            Capsule()
                                .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                                .matchedGeometryEffect(id: "mode_pill", in: modeToggleNamespace)
                        }
                    }
            }
            .buttonStyle(.plain)

            // For You button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewMode = .forYou
                }
                SensoryFeedback.selection()

                // Load recommendations on first tap
                if forYouRecommendations.isEmpty {
                    Task {
                        await loadForYouRecommendations()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if !hasEnoughBooksForRecommendations {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                    }
                    Text("For You")
                }
                .font(.system(size: 15, weight: viewMode == .forYou ? .semibold : .medium))
                .foregroundStyle(viewMode == .forYou ? DesignSystem.Colors.primaryAccent : .white.opacity(hasEnoughBooksForRecommendations ? 0.6 : 0.3))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background {
                    if viewMode == .forYou {
                        Capsule()
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                            .matchedGeometryEffect(id: "mode_pill", in: modeToggleNamespace)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasEnoughBooksForRecommendations)
        }
        .padding(6)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
        }
    }

    @Namespace private var modeToggleNamespace

    // MARK: - For You View

    @ViewBuilder
    private var forYouView: some View {
        if !hasEnoughBooksForRecommendations {
            forYouEmptyState
        } else if isLoadingForYou {
            forYouLoadingState
        } else if forYouRecommendations.isEmpty {
            Text("No recommendations yet")
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 100)
        } else {
            forYouResults
        }
    }

    // MARK: - For You Empty State (<5 books)

    private var forYouEmptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                // Lock icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))
                }

                VStack(spacing: 8) {
                    Text("For You")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Add \(5 - libraryBookCount) more \(5 - libraryBookCount == 1 ? "book" : "books") to unlock personalized recommendations")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // Mini explainer
                VStack(alignment: .leading, spacing: 12) {
                    Text("HOW IT WORKS")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(1.2)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Analyzes your library on-device", systemImage: "cpu")
                        Label("Uses AI to understand your taste", systemImage: "brain")
                        Label("Recommends books you'll love", systemImage: "sparkles")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.02))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - For You Loading State

    private var forYouLoadingState: some View {
        VStack(spacing: 24) {
            // Animated dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isLoadingForYou
                        )
                }
            }

            VStack(spacing: 12) {
                Text("Analyzing your library...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Reading your taste, finding perfect matches")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    // MARK: - For You Results

    private var forYouResults: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("FOR YOU")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Text("Based on your library of \(libraryBookCount) books")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            // Recommendations list
            LazyVStack(spacing: 0) {
                ForEach(forYouRecommendations) { rec in
                    ForYouRecommendationRow(recommendation: rec, onAdd: {
                        // Convert to Book and call onBookSelected
                        let book = Book(
                            id: rec.id,
                            title: rec.title,
                            author: rec.author,
                            publishedYear: rec.year,
                            coverImageURL: rec.coverURL
                        )
                        onBookSelected(book)
                        dismiss()
                    })
                }
            }
        }
    }

    // MARK: - Load For You Recommendations

    private func loadForYouRecommendations() async {
        isLoadingForYou = true

        do {
            // Check cache first
            if let cached = await RecommendationCache.shared.load(currentBookCount: libraryBookCount) {
                #if DEBUG
                print("✅ Using cached recommendations")
                #endif
                forYouRecommendations = cached.recommendations
                isLoadingForYou = false
                return
            }

            // Generate fresh recommendations
            #if DEBUG
            print("🎯 Generating fresh For You recommendations...")
            #endif

            // Step 1: Load all books for analysis (only when needed for recommendations)
            let descriptor = FetchDescriptor<BookModel>()
            let allBooks = (try? modelContext.fetch(descriptor)) ?? []

            // Step 2: Analyze library on-device
            let profile = await LibraryTasteAnalyzer.shared.analyzeLibrary(books: allBooks)

            // Step 3: Get recommendations from Perplexity
            let recommendations = try await RecommendationEngine.shared.generateRecommendations(for: profile)

            // Step 4: Cache for 30 days
            await RecommendationCache.shared.save(
                profile: profile,
                recommendations: recommendations,
                bookCount: libraryBookCount
            )

            await MainActor.run {
                forYouRecommendations = recommendations
                isLoadingForYou = false
            }

            #if DEBUG
            print("✅ Loaded \(recommendations.count) For You recommendations")
            #endif

        } catch {
            #if DEBUG
            print("❌ Failed to load For You recommendations: \(error)")
            #endif
            isLoadingForYou = false
        }
    }
}

// MARK: - Clean Book Search Result Row
struct BookSearchResultRow: View {
    let book: Book
    let onAdd: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Book cover - smaller and cleaner
            bookCoverView
            
            // Book info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(book.author)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                
                if let year = book.publishedYear {
                    Text(year)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Add button - now the only clickable element
            Button(action: {
                #if DEBUG
                print("📚 Book selected for addition:")
                #endif
                #if DEBUG
                print("   ID: \(book.id)")
                #endif
                #if DEBUG
                print("   Title: \(book.title)")
                #endif
                #if DEBUG
                print("   Cover URL: \(book.coverImageURL ?? "nil")")
                #endif
                onAdd()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var bookCoverView: some View {
        SmartBookCoverView(coverURL: book.coverImageURL, width: 50, height: 75)
    }
}

// MARK: - Book Search Result Card (Ultra Polished) - DEPRECATED
struct BookSearchResultCard: View {
    let book: Book
    let onAdd: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 16) {
                bookCoverView
                bookDetailsView
                addButtonView
            }
            .padding(16)
            .background(cardBackground)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0.1,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
    
    // MARK: - Sub-views
    @ViewBuilder
    private var bookCoverView: some View {
        SmartBookCoverView(coverURL: book.coverImageURL, width: 60, height: 90)
    }
    
    @ViewBuilder
    private var bookCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
            .overlay {
                Image(systemName: "book.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.3))
            }
    }
    
    @ViewBuilder
    private var bookDetailsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(book.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            
            Text(book.author)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            
            if let year = book.publishedYear {
                Text(year)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var addButtonView: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                .frame(width: 36, height: 36)
            
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.primaryAccent)
        }
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(cardBackgroundColor)
            .overlay(cardBorder)
    }
    
    private var cardBackgroundColor: Color {
        Color.white.opacity(isPressed ? 0.08 : 0.05)
    }
    
    @ViewBuilder
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(cardBorderColor, lineWidth: 0.5)
    }
    
    private var cardBorderColor: Color {
        isPressed ? DesignSystem.Colors.primaryAccent.opacity(0.3) : Color.white.opacity(0.1)
    }
}

// MARK: - Smart Book Cover View
struct SmartBookCoverView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat = 8
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Background placeholder
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.05))
                .frame(width: width, height: height)
            
            if let image = loadedImage {
                // Display loaded image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .transition(.opacity)
            } else if isLoading {
                // Loading indicator
                ProgressView()
                    .tint(DesignSystem.Colors.primaryAccent.opacity(0.6))
                    .scaleEffect(0.8)
            } else {
                // Fallback when no image
                Image(systemName: "book.fill")
                    .font(.system(size: min(width, height) * 0.25))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
        .task {
            await loadCover()
        }
    }
    
    private func loadCover() async {
        guard let url = coverURL else {
            isLoading = false
            return
        }
        
        // Log URL for debugging
        #if DEBUG
        print("🔍 SmartBookCoverView loading: \(url)")
        #endif
        
        // First check cache
        if let cached = SharedBookCoverManager.shared.getCachedImage(for: url) {
            #if DEBUG
            print("✅ Found in cache")
            #endif
            loadedImage = cached
            isLoading = false
            return
        }
        
        // Load thumbnail size for grid
        let targetSize = CGSize(width: width * UIScreen.main.scale, 
                               height: height * UIScreen.main.scale)
        if let image = await SharedBookCoverManager.shared.loadThumbnail(from: url, targetSize: targetSize) {
            #if DEBUG
            print("✅ Loaded successfully")
            #endif
            withAnimation(.easeIn(duration: 0.3)) {
                loadedImage = image
            }
        } else {
            #if DEBUG
            print("❌ Failed to load cover from: \(url)")
            #endif
        }
        isLoading = false
    }
}

// MARK: - For You Recommendation Row
struct ForYouRecommendationRow: View {
    let recommendation: RecommendationEngine.Recommendation
    let onAdd: () -> Void

    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Book cover
            SmartBookCoverView(coverURL: recommendation.coverURL, width: 50, height: 75)

            // Book info with reasoning
            VStack(alignment: .leading, spacing: 6) {
                Text(recommendation.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(recommendation.author)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                // Reasoning - collapsible
                Text(recommendation.reasoning)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.9))
                    .lineLimit(isExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Add button
            Button(action: {
                #if DEBUG
                print("📚 For You book selected:")
                #endif
                #if DEBUG
                print("   Title: \(recommendation.title)")
                #endif
                #if DEBUG
                print("   Reasoning: \(recommendation.reasoning)")
                #endif
                onAdd()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.vertical, 12)
    }
}

// MARK: - Bestseller Book Card
struct BestsellerBookCard: View {
    let book: Book
    let onAdd: () -> Void
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 0) {
            // Book cover with add button overlay
            ZStack(alignment: .topTrailing) {
                // Use SmartBookCoverView instead of AsyncImage
                SmartBookCoverView(coverURL: book.coverImageURL, width: 100, height: 150)

                // Add button with glass effect
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isAdding = true
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAdd()

                    // Reset after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAdding = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .glassEffect(.regular, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        DesignSystem.Colors.primaryAccent.opacity(0.3),
                                        lineWidth: 0.5
                                    )
                            }

                        Image(systemName: isAdding ? "checkmark" : "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .offset(x: 6, y: -6)
                .shadow(color: DesignSystem.Colors.primaryAccent.opacity(0.2), radius: 4, y: 2)
            }

            // Title
            Text(book.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)
                .padding(.top, 8)

            // Author
            Text(book.author)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .frame(width: 100)
                .padding(.top, 2)
        }
        .scaleEffect(isAdding ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isAdding)
    }
}

// MARK: - Book Search Thinking Indicator
/// Polished centered thinking indicator with fluid bounce animation (matching ambient mode style)
struct BookSearchThinkingIndicator: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]
    @State private var timer: Timer?

    // Amber accent color matching app theme
    private let amberColor = Color(red: 1.0, green: 0.6, blue: 0.2)

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(amberColor)
                    .frame(width: 10, height: 10)
                    .offset(y: dotOffsets[i])
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassEffect(.regular.tint(amberColor.opacity(0.15)), in: Capsule())
        .onAppear {
            startBounceAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startBounceAnimation() {
        // Staggered bounce for each dot
        for i in 0..<3 {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateDot(at: i)
            }
        }

        // Repeat the whole sequence
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            for i in 0..<3 {
                let delay = Double(i) * 0.15
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    animateDot(at: i)
                }
            }
        }
    }

    private func animateDot(at index: Int) {
        withAnimation(.easeOut(duration: 0.25)) {
            dotOffsets[index] = -8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.25)) {
                dotOffsets[index] = 0
            }
        }
    }
}
