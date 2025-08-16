import SwiftUI
import SwiftData

// MARK: - AI Enhanced Notes View
struct AIEnhancedNotesView: View {
    @StateObject private var ai = EpilogueAI.shared
    @Query(sort: \CapturedNote.timestamp, order: .reverse) private var notes: [CapturedNote]
    @Query(sort: \CapturedQuote.timestamp, order: .reverse) private var quotes: [CapturedQuote]
    
    @State private var selectedNote: CapturedNote?
    @State private var selectedQuote: CapturedQuote?
    @State private var showingAISheet = false
    @State private var aiResponse = ""
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // AI Status
                    EpilogueAIStatusView()
                        .padding(.horizontal)
                    
                    // Recent Quotes Section
                    if !quotes.isEmpty {
                        quotesSection
                    }
                    
                    // Recent Notes Section
                    if !notes.isEmpty {
                        notesSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("AI Reading Assistant")
            .sheet(isPresented: $showingAISheet) {
                aiAnalysisSheet
            }
        }
    }
    
    // MARK: - Quotes Section
    private var quotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Quotes")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quotes.prefix(5)) { quote in
                        QuoteCardWithAI(
                            quote: quote,
                            onAnalyze: {
                                selectedQuote = quote
                                analyzeQuote(quote)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Notes")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(notes.prefix(5)) { note in
                    NoteCardWithAI(
                        note: note,
                        onEnhance: {
                            selectedNote = note
                            enhanceNote(note)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - AI Analysis Sheet
    private var aiAnalysisSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Original Content
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Original", systemImage: "text.quote")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        if let quote = selectedQuote {
                            Text("\"\(quote.text)\"")
                                .font(.system(.body, design: .serif))
                                .italic()
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        } else if let note = selectedNote {
                            Text(note.content)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // AI Analysis
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI Analysis", systemImage: "brain")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        if isAnalyzing {
                            HStack {
                                ProgressView()
                                Text("Analyzing...")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else if !aiResponse.isEmpty {
                            Text(aiResponse)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingAISheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    private func analyzeQuote(_ quote: CapturedQuote) {
        isAnalyzing = true
        aiResponse = ""
        showingAISheet = true
        
        Task {
            // Pass the BookModel directly if available
            let bookModel = quote.book
            aiResponse = await ai.analyzeQuote(quote.text, from: bookModel)
            isAnalyzing = false
        }
    }
    
    private func enhanceNote(_ note: CapturedNote) {
        isAnalyzing = true
        aiResponse = ""
        showingAISheet = true
        
        Task {
            aiResponse = await ai.enhanceNote(note.content)
            isAnalyzing = false
        }
    }
}

// MARK: - Quote Card with AI
struct QuoteCardWithAI: View {
    let quote: CapturedQuote
    let onAnalyze: () -> Void
    @StateObject private var ai = EpilogueAI.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quote text
            Text("\"\(String(quote.text.prefix(100)))...\"")
                .font(.system(.callout, design: .serif))
                .italic()
                .lineLimit(3)
            
            // Book info
            if let book = quote.book {
                Text(book.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // AI Button
            if ai.isAvailable {
                Button {
                    onAnalyze()
                } label: {
                    Label("Analyze", systemImage: "sparkles")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Note Card with AI
struct NoteCardWithAI: View {
    let note: CapturedNote
    let onEnhance: () -> Void
    @StateObject private var ai = EpilogueAI.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                // Note content
                Text(note.content)
                    .font(.callout)
                    .lineLimit(3)
                
                // Metadata
                HStack {
                    if let bookTitle = note.book?.title {
                        Text(bookTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(note.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // AI Button
            if ai.isAvailable {
                Button {
                    onEnhance()
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Extension removed - toNote() already exists