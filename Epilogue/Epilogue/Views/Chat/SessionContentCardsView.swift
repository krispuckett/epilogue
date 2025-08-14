import SwiftUI

// MARK: - Session Content Cards View
struct SessionContentCardsView: View {
    let session: ProcessedAmbientSession
    let bookTitle: String?
    let bookAuthor: String?
    
    @StateObject private var processor = TrueAmbientProcessor.shared
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    private enum ContentType {
        case quote
        case note
        case question
        case progressUpdate
        case bookReference
        case suggestion
    }
    
    // Item wrapper for ForEach compatibility
    private struct ContentItem: Identifiable {
        let id: String
        let type: ContentType
        let timestamp: Date
        let content: Any
    }
    
    // Combine all items with their types and timestamps for chronological ordering
    private var allItems: [ContentItem] {
        var items: [ContentItem] = []
        
        // Add quotes
        for (index, quote) in session.quotes.enumerated() {
            items.append(ContentItem(
                id: "quote_\(index)_\(quote.timestamp.timeIntervalSince1970)",
                type: .quote,
                timestamp: quote.timestamp,
                content: quote
            ))
        }
        
        // Add notes
        for (index, note) in session.notes.enumerated() {
            items.append(ContentItem(
                id: "note_\(index)_\(note.timestamp.timeIntervalSince1970)",
                type: .note,
                timestamp: note.timestamp,
                content: note
            ))
        }
        
        // Add questions
        for (index, question) in session.questions.enumerated() {
            items.append(ContentItem(
                id: "question_\(index)_\(question.timestamp.timeIntervalSince1970)",
                type: .question,
                timestamp: question.timestamp,
                content: question
            ))
        }
        
        // Sort by timestamp
        return items.sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Intelligent suggestions at the top
                IntelligentSuggestionsSection(
                    session: session,
                    processor: processor,
                    library: libraryViewModel.books
                )
                
                // Original content items
                ForEach(allItems) { item in
                    contentView(for: item)
                }
                
                // Progress updates detected
                ProgressUpdatesSection(
                    content: session.summary,
                    processor: processor
                )
                
                // Book references
                BookReferencesSection(
                    content: session.summary,
                    processor: processor,
                    library: libraryViewModel.books
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private func contentView(for item: ContentItem) -> some View {
        switch item.type {
        case .quote:
            if let quote = item.content as? ExtractedQuote {
                ChatQuoteCard(
                    quote: quote.text,
                    bookTitle: bookTitle,
                    bookAuthor: bookAuthor,
                    timestamp: quote.timestamp
                )
            }
        case .note:
            if let note = item.content as? ExtractedNote {
                ChatNoteCard(
                    content: note.text,
                    bookTitle: bookTitle,
                    bookAuthor: bookAuthor,
                    timestamp: note.timestamp
                )
            }
        case .question:
            if let question = item.content as? ExtractedQuestion {
                ChatQuestionCard(
                    question: question.text,
                    response: question.context ?? "Thinking about this...",
                    bookTitle: bookTitle,
                    timestamp: question.timestamp
                )
            }
        case .progressUpdate, .bookReference, .suggestion:
            // These are handled by separate sections
            EmptyView()
        }
    }
}

// MARK: - Chat Quote Card
struct ChatQuoteCard: View {
    let quote: String
    let bookTitle: String?
    let bookAuthor: String?
    let timestamp: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Drop cap quote mark
            Text("\u{201C}")
                .font(.custom("Georgia", size: 60))
                .foregroundStyle(Color.warmAmber.opacity(0.6))
                .offset(x: -8, y: 15)
                .frame(height: 0)
            
            // Quote text
            Text(quote)
                .font(.custom("Georgia", size: 18))
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(6)
                .padding(.top, 8)
            
            // Attribution
            HStack {
                if let title = bookTitle {
                    Text("— \(title)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text(timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.8))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.warmAmber.opacity(0.3),
                            Color.warmAmber.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - Chat Note Card
struct ChatNoteCard: View {
    let content: String
    let bookTitle: String?
    let bookAuthor: String?
    let timestamp: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.warmAmber.opacity(0.5))
            }
            
            // Note content
            Text(content)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(4)
            
            // Footer
            HStack {
                if let title = bookTitle {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.13, green: 0.125, blue: 0.12).opacity(0.9))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

// MARK: - Chat Question Card
struct ChatQuestionCard: View {
    let question: String
    let response: String
    let bookTitle: String?
    let timestamp: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.warmAmber.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Q label and question
                HStack(alignment: .top, spacing: 8) {
                    Text("Q")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.warmAmber)
                    
                    Text(question)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.95))
                }
                
                // A label and response
                HStack(alignment: .top, spacing: 8) {
                    Text("A")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(response)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                        .italic()
                }
            }
            
            // Footer
            HStack {
                if let title = bookTitle {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.14, green: 0.135, blue: 0.13).opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.warmAmber.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

// MARK: - Intelligent Suggestions Section

struct IntelligentSuggestionsSection: View {
    let session: ProcessedAmbientSession
    let processor: TrueAmbientProcessor
    let library: [Book]
    
    // Suggestions temporarily disabled - was SessionSuggestion
    @State private var suggestions: [String] = []
    @State private var showingSuggestions = true
    
    var body: some View {
        if !suggestions.isEmpty && showingSuggestions {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Suggested Actions", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.warmAmber)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingSuggestions = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                
                ForEach(suggestions, id: \.self) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
            }
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.warmAmber.opacity(0.2), lineWidth: 0.5)
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
            .onAppear {
                // Create a temporary AmbientSession for processor  
                let ambientSession = AmbientSession(startTime: Date().addingTimeInterval(-session.duration))
                ambientSession.endTime = Date()
                // processedData no longer needed - using SwiftData model
                
                // Suggestions temporarily disabled
                suggestions = []
            }
        }
    }
}

struct SuggestionCard: View {
    // Suggestion temporarily disabled - using string for now
    let suggestion: String
    @State private var isPressed = false
    
    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            // Action disabled for now
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.warmAmber)
                    .frame(width: 32, height: 32)
                
                Text(suggestion)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Progress Updates Section

struct ProgressUpdatesSection: View {
    let content: String
    let processor: TrueAmbientProcessor
    
    // Progress updates temporarily disabled
    @State private var progressUpdates: [String] = []
    
    var body: some View {
        if !progressUpdates.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Reading Progress", systemImage: "bookmark.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.warmAmber.opacity(0.8))
                
                ForEach(progressUpdates, id: \.self) { update in
                    ProgressUpdateCard(update: update)
                }
            }
            .onAppear {
                // Progress updates temporarily disabled
                progressUpdates = []
            }
        }
    }
}

struct ProgressUpdateCard: View {
    // Update temporarily disabled - using string for now
    let update: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.warmAmber.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress Update")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                
                Text(update)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                HapticManager.shared.lightTap()
                // Action disabled for now
            } label: {
                Text("Update")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.warmAmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.warmAmber.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.warmAmber.opacity(0.1), lineWidth: 0.5)
        }
    }
}

// MARK: - Book References Section

struct BookReferencesSection: View {
    let content: String
    let processor: TrueAmbientProcessor
    let library: [Book]
    
    // Book references temporarily disabled
    @State private var bookReferences: [String] = []
    
    var body: some View {
        if !bookReferences.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Book References", systemImage: "book.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.warmAmber.opacity(0.8))
                
                ForEach(bookReferences, id: \.self) { reference in
                    BookReferenceCard(reference: reference)
                }
            }
            .onAppear {
                // Book references temporarily disabled
                bookReferences = []
            }
        }
    }
}

struct BookReferenceCard: View {
    // Reference temporarily disabled - using string for now
    let reference: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.warmAmber.opacity(0.6))
                .frame(width: 40, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reference)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    
                    Text("Book Reference")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.warmAmber.opacity(0.1), lineWidth: 0.5)
        }
    }
}