import XCTest
import Foundation
@testable import Epilogue

/// Tests for ambient mode voice detection and intelligence features
class AmbientModeDetectionTests: XCTestCase {

    // MARK: - Session Insights Tests

    func test_whenSessionHasMultipleQuestions_thenGeneratesBasicInsights() {
        // Given: An ambient session with questions
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question1 = CapturedQuestion(content: "Who is the main character?", book: book)
        let question2 = CapturedQuestion(content: "What is the theme of this story?", book: book)
        let question3 = CapturedQuestion(content: "How does the character change?", book: book)

        session.capturedQuestions = [question1, question2, question3]

        // When: Generating basic insights
        let insights = session.generateBasicInsights()

        // Then: Should generate meaningful insights
        XCTAssertFalse(insights.dominantTheme.isEmpty)
        XCTAssertFalse(insights.emotionalArc.isEmpty)
        XCTAssertFalse(insights.suggestedReflection.isEmpty)
    }

    func test_whenSessionHasMoreQuotesThanNotes_thenReflectsInEmotionalArc() {
        // Given: A session with many quotes
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let quote1 = CapturedQuote(text: "Quote 1", book: book)
        let quote2 = CapturedQuote(text: "Quote 2", book: book)
        let quote3 = CapturedQuote(text: "Quote 3", book: book)
        let note1 = CapturedNote(content: "Note 1", book: book)

        session.capturedQuotes = [quote1, quote2, quote3]
        session.capturedNotes = [note1]

        // When: Generating insights
        let insights = session.generateBasicInsights()

        // Then: Emotional arc should reflect quote focus
        XCTAssertTrue(insights.emotionalArc.contains("memorable") || insights.emotionalArc.contains("passages"))
    }

    // MARK: - Key Topic Extraction Tests

    func test_whenQuestionsContainCommonThemes_thenExtractsKeyTopics() {
        // Given: A session with themed questions
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question1 = CapturedQuestion(content: "Tell me about friendship in this story", book: book)
        let question2 = CapturedQuestion(content: "How does friendship develop?", book: book)
        let question3 = CapturedQuestion(content: "What role does friendship play?", book: book)

        session.capturedQuestions = [question1, question2, question3]

        // When: Extracting key topics
        let topics = session.keyTopics

        // Then: Should extract "friendship" as a topic
        XCTAssertTrue(topics.contains(where: { $0.lowercased().contains("friendship") }))
    }

    func test_whenContentIsEmpty_thenKeyTopicsIsEmpty() {
        // Given: A session with no content
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        session.capturedQuestions = []
        session.capturedQuotes = []
        session.capturedNotes = []

        // When: Extracting key topics
        let topics = session.keyTopics

        // Then: Should return empty array
        XCTAssertTrue(topics.isEmpty)
    }

    func test_whenContentHasCommonWords_thenFiltersThemOut() {
        // Given: A session with common words
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question = CapturedQuestion(content: "What is the meaning and purpose of this story?", book: book)
        session.capturedQuestions = [question]

        // When: Extracting key topics
        let topics = session.keyTopics

        // Then: Common words like "what", "is", "the" should be filtered
        XCTAssertFalse(topics.contains("what"))
        XCTAssertFalse(topics.contains("the"))
        XCTAssertFalse(topics.contains("and"))
    }

    // MARK: - Conversation Thread Tests

    func test_whenSessionHasQuestions_thenGroupsIntoThreads() {
        // Given: A session with questions
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question1 = CapturedQuestion(content: "Who is Frodo?", book: book)
        question1.answer = "Frodo is the main character"

        let question2 = CapturedQuestion(content: "What is his quest?", book: book)
        question2.answer = "To destroy the Ring"

        session.capturedQuestions = [question1, question2]

        // When: Grouping conversations
        let threads = session.groupedThreads

        // Then: Should create threads for each question
        XCTAssertEqual(threads.count, 2)
        XCTAssertEqual(threads[0].title, "Who is Frodo?")
        XCTAssertEqual(threads[0].aiResponse, "Frodo is the main character")
        XCTAssertEqual(threads[1].title, "What is his quest?")
        XCTAssertEqual(threads[1].aiResponse, "To destroy the Ring")
    }

    // MARK: - Follow-up Suggestion Tests

    func test_whenQuestionAboutCharacter_thenSuggestsCharacterFollowUps() {
        // Given: A character-related question
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question = CapturedQuestion(content: "Who is the main character?", book: book)
        session.capturedQuestions = [question]

        // When: Getting conversation threads
        let threads = session.groupedThreads

        // Then: Should suggest character-related follow-ups
        XCTAssertFalse(threads.isEmpty)
        let followUps = threads[0].suggestedFollowUps
        XCTAssertTrue(followUps.contains(where: { $0.lowercased().contains("motivation") || $0.lowercased().contains("change") }))
    }

    func test_whenQuestionAboutTheme_thenSuggestsThemeFollowUps() {
        // Given: A theme-related question
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question = CapturedQuestion(content: "What is the main theme?", book: book)
        session.capturedQuestions = [question]

        // When: Getting conversation threads
        let threads = session.groupedThreads

        // Then: Should suggest theme-related follow-ups
        XCTAssertFalse(threads.isEmpty)
        let followUps = threads[0].suggestedFollowUps
        XCTAssertTrue(followUps.contains(where: { $0.lowercased().contains("theme") || $0.lowercased().contains("example") }))
    }

    func test_whenQuestionAboutComparison_thenSuggestsComparisonFollowUps() {
        // Given: A comparison question
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question = CapturedQuestion(content: "How is this different from the movie?", book: book)
        session.capturedQuestions = [question]

        // When: Getting conversation threads
        let threads = session.groupedThreads

        // Then: Should suggest comparison-related follow-ups
        XCTAssertFalse(threads.isEmpty)
        let followUps = threads[0].suggestedFollowUps
        XCTAssertTrue(followUps.contains(where: { $0.lowercased().contains("similar") || $0.lowercased().contains("prefer") }))
    }

    // MARK: - Session Duration Tests

    func test_whenSessionHasEndTime_thenCalculatesDuration() {
        // Given: A session with start and end times
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour later
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")

        let session = AmbientSession(startTime: startTime, bookModel: book)
        session.endTime = endTime

        // When: Getting duration
        let duration = session.duration

        // Then: Should be 1 hour (3600 seconds)
        XCTAssertEqual(duration, 3600, accuracy: 1.0)
    }

    func test_whenSessionHasNoEndTime_thenDurationIsZero() {
        // Given: A session with no end time
        let startTime = Date()
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")

        let session = AmbientSession(startTime: startTime, bookModel: book)
        session.endTime = nil

        // When: Getting duration
        let duration = session.duration

        // Then: Duration should be 0 or very small
        XCTAssertLessThan(duration, 1.0)
    }

    // MARK: - Captured Content Tests

    func test_whenSessionHasMultipleContentTypes_thenCombinesAll() {
        // Given: A session with various content types
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let quote1 = CapturedQuote(text: "Quote 1", book: book)
        let quote2 = CapturedQuote(text: "Quote 2", book: book)
        let note1 = CapturedNote(content: "Note 1", book: book)

        session.capturedQuotes = [quote1, quote2]
        session.capturedNotes = [note1]

        // When: Getting captured content
        let content = session.capturedContent

        // Then: Should combine all content types
        XCTAssertEqual(content.count, 3)
    }

    func test_whenSessionHasNoContent_thenCapturedContentIsEmpty() {
        // Given: A session with no content
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        session.capturedQuotes = []
        session.capturedNotes = []
        session.capturedQuestions = []

        // When: Getting captured content
        let content = session.capturedContent

        // Then: Should be empty
        XCTAssertTrue(content.isEmpty)
    }

    // MARK: - Suggested Continuation Tests

    func test_whenSessionHasRecentContent_thenGeneratesSuggestions() {
        // Given: A session with recent activity
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question = CapturedQuestion(content: "Tell me about the characters", book: book)
        session.capturedQuestions = [question]
        session.currentChapter = 5

        // When: Getting suggested continuations
        let suggestions = session.suggestedContinuations

        // Then: Should have suggestions
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertLessThanOrEqual(suggestions.count, 3)
    }

    // MARK: - Content Protocol Conformance Tests

    func test_whenCapturedNote_thenConformsToCapturedContentProtocol() {
        // Given: A captured note
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let note = CapturedNote(content: "Test note", book: book)

        // When: Accessing protocol properties
        let content: any CapturedContent = note

        // Then: Should have required properties
        XCTAssertNotNil(content.id)
        XCTAssertNotNil(content.timestamp)
    }

    func test_whenCapturedQuote_thenConformsToCapturedContentProtocol() {
        // Given: A captured quote
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let quote = CapturedQuote(text: "Test quote", book: book)

        // When: Accessing protocol properties
        let content: any CapturedContent = quote

        // Then: Should have required properties
        XCTAssertNotNil(content.id)
        XCTAssertNotNil(content.timestamp)
    }

    func test_whenCapturedQuestion_thenConformsToCapturedContentProtocol() {
        // Given: A captured question
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let question = CapturedQuestion(content: "Test question", book: book)

        // When: Accessing protocol properties
        let content: any CapturedContent = question

        // Then: Should have required properties
        XCTAssertNotNil(content.id)
        XCTAssertNotNil(content.timestamp)
    }

    // MARK: - Edge Case Tests

    func test_whenQuestionContentIsNil_thenDoesNotCrash() {
        // Given: A question with nil content
        let book = BookModel(id: "test-book", title: "Test Book", author: "Test Author")
        let session = AmbientSession(startTime: Date(), bookModel: book)

        let question = CapturedQuestion(content: "Question", book: book)
        question.content = nil
        session.capturedQuestions = [question]

        // When: Extracting topics
        let topics = session.keyTopics

        // Then: Should handle gracefully without crashing
        XCTAssertNotNil(topics)
    }

    func test_whenBookModelIsNil_thenSessionStillWorks() {
        // Given: A session with no book
        let session = AmbientSession(startTime: Date(), bookModel: nil)

        // When: Accessing properties
        let duration = session.duration
        let topics = session.keyTopics
        let threads = session.groupedThreads

        // Then: Should handle gracefully
        XCTAssertGreaterThanOrEqual(duration, 0)
        XCTAssertNotNil(topics)
        XCTAssertNotNil(threads)
    }
}
