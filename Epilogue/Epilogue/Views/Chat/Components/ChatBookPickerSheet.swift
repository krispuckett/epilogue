import SwiftUI

struct ChatBookPickerSheet: View {
    @Binding var selectedBook: Book?
    @Binding var isPresented: Bool
    let books: [Book]
    @State private var searchText = ""
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
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
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // Search bar - using standardized styles
            StandardizedSearchField(
                text: $searchText,
                placeholder: "Search books"
            )
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            
            // Results
            ScrollView {
                VStack(spacing: 0) {
                    // Books
                    ForEach(Array(filteredBooks.enumerated()), id: \.element.id) { index, book in
                        bookRow(book: book)
                            .onTapGesture {
                                handleBookSelection(book)
                            }
                        
                        if index < filteredBooks.count - 1 || selectedBook != nil {
                            Divider()
                                .foregroundStyle(.white.opacity(0.10))
                                .padding(.leading, 60)
                        }
                    }
                    
                    // Clear selection option
                    if selectedBook != nil {
                        Button {
                            selectedBook = nil
                            dismiss()
                            SensoryFeedback.light()
                        } label: {
                            HStack(spacing: 16) {
                                // Icon
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(.white.opacity(0.10))
                                    )
                                
                                // Text
                                Text("Clear Book Selection")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                            }
                            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Empty state
                    if filteredBooks.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
                            Text("No books found")
                                .font(.system(size: 15))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.top, 16)
            }
            .frame(maxHeight: 320)
        }
        .frame(maxWidth: 340)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -50 {
                        dismiss()
                    } else {
                        withAnimation(DesignSystem.Animation.springStandard) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            isFocused = true
        }
    }
    
    // MARK: - Book Row
    
    private func bookRow(book: Book) -> some View {
        HStack(spacing: 16) {
            // Book cover
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 32,
                height: 44
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            
            // Book info
            VStack(alignment: .leading, spacing: 2) {
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
            
            // Selection indicator
            if selectedBook?.id == book.id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    // MARK: - Actions
    
    private func handleBookSelection(_ book: Book) {
        SensoryFeedback.light()
        selectedBook = book
        isPresented = false
        dismiss()
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
