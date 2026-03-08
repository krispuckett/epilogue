import Foundation
import SwiftData
import Network
import Combine
import OSLog
import UserNotifications

@MainActor
@Observable
class OfflineQueueManager {
    static let shared = OfflineQueueManager()

    var queuedQuestions: [QueuedQuestion] = []
    var isOnline: Bool = true
    var isProcessing: Bool = false
    var queueDepth: Int = 0

    @ObservationIgnored private let logger = Logger(subsystem: "com.epilogue", category: "OfflineQueue")
    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let monitorQueue = DispatchQueue(label: "com.epilogue.networkmonitor")
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    
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
        // Check if network is still available before processing
        guard isOnline else {
            logger.info("⏸️ Network lost during processing, pausing queue")
            return
        }

        let maxRetries = 3

        for attempt in 1...maxRetries {
            do {
                // Note: Book context lookup disabled due to BookModel/Book type mismatch
                // TODO: Figure out the proper Book type conversion

                // Process with OptimizedPerplexityService - we can't cast BookModel to Book directly
                // For now, pass nil to avoid type conflicts
                // TODO: Figure out the proper Book type conversion
                let response = try await OptimizedPerplexityService.shared.chat(
                    message: question.question ?? "",
                    bookContext: nil as Book?
                )

                // Success! Mark as processed
                question.processed = true
                question.response = response
                question.processingError = nil

                try modelContext?.save()

                logger.info("✅ Processed question (attempt \(attempt)): \(question.question ?? "")")

                // Post notification for UI update
                NotificationCenter.default.post(
                    name: .queuedQuestionProcessed,
                    object: question
                )

                // Send user notification if app is in background
                await sendNotificationForAnsweredQuestion(question)

                return // Success, exit retry loop

            } catch {
                logger.warning("⚠️ Attempt \(attempt) failed: \(error.localizedDescription)")

                // Check if we should retry
                if attempt < maxRetries {
                    // Check network status before retrying
                    guard isOnline else {
                        logger.info("📵 Network lost, stopping retries")
                        question.processingError = "Network unavailable"
                        try? modelContext?.save()
                        return
                    }

                    // Exponential backoff: 2s, 4s, 8s
                    let delay = pow(2.0, Double(attempt))
                    logger.info("⏳ Retrying in \(Int(delay))s...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    // All retries exhausted
                    question.processingError = "Failed after \(maxRetries) attempts: \(error.localizedDescription)"
                    try? modelContext?.save()
                    logger.error("❌ All retries exhausted for question: \(question.question ?? "")")
                }
            }
        }
    }

    // MARK: - Notifications

    private func sendNotificationForAnsweredQuestion(_ question: QueuedQuestion) async {
        guard let questionText = question.question else { return }

        let content = UNMutableNotificationContent()
        content.title = "Question Answered"
        content.body = questionText
        content.sound = .default
        content.categoryIdentifier = "ANSWERED_QUESTION"

        let request = UNNotificationRequest(
            identifier: question.id?.uuidString ?? UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to send notification: \(error)")
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