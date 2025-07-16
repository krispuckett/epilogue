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
                            VStack(spacing: 12) {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.3))
                                
                                Text("No books found")
                                    .font(.system(size: 20, weight: .medium, design: .serif))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                
                                Text("Try searching with different keywords")
                                    .font(.bodyMedium)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.top, 60)
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
        }
    }
    
    private func performSearch() {
        Task {
            isLoading = true
            searchError = nil
            
            await booksService.searchBooks(query: searchQuery)
            
            searchResults = booksService.searchResults
            searchError = booksService.errorMessage
            isLoading = false
        }
    }
    
    private func addBookToLibrary(_ book: Book) {
        HapticManager.shared.success()
        onBookSelected(book)
        dismiss()
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
            
            // Add button with liquid glass effect and amber tint
            Button(action: onSelect) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(.regularMaterial)
                            .overlay {
                                Circle()
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.35))
                            }
                    }
            }
            .glassEffect(in: Circle())
            .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 10)
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