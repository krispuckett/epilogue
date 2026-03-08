import SwiftUI
import Foundation
import Combine
import SwiftData
import os.log
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Smart Context-Aware AI Service
@MainActor
class SmartEpilogueAI: ObservableObject {
    static let shared = SmartEpilogueAI()
    
    // Foundation Models (only available on iOS 26+)
    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #else
    private var session: Any?
    #endif
    
    // Perplexity Service for external queries
    private let perplexityService = OptimizedPerplexityService.shared
    
    // Context tracking
    @Published var activeBook: BookModel?
    @Published var currentMode: AIMode = .automatic
    @Published var isProcessing = false
    @Published var lastResponse = ""
    @Published var lastProvider: String = ""

    enum AIMode {
        case automatic      // Smart routing (Foundation → Claude → Perplexity)
        case localOnly      // Foundation Models only
        case claudeOnly     // Claude only
        case externalOnly   // Perplexity only
    }
    
    private init() {
        setupSession()
    }
    
    // MARK: - Session Setup with Book Context
    private func setupSession() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            #if DEBUG
            print("⚠️ Foundation Models requires iOS 26.0 or later")
            #endif
            return
        }
        
        var instructions = "You are Epilogue's AI reading companion."
        
        if let book = activeBook {
            // Build grounded context from SwiftData enrichment (works for ANY book)
            let groundedContext = GroundedBookSession.shared.buildGroundedInstructions(for: book)

            var bookInfo = groundedContext

            // Add book-specific knowledge for popular books (legacy fallback/supplement)
            #if DEBUG
            let enrichmentStatus = GroundedBookSession.shared.enrichmentStatus(for: book)
            print("📚 Setting up AI context for book: \(book.title) by \(book.author) [\(enrichmentStatus.description)]")
            #endif

            if book.title.lowercased().contains("project hail mary") {
                bookInfo += """

                Key Information about Project Hail Mary:
                - Main characters: Ryland Grace (human protagonist) and Rocky (alien friend)
                - Plot: Ryland Grace wakes up alone on a spaceship with amnesia, tasked with saving Earth from extinction
                - Rocky is an Eridian, a spider-like alien who becomes Grace's friend and collaborator
                - The threat is the Astrophage, organisms eating the sun's energy
                - Themes: Science, friendship across species, sacrifice, problem-solving
                """
            } else if book.title.lowercased().contains("lord of the rings") || book.title.lowercased().contains("fellowship") || book.title.lowercased().contains("two towers") || book.title.lowercased().contains("return of the king") {
                bookInfo += """

                Key Information about Lord of the Rings:
                - Main characters: Frodo Baggins (hobbit, ring-bearer), Sam Gamgee (Frodo's loyal companion), Aragorn/Strider (ranger, true king), Gandalf (wizard), Legolas (elf), Gimli (dwarf), Boromir, Merry, Pippin
                - Plot: Frodo must destroy the One Ring in Mount Doom to save Middle-earth from Sauron
                - GANDALF'S TRANSFORMATION:
                  * Gandalf the Grey falls fighting the Balrog in Moria (Fellowship of the Ring)
                  * He dies but is sent back by Eru Ilúvatar as Gandalf the White
                  * Returns in The Two Towers with greater power and authority
                  * Takes Saruman's place as head of the Istari (wizards)
                  * This happens IN THE TWO TOWERS, NOT The Silmarillion!
                - Important Swords:
                  * Sting: Frodo's sword (given by Bilbo, glows blue when orcs are near)
                  * Glamdring: Gandalf's sword (also called Foe-hammer)
                  * Andúril: Aragorn's sword (reforged from Narsil, the sword that cut the Ring from Sauron)
                  * NOT Frodo's sword - Frodo has Sting, not Andúril!
                - The One Ring: Forged by Sauron, corrupts the bearer, must be destroyed
                - Key Events: Battle of Helm's Deep, Battle of Pelennor Fields, Battle at the Black Gate
                - Themes: Good vs evil, friendship, sacrifice, corruption of power, hope against despair
                """
            } else if book.title.lowercased().contains("the silmarillion") {
                bookInfo += """

                Key Information about The Silmarillion:
                - Main themes: Creation myth of Middle-earth, the Silmarils, wars of the First Age
                - Key figures: Eru Ilúvatar, Melkor/Morgoth, Fëanor, Beren and Lúthien
                - Structure: Mythological history from creation through the First Age
                """
            }

            // Add series spoiler protection
            let seriesInfo = detectSeriesInformation(title: book.title, author: book.author)
            var seriesSpoilerInstructions = ""

            if let (seriesName, bookNumber) = seriesInfo {
                seriesSpoilerInstructions = """

                CRITICAL SPOILER PROTECTION:
                This book is part of the "\(seriesName)" series (Book \(bookNumber)).

                STRICT RULES:
                1. The user is currently reading Book \(bookNumber). You may discuss:
                   ✅ Events from Book \(bookNumber) (current book) - NO RESTRICTIONS
                   ✅ Events from Books 1-\(bookNumber - 1) (previous books) - SAFE to reference

                2. You must NEVER reveal or hint at:
                   ❌ Plot points from Book \(bookNumber + 1) or later (future books)
                   ❌ Character fates that occur after Book \(bookNumber)
                   ❌ Major revelations or twists from later books
                   ❌ Events, battles, or outcomes from future installments

                3. If asked about the series or future events:
                   - Say "I can discuss Books 1-\(bookNumber), but I'll avoid spoiling future books"
                   - Suggest they ask again after finishing later books
                """
            } else {
                seriesSpoilerInstructions = """

                SPOILER AWARENESS:
                - If this book is part of a series, discuss only THIS book and any confirmed prequels
                - Do not reveal plot points beyond what the user is currently reading
                - If unsure about spoilers, err on the side of caution
                """
            }

            instructions = bookInfo + seriesSpoilerInstructions + """

            CRITICAL INSTRUCTIONS FOR ANY BOOK:

            Context: The user is actively reading '\(book.title)' by \(book.author).
            They are using Epilogue's ambient mode to ask questions while reading.

            Core Rules:
            1. DEFAULT ASSUMPTION: Every question is about '\(book.title)' unless explicitly about something else
            2. NEVER REFUSE: Do not say "I can't assist" or "I cannot help" - always provide useful information
            3. NO SPOILER CONCERNS FOR THIS BOOK: The user is currently reading this book - answer everything about THIS book
            4. STAY IN CONTEXT: Focus on THIS specific book, respecting spoiler boundaries for future books in the series

            Response Guidelines:
            - If you know the answer from the book, provide it with confidence
            - If you're uncertain, say "Based on what I recall from '\(book.title)'..."
            - If genuinely unsure, say "I don't have that specific detail about '\(book.title)'"
            - NEVER make up facts or claim events happen in different books
            - Draw from your general knowledge about '\(book.title)' even without specific context

            Answer Structure:
            - Start with a direct answer to the question
            - Provide supporting details and context
            - Connect to themes or character development when relevant
            - Aim for 2-3 paragraphs for substantial questions

            Remember: You are a knowledgeable reading companion for '\(book.title)'.
            The user trusts you to enhance their reading experience with accurate information.

            RESPONSE TONE:
            - Be natural and conversational, like a knowledgeable friend
            - Avoid overly formal or literary language ("Thus...", "Indeed...", "One might say...")
            - Use direct, clear sentences
            - Be helpful and informative without being pompous
            - NO emojis in responses
            - NO sycophantic language ("You're right!", "Great question!", "Excellent observation!")
            - NO cliche AI responses ("As an AI...", "I'm here to help...", generic pleasantries)
            - Just answer the question directly and naturally
            """
        }
        
        // Create session with instructions - but only if model is available
        // Check model availability first
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            session = LanguageModelSession(instructions: instructions)
            #if DEBUG
            print("✅ Foundation Models session created successfully")
            #endif
        case .unavailable(.deviceNotEligible):
            #if DEBUG
            print("⚠️ Device not eligible for Apple Intelligence")
            #endif
            session = nil
        case .unavailable(.appleIntelligenceNotEnabled):
            #if DEBUG
            print("⚠️ Apple Intelligence not enabled in Settings")
            #endif
            session = nil
        case .unavailable(.modelNotReady):
            #if DEBUG
            print("⚠️ Model is downloading or not ready")
            #endif
            session = nil
        case .unavailable(let other):
            #if DEBUG
            print("⚠️ Foundation Models unavailable: \(other)")
            #endif
            session = nil
        @unknown default:
            #if DEBUG
            print("⚠️ Foundation Models availability unknown")
            #endif
            session = nil
        }
        #else
        #if DEBUG
        print("⚠️ Foundation Models not available on this iOS version")
        #endif
        #endif
    }
    
    // MARK: - Check if Local Model is Actually Ready
    private func isLocalModelActuallyReady() -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // Check the actual availability status
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                // Model is available and ready
                return true
            case .unavailable(.modelNotReady):
                // Model is still downloading or preparing
                #if DEBUG
                print("⚠️ Model is downloading or not ready")
                #endif
                return false
            case .unavailable(let reason):
                // Other unavailability reasons
                #if DEBUG
                print("⚠️ Model unavailable: \(reason)")
                #endif
                return false
            @unknown default:
                return false
            }
        }
        #endif
        return false
    }
    
    // MARK: - Update Active Book Context
    func setActiveBook(_ book: BookModel?) {
        self.activeBook = book
        setupSession() // Recreate session with new context
    }
    
    // MARK: - Smart Query Routing (OPTIMIZED FOR SPEED)
    func smartQuery(_ question: String) async -> String {
        isProcessing = true
        defer { isProcessing = false }

        // Force mode overrides
        if currentMode == .externalOnly {
            return await queryWithPerplexity(question)
        } else if currentMode == .localOnly {
            return await queryLocal(question)
        } else if currentMode == .claudeOnly {
            return await queryWithClaude(question)
        }

        // AUTOMATIC MODE - Intelligent routing
        // Step 1: Check if external web knowledge is needed → Perplexity
        let needsExternal = await shouldUseExternal(question)
        if needsExternal {
            return await queryWithPerplexity(question)
        }

        // Step 2: Check if deep analysis is needed → Claude
        if shouldUseClaude(question) {
            return await queryWithClaude(question)
        }

        // Step 3: Try Foundation Models locally, with fallback chain
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), session != nil {
            if isLocalModelActuallyReady() {
                return await queryLocal(question)
            } else {
                #if DEBUG
                print("⚡ Local model not ready - falling back to Claude")
                #endif
            }
        }
        #endif

        // Step 4: Fallback → Claude → Perplexity
        return await queryWithClaude(question)
    }
    
    // MARK: - Determine Query Type (OPTIMIZED)
    private func shouldUseExternal(_ question: String) async -> Bool {
        let questionLower = question.lowercased()
        
        // Fast path: If no book context, use Perplexity for general questions
        guard activeBook != nil else {
            #if DEBUG
            print("🌐 No book context - using Perplexity for speed")
            #endif
            return true
        }
        
        // SYSTEMATIC APPROACH FOR ANY BOOK
        
        // 1. Keywords that DEFINITELY need external/current knowledge
        let externalKeywords = [
            "latest", "current", "recent", "news", "2024", "2025", "2026",
            "real world", "actually happened", "true story", "historical",
            "author died", "author born", "author's life", "biography",
            "movie", "film", "tv show", "adaptation", "netflix", "amazon",
            "published", "sales", "awards", "reviews", "bestseller",
            "other books", "similar books", "compare", "recommend",
            "sequel", "prequel", "next book", "series order"
        ]
        
        // Check for external needs FIRST
        for keyword in externalKeywords {
            if questionLower.contains(keyword) {
                #if DEBUG
                print("🌐 External knowledge required for: \(keyword)")
                #endif
                return true
            }
        }
        
        // 2. Question patterns that are ALWAYS about the book content
        let bookQuestionPatterns = [
            "who is", "who are", "who was", "who were",
            "what is", "what are", "what was", "what were",
            "what happens", "what happened",
            "when does", "when did", "when is", "when was",
            "where does", "where did", "where is", "where was",
            "why does", "why did", "why is", "why was",
            "how does", "how did", "how is", "how was",
            "tell me about", "explain", "describe",
            "dies", "died", "death", "kill", "killed",
            "marry", "married", "marriage",
            "fight", "battle", "war",
            "love", "romance", "relationship",
            "power", "magic", "ability",
            "chapter", "part", "book", "volume",
            "beginning", "middle", "end", "ending",
            "main", "protagonist", "antagonist", "villain", "hero",
            "theme", "symbol", "meaning", "represents"
        ]
        
        // Check if it matches book question patterns
        for pattern in bookQuestionPatterns {
            if questionLower.contains(pattern) {
                #if DEBUG
                print("📚 Book content question detected: '\(pattern)' - using local AI")
                #endif
                return false // Use local AI with book context
            }
        }
        
        // 3. Default: Assume it's about the book (when in reading mode)
        #if DEBUG
        print("📚 Default: Treating as book question - using local AI")
        #endif
        return false
    }
    
    // MARK: - Determine if Claude is Best Provider
    private func shouldUseClaude(_ question: String) -> Bool {
        let questionLower = question.lowercased()

        // Deep thinking / literary analysis keywords
        let claudeKeywords = [
            // Meaning and symbolism
            "what does", "what do", "represent", "symbolism", "symbolize",
            "metaphor", "allegory", "imagery",
            // Analysis
            "analyze", "analysis", "interpretation", "significance",
            "deeper meaning", "underlying",
            // Comparison and connections
            "compare", "contrast", "difference between", "connection between",
            "similarities", "parallel",
            // Author craft
            "why does the author", "writing style", "narrative technique",
            "prose style", "literary device", "foreshadowing", "motif",
            // Opinion / subjective
            "what do you think", "your thoughts", "opinion",
            "how do you interpret", "do you believe",
            // Recommendations
            "recommend", "similar books", "if i liked",
            "books like", "should i read"
        ]

        for keyword in claudeKeywords {
            if questionLower.contains(keyword) {
                #if DEBUG
                print("🧠 Deep analysis detected ('\(keyword)') - routing to Claude")
                #endif
                return true
            }
        }

        // Long/complex questions benefit from Claude's reasoning
        if question.count > 100 {
            #if DEBUG
            print("🧠 Complex question (\(question.count) chars) - routing to Claude")
            #endif
            return true
        }

        return false
    }

    // MARK: - Query with Smart Routing
    private func queryWithSmartRouting(_ question: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard let session = session else {
                #if DEBUG
                print("⚠️ No Foundation Models session available, falling back to Perplexity")
                #endif
                return await queryWithPerplexity(question)
            }
            
            do {
                // The session will automatically use tools when needed
                let response = try await session.respond(to: formatQuestionWithContext(question))
                lastResponse = response.content
                return response.content
            } catch {
                #if DEBUG
                print("Smart routing failed: \(error)")
                #endif
                // Fallback to Perplexity
                return await queryWithPerplexity(question)
            }
        } else {
            // iOS version too old, use Perplexity
            return await queryWithPerplexity(question)
        }
        #else
        // Foundation Models not available, use Perplexity
        return await queryWithPerplexity(question)
        #endif
    }
    
    // MARK: - Local Query (Foundation Models)
    private func queryLocal(_ question: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard let session = session else {
                #if DEBUG
                print("⚠️ No Foundation Models session - falling back to Perplexity")
                #endif
                // Automatically fallback to Perplexity when local model unavailable
                return await queryWithPerplexity(question)
            }
            
            let startTime = Date()
            do {
                let formattedQuestion = formatQuestionWithContext(question)
                let response = try await session.respond(to: formattedQuestion)
                lastResponse = response.content
                lastProvider = "Apple Intelligence"

                let responseTime = Date().timeIntervalSince(startTime) * 1000
                #if DEBUG
                print("⚡ Local response in \(String(format: "%.1f", responseTime))ms")
                #endif

                return response.content
            } catch {
                #if DEBUG
                print("❌ Foundation Models error: \(error)")
                #endif
                lastResponse = "Unable to process question locally: \(error.localizedDescription)"
                return lastResponse
            }
        } else {
            return "Local AI requires iOS 26 or later. Please use Perplexity mode instead."
        }
        #else
        return "Foundation Models not available on this device. Please use Perplexity mode."
        #endif
    }
    
    // MARK: - External Query (Perplexity)
    private func queryWithPerplexity(_ question: String) async -> String {
        let startTime = Date()
        do {
            let formattedQuestion = formatQuestionWithContext(question)
            let response = try await perplexityService.chat(
                message: formattedQuestion,
                bookContext: activeBook?.toBook()
            )
            lastResponse = response
            lastProvider = "Perplexity"

            let responseTime = Date().timeIntervalSince(startTime) * 1000
            #if DEBUG
            print("⚡ Perplexity response in \(String(format: "%.1f", responseTime))ms")
            #endif
            
            return response
        } catch {
            // Check if it's a rate limit error and provide better messaging
            if let perplexityError = error as? PerplexityError,
               case .rateLimitExceeded(_, _) = perplexityError {
                // This is Epilogue+ conversation limit, not Perplexity API limit
                lastResponse = """
                **Monthly Conversation Limit Reached.**

                You've used all your free ambient conversations this month.

                **Want unlimited conversations?**

                Upgrade to Epilogue+ for unlimited ambient AI conversations with your books.

                [UPGRADE_BUTTON]
                """
            } else {
                // Check for rate limit in error description as fallback
                let errorDesc = error.localizedDescription
                if errorDesc.contains("rateLimitExceeded") || errorDesc.contains("rate limit") || errorDesc.contains("Too many requests") {
                    lastResponse = """
                    **Monthly Conversation Limit Reached.**

                    You've used all your free ambient conversations this month.

                    **Want unlimited conversations?**

                    Upgrade to Epilogue+ for unlimited ambient AI conversations.

                    [UPGRADE_BUTTON]
                    """
                } else {
                    // Generic error - keep it friendly
                    lastResponse = "Sorry, I couldn't process your message right now. Please try again."
                }
            }
            return lastResponse
        }
    }
    
    // MARK: - Claude Query
    private func queryWithClaude(_ question: String) async -> String {
        let startTime = Date()
        do {
            let formattedQuestion = formatQuestionWithContext(question)
            let response = try await ClaudeService.shared.subscriberChat(
                message: formattedQuestion,
                systemPrompt: buildClaudeSystemPrompt(),
                maxTokens: 2048
            )
            lastResponse = response
            lastProvider = "Claude"
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            #if DEBUG
            print("⚡ Claude response in \(String(format: "%.1f", responseTime))ms")
            #endif
            return response
        } catch {
            #if DEBUG
            print("❌ Claude error: \(error), falling back to Perplexity")
            #endif
            return await queryWithPerplexity(question)
        }
    }

    // MARK: - Claude System Prompt
    private func buildClaudeSystemPrompt() -> String {
        var prompt = """
        You are Epilogue's AI reading companion — a thoughtful, knowledgeable literary partner.
        You excel at deep analysis, thematic interpretation, and drawing connections.
        """

        if let book = activeBook {
            let groundedContext = GroundedBookSession.shared.buildGroundedInstructions(for: book)

            // Add series spoiler protection
            let seriesInfo = detectSeriesInformation(title: book.title, author: book.author)
            var spoilerInstructions = ""

            if let (seriesName, bookNumber) = seriesInfo {
                spoilerInstructions = """

                SPOILER PROTECTION: This is Book \(bookNumber) of the "\(seriesName)" series.
                Only discuss events from Books 1-\(bookNumber). Never reveal anything from later books.
                """
            }

            prompt += """

            \(groundedContext)
            \(spoilerInstructions)

            Context: The user is actively reading '\(book.title)' by \(book.author).
            They are using Epilogue's ambient mode to ask questions while reading.

            Your strengths for this conversation:
            - Deep literary analysis: themes, symbolism, narrative techniques, character psychology
            - Drawing connections between this book and broader literary traditions
            - Thoughtful interpretation that enhances the reading experience
            - Nuanced discussion of complex ideas and moral questions raised by the text

            Response Guidelines:
            - Start with a direct answer, then build depth
            - Provide specific textual evidence when discussing themes or interpretations
            - Connect ideas to broader literary or philosophical contexts when relevant
            - Aim for 2-3 substantive paragraphs for analysis questions
            - For simple factual questions, be concise and direct
            - NO emojis, NO sycophantic language, NO "As an AI..." phrasing
            - Be natural and conversational, like a well-read friend
            """
        }

        return prompt
    }

    // MARK: - Format Question with Book Context
    private func formatQuestionWithContext(_ question: String) -> String {
        guard let book = activeBook else {
            return question
        }
        
        // For ANY question when we have a book context, make it explicit
        let questionLower = question.lowercased()
        
        // Questions that are clearly NOT about the book
        let generalQuestions = [
            "what time is it",
            "what's the weather",
            "what day is it",
            "how are you",
            "hello",
            "hi"
        ]
        
        // Check if it's a general question
        for general in generalQuestions {
            if questionLower == general || questionLower == general + "?" {
                return question // Don't add book context
            }
        }
        
        // Use enhanced context for smarter responses
        let enhancedContext = AmbientContextManager.shared.buildEnhancedContext(
            for: question,
            book: book.toBook()
        )
        
        // Check for potential transcription errors
        var finalQuestion = question
        if let correction = AmbientContextManager.shared.suggestCorrection(
            for: question, 
            confidence: 0.6
        ) {
            #if DEBUG
            print("📝 Correcting transcription: '\(question)' → '\(correction)'")
            #endif
            finalQuestion = correction
        }
        
        // Build intelligent prompt with rich context
        return """
        \(enhancedContext)
        
        Book: '\(book.title)' by \(book.author)
        Question: \(finalQuestion)
        
        Respond as a knowledgeable friend who:
        - Provides specific, relevant answers about THIS book
        - Avoids spoilers based on reading progress
        - Anticipates natural follow-up questions
        - Uses a warm, conversational tone
        """
    }
    
    // MARK: - Stream Response
    func streamResponse(to question: String) async {
        isProcessing = true
        lastResponse = ""

        // Determine which provider to stream from
        let provider: AIMode
        if currentMode == .externalOnly {
            provider = .externalOnly
        } else if currentMode == .claudeOnly {
            provider = .claudeOnly
        } else if currentMode == .localOnly {
            provider = .localOnly
        } else {
            // Automatic routing
            let needsExternal = await shouldUseExternal(question)
            if needsExternal {
                provider = .externalOnly
            } else if shouldUseClaude(question) {
                provider = .claudeOnly
            } else {
                provider = .localOnly
            }
        }

        do {
            switch provider {
            case .externalOnly:
                // Stream from Perplexity
                let responseStream = AsyncThrowingStream<String, Error> { continuation in
                    Task {
                        do {
                            for try await response in self.perplexityService.streamSonarResponse(self.formatQuestionWithContext(question), bookContext: self.activeBook?.toBook()) {
                                continuation.yield(response.text)
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                }

                for try await chunk in responseStream {
                    await MainActor.run {
                        self.lastResponse += chunk
                    }
                }
                lastProvider = "Perplexity"

            case .claudeOnly:
                // Stream from Claude
                let formattedQuestion = formatQuestionWithContext(question)
                let stream = ClaudeService.shared.subscriberStreamChat(
                    message: formattedQuestion,
                    systemPrompt: buildClaudeSystemPrompt(),
                    maxTokens: 2048
                )

                for try await response in stream {
                    await MainActor.run {
                        self.lastResponse = response.text
                    }
                }
                lastProvider = "Claude"

            case .localOnly, .automatic:
                // Stream from local Foundation Models
                #if canImport(FoundationModels)
                if #available(iOS 26.0, *), let session = session {
                    let stream = session.streamResponse(to: formatQuestionWithContext(question))

                    for try await partial in stream {
                        await MainActor.run {
                            self.lastResponse = partial.content
                        }
                    }
                    lastProvider = "Apple Intelligence"
                } else {
                    // Fallback to Claude streaming if local unavailable
                    let formattedQuestion = formatQuestionWithContext(question)
                    let stream = ClaudeService.shared.subscriberStreamChat(
                        message: formattedQuestion,
                        systemPrompt: buildClaudeSystemPrompt(),
                        maxTokens: 2048
                    )

                    for try await response in stream {
                        await MainActor.run {
                            self.lastResponse = response.text
                        }
                    }
                    lastProvider = "Claude"
                }
                #else
                // No Foundation Models - fall back to Claude streaming
                let formattedQuestion = formatQuestionWithContext(question)
                let stream = ClaudeService.shared.subscriberStreamChat(
                    message: formattedQuestion,
                    systemPrompt: buildClaudeSystemPrompt(),
                    maxTokens: 2048
                )

                for try await response in stream {
                    await MainActor.run {
                        self.lastResponse = response.text
                    }
                }
                lastProvider = "Claude"
                #endif
            }
        } catch {
            await MainActor.run {
                self.lastResponse = "Error: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            self.isProcessing = false
        }
    }

    // MARK: - Series Detection Helper

    /// Detects if a book is part of a series and returns (seriesName, bookNumber)
    private func detectSeriesInformation(title: String, author: String) -> (String, Int)? {
        // Pattern 1: "Series Name: Book N" or "Series Name, Book N"
        if let match = title.range(of: #"(.+?)[\s:,]+Book\s+(\d+)"#, options: .regularExpression) {
            let seriesName = String(title[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
            if let bookNumberStr = title[match].components(separatedBy: CharacterSet.decimalDigits.inverted).last,
               let bookNumber = Int(bookNumberStr) {
                return (seriesName, bookNumber)
            }
        }

        // Pattern 2: "Title (#N in Series)" or "(Book N)"
        if let match = title.range(of: #"\((?:#|Book\s+)?(\d+)(?:\s+in\s+.+?)?\)"#, options: .regularExpression) {
            let bookNumberStr = title[match].components(separatedBy: CharacterSet.decimalDigits.inverted).first { !$0.isEmpty } ?? ""
            if let bookNumber = Int(bookNumberStr) {
                let seriesName = String(title[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
                return (seriesName.isEmpty ? "series" : seriesName, bookNumber)
            }
        }

        // Known series patterns by author and title
        let knownSeries: [(pattern: String, series: String, bookMap: [String: Int])] = [
            ("harry potter", "Harry Potter", [
                "philosopher's stone": 1, "sorcerer's stone": 1,
                "chamber of secrets": 2,
                "prisoner of azkaban": 3,
                "goblet of fire": 4,
                "order of the phoenix": 5,
                "half-blood prince": 6,
                "deathly hallows": 7
            ]),
            ("lord of the rings", "Lord of the Rings", [
                "fellowship": 1,
                "two towers": 2,
                "return of the king": 3
            ]),
            ("hunger games", "Hunger Games", [
                "hunger games": 1,
                "catching fire": 2,
                "mockingjay": 3
            ]),
            ("dune", "Dune", [
                "dune": 1,
                "dune messiah": 2,
                "children of dune": 3,
                "god emperor": 4
            ])
        ]

        let lowerTitle = title.lowercased()
        for (pattern, seriesName, bookMap) in knownSeries {
            if lowerTitle.contains(pattern) || author.lowercased().contains(pattern) {
                for (bookKey, bookNum) in bookMap {
                    if lowerTitle.contains(bookKey) {
                        return (seriesName, bookNum)
                    }
                }
            }
        }

        return nil
    }
}

// MARK: - Perplexity Tool for Foundation Models
// TODO: Implement when Foundation Models API supports custom tools
/*
class PerplexitySearchTool: LanguageModelTool {
    let name = "search_web"
    let description = "Search the web for current information, facts, or details not in the model's training data"
    
    private let service: OptimizedPerplexityService
    
    init(service: OptimizedPerplexityService) {
        self.service = service
    }
    
    struct Arguments: Decodable {
        let query: String
        let needsRecent: Bool?
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        do {
            let response = try await service.chat(with: arguments.query)
            return .string(response)
        } catch {
            return .string("Unable to search web: \(error.localizedDescription)")
        }
    }
}
*/

// MARK: - Book-Specific Response Structure
@Generable
struct BookResponse {
    @Guide(description: "The main answer to the question")
    var answer: String
    
    @Guide(description: "Specific book context if relevant")
    var bookContext: String?
    
    @Guide(description: "Whether external search was used")
    var usedExternalSearch: Bool
}

// MARK: - Extension to Convert BookModel to Book
extension BookModel {
    func toBook() -> Book {
        return Book(
            id: self.id,
            title: self.title,
            author: self.author,
            publishedYear: self.publishedYear,
            coverImageURL: self.coverImageURL,
            isbn: self.isbn,
            description: self.desc,
            pageCount: self.pageCount,
            localId: UUID(uuidString: self.localId) ?? UUID()
        )
    }
}

// MARK: - Extension to Convert Book to BookModel
extension Book {
    func toBookModel() -> BookModel {
        let model = BookModel(
            id: self.id,
            title: self.title,
            author: self.author,
            publishedYear: self.publishedYear,
            coverImageURL: self.coverImageURL,
            isbn: self.isbn,
            description: self.description,
            pageCount: self.pageCount,
            localId: self.localId.uuidString
        )
        return model
    }
}