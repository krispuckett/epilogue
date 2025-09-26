import SwiftUI
import UIKit

// MARK: - Book Search Sheet (Matching Session Summary Design)
struct BookSearchSheet: View {
    enum Mode { case add, replace }
    let searchQuery: String
    let onBookSelected: (Book) -> Void
    var mode: Mode = .add
    @Environment(\.dismiss) private var dismiss
    @StateObject private var booksService = EnhancedGoogleBooksService()
    @StateObject private var trendingService = TrendingBooksService.shared
    @State private var searchResults: [Book] = []
    @State private var isLoading = true
    @State private var searchError: String?
    @State private var refinedSearchQuery: String = ""
    @State private var hasAutoSearched = false
    @FocusState private var isSearchFocused: Bool
    @State private var selectedFilter: TrendingBooksService.TrendingFilter = .currentYear
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient-style gradient background matching session summary
                ambientGradientBackground
                
                ScrollView {
                    VStack(spacing: 0) {
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
            print("📚 BookSearchSheet appeared with query: '\(searchQuery)'")
            refinedSearchQuery = searchQuery
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
            // Animated dots like ambient mode
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
                            value: isLoading
                        )
                }
            }
            
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
                    ForEach(TrendingBooksService.TrendingFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                            Task {
                                await trendingService.fetchTrendingBooks(for: filter)
                            }
                        }) {
                            Label(filter.rawValue, systemImage: filter.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedFilter.icon)
                            .font(.caption)
                        Text(selectedFilter.rawValue)
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
            } else if !trendingService.trendingBooks.isEmpty {
                // Grid of dynamic trending books
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(trendingService.trendingBooks, id: \.id) { book in
                        BestsellerBookCard(book: book) {
                            print("🔥 DEBUG: Book selected from trending/bestsellers:")
                            print("   ID: \(book.id)")
                            print("   Title: \(book.title)")
                            print("   Author: \(book.author)")
                            print("   Cover URL: \(book.coverImageURL ?? "nil")")
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
                            print("📚 DEBUG: Book selected from static bestsellers:")
                            print("   ID: \(book.id)")
                            print("   Title: \(book.title)")
                            print("   Author: \(book.author)")
                            print("   Cover URL: \(book.coverImageURL ?? "nil")")
                            onBookSelected(book)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            }
        }
        .task {
            // Load trending books if not already loaded
            if trendingService.trendingBooks.isEmpty {
                await trendingService.fetchTrendingBooks(for: selectedFilter)
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
            ForEach(searchResults) { book in
                BookSearchResultRow(book: book, onAdd: {
                    print("🔍 DEBUG: Book selected from search results:")
                    print("   ID: \(book.id)")
                    print("   Title: \(book.title)")
                    print("   Author: \(book.author)")
                    print("   Cover URL: \(book.coverImageURL ?? "nil")")
                    onBookSelected(book)
                    dismiss()
                })
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
        print("🔍 Starting search for: '\(query)'")
        isLoading = true
        searchError = nil
        
        // Use enhanced service ranking for better results
        // Use the enhanced searchBooksWithRanking method for better results
        searchResults = await booksService.searchBooksWithRanking(query: query)
        print("📖 Found \(searchResults.count) ranked results for: '\(query)'")
        
        if searchResults.isEmpty {
            // Try spell correction
            if let correctedQuery = spellCorrect(query), correctedQuery != query {
                print("🔤 Trying spell correction: '\(correctedQuery)'")
                searchResults = await booksService.searchBooksWithRanking(query: correctedQuery)
                print("📖 Found \(searchResults.count) results after correction")
            }
        }
        
        // Check for errors
        if let error = booksService.errorMessage {
            searchError = error
            print("❌ Search error:  (error)")
        }
        
        isLoading = false
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
                print("📚 Book selected for addition:")
                print("   ID: \(book.id)")
                print("   Title: \(book.title)")
                print("   Cover URL: \(book.coverImageURL ?? "nil")")
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
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .frame(width: 50, height: 75)
            
            if let coverURL = book.coverImageURL {
                let _ = print("🔍 BookSearchResultRow displaying book:")
                let _ = print("   Title: \(book.title)")
                let _ = print("   ID: \(book.id)")
                let _ = print("   Cover URL: \(coverURL)")
                AsyncImage(url: URL(string: coverURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.05))
                        .overlay {
                            Image(systemName: "book.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.2))
                        }
                }
            } else {
                Image(systemName: "book.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
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
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .frame(width: 60, height: 90)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            
            if let coverURL = book.coverImageURL {
                AsyncImage(url: URL(string: coverURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    bookCoverPlaceholder
                }
            } else {
                Image(systemName: "book.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.3))
            }
        }
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

// MARK: - Bestseller Book Card
struct BestsellerBookCard: View {
    let book: Book
    let onAdd: () -> Void
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 0) {
            // Book cover with add button overlay
            ZStack(alignment: .topTrailing) {
                // Book cover
                if let coverURL = book.coverImageURL {
                    AsyncImage(url: URL(string: coverURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 100, height: 150)
                            .overlay {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.white.opacity(0.2))
                            }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 100, height: 150)
                        .overlay {
                            Image(systemName: "book.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.white.opacity(0.2))
                        }
                }

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
