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
    
    enum AIMode {
        case automatic      // Smart routing
        case localOnly      // Foundation Models only
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
            // Build rich context for the book
            var bookInfo = """
            You are Epilogue's AI reading companion currently discussing '\(book.title)' by \(book.author).
            
            IMPORTANT: You are discussing THIS SPECIFIC BOOK. When asked any question about:
            - "the main character" or "protagonist" - answer about \(book.title)'s main character
            - "the plot" or "story" - answer about \(book.title)'s plot
            - "the ending" - answer about \(book.title)'s ending
            - "the theme" - answer about \(book.title)'s themes
            - Any character names - assume they're from \(book.title)
            
            Book Details:
            - Title: \(book.title)
            - Author: \(book.author)
            """
            
            // Add book-specific knowledge for popular books  
            #if DEBUG
            print("📚 Setting up AI context for book: \(book.title) by \(book.author)")
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
            
            instructions = bookInfo + """
            
            CRITICAL INSTRUCTIONS FOR ANY BOOK:
            
            Context: The user is actively reading '\(book.title)' by \(book.author).
            They are using Epilogue's ambient mode to ask questions while reading.
            
            Core Rules:
            1. DEFAULT ASSUMPTION: Every question is about '\(book.title)' unless explicitly about something else
            2. NEVER REFUSE: Do not say "I can't assist" or "I cannot help" - always provide useful information
            3. NO SPOILER CONCERNS: The user is currently reading this book - answer everything
            4. STAY IN CONTEXT: Focus on THIS specific book, not other books in a series unless asked
            
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
        }
        
        // AUTOMATIC MODE - Intelligent routing
        let needsExternal = await shouldUseExternal(question)
        
        if needsExternal {
            // External knowledge needed - go straight to Perplexity
            return await queryWithPerplexity(question)
        } else {
            // CRITICAL FIX: Check if model is ACTUALLY ready before trying local
            // The session existing doesn't mean it's ready to use!
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), session != nil {
                // Double-check the model is actually ready
                // If we see "Model is downloading or not ready" in logs, skip local
                if isLocalModelActuallyReady() {
                    return await queryLocal(question)
                } else {
                    #if DEBUG
                    print("⚡ Local model not ready - using Perplexity for fast response")
                    #endif
                }
            }
            #endif
            
            // Fallback to Perplexity if local not available or not ready
            return await queryWithPerplexity(question)
        }
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
            
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            #if DEBUG
            print("⚡ Perplexity response in \(String(format: "%.1f", responseTime))ms")
            #endif
            
            return response
        } catch {
            lastResponse = "Unable to fetch external information: \(error.localizedDescription)"
            return lastResponse
        }
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
        
        do {
            let shouldUseExternalCheck = await shouldUseExternal(question)
            let useExternal = currentMode == .externalOnly || shouldUseExternalCheck
            if useExternal {
                // Stream from Perplexity
                // Convert PerplexityResponse stream to String stream
                let responseStream = AsyncThrowingStream<String, Error> { continuation in
                    Task {
                        do {
                            for try await response in perplexityService.streamSonarResponse(formatQuestionWithContext(question), bookContext: activeBook?.toBook()) {
                                continuation.yield(response.text)
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                }
                let stream = responseStream
                
                for try await chunk in stream {
                    await MainActor.run {
                        self.lastResponse += chunk
                    }
                }
            } else {
                // Stream from local Foundation Models
                guard let session = session else { return }
                
                let stream = session.streamResponse(to: formatQuestionWithContext(question))
                
                for try await partial in stream {
                    await MainActor.run {
                        self.lastResponse = partial.content
                    }
                }
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