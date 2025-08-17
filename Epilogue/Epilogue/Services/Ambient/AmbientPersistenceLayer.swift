import Foundation
import SwiftData
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientPersistence")

/// Single write path for all ambient data persistence
/// Prevents race conditions and ensures data integrity
@MainActor
public class AmbientPersistenceLayer {
    // MARK: - Properties
    private let writeQueue = DispatchQueue(label: "ambient.persistence", qos: .userInitiated)
    private var modelContext: ModelContext?
    private var currentSession: AmbientSession?
    private var pendingWrites: [PendingWrite] = []
    private var writeTimer: Timer?
    
    // Batch configuration
    private let batchSize = 10
    private let batchDelay: TimeInterval = 0.5
    
    // MARK: - Types
    private struct PendingWrite {
        let content: AmbientProcessedContent
        let completion: ((Bool) -> Void)?
    }
    
    // MARK: - Initialization
    init() {
        setupBatchTimer()
    }
    
    // MARK: - Public Methods
    
    /// Configure with model context and session
    func configure(modelContext: ModelContext, session: AmbientSession) {
        self.modelContext = modelContext
        self.currentSession = session
        logger.info("Persistence layer configured for session: \(session.id)")
    }
    
    /// Save content with guaranteed single write path
    public func save(_ content: AmbientProcessedContent, completion: ((Bool) -> Void)? = nil) {
        writeQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Add to pending writes
            self.pendingWrites.append(PendingWrite(content: content, completion: completion))
            
            // Process immediately if batch is full
            if self.pendingWrites.count >= self.batchSize {
                Task { @MainActor in
                    await self.processPendingWrites()
                }
            }
        }
    }
    
    /// Save question with answer (atomic operation)
    func saveQuestionWithAnswer(_ question: String, answer: String?, book: Book?) {
        let content = AmbientProcessedContent(
            text: question,
            type: .question,
            response: answer,
            bookTitle: book?.title,
            bookAuthor: book?.author
        )
        
        save(content) { success in
            if success {
                logger.info("Question saved with answer: \(question.prefix(30))...")
            }
        }
    }
    
    /// Update existing question with answer
    public func updateQuestionAnswer(questionText: String, answer: String) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        let descriptor = FetchDescriptor<CapturedQuestion>(
            predicate: #Predicate { $0.content == questionText }
        )
        
        do {
            if let questions = try? modelContext.fetch(descriptor),
               let question = questions.first {
                question.answer = answer
                question.isAnswered = true
                
                try modelContext.save()
                logger.info("Updated question with answer: \(questionText.prefix(30))...")
                return true
            }
        } catch {
            logger.error("Failed to update question: \(error)")
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func setupBatchTimer() {
        writeTimer = Timer.scheduledTimer(withTimeInterval: batchDelay, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.processPendingWrites()
            }
        }
    }
    
    @MainActor
    private func processPendingWrites() async {
        guard !pendingWrites.isEmpty,
              let modelContext = modelContext,
              let session = currentSession else { return }
        
        let writes = pendingWrites
        pendingWrites.removeAll()
        
        logger.info("Processing \(writes.count) pending writes")
        
        // Batch process all writes in a single transaction
        do {
            for write in writes {
                switch write.content.type {
                case .quote:
                    try await saveQuote(write.content, to: session, using: modelContext)
                case .note, .thought:
                    try await saveNote(write.content, to: session, using: modelContext)
                case .question:
                    try await saveQuestion(write.content, to: session, using: modelContext)
                default:
                    break
                }
            }
            
            // Single save for all operations
            try modelContext.save()
            
            // Notify completions
            for write in writes {
                write.completion?(true)
            }
            
            logger.info("Successfully saved \(writes.count) items")
            
        } catch {
            logger.error("Batch save failed: \(error)")
            
            // Notify failures
            for write in writes {
                write.completion?(false)
            }
        }
    }
    
    private func saveQuote(_ content: AmbientProcessedContent, to session: AmbientSession, using context: ModelContext) async throws {
        // Check for existing quote
        let descriptor = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { $0.text == content.text }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            // Link to session if not already linked
            if existing.ambientSession == nil {
                existing.ambientSession = session
                session.capturedQuotes.append(existing)
            }
            return
        }
        
        // Create new quote
        let bookModel = await findOrCreateBookModel(content: content, using: context)
        
        let quote = CapturedQuote(
            text: content.text,
            book: bookModel,
            author: content.bookAuthor,
            pageNumber: nil,
            timestamp: content.timestamp,
            source: .ambient
        )
        
        quote.ambientSession = session
        context.insert(quote)
        session.capturedQuotes.append(quote)
    }
    
    private func saveNote(_ content: AmbientProcessedContent, to session: AmbientSession, using context: ModelContext) async throws {
        // Check for existing note
        let descriptor = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { $0.content == content.text }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            if existing.ambientSession == nil {
                existing.ambientSession = session
                session.capturedNotes.append(existing)
            }
            return
        }
        
        // Create new note
        let bookModel = await findOrCreateBookModel(content: content, using: context)
        
        let note = CapturedNote(
            content: content.text,
            book: bookModel,
            pageNumber: nil,
            timestamp: content.timestamp,
            source: .ambient
        )
        
        note.ambientSession = session
        context.insert(note)
        session.capturedNotes.append(note)
    }
    
    private func saveQuestion(_ content: AmbientProcessedContent, to session: AmbientSession, using context: ModelContext) async throws {
        // Check for existing question
        let descriptor = FetchDescriptor<CapturedQuestion>(
            predicate: #Predicate { $0.content == content.text }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            // Update answer if provided
            if let answer = content.response, existing.answer == nil {
                existing.answer = answer
                existing.isAnswered = true
            }
            
            if existing.ambientSession == nil {
                existing.ambientSession = session
                session.capturedQuestions.append(existing)
            }
            return
        }
        
        // Create new question
        let bookModel = await findOrCreateBookModel(content: content, using: context)
        
        let question = CapturedQuestion(
            content: content.text,
            book: bookModel,
            timestamp: content.timestamp,
            source: .ambient
        )
        
        if let answer = content.response {
            question.answer = answer
            question.isAnswered = true
        }
        
        question.ambientSession = session
        context.insert(question)
        session.capturedQuestions.append(question)
    }
    
    private func findOrCreateBookModel(content: AmbientProcessedContent, using context: ModelContext) async -> BookModel? {
        guard let bookTitle = content.bookTitle else { return nil }
        
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.title == bookTitle }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // Create minimal book model
        let bookModel = BookModel(
            id: UUID(),
            title: bookTitle,
            author: content.bookAuthor ?? "Unknown",
            publishedYear: nil,
            coverImageURL: nil,
            isbn: nil,
            description: nil,
            pageCount: nil,
            localId: UUID().uuidString
        )
        
        context.insert(bookModel)
        return bookModel
    }
    
    deinit {
        writeTimer?.invalidate()
    }
}