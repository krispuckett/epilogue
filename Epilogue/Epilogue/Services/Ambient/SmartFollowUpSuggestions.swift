import Foundation

// MARK: - Smart Follow-Up Suggestions
/// Generates intelligent follow-up questions based on conversation context
class SmartFollowUpSuggestions {
    static let shared = SmartFollowUpSuggestions()
    
    private init() {}
    
    struct FollowUpSuggestion {
        let question: String
        let rationale: String  // Why this might be interesting
        let confidence: Float  // How likely the user wants this
    }
    
    /// Generate smart follow-up questions based on the answer just given
    func generateFollowUps(
        originalQuestion: String,
        answer: String,
        book: Book?
    ) -> [FollowUpSuggestion] {
        var suggestions: [FollowUpSuggestion] = []
        
        let questionLower = originalQuestion.lowercased()
        let answerLower = answer.lowercased()
        
        // 1. Character Questions → Natural Follow-ups
        if questionLower.contains("who is") {
            let characterName = extractCharacterName(from: originalQuestion)
            
            suggestions.append(contentsOf: [
                FollowUpSuggestion(
                    question: "What motivates \(characterName)?",
                    rationale: "Understanding character motivation",
                    confidence: 0.9
                ),
                FollowUpSuggestion(
                    question: "How does \(characterName) change throughout the story?",
                    rationale: "Character development arc",
                    confidence: 0.8
                ),
                FollowUpSuggestion(
                    question: "What's \(characterName)'s relationship with other main characters?",
                    rationale: "Character dynamics",
                    confidence: 0.85
                )
            ])
        }
        
        // 2. Plot Questions → What Happens Next
        if questionLower.contains("what happens") || questionLower.contains("what occurred") {
            suggestions.append(contentsOf: [
                FollowUpSuggestion(
                    question: "Why did that happen?",
                    rationale: "Understanding causation",
                    confidence: 0.9
                ),
                FollowUpSuggestion(
                    question: "What are the consequences?",
                    rationale: "Plot implications",
                    confidence: 0.85
                ),
                FollowUpSuggestion(
                    question: "How do the characters react?",
                    rationale: "Character responses",
                    confidence: 0.8
                )
            ])
        }
        
        // 3. Theme Questions → Deeper Exploration
        if questionLower.contains("theme") || questionLower.contains("meaning") {
            suggestions.append(contentsOf: [
                FollowUpSuggestion(
                    question: "Can you give specific examples from the book?",
                    rationale: "Concrete evidence",
                    confidence: 0.9
                ),
                FollowUpSuggestion(
                    question: "How does this relate to real life?",
                    rationale: "Personal connection",
                    confidence: 0.75
                ),
                FollowUpSuggestion(
                    question: "What symbols represent this theme?",
                    rationale: "Symbolic analysis",
                    confidence: 0.7
                )
            ])
        }
        
        // 4. History/Background Questions → Expansion
        if questionLower.contains("history") || questionLower.contains("background") {
            suggestions.append(contentsOf: [
                FollowUpSuggestion(
                    question: "How does this affect the current story?",
                    rationale: "Present implications",
                    confidence: 0.85
                ),
                FollowUpSuggestion(
                    question: "Tell me more about the key events",
                    rationale: "Detailed exploration",
                    confidence: 0.8
                ),
                FollowUpSuggestion(
                    question: "Who were the important figures?",
                    rationale: "Historical characters",
                    confidence: 0.75
                )
            ])
        }
        
        // 5. Quote Questions → Interpretation
        if questionLower.contains("quote") || answerLower.contains("\"") {
            suggestions.append(contentsOf: [
                FollowUpSuggestion(
                    question: "What does this quote mean in context?",
                    rationale: "Deeper understanding",
                    confidence: 0.9
                ),
                FollowUpSuggestion(
                    question: "Why is this quote significant?",
                    rationale: "Importance to story",
                    confidence: 0.85
                ),
                FollowUpSuggestion(
                    question: "Are there other memorable quotes?",
                    rationale: "More memorable lines",
                    confidence: 0.7
                )
            ])
        }
        
        // 6. Comparison Questions → Related Topics
        if questionLower.contains("similar") || questionLower.contains("different") {
            suggestions.append(contentsOf: [
                FollowUpSuggestion(
                    question: "What are the key differences?",
                    rationale: "Contrast analysis",
                    confidence: 0.85
                ),
                FollowUpSuggestion(
                    question: "Which is more important to the story?",
                    rationale: "Relative significance",
                    confidence: 0.75
                ),
                FollowUpSuggestion(
                    question: "How do they interact?",
                    rationale: "Relationships",
                    confidence: 0.8
                )
            ])
        }
        
        // 7. Smart Context-Based Suggestions
        if let book = book, let pageCount = book.pageCount, pageCount > 0 {
            // Calculate reading progress from current page
            let progress = Double(book.currentPage) / Double(pageCount)
            
            if progress < 0.3 {
                // Early in book - world-building questions
                suggestions.append(
                    FollowUpSuggestion(
                        question: "Tell me more about the setting",
                        rationale: "Understanding the world",
                        confidence: 0.7
                    )
                )
            } else if progress > 0.7 {
                // Late in book - resolution questions
                suggestions.append(
                    FollowUpSuggestion(
                        question: "How are the conflicts being resolved?",
                        rationale: "Story conclusion",
                        confidence: 0.75
                    )
                )
            }
        }
        
        // Sort by confidence and return top 3
        return Array(suggestions.sorted { $0.confidence > $1.confidence }.prefix(3))
    }
    
    private func extractCharacterName(from question: String) -> String {
        // Simple extraction - get the name after "who is"
        let components = question.lowercased().components(separatedBy: "who is ")
        if components.count > 1 {
            let namepart = components[1]
                .replacingOccurrences(of: "?", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Capitalize properly
            return namepart.split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
        return "this character"
    }
    
    /// Generate ambient prompts when user hasn't asked anything in a while
    func generateAmbientPrompts(
        currentPage: Int?,
        book: Book?,
        recentTopics: [String]
    ) -> [String] {
        var prompts: [String] = []
        
        if let book = book {
            // Based on reading progress
            if let pageCount = book.pageCount, pageCount > 0 {
                let progress = Double(book.currentPage) / Double(pageCount)
                
                if progress < 0.1 {
                    prompts.append("Ask me about the main characters")
                    prompts.append("I can explain the setting")
                } else if progress < 0.5 {
                    prompts.append("Curious about any plot points?")
                    prompts.append("Want to discuss themes emerging?")
                } else {
                    prompts.append("Any predictions about the ending?")
                    prompts.append("How are you enjoying it so far?")
                }
            }
            
            // Based on book description/title for genre hints
            let titleAndDesc = (book.title + " " + (book.description ?? "")).lowercased()
            
            if titleAndDesc.contains("fantasy") || titleAndDesc.contains("magic") || titleAndDesc.contains("wizard") {
                prompts.append("Ask about the magic system")
                prompts.append("Curious about the world-building?")
            } else if titleAndDesc.contains("mystery") || titleAndDesc.contains("detective") || titleAndDesc.contains("murder") {
                prompts.append("Any theories about the solution?")
                prompts.append("Want to discuss the clues?")
            } else if titleAndDesc.contains("romance") || titleAndDesc.contains("love") {
                prompts.append("Thoughts on the relationships?")
                prompts.append("How do you feel about the characters?")
            }
        }
        
        // Generic prompts
        prompts.append(contentsOf: [
            "Ask me anything about what you're reading",
            "I can help clarify confusing parts",
            "Want to explore themes or symbolism?"
        ])
        
        // Shuffle and return a subset
        return Array(prompts.shuffled().prefix(3))
    }
}