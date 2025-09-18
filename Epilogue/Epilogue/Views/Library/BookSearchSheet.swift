import SwiftUI
import UIKit

// MARK: - Book Search Sheet (Matching Session Summary Design)
struct BookSearchSheet: View {
    enum Mode { case add, replace }
    let searchQuery: String
    let onBookSelected: (Book) -> Void
    var mode: Mode = .add
    @Environment(\.dismiss) private var dismiss
    @StateObject private var booksService = GoogleBooksService()
    @State private var searchResults: [Book] = []
    @State private var isLoading = true
    @State private var searchError: String?
    @State private var refinedSearchQuery: String = ""
    @State private var hasAutoSearched = false
    @FocusState private var isSearchFocused: Bool
    
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
                            emptyStateView
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
        .presentationBackground(.black.opacity(0.95))
        .onAppear {
            print("📚 BookSearchSheet appeared with query: '\(searchQuery)'")
            refinedSearchQuery = searchQuery
            if searchQuery.isEmpty {
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
    
    // MARK: - Ambient Gradient Background
    private var ambientGradientBackground: some View {
        // Simple dark background for modal sheets
        Color.black.opacity(0.95)
            .ignoresSafeArea()
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
                        Text("Search for books...")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .font(.system(size: 16))
                            .lineLimit(1)
                    }
                    
                    TextField("", text: $refinedSearchQuery, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .accentColor(DesignSystem.Colors.primaryAccent)
                        .focused($isSearchFocused)
                        .lineLimit(1...5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
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
            
            Text(searchQuery.isEmpty ? "Searching..." : "Searching for \"\(searchQuery)\"...")
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
    
    // MARK: - Empty State View (Minimal Design)
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                // Only show "no results" if they actually searched for something
                if !searchQuery.isEmpty {
                    VStack(spacing: 12) {
                        Text("No results found")
                            .font(.system(size: 32, weight: .semibold, design: .default))
                            .foregroundStyle(.white)
                        
                        Text("for \"\(searchQuery)\"")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
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
        
        // Call searchBooks which updates the service's searchResults property
        await booksService.searchBooks(query: query)
        
        // Get the results from the service
        searchResults = booksService.searchResults
        print("📖 Found \(searchResults.count) results for: '\(query)'")
        
        if searchResults.isEmpty {
            // Try spell correction
            if let correctedQuery = spellCorrect(query), correctedQuery != query {
                print("🔤 Trying spell correction: '\(correctedQuery)'")
                await booksService.searchBooks(query: correctedQuery)
                searchResults = booksService.searchResults
                print("📖 Found \(searchResults.count) results after correction")
            }
        }
        
        // Check for errors
        if let error = booksService.errorMessage {
            searchError = error
            print("❌ Search error: \(error)")
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
        Button(action: onAdd) {
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
                
                // Add button - simpler
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var bookCoverView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
                .frame(width: 50, height: 75)
            
            if let coverURL = book.coverImageURL {
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
