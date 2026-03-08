import SwiftUI
import SwiftData

// MARK: - Reading Plans
extension AmbientModeView {

    /// Handle completion of the reading plan question flow (habit or challenge)
    func handleReadingPlanFlowComplete(_ context: ReadingPlanContext) {
        // Store context for later parsing
        readingPlanContext = context

        // Hide the question flow
        withAnimation(DesignSystem.Animation.springStandard) {
            showReadingPlanFlow = nil
        }

        // Create the plan directly from context (no AI chat needed)
        createReadingPlanFromContext(context)
    }

    /// Create a reading plan directly from the question flow context
    func createReadingPlanFromContext(_ context: ReadingPlanContext) {
        let days = context.durationDays
        let planBook = context.selectedBook ?? currentBookContext

        // Use book title if selected, otherwise generic title
        let title: String
        let goal: String

        switch context.flowType {
        case .habit:
            title = planBook?.title ?? "\(days)-Day Reading Kickstart"
            goal = "Build a sustainable reading habit that fits your schedule"
        case .challenge:
            title = planBook?.title ?? "Reading Challenge"
            goal = context.challengeOrBlocker ?? "Complete your reading goal"
        }

        #if DEBUG
        print("📋 Creating reading plan: '\(title)' (type: \(context.flowType))")
        #endif

        let plan = ReadingHabitPlan(
            type: context.flowType == .habit ? .habit : .challenge,
            title: title,
            goal: goal
        )
        plan.preferredTime = context.timePreference
        plan.commitmentLevel = context.commitmentLevel
        plan.planDuration = context.planDuration
        if let book = planBook {
            plan.bookId = book.id
            plan.bookTitle = book.title
            plan.bookAuthor = book.author
            plan.bookCoverURL = book.coverImageURL
        }

        // Set notification preferences from onboarding
        plan.notificationsEnabled = context.notificationsEnabled
        if context.notificationsEnabled {
            plan.notificationTime = context.notificationTime
        }

        // Initialize days for both habit and challenge plans
        if context.flowType == .habit {
            plan.initializeDays(count: days)
        } else {
            plan.challengeType = context.planDuration
            plan.ambitionLevel = context.commitmentLevel
            plan.timeframe = context.timePreference
            plan.initializeDays(count: days) // Challenges also need days initialized
        }

        #if DEBUG
        print("📋 Plan configured - isActive: \(plan.isActive), days: \(plan.days?.count ?? 0)")
        #endif

        // Insert and save
        modelContext.insert(plan)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Reading plan saved successfully: \(plan.title) (id: \(plan.id))")
            #endif

            // Store reference and show the timeline directly
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = plan
                showPlanDetail = true  // Go directly to timeline view
            }

            // Provide haptic feedback
            SensoryFeedback.success()

            // Show local toast notification (visible in fullScreenCover)
            let toastMessage = context.flowType == .habit
                ? "Reading habit created! Find it in Reading Plans."
                : "Challenge created! Find it in Reading Plans."
            localToastMessage = toastMessage
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showLocalToast = true
            }

            // Ask user about notification preferences
            promptForNotifications(plan: plan)

        } catch {
            #if DEBUG
            print("❌ Failed to save reading plan: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            #endif

            // Show error toast (local for fullScreenCover visibility)
            localToastMessage = "Failed to create plan. Please try again."
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showLocalToast = true
            }
        }
    }

    /// Get AI response for reading plan and create structured plan from it
    func getReadingPlanAIResponse(userQuery: String, context: ReadingPlanContext) async {
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
            let systemPrompt = buildReadingPlanSystemPrompt(for: context.flowType)

            var fullResponse = ""
            var isFirstChunk = true

            // Stream the response
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

            // Streaming complete - finalize message content and create the plan
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index] = UnifiedChatMessage(
                        id: messageId,
                        content: streamingResponses[messageId] ?? fullResponse,
                        isUser: false,
                        timestamp: aiMessage.timestamp,
                        bookContext: nil,
                        messageType: .text
                    )
                    streamingResponses.removeValue(forKey: messageId)
                }
                createReadingPlanFromResponse(fullResponse, context: context)
            }

        } catch {
            #if DEBUG
            print("❌ Reading plan AI response error: \(error)")
            #endif
            await MainActor.run {
                isGenericModeThinking = false
                streamingResponses.removeValue(forKey: messageId)
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index] = UnifiedChatMessage(
                        id: messageId,
                        content: "Sorry, I couldn't create your reading plan. Please try again.",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: nil,
                        messageType: .text
                    )
                }
            }
        }
    }

    /// Parse AI response and create a ReadingHabitPlan
    func createReadingPlanFromResponse(_ response: String, context: ReadingPlanContext) {
        let plan: ReadingHabitPlan?

        switch context.flowType {
        case .habit:
            plan = ReadingPlanParser.parseHabitPlan(from: response, context: context)
        case .challenge:
            plan = ReadingPlanParser.parseChallengePlan(from: response, context: context)
        }

        guard let plan = plan else {
            #if DEBUG
            print("⚠️ Could not parse reading plan from response")
            #endif
            return
        }

        // Save to SwiftData
        modelContext.insert(plan)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Reading plan saved: \(plan.title)")
            #endif

            // Store reference and show the card
            withAnimation(DesignSystem.Animation.springStandard) {
                createdReadingPlan = plan
            }

            // Provide haptic feedback
            SensoryFeedback.success()

            // Ask user about notification preferences
            promptForNotifications(plan: plan)

        } catch {
            #if DEBUG
            print("❌ Failed to save reading plan: \(error)")
            #endif
        }
    }

    /// Prompt user to enable notifications for their reading plan
    func promptForNotifications(plan: ReadingHabitPlan) {
        // Only prompt if user chose to enable notifications during onboarding
        guard plan.notificationsEnabled else {
            #if DEBUG
            print("🔔 Skipping notification prompt - user selected 'No reminders'")
            #endif
            return
        }

        Task {
            // Check current permission status
            let status = await ReadingPlanNotificationService.shared.checkPermissionStatus()

            switch status {
            case .notDetermined:
                // Request permission and schedule if granted
                let granted = await ReadingPlanNotificationService.shared.requestPermission()
                if granted {
                    try? modelContext.save()
                    await ReadingPlanNotificationService.shared.scheduleReminders(for: plan)

                    // Add a chat message about notifications
                    await MainActor.run {
                        addNotificationConfirmationMessage(for: plan)
                    }
                } else {
                    // User denied - update plan
                    plan.notificationsEnabled = false
                    try? modelContext.save()
                }

            case .authorized:
                // Already authorized, just schedule
                try? modelContext.save()
                await ReadingPlanNotificationService.shared.scheduleReminders(for: plan)

                await MainActor.run {
                    addNotificationConfirmationMessage(for: plan)
                }

            case .denied, .provisional, .ephemeral:
                // Can't send notifications - update plan
                plan.notificationsEnabled = false
                try? modelContext.save()
                #if DEBUG
                print("🔔 Notifications not available (status: \(status.rawValue))")
                #endif

            @unknown default:
                break
            }
        }
    }

    /// Add a chat message confirming notification setup
    func addNotificationConfirmationMessage(for plan: ReadingHabitPlan) {
        let timeDescription: String
        if let preferredTime = plan.preferredTime {
            timeDescription = "around \(preferredTime.lowercased())"
        } else {
            timeDescription = "each day"
        }

        let message = UnifiedChatMessage(
            content: "I'll send you a gentle reminder \(timeDescription) to help you stay on track. You can adjust or turn off notifications anytime in Settings.",
            isUser: false,
            timestamp: Date(),
            bookContext: currentBookContext
        )
        messages.append(message)
    }

    /// Build specialized system prompt for reading habit/challenge plans
    func buildReadingPlanSystemPrompt(for flowType: ReadingPlanQuestionFlow.FlowType) -> String {
        let libraryContext = buildLibraryContext()

        switch flowType {
        case .habit:
            return """
            You are a reading coach in the Epilogue app. Create a personalized, actionable reading habit plan.

            \(libraryContext.isEmpty ? "" : "USER'S LIBRARY:\n\(libraryContext)\n")

            FORMAT YOUR RESPONSE EXACTLY LIKE THIS:

            **Your 7-Day Reading Kickstart**

            **The Goal**: [One clear, specific goal based on their answers]

            **Your Daily Ritual**:
            - **When**: [Specific time based on their preference]
            - **Where**: [Suggest a cozy spot]
            - **How long**: [Based on their commitment level]
            - **The trigger**: [A habit stack suggestion - "After I [existing habit], I will read"]

            **Week 1 Roadmap**:
            - Day 1-2: Start with just 5 pages, no pressure
            - Day 3-4: Increase to [their target]
            - Day 5-7: Establish the full routine

            **Your First Book**: [Suggest a specific book from their TBR or a new one that's easy to start]

            **One Pro Tip**: [Specific advice addressing their blocker]

            RULES:
            - Be specific, not generic. Reference their actual time preference and blockers.
            - Make it feel achievable, not overwhelming
            - If they mentioned being busy, emphasize small wins
            - If they struggle with focus, suggest audiobooks or short chapters
            - No emojis
            - End with an encouraging but not cheesy closing line
            """

        case .challenge:
            return """
            You are a reading challenge creator in the Epilogue app. Design an exciting, personalized reading challenge.

            \(libraryContext.isEmpty ? "" : "USER'S LIBRARY:\n\(libraryContext)\n")

            FORMAT YOUR RESPONSE EXACTLY LIKE THIS:

            **Your [Timeframe] Reading Challenge**

            **The Challenge**: [Clear challenge statement based on their goals]

            **Your Target**: [Specific number of books or pages based on ambition level]

            **The Rules**:
            1. [Rule based on their challenge type - e.g., "Each book must be from a different genre"]
            2. [Supporting rule]
            3. [Flexibility rule - one "wildcard" or skip allowed]

            **Milestone Checkpoints**:
            - [First milestone]: [Reward/celebration suggestion]
            - [Mid-point]: [Check-in activity]
            - [Final stretch]: [Motivation boost]

            **Starter Books**:
            1. **[Book Title]** by [Author] - [Why it fits the challenge]
            2. **[Book Title]** by [Author] - [Why it fits]
            3. **[Book Title]** by [Author] - [Why it fits]

            **Accountability Tip**: [One specific suggestion for staying on track]

            RULES:
            - Match intensity to their ambition level (Gentle = 3-5 books, Ambitious = 10+, All in = stretch goal)
            - If they want to explore genres, suggest specific genres to try
            - If they want to clear TBR, reference books from their want-to-read list
            - Make milestones feel rewarding, not arbitrary
            - No emojis
            - End with a rallying cry that matches their energy level
            """
        }
    }

    /// Handle completion of the recommendation question flow
    func handleRecommendationFlowComplete(_ context: RecommendationContext) {
        // Hide the question flow
        withAnimation(DesignSystem.Animation.springStandard) {
            showRecommendationFlow = false
        }

        // Store context and send enhanced request
        recommendationContext = context

        // Build the enhanced prompt
        let enhancedPrompt = context.buildPromptContext()

        // Add user message
        let userMessage = UnifiedChatMessage(
            content: enhancedPrompt,
            isUser: true,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        messages.append(userMessage)

        // Get AI response with the context
        isGenericModeThinking = true
        Task {
            await getGenericAIResponse(for: enhancedPrompt)
        }
    }

    /// Handle mood-based recommendation selection from conversational view
    func handleMoodRecommendation(_ mood: AmbientConversationFlows.ReadingMood) {
        // Hide the recommendation flow
        withAnimation(DesignSystem.Animation.springStandard) {
            showRecommendationFlow = false
        }

        // Use the mood's built-in natural prompt - this is well-crafted for Claude
        let moodPrompt = mood.prompt

        // Add user message (display a shorter version)
        let displayMessage = "I'm in the mood for: \(mood.rawValue)"
        let userMessage = UnifiedChatMessage(
            content: displayMessage,
            isUser: true,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        messages.append(userMessage)

        // Use Claude for vibe-based recommendations (not Perplexity)
        isGenericModeThinking = true
        Task {
            await getClaudeRecommendationResponse(for: moodPrompt)
        }
    }

    /// Handle conversation starter selection from conversational view
    func handleConversationStarterSelected(_ prompt: String) {
        // Hide the recommendation flow
        withAnimation(DesignSystem.Animation.springStandard) {
            showRecommendationFlow = false
        }

        // Add user message with full prompt (don't truncate)
        let userMessage = UnifiedChatMessage(
            content: prompt,
            isUser: true,
            timestamp: Date(),
            bookContext: nil,
            messageType: .text
        )
        messages.append(userMessage)

        // Use Claude for recommendation-related prompts (they're vibe-focused)
        isGenericModeThinking = true
        Task {
            await getClaudeRecommendationResponse(for: prompt)
        }
    }
}
