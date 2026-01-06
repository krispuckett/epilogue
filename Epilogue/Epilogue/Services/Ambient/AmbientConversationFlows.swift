import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Ambient Conversation Flow Orchestrator

/// Orchestrates conversational flows for generic ambient mode
/// Handles recommendations, reading plans, and intelligent follow-ups
@MainActor
class AmbientConversationFlows: ObservableObject {
    static let shared = AmbientConversationFlows()

    // MARK: - Published State

    @Published var activeFlow: ConversationFlow?
    @Published var flowState: FlowState = .idle
    @Published var tasteProfile: LibraryTasteAnalyzer.TasteProfile?
    @Published var recommendations: [RecommendationEngine.Recommendation] = []
    @Published var pendingClarifications: [ClarificationQuestion] = []

    // Reading plan state
    @Published var selectedBooksForPlan: [BookModel] = []
    @Published var planPreferences: ReadingPreferences?

    private var modelContext: ModelContext?
    private let tasteAnalyzer = LibraryTasteAnalyzer.shared
    private let recommendationEngine = RecommendationEngine.shared
    private let journeyManager = ReadingJourneyManager.shared

    private init() {}

    // MARK: - Initialization

    func initialize(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Flow Types

    enum ConversationFlow: Equatable {
        case recommendation
        case readingPlan
        case readingHabit      // "build a reading habit" flow
        case readingChallenge  // "create a reading challenge" flow
        case libraryInsights
        case moodBasedRecommendation(mood: String)
        case vibeBasedRecommendation(bookTitle: String)  // "books like X", "similar vibes to X"
    }

    enum FlowState: Equatable {
        case idle
        case analyzing           // Analyzing library for taste profile
        case awaitingClarification(question: ClarificationQuestion)
        case generating          // Generating recommendations/plan
        case completed(result: FlowResult)
        case error(message: String)
    }

    struct ClarificationQuestion: Identifiable, Equatable {
        let id = UUID()
        let question: String
        let options: [String]?
        let freeResponse: Bool

        static func == (lhs: ClarificationQuestion, rhs: ClarificationQuestion) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Conversation Starters

    /// Quick-tap mood options for finding books
    enum ReadingMood: String, CaseIterable {
        case cozy = "Cozy & comforting"
        case epic = "Epic adventure"
        case thoughtful = "Thought-provoking"
        case emotional = "Emotional journey"
        case funny = "Light & funny"
        case dark = "Dark & atmospheric"
        case hopeful = "Hopeful & uplifting"
        case mindBending = "Mind-bending"

        var emoji: String {
            switch self {
            case .cozy: return "blanket"
            case .epic: return "mountain"
            case .thoughtful: return "brain"
            case .emotional: return "heart"
            case .funny: return "smile"
            case .dark: return "moon"
            case .hopeful: return "sunrise"
            case .mindBending: return "spiral"
            }
        }

        var sfSymbol: String {
            switch self {
            case .cozy: return "cup.and.saucer.fill"
            case .epic: return "mountain.2.fill"
            case .thoughtful: return "brain.head.profile"
            case .emotional: return "heart.fill"
            case .funny: return "face.smiling.fill"
            case .dark: return "moon.stars.fill"
            case .hopeful: return "sunrise.fill"
            case .mindBending: return "tornado"
            }
        }

        var prompt: String {
            switch self {
            case .cozy: return "Find me something cozy - the kind of book that feels like a warm blanket and a cup of tea."
            case .epic: return "I want an epic adventure - sweeping scope, high stakes, a journey I can get lost in."
            case .thoughtful: return "Give me something thought-provoking - a book that will stick with me and make me think."
            case .emotional: return "I'm ready to feel things - find me a book that will move me emotionally."
            case .funny: return "I need something light and funny - a book that will make me laugh."
            case .dark: return "I'm in the mood for something dark and atmospheric - moody, immersive, maybe a little unsettling."
            case .hopeful: return "Find me something hopeful and uplifting - a book that will leave me feeling good about the world."
            case .mindBending: return "I want something mind-bending - twists, surprises, a book that will keep me guessing."
            }
        }
    }

    /// Contextual suggestions based on library
    struct ConversationStarter: Identifiable {
        let id = UUID()
        let label: String
        let prompt: String
        let sfSymbol: String
    }

    /// Generate personalized conversation starters based on the user's library
    func getConversationStarters(from books: [Book]) -> [ConversationStarter] {
        var starters: [ConversationStarter] = []

        // Always include "Surprise me"
        starters.append(ConversationStarter(
            label: "Surprise me",
            prompt: "Surprise me with something I wouldn't expect but will love based on my reading history.",
            sfSymbol: "sparkle"
        ))

        // If they have recent reads, offer "More like..."
        if let recentFavorite = books.filter({ $0.userRating ?? 0 >= 4 }).first {
            starters.append(ConversationStarter(
                label: "More like \(recentFavorite.title.prefix(20))...",
                prompt: "Find me books with a similar vibe to \(recentFavorite.title) by \(recentFavorite.author).",
                sfSymbol: "arrow.triangle.branch"
            ))
        }

        // Offer something different
        if books.count >= 5 {
            starters.append(ConversationStarter(
                label: "Something different",
                prompt: "I want to try something outside my usual reading patterns - surprise me with a genre or style I haven't explored.",
                sfSymbol: "arrow.triangle.swap"
            ))
        }

        // "I don't know what I want"
        starters.append(ConversationStarter(
            label: "I don't know what I want",
            prompt: "I'm not sure what I'm in the mood for. Can you ask me a few questions to help figure it out?",
            sfSymbol: "questionmark.bubble"
        ))

        return starters
    }

    enum FlowResult: Equatable {
        case recommendations([RecommendationEngine.Recommendation])
        case readingPlan(ReadingJourney)
        case insights(String)

        static func == (lhs: FlowResult, rhs: FlowResult) -> Bool {
            switch (lhs, rhs) {
            case (.recommendations(let a), .recommendations(let b)):
                return a.count == b.count
            case (.readingPlan(let a), .readingPlan(let b)):
                return a.id == b.id
            case (.insights(let a), .insights(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    // MARK: - Start Recommendation Flow

    /// Starts the recommendation flow, analyzing library and generating personalized suggestions
    /// Accepts [Book] type from LibraryViewModel
    func startRecommendationFlow(books: [Book]) async -> AsyncStream<FlowUpdate> {
        // Convert Book to BookModel using convenience initializer
        let bookModels = books.map { BookModel(from: $0) }
        return await startRecommendationFlowInternal(books: bookModels)
    }

    /// Internal implementation for recommendation flow
    private func startRecommendationFlowInternal(books: [BookModel]) async -> AsyncStream<FlowUpdate> {
        AsyncStream { continuation in
            Task { @MainActor in
                activeFlow = .recommendation
                flowState = .analyzing

                // Step 1: Check if we have a recent taste profile
                let profileAge = tasteProfile?.createdAt.timeIntervalSinceNow ?? -Double.infinity
                let needsNewProfile = tasteProfile == nil || abs(profileAge) > 7 * 24 * 60 * 60 // 7 days

                if needsNewProfile {
                    continuation.yield(.status("Analyzing your library..."))

                    // Analyze library on-device
                    let profile = await tasteAnalyzer.analyzeLibrary(books: books)
                    self.tasteProfile = profile

                    #if DEBUG
                    print("📊 Taste profile generated:")
                    print("   Genres: \(profile.genres.keys.prefix(3).joined(separator: ", "))")
                    print("   Themes: \(profile.themes.prefix(3).joined(separator: ", "))")
                    #endif
                }

                // Step 2: Check if profile is too thin
                guard let profile = self.tasteProfile else {
                    continuation.yield(.error("Could not analyze your library"))
                    continuation.finish()
                    return
                }

                if books.count < 5 {
                    // Ask clarifying questions
                    let clarification = ClarificationQuestion(
                        question: "I'd love to help you find great books! To give better recommendations, tell me: are you in the mood for fiction or non-fiction?",
                        options: ["Fiction", "Non-fiction", "Either is fine"],
                        freeResponse: true
                    )
                    self.flowState = .awaitingClarification(question: clarification)
                    continuation.yield(.clarificationNeeded(clarification))
                    continuation.finish()
                    return
                }

                // Step 3: Generate recommendations
                continuation.yield(.status("Finding books you'll love..."))
                self.flowState = .generating

                do {
                    let recs = try await recommendationEngine.generateRecommendations(for: profile)
                    self.recommendations = recs
                    self.flowState = .completed(result: .recommendations(recs))

                    continuation.yield(.recommendations(recs))
                    #if DEBUG
                    print("✅ Generated \(recs.count) recommendations")
                    #endif
                } catch {
                    self.flowState = .error(message: error.localizedDescription)
                    continuation.yield(.error("Couldn't generate recommendations: \(error.localizedDescription)"))
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Handle Clarification Response

    /// Handles user's response to a clarification question and continues the flow
    /// Accepts [Book] type from LibraryViewModel
    func handleClarificationResponse(_ response: String, books: [Book]) async -> AsyncStream<FlowUpdate> {
        AsyncStream { continuation in
            Task { @MainActor in
                // Enhance the profile with user's response
                let enhancedPrompt = buildEnhancedPromptWithClarification(response)

                continuation.yield(.status("Finding books you'll love..."))
                self.flowState = .generating

                do {
                    // Generate with enhanced context
                    let recs = try await self.generateRecommendationsWithContext(
                        profile: self.tasteProfile,
                        additionalContext: enhancedPrompt
                    )
                    self.recommendations = recs
                    self.flowState = .completed(result: .recommendations(recs))

                    continuation.yield(.recommendations(recs))
                } catch {
                    self.flowState = .error(message: error.localizedDescription)
                    continuation.yield(.error("Couldn't generate recommendations"))
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Start Vibe-Based Recommendation Flow

    /// Find books with similar emotional resonance to a given book title
    func startVibeRecommendationFlow(bookTitle: String, library: [Book]) async -> AsyncStream<FlowUpdate> {
        AsyncStream { continuation in
            Task { @MainActor in
                activeFlow = .vibeBasedRecommendation(bookTitle: bookTitle)
                flowState = .analyzing

                continuation.yield(.status("Finding books with similar vibes to \"\(bookTitle)\"..."))

                // First, try to find the book in the user's library
                var matchedBook: Book?
                let normalizedTitle = bookTitle.lowercased()

                for book in library {
                    if book.title.lowercased().contains(normalizedTitle) ||
                       normalizedTitle.contains(book.title.lowercased()) {
                        matchedBook = book
                        break
                    }
                }

                // If not in library, create a minimal Book object for the query
                let sourceBook = matchedBook ?? Book(
                    id: UUID().uuidString,
                    title: bookTitle,
                    author: "Unknown",
                    description: nil
                )

                do {
                    flowState = .generating
                    continuation.yield(.status("Analyzing the emotional landscape of \"\(sourceBook.title)\"..."))

                    let vibeRecs = try await recommendationEngine.findSimilarVibes(to: sourceBook, count: 5)
                    self.recommendations = vibeRecs
                    self.flowState = .completed(result: .recommendations(vibeRecs))

                    continuation.yield(.recommendations(vibeRecs))

                    #if DEBUG
                    print("✨ Found \(vibeRecs.count) vibe matches for \(sourceBook.title)")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Vibe recommendation failed: \(error)")
                    #endif
                    self.flowState = .error(message: "Couldn't find similar books")
                    continuation.yield(.error("I couldn't find books with similar vibes right now. Try again?"))
                }

                continuation.finish()
            }
        }
    }

    /// Find books for a specific mood using Claude
    func startMoodRecommendationFlow(mood: String) async -> AsyncStream<FlowUpdate> {
        AsyncStream { continuation in
            Task { @MainActor in
                activeFlow = .moodBasedRecommendation(mood: mood)
                flowState = .generating

                continuation.yield(.status("Finding books for a \(mood) mood..."))

                do {
                    let moodRecs = try await recommendationEngine.findBooksForMood(mood)
                    self.recommendations = moodRecs
                    self.flowState = .completed(result: .recommendations(moodRecs))

                    continuation.yield(.recommendations(moodRecs))

                    #if DEBUG
                    print("🎭 Found \(moodRecs.count) books for mood: \(mood)")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Mood recommendation failed: \(error)")
                    #endif
                    self.flowState = .error(message: "Couldn't find books for that mood")
                    continuation.yield(.error("I couldn't find books for that mood right now. Try being more specific?"))
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Start Reading Plan Flow

    /// Starts the conversational reading plan creation flow
    /// Accepts [Book] type from LibraryViewModel
    func startReadingPlanFlow(books: [Book]) -> FlowUpdate {
        activeFlow = .readingPlan
        selectedBooksForPlan = []

        // First question: What books do you want to include?
        if books.isEmpty {
            return .clarificationNeeded(ClarificationQuestion(
                question: "I'd love to help you create a reading plan! First, which books from your library would you like to include?",
                options: nil,
                freeResponse: true
            ))
        }

        // Ask about timeline
        let clarification = ClarificationQuestion(
            question: "Great! What's your timeline for this reading journey?",
            options: ["This month", "This quarter", "This year", "No deadline - flexible"],
            freeResponse: true
        )
        flowState = .awaitingClarification(question: clarification)
        return .clarificationNeeded(clarification)
    }

    /// Continue reading plan flow with user's timeline response
    func continueReadingPlanWithTimeline(_ timeframe: String) -> FlowUpdate {
        // Ask about reading pattern
        let clarification = ClarificationQuestion(
            question: "When do you typically like to read?",
            options: ["Morning person", "Evening wind-down", "Weekend marathons", "Whenever I can"],
            freeResponse: true
        )
        flowState = .awaitingClarification(question: clarification)
        return .clarificationNeeded(clarification)
    }

    /// Finalize and create the reading plan
    /// Accepts [Book] type from LibraryViewModel
    func createReadingPlan(
        books: [Book],
        intent: String,
        timeframe: String?,
        readingPattern: String?
    ) async -> AsyncStream<FlowUpdate> {
        AsyncStream { continuation in
            Task { @MainActor in
                self.flowState = .generating
                continuation.yield(.status("Creating your personalized reading plan..."))

                // Convert Book to BookModel using convenience initializer
                let bookModels = books.map { BookModel(from: $0) }

                let preferences = ReadingPreferences(
                    timeframe: timeframe,
                    readingPattern: readingPattern,
                    pace: nil,
                    mood: nil
                )

                do {
                    let journey = try await journeyManager.createJourneyFromConversation(
                        books: bookModels,
                        userIntent: intent,
                        timeframe: timeframe,
                        preferences: preferences
                    )

                    self.flowState = .completed(result: .readingPlan(journey))
                    continuation.yield(.readingPlan(journey))

                    #if DEBUG
                    print("✅ Created reading plan with \(books.count) books")
                    #endif
                } catch {
                    self.flowState = .error(message: error.localizedDescription)
                    continuation.yield(.error("Couldn't create reading plan: \(error.localizedDescription)"))
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Library Insights Flow

    /// Generate insights about the user's reading patterns
    /// Accepts [Book] type from LibraryViewModel
    func generateLibraryInsights(books: [Book]) async -> String {
        flowState = .analyzing

        // Convert Book to BookModel using convenience initializer
        let bookModels = books.map { BookModel(from: $0) }

        // Ensure we have a taste profile
        if tasteProfile == nil {
            tasteProfile = await tasteAnalyzer.analyzeLibrary(books: bookModels)
        }

        guard let profile = tasteProfile else {
            return "I couldn't analyze your library yet. Add a few more books and try again!"
        }

        // Build insights summary
        var insights: [String] = []

        // Top genres
        let topGenres = profile.genres
            .sorted(by: { $0.value > $1.value })
            .prefix(3)
            .map { $0.key }
        if !topGenres.isEmpty {
            insights.append("You gravitate toward **\(topGenres.joined(separator: ", "))**")
        }

        // Favorite authors
        let topAuthors = profile.authors
            .sorted(by: { $0.value > $1.value })
            .prefix(3)
            .map { $0.key }
        if !topAuthors.isEmpty {
            insights.append("You've read multiple books by **\(topAuthors.joined(separator: ", "))**")
        }

        // Reading level
        insights.append("Your reading tends toward **\(profile.readingLevel.rawValue)** works")

        // Era preference
        if let era = profile.preferredEra {
            insights.append("You seem drawn to **\(era.rawValue)** publications")
        }

        // Themes
        if !profile.themes.isEmpty {
            insights.append("Common themes: **\(profile.themes.prefix(5).joined(separator: ", "))**")
        }

        flowState = .completed(result: .insights(insights.joined(separator: "\n\n")))
        return insights.joined(separator: "\n\n")
    }

    // MARK: - Intent Detection

    /// Detects if a user message indicates a specific ambient flow intent
    func detectFlowIntent(from message: String) -> ConversationFlow? {
        let lowercased = message.lowercased()

        // Reading habit intent (check before general plan)
        let habitKeywords = ["reading habit", "build a habit", "start a habit", "daily reading", "habit plan"]
        if habitKeywords.contains(where: { lowercased.contains($0) }) {
            return .readingHabit
        }

        // Reading challenge intent (check before general plan)
        let challengeKeywords = ["reading challenge", "create a challenge", "book challenge", "challenge myself"]
        if challengeKeywords.contains(where: { lowercased.contains($0) }) {
            return .readingChallenge
        }

        // Recommendation intent
        let recommendationKeywords = ["recommend", "suggestion", "what should i read", "what to read", "book recommendation", "something to read"]
        if recommendationKeywords.contains(where: { lowercased.contains($0) }) {
            return .recommendation
        }

        // Reading plan intent (generic - falls back to habit)
        let planKeywords = ["reading plan", "create a plan", "plan my reading", "reading journey", "reading schedule"]
        if planKeywords.contains(where: { lowercased.contains($0) }) {
            return .readingHabit // Default to habit flow for generic plan requests
        }

        // Insights intent
        let insightKeywords = ["reading patterns", "reading habits", "what do i like", "my taste", "analyze my", "what genres"]
        if insightKeywords.contains(where: { lowercased.contains($0) }) {
            return .libraryInsights
        }

        // Vibe-based recommendation - "books like X", "similar vibes to X"
        let vibeKeywords = ["similar vibes", "books like", "something like", "feels like", "vibe of", "reminds me of", "in the spirit of"]
        for keyword in vibeKeywords {
            if lowercased.contains(keyword) {
                if let bookTitle = extractBookTitle(from: message, trigger: keyword) {
                    return .vibeBasedRecommendation(bookTitle: bookTitle)
                }
            }
        }

        // Mood-based recommendation
        let moodKeywords = ["in the mood for", "feeling like", "something for a", "rainy day", "beach read", "cozy"]
        for keyword in moodKeywords {
            if lowercased.contains(keyword) {
                // Extract the mood context
                return .moodBasedRecommendation(mood: extractMood(from: message))
            }
        }

        return nil
    }

    /// Extract book title from a vibe query like "books like The Odyssey"
    private func extractBookTitle(from message: String, trigger: String) -> String? {
        let lowercased = message.lowercased()
        guard let range = lowercased.range(of: trigger) else { return nil }

        // Get the text after the trigger
        let afterTrigger = String(message[range.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Clean up common suffixes
        var title = afterTrigger
        let suffixes = ["?", ".", "!", " please", " thanks", " maybe"]
        for suffix in suffixes {
            if title.lowercased().hasSuffix(suffix) {
                title = String(title.dropLast(suffix.count))
            }
        }

        // Remove leading articles for cleaner matching
        let prefixes = ["the book ", "a book ", "\"", "'"]
        for prefix in prefixes {
            if title.lowercased().hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
            }
        }

        // Clean trailing quotes
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        return title.isEmpty ? nil : title.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private Helpers

    private func buildEnhancedPromptWithClarification(_ response: String) -> String {
        "User preference: \(response)"
    }

    private func generateRecommendationsWithContext(profile: LibraryTasteAnalyzer.TasteProfile?, additionalContext: String) async throws -> [RecommendationEngine.Recommendation] {
        // If no profile, create minimal one
        let effectiveProfile = profile ?? LibraryTasteAnalyzer.TasteProfile(
            genres: [:],
            authors: [:],
            themes: [],
            readingLevel: .popular,
            preferredEra: nil,
            topKeywords: [],
            createdAt: Date()
        )

        // For now, use the standard recommendation engine
        // In the future, we could enhance the prompt with the additional context
        return try await recommendationEngine.generateRecommendations(for: effectiveProfile)
    }

    private func extractMood(from message: String) -> String {
        let lowercased = message.lowercased()

        let moodMappings: [(keywords: [String], mood: String)] = [
            (["rainy day", "cozy", "comfort"], "cozy and comforting"),
            (["beach", "vacation", "light"], "light and fun"),
            (["thoughtful", "deep", "philosophical"], "thought-provoking"),
            (["adventure", "exciting", "thrilling"], "adventurous and exciting"),
            (["sad", "melancholy", "emotional"], "emotionally moving"),
            (["funny", "humor", "laugh"], "humorous and entertaining")
        ]

        for mapping in moodMappings {
            if mapping.keywords.contains(where: { lowercased.contains($0) }) {
                return mapping.mood
            }
        }

        return "general interest"
    }

    // MARK: - Reset

    func resetFlow() {
        activeFlow = nil
        flowState = .idle
        recommendations = []
        pendingClarifications = []
        selectedBooksForPlan = []
        planPreferences = nil
    }
}

// MARK: - Flow Update Type

enum FlowUpdate {
    case status(String)
    case clarificationNeeded(AmbientConversationFlows.ClarificationQuestion)
    case recommendations([RecommendationEngine.Recommendation])
    case readingPlan(ReadingJourney)
    case insights(String)
    case error(String)
}

// MARK: - Recommendation Card View

/// Beautiful card display for recommendations in ambient mode
struct RecommendationCardView: View {
    let recommendation: RecommendationEngine.Recommendation
    let onAddToLibrary: () -> Void
    let onTellMeMore: () -> Void

    @State private var isVisible = false
    @State private var coverImage: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            // Cover image
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primaryAccent.opacity(0.3),
                                        DesignSystem.Colors.primaryAccent.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: "book.closed")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(recommendation.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(recommendation.author)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))

                Text(recommendation.reasoning)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .padding(.top, 2)

                // Actions
                HStack(spacing: 12) {
                    Button(action: onAddToLibrary) {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    }

                    Button(action: onTellMeMore) {
                        Text("Tell me more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.3))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
            loadCoverImage()
        }
    }

    private func loadCoverImage() {
        guard let urlString = recommendation.coverURL,
              let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        coverImage = image
                    }
                }
            } catch {
                #if DEBUG
                print("Failed to load cover: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Recommendations List View

/// Displays a list of recommendations in ambient mode
struct RecommendationsListView: View {
    let recommendations: [RecommendationEngine.Recommendation]
    let onAddToLibrary: (RecommendationEngine.Recommendation) -> Void
    let onTellMeMore: (RecommendationEngine.Recommendation) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(recommendations) { recommendation in
                RecommendationCardView(
                    recommendation: recommendation,
                    onAddToLibrary: { onAddToLibrary(recommendation) },
                    onTellMeMore: { onTellMeMore(recommendation) }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Recommendation Card") {
    ZStack {
        Color.black.ignoresSafeArea()

        RecommendationCardView(
            recommendation: RecommendationEngine.Recommendation(
                title: "The Name of the Wind",
                author: "Patrick Rothfuss",
                reasoning: "A beautifully written epic fantasy with a poet's prose"
            ),
            onAddToLibrary: {},
            onTellMeMore: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
