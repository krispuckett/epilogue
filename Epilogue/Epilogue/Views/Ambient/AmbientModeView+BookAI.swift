import SwiftUI
import SwiftData

// MARK: - Book-Specific AI
extension AmbientModeView {

    /// Clean book AI conversation - uses **Question**\n\nAnswer format for book mode UI
    func sendToBookAIConversation(_ text: String, book: Book, displayQuestion: String) {
        // Ensure session exists
        startAmbientSessionIfNeeded()

        // Collapse previous messages
        withAnimation(DesignSystem.Animation.easeStandard) {
            expandedMessageIds.removeAll()
        }

        // Get AI response (will create combined Q&A message)
        Task {
            await getBookAIResponse(for: text, book: book, displayQuestion: displayQuestion)
        }
    }

    /// Get AI response for book context - creates **Question**\n\nAnswer format message
    func getBookAIResponse(for question: String, book: Book, displayQuestion: String) async {
        // Create placeholder AI message with question shown while loading
        let aiMessage = UnifiedChatMessage(
            content: "**\(displayQuestion)**",  // Show question while loading
            isUser: false,
            timestamp: Date(),
            bookContext: book,
            messageType: .text
        )
        let messageId = aiMessage.id

        // Add message immediately so user sees their question
        await MainActor.run {
            messages.append(aiMessage)
            withAnimation(DesignSystem.Animation.easeStandard) {
                expandedMessageIds.insert(messageId)
            }
        }

        do {
            let service = OptimizedPerplexityService.shared
            var fullResponse = ""

            for try await response in service.streamSonarResponse(
                question,
                bookContext: book,
                enrichment: nil,
                sessionHistory: buildConversationHistory(),
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: book.currentPage > 0 ? book.currentPage : nil,
                customSystemPrompt: nil
            ) {
                // Clean the response
                fullResponse = response.text
                    .replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\.([A-Z])"#, with: ". $1", options: .regularExpression)
                    .replacingOccurrences(of: "  ", with: " ")

                await MainActor.run {
                    // v0 best practice: Update streamingResponses dictionary with smooth animation
                    // instead of recreating the entire message struct on every chunk
                    withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.86, blendDuration: 0.25)) {
                        streamingResponses[messageId] = fullResponse
                    }
                }
            }

            // Streaming complete - finalize message content
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    let finalContent = "**\(displayQuestion)**\n\n\(streamingResponses[messageId] ?? fullResponse)"
                    messages[index] = UnifiedChatMessage(
                        id: messageId,
                        content: finalContent,
                        isUser: false,
                        timestamp: aiMessage.timestamp,
                        bookContext: book,
                        messageType: .text
                    )
                    streamingResponses.removeValue(forKey: messageId)
                }
                saveQuestionToCurrentSession(question, response: fullResponse)
            }

        } catch {
            await MainActor.run {
                streamingResponses.removeValue(forKey: messageId)
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index] = UnifiedChatMessage(
                        id: messageId,
                        content: "**\(displayQuestion)**\n\nSorry, I couldn't get a response. Please try again.",
                        isUser: false,
                        timestamp: aiMessage.timestamp,
                        bookContext: book,
                        messageType: .text
                    )
                }
            }
        }
    }

    /// Handle tapping a related question pill to continue the conversation
    func handleRelatedQuestionTap(_ question: String) {
        // Use the same flow as regular text input for consistency
        keyboardText = question
        sendTextMessage()
    }

    /// Get AI response specifically for book context questions
    /// Uses streamingResponses for smooth text animation (v0 best practice)
    func getBookSpecificAIResponse(for question: String, book: Book) async {
        // Create AI response placeholder with question format
        // The message content stays static; streaming text goes to streamingResponses
        let aiMessage = UnifiedChatMessage(
            content: "**\(question)**",  // Just the question - answer streams separately
            isUser: false,
            timestamp: Date(),
            bookContext: book,
            messageType: .text
        )
        let messageId = aiMessage.id

        do {
            let service = OptimizedPerplexityService.shared
            var fullResponse = ""
            var capturedRelatedQuestions: [String] = []
            var isFirstChunk = true

            // Use streaming with book context
            for try await response in service.streamSonarResponse(
                question,
                bookContext: book,
                enrichment: nil,
                sessionHistory: buildConversationHistory(),
                userNotes: nil,
                userQuotes: nil,
                userQuestions: nil,
                currentPage: book.currentPage > 0 ? book.currentPage : nil,
                customSystemPrompt: nil  // Let it use default book-aware prompt
            ) {
                fullResponse = response.text

                // Capture related questions when available (usually at end of stream)
                if !response.relatedQuestions.isEmpty {
                    capturedRelatedQuestions = response.relatedQuestions
                }

                await MainActor.run {
                    if isFirstChunk {
                        // Clear thinking indicator when streaming starts
                        pendingQuestion = nil

                        messages.append(aiMessage)
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.removeAll()
                            expandedMessageIds.insert(messageId)
                        }
                        isFirstChunk = false
                    }

                    // Clean citations from response
                    let cleanedResponse = fullResponse
                        .replacingOccurrences(of: #"\[\d+\]"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"\.([A-Z])"#, with: ". $1", options: .regularExpression)
                        .replacingOccurrences(of: #"\?([A-Z])"#, with: "? $1", options: .regularExpression)
                        .replacingOccurrences(of: #"\!([A-Z])"#, with: "! $1", options: .regularExpression)
                        .replacingOccurrences(of: "  ", with: " ")

                    // Update streaming text with smooth animation (v0 best practice)
                    // This avoids recreating the message struct on every chunk
                    withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.86, blendDuration: 0.25)) {
                        streamingResponses[messageId] = cleanedResponse
                    }
                }
            }

            // Streaming complete - finalize message content and store related questions
            await MainActor.run {
                // Update message with final content (question + answer)
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    let finalContent = "**\(question)**\n\n\(streamingResponses[messageId] ?? fullResponse)"
                    messages[index] = UnifiedChatMessage(
                        id: messageId,
                        content: finalContent,
                        isUser: false,
                        timestamp: aiMessage.timestamp,
                        bookContext: book,
                        messageType: .text
                    )
                    // Clear streaming text now that it's in the message
                    streamingResponses.removeValue(forKey: messageId)
                }

                if !capturedRelatedQuestions.isEmpty {
                    relatedQuestionsMap[messageId] = capturedRelatedQuestions
                }
                saveQuestionToCurrentSession(question, response: fullResponse)
            }

        } catch {
            await MainActor.run {
                pendingQuestion = nil
                messages.append(UnifiedChatMessage(
                    content: "**\(question)**\n\nSorry, I couldn't process that. Please try again.",
                    isUser: false,
                    timestamp: Date(),
                    bookContext: book,
                    messageType: .text
                ))
            }
        }
    }

    /// Handle tapping a book-specific suggestion pill
    /// Uses a clean pattern similar to generic mode for reliable display
    func handleBookSuggestionTap(_ suggestion: String) {
        guard let book = currentBookContext else {
            // Fallback to generic if no book context
            keyboardText = suggestion
            sendTextMessage()
            return
        }

        let lowercased = suggestion.lowercased()

        // Check for similar books request
        if lowercased.contains("similar") || lowercased.contains("like this") {
            // Show recommendation flow with book context
            withAnimation(DesignSystem.Animation.springStandard) {
                showRecommendationFlow = true
            }
            return
        }

        // Enhance the question with book context for better AI responses
        let enhancedQuestion: String
        if lowercased.contains("theme") {
            enhancedQuestion = "What are the main themes in \(book.title) by \(book.author)?"
        } else if lowercased.contains("about") {
            enhancedQuestion = "Tell me about \(book.author), the author of \(book.title)"
        } else if lowercased.contains("review my notes") {
            enhancedQuestion = "Summarize my notes for \(book.title)"
        } else if lowercased.contains("summarize where") {
            enhancedQuestion = "Summarize where I am in \(book.title) - I'm on page \(book.currentPage)"
        } else {
            enhancedQuestion = suggestion
        }

        // Use clean conversation pattern (like generic mode)
        sendToBookAIConversation(enhancedQuestion, book: book, displayQuestion: suggestion)
    }

    /// Triggers the reading taste analysis flow
    func triggerReadingTasteAnalysis() {
        // Build analysis prompt with library context
        let analysisPrompt = buildReadingTasteAnalysisPrompt()

        // Add user message
        let userMessage = UnifiedChatMessage(
            content: "Analyze my reading taste",
            isUser: true,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        messages.append(userMessage)

        // Get AI response
        isGenericModeThinking = true
        Task {
            await getGenericAIResponseWithCustomPrompt(
                userQuery: analysisPrompt,
                systemPrompt: buildReadingAnalysisSystemPrompt()
            )
        }
    }

    /// Build the prompt for reading taste analysis
    func buildReadingTasteAnalysisPrompt() -> String {
        let libraryContext = buildLibraryContext()
        return """
        Based on my reading history, analyze my reading taste and patterns.

        \(libraryContext)

        Tell me:
        1. What themes and genres I gravitate toward
        2. My reading comfort zone vs. blind spots
        3. Authors or styles I might enjoy but haven't tried
        4. One surprising insight about my reading patterns
        """
    }

    /// System prompt specifically for reading analysis
    func buildReadingAnalysisSystemPrompt() -> String {
        return """
        You are a literary analyst in the Epilogue reading app. Analyze the user's reading taste based on their library data.

        FORMAT:
        - Start with a brief, insightful summary of their reading identity (2-3 sentences)
        - Use clear sections with bold headers: **Themes You Love**, **Your Comfort Zone**, **Blind Spots**, **Try Next**
        - Keep each section to 2-3 bullet points max
        - End with ONE genuinely surprising or insightful observation

        RULES:
        - Be specific and reference actual books from their library
        - No generic advice - everything should feel personalized
        - No emojis
        - Be direct, insightful, occasionally witty
        - If they have few books, acknowledge this and focus on what patterns exist
        """
    }

    /// Get AI response for ambient mode voice-detected questions
    func getAIResponse(for text: String) async {
        let aiService = AICompanionService.shared
        let offlineQueue = OfflineQueueManager.shared
        let conversationFlows = AmbientConversationFlows.shared

        // MARK: - Check for conversation flow intents FIRST
        // This routes specialized queries (reading plans, library insights) to their proper handlers
        if let flowIntent = conversationFlows.detectFlowIntent(from: text) {
            await handleConversationFlow(flowIntent, originalText: text)
            return
        }

        guard aiService.isConfigured() else {
            await MainActor.run {
                // Update thinking message to show error
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let updatedMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\nPlease configure your AI service.",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        bookContext: currentBookContext
                    )
                    messages[thinkingIndex] = updatedMessage
                } else {
                    let configMessage = UnifiedChatMessage(
                        content: "Please configure your AI service.",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(configMessage)
                }
            }
            return
        }

        // Check network status - if offline, queue the question
        if !offlineQueue.isOnline {
            await MainActor.run {
                offlineQueue.addQuestion(text, book: currentBookContext, sessionContext: currentSession?.id?.uuidString)

                // Update UI to show queued state
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let queuedMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\n📵 You're offline. This question has been queued and will be answered when you're back online.",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        bookContext: currentBookContext
                    )
                    messages[thinkingIndex] = queuedMessage
                } else {
                    let queuedMessage = UnifiedChatMessage(
                        content: "📵 You're offline. This question has been queued and will be answered when you're back online.",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(queuedMessage)
                }

                // Save question to current session
                if let session = currentSession {
                    let capturedQuestion = CapturedQuestion(
                        content: text,
                        book: currentBookContext.map { BookModel(from: $0) },
                        pageNumber: nil,
                        timestamp: Date(),
                        source: .manual
                    )
                    capturedQuestion.answer = "Queued for when you're back online"
                    capturedQuestion.isAnswered = false

                    if session.capturedQuestions == nil {
                        session.capturedQuestions = []
                    }
                    session.capturedQuestions?.append(capturedQuestion)
                    try? modelContext.save()
                }
            }
            return
        }

        do {
            // For generic mode (no book context), use conversational prompting
            let enhancedPrompt: String
            if currentBookContext == nil {
                enhancedPrompt = """
                You are a friendly reading companion having a conversation. Be warm, curious, and engaging.

                IMPORTANT FORMATTING RULES:
                1. Keep responses concise and conversational (2-3 short paragraphs max)
                2. When recommending books, list them clearly with:
                   - **Title** by Author
                   - A brief one-line reason why they'd enjoy it
                3. End with a follow-up question to continue the conversation
                4. Use natural paragraph breaks for readability

                User's message: \(text)
                """
            } else {
                enhancedPrompt = text
            }

            let response = try await aiService.processMessage(
                enhancedPrompt,
                bookContext: currentBookContext,
                conversationHistory: messages
            )

            await MainActor.run {
                // For generic mode, create conversational response with follow-ups
                if currentBookContext == nil {
                    // Parse response for potential book recommendations
                    let parsedResponse = parseConversationalResponse(response, originalQuestion: text)

                    // Update thinking message with conversational response
                    if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                        let updatedMessage = UnifiedChatMessage(
                            content: parsedResponse.cleanedText,
                            isUser: false,
                            timestamp: messages[thinkingIndex].timestamp,
                            bookContext: nil,
                            messageType: parsedResponse.hasRecommendations
                                ? .bookRecommendations(parsedResponse.recommendations)
                                : .conversationalResponse(text: parsedResponse.cleanedText, followUpQuestions: parsedResponse.followUps)
                        )
                        messages[thinkingIndex] = updatedMessage
                        expandedMessageIds.insert(updatedMessage.id)
                    } else {
                        let aiMessage = UnifiedChatMessage(
                            content: parsedResponse.cleanedText,
                            isUser: false,
                            timestamp: Date(),
                            bookContext: nil,
                            messageType: parsedResponse.hasRecommendations
                                ? .bookRecommendations(parsedResponse.recommendations)
                                : .conversationalResponse(text: parsedResponse.cleanedText, followUpQuestions: parsedResponse.followUps)
                        )
                        messages.append(aiMessage)
                        expandedMessageIds.insert(aiMessage.id)
                    }
                } else {
                    // Book mode - use existing behavior
                    if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                        let updatedMessage = UnifiedChatMessage(
                            content: "**\(text)**\n\n\(response)",
                            isUser: false,
                            timestamp: messages[thinkingIndex].timestamp,
                            bookContext: currentBookContext
                        )
                        messages[thinkingIndex] = updatedMessage

                        // AUTO-EXPAND the first question's answer!
                        let nonUserMessages = messages.filter { !$0.isUser }
                        if nonUserMessages.count == 1 {
                            withAnimation(DesignSystem.Animation.easeStandard) {
                                expandedMessageIds.insert(updatedMessage.id)
                            }
                        }
                    } else {
                        // No thinking message found - create with proper format
                        let aiMessage = UnifiedChatMessage(
                            content: "**\(text)**\n\n\(response)",
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext
                        )
                        messages.append(aiMessage)
                    }
                }
                pendingQuestion = nil

                // Update the processed content with the response
                if let pendingQ = pendingQuestion,
                   let index = processor.detectedContent.firstIndex(where: { $0.text == pendingQ && $0.type == .question }) {
                    processor.detectedContent[index] = AmbientProcessedContent(
                        text: pendingQ,
                        type: .question,
                        timestamp: processor.detectedContent[index].timestamp,
                        confidence: 1.0,
                        response: response,
                        bookTitle: currentBookContext?.title,
                        bookAuthor: currentBookContext?.author
                    )

                    // CRITICAL: Update the saved question in SwiftData with the answer
                    if let session = currentSession {
                        // Find the question in the current session's questions
                        if let question = (session.capturedQuestions ?? []).first(where: { $0.content == pendingQ }) {
                            question.answer = response
                            question.isAnswered = true

                            // Record conversation usage (only counts when AI actually answers)
                            storeKit.recordConversation()

                            try? modelContext.save()
                            #if DEBUG
                            print("✅ Updated SwiftData question with answer for summary view")
                            #endif
                        }
                    }
                }
                pendingQuestion = nil
            }
        } catch {
            await MainActor.run {
                // Update thinking message to show error
                var errorContent: String

                // Check if it's a rate limit error
                if let perplexityError = error as? PerplexityError,
                   case .rateLimitExceeded(_, _) = perplexityError {
                    errorContent = """
                    **\(text)**

                    **Monthly Conversation Limit Reached.**

                    You've used all your free ambient conversations this month.

                    **Want unlimited conversations?**

                    Upgrade to Epilogue+ for unlimited ambient AI conversations.

                    [UPGRADE_BUTTON]
                    """
                } else {
                    // Check for rate limit in error description
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("rateLimitExceeded") || errorDesc.contains("rate limit") {
                        errorContent = """
                        **\(text)**

                        **Monthly Conversation Limit Reached.**

                        You've used all your free ambient conversations this month.

                        **Want unlimited conversations?**

                        Upgrade to Epilogue+ for unlimited ambient AI conversations.

                        [UPGRADE_BUTTON]
                        """
                    } else {
                        errorContent = "**\(text)**\n\nSorry, I couldn't process your message right now. Please try again."
                    }
                }

                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let updatedMessage = UnifiedChatMessage(
                        content: errorContent,
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        bookContext: currentBookContext
                    )
                    messages[thinkingIndex] = updatedMessage
                } else {
                    let errorMessage = UnifiedChatMessage(
                        content: errorContent,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(errorMessage)
                }
                pendingQuestion = nil
                #if DEBUG
                print("❌ Failed to process message: \(error)")
                #endif
            }
        }
    }

    /// Get AI response for ambient voice-detected questions (with processing animation)
    func getAIResponseForAmbientQuestion(_ text: String) async {
        let aiService = AICompanionService.shared

        // First update the thinking message to show it's processing
        await MainActor.run {
            if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                let processingMessage = UnifiedChatMessage(
                    content: "**\(text)**",  // Just the question, no answer yet
                    isUser: false,
                    timestamp: messages[thinkingIndex].timestamp,
                    messageType: .text
                )
                messages[thinkingIndex] = processingMessage

                // Auto-expand this message to show the scrolling text
                expandedMessageIds.insert(processingMessage.id)
            }
        }

        // Small delay to show the animation
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        guard aiService.isConfigured() else {
            #if DEBUG
            print("🔑 AI Service configured: false")
            #endif
            await MainActor.run {
                // Update thinking message to show error with better formatting
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") }) {
                    let errorMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\n\u{26A0}\u{FE0F} **AI Service Not Configured**\n\nTo get AI responses, please add your Perplexity API key in Settings \u{2192} AI Services.\n\n*Your question has been saved and will be available when you configure the service.*",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        messageType: .text
                    )
                    messages[thinkingIndex] = errorMessage
                }
                pendingQuestion = nil
            }
            return
        }

        do {
            let response = try await aiService.processMessage(
                text,
                bookContext: currentBookContext,
                conversationHistory: messages
            )

            await MainActor.run {
                // Update the thinking message with the actual response
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") && !$0.content.contains("\n\n") }) {
                    let updatedMessage = UnifiedChatMessage(
                        content: "**\(text)**\n\n\(response)",
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        messageType: .text
                    )
                    messages[thinkingIndex] = updatedMessage

                    // AUTO-EXPAND the first question's answer!
                    let nonUserMessages = messages.filter { !$0.isUser }
                    if nonUserMessages.count == 1 {
                        // This is the first question/answer - auto-expand it
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            expandedMessageIds.insert(updatedMessage.id)
                        }
                    }
                }

                // Update the processed content with the response
                if let index = processor.detectedContent.firstIndex(where: { $0.text == text && $0.type == .question && $0.response == nil }) {
                    processor.detectedContent[index] = AmbientProcessedContent(
                        text: text,
                        type: .question,
                        timestamp: processor.detectedContent[index].timestamp,
                        confidence: 1.0,
                        response: response,
                        bookTitle: currentBookContext?.title,
                        bookAuthor: currentBookContext?.author
                    )
                    #if DEBUG
                    print("✅ Updated ambient question with AI response: \(text.prefix(30))...")
                    #endif
                }

                // CRITICAL: Update the saved question in SwiftData with the answer
                if let session = currentSession {
                    // Find the question in the current session's questions
                    if let question = (session.capturedQuestions ?? []).first(where: { $0.content == text }) {
                        question.answer = response
                        question.isAnswered = true

                        // Record conversation usage (only counts when AI actually answers)
                        storeKit.recordConversation()

                        try? modelContext.save()
                        #if DEBUG
                        print("✅ Updated SwiftData question with answer for summary view")
                        #endif
                        #if DEBUG
                        print("   Session has \((session.capturedQuestions ?? []).count) questions")
                        #endif
                    }
                }

                pendingQuestion = nil
            }
        } catch {
            await MainActor.run {
                // Update thinking message to show error
                if let thinkingIndex = messages.lastIndex(where: { !$0.isUser && $0.content.contains("**") }) {
                    var errorContent: String

                    // Check if it's a rate limit error
                    if let perplexityError = error as? PerplexityError,
                       case .rateLimitExceeded(_, let resetTime) = perplexityError {
                        // Show rate limit message for Epilogue+ conversation limit
                        let storeKit = SimplifiedStoreKitManager.shared
                        let remaining = storeKit.conversationsRemaining() ?? 0

                        let calendar = Calendar.current
                        let now = Date()

                        // Calculate time until next month (first day of next month)
                        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now)!
                        let firstOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))!

                        let components = calendar.dateComponents([.day, .hour], from: now, to: firstOfNextMonth)
                        let daysUntilReset = components.day ?? 0
                        let hoursUntilReset = components.hour ?? 0

                        let resetTimeStr: String
                        if daysUntilReset > 0 {
                            resetTimeStr = "\(daysUntilReset)d \(hoursUntilReset)h"
                        } else {
                            resetTimeStr = "\(hoursUntilReset)h"
                        }

                        errorContent = """
                        **\(text)**

                        **Monthly Conversation Limit Reached.**

                        You've used all 8 of your free ambient conversations this month. Your limit resets in \(resetTimeStr) (on the 1st of next month).

                        Your question has been saved and you can try again when your limit resets.

                        **Want unlimited conversations?**

                        Upgrade to Epilogue+ for unlimited ambient AI conversations with your books.

                        [UPGRADE_BUTTON]
                        """
                    } else {
                        // Generic error message with better formatting
                        let errorDesc = error.localizedDescription
                        if errorDesc.contains("rateLimitExceeded") {
                            // Fallback for rate limit errors that don't match the pattern
                            errorContent = """
                            **\(text)**

                            **Monthly Conversation Limit Reached.**

                            You've used all your free ambient conversations this month.

                            **Want unlimited conversations?**

                            Upgrade to Epilogue+ for unlimited ambient AI conversations.

                            [UPGRADE_BUTTON]
                            """
                        } else {
                            errorContent = "**\(text)**\n\nSorry, I couldn't process your message right now. Please try again."
                        }
                    }

                    let updatedMessage = UnifiedChatMessage(
                        content: errorContent,
                        isUser: false,
                        timestamp: messages[thinkingIndex].timestamp,
                        messageType: .text
                    )
                    messages[thinkingIndex] = updatedMessage
                }
                pendingQuestion = nil
                #if DEBUG
                print("❌ Failed to get AI response: \(error)")
                #endif
            }
        }
    }

    /// Handle tapping an empty state suggestion
    func handleSuggestionTap(_ suggestion: String) {
        let lowercased = suggestion.lowercased()

        // Check for recommendation requests
        let isRecommendationRequest = lowercased.contains("read next") ||
                                       lowercased.contains("recommend") ||
                                       lowercased.contains("something like")

        // Check for reading habit flow
        let isHabitRequest = lowercased.contains("reading habit") ||
                             lowercased.contains("build a habit")

        // Check for reading challenge flow
        let isChallengeRequest = lowercased.contains("reading challenge") ||
                                  lowercased.contains("create a challenge")

        // Check for reading taste/patterns analysis
        let isAnalysisRequest = lowercased.contains("reading taste") ||
                                 lowercased.contains("reading patterns") ||
                                 lowercased.contains("analyze my")

        if isRecommendationRequest {
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = nil  // Dismiss any existing plan card
                showRecommendationFlow = true
            }
        } else if isHabitRequest {
            isKeyboardFocused = false // Dismiss keyboard before showing flow
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = nil  // Dismiss any existing plan card
                showReadingPlanFlow = .habit
            }
        } else if isChallengeRequest {
            isKeyboardFocused = false // Dismiss keyboard before showing flow
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = nil  // Dismiss any existing plan card
                showReadingPlanFlow = .challenge
            }
        } else if isAnalysisRequest {
            // Trigger reading taste analysis directly with library context
            triggerReadingTasteAnalysis()
        } else {
            // Populate the input bar with the suggestion text
            keyboardText = suggestion
            inputMode = .textInput
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isKeyboardFocused = true
            }
        }
    }
}
