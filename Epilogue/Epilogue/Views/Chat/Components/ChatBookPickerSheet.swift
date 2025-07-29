import SwiftUI

struct ChatBookPickerSheet: View {
    @Binding var selectedBook: Book?
    @Binding var isPresented: Bool
    let books: [Book]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    // Filtered books based on search
    private var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        } else {
            return books.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.4))
                
                TextField("Search books...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Book list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredBooks) { book in
                        BookRowItem(
                            book: book,
                            isSelected: selectedBook?.id == book.id
                        ) {
                            selectedBook = book
                            dismiss()
                            HapticManager.shared.lightTap()
                        }
                    }
                    
                    // Clear selection option
                    if selectedBook != nil {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 8)
                        
                        Button {
                            selectedBook = nil
                            dismiss()
                            HapticManager.shared.lightTap()
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                
                                Text("Clear Book Selection")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Book Row Item

struct BookRowItem: View {
    let book: Book
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                // Book cover
                AsyncImage(url: URL(string: book.coverImageURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    case .failure(_), .empty:
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 40, height: 56)
                            .overlay {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Book info
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    
                    Text(book.author)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ChatBookPickerSheet(
        selectedBook: .constant(nil),
        isPresented: .constant(true),
        books: [
            Book(
                id: "1",
                title: "The Lord of the Rings",
                author: "J.R.R. Tolkien",
                coverImageURL: nil,
                pageCount: 1216
            ),
            Book(
                id: "2",
                title: "1984",
                author: "George Orwell",
                coverImageURL: nil,
                pageCount: 328
            )
        ]
    )
}