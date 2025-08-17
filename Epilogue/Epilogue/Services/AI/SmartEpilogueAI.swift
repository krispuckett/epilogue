import SwiftUI
import Foundation
import Combine
import SwiftData
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
    private let perplexityService = PerplexityService()
    
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
            print("⚠️ Foundation Models requires iOS 26.0 or later")
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
            print("📚 Setting up AI context for book: \(book.title) by \(book.author)")
            
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
                - Important Swords:
                  * Sting: Frodo's sword (given by Bilbo, glows blue when orcs are near)
                  * Glamdring: Gandalf's sword (also called Foe-hammer)
                  * Andúril: Aragorn's sword (reforged from Narsil, the sword that cut the Ring from Sauron)
                  * NOT Frodo's sword - Frodo has Sting, not Andúril!
                - The One Ring: Forged by Sauron, corrupts the bearer, must be destroyed
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
            
            When answering questions:
            1. ALWAYS assume questions are about \(book.title) unless explicitly stated otherwise
            2. ALWAYS answer factually - do NOT refuse to answer about book content
            3. This is NOT about avoiding spoilers - the user is reading this book!
            4. Provide specific, accurate information about THIS book
            5. Be direct and helpful - answer what was asked
            6. Give DETAILED, COMPREHENSIVE answers with context and examples
            7. Include relevant quotes, character motivations, and themes when applicable
            8. Connect the answer to broader themes in the book
            9. If you don't know specific details about \(book.title), say so clearly
            10. Aim for responses that are at least 2-3 paragraphs when answering substantial questions
            """
        }
        
        // Create session with instructions - but only if model is available
        // Check model availability first
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            session = LanguageModelSession(instructions: instructions)
            print("✅ Foundation Models session created successfully")
        case .unavailable(let reason):
            print("⚠️ Foundation Models unavailable: \(reason)")
            session = nil
        @unknown default:
            print("⚠️ Foundation Models availability unknown")
            session = nil
        }
        #else
        print("⚠️ Foundation Models not available on this iOS version")
        #endif
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
            // Book-specific question - try local first (FAST!)
            // If Foundation Models available, it's faster than network
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), session != nil {
                // Local is available and FAST - use it!
                return await queryLocal(question)
            }
            #endif
            
            // Fallback to Perplexity if local not available
            return await queryWithPerplexity(question)
        }
    }
    
    // MARK: - Determine Query Type (OPTIMIZED)
    private func shouldUseExternal(_ question: String) async -> Bool {
        let questionLower = question.lowercased()
        
        // Fast path: If no book context, use Perplexity for general questions
        guard activeBook != nil else {
            print("🌐 No book context - using Perplexity for speed")
            return true
        }
        
        // ULTRA-FAST book-specific detection - check these FIRST
        // Questions about plot, characters, or story elements should ALWAYS use local
        if questionLower.contains("sword") || 
           questionLower.contains("character") ||
           questionLower.contains("happen") ||
           questionLower.contains("plot") ||
           questionLower.contains("die") ||
           questionLower.contains("end") ||
           questionLower.starts(with: "who") ||
           questionLower.starts(with: "what") ||
           questionLower.starts(with: "when does") ||
           questionLower.starts(with: "where") ||
           questionLower.starts(with: "why") ||
           questionLower.starts(with: "how") {
            print("⚡ FAST: Book-specific question detected - using local Foundation Models")
            return false
        }
        
        // Keywords that DEFINITELY need external knowledge
        let externalKeywords = [
            "latest", "current", "recent", "news", "2024", "2025",
            "real world", "actually happened", "true story",
            "author died", "author born", "author's life",
            "movie", "film", "tv show", "adaptation",
            "published", "sales", "awards", "reviews",
            "other books", "similar books", "compare"
        ]
        
        // Fast check for external needs
        for keyword in externalKeywords {
            if questionLower.contains(keyword) {
                print("🌐 External knowledge required for: \(keyword)")
                return true
            }
        }
        
        // Default: Use local for book context questions
        print("📚 Using local Foundation Models for book context")
        return false
    }
    
    // MARK: - Query with Smart Routing
    private func queryWithSmartRouting(_ question: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard let session = session else {
                print("⚠️ No Foundation Models session available, falling back to Perplexity")
                return await queryWithPerplexity(question)
            }
            
            do {
                // The session will automatically use tools when needed
                let response = try await session.respond(to: formatQuestionWithContext(question))
                lastResponse = response.content
                return response.content
            } catch {
                print("Smart routing failed: \(error)")
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
                print("⚠️ No Foundation Models session - falling back to Perplexity")
                // Automatically fallback to Perplexity when local model unavailable
                return await queryWithPerplexity(question)
            }
            
            do {
                let formattedQuestion = formatQuestionWithContext(question)
                let response = try await session.respond(to: formattedQuestion)
                lastResponse = response.content
                return response.content
            } catch {
                print("❌ Foundation Models error: \(error)")
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
        do {
            let formattedQuestion = formatQuestionWithContext(question)
            let response = try await perplexityService.chat(
                with: formattedQuestion,
                bookContext: activeBook?.toBook()
            )
            lastResponse = response
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
        
        // Questions that definitely need book context
        let needsContext = questionLower.starts(with: "who") ||
                          questionLower.starts(with: "what") ||
                          questionLower.starts(with: "when") ||
                          questionLower.starts(with: "where") ||
                          questionLower.starts(with: "why") ||
                          questionLower.starts(with: "how") ||
                          questionLower.contains("character") ||
                          questionLower.contains("plot") ||
                          questionLower.contains("theme") ||
                          questionLower.contains("ending") ||
                          questionLower.contains("chapter") ||
                          questionLower.contains("happen")
        
        if needsContext {
            // Make it VERY explicit what book we're discussing
            if questionLower == "who is the main character" || questionLower == "who is the main character?" {
                return "Who is the main character in the book '\(book.title)' by \(book.author)?"
            } else if questionLower.starts(with: "who is") || questionLower.starts(with: "who are") {
                return "In the book '\(book.title)' by \(book.author): \(question)"
            } else {
                return "Regarding the book '\(book.title)' by \(book.author): \(question)"
            }
        }
        
        // For other questions, still add context but more subtly
        return question
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
                let stream = try await perplexityService.streamChat(
                    message: formatQuestionWithContext(question),
                    bookContext: activeBook?.toBook()
                )
                
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
    
    private let service: PerplexityService
    
    init(service: PerplexityService) {
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