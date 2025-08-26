import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditBook = false
    @State private var showingAddQuote = false
    @State private var showingAddNote = false
    @State private var showingAIChat = false
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Book Header
                HStack(alignment: .top, spacing: 16) {
                    if let imageData = book.coverImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 180)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 180)
                            .overlay(
                                Image(systemName: "book.closed")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let genre = book.genre {
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        if let year = book.publicationYear {
                            Text("Published \(String(year))")
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
                }
                .padding(.horizontal)
                
                // Reading Progress
                if book.readingProgress > 0 || book.totalPages != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reading Progress")
                            .font(.headline)
                        
                        ProgressView(value: book.readingProgress)
                            .tint(.blue)
                        
                        HStack {
                            Text("\(book.progressPercentage)% complete")
                            Spacer()
                            if let current = book.currentPage,
                               let total = book.totalPages {
                                Text("Page \(current) of \(total)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        if let timeToFinish = book.estimatedTimeToFinish {
                            Text("Estimated time to finish: \(formatTimeInterval(timeToFinish))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Description
                if let description = book.bookDescription {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Content Tabs
                TabView(selection: $selectedTab) {
                    QuotesTabView(book: book)
                        .tag(0)
                        .tabItem {
                            Label("Quotes", systemImage: "quote.bubble")
                        }
                    
                    NotesTabView(book: book)
                        .tag(1)
                        .tabItem {
                            Label("Notes", systemImage: "note.text")
                        }
                    
                    AISessionsTabView(book: book)
                        .tag(2)
                        .tabItem {
                            Label("AI Chat", systemImage: "message")
                        }
                    
                    StatsTabView(book: book)
                        .tag(3)
                        .tabItem {
                            Label("Stats", systemImage: "chart.bar")
                        }
                }
                .frame(height: 400)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditBook = true }) {
                        Label("Edit Book", systemImage: "pencil")
                    }
                    
                    Button(action: { showingAddQuote = true }) {
                        Label("Add Quote", systemImage: "quote.bubble.fill")
                    }
                    
                    Button(action: { showingAddNote = true }) {
                        Label("Add Note", systemImage: "note.text.badge.plus")
                    }
                    
                    Button(action: { showingAIChat = true }) {
                        Label("Start AI Chat", systemImage: "message.fill")
                    }
                    
                    Button(action: updateReadingProgress) {
                        Label("Update Progress", systemImage: "book.pages")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditBook) {
            EditBookView(book: book)
        }
        .sheet(isPresented: $showingAddQuote) {
            AddQuoteView(book: book)
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteView(book: book)
        }
        .sheet(isPresented: $showingAIChat) {
            AISessionView(book: book)
        }
        .onAppear {
            book.lastOpened = Date()
        }
    }
    
    private func updateReadingProgress() {
        // Implementation for updating reading progress
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct QuotesTabView: View {
    let book: Book
    @State private var searchText = ""
    
    var filteredQuotes: [Quote] {
        guard let quotes = book.quotes else { return [] }
        
        if searchText.isEmpty {
            return quotes.sorted { $0.dateCreated > $1.dateCreated }
        } else {
            return quotes.filter {
                $0.text.localizedCaseInsensitiveContains(searchText) ||
                ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }.sorted { $0.dateCreated > $1.dateCreated }
        }
    }
    
    var body: some View {
        VStack {
            if filteredQuotes.isEmpty {
                ContentUnavailableView(
                    "No Quotes",
                    systemImage: "quote.bubble",
                    description: Text("Add your first quote from this book")
                )
            } else {
                List(filteredQuotes) { quote in
                    QuoteRowView(quote: quote)
                }
                .searchable(text: $searchText, prompt: "Search quotes")
            }
        }
    }
}

struct NotesTabView: View {
    let book: Book
    @State private var searchText = ""
    
    var filteredNotes: [Note] {
        guard let notes = book.notes else { return [] }
        
        if searchText.isEmpty {
            return notes.sorted { $0.dateModified > $1.dateModified }
        } else {
            return notes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.dateModified > $1.dateModified }
        }
    }
    
    var body: some View {
        VStack {
            if filteredNotes.isEmpty {
                ContentUnavailableView(
                    "No Notes",
                    systemImage: "note.text",
                    description: Text("Add your first note for this book")
                )
            } else {
                List(filteredNotes) { note in
                    NoteRowView(note: note)
                }
                .searchable(text: $searchText, prompt: "Search notes")
            }
        }
    }
}

struct AISessionsTabView: View {
    let book: Book
    
    var sessions: [AISession] {
        book.aiSessions?.sorted { $0.lastAccessed > $1.lastAccessed } ?? []
    }
    
    var body: some View {
        VStack {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No AI Conversations",
                    systemImage: "message",
                    description: Text("Start an AI chat about this book")
                )
            } else {
                List(sessions) { session in
                    AISessionRowView(session: session)
                }
            }
        }
    }
}

struct StatsTabView: View {
    let book: Book
    
    var body: some View {
        VStack(spacing: 16) {
            StatCard(title: "Quotes", value: "\(book.quotes?.count ?? 0)", icon: "quote.bubble")
            StatCard(title: "Notes", value: "\(book.notes?.count ?? 0)", icon: "note.text")
            StatCard(title: "AI Chats", value: "\(book.aiSessions?.count ?? 0)", icon: "message")
            
            if let sessions = book.readingSessions, !sessions.isEmpty {
                let totalTime = sessions.reduce(0) { $0 + $1.duration }
                StatCard(
                    title: "Reading Time",
                    value: formatReadingTime(totalTime),
                    icon: "clock"
                )
            }
        }
        .padding()
    }
    
    private func formatReadingTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: Book(
            title: "Sample Book",
            author: "Sample Author",
            genre: "Fiction",
            totalPages: 300
        ))
        .modelContainer(ModelContainer.previewContainer)
    }
}