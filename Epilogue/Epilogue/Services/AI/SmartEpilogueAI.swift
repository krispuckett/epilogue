import SwiftUI
import Foundation
import Combine
import SwiftData
import FoundationModels

// MARK: - Smart Context-Aware AI Service
@MainActor
class SmartEpilogueAI: ObservableObject {
    static let shared = SmartEpilogueAI()
    
    // Foundation Models
    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?
    
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
            if book.title.lowercased().contains("project hail mary") {
                bookInfo += """
                
                Key Information about Project Hail Mary:
                - Main characters: Ryland Grace (human protagonist) and Rocky (alien friend)
                - Plot: Ryland Grace wakes up alone on a spaceship with amnesia, tasked with saving Earth from extinction
                - Rocky is an Eridian, a spider-like alien who becomes Grace's friend and collaborator
                - The threat is the Astrophage, organisms eating the sun's energy
                - Themes: Science, friendship across species, sacrifice, problem-solving
                """
            } else if book.title.lowercased().contains("lord of the rings") {
                bookInfo += """
                
                Key Information about Lord of the Rings:
                - Main characters: Frodo Baggins, Sam, Aragorn, Gandalf, and the Fellowship
                - Plot: Frodo must destroy the One Ring in Mount Doom to save Middle-earth
                - Themes: Good vs evil, friendship, sacrifice, corruption of power
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
            2. Provide specific, accurate information about THIS book
            3. If you don't know specific details about \(book.title), say so clearly
            4. Be concise but informative
            """
        }
        
        // Create session with instructions
        // TODO: Add tool support when Foundation Models API supports it
        session = LanguageModelSession(instructions: instructions)
    }
    
    // MARK: - Update Active Book Context
    func setActiveBook(_ book: BookModel?) {
        self.activeBook = book
        setupSession() // Recreate session with new context
    }
    
    // MARK: - Smart Query Routing
    func smartQuery(_ question: String) async -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        // Determine if question needs external knowledge
        let needsExternal = await shouldUseExternal(question)
        
        if needsExternal || currentMode == .externalOnly {
            return await queryWithPerplexity(question)
        } else if currentMode == .localOnly {
            return await queryLocal(question)
        } else {
            // Automatic mode - try local first, use tool if needed
            return await queryWithSmartRouting(question)
        }
    }
    
    // MARK: - Determine Query Type
    private func shouldUseExternal(_ question: String) async -> Bool {
        let questionLower = question.lowercased()
        
        // Keywords that suggest external knowledge needed
        let externalKeywords = [
            "latest", "current", "recent", "news", "update",
            "real world", "actually", "factual", "true story",
            "author's life", "biography", "historical context",
            "other books", "similar to", "compare with",
            "movie adaptation", "film version", "tv series",
            "when was it published", "sales", "awards", "reviews"
        ]
        
        // Keywords that strongly suggest book-specific knowledge
        let bookKeywords = [
            "who is", "who are", "who's",  // Who is the main character?
            "main character", "protagonist", "antagonist", "villain",
            "plot", "story", "happen", "happens",
            "theme", "meaning", "symbolism",
            "chapter", "ending", "beginning", "scene", "part",
            "quote", "said", "says", "tell", "tells",
            "relationship", "conflict", "dies", "death",
            "character", "rocky", "grace", "frodo", "gandalf"  // Common character names
        ]
        
        // Check for external indicators
        let needsExternal = externalKeywords.contains { questionLower.contains($0) }
        
        // Check for book-specific indicators - be more aggressive about detecting these
        let isBookSpecific = bookKeywords.contains { keyword in 
            questionLower.contains(keyword)
        } || questionLower.starts(with: "who") || questionLower.starts(with: "what happens") || questionLower.starts(with: "how does")
        
        // If we have an active book and the question seems book-specific, ALWAYS use local
        if activeBook != nil && isBookSpecific {
            print("📚 Question '\(question)' detected as book-specific for '\(activeBook?.title ?? "unknown")'")
            return false  // Use local Foundation Models
        }
        
        // If explicitly asking for external info, use external
        if needsExternal {
            print("🌐 Question '\(question)' requires external knowledge")
            return true
        }
        
        // Default to local if we have a book context
        if activeBook != nil {
            return false
        }
        
        return needsExternal
    }
    
    // MARK: - Query with Smart Routing
    private func queryWithSmartRouting(_ question: String) async -> String {
        guard let session = session else {
            return "AI session not available"
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
    }
    
    // MARK: - Local Query (Foundation Models)
    private func queryLocal(_ question: String) async -> String {
        guard let session = session else {
            return "Local AI not available"
        }
        
        do {
            let formattedQuestion = formatQuestionWithContext(question)
            let response = try await session.respond(to: formattedQuestion)
            lastResponse = response.content
            return response.content
        } catch {
            lastResponse = "Unable to process question locally"
            return lastResponse
        }
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