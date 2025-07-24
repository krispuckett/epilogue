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
        NavigationStack {
            ZStack {
                // Background - warm charcoal
                Color(red: 0.11, green: 0.105, blue: 0.102) // #1C1B1A
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        if isLoading {
                            LiteraryLoadingView(message: "Searching for \"\(searchQuery)\"...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else if let error = searchError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26)) // Warm orange
                                
                                Text("Search Error")
                                    .font(.system(size: 20, weight: .medium, design: .serif))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                
                                Text(error)
                                    .font(.bodyMedium)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                        } else if searchResults.isEmpty {
                            VStack(spacing: 20) {
                                // Icon and title
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass.circle")
                                        .font(.system(size: 56))
                                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
                                    
                                    Text("No results for \"\(searchQuery)\"")
                                        .font(.system(size: 20, weight: .semibold, design: .serif))
                                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                        .multilineTextAlignment(.center)
                                }
                                
                                // Spell check suggestion if available
                                if let suggestion = getSpellingSuggestion(for: searchQuery) {
                                    VStack(spacing: 8) {
                                        Text("Did you mean:")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white.opacity(0.6))
                                        
                                        Button {
                                            performSearchWithQuery(suggestion)
                                        } label: {
                                            Text(suggestion)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .glassEffect(in: Capsule())
                                        }
                                    }
                                }
                                
                                // Search refinement input
                                VStack(spacing: 12) {
                                    Text("Refine your search:")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.7))
                                    
                                    HStack {
                                        TextField("Try another title or author...", text: $refinedSearchQuery)
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                            .textFieldStyle(.plain)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
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
                                                .font(.title2)
                                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                                        }
                                        .disabled(refinedSearchQuery.isEmpty)
                                    }
                                    .padding(.horizontal, 20)
                                }
                                
                                // Tips
                                VStack(spacing: 8) {
                                    Text("Search tips:")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label("Try the author's name", systemImage: "person.fill")
                                        Label("Use fewer keywords", systemImage: "textformat")
                                        Label("Check spelling", systemImage: "character.cursor.ibeam")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(.top, 8)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 40)
                            .padding(.bottom, 32)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { book in
                                    BookSearchResultRow(book: book) {
                                        addBookToLibrary(book)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 17))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                }
            }
        }
        .presentationDetents([.fraction(0.75)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onAppear {
            performSearch()
            refinedSearchQuery = searchQuery
        }
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
        HapticManager.shared.success()
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

// MARK: - Book Search Result Row
struct BookSearchResultRow: View {
    let book: Book
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Book cover - match library list size
            Group {
                if let coverURL = book.coverImageURL,
                   let url = URL(string: coverURL.replacingOccurrences(of: "http://", with: "https://")) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    ProgressView()
                                        .tint(.white.opacity(0.5))
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 90)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        case .failure(_):
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                                .overlay {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                }
            }
            .frame(width: 60, height: 90)
            .clipped()
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
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            }
        }
        .padding(16)
        .frame(height: 114) // Match library list item height
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)) // #262524 with transparency
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}


#Preview {
    BookSearchSheet(searchQuery: "Dune") { book in
        print("Selected: \(book.title)")
    }
}