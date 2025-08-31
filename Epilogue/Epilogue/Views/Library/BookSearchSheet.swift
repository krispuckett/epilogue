import SwiftUI
import UIKit




struct BookSearchSheet: View {
    let searchQuery: String
    let onBookSelected: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var booksService = GoogleBooksService()
    @State private var searchResults: [Book] = []
    @State private var isLoading = true
    @State private var searchError: String?
    @State private var refinedSearchQuery: String = ""
    @State private var showSearchRefinement = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack {
            // Beautiful gradient background like ambient sessions
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95),
                    Color(red: 0.1, green: 0.08, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // iOS 26 Style Header with glass effect
                headerView
                    .padding(.top, 8)
                
                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        if isLoading {
                            loadingView
                        } else if let error = searchError {
                            errorView(error: error)
                        } else if searchResults.isEmpty {
                            emptyStateView
                        } else {
                            resultsView
                        }
                    }
                    .padding(.top, 24)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
        .onAppear {
            performSearch()
            refinedSearchQuery = searchQuery
        }
    }
    
    // MARK: - Header View (iOS 26 Style)
    private var headerView: some View {
        HStack {
            // Drag indicator pill
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    // Cancel button
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.trailing, DesignSystem.Spacing.listItemPadding)
                }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            // Title
            Text("Select Book")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .background {
            // Glass effect background
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primaryAccent.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
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
            
            Text("Searching for \"\(searchQuery)\"...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
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
    
    // MARK: - Empty State View (Ultra Polished)
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            // Icon with glass background
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .overlay {
                        Circle()
                            .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.2), lineWidth: 1)
                    }
                    .glassEffect()
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
            }
            
            VStack(spacing: 12) {
                Text("No results for \"\"")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .overlay {
                        // Inject the search query with orange color
                        Text("No results for \"\(searchQuery)\"")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                
                Text("Refine your search:")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            // Search input with glass effect
            HStack(spacing: 0) {
                TextField("Try another title or author...", text: $refinedSearchQuery)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if !refinedSearchQuery.isEmpty {
                            performSearchWithQuery(refinedSearchQuery)
                        }
                    }
                
                Button {
                    if !refinedSearchQuery.isEmpty {
                        performSearchWithQuery(refinedSearchQuery)
                    }
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(refinedSearchQuery.isEmpty ? .white.opacity(0.3) : DesignSystem.Colors.primaryAccent)
                }
                .disabled(refinedSearchQuery.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
            }
            .glassEffect()
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            
            // Search tips with monospace styling
            VStack(spacing: 12) {
                Text("Search tips:")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.2)
                
                VStack(alignment: .leading, spacing: 8) {
                    tipRow(icon: "person", text: "Try the author's name")
                    tipRow(icon: "Aa", text: "Use fewer keywords")
                    tipRow(icon: "A|", text: "Check spelling")
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.top, 60)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 16) {
            // Results count header
            HStack {
                Text("RESULTS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.2)
                
                Spacer()
                
                Text("\(searchResults.count) books")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.8))
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            
            // Book results with glass cards
            VStack(spacing: 12) {
                ForEach(searchResults) { book in
                    BookSearchResultCard(book: book) {
                        addBookToLibrary(book)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
        .padding(.bottom, 32)
    }
    
    private func performSearch() {
        Task {
            print("BookSearchSheet: Starting search for query: '\(searchQuery)'")
            isLoading = true
            searchError = nil
            
            await booksService.searchBooks(query: searchQuery)
            
            searchResults = booksService.searchResults
            searchError = booksService.errorMessage
            isLoading = false
            print("BookSearchSheet: Search completed. Results: \(searchResults.count), Error: \(searchError ?? "none")")
        }
    }
    
    private func addBookToLibrary(_ book: Book) {
        SensoryFeedback.success()
        onBookSelected(book)
        dismiss()
    }
    
    private func performSearchWithQuery(_ query: String) {
        Task {
            isLoading = true
            searchError = nil
            refinedSearchQuery = query
            
            await booksService.searchBooks(query: query)
            
            searchResults = booksService.searchResults
            searchError = booksService.errorMessage
            isLoading = false
        }
    }
    
    private func getSpellingSuggestion(for query: String) -> String? {
        // Common book title misspellings
        let commonMisspellings: [String: String] = [
            "simiilarion": "silmarillion",
            "simillarion": "silmarillion",
            "simarillon": "silmarillion",
            "simarillion": "silmarillion",
            "hobitt": "hobbit",
            "hobit": "hobbit",
            "oddessey": "odyssey",
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
        var bestMatch: (String, Int) = ("", Int.max)
        
        for (_, correction) in commonMisspellings {
            let distance = levenshteinDistance(lowercaseQuery, correction)
            if distance < bestMatch.1 && distance <= 3 { // Allow up to 3 character differences
                bestMatch = (correction, distance)
            }
        }
        
        if bestMatch.1 <= 3 {
            return bestMatch.0.split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
        
        return nil
    }
    
    // Simple Levenshtein distance implementation
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[m][n]
    }
}

// MARK: - Book Search Result Card (Ultra Polished)
struct BookSearchResultCard: View {
    let book: Book
    let onAdd: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 16) {
                // Book cover with glass effect
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
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
                                .overlay {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.3))
                                }
                        }
                    } else {
                        Image(systemName: "book.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.3))
                    }
                }
                
                // Book details
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    Text(book.author)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    if let year = book.publishedDate?.prefix(4) {
                        Text(String(year))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Add button
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isPressed ? 0.08 : 0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isPressed ? DesignSystem.Colors.primaryAccent.opacity(0.3) : Color.white.opacity(0.1),
                                lineWidth: 0.5
                            )
                    }
            }
            .glassEffect()
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
}

// MARK: - Book Search Result Row (Legacy - to be removed)
struct BookSearchResultRow: View {
    let book: Book
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Book cover - use SharedBookCoverView for consistency
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 60,
                height: 90,
                loadFullImage: false,
                isLibraryView: false
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            
            // Book details
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96)) // Warm white
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                Text(book.author)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                if let year = book.publishedYear {
                    Text(year)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                }
            }
            
            Spacer()
            
            // Add button matching Notes view style
            Button(action: onSelect) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
            }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .frame(height: 114) // Match library list item height
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)) // #262524 with transparency
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}


#Preview {
    BookSearchSheet(searchQuery: "Dune") { book in
        print("Selected: \(book.title)")
    }
}