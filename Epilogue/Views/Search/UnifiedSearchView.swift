import SwiftUI
import SwiftData

struct UnifiedSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .all
    @State private var selectedBook: Book?
    @State private var searchResults: SearchResults = SearchResults()
    @State private var isSearching = false
    
    @Query private var books: [Book]
    
    enum SearchScope: String, CaseIterable {
        case all = "All"
        case quotes = "Quotes"
        case notes = "Notes"
    }
    
    struct SearchResults {
        var quotes: [Quote] = []
        var notes: [Note] = []
        
        var isEmpty: Bool {
            quotes.isEmpty && notes.isEmpty
        }
        
        var totalCount: Int {
            quotes.count + notes.count
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Book Filter
                if !books.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            FilterChip(
                                title: "All Books",
                                isSelected: selectedBook == nil,
                                action: { selectedBook = nil }
                            )
                            
                            ForEach(books) { book in
                                FilterChip(
                                    title: book.title,
                                    isSelected: selectedBook?.id == book.id,
                                    action: { selectedBook = book }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
                
                // Search Results
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Your Library",
                        systemImage: "magnifyingglass",
                        description: Text("Find quotes and notes across all your books")
                    )
                } else if searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        if searchScope == .all || searchScope == .quotes {
                            if !searchResults.quotes.isEmpty {
                                Section("Quotes (\(searchResults.quotes.count))") {
                                    ForEach(searchResults.quotes) { quote in
                                        SearchQuoteRow(quote: quote)
                                    }
                                }
                            }
                        }
                        
                        if searchScope == .all || searchScope == .notes {
                            if !searchResults.notes.isEmpty {
                                Section("Notes (\(searchResults.notes.count))") {
                                    ForEach(searchResults.notes) { note in
                                        SearchNoteRow(note: note)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search quotes and notes")
            .searchScopes($searchScope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .onChange(of: searchText) { _, newValue in
                performSearch(newValue)
            }
            .onChange(of: selectedBook) { _, _ in
                if !searchText.isEmpty {
                    performSearch(searchText)
                }
            }
            .onChange(of: searchScope) { _, _ in
                if !searchText.isEmpty {
                    performSearch(searchText)
                }
            }
        }
    }
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = SearchResults()
            return
        }
        
        isSearching = true
        
        Task {
            do {
                let results = try await Task.detached {
                    var quotes: [Quote] = []
                    var notes: [Note] = []
                    
                    if searchScope == .all || searchScope == .quotes {
                        quotes = try SearchService.searchQuotes(
                            query,
                            in: modelContext,
                            for: selectedBook
                        )
                    }
                    
                    if searchScope == .all || searchScope == .notes {
                        notes = try SearchService.searchNotes(
                            query,
                            in: modelContext,
                            for: selectedBook
                        )
                    }
                    
                    return SearchResults(quotes: quotes, notes: notes)
                }.value
                
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                print("Search error: \(error)")
                isSearching = false
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

struct SearchQuoteRow: View {
    let quote: Quote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let book = quote.book {
                HStack {
                    Image(systemName: "book.closed")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(book.title)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
            
            Text(quote.text)
                .font(.body)
                .lineLimit(3)
            
            HStack {
                if let page = quote.pageNumber {
                    Text("Page \(page)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if quote.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                Text(quote.dateCreated, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchNoteRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let book = note.book {
                HStack {
                    Image(systemName: "book.closed")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(book.title)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
            }
            
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text(note.dateModified, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    UnifiedSearchView()
        .modelContainer(ModelContainer.previewContainer)
}
