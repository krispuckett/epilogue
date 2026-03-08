import SwiftUI
import SwiftData

// MARK: - Generic Mode AI Conversation
extension AmbientModeView {

    /// Routes text to the appropriate Generic mode AI handler
    func sendToGenericAIConversation(_ text: String) {
        // 1. Add user message to display
        let userMessage = UnifiedChatMessage(
            content: text,
            isUser: true,
            timestamp: Date(),
            bookContext: nil,  // No book context in Generic mode
            messageType: .text
        )
        messages.append(userMessage)

        // 2. Show typing indicator (V0 pattern)
        withAnimation(.easeOut(duration: 0.2)) {
            isGenericModeThinking = true
        }

        #if DEBUG
        print("🤖 Generic Mode: Routing to AI conversation: '\(text)'")
        #endif

        // 3. Check for specialized flow intents (recommendations, reading plans, insights)
        let conversationFlows = AmbientConversationFlows.shared
        if let flowIntent = conversationFlows.detectFlowIntent(from: text) {
            #if DEBUG
            print("🎯 Detected flow intent: \(flowIntent)")
            #endif
            Task {
                await handleSpecializedFlow(flowIntent, userText: text)
            }
            return
        }

        // 4. Standard AI conversation for general questions
        Task {
            await getGenericAIResponse(for: text)
        }
    }

    /// Processes AI response for Generic mode conversations
    func getGenericAIResponse(for text: String) async {
        // Create AI response message placeholder
        let aiMessage = UnifiedChatMessage(
            content: "",
            isUser: false,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        let messageId = aiMessage.id

        do {
            // Use the existing Perplexity service for streaming
            let service = OptimizedPerplexityService.shared

            var fullResponse = ""
            var isFirstChunk = true

            // Build the specialized Generic Mode system prompt
            let genericModePrompt = buildGenericModeSystemPrompt()

            // Build conversation history for context (last 10 messages)
            let conversationHistory = buildConversationHistory()

            // Use streamSonarResponse with custom system prompt for Generic mode
            for try await response in service.streamSonarResponse(
                text,
                bookContext: nil,  // No book context in Generic mode
                enrichment: nil,
                sessionHistory: conversationHistory,
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: nil,
                customSystemPrompt: genericModePrompt
            ) {
                fullResponse = response.text

                await MainActor.run {
                    // On first chunk, hide typing indicator and add the message
                    if isFirstChunk {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isGenericModeThinking = false
                        }
                        messages.append(aiMessage)
                        // Expand the new AI message
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(messageId)
                        }
                        isFirstChunk = false
                    }

                    // v0 best practice: Update streamingResponses dictionary with smooth animation
                    // instead of recreating the entire message struct on every chunk
                    withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.86, blendDuration: 0.25)) {
                        streamingResponses[messageId] = fullResponse
                    }
                }
            }

            // Streaming complete - finalize message content
            await MainActor.run {
                let finalResponse = streamingResponses[messageId] ?? fullResponse

                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index] = UnifiedChatMessage(
                        id: messageId,
                        content: finalResponse,
                        isUser: false,
                        timestamp: aiMessage.timestamp,
                        bookContext: nil,
                        messageType: .text
                    )
                    streamingResponses.removeValue(forKey: messageId)
                }

                // Save to session for session summary
                startAmbientSessionIfNeeded()
                saveQuestionToCurrentSession(text, response: finalResponse)
            }

        } catch {
            #if DEBUG
            print("❌ Generic AI response error: \(error)")
            #endif

            await MainActor.run {
                // Hide typing indicator on error
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                streamingResponses.removeValue(forKey: messageId)

                // Add error message
                messages.append(UnifiedChatMessage(
                    content: "Sorry, I couldn't process that. Please try again.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                ))
            }
        }
    }

    /// Processes AI response with a custom system prompt (for specialized flows like reading plans, analysis)
    func getGenericAIResponseWithCustomPrompt(userQuery: String, systemPrompt: String) async {
        // Create AI response message placeholder
        let aiMessage = UnifiedChatMessage(
            content: "",
            isUser: false,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        let messageId = aiMessage.id

        do {
            let service = OptimizedPerplexityService.shared

            var fullResponse = ""
            var isFirstChunk = true

            // Use streamSonarResponse with the custom system prompt
            for try await response in service.streamSonarResponse(
                userQuery,
                bookContext: nil,
                enrichment: nil,
                sessionHistory: nil,
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: nil,
                customSystemPrompt: systemPrompt
            ) {
                fullResponse = response.text

                await MainActor.run {
                    if isFirstChunk {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isGenericModeThinking = false
                        }
                        messages.append(aiMessage)
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(messageId)
                        }
                        isFirstChunk = false
                    }

                    // v0 best practice: Update streamingResponses dictionary with smooth animation
                    // instead of recreating the entire message struct on every chunk
                    withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.86, blendDuration: 0.25)) {
                        streamingResponses[messageId] = fullResponse
                    }
                }
            }

            // Streaming complete - finalize message content
            await MainActor.run {
                let finalResponse = streamingResponses[messageId] ?? fullResponse

                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index] = UnifiedChatMessage(
                        id: messageId,
                        content: finalResponse,
                        isUser: false,
                        timestamp: aiMessage.timestamp,
                        bookContext: nil,
                        messageType: .text
                    )
                    streamingResponses.removeValue(forKey: messageId)
                }

                // Save to session for session summary
                startAmbientSessionIfNeeded()
                saveQuestionToCurrentSession(userQuery, response: finalResponse)
            }

        } catch {
            #if DEBUG
            print("❌ Custom prompt AI response error: \(error)")
            #endif

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                streamingResponses.removeValue(forKey: messageId)

                messages.append(UnifiedChatMessage(
                    content: "Sorry, I couldn't process that. Please try again.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                ))
            }
        }
    }

    /// Get Claude-based recommendation response for mood/vibe queries
    /// Uses Claude for more thoughtful, literary recommendations
    func getClaudeRecommendationResponse(for query: String) async {
        let libraryContext = buildLibraryContext()

        // Build vibe-focused system prompt
        let vibePrompt = """
        You are a literary companion with deep understanding of books' emotional landscapes.

        \(libraryContext)

        IF THE USER IS UNCERTAIN (asking for help figuring out what they want):
        Ask exactly 2-3 SHORT questions to understand their mood. Format each question on its own line:

        **Question 1?**

        **Question 2?**

        Keep questions brief (one sentence each). No explanations or options after each question.

        IF THE USER KNOWS WHAT THEY WANT:
        Give 3-4 recommendations:
        1. **Title** by Author - Why this fits their vibe (1-2 sentences)
        2. **Title** by Author - Why this fits (1-2 sentences)
        [etc.]

        RULES:
        - Be concise and conversational
        - No emojis
        - Never recommend books they already own
        - End with one brief follow-up question
        """

        do {
            let response = try await ClaudeService.shared.subscriberChat(
                message: query,
                systemPrompt: vibePrompt,
                maxTokens: 1500
            )

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }

                let aiMessage = UnifiedChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)

                // Expand the response
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.removeAll()
                    expandedMessageIds.insert(aiMessage.id)
                }

                // Save to session for session summary
                startAmbientSessionIfNeeded()
                saveQuestionToCurrentSession(query, response: response)
            }

        } catch {
            #if DEBUG
            print("❌ Claude recommendation error: \(error)")
            #endif

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }

                // Fallback to Perplexity with brief user notice
                localToastMessage = "Switching to backup AI..."
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showLocalToast = true
                }
                Task {
                    await getGenericAIResponse(for: query)
                }
            }
        }
    }

    /// Builds the system prompt for Generic mode AI conversations
    func buildGenericModeSystemPrompt() -> String {
        // Fetch user's library for personalized recommendations
        let libraryContext = buildLibraryContext()

        var prompt = """
        You are a book recommendation assistant in the Epilogue reading app.

        CRITICAL RULE: When asked for book recommendations, you MUST provide EXACTLY 3-5 book suggestions. Never give just 1 book. This is mandatory.
        """

        // Add personalized library context if available
        if !libraryContext.isEmpty {
            prompt += "\n\n" + libraryContext
        }

        prompt += """

        FORMAT (follow exactly):
        1. **Book Title** by Author Name - Brief 1-2 sentence description explaining why this book fits.
        2. **Book Title** by Author Name - Brief description.
        3. **Book Title** by Author Name - Brief description.
        [Continue to 4-5 if relevant]

        Then ask ONE follow-up question to refine future recommendations.

        RULES:
        - MINIMUM 3 books per recommendation request
        - Use markdown bold for titles: **Title**
        - Keep descriptions concise (1-2 sentences each)
        - End with a single follow-up question
        - No emojis
        - No phrases like "Great question!" or "Excellent choice!"
        - Be direct and helpful
        - NEVER recommend books the user has already read or owns
        - Base suggestions on their reading history and preferences
        """

        return prompt
    }

    /// Builds conversation history for AI context (last 10 messages)
    func buildConversationHistory() -> [String] {
        // Get the last 10 messages (excluding the current one being responded to)
        let recentMessages = messages.suffix(10)

        return recentMessages.map { message in
            let role = message.isUser ? "User" : "Assistant"
            return "\(role): \(message.content)"
        }
    }

    /// Builds context from user's library for personalized recommendations
    func buildLibraryContext() -> String {
        // Fetch books from SwiftData
        let fetchDescriptor = FetchDescriptor<BookModel>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )

        guard let books = try? modelContext.fetch(fetchDescriptor), !books.isEmpty else {
            return ""
        }

        // Categorize books by reading status
        let readBooks = books.filter { $0.readingStatus == ReadingStatus.read.rawValue }
        let currentlyReading = books.filter { $0.readingStatus == ReadingStatus.currentlyReading.rawValue }
        let wantToRead = books.filter { $0.readingStatus == ReadingStatus.wantToRead.rawValue }

        // Extract themes from read books (keyThemes is the AI-enriched themes array)
        let allThemes: [String] = readBooks.flatMap { $0.keyThemes ?? [] }
        let uniqueThemes = Array(Set(allThemes)).prefix(6)

        // Extract favorite authors (from highly rated books - userRating is Double 0-5)
        let ratedBooks = readBooks.filter { ($0.userRating ?? 0) >= 4.0 }
        let favoriteAuthors = Array(Set(ratedBooks.map { $0.author })).prefix(5)

        var context = "USER'S READING PROFILE:\n"

        // Books they've read (sample of recent ones)
        if !readBooks.isEmpty {
            let recentRead = readBooks.prefix(8).map { "\($0.title) by \($0.author)" }
            context += "Recently finished: \(recentRead.joined(separator: ", "))\n"
        }

        // Currently reading
        if !currentlyReading.isEmpty {
            let current = currentlyReading.prefix(3).map { "\($0.title) by \($0.author)" }
            context += "Currently reading: \(current.joined(separator: ", "))\n"
        }

        // Want to read (don't recommend these - they already want them)
        if !wantToRead.isEmpty {
            let tbr = wantToRead.prefix(5).map { $0.title }
            context += "Already on their TBR list (don't recommend): \(tbr.joined(separator: ", "))\n"
        }

        // Preferred themes
        if !uniqueThemes.isEmpty {
            context += "Themes they enjoy: \(uniqueThemes.joined(separator: ", "))\n"
        }

        // Favorite authors
        if !favoriteAuthors.isEmpty {
            context += "Favorite authors: \(favoriteAuthors.joined(separator: ", "))\n"
        }

        // Total library size for context
        context += "Library size: \(books.count) books (\(readBooks.count) read, \(currentlyReading.count) in progress, \(wantToRead.count) on TBR)\n"

        return context
    }

    func determineContentType(_ text: String) -> AmbientProcessedContent.ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        // Check for questions - be comprehensive
        if trimmed.hasSuffix("?") ||
           lowercased.starts(with: "who ") ||
           lowercased.starts(with: "what ") ||
           lowercased.starts(with: "where ") ||
           lowercased.starts(with: "when ") ||
           lowercased.starts(with: "why ") ||
           lowercased.starts(with: "how ") ||
           lowercased.starts(with: "is ") ||
           lowercased.starts(with: "are ") ||
           lowercased.starts(with: "can ") ||
           lowercased.starts(with: "could ") ||
           lowercased.starts(with: "would ") ||
           lowercased.starts(with: "should ") ||
           lowercased.starts(with: "will ") ||
           lowercased.starts(with: "do ") ||
           lowercased.starts(with: "does ") ||
           lowercased.starts(with: "did ") ||
           lowercased.starts(with: "has ") ||
           lowercased.starts(with: "have ") ||
           lowercased.starts(with: "had ") ||
           lowercased.starts(with: "tell me") ||
           lowercased.starts(with: "explain") ||
           lowercased.starts(with: "describe") ||
           lowercased.starts(with: "analyze") ||
           lowercased.starts(with: "compare") ||
           lowercased.starts(with: "contrast") ||
           lowercased.starts(with: "summarize") ||
           lowercased.starts(with: "define") ||
           lowercased.starts(with: "discuss") ||
           lowercased.starts(with: "elaborate") ||
           lowercased.starts(with: "clarify") ||
           lowercased.contains("tell me about") ||
           lowercased.contains("what about") ||
           lowercased.contains("how about") ||
           lowercased.contains("thoughts on") ||
           lowercased.contains("opinion on") ||
           lowercased.contains("do you think") ||
           lowercased.contains("what do you think") {
            return .question
        }

        // Check for quotes - with or without quotation marks
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("\u{201C}") && trimmed.hasSuffix("\u{201D}")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
           lowercased.starts(with: "quote:") {
            return .quote
        }

        // Everything else is a note
        return .note
    }

    /// Parse conversational response to extract book recommendations and generate follow-ups
    func parseConversationalResponse(_ response: String, originalQuestion: String) -> ConversationalResponseParsed {
        var recommendations: [UnifiedChatMessage.BookRecommendation] = []
        var cleanedText = response
        var followUps: [String] = []

        // Pattern to detect book recommendations: **Title** by Author
        let bookPattern = #"\*\*([^*]+)\*\*\s+by\s+([^(\n]+)"#
        if let regex = try? NSRegularExpression(pattern: bookPattern, options: []) {
            let matches = regex.matches(in: response, options: [], range: NSRange(response.startIndex..., in: response))

            for match in matches {
                if let titleRange = Range(match.range(at: 1), in: response),
                   let authorRange = Range(match.range(at: 2), in: response),
                   let fullMatchRange = Range(match.range, in: response) {
                    let title = String(response[titleRange]).trimmingCharacters(in: .whitespaces)
                    let author = String(response[authorRange]).trimmingCharacters(in: .whitespaces)

                    // Extract reason (text following the book on the same line or next line)
                    let afterMatch = response[fullMatchRange.upperBound...]
                    let reason = extractReason(from: String(afterMatch))

                    let rec = UnifiedChatMessage.BookRecommendation(
                        title: title,
                        author: author,
                        reason: reason,
                        coverURL: nil, // Could be fetched from Google Books API
                        isbn: nil,
                        purchaseURL: nil
                    )
                    recommendations.append(rec)
                }
            }
        }

        // If we found recommendations, extract intro text
        let hasRecommendations = recommendations.count >= 2
        if hasRecommendations {
            // Get text before the first book mention
            if let firstBookIndex = response.range(of: "**")?.lowerBound {
                let introText = String(response[..<firstBookIndex])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                cleanedText = introText.isEmpty ? "Here are some books you might enjoy:" : introText
            }
        }

        // Generate follow-up questions based on context
        followUps = generateFollowUpQuestions(originalQuestion: originalQuestion, response: response)

        return ConversationalResponseParsed(
            cleanedText: cleanedText,
            recommendations: recommendations,
            followUps: followUps,
            hasRecommendations: hasRecommendations
        )
    }

    /// Extract reason text after a book recommendation
    func extractReason(from text: String) -> String {
        // Get the first line or sentence after the book
        let lines = text.components(separatedBy: CharacterSet.newlines)
        if let firstLine = lines.first {
            let trimmed = firstLine
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "()-\u{2013}"))
                .trimmingCharacters(in: .whitespaces)

            // Limit to a reasonable length
            if trimmed.count > 100 {
                return String(trimmed.prefix(100)) + "..."
            }
            return trimmed.isEmpty ? "Recommended for you" : trimmed
        }
        return "Recommended for you"
    }

    /// Generate contextual follow-up questions
    func generateFollowUpQuestions(originalQuestion: String, response: String) -> [String] {
        var followUps: [String] = []
        let questionLower = originalQuestion.lowercased()
        let responseLower = response.lowercased()

        // Book recommendation context
        if responseLower.contains("recommend") || responseLower.contains("might enjoy") || responseLower.contains("you'd like") {
            followUps.append("Tell me more about one of these")
            followUps.append("Something more literary")
            followUps.append("Anything newer?")
        }
        // Reading habits context
        else if questionLower.contains("read") && questionLower.contains("next") {
            followUps.append("What genre am I in the mood for?")
            followUps.append("Based on my favorites")
            followUps.append("Something short")
        }
        // General conversation
        else {
            followUps.append("Tell me more")
            followUps.append("Any book recommendations?")
            followUps.append("What else should I know?")
        }

        // Check if AI asked a question - if so, don't add generic follow-ups
        if response.contains("?") {
            // AI asked a question, let user respond naturally
            return []
        }

        return Array(followUps.prefix(3))
    }

    /// Handles specialized conversation flows (recommendations, reading plans, insights)
    func handleSpecializedFlow(_ flow: AmbientConversationFlows.ConversationFlow, userText: String) async {
        let conversationFlows = AmbientConversationFlows.shared
        let books = libraryViewModel.books

        switch flow {
        case .recommendation:
            // Start general recommendation flow
            for await update in await conversationFlows.startRecommendationFlow(books: books) {
                await handleFlowUpdate(update)
            }

        case .moodBasedRecommendation(let mood):
            // Start mood-based recommendation flow
            for await update in await conversationFlows.startMoodRecommendationFlow(mood: mood) {
                await handleFlowUpdate(update)
            }

        case .vibeBasedRecommendation(let bookTitle):
            // Start vibe-based recommendation flow - find books with similar emotional resonance
            for await update in await conversationFlows.startVibeRecommendationFlow(bookTitle: bookTitle, library: books) {
                await handleFlowUpdate(update)
            }

        case .readingPlan:
            // Generic plan request - show habit flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .habit
                }
            }

        case .readingHabit:
            // Show the reading habit question flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .habit
                }
            }

        case .readingChallenge:
            // Show the reading challenge question flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .challenge
                }
            }

        case .libraryInsights:
            // Generate library insights
            let insights = await conversationFlows.generateLibraryInsights(books: books)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                // Add insights as AI message
                let aiMessage = UnifiedChatMessage(
                    content: insights,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }
            }
        }
    }

    /// Handles flow updates from AmbientConversationFlows
    func handleFlowUpdate(_ update: FlowUpdate) async {
        await MainActor.run {
            switch update {
            case .status(let statusText):
                // Update a status message or show progress
                #if DEBUG
                print("📊 Flow status: \(statusText)")
                #endif

            case .clarificationNeeded(let question):
                // Hide thinking, show clarification
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                let aiMessage = UnifiedChatMessage(
                    content: question.question,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }

            case .recommendations(let recs):
                // Hide thinking, show recommendations
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                // Convert RecommendationEngine.Recommendation to UnifiedChatMessage.BookRecommendation
                let bookRecs = recs.map { rec in
                    UnifiedChatMessage.BookRecommendation(
                        title: rec.title,
                        author: rec.author,
                        reason: rec.reasoning,
                        coverURL: rec.coverURL,
                        isbn: nil,  // RecommendationEngine doesn't provide ISBN
                        purchaseURL: nil
                    )
                }
                // Add as a recommendations message
                let aiMessage = UnifiedChatMessage(
                    content: formatRecommendationsText(recs),
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .bookRecommendations(bookRecs)
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }

            case .readingPlan(let journey):
                // Hide thinking, show reading plan
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                let journeyDescription = journey.userIntent ?? "your reading journey"
                let bookCount = journey.books?.count ?? 0
                let aiMessage = UnifiedChatMessage(
                    content: "I've created a reading plan for you! 📚\n\n**\(journeyDescription)**\n\n\(bookCount) books queued up for your journey. You can view and manage it in your Reading Journey section.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }

            case .insights(let insightsText):
                // Hide thinking, show insights
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                let aiMessage = UnifiedChatMessage(
                    content: insightsText,
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
                withAnimation(DesignSystem.Animation.easeStandard) {
                    expandedMessageIds.insert(aiMessage.id)
                }

            case .error(let errorMessage):
                // Hide thinking, show error
                withAnimation(.easeOut(duration: 0.2)) {
                    isGenericModeThinking = false
                }
                let aiMessage = UnifiedChatMessage(
                    content: "Sorry, I ran into an issue: \(errorMessage)",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: nil,
                    messageType: .text
                )
                messages.append(aiMessage)
            }
        }
    }

    /// Helper to update existing thinking message or append new one
    func updateOrAppendMessage(question: String, response: String) {
        if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && ($0.content.contains("**\(question)**") || $0.content == "Analyzing your library...") }) {
            let updatedMessage = UnifiedChatMessage(
                content: "**\(question)**\n\n\(response)",
                isUser: false,
                timestamp: messages[thinkingIndex].timestamp,
                bookContext: currentBookContext
            )
            messages[thinkingIndex] = updatedMessage
            expandedMessageIds.insert(updatedMessage.id)
        } else {
            let newMessage = UnifiedChatMessage(
                content: "**\(question)**\n\n\(response)",
                isUser: false,
                timestamp: Date(),
                bookContext: currentBookContext
            )
            messages.append(newMessage)
            expandedMessageIds.insert(newMessage.id)
        }
    }

    /// Formats recommendations into readable text
    func formatRecommendationsText(_ recs: [RecommendationEngine.Recommendation]) -> String {
        if recs.isEmpty {
            return "I couldn't find specific recommendations right now. Try telling me more about what you're in the mood for!"
        }

        var text = "Based on your library, here are some books I think you'd love:\n\n"
        for (index, rec) in recs.prefix(5).enumerated() {
            text += "**\(index + 1). \(rec.title)** by \(rec.author)\n"
            text += "\(rec.reasoning)\n\n"
        }
        return text
    }

    /// Handle conversation flow routing
    func handleConversationFlow(_ flow: AmbientConversationFlows.ConversationFlow, originalText: String) async {
        let conversationFlows = AmbientConversationFlows.shared

        switch flow {
        case .recommendation:
            // Start recommendation flow
            updateOrAppendMessage(question: originalText, response: "Analyzing your library for recommendations...")
            let stream = await conversationFlows.startRecommendationFlow(books: libraryViewModel.books)
            for await update in stream {
                switch update {
                case .status(let status):
                    updateOrAppendMessage(question: originalText, response: status)
                case .clarificationNeeded(let question):
                    let options = question.options?.joined(separator: ", ") ?? ""
                    updateOrAppendMessage(question: originalText, response: question.question + (options.isEmpty ? "" : "\n\nOptions: " + options))
                case .recommendations(let recs):
                    let recText = recs.map { "**\($0.title)** by \($0.author)\n\($0.reasoning)" }.joined(separator: "\n\n")
                    updateOrAppendMessage(question: originalText, response: recText.isEmpty ? "No recommendations found based on your library." : recText)
                case .error(let error):
                    updateOrAppendMessage(question: originalText, response: error)
                default:
                    break
                }
            }

        case .readingPlan:
            // Start reading plan flow - returns a single FlowUpdate (clarification question)
            updateOrAppendMessage(question: originalText, response: "Creating your personalized reading plan...")
            let update = conversationFlows.startReadingPlanFlow(books: libraryViewModel.books)
            switch update {
            case .status(let status):
                updateOrAppendMessage(question: originalText, response: status)
            case .clarificationNeeded(let question):
                let options = question.options?.joined(separator: ", ") ?? ""
                updateOrAppendMessage(question: originalText, response: question.question + (options.isEmpty ? "" : "\n\nOptions: " + options))
            case .readingPlan(let plan):
                let planText = "**Your Reading Plan**\n\n" + (plan.books?.map { "• \($0.bookModel?.title ?? "Unknown")" }.joined(separator: "\n") ?? "No books in plan")
                updateOrAppendMessage(question: originalText, response: planText)
            case .error(let error):
                updateOrAppendMessage(question: originalText, response: error)
            default:
                break
            }

        case .libraryInsights:
            // Generate library insights
            updateOrAppendMessage(question: originalText, response: "Analyzing your reading patterns...")
            let insights = await conversationFlows.generateLibraryInsights(books: libraryViewModel.books)
            updateOrAppendMessage(question: originalText, response: insights)

        case .moodBasedRecommendation(let mood):
            // Handle mood-based recommendation
            updateOrAppendMessage(question: originalText, response: "Finding books for your \(mood) mood...")
            let stream = await conversationFlows.startRecommendationFlow(books: libraryViewModel.books)
            for await update in stream {
                switch update {
                case .status(let status):
                    updateOrAppendMessage(question: originalText, response: status)
                case .recommendations(let recs):
                    let recText = recs.map { "**\($0.title)** by \($0.author)\n\($0.reasoning)" }.joined(separator: "\n\n")
                    updateOrAppendMessage(question: originalText, response: recText.isEmpty ? "No recommendations found." : recText)
                default:
                    break
                }
            }

        case .readingHabit:
            // Show the reading habit question flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .habit
                }
            }

        case .readingChallenge:
            // Show the reading challenge question flow
            await MainActor.run {
                isGenericModeThinking = false
                isKeyboardFocused = false
                withAnimation(DesignSystem.Animation.springStandard) {
                    showReadingPlanFlow = .challenge
                }
            }

        case .vibeBasedRecommendation(let bookTitle):
            // Find books with similar emotional resonance
            updateOrAppendMessage(question: originalText, response: "Finding books with similar vibes to \"\(bookTitle)\"...")
            let stream = await conversationFlows.startVibeRecommendationFlow(bookTitle: bookTitle, library: libraryViewModel.books)
            for await update in stream {
                switch update {
                case .status(let status):
                    updateOrAppendMessage(question: originalText, response: status)
                case .recommendations(let recs):
                    let recText = recs.map { "**\($0.title)** by \($0.author)\n\($0.reasoning)" }.joined(separator: "\n\n")
                    updateOrAppendMessage(question: originalText, response: recText.isEmpty ? "Couldn't find books with similar vibes." : "Books with similar vibes to \"\(bookTitle)\":\n\n" + recText)
                case .error(let error):
                    updateOrAppendMessage(question: originalText, response: error)
                default:
                    break
                }
            }
        }
    }
}
