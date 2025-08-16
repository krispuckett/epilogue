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
            instructions = """
            You are Epilogue's AI reading companion currently discussing '\(book.title)' by \(book.author).
            
            When asked about characters, plot, themes, or specific questions about this book:
            - Provide specific answers about '\(book.title)'
            - Reference actual characters, events, and themes from this book
            - Be concise and accurate
            
            Current book context:
            - Title: \(book.title)
            - Author: \(book.author)
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
            "movie adaptation", "film version", "tv series"
        ]
        
        // Keywords that suggest book-specific knowledge
        let bookKeywords = [
            "main character", "protagonist", "plot", "theme",
            "chapter", "ending", "beginning", "scene",
            "quote", "said", "relationship", "conflict"
        ]
        
        // Check for external indicators
        let needsExternal = externalKeywords.contains { questionLower.contains($0) }
        
        // Check for book-specific indicators
        let isBookSpecific = bookKeywords.contains { questionLower.contains($0) }
        
        // If book-specific and we have active book, use local
        if isBookSpecific && activeBook != nil {
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
        
        // For questions about "the main character" or similar, add book context
        let questionLower = question.lowercased()
        
        if questionLower.contains("main character") ||
           questionLower.contains("protagonist") ||
           questionLower.contains("plot") ||
           questionLower.contains("ending") ||
           questionLower.contains("theme") {
            return "In the book '\(book.title)' by \(book.author): \(question)"
        }
        
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