import SwiftUI
import SwiftData
import CoreML
import NaturalLanguage
import Combine

// MARK: - Note Intelligence Engine
@MainActor
class NoteIntelligenceEngine: ObservableObject {
    static let shared = NoteIntelligenceEngine()
    
    // MARK: - Published Properties
    @Published var smartSections: [SmartSection] = []
    @Published var suggestedTags: Set<String> = []
    @Published var noteConnections: [UUID: Set<UUID>] = [:]
    @Published var isProcessing = false
    
    // MARK: - Private Properties
    private var processingQueue = DispatchQueue(label: "com.epilogue.noteintelligence", qos: .utility)
    private var embeddings: [UUID: [Float]] = [:]
    private var sentimentAnalyzer: NLModel?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Smart Section Types
    enum SectionType: String, CaseIterable {
        case todaysThoughts = "Today's Thoughts"
        case continueReading = "Continue Reading"
        case questionsToExplore = "Questions to Explore"
        case goldenQuotes = "Golden Quotes"
        case connections = "Connected Ideas"
        case recentlyEdited = "Recently Edited"
        case bookCollections = "By Book"
        case themes = "Themes"
    }
    
    // MARK: - Initialization
    private init() {
        setupBackgroundProcessing()
    }
    
    // MARK: - Public Methods
    
    /// Process notes with AI to generate smart sections and connections
    func processNotes(_ notes: [Note], quotes: [Note], questions: [CapturedQuestion]) async {
        await MainActor.run {
            isProcessing = true
        }
        
        // Process in background
        await withTaskGroup(of: Void.self) { group in
            // Generate embeddings
            group.addTask { [weak self] in
                await self?.generateEmbeddings(for: notes + quotes)
            }
            
            // Detect themes
            group.addTask { [weak self] in
                await self?.detectThemes(in: notes + quotes)
            }
            
            // Find connections
            group.addTask { [weak self] in
                await self?.findConnections(between: notes + quotes)
            }
            
            // Categorize into smart sections
            group.addTask { [weak self] in
                await self?.categorizeIntoSections(notes: notes, quotes: quotes, questions: questions)
            }
        }
        
        await MainActor.run {
            isProcessing = false
        }
    }
    
    /// Semantic search across all notes
    func semanticSearch(query: String, in notes: [Note]) async -> [Note] {
        // Generate embedding for query
        let queryEmbedding = await generateEmbedding(for: query)
        
        // Calculate similarity scores - break up for type checking
        var scoredNotes: [(Note, Float)] = []
        for note in notes {
            if let noteEmbedding = embeddings[note.id] {
                let similarity = cosineSimilarity(queryEmbedding, noteEmbedding)
                scoredNotes.append((note, similarity))
            }
        }
        
        // Sort by relevance
        scoredNotes.sort { $0.1 > $1.1 }
        
        // Filter and extract notes
        var results: [Note] = []
        for (note, score) in scoredNotes {
            if score > 0.7 {
                results.append(note)
            }
        }
        
        return results
    }
    
    /// Get AI suggestions for a specific note
    func getSuggestions(for note: Note) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        // Analyze content
        let sentiment = analyzeSentiment(note.content)
        let hasQuestion = note.content.contains("?")
        let wordCount = note.content.split(separator: " ").count
        
        // Generate contextual suggestions
        if hasQuestion {
            suggestions.append(AISuggestion(
                type: .findAnswer,
                title: "Find Answer",
                icon: "sparkles.rectangle.stack",
                action: .search(query: extractQuestion(from: note.content))
            ))
        }
        
        if wordCount < 50 {
            suggestions.append(AISuggestion(
                type: .expand,
                title: "Expand Thought",
                icon: "arrow.up.right.square",
                action: .expand
            ))
        }
        
        if sentiment.isStrong {
            suggestions.append(AISuggestion(
                type: .similar,
                title: "Find Similar",
                icon: "doc.on.doc",
                action: .findSimilar
            ))
        }
        
        if let connections = noteConnections[note.id], !connections.isEmpty {
            suggestions.append(AISuggestion(
                type: .connections,
                title: "View Connections (\(connections.count))",
                icon: "link",
                action: .showConnections
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundProcessing() {
        // Set up periodic background processing
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.performBackgroundIndexing()
                }
            }
            .store(in: &cancellables)
    }
    
    private func generateEmbeddings(for notes: [Note]) async {
        // Use NaturalLanguage framework for basic embeddings
        // In production, you'd use a proper embedding model
        for note in notes {
            let embedding = await generateEmbedding(for: note.content)
            await MainActor.run {
                self.embeddings[note.id] = embedding
            }
        }
    }
    
    private func generateEmbedding(for text: String) async -> [Float] {
        // Simplified embedding generation
        // In production, use CoreML model or API
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var embedding = Array(repeating: Float(0), count: 384) // Standard embedding size
        
        for (index, word) in words.enumerated() where index < embedding.count {
            embedding[index] = Float(word.hashValue % 100) / 100.0
        }
        
        return embedding
    }
    
    private func detectThemes(in notes: [Note]) async {
        // Use NLP to detect common themes
        let tagger = NLTagger(tagSchemes: [.lemma, .nameType])
        var themes = Set<String>()
        
        for note in notes {
            tagger.string = note.content
            
            tagger.enumerateTags(in: note.content.startIndex..<note.content.endIndex,
                                  unit: .word,
                                  scheme: .nameType,
                                  options: [.omitWhitespace, .omitPunctuation]) { tag, range in
                if let tag = tag {
                    themes.insert(tag.rawValue)
                }
                return true
            }
        }
        
        await MainActor.run {
            self.suggestedTags = themes
        }
    }
    
    private func findConnections(between notes: [Note]) async {
        var connections: [UUID: Set<UUID>] = [:]
        
        for i in 0..<notes.count {
            for j in (i+1)..<notes.count {
                let note1 = notes[i]
                let note2 = notes[j]
                
                // Check for connections
                if areConnected(note1, note2) {
                    connections[note1.id, default: []].insert(note2.id)
                    connections[note2.id, default: []].insert(note1.id)
                }
            }
        }
        
        await MainActor.run {
            self.noteConnections = connections
        }
    }
    
    private func areConnected(_ note1: Note, _ note2: Note) -> Bool {
        // Check for various connection types
        
        // Same book
        if let book1 = note1.bookTitle, let book2 = note2.bookTitle, book1 == book2 {
            return true
        }
        
        // Similar embeddings
        if let emb1 = embeddings[note1.id], let emb2 = embeddings[note2.id] {
            let similarity = cosineSimilarity(emb1, emb2)
            if similarity > 0.85 {
                return true
            }
        }
        
        // Shared significant words
        let words1 = Set(note1.content.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(note2.content.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let intersection = words1.intersection(words2)
        
        if intersection.count > min(words1.count, words2.count) / 3 {
            return true
        }
        
        return false
    }
    
    private func categorizeIntoSections(notes: [Note], quotes: [Note], questions: [CapturedQuestion]) async {
        var sections: [SmartSection] = []
        
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        // Today's Thoughts
        var allNotes = notes + quotes
        let todaysNotes = allNotes.filter { note in
            note.dateCreated >= today
        }
        if !todaysNotes.isEmpty {
            sections.append(SmartSection(
                id: UUID(),
                type: .todaysThoughts,
                title: "Today's Thoughts",
                icon: "sun.max",
                notes: todaysNotes,
                color: Color.orange.opacity(0.3)
            ))
        }
        
        // Questions to Explore
        if !questions.isEmpty {
            let questionNotes = questions.map { q in
                Note(
                    type: .note,  // Changed from .insight which doesn't exist
                    content: q.content,
                    bookId: nil,
                    bookTitle: q.book?.title,
                    author: q.book?.author,
                    pageNumber: q.pageNumber,
                    dateCreated: q.timestamp,
                    id: q.id
                )
            }
            sections.append(SmartSection(
                id: UUID(),
                type: .questionsToExplore,
                title: "Questions to Explore",
                icon: "questionmark.circle",
                notes: questionNotes,
                color: Color.purple.opacity(0.3)
            ))
        }
        
        // Golden Quotes (most engaged with)
        var sortedQuotes = quotes
        sortedQuotes.sort { quote1, quote2 in
            // Sort by some engagement metric (for now, use length as proxy)
            quote1.content.count > quote2.content.count
        }
        let goldenQuotes = Array(sortedQuotes.prefix(5))
        
        if !goldenQuotes.isEmpty {
            sections.append(SmartSection(
                id: UUID(),
                type: .goldenQuotes,
                title: "Golden Quotes",
                icon: "star",
                notes: Array(goldenQuotes),
                color: Color.yellow.opacity(0.3)
            ))
        }
        
        // Recently Edited (using dateCreated since dateModified doesn't exist)
        var combinedNotes = notes + quotes
        combinedNotes = combinedNotes.filter { $0.dateCreated >= yesterday }
        combinedNotes.sort { $0.dateCreated > $1.dateCreated }
        let recentlyEdited = Array(combinedNotes.prefix(10))
        
        if !recentlyEdited.isEmpty {
            sections.append(SmartSection(
                id: UUID(),
                type: .recentlyEdited,
                title: "Recently Edited",
                icon: "clock",
                notes: Array(recentlyEdited),
                color: Color.blue.opacity(0.3)
            ))
        }
        
        // Group by books
        let bookGroups = Dictionary(grouping: notes + quotes) { note in
            note.bookTitle ?? "No Book"
        }
        
        for (book, bookNotes) in bookGroups.prefix(3) where bookNotes.count > 2 {
            sections.append(SmartSection(
                id: UUID(),
                type: .bookCollections,
                title: book,
                icon: "book.closed",
                notes: Array(bookNotes.prefix(6)),
                color: Color.green.opacity(0.3)
            ))
        }
        
        await MainActor.run {
            self.smartSections = sections
        }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        // Break up complex expressions for better type checking
        var dotProduct: Float = 0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
        }
        
        var sumA: Float = 0
        for value in a {
            sumA += value * value
        }
        let magnitudeA = sqrt(sumA)
        
        var sumB: Float = 0
        for value in b {
            sumB += value * value
        }
        let magnitudeB = sqrt(sumB)
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    private func analyzeSentiment(_ text: String) -> (sentiment: String, isStrong: Bool) {
        // Simplified sentiment analysis
        let positiveWords = ["love", "amazing", "brilliant", "wonderful", "excellent"]
        let negativeWords = ["hate", "terrible", "awful", "disappointing", "bad"]
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        // Count positive and negative words more efficiently
        var positiveCount = 0
        var negativeCount = 0
        
        for word in words {
            if positiveWords.contains(word) {
                positiveCount += 1
            }
            if negativeWords.contains(word) {
                negativeCount += 1
            }
        }
        
        if positiveCount > negativeCount {
            return ("positive", positiveCount > 2)
        } else if negativeCount > positiveCount {
            return ("negative", negativeCount > 2)
        } else {
            return ("neutral", false)
        }
    }
    
    private func extractQuestion(from text: String) -> String {
        // Extract the main question from text
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        return sentences.first { $0.contains("?") } ?? text
    }
    
    private func performBackgroundIndexing() async {
        // Periodic background processing
        // This would run more sophisticated indexing in production
    }
}

// MARK: - Smart Section Model
struct SmartSection: Identifiable, Equatable {
    let id: UUID
    let type: NoteIntelligenceEngine.SectionType
    let title: String
    let icon: String
    var notes: [Note]  // Changed to var so it can be filtered
    let color: Color
    var isExpanded: Bool = true
    var layoutDensity: LayoutDensity = .comfortable
    
    enum LayoutDensity {
        case compact
        case comfortable
        case spacious
    }
    
    static func == (lhs: SmartSection, rhs: SmartSection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AI Suggestion Model
struct AISuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let icon: String
    let action: SuggestionAction
    
    enum SuggestionType {
        case expand
        case findAnswer
        case similar
        case connections
        case summarize
        case turnIntoQuestion
    }
    
    enum SuggestionAction {
        case expand
        case search(query: String)
        case findSimilar
        case showConnections
        case summarize
        case transform
    }
}