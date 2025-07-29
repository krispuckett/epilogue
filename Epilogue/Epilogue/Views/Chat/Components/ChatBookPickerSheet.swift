import SwiftUI

struct ChatBookPickerSheet: View {
    @Binding var selectedBook: Book?
    @Binding var isPresented: Bool
    let books: [Book]
    @State private var searchText = ""
    @State private var showAllBooks = true
    @State private var selectedFilter: ReadingStatus? = nil
    @Environment(\.dismiss) private var dismiss
    
    // Filtered books based on search and reading status
    private var filteredBooks: [Book] {
        let filtered = if showAllBooks {
            books
        } else if let status = selectedFilter {
            books.filter { $0.readingStatus == status }
        } else {
            books
        }
        
        // Apply search filter
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // All Books pill
                            ChatFilterPill(
                                title: "All Books",
                                isSelected: showAllBooks,
                                count: books.count
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    showAllBooks = true
                                    selectedFilter = nil
                                }
                            }
                            
                            // Status pills
                            ForEach([ReadingStatus.currentlyReading, .wantToRead, .read], id: \.self) { status in
                                ChatFilterPill(
                                    title: statusTitle(for: status),
                                    isSelected: !showAllBooks && selectedFilter == status,
                                    count: countBooks(with: status)
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        showAllBooks = false
                                        selectedFilter = status
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    
                    // Books Grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredBooks) { book in
                                BookGridItem(
                                    book: book,
                                    isSelected: selectedBook?.id == book.id
                                ) {
                                    withAnimation(.spring(response: 0.25)) {
                                        selectedBook = book
                                    }
                                    
                                    // Auto-dismiss after selection
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search books...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedBook != nil {
                        Button("Clear") {
                            selectedBook = nil
                            dismiss()
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func statusTitle(for status: ReadingStatus) -> String {
        switch status {
        case .currentlyReading:
            return "Reading"
        case .wantToRead:
            return "Want to Read"
        case .read:
            return "Finished"
        }
    }
    
    private func countBooks(with status: ReadingStatus) -> Int {
        books.filter { $0.readingStatus == status }.count
    }
}

// MARK: - Filter Pill

struct ChatFilterPill: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2) : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white)
    }
}

// MARK: - Book Grid Item

struct BookGridItem: View {
    let book: Book
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    private var readingProgress: Double? {
        if let pageCount = book.pageCount, pageCount > 0 {
            return Double(book.currentPage) / Double(pageCount)
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Book Cover
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: book.coverImageURL ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure(_), .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 150)
                            .overlay {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Reading progress badge
                if let progress = readingProgress, progress > 0 {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.9))
                        )
                        .offset(x: -4, y: -4)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .overlay(alignment: .topLeading) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white, Color(red: 1.0, green: 0.55, blue: 0.26))
                        .background(Circle().fill(.black))
                        .offset(x: -6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Book Info
            VStack(spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(book.author)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(width: 100)
        }
        .onTapGesture {
            HapticManager.shared.lightTap()
            onTap()
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
            }
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3)) {
                isPressed = pressing
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
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