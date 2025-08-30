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
                DesignSystem.Colors.surfaceBackground
                    .ignoresSafeArea()
                
                if libraryViewModel.books.isEmpty {
                    // Empty library state
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 48))
                            .foregroundStyle(DesignSystem.Colors.textQuaternary)
                        
                        Text("No books in library")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        Text("Add books to your library first")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
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
        
        // Add width parameter only (NO ZOOM)
        if enhanced.contains("?") {
            enhanced += "&w=1080"
        } else {
            enhanced += "?w=1080"
        }
        
        // Also remove edge curl parameter if present (makes covers look cleaner)
        enhanced = enhanced.replacingOccurrences(of: "&edge=curl", with: "")
        enhanced = enhanced.replacingOccurrences(of: "?edge=curl", with: "?")
        
        // IMPORTANT: Convert HTTP to HTTPS for App Transport Security
        enhanced = enhanced.replacingOccurrences(of: "http://", with: "https://")
        
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
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
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
                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color.white.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}