import SwiftUI

struct BookPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    let onBookSelected: (Book) -> Void
    @State private var searchText = ""
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return libraryViewModel.books
        } else {
            return libraryViewModel.books.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.11, green: 0.105, blue: 0.102)
                    .ignoresSafeArea()
                
                if libraryViewModel.books.isEmpty {
                    // Empty library state
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("No books in library")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text("Add books to your library first")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredBooks) { book in
                                BookPickerRow(book: book) {
                                    onBookSelected(book)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $searchText, prompt: "Search books...")
                }
            }
            .navigationTitle("Select a Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct BookPickerRow: View {
    let book: Book
    let onTap: () -> Void
    
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
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Book cover thumbnail
                if let coverURL = book.coverImageURL {
                    let enhancedURL = enhanceGoogleBooksImageURL(coverURL)
                    if let url = URL(string: enhancedURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                        .frame(width: 40, height: 60)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(book.author)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}