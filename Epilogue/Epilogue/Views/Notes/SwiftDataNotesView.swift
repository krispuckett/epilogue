import SwiftUI
import SwiftData

// MARK: - SwiftData Notes View

struct SwiftDataNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    
    // Queries
    @Query(sort: \Note.timestamp, order: .reverse) private var notes: [Note]
    @Query(sort: \Quote.timestamp, order: .reverse) private var quotes: [Quote]
    @Query(sort: \Question.timestamp, order: .reverse) private var questions: [Question]
    
    @State private var selectedFilter: ContentFilter = .all
    @State private var selectedBook: Book?
    @State private var searchText = ""
    
    enum ContentFilter: String, CaseIterable {
        case all = "All"
        case notes = "Notes"
        case quotes = "Quotes"
        case questions = "Questions"
        
        var icon: String {
            switch self {
            case .all: return "square.stack.3d.up"
            case .notes: return "note.text"
            case .quotes: return "quote.bubble"
            case .questions: return "questionmark.circle"
            }
        }
    }
    
    // Computed properties for filtered content
    private var filteredItems: [(id: String, type: ContentType, timestamp: Date)] {
        var items: [(id: String, type: ContentType, timestamp: Date)] = []
        
        switch selectedFilter {
        case .all:
            items += notes.map { (id: $0.id.uuidString, type: ContentType.note($0), timestamp: $0.timestamp) }
            items += quotes.map { (id: $0.id.uuidString, type: ContentType.quote($0), timestamp: $0.timestamp) }
            items += questions.map { (id: $0.id.uuidString, type: ContentType.question($0), timestamp: $0.timestamp) }
        case .notes:
            items = notes.map { (id: $0.id.uuidString, type: ContentType.note($0), timestamp: $0.timestamp) }
        case .quotes:
            items = quotes.map { (id: $0.id.uuidString, type: ContentType.quote($0), timestamp: $0.timestamp) }
        case .questions:
            items = questions.map { (id: $0.id.uuidString, type: ContentType.question($0), timestamp: $0.timestamp) }
        }
        
        // Filter by book if selected
        if let selectedBook = selectedBook {
            items = items.filter { item in
                switch item.type {
                case .note(let note): return note.bookLocalId == selectedBook.localId.uuidString
                case .quote(let quote): return quote.bookLocalId == selectedBook.localId.uuidString
                case .question(let question): return question.bookLocalId == selectedBook.localId.uuidString
                }
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter { item in
                switch item.type {
                case .note(let note): return note.content.localizedCaseInsensitiveContains(searchText)
                case .quote(let quote): return quote.text.localizedCaseInsensitiveContains(searchText)
                case .question(let question): return question.content.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        return items.sorted { $0.timestamp > $1.timestamp }
    }
    
    enum ContentType {
        case note(Note)
        case quote(Quote)
        case question(Question)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Filter pills
                            filterSection
                            
                            // Book filter
                            bookFilterSection
                            
                            // Content
                            LazyVStack(spacing: 16) {
                                ForEach(filteredItems, id: \.id) { item in
                                    contentCard(for: item.type)
                                        .id(item.id)
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                                            removal: .scale(scale: 0.95).combined(with: .opacity)
                                        ))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        .padding(.bottom, 100)
                    }
                    .onChange(of: navigationCoordinator.highlightedNoteID) { _, noteID in
                        if let noteID = noteID {
                            withAnimation {
                                proxy.scrollTo(noteID.uuidString, anchor: .center)
                            }
                            // Clear after scrolling
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                navigationCoordinator.highlightedNoteID = nil
                            }
                        }
                    }
                    .onChange(of: navigationCoordinator.highlightedQuoteID) { _, quoteID in
                        if let quoteID = quoteID {
                            withAnimation {
                                proxy.scrollTo(quoteID.uuidString, anchor: .center)
                            }
                            // Clear after scrolling
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                navigationCoordinator.highlightedQuoteID = nil
                            }
                        }
                    }
                }
            }
            .navigationTitle("All Content")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search notes, quotes, and questions")
        }
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ContentFilter.allCases, id: \.self) { filter in
                    filterPill(for: filter)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func filterPill(for filter: ContentFilter) -> some View {
        let count: Int = switch filter {
        case .all: notes.count + quotes.count + questions.count
        case .notes: notes.count
        case .quotes: quotes.count
        case .questions: questions.count
        }
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14))
                Text(filter.rawValue)
                    .font(.system(size: 14, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedFilter == filter ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2) : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(selectedFilter == filter ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .foregroundStyle(selectedFilter == filter ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white)
    }
    
    // MARK: - Book Filter Section
    
    private var bookFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All books pill
                Button {
                    withAnimation {
                        selectedBook = nil
                    }
                } label: {
                    Text("All Books")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedBook == nil ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(selectedBook == nil ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .foregroundStyle(selectedBook == nil ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white)
                
                // Individual book pills
                ForEach(libraryViewModel.books) { book in
                    bookPill(for: book)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func bookPill(for book: Book) -> some View {
        Button {
            withAnimation {
                selectedBook = book
            }
        } label: {
            HStack(spacing: 8) {
                if let coverURL = book.coverImageURL {
                    AsyncImage(url: URL(string: coverURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 20, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                
                Text(book.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedBook?.id == book.id ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2) : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(selectedBook?.id == book.id ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .foregroundStyle(selectedBook?.id == book.id ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white)
    }
    
    // MARK: - Content Cards
    
    @ViewBuilder
    private func contentCard(for type: ContentType) -> some View {
        switch type {
        case .note(let note):
            MiniNoteCard(note: note) {
                // Handle navigation if needed
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 2)
                    .opacity(navigationCoordinator.highlightedNoteID == note.id ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: navigationCoordinator.highlightedNoteID)
            )
            
        case .quote(let quote):
            MiniQuoteCard(quote: quote) {
                // Handle navigation if needed
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 2)
                    .opacity(navigationCoordinator.highlightedQuoteID == quote.id ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: navigationCoordinator.highlightedQuoteID)
            )
            
        case .question(let question):
            QuestionCard(question: question)
        }
    }
}

// MARK: - Question Card

struct QuestionCard: View {
    let question: Question
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Question")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                if question.isAnswered {
                    Label("Answered", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green.opacity(0.8))
                }
                
                Text(question.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            // Question text
            Text(question.content)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
            
            // Answer if available
            if let answer = question.answer {
                Text(answer)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .padding(.top, 4)
            }
            
            // Book context
            if let book = question.book {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text(book.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    
                    if let pageNumber = question.pageNumber {
                        Text("• p.\(pageNumber)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    SwiftDataNotesView()
        .environmentObject(NavigationCoordinator.shared)
        .environmentObject(LibraryViewModel())
        .preferredColorScheme(.dark)
}