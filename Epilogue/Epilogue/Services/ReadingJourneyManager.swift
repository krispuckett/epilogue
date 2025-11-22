import Foundation
import SwiftData
import SwiftUI
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

private let logger = Logger(subsystem: "com.epilogue", category: "ReadingJourney")

// MARK: - Reading Journey Manager
/// Manages reading journeys and integrates with Foundation Models for intelligent timeline generation
@MainActor
class ReadingJourneyManager: ObservableObject {
    static let shared = ReadingJourneyManager()

    @Published var currentJourney: ReadingJourney?
    @Published var isGenerating: Bool = false

    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Initialization

    func initialize(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCurrentJourney()
    }

    private func loadCurrentJourney() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ReadingJourney>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let journeys = try context.fetch(descriptor)
            currentJourney = journeys.first
            logger.info("📖 Loaded active journey: \(currentJourney?.id.uuidString ?? "none")")
        } catch {
            logger.error("❌ Failed to load journey: \(error)")
        }
    }

    // MARK: - Journey Creation via Conversation

    /// Creates a new reading journey based on conversational input
    /// This is called from ambient mode after the user expresses interest
    func createJourneyFromConversation(
        books: [BookModel],
        userIntent: String,
        timeframe: String?,
        preferences: ReadingPreferences
    ) async throws -> ReadingJourney {
        guard let context = modelContext else {
            throw JourneyError.noContext
        }

        isGenerating = true
        defer { isGenerating = false }

        // Deactivate any existing active journey
        if let existing = currentJourney {
            existing.isActive = false
        }

        // Create new journey
        let journey = ReadingJourney(userIntent: userIntent, timeframe: timeframe)
        context.insert(journey)

        // Generate intelligent book order and reasoning using Foundation Models
        let orderedBooks = await generateBookOrder(books: books, intent: userIntent, preferences: preferences)

        // Add books to journey with reasoning
        for (index, bookWithReasoning) in orderedBooks.enumerated() {
            journey.addBook(bookWithReasoning.book, reasoning: bookWithReasoning.reasoning)

            // Generate milestones for each book
            if let journeyBook = journey.books?.last {
                await generateMilestones(for: journeyBook)
            }
        }

        // Generate journey-level milestones
        await generateJourneyMilestones(for: journey)

        try context.save()
        currentJourney = journey

        logger.info("✅ Created journey with \(books.count) books")
        return journey
    }

    // MARK: - Book Order Generation

    private func generateBookOrder(
        books: [BookModel],
        intent: String,
        preferences: ReadingPreferences
    ) async -> [(book: BookModel, reasoning: String)] {
        guard AIFoundationModelsManager.shared.isAvailable else {
            // Fallback to simple ordering
            return books.map { ($0, "Added to your journey") }
        }

        let prompt = buildBookOrderPrompt(books: books, intent: intent, preferences: preferences)

        let response = await AIFoundationModelsManager.shared.processQuery(prompt, bookContext: nil)

        // Parse the response to get ordered books with reasoning
        return parseBookOrderResponse(response, books: books)
    }

    private func buildBookOrderPrompt(
        books: [BookModel],
        intent: String,
        preferences: ReadingPreferences
    ) -> String {
        let booksList = books.enumerated().map { index, book in
            "[\(index + 1)] \(book.title) by \(book.author) - \(book.pageCount ?? 0) pages"
        }.joined(separator: "\n")

        return """
        I need help creating a thoughtful reading order for these books.

        User's intent: \(intent)
        Timeframe: \(preferences.timeframe ?? "flexible")
        Reading pattern: \(preferences.readingPattern ?? "varied")

        Books to order:
        \(booksList)

        Please suggest a reading order that:
        1. Honors the user's stated intent
        2. Creates a natural flow (consider pacing, themes, intensity)
        3. Starts with something engaging or what they're most excited about
        4. Leaves breathing room - doesn't pack everything tightly
        5. Balances lighter and heavier reads if applicable

        For each book, provide:
        - Position in the order (1, 2, 3...)
        - Brief reasoning (one sentence, natural language)

        Format your response as:
        1. [Book Title] - [Reasoning]
        2. [Book Title] - [Reasoning]
        ...

        Be thoughtful and human - this is a companion, not a scheduler.
        """
    }

    private func parseBookOrderResponse(_ response: String, books: [BookModel]) -> [(book: BookModel, reasoning: String)] {
        var orderedBooks: [(book: BookModel, reasoning: String)] = []

        // Parse each line of the response
        let lines = response.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for line in lines {
            // Match pattern: "1. Book Title - Reasoning"
            let components = line.components(separatedBy: " - ")
            guard components.count >= 2 else { continue }

            let bookPart = components[0]
            let reasoning = components.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)

            // Find matching book
            if let book = books.first(where: { bookPart.contains($0.title) }) {
                orderedBooks.append((book, reasoning))
            }
        }

        // If parsing failed, fall back to original order
        if orderedBooks.isEmpty {
            return books.map { ($0, "Added to your reading journey") }
        }

        return orderedBooks
    }

    // MARK: - Milestone Generation

    private func generateMilestones(for journeyBook: JourneyBook) async {
        guard let book = journeyBook.bookModel else { return }
        guard AIFoundationModelsManager.shared.isAvailable else {
            // Fallback to simple chapter-based milestones
            generateSimpleMilestones(for: journeyBook)
            return
        }

        let prompt = buildMilestonePrompt(for: book)
        let response = await AIFoundationModelsManager.shared.processQuery(prompt, bookContext: book.asBook)

        // Parse milestones from response
        let milestones = parseMilestoneResponse(response)

        for (index, milestoneData) in milestones.enumerated() {
            let milestone = BookMilestone(
                title: milestoneData.title,
                type: milestoneData.type,
                order: index
            )
            milestone.description = milestoneData.description
            milestone.reflectionPrompt = milestoneData.reflectionPrompt

            journeyBook.addMilestone(milestone)
        }

        logger.info("✅ Generated \(milestones.count) milestones for \(book.title)")
    }

    private func buildMilestonePrompt(for book: BookModel) -> String {
        """
        I need meaningful milestones for a reader going through "\(book.title)" by \(book.author).

        Book context:
        - Pages: \(book.pageCount ?? 0)
        - Description: \(book.effectiveDescription ?? "No description")

        Create 3-5 meaningful waypoints for this book. These should NOT be arbitrary page numbers.
        Instead, think about:
        - Major structural divisions (Part 1, Part 2, etc.)
        - Significant turning points or reveals
        - Natural break points where a reader might want to pause and reflect
        - Moments that feel like achievements

        For each milestone, provide:
        - Title (brief, evocative)
        - Description (what this represents)
        - Type (chapter, part, section, turning_point, or climax)
        - Reflection prompt (a thoughtful question to ask when they reach this point)

        Format as:
        1. [Title] | [Type] | [Description] | [Reflection prompt]

        Keep the language natural and encouraging - this is a companion, not a teacher.
        NO spoilers for plot-dependent milestones - keep them vague but meaningful.
        """
    }

    private func parseMilestoneResponse(_ response: String) -> [(title: String, type: BookMilestoneType, description: String, reflectionPrompt: String)] {
        var milestones: [(String, BookMilestoneType, String, String)] = []

        let lines = response.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for line in lines {
            // Parse format: "1. Title | Type | Description | Prompt"
            let components = line.components(separatedBy: " | ")
            guard components.count >= 4 else { continue }

            let title = components[0]
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)

            let typeString = components[1].trimmingCharacters(in: .whitespaces).lowercased()
            let type = mapStringToMilestoneType(typeString)

            let description = components[2].trimmingCharacters(in: .whitespaces)
            let prompt = components[3].trimmingCharacters(in: .whitespaces)

            milestones.append((title, type, description, prompt))
        }

        return milestones
    }

    private func mapStringToMilestoneType(_ string: String) -> BookMilestoneType {
        switch string {
        case "chapter": return .chapter
        case "part": return .part
        case "section": return .section
        case "turning_point", "turning point": return .turningPoint
        case "climax": return .climax
        default: return .custom
        }
    }

    private func generateSimpleMilestones(for journeyBook: JourneyBook) {
        guard let book = journeyBook.bookModel, let pageCount = book.pageCount, pageCount > 0 else { return }

        // Create simple percentage-based milestones
        let milestones = [
            (0.25, "Quarter Mark", "A quarter of the way through"),
            (0.5, "Halfway Point", "Halfway through the journey"),
            (0.75, "Three-Quarter Mark", "The home stretch"),
            (1.0, "Completion", "Finished the book")
        ]

        for (index, (percentage, title, description)) in milestones.enumerated() {
            let milestone = BookMilestone(title: title, type: .custom, order: index)
            milestone.description = description
            milestone.pageNumber = Int(Double(pageCount) * percentage)
            milestone.reflectionPrompt = "How are you feeling about the book so far?"

            journeyBook.addMilestone(milestone)
        }
    }

    // MARK: - Journey Milestones

    private func generateJourneyMilestones(for journey: ReadingJourney) async {
        guard let books = journey.books, !books.isEmpty else { return }

        // Create a milestone for each book completion
        for (index, journeyBook) in books.enumerated() {
            guard let book = journeyBook.bookModel else { continue }

            let milestone = JourneyMilestone(
                title: "Complete \(book.title)",
                type: .bookCompletion,
                order: index
            )
            milestone.description = "Finish reading \(book.title) by \(book.author)"
            milestone.reflectionPrompt = await generateCompletionReflectionPrompt(for: book)

            if journey.milestones == nil {
                journey.milestones = []
            }
            milestone.journey = journey
            journey.milestones?.append(milestone)
        }

        // Add a halfway celebration
        if books.count > 2 {
            let halfwayIndex = books.count / 2
            let halfway = JourneyMilestone(
                title: "Halfway Through Your Journey",
                type: .halfway,
                order: halfwayIndex
            )
            halfway.description = "You've completed half of your reading journey"
            halfway.reflectionPrompt = "How has your reading experience been so far? Any surprises?"

            halfway.journey = journey
            journey.milestones?.append(halfway)
        }
    }

    private func generateCompletionReflectionPrompt(for book: BookModel) async -> String {
        guard AIFoundationModelsManager.shared.isAvailable else {
            return "What did you think of this book?"
        }

        let prompt = """
        Generate a thoughtful reflection question for someone who just finished reading "\(book.title)" by \(book.author).

        The question should:
        - Be open-ended and encourage reflection
        - Be specific to this book's likely themes (based on title/author)
        - NOT be generic ("Did you like it?")
        - Feel like a friend asking, not a teacher testing
        - Be one sentence

        Just return the question, nothing else.
        """

        let response = await AIFoundationModelsManager.shared.processQuery(prompt, bookContext: book.asBook)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Journey Updates

    func updateProgress(for journeyBook: JourneyBook, currentPage: Int) {
        // Update book progress
        journeyBook.bookModel?.currentPage = currentPage

        // Check and complete milestones
        if let milestones = journeyBook.milestones {
            for milestone in milestones {
                if let milestonePage = milestone.pageNumber,
                   currentPage >= milestonePage,
                   !milestone.isCompleted {
                    milestone.isCompleted = true
                    milestone.completedAt = Date()
                    logger.info("🎯 Milestone completed: \(milestone.title)")
                }
            }
        }

        // Check if book is completed
        if let pageCount = journeyBook.bookModel?.pageCount,
           currentPage >= pageCount {
            journeyBook.markAsCompleted()
            logger.info("📚 Book completed: \(journeyBook.bookModel?.title ?? "")")

            // Move to next book
            if let journey = journeyBook.journey,
               let nextBook = journey.orderedBooks.first(where: { !$0.isCompleted }) {
                nextBook.startReading()
            }
        }

        saveContext()
    }

    func adjustJourney(reason: String) async {
        guard let journey = currentJourney else { return }

        journey.adjustTimeline(reason: reason)

        // Re-generate timeline with Foundation Models
        if AIFoundationModelsManager.shared.isAvailable {
            let prompt = """
            A reader needs to adjust their reading timeline.

            Original intent: \(journey.userIntent ?? "General reading")
            Current progress: \(journey.completedBooks.count) of \(journey.orderedBooks.count) books completed
            Reason for adjustment: \(reason)

            Suggest how to adapt the timeline. Should they:
            - Continue as planned?
            - Extend the timeframe?
            - Skip a book?
            - Change the order?

            Be supportive and practical. No guilt, just helpful suggestions.
            Keep response to 2-3 sentences.
            """

            let response = await AIFoundationModelsManager.shared.processQuery(prompt, bookContext: nil)
            logger.info("📝 Timeline adjustment: \(response)")

            // Update adaptation reason with AI suggestion
            journey.adaptationReason = response
        }

        saveContext()
    }

    func checkIn() async -> String? {
        guard let journey = currentJourney,
              let currentBook = journey.currentBook,
              AIFoundationModelsManager.shared.isAvailable else {
            return nil
        }

        journey.lastCheckIn = Date()
        journey.nextCheckInSuggested = Calendar.current.date(byAdding: .day, value: 7, to: Date())

        let prompt = """
        Generate a gentle check-in message for a reader.

        Current book: \(currentBook.bookModel?.title ?? "Unknown")
        Journey progress: \(Int(journey.progress * 100))%
        Books completed: \(journey.completedBooks.count)

        Create a warm, non-judgmental check-in that:
        - Acknowledges their progress
        - Asks how they're feeling about the current book
        - Offers help if they want to adjust the timeline
        - Feels like a friend checking in, not a coach demanding results

        Keep it to 2-3 sentences. Be genuine and supportive.
        """

        let response = await AIFoundationModelsManager.shared.processQuery(prompt, bookContext: nil)
        saveContext()

        return response
    }

    // MARK: - Helper Methods

    private func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            logger.error("❌ Failed to save context: \(error)")
        }
    }

    func deleteJourney(_ journey: ReadingJourney) {
        guard let context = modelContext else { return }
        context.delete(journey)
        if currentJourney?.id == journey.id {
            currentJourney = nil
        }
        saveContext()
    }
}

// MARK: - Supporting Types

struct ReadingPreferences {
    let timeframe: String?
    let readingPattern: String? // "Morning", "Evening", "Weekends"
    let pace: String? // "Slow and steady", "Quick bursts", "Flexible"
    let mood: String? // "Something light", "Deep dives", "Varied"
}

enum JourneyError: LocalizedError {
    case noContext
    case generationFailed
    case noActiveJourney

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "Model context not initialized"
        case .generationFailed:
            return "Failed to generate journey"
        case .noActiveJourney:
            return "No active journey found"
        }
    }
}
