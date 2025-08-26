import SwiftUI
import SwiftData

struct BookListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.lastOpened, order: .reverse) private var books: [Book]
    @State private var searchText = ""
    @State private var showingAddBook = false
    @State private var sortOrder: SortOrder = .lastOpened
    
    enum SortOrder: String, CaseIterable {
        case lastOpened = "Last Opened"
        case title = "Title"
        case author = "Author"
        case dateAdded = "Date Added"
        case progress = "Reading Progress"
    }
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books.sorted(by: sortPredicate)
        } else {
            return books.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText) ||
                (book.genre?.localizedCaseInsensitiveContains(searchText) ?? false)
            }.sorted(by: sortPredicate)
        }
    }
    
    var sortPredicate: (Book, Book) -> Bool {
        switch sortOrder {
        case .lastOpened:
            return { ($0.lastOpened ?? Date.distantPast) > ($1.lastOpened ?? Date.distantPast) }
        case .title:
            return { $0.title < $1.title }
        case .author:
            return { $0.author < $1.author }
        case .dateAdded:
            return { $0.dateAdded > $1.dateAdded }
        case .progress:
            return { $0.readingProgress > $1.readingProgress }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredBooks) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookRowView(book: book)
                    }
                }
                .onDelete(perform: deleteBooks)
            }
            .searchable(text: $searchText, prompt: "Search books, authors, or genres")
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddBook = true }) {
                        Label("Add Book", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
            .overlay {
                if books.isEmpty {
                    ContentUnavailableView(
                        "No Books Yet",
                        systemImage: "books.vertical",
                        description: Text("Add your first book to get started")
                    )
                }
            }
        }
    }
    
    private func deleteBooks(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredBooks[index])
            }
        }
    }
}

struct BookRowView: View {
    let book: Book
    
    var body: some View {
        HStack {
            if let imageData = book.coverImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 90)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if book.readingProgress > 0 {
                    ProgressView(value: book.readingProgress)
                        .tint(.blue)
                    
                    Text("\(book.progressPercentage)% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let rating = book.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack {
                if let quotesCount = book.quotes?.count, quotesCount > 0 {
                    Label("\(quotesCount)", systemImage: "quote.bubble")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notesCount = book.notes?.count, notesCount > 0 {
                    Label("\(notesCount)", systemImage: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BookListView()
        .modelContainer(ModelContainer.previewContainer)
}