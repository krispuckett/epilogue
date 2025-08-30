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
                DesignSystem.Colors.surfaceBackground // #1C1B1A
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
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
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
                .foregroundStyle(DesignSystem.Colors.primaryAccent) // Warm orange
            
            CurrentBookRow(book: currentBook)
            
            // Add compact timeline if currently reading
            if currentBook.readingStatus == .currentlyReading, let pageCount = currentBook.pageCount, pageCount > 0 {
                GeometryReader { geometry in
                    AmbientReadingProgressView(
                        book: currentBook,
                        width: geometry.size.width - 32,
                        showDetailed: false,
                        colorPalette: nil // EditBookSheet doesn't have color palette context
                    )
                }
                .frame(height: 60) // Set explicit height for GeometryReader
                .padding(.top, -8) // Reduce spacing since CurrentBookRow has bottom padding
            }
        }
    }
    
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search for Replacement")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryAccent) // Warm orange
            
            HStack {
                // Standardized search field
                StandardizedSearchField(
                    text: $searchTerm,
                    placeholder: "Enter book title or author..."
                )
                .onSubmit {
                    performSearch()
                    }
                
                Button(action: performSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .disabled(searchTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryAccent) // Warm orange
            
            if isLoading {
                LiteraryLoadingView(message: "Searching for \"\(searchTerm)\"...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            } else if let error = searchError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent) // Warm orange
                    
                    Text("Search Error")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    
                    Text(error)
                        .font(.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
            } else if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 36))
                        .foregroundStyle(DesignSystem.Colors.textQuaternary)
                    
                    Text("No books found")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    
                    Text("Try searching with different keywords")
                        .font(.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
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
        DesignSystem.HapticFeedback.success()
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
        
        // Add width parameter only (NO ZOOM)
        if enhanced.contains("?") {
            enhanced += "&w=1080"
        } else {
            enhanced += "?w=1080"
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
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    ProgressView()
                                        .tint(DesignSystem.Colors.textTertiary)
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                        case .failure(_):
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                                .overlay {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(DesignSystem.Colors.textQuaternary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    }
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
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
        .padding(DesignSystem.Spacing.inlinePadding)
        .frame(height: 114)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.4)) // Slightly less opacity for current book
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.3), lineWidth: 1) // Orange border
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
        
        // Add width parameter only (NO ZOOM)
        if enhanced.contains("?") {
            enhanced += "&w=1080"
        } else {
            enhanced += "?w=1080"
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
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    ProgressView()
                                        .tint(DesignSystem.Colors.textTertiary)
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                        case .failure(_):
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                                .overlay {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(DesignSystem.Colors.textQuaternary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    }
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
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
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.3), lineWidth: 1)
                    }
            } else {
                Button(action: onReplace) {
                    Text("Replace")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                        .padding(.vertical, 8)
                }
                .glassEffect(in: Capsule())
                .shadow(color: DesignSystem.Colors.primaryAccent.opacity(0.2), radius: 8)
            }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .frame(height: 114)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)) // #262524 with transparency
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(isCurrentBook ? DesignSystem.Colors.primaryAccent.opacity(0.3) : .white.opacity(0.10), lineWidth: 0.5)
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
        print("Replaced with: \(newBook.title)")
    }
}