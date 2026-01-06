import Foundation
import SwiftUI
import Combine

// MARK: - Reading Companion
/// The brain of the Reading Companion system.
/// Orchestrates proactive help, determines when to intervene, and manages the companion experience.

@MainActor
@Observable
final class ReadingCompanion {
    static let shared = ReadingCompanion()

    // MARK: - State

    private(set) var activeBookProfile: BookIntelligence.BookProfile?
    private(set) var readerState: ReaderState = ReaderState()
    private(set) var companionState: CompanionState = .idle
    private(set) var pendingSuggestions: [CompanionSuggestion] = []
    private(set) var sessionHistory: [CompanionInteraction] = []

    // Dependencies
    private let bookIntelligence = BookIntelligence.shared
    private let promptLibrary = CompanionPromptLibrary.shared

    private init() {}

    // MARK: - Reader State

    struct ReaderState {
        var currentBook: BookModel?
        var readingProgress: Double = 0
        var sessionStartTime: Date?
        var pagesThisSession: Int = 0
        var questionsAsked: Int = 0
        var lastInteractionTime: Date?
        var confusionSignals: Int = 0
        var hasSeenPreparation: Bool = false
        var hasSeenApproachGuide: Bool = false

        var isNewToBook: Bool {
            readingProgress < 0.05
        }

        var isEarlyReading: Bool {
            readingProgress >= 0.05 && readingProgress < 0.2
        }

        var isMidReading: Bool {
            readingProgress >= 0.2 && readingProgress < 0.7
        }

        var isNearingEnd: Bool {
            readingProgress >= 0.7
        }

        var sessionDuration: TimeInterval? {
            guard let start = sessionStartTime else { return nil }
            return Date().timeIntervalSince(start)
        }

        var seemsConfused: Bool {
            confusionSignals >= 2
        }
    }

    // MARK: - Companion State

    enum CompanionState {
        case idle
        case observing
        case readyToHelp(suggestion: CompanionSuggestion)
        case helping
        case reflecting
    }

    // MARK: - Companion Suggestion

    struct CompanionSuggestion: Identifiable, Equatable {
        let id = UUID()
        let type: SuggestionType
        let headline: String          // Short text for pill
        let fullPrompt: String         // What to say when tapped
        let priority: Priority
        let context: SuggestionContext
        let expiresAfterProgress: Double?  // Optional: hide after this progress %

        static func == (lhs: CompanionSuggestion, rhs: CompanionSuggestion) -> Bool {
            lhs.id == rhs.id
        }
    }

    enum SuggestionType {
        case preparation       // Pre-read guide
        case approach          // How to read this
        case context           // Historical/cultural context
        case characterGuide    // Who's who
        case structureGuide    // How the book is organized
        case checkIn           // How's it going?
        case encouragement     // Keep going!
        case clarification     // Confused about something?
        case progressCelebration // Milestone reached
        case insight           // Theme/connection observation
        case pacing            // Reading pace suggestion
    }

    enum Priority: Int, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct SuggestionContext {
        let triggerReason: String
        let spoilerSafe: Bool
        let requiresAI: Bool
    }

    // MARK: - Companion Interaction

    struct CompanionInteraction {
        let timestamp: Date
        let type: SuggestionType
        let userEngaged: Bool
        let bookId: String
        let progress: Double
    }

    // MARK: - Core Methods

    /// Called when user opens a book or starts a reading session
    func onBookOpened(_ book: BookModel) async {
        // Analyze the book if we haven't already
        activeBookProfile = await bookIntelligence.analyzeBook(book)

        // Update reader state
        readerState.currentBook = book
        // Calculate reading progress from currentPage and pageCount
        if let pageCount = book.pageCount, pageCount > 0 {
            readerState.readingProgress = Double(book.currentPage) / Double(pageCount)
        } else {
            readerState.readingProgress = 0
        }
        readerState.sessionStartTime = Date()
        readerState.pagesThisSession = 0
        readerState.questionsAsked = 0
        readerState.confusionSignals = 0

        // Generate initial suggestions based on book profile
        await generateSuggestions()

        companionState = .observing

        #if DEBUG
        if let profile = activeBookProfile {
            print("📚 Reading Companion activated for: \(book.title)")
            print("   Intimidation score: \(String(format: "%.2f", profile.intimidationScore))")
            print("   Companion mode: \(profile.companionMode)")
            print("   Needs preparation: \(profile.needsPreparation)")
        }
        #endif
    }

    /// Called when user's reading progress updates
    func onProgressUpdated(_ progress: Double) async {
        let previousProgress = readerState.readingProgress
        readerState.readingProgress = progress

        // Check for milestone crossings
        let milestones = [0.1, 0.25, 0.5, 0.75, 0.9]
        for milestone in milestones {
            if previousProgress < milestone && progress >= milestone {
                await onMilestoneReached(milestone)
            }
        }

        // Regenerate suggestions if we've moved significantly
        if abs(progress - previousProgress) > 0.05 {
            await generateSuggestions()
        }
    }

    /// Called when user asks a question
    func onUserQuestion(_ question: String) {
        readerState.questionsAsked += 1
        readerState.lastInteractionTime = Date()

        // Detect confusion signals
        let confusionIndicators = [
            "confused", "don't understand", "what does", "who is",
            "lost", "can't follow", "makes no sense", "huh"
        ]
        let questionLower = question.lowercased()
        if confusionIndicators.contains(where: { questionLower.contains($0) }) {
            readerState.confusionSignals += 1
        }

        // If user seems confused, offer more help
        if readerState.seemsConfused {
            injectConfusionHelp()
        }
    }

    /// Called when user dismisses a suggestion
    func onSuggestionDismissed(_ suggestion: CompanionSuggestion) {
        pendingSuggestions.removeAll { $0.id == suggestion.id }

        sessionHistory.append(CompanionInteraction(
            timestamp: Date(),
            type: suggestion.type,
            userEngaged: false,
            bookId: readerState.currentBook?.localId ?? "",
            progress: readerState.readingProgress
        ))
    }

    /// Called when user engages with a suggestion
    func onSuggestionEngaged(_ suggestion: CompanionSuggestion) {
        pendingSuggestions.removeAll { $0.id == suggestion.id }
        companionState = .helping

        // Track what they've seen
        switch suggestion.type {
        case .preparation:
            readerState.hasSeenPreparation = true
        case .approach:
            readerState.hasSeenApproachGuide = true
        default:
            break
        }

        sessionHistory.append(CompanionInteraction(
            timestamp: Date(),
            type: suggestion.type,
            userEngaged: true,
            bookId: readerState.currentBook?.localId ?? "",
            progress: readerState.readingProgress
        ))
    }

    /// Called when reading session ends
    func onSessionEnded() {
        companionState = .idle
        readerState.sessionStartTime = nil
    }

    // MARK: - Suggestion Generation

    private func generateSuggestions() async {
        guard let profile = activeBookProfile else { return }

        var suggestions: [CompanionSuggestion] = []

        // === NEW TO BOOK ===
        if readerState.isNewToBook {

            // Preparation suggestion for intimidating books
            if profile.needsPreparation && !readerState.hasSeenPreparation {
                suggestions.append(CompanionSuggestion(
                    type: .preparation,
                    headline: "Want a spoiler-free intro?",
                    fullPrompt: promptLibrary.preparationPrompt(for: profile),
                    priority: .high,
                    context: SuggestionContext(
                        triggerReason: "Book is intimidating and reader is just starting",
                        spoilerSafe: true,
                        requiresAI: true
                    ),
                    expiresAfterProgress: 0.1
                ))
            }

            // Approach suggestion for challenging books
            if profile.difficulty.level == .challenging && !readerState.hasSeenApproachGuide {
                suggestions.append(CompanionSuggestion(
                    type: .approach,
                    headline: "How should I approach this?",
                    fullPrompt: promptLibrary.approachPrompt(for: profile),
                    priority: .high,
                    context: SuggestionContext(
                        triggerReason: "Challenging book, reader may want guidance",
                        spoilerSafe: true,
                        requiresAI: true
                    ),
                    expiresAfterProgress: 0.15
                ))
            }

            // Context suggestion for books that need it
            let essentialContext = profile.contextNeeds.filter { $0.importance == .essential }
            if !essentialContext.isEmpty {
                suggestions.append(CompanionSuggestion(
                    type: .context,
                    headline: "Give me some context",
                    fullPrompt: promptLibrary.contextPrompt(for: profile),
                    priority: .medium,
                    context: SuggestionContext(
                        triggerReason: "Book has essential context needs",
                        spoilerSafe: true,
                        requiresAI: true
                    ),
                    expiresAfterProgress: 0.2
                ))
            }

            // Character guide for books with complex casts
            let hasCharacterChallenge = profile.challenges.contains { $0.type == .largeCharacterCast || $0.type == .unfamiliarNames }
            if hasCharacterChallenge {
                suggestions.append(CompanionSuggestion(
                    type: .characterGuide,
                    headline: "Who should I know?",
                    fullPrompt: promptLibrary.characterGuidePrompt(for: profile),
                    priority: .medium,
                    context: SuggestionContext(
                        triggerReason: "Book has many characters or unfamiliar names",
                        spoilerSafe: true,
                        requiresAI: true
                    ),
                    expiresAfterProgress: 0.25
                ))
            }
        }

        // === EARLY READING (5-20%) ===
        if readerState.isEarlyReading {

            // Check-in for challenging books
            if profile.difficulty.level == .challenging {
                suggestions.append(CompanionSuggestion(
                    type: .checkIn,
                    headline: "How's it going so far?",
                    fullPrompt: promptLibrary.earlyCheckInPrompt(for: profile),
                    priority: .low,
                    context: SuggestionContext(
                        triggerReason: "Early in a challenging book",
                        spoilerSafe: true,
                        requiresAI: false
                    ),
                    expiresAfterProgress: 0.25
                ))
            }

            // Encouragement if they're pushing through
            if readerState.readingProgress > 0.1 && profile.needsPreparation {
                suggestions.append(CompanionSuggestion(
                    type: .encouragement,
                    headline: "You're past the hardest part",
                    fullPrompt: "The beginning is often the most challenging. You're building momentum now — it gets easier from here.",
                    priority: .low,
                    context: SuggestionContext(
                        triggerReason: "Past initial difficulty hump",
                        spoilerSafe: true,
                        requiresAI: false
                    ),
                    expiresAfterProgress: 0.2
                ))
            }
        }

        // === MID READING (20-70%) ===
        if readerState.isMidReading {

            // Insight prompts
            suggestions.append(CompanionSuggestion(
                type: .insight,
                headline: "What themes are you noticing?",
                fullPrompt: promptLibrary.themeDiscussionPrompt(for: profile),
                priority: .low,
                context: SuggestionContext(
                    triggerReason: "Deep enough for thematic discussion",
                    spoilerSafe: true,
                    requiresAI: true
                ),
                expiresAfterProgress: nil
            ))
        }

        // === NEARING END (70%+) ===
        if readerState.isNearingEnd {

            // Reflection prompt
            suggestions.append(CompanionSuggestion(
                type: .insight,
                headline: "How is this landing for you?",
                fullPrompt: promptLibrary.nearEndReflectionPrompt(for: profile),
                priority: .low,
                context: SuggestionContext(
                    triggerReason: "Approaching the end",
                    spoilerSafe: true,
                    requiresAI: false
                ),
                expiresAfterProgress: nil
            ))
        }

        // === CONFUSION DETECTED ===
        if readerState.seemsConfused {
            suggestions.insert(CompanionSuggestion(
                type: .clarification,
                headline: "I can help clarify things",
                fullPrompt: promptLibrary.clarificationOfferPrompt(for: profile),
                priority: .high,
                context: SuggestionContext(
                    triggerReason: "User shows signs of confusion",
                    spoilerSafe: true,
                    requiresAI: true
                ),
                expiresAfterProgress: nil
            ), at: 0)
        }

        // Sort by priority and limit
        suggestions.sort { $0.priority > $1.priority }

        // Filter out expired suggestions
        suggestions = suggestions.filter { suggestion in
            if let expires = suggestion.expiresAfterProgress {
                return readerState.readingProgress < expires
            }
            return true
        }

        // Take top 3 most relevant
        pendingSuggestions = Array(suggestions.prefix(3))

        #if DEBUG
        print("📚 Generated \(pendingSuggestions.count) companion suggestions")
        for suggestion in pendingSuggestions {
            print("   - \(suggestion.type): \(suggestion.headline)")
        }
        #endif
    }

    private func onMilestoneReached(_ milestone: Double) async {
        guard let profile = activeBookProfile else { return }

        let milestoneMessage: String
        switch milestone {
        case 0.1:
            milestoneMessage = "You're 10% in — the world is opening up."
        case 0.25:
            milestoneMessage = "A quarter of the way! You're finding your rhythm."
        case 0.5:
            milestoneMessage = "Halfway there. The story has its hooks in you now."
        case 0.75:
            milestoneMessage = "The home stretch. Everything is building toward resolution."
        case 0.9:
            milestoneMessage = "Almost there. Savor these final pages."
        default:
            return
        }

        // Insert celebration suggestion at top
        let celebration = CompanionSuggestion(
            type: .progressCelebration,
            headline: milestoneMessage,
            fullPrompt: milestoneMessage,
            priority: .medium,
            context: SuggestionContext(
                triggerReason: "Reached \(Int(milestone * 100))% milestone",
                spoilerSafe: true,
                requiresAI: false
            ),
            expiresAfterProgress: milestone + 0.1
        )

        pendingSuggestions.insert(celebration, at: 0)
        if pendingSuggestions.count > 3 {
            pendingSuggestions.removeLast()
        }
    }

    private func injectConfusionHelp() {
        guard let profile = activeBookProfile else { return }

        // If user seems confused and hasn't seen the clarification offer
        let alreadyHasClarification = pendingSuggestions.contains { $0.type == .clarification }
        if !alreadyHasClarification {
            pendingSuggestions.insert(CompanionSuggestion(
                type: .clarification,
                headline: "Feeling lost? I can help",
                fullPrompt: promptLibrary.clarificationOfferPrompt(for: profile),
                priority: .critical,
                context: SuggestionContext(
                    triggerReason: "Multiple confusion signals detected",
                    spoilerSafe: true,
                    requiresAI: true
                ),
                expiresAfterProgress: nil
            ), at: 0)

            if pendingSuggestions.count > 3 {
                pendingSuggestions.removeLast()
            }
        }
    }

    // MARK: - AI Response Generation

    /// Generates an AI response for a companion suggestion
    /// Uses Claude for thoughtful, warm companion responses
    func generateResponse(for suggestion: CompanionSuggestion) async -> String {
        guard let profile = activeBookProfile,
              let bookModel = readerState.currentBook else {
            return "I'd love to help, but I'm not sure which book you're reading."
        }

        // Build the AI prompt with book context and spoiler safety
        let systemPrompt = buildSystemPrompt(for: profile, suggestion: suggestion)
        let userPrompt = suggestion.fullPrompt

        // Use Claude with subscription-aware model (Opus for Plus, Sonnet for free)
        do {
            let response = try await ClaudeService.shared.subscriberChat(
                message: userPrompt,
                systemPrompt: systemPrompt,
                maxTokens: 800
            )

            #if DEBUG
            print("📚 Companion response from Claude (\(ClaudeService.shared.subscriberModel.displayName)): \(response.prefix(100))...")
            #endif

            return response
        } catch {
            #if DEBUG
            print("❌ Claude companion response failed: \(error), trying fallback")
            #endif

            // Fallback: Try Sonar if Claude fails
            do {
                let book = Book(
                    id: bookModel.id,
                    title: bookModel.title,
                    author: bookModel.author,
                    publishedYear: bookModel.publishedYear,
                    coverImageURL: bookModel.coverImageURL,
                    isbn: bookModel.isbn,
                    description: bookModel.desc,
                    pageCount: bookModel.pageCount
                )

                let combinedPrompt = """
                \(systemPrompt)

                ---

                \(userPrompt)
                """

                let response = try await OptimizedPerplexityService.shared.chat(
                    message: combinedPrompt,
                    bookContext: book
                )
                return response
            } catch {
                #if DEBUG
                print("❌ Sonar fallback also failed: \(error)")
                #endif
                return fallbackResponse(for: suggestion, profile: profile)
            }
        }
    }

    private func buildSystemPrompt(for profile: BookIntelligence.BookProfile, suggestion: CompanionSuggestion) -> String {
        let progress = readerState.readingProgress
        let progressPercent = Int(progress * 100)

        // Get conversation context from AmbientContextManager
        let contextManager = AmbientContextManager.shared
        let conversationContext = buildConversationContext(from: contextManager)

        var prompt = """
        You are a reading companion helping someone read "\(profile.book.title)" by \(profile.book.author).

        You're like a well-read friend who has read this book and genuinely wants to help them enjoy it.
        You remember what they've asked before and build on previous conversations.

        READER CONTEXT:
        - Progress: \(progressPercent)%
        \(conversationContext)

        SPOILER PROTECTION (\(progressPercent)%):
        \(buildProgressAwareSpoilerGuidance(progress: progress, profile: profile))

        STYLE GUIDELINES:
        - Be concise — this is a mobile app, not an essay
        - Be warm and conversational, not academic
        - If they're struggling, normalize it — many readers find this challenging
        - Reference their previous questions naturally when relevant
        - No emojis, no sycophantic phrases

        """

        // Add context based on suggestion type
        switch suggestion.type {
        case .preparation:
            prompt += "\nFOCUS: Spoiler-free introduction to help them start reading. Focus on context, atmosphere, and what to expect — not plot."

        case .approach:
            prompt += "\nFOCUS: Practical reading strategies for this specific book."
            for tip in profile.approachRecommendation.duringReadingTips {
                prompt += "\n- \(tip)"
            }

        case .context:
            prompt += "\nFOCUS: Historical/cultural context that enriches understanding. Make it interesting, not like a textbook."

        case .characterGuide:
            prompt += "\nFOCUS: Introduce key characters they'll meet early on. Only describe who they are at the start, not what happens to them."

        case .clarification:
            prompt += "\nFOCUS: The reader seems confused. Gently offer to help clarify without assuming what confuses them. Ask what's unclear."

        case .checkIn:
            prompt += "\nFOCUS: Check in on how they're finding the book. Be genuinely curious, not performative."

        case .encouragement:
            prompt += "\nFOCUS: Genuine encouragement based on where they are in the book. Acknowledge what they've accomplished."

        case .progressCelebration:
            prompt += "\nFOCUS: Celebrate a reading milestone. Keep it brief and genuine, not over-the-top."

        case .insight:
            prompt += "\nFOCUS: Share an interesting observation about themes or connections at their current point. Be thought-provoking."

        case .pacing:
            prompt += "\nFOCUS: Gentle pacing suggestion. No pressure, just helpful guidance."

        case .structureGuide:
            prompt += "\nFOCUS: Explain how the book is structured without revealing plot. Help them navigate the form."
        }

        return prompt
    }

    /// Builds conversation context from the ambient context manager
    private func buildConversationContext(from contextManager: AmbientContextManager) -> String {
        var context: [String] = []

        // Add recent topics if available
        let memoryContext = contextManager.buildEnhancedContext(for: "", book: nil)
        if !memoryContext.isEmpty {
            context.append(memoryContext)
        }

        return context.joined(separator: "\n")
    }

    /// Builds progress-aware spoiler guidance
    private func buildProgressAwareSpoilerGuidance(progress: Double, profile: BookIntelligence.BookProfile) -> String {
        var guidance = ""

        // Add static spoiler boundaries from profile
        let spoilers = profile.spoilerBoundaries
        if !spoilers.safeToReveal.isEmpty {
            guidance += "Safe to discuss:\n"
            for safe in spoilers.safeToReveal.prefix(5) {
                guidance += "- \(safe.content)\n"
            }
        }

        // Add progress-gated content that's now available
        let availableGated = spoilers.revealAfterProgress.filter { $0.revealAfterPercent <= progress * 100 }
        if !availableGated.isEmpty {
            guidance += "\nNow safe (given progress):\n"
            for gated in availableGated.prefix(3) {
                guidance += "- \(gated.content)\n"
            }
        }

        if !spoilers.neverReveal.isEmpty {
            guidance += "\nNEVER reveal:\n"
            for forbidden in spoilers.neverReveal.prefix(5) {
                guidance += "- \(forbidden)\n"
            }
        }

        // Add progress-specific guidance
        if progress < 0.1 {
            guidance += "\nVERY EARLY - stick to premise and context only."
        } else if progress < 0.25 {
            guidance += "\nEARLY - can discuss initial setup but avoid developments."
        } else if progress < 0.5 {
            guidance += "\nFIRST HALF - avoid midpoint twists and second-half events."
        } else if progress < 0.75 {
            guidance += "\nPAST MIDPOINT - avoid climax and resolution."
        } else {
            guidance += "\nNEARING END - almost everything is fair, but protect the ending."
        }

        return guidance
    }

    private func fallbackResponse(for suggestion: CompanionSuggestion, profile: BookIntelligence.BookProfile) -> String {
        // Provide helpful static responses when AI isn't available
        switch suggestion.type {
        case .preparation:
            return """
            Before diving in, here's what might help:

            \(profile.approachRecommendation.preparationSteps.map { "• \($0)" }.joined(separator: "\n"))

            Take your time with the opening pages — they're often the most challenging.
            """

        case .approach:
            return """
            Here's how to approach this:

            \(profile.approachRecommendation.paceGuidance)

            \(profile.approachRecommendation.duringReadingTips.prefix(3).map { "• \($0)" }.joined(separator: "\n"))
            """

        case .clarification:
            return "What's confusing you? I can help explain characters, plot points, or context — just ask."

        default:
            return "I'm here to help with anything about what you're reading. What would you like to know?"
        }
    }

    // MARK: - Reset

    func reset() {
        activeBookProfile = nil
        readerState = ReaderState()
        companionState = .idle
        pendingSuggestions = []
    }
}

// MARK: - Convenience Extensions

extension ReadingCompanion {
    /// Quick check if we should show companion suggestions for current book
    var shouldShowCompanionSuggestions: Bool {
        guard let profile = activeBookProfile else { return false }
        return profile.companionMode != .observer || readerState.seemsConfused
    }

    /// Get the top suggestion to show prominently
    var primarySuggestion: CompanionSuggestion? {
        pendingSuggestions.first
    }

    /// Get secondary suggestions for additional pills
    var secondarySuggestions: [CompanionSuggestion] {
        Array(pendingSuggestions.dropFirst())
    }
}
