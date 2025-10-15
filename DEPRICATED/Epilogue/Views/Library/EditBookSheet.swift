import SwiftUI
import UIKit

struct EditBookSheet: View {
    let currentBook: Book
    let initialSearchTerm: String
    let onBookReplaced: (Book) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var booksService = GoogleBooksService()
    @State private var searchTerm: String
    @State private var searchResults: [Book] = []
    @State private var isLoading = false
    @State private var searchError: String?
    @State private var hasSearched = false
    @FocusState private var isSearchFieldFocused: Bool
    
    init(currentBook: Book, initialSearchTerm: String, onBookReplaced: @escaping (Book) -> Void) {
        self.currentBook = currentBook
        self.initialSearchTerm = initialSearchTerm
        self.onBookReplaced = onBookReplaced
        self._searchTerm = State(initialValue: initialSearchTerm)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - warm charcoal
                Color(red: 0.11, green: 0.105, blue: 0.102) // #1C1B1A
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Current book section
                        currentBookSection
                        
                        // Search section
                        searchSection
                        
                        // Results section
                        if hasSearched {
                            resultsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 17))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                }
            }
        }
        .presentationDetents([.fraction(0.9)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
    
    private var currentBookSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Book")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26)) // Warm orange
            
            CurrentBookRow(book: currentBook)
        }
    }
    
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search for Replacement")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26)) // Warm orange
            
            HStack {
                TextField("Enter book title or author...", text: $searchTerm)
                    .font(.system(size: 17))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    }
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        performSearch()
                    }
                
                Button(action: performSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                .disabled(searchTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26)) // Warm orange
            
            if isLoading {
                LiteraryLoadingView(message: "Searching for \"\(searchTerm)\"...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            } else if let error = searchError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26)) // Warm orange
                    
                    Text("Search Error")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    
                    Text(error)
                        .font(.bodyMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
            } else if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text("No books found")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    
                    Text("Try searching with different keywords")
                        .font(.bodyMedium)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(searchResults) { book in
                        EditBookResultRow(book: book, currentBook: currentBook) {
                            replaceBook(with: book)
                        }
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchTerm.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        hasSearched = true
        isSearchFieldFocused = false
        
        Task {
            isLoading = true
            searchError = nil
            
            await booksService.searchBooks(query: searchTerm)
            
            searchResults = booksService.searchResults
            searchError = booksService.errorMessage
            isLoading = false
        }
    }
    
    private func replaceBook(with book: Book) {
        HapticManager.shared.success()
        onBookReplaced(book)
    }
}

// MARK: - Current Book Row
struct CurrentBookRow: View {
    let book: Book
    
    private func enhanceGoogleBooksImageURL(_ urlString: String) -> String {
        // Google Books image URLs support zoom parameter for higher resolution
        var enhanced = urlString
        
        // Remove existing zoom parameter if present
        if let regex = try? NSRegularExpression(pattern: "&zoom=\\d", options: []) {
            let range = NSRange(location: 0, length: enhanced.utf16.count)
            enhanced = regex.stringByReplacingMatches(in: enhanced, options: [], range: range, withTemplate: "")
        }
        
        // Add high quality zoom parameter
        if enhanced.contains("?") {
            enhanced += "&zoom=2"
        } else {
            enhanced += "?zoom=2"
        }
        
        // Also remove edge curl parameter if present (makes covers look cleaner)
        enhanced = enhanced.replacingOccurrences(of: "&edge=curl", with: "")
        enhanced = enhanced.replacingOccurrences(of: "?edge=curl", with: "?")
        
        return enhanced
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Book cover
            Group {
                if let coverURL = book.coverImageURL {
                    let enhancedURL = enhanceGoogleBooksImageURL(coverURL)
                    if let url = URL(string: enhancedURL.replacingOccurrences(of: "http://", with: "https://")) {
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
        }
        .padding(16)
        .frame(height: 114)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.4)) // Slightly less opacity for current book
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1) // Orange border
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Edit Book Result Row
struct EditBookResultRow: View {
    let book: Book
    let currentBook: Book
    
    private func enhanceGoogleBooksImageURL(_ urlString: String) -> String {
        // Google Books image URLs support zoom parameter for higher resolution
        var enhanced = urlString
        
        // Remove existing zoom parameter if present
        if let regex = try? NSRegularExpression(pattern: "&zoom=\\d", options: []) {
            let range = NSRange(location: 0, length: enhanced.utf16.count)
            enhanced = regex.stringByReplacingMatches(in: enhanced, options: [], range: range, withTemplate: "")
        }
        
        // Add high quality zoom parameter
        if enhanced.contains("?") {
            enhanced += "&zoom=2"
        } else {
            enhanced += "?zoom=2"
        }
        
        // Also remove edge curl parameter if present (makes covers look cleaner)
        enhanced = enhanced.replacingOccurrences(of: "&edge=curl", with: "")
        enhanced = enhanced.replacingOccurrences(of: "?edge=curl", with: "?")
        
        return enhanced
    }
    let onReplace: () -> Void
    
    var isCurrentBook: Bool {
        book.id == currentBook.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Book cover
            Group {
                if let coverURL = book.coverImageURL {
                    let enhancedURL = enhanceGoogleBooksImageURL(coverURL)
                    if let url = URL(string: enhancedURL.replacingOccurrences(of: "http://", with: "https://")) {
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
            
            // Replace button or current indicator
            if isCurrentBook {
                Text("Current")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.15))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1)
                    }
            } else {
                Button(action: onReplace) {
                    Text("Replace")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .glassEffect(in: Capsule())
                .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2), radius: 8)
            }
        }
        .padding(16)
        .frame(height: 114)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)) // #262524 with transparency
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isCurrentBook ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3) : .white.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    EditBookSheet(
        currentBook: Book(
            id: "1",
            title: "The Lord of the Rings Illustrated",
            author: "J.R.R. Tolkien",
            publishedYear: "1954"
        ),
        initialSearchTerm: "Lord of the Rings"
    ) { newBook in
        #if DEBUG
        print("Replaced with: \(newBook.title)")
        #endif
    }
}