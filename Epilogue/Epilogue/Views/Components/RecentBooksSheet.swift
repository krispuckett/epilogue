import SwiftUI

// MARK: - Recent Books Sheet for Quick Note Addition
struct RecentBooksSheet: View {
    @Binding var isPresented: Bool
    let onBookSelected: (Book) -> Void

    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select a book to add notes")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal)
                            .padding(.top, 8)

                        VStack(spacing: 12) {
                            ForEach(recentBooks) { book in
                                BookRow(book: book) {
                                    onBookSelected(book)
                                    isPresented = false
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Recent Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(themeManager.currentTheme.primaryAccent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var recentBooks: [Book] {
        // Get recently viewed or recently added books
        let allBooks = libraryViewModel.books

        // Sort by last interaction (could be lastViewedDate if you track that)
        // For now, just show the most recently added books
        return Array(allBooks.prefix(10))
    }
}

// MARK: - Book Row Component
private struct BookRow: View {
    let book: Book
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Book cover thumbnail
                SharedBookCoverView(
                    coverURL: book.coverImageURL,
                    width: 50,
                    height: 70,
                    loadFullImage: false,
                    isLibraryView: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(book.author)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    if let pageCount = book.pageCount, book.currentPage > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                                .font(.system(size: 11))
                            Text("\(Int(Double(book.currentPage) / Double(pageCount) * 100))% read")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(themeManager.currentTheme.primaryAccent.opacity(0.8))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        themeManager.currentTheme.primaryAccent.opacity(0.2),
                        lineWidth: 0.5
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RecentBooksSheet(isPresented: .constant(true)) { book in
        print("Selected: \(book.title)")
    }
    .environmentObject(LibraryViewModel())
}