import Foundation
import SwiftData
import Network
import Combine
import OSLog

@MainActor
class OfflineQueueManager: ObservableObject {
    static let shared = OfflineQueueManager()
    
    @Published var queuedQuestions: [QueuedQuestion] = []
    @Published var isOnline: Bool = true
    @Published var isProcessing: Bool = false
    @Published var queueDepth: Int = 0
    
    private let logger = Logger(subsystem: "com.epilogue", category: "OfflineQueue")
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.epilogue.networkmonitor")
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNetworkMonitoring()
    }
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        loadQueuedQuestions()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
                
                if path.status == .satisfied {
                    self?.logger.info("📶 Network available - processing queue")
                    await self?.processQueue()
                } else {
                    self?.logger.info("📵 Network unavailable - queueing enabled")
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Queue Management
    
    func addQuestion<T>(_ question: String, book: T?, sessionContext: String? = nil) {
        guard let modelContext = modelContext else {
            logger.error("ModelContext not configured")
            return
        }
        
        // Extract title and author from whatever book type is passed
        var bookTitle: String?
        var bookAuthor: String?
        
        if let bookModel = book as? BookModel {
            bookTitle = bookModel.title
            bookAuthor = bookModel.author
        } else if let bookMirror = book.map({ Mirror(reflecting: $0) }) {
            // Try to extract title and author using reflection for unknown Book type
            for child in bookMirror.children {
                if child.label == "title", let title = child.value as? String {
                    bookTitle = title
                }
                if child.label == "author", let author = child.value as? String {
                    bookAuthor = author
                }
            }
        }
        
        let queuedQuestion = QueuedQuestion(
            question: question,
            bookTitle: bookTitle,
            bookAuthor: bookAuthor,
            sessionContext: sessionContext
        )
        
        modelContext.insert(queuedQuestion)
        
        do {
            try modelContext.save()
            loadQueuedQuestions()
            logger.info("💾 Question queued: \(question)")
            
            if isOnline {
                Task {
                    await processQueue()
                }
            }
        } catch {
            logger.error("Failed to save queued question: \(error)")
        }
    }
    
    func loadQueuedQuestions() {
        guard let modelContext = self.modelContext else { return }
        
        let descriptor = FetchDescriptor<QueuedQuestion>(
            predicate: #Predicate { !($0.processed ?? false) },
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.timestamp, order: .forward)
            ]
        )
        
        do {
            self.queuedQuestions = try modelContext.fetch(descriptor)
            self.queueDepth = self.queuedQuestions.count
        } catch {
            self.logger.error("Failed to load queued questions: \(error)")
        }
    }
    
    @MainActor
    func processQueue() async {
        guard isOnline, !isProcessing, !self.queuedQuestions.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        logger.info("🔄 Processing \(self.queuedQuestions.count) queued questions")
        
        for question in self.queuedQuestions {
            await processQuestion(question)
        }
        
        loadQueuedQuestions()
    }
    
    private func processQuestion(_ question: QueuedQuestion) async {
        do {
            // Create book context if available
            var bookContext: BookModel?
            if let title = question.bookTitle,
               let author = question.bookAuthor,
               let modelContext = modelContext {
                let descriptor = FetchDescriptor<BookModel>(
                    predicate: #Predicate { (book: BookModel) in
                        book.title == title && book.author == author
                    }
                )
                bookContext = try modelContext.fetch(descriptor).first
            }
            
            // Process with Perplexity - we can't cast BookModel to Book directly
            // For now, pass nil to avoid type conflicts
            // TODO: Figure out the proper Book type conversion
            let response = try await PerplexityService.staticChat(
                message: question.question ?? "",
                bookContext: nil
            )
            
            // Mark as processed
            question.processed = true
            question.response = response
            
            try modelContext?.save()
            
            logger.info("✅ Processed question: \(question.question ?? "")")
            
            // Post notification for UI update
            NotificationCenter.default.post(
                name: Notification.Name("QueuedQuestionProcessed"),
                object: question
            )
            
        } catch {
            question.processingError = error.localizedDescription
            logger.error("❌ Failed to process question: \(error)")
        }
    }
    
    func clearProcessedQuestions() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<QueuedQuestion>(
            predicate: #Predicate { $0.processed ?? false }
        )
        
        do {
            let processed = try modelContext.fetch(descriptor)
            for question in processed {
                modelContext.delete(question)
            }
            try modelContext.save()
            loadQueuedQuestions()
            logger.info("🧹 Cleared \(processed.count) processed questions")
        } catch {
            logger.error("Failed to clear processed questions: \(error)")
        }
    }
    
    func deleteQuestion(_ question: QueuedQuestion) {
        guard let modelContext = modelContext else { return }
        
        modelContext.delete(question)
        
        do {
            try modelContext.save()
            loadQueuedQuestions()
        } catch {
            logger.error("Failed to delete question: \(error)")
        }
    }
    
    func getProcessedResponses() -> [(question: String, response: String, timestamp: Date)] {
        guard let modelContext = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<QueuedQuestion>(
            predicate: #Predicate { ($0.processed ?? false) && $0.response != nil },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let processed = try modelContext.fetch(descriptor)
            return processed.compactMap { q in
                guard let response = q.response else { return nil }
                return (q.question ?? "", response, q.timestamp ?? Date())
            }
        } catch {
            logger.error("Failed to fetch processed responses: \(error)")
            return []
        }
    }
}