import SwiftUI

struct NotesSearchPalette: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var searchTokens: [SearchToken] = []
    @FocusState private var isFocused: Bool
    @EnvironmentObject var notesViewModel: NotesViewModel
    @State private var containerOpacity: Double = 0
    @State private var isAnimating = false
    
    // Search results
    @State private var filteredNotes: [Note] = []
    
    // Token types for spotlight-like parsing
    enum TokenType {
        case author(String)
        case book(String)
        case content(String)
        case type(NoteType)
        case date(String)
        
        var color: Color {
            switch self {
            case .author:
                return Color(red: 0.6, green: 0.4, blue: 0.8) // Purple
            case .book:
                return Color(red: 0.4, green: 0.6, blue: 0.9) // Blue
            case .content:
                return Color(red: 1.0, green: 0.55, blue: 0.26) // Orange
            case .type:
                return Color(red: 0.3, green: 0.7, blue: 0.5) // Green
            case .date:
                return Color(red: 0.9, green: 0.3, blue: 0.3) // Red
            }
        }
        
        var icon: String {
            switch self {
            case .author:
                return "person.fill"
            case .book:
                return "book.fill"
            case .content:
                return "quote.bubble.fill"
            case .type:
                return "tag.fill"
            case .date:
                return "calendar"
            }
        }
    }
    
    struct SearchToken: Identifiable {
        let id = UUID()
        let type: TokenType
        let value: String
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPalette()
                }
            
            VStack {
                Spacer().frame(height: UIScreen.main.bounds.height * 0.25)
                
                // Glass container taking 3/4 of screen
                VStack(spacing: 0) {
                    // Header with search field
                    VStack(spacing: 16) {
                        // Drag indicator
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 36, height: 5)
                            .padding(.top, 12)
                        
                        // Search field with tokens
                        VStack(spacing: 12) {
                            // Token display
                            if !searchTokens.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(searchTokens) { token in
                                            TokenView(token: token) {
                                                removeToken(token)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            // Search input
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.white.opacity(0.6))
                                    .font(.system(size: 18, weight: .medium))
                                
                                TextField("Search notes...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                                    .focused($isFocused)
                                    .submitLabel(.search)
                                    .onChange(of: searchText) { _, newValue in
                                        parseSearchText(newValue)
                                        performSearch()
                                    }
                                    .onSubmit {
                                        performSearch()
                                    }
                                
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        searchTokens = []
                                        performSearch()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        
                        // Quick filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                SearchFilterChip(title: "Quotes", icon: "quote.bubble.fill", isSelected: false) {
                                    addToken(.type(.quote))
                                }
                                SearchFilterChip(title: "Notes", icon: "note.text", isSelected: false) {
                                    addToken(.type(.note))
                                }
                                SearchFilterChip(title: "Today", icon: "calendar", isSelected: false) {
                                    addToken(.date("today"))
                                }
                                SearchFilterChip(title: "This Week", icon: "calendar", isSelected: false) {
                                    addToken(.date("week"))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 16)
                    }
                    .glassEffect(in: RoundedRectangle(cornerRadius: 0))
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Search results
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if filteredNotes.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.white.opacity(0.3))
                                    
                                    Text("Search your notes")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.6))
                                    
                                    Text("Try searching by author, book title, or content")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(filteredNotes) { note in
                                    SearchResultRow(note: note, searchTokens: searchTokens) {
                                        // Handle selection
                                        dismissPalette()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .frame(maxHeight: .infinity)
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 28))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            Color.white.opacity(0.2),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                .opacity(containerOpacity)
            }
        }
        .onAppear {
            // Reset and load all notes
            filteredNotes = notesViewModel.notes
            
            // Animate appearance
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                containerOpacity = 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
    
    // MARK: - Search Logic
    
    private func parseSearchText(_ text: String) {
        // Parse special tokens like "author:name" or "book:title"
        let patterns = [
            "author:": TokenType.author,
            "book:": TokenType.book,
            "type:": { (value: String) -> TokenType? in
                if value == "quote" { return .type(.quote) }
                if value == "note" { return .type(.note) }
                return nil
            }
        ]
        
        // Simple token parsing (can be enhanced)
        if text.contains("author:") {
            if let range = text.range(of: "author:") {
                let value = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    addToken(.author(value))
                    searchText = ""
                }
            }
        }
    }
    
    private func addToken(_ type: TokenType) {
        let token = SearchToken(type: type, value: describeToken(type))
        searchTokens.append(token)
        performSearch()
    }
    
    private func removeToken(_ token: SearchToken) {
        searchTokens.removeAll { $0.id == token.id }
        performSearch()
    }
    
    private func describeToken(_ type: TokenType) -> String {
        switch type {
        case .author(let name):
            return name
        case .book(let title):
            return title
        case .content(let text):
            return text
        case .type(let noteType):
            return noteType == .quote ? "Quote" : "Note"
        case .date(let period):
            return period
        }
    }
    
    private func performSearch() {
        var results = notesViewModel.notes
        
        // Apply token filters
        for token in searchTokens {
            switch token.type {
            case .type(let noteType):
                results = results.filter { $0.type == noteType }
            case .author(let name):
                results = results.filter { 
                    $0.author?.lowercased().contains(name.lowercased()) ?? false 
                }
            case .book(let title):
                results = results.filter { 
                    $0.bookTitle?.lowercased().contains(title.lowercased()) ?? false 
                }
            case .content(let text):
                results = results.filter { 
                    $0.content.lowercased().contains(text.lowercased())
                }
            case .date(_):
                // TODO: Implement date filtering
                break
            }
        }
        
        // Apply general search text
        if !searchText.isEmpty {
            results = results.filter { note in
                note.content.lowercased().contains(searchText.lowercased()) ||
                (note.author?.lowercased().contains(searchText.lowercased()) ?? false) ||
                (note.bookTitle?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            filteredNotes = results
        }
    }
    
    private func dismissPalette() {
        isFocused = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            containerOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }
}

// MARK: - Subviews

struct TokenView: View {
    let token: NotesSearchPalette.SearchToken
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: token.type.icon)
                .font(.system(size: 12))
            
            Text(token.value)
                .font(.system(size: 14, weight: .medium))
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(token.type.color.gradient)
        .clipShape(Capsule())
    }
}

struct SearchFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        Color.white.opacity(isSelected ? 0.3 : 0.1),
                        lineWidth: 1
                    )
            }
        }
    }
}

struct SearchResultRow: View {
    let note: Note
    let searchTokens: [NotesSearchPalette.SearchToken]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Note type and metadata
                HStack {
                    Label(note.type == .quote ? "Quote" : "Note", 
                          systemImage: note.type == .quote ? "quote.bubble.fill" : "note.text")
                        .font(.caption)
                        .foregroundStyle(note.type == .quote ? 
                            Color(red: 1.0, green: 0.55, blue: 0.26) : 
                            Color(red: 0.4, green: 0.6, blue: 0.9))
                    
                    Spacer()
                    
                    if let author = note.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                
                // Content preview
                Text(note.content)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Book info
                if let bookTitle = note.bookTitle {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 10))
                        Text(bookTitle)
                            .font(.caption)
                        
                        if let page = note.pageNumber {
                            Text("• p. \(page)")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
                
                // Date
                Text(note.dateCreated.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NotesSearchPalette(isPresented: .constant(true))
        .environmentObject(NotesViewModel())
}