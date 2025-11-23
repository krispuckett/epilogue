import Foundation
import SwiftUI
import Combine

// MARK: - Quote Intelligence
/// AI-powered question generation for captured quotes
/// Uses Foundation Models Framework (iOS 26) when available
/// Falls back to smart heuristics

@MainActor
class QuoteIntelligence: ObservableObject {

    @Published var isGenerating = false
    @Published var lastQuestion: String?

    // MARK: - Question Generation

    func generateSmartQuestion(
        for quote: String,
        bookContext: Book?,
        useAI: Bool = true
    ) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        #if DEBUG
        print("🤔 [INTELLIGENCE] Generating question for: \(quote.prefix(50))...")
        #endif

        // Try AI generation first (if available and enabled)
        if useAI, let aiQuestion = await tryAIGeneration(quote: quote, bookContext: bookContext) {
            lastQuestion = aiQuestion
            return aiQuestion
        }

        // Fallback to smart heuristics
        let heuristicQuestion = generateHeuristicQuestion(quote, bookContext: bookContext)
        lastQuestion = heuristicQuestion
        return heuristicQuestion
    }

    // MARK: - AI Generation (Foundation Models)

    private func tryAIGeneration(quote: String, bookContext: Book?) async -> String? {
        // NOTE: Foundation Models Framework integration
        // This is where we'd use LanguageModelSession from Foundation Models
        // For now, returning nil to use fallback heuristics
        // TODO: Implement when Foundation Models API is fully available

        #if DEBUG
        print("🤖 [INTELLIGENCE] Foundation Models not yet integrated, using heuristics")
        #endif

        return nil
    }

    // MARK: - Smart Heuristics

    private func generateHeuristicQuestion(_ quote: String, bookContext: Book?) -> String {
        let wordCount = quote.split(separator: " ").count
        let sentences = quote.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Analyze quote characteristics
        let hasQuestion = quote.contains("?")
        let hasExclamation = quote.contains("!")
        let hasQuotation = quote.contains("\"") || quote.contains("\u{201C}")
        let isDialogue = hasQuotation && wordCount < 30

        // Generate contextual question
        if hasQuestion {
            return generateQuestionAboutQuestion(quote, bookContext: bookContext)
        } else if isDialogue {
            return generateDialogueQuestion(quote, bookContext: bookContext)
        } else if wordCount > 50 {
            return generatePassageQuestion(quote, bookContext: bookContext)
        } else if wordCount < 10 {
            return generatePhraseQuestion(quote, bookContext: bookContext)
        } else if hasExclamation {
            return generateEmotionalQuestion(quote, bookContext: bookContext)
        } else {
            return generateGenericQuestion(quote, bookContext: bookContext)
        }
    }

    // MARK: - Question Generators

    private func generateQuestionAboutQuestion(_ quote: String, bookContext: Book?) -> String {
        let templates = [
            "What are the implications of this question?",
            "How does this question relate to the book's central themes?",
            "Why might the author be asking this question here?",
            "What answer does the text suggest for this question?"
        ]

        if let book = bookContext {
            return "In \(book.title), \(templates.randomElement() ?? templates[0])"
        }

        return templates.randomElement() ?? templates[0]
    }

    private func generateDialogueQuestion(_ quote: String, bookContext: Book?) -> String {
        let templates = [
            "What does this dialogue reveal about the character?",
            "How does this conversation advance the plot?",
            "What's the subtext behind these words?",
            "What can we infer from this exchange?"
        ]

        return templates.randomElement() ?? templates[0]
    }

    private func generatePassageQuestion(_ quote: String, bookContext: Book?) -> String {
        let templates = [
            "What are the key themes in this passage?",
            "How does this passage connect to the broader narrative?",
            "What literary techniques is the author using here?",
            "What is the significance of this moment in the story?"
        ]

        if let book = bookContext {
            return "\(templates.randomElement() ?? templates[0]) In the context of \(book.title), how does this deepen our understanding?"
        }

        return templates.randomElement() ?? templates[0]
    }

    private func generatePhraseQuestion(_ quote: String, bookContext: Book?) -> String {
        let templates = [
            "What does \"\(quote)\" mean in this context?",
            "Why is \"\(quote)\" significant here?",
            "What's the deeper meaning of \"\(quote)\"?",
            "How does \"\(quote)\" relate to the book's themes?"
        ]

        return templates.randomElement() ?? templates[0]
    }

    private func generateEmotionalQuestion(_ quote: String, bookContext: Book?) -> String {
        let templates = [
            "What emotion is the author trying to evoke with this statement?",
            "Why is this moment so impactful?",
            "What makes this declaration significant?",
            "What intensity does this passage carry?"
        ]

        return templates.randomElement() ?? templates[0]
    }

    private func generateGenericQuestion(_ quote: String, bookContext: Book?) -> String {
        let templates = [
            "What is the significance of this quote?",
            "How does this connect to the larger themes?",
            "What deeper meaning can we extract from this?",
            "Why did this passage stand out?"
        ]

        if let book = bookContext {
            return "\(templates.randomElement() ?? templates[0]) Consider its role in \(book.title)."
        }

        return templates.randomElement() ?? templates[0]
    }

    // MARK: - Context Analysis

    func analyzeQuote(_ quote: String) -> QuoteAnalysis {
        let wordCount = quote.split(separator: " ").count
        let characterCount = quote.count

        let type: QuoteType
        if quote.contains("?") {
            type = .question
        } else if quote.contains("\"") || quote.contains("\u{201C}") {
            type = .dialogue
        } else if wordCount > 50 {
            type = .passage
        } else if wordCount < 10 {
            type = .phrase
        } else {
            type = .statement
        }

        return QuoteAnalysis(
            type: type,
            wordCount: wordCount,
            characterCount: characterCount,
            hasQuotation: quote.contains("\"") || quote.contains("\u{201C}"),
            hasQuestion: quote.contains("?"),
            hasExclamation: quote.contains("!")
        )
    }
}

// MARK: - Models

enum QuoteType {
    case question
    case dialogue
    case passage
    case phrase
    case statement
}

struct QuoteAnalysis {
    let type: QuoteType
    let wordCount: Int
    let characterCount: Int
    let hasQuotation: Bool
    let hasQuestion: Bool
    let hasExclamation: Bool

    var isComplex: Bool {
        wordCount > 30
    }

    var isSimple: Bool {
        wordCount < 15
    }
}
