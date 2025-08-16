import SwiftUI
import Foundation
import Combine
import SwiftData
import FoundationModels

// MARK: - Epilogue AI Service using Foundation Models
@MainActor
class EpilogueAI: ObservableObject {
    static let shared = EpilogueAI()
    
    // Model reference
    private let model = SystemLanguageModel.default
    
    // Session for conversations
    private var session: LanguageModelSession?
    
    // Published properties for UI
    @Published var isAvailable = false
    @Published var isProcessing = false
    @Published var streamedResponse = ""
    @Published var lastError: String?
    
    private init() {
        checkAvailability()
        setupSession()
    }
    
    // MARK: - Availability Check
    func checkAvailability() {
        switch model.availability {
        case .available:
            isAvailable = true
            lastError = nil
        case .unavailable(let reason):
            isAvailable = false
            handleUnavailability(reason)
        }
    }
    
    private func handleUnavailability(_ reason: Any) {
        // Handle unavailability based on the reason
        lastError = "Apple Intelligence is currently unavailable"
    }
    
    // MARK: - Session Setup
    private func setupSession() {
        let instructions = """
        You are Epilogue's AI reading companion. You help users:
        - Understand and analyze quotes from their books
        - Enhance their reading notes with insights
        - Discover connections between different books and ideas
        - Summarize their reading sessions
        
        Be concise, thoughtful, and focus on literary insights.
        When analyzing quotes, consider their thematic significance and emotional resonance.
        Help readers deepen their understanding and appreciation of their reading journey.
        """
        
        session = LanguageModelSession(instructions: instructions)
    }
    
    // MARK: - Quote Analysis
    func analyzeQuote(_ quote: String, from book: BookModel? = nil) async -> String {
        guard isAvailable, let session = session else {
            return "Apple Intelligence is not available"
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        var prompt = "Analyze this quote and provide insights about its meaning and significance:\n\n\"\(quote)\""
        
        if let book = book {
            prompt += "\n\nThis quote is from '\(book.title)' by \(book.author)."
        }
        
        prompt += "\n\nProvide:\n1. The main theme or message\n2. Why this quote is significant\n3. A thought-provoking question for reflection"
        
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            lastError = "Failed to analyze quote: \(error.localizedDescription)"
            return "Unable to analyze quote at this time"
        }
    }
    
    // MARK: - Note Enhancement
    func enhanceNote(_ note: String) async -> String {
        guard isAvailable, let session = session else {
            return note
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = """
        Enhance this reading note by improving its clarity and adding deeper insights:
        
        Original note: \(note)
        
        Provide an enhanced version that:
        - Clarifies the main idea
        - Adds relevant context or connections
        - Maintains the original meaning
        - Is concise and well-structured
        """
        
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            lastError = "Failed to enhance note: \(error.localizedDescription)"
            return note
        }
    }
    
    // MARK: - Streaming Chat
    func streamChat(_ prompt: String) async {
        guard isAvailable, let session = session else {
            streamedResponse = "Apple Intelligence is not available"
            return
        }
        
        isProcessing = true
        streamedResponse = ""
        
        do {
            let stream = session.streamResponse(to: prompt)
            
            for try await partial in stream {
                await MainActor.run {
                    self.streamedResponse = partial.content
                }
            }
        } catch {
            await MainActor.run {
                self.lastError = "Streaming failed: \(error.localizedDescription)"
                self.streamedResponse = "Failed to generate response"
            }
        }
        
        await MainActor.run {
            self.isProcessing = false
        }
    }
    
    // MARK: - Book Recommendations
    func getBookRecommendations(basedOn books: [BookModel]) async -> String {
        guard isAvailable, let session = session else {
            return "Recommendations unavailable"
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let bookList = books.prefix(5).map { b in "'\(b.title)' by \(b.author)" }.joined(separator: ", ")
        
        let prompt = """
        Based on these books in my library: \(bookList)
        
        Recommend 3 books I might enjoy. For each recommendation:
        - Book title and author
        - Why I would enjoy it based on my reading history
        - Which book from my library it's most similar to
        
        Keep each recommendation brief (2-3 sentences).
        """
        
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            lastError = "Failed to get recommendations: \(error.localizedDescription)"
            return "Unable to generate recommendations"
        }
    }
    
    // MARK: - Reading Session Summary
    func summarizeReadingSession(
        notes: [CapturedNote],
        quotes: [CapturedQuote],
        duration: TimeInterval,
        book: BookModel?
    ) async -> String {
        guard isAvailable, let session = session else {
            return "Summary unavailable"
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let durationMinutes = Int(duration / 60)
        let notesText = notes.isEmpty ? "No notes" : notes.map { "- \($0.content)" }.joined(separator: "\n")
        let quotesText = quotes.isEmpty ? "No quotes" : quotes.map { "- \"\($0.text)\"" }.joined(separator: "\n")
        
        var prompt = "Summarize this reading session:\n\n"
        
        if let book = book {
            prompt += "Book: '\(book.title)' by \(book.author)\n"
        }
        
        prompt += """
        Duration: \(durationMinutes) minutes
        
        Notes captured:
        \(notesText)
        
        Quotes saved:
        \(quotesText)
        
        Provide a brief, insightful summary that:
        1. Identifies the main themes explored
        2. Highlights key insights or revelations
        3. Suggests a focus area for the next reading session
        """
        
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            lastError = "Failed to summarize: \(error.localizedDescription)"
            return "Unable to generate summary"
        }
    }
}

// MARK: - AI Status View
struct EpilogueAIStatusView: View {
    @StateObject private var ai = EpilogueAI.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ai.isAvailable ? "brain" : "brain.slash")
                .foregroundStyle(ai.isAvailable ? .green : .red)
            
            if ai.isAvailable {
                Text("AI Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let error = ai.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            if ai.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}

// MARK: - AI Chat View
struct EpilogueAIChatView: View {
    @StateObject private var ai = EpilogueAI.shared
    @State private var userPrompt = ""
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !ai.streamedResponse.isEmpty {
                        MessageBubble(
                            text: ai.streamedResponse,
                            isUser: false,
                            isStreaming: ai.isProcessing
                        )
                    }
                }
                .padding()
            }
            
            // Input area
            HStack(spacing: 12) {
                TextField("Ask about your reading...", text: $userPrompt)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!ai.isAvailable || isGenerating)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(userPrompt.isEmpty || !ai.isAvailable || isGenerating)
            }
            .padding()
            .background(.regularMaterial)
        }
    }
    
    private func sendMessage() {
        guard !userPrompt.isEmpty else { return }
        
        let prompt = userPrompt
        userPrompt = ""
        isGenerating = true
        
        Task {
            await ai.streamChat(prompt)
            isGenerating = false
        }
    }
}

struct MessageBubble: View {
    let text: String
    let isUser: Bool
    let isStreaming: Bool
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .padding(12)
                    .background(isUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(isUser ? .white : .primary)
                    .cornerRadius(16)
                
                if isStreaming {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 4, height: 4)
                                .opacity(isStreaming ? 1 : 0)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isStreaming
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            if !isUser { Spacer() }
        }
    }
}