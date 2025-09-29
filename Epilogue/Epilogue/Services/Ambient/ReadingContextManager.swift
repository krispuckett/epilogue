import Foundation
import SwiftUI
import Combine

// MARK: - Reading Context Manager
// Intelligent context awareness for enhanced ambient mode processing

public class ReadingContextManager: ObservableObject {
    public static let shared = ReadingContextManager()
    
    @Published private(set) var currentContext: ReadingContext?
    
    // Character and theme tracking
    private var detectedCharacters: Set<String> = []
    private var detectedThemes: Set<String> = []
    private var detectedLocations: Set<String> = []
    private var recentTerms: [String: Int] = [:] // Frequency map
    
    public struct ReadingContext {
        let book: Book
        let chapter: String?
        let lastPageNumber: Int
        let recentCharacters: [String]
        let recentThemes: [String]
        let recentLocations: [String]
        let sessionMood: String
        let contextualVocabulary: [String]
        let timestamp: Date
        
        // Context confidence score
        var confidence: Float {
            var score: Float = 0.0
            
            // More characters = higher confidence
            score += Float(recentCharacters.count) * 0.2
            
            // More themes = better understanding
            score += Float(recentThemes.count) * 0.15
            
            // Page progress adds confidence
            if lastPageNumber > 0 {
                score += 0.3
            }
            
            // Recent context is more confident
            let timeSinceUpdate = Date().timeIntervalSince(timestamp)
            if timeSinceUpdate < 300 { // Within 5 minutes
                score += 0.35
            }
            
            return min(score, 1.0)
        }
    }
    
    private init() {}
    
    // MARK: - Context Updates
    
    func updateContext(from captures: [AmbientProcessedContent], book: Book?) async {
        guard let book = book else { return }
        
        // Extract entities from recent captures
        var characters: Set<String> = []
        var themes: Set<String> = []
        var locations: Set<String> = []
        var moods: [String] = []
        
        // Use Foundation Models for context extraction if available
        let isAvailable = await MainActor.run { AIFoundationModelsManager.shared.isAvailable }
        if #available(iOS 18.0, *), isAvailable {
            let contextData = await extractContextWithFoundationModels(captures, book: book)
            characters = Set(contextData.characters)
            themes = Set(contextData.themes)
            locations = Set(contextData.locations)
            moods = [contextData.mood]
        } else {
            // Fallback to rule-based extraction
            for capture in captures {
                let extracted = extractEntitiesFromText(capture.text)
                characters.formUnion(extracted.characters)
                themes.formUnion(extracted.themes)
                locations.formUnion(extracted.locations)
            }
        }
        
        // Merge with existing detected entities
        detectedCharacters.formUnion(characters)
        detectedThemes.formUnion(themes)
        detectedLocations.formUnion(locations)
        
        // Update frequency map
        updateTermFrequency(from: captures)
        
        // Build contextual vocabulary
        let vocabulary = buildContextualVocabulary(book: book)
        
        // Determine session mood
        let sessionMood = determineMood(from: moods, captures: captures)
        
        // Find current chapter (if available)
        let currentChapter = extractChapter(from: captures)
        
        // Get last page number
        let lastPage = captures.compactMap { capture in
            // Look for page references in captured content
            extractPageNumber(from: capture.text)
        }.max() ?? 0
        
        // Update context
        await MainActor.run {
            self.currentContext = ReadingContext(
                book: book,
                chapter: currentChapter,
                lastPageNumber: lastPage,
                recentCharacters: Array(characters.prefix(10)),
                recentThemes: Array(themes.prefix(8)),
                recentLocations: Array(locations.prefix(6)),
                sessionMood: sessionMood,
                contextualVocabulary: vocabulary,
                timestamp: Date()
            )
        }
        
        // Notify TrueAmbientProcessor to update WhisperKit
        await TrueAmbientProcessor.shared.updateWhisperKitContext(for: currentContext)
    }
    
    // MARK: - Foundation Models Context Extraction
    
    struct ContextExtraction {
        let characters: [String]
        let themes: [String]
        let locations: [String]
        let chapter: String?
        let mood: String
    }
    
    @available(iOS 18.0, *)
    private func extractContextWithFoundationModels(_ captures: [AmbientProcessedContent], book: Book) async -> ContextExtraction {
        
        let captureText = captures.map { $0.text }.joined(separator: "\n")
        let prompt = """
        Extract context from this reading session of "\(book.title)" by \(book.author):
        
        \(captureText)
        
        Identify:
        1. Character names mentioned
        2. Themes or concepts discussed
        3. Locations mentioned
        4. Current chapter (if detectable)
        5. Overall mood/tone of the session
        """
        
        // Use Foundation Models via the manager
        let response = await AIFoundationModelsManager.shared.processQuery(
            prompt,
            bookContext: book
        )
        
        // Parse the response
        return parseContextExtraction(from: response)
    }
    
    // MARK: - Rule-based Entity Extraction (Fallback)
    
    private func extractEntitiesFromText(_ text: String) -> (characters: Set<String>, themes: Set<String>, locations: Set<String>) {
        var characters = Set<String>()
        var themes = Set<String>()
        var locations = Set<String>()
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            
            // Simple heuristic: Capitalized words might be names or places
            if cleanWord.first?.isUppercase == true && cleanWord.count > 2 {
                // Check if it's a common word
                if !isCommonWord(cleanWord.lowercased()) {
                    // Likely a character name or location
                    if isLocationIndicator(text, word: cleanWord) {
                        locations.insert(cleanWord)
                    } else {
                        characters.insert(cleanWord)
                    }
                }
            }
            
            // Theme detection (simple keyword matching)
            let lowerWord = cleanWord.lowercased()
            for themeKeyword in themeKeywords {
                if lowerWord.contains(themeKeyword) {
                    themes.insert(themeKeyword.capitalized)
                }
            }
        }
        
        return (characters, themes, locations)
    }
    
    // MARK: - Vocabulary Building
    
    private func buildContextualVocabulary(book: Book) -> [String] {
        var vocabulary: [String] = []
        
        // Add book-specific terms
        vocabulary.append(book.title)
        vocabulary.append(book.author)
        
        // Add detected characters (most frequent first)
        let sortedCharacters = detectedCharacters.sorted { char1, char2 in
            (recentTerms[char1] ?? 0) > (recentTerms[char2] ?? 0)
        }
        vocabulary.append(contentsOf: sortedCharacters.prefix(20))
        
        // Add locations
        vocabulary.append(contentsOf: detectedLocations.prefix(10))
        
        // Add frequently used terms
        let frequentTerms = recentTerms.sorted { $0.value > $1.value }
            .map { $0.key }
            .filter { $0.count > 4 } // Only meaningful words
            .prefix(15)
        vocabulary.append(contentsOf: frequentTerms)
        
        return Array(Set(vocabulary)) // Remove duplicates
    }
    
    // MARK: - Helper Methods
    
    private func updateTermFrequency(from captures: [AmbientProcessedContent]) {
        for capture in captures {
            let words = capture.text.components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                if cleanWord.count > 3 && !isCommonWord(cleanWord.lowercased()) {
                    recentTerms[cleanWord, default: 0] += 1
                }
            }
        }
        
        // Decay old terms
        recentTerms = recentTerms.compactMapValues { count in
            let decayed = count - 1
            return decayed > 0 ? decayed : nil
        }
    }
    
    private func determineMood(from moods: [String], captures: [AmbientProcessedContent]) -> String {
        // If we have AI-detected mood, use it
        if let mood = moods.first {
            return mood
        }
        
        // Fallback: Simple sentiment analysis
        var sentimentScore = 0.0
        
        for capture in captures {
            let text = capture.text.lowercased()
            
            // Positive indicators
            for word in positiveWords {
                if text.contains(word) {
                    sentimentScore += 1.0
                }
            }
            
            // Negative indicators
            for word in negativeWords {
                if text.contains(word) {
                    sentimentScore -= 1.0
                }
            }
            
            // Question indicators suggest curiosity
            if capture.type == .question {
                sentimentScore += 0.5
            }
        }
        
        // Determine mood based on score
        switch sentimentScore {
        case ..<(-2):
            return "troubled"
        case -2..<0:
            return "contemplative"
        case 0..<3:
            return "curious"
        case 3..<6:
            return "engaged"
        default:
            return "excited"
        }
    }
    
    private func extractChapter(from captures: [AmbientProcessedContent]) -> String? {
        for capture in captures {
            let text = capture.text.lowercased()
            
            // Look for chapter indicators
            if let range = text.range(of: "chapter (\\d+)", options: .regularExpression) {
                return String(text[range])
            }
            
            if text.contains("chapter") {
                // Extract the chapter reference
                let components = text.components(separatedBy: " ")
                if let chapterIndex = components.firstIndex(of: "chapter"),
                   chapterIndex + 1 < components.count {
                    return "Chapter \(components[chapterIndex + 1])"
                }
            }
        }
        
        return nil
    }
    
    private func extractPageNumber(from text: String) -> Int? {
        // Look for page references
        let patterns = [
            "page (\\d+)",
            "p\\. ?(\\d+)",
            "pg (\\d+)"
        ]
        
        for pattern in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let pageText = String(text[range])
                let numbers = pageText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                return Int(numbers)
            }
        }
        
        return nil
    }
    
    private func isLocationIndicator(_ context: String, word: String) -> Bool {
        let locationPrepositions = ["in", "at", "to", "from", "near", "by", "through", "across"]
        let contextLower = context.lowercased()
        
        for prep in locationPrepositions {
            if contextLower.contains("\(prep) \(word.lowercased())") {
                return true
            }
        }
        
        return false
    }
    
    private func isCommonWord(_ word: String) -> Bool {
        commonWords.contains(word)
    }
    
    private func getGenreVocabulary(for genre: String) -> [String] {
        switch genre.lowercased() {
        case "fantasy":
            return ["magic", "spell", "wizard", "dragon", "quest", "sword", "kingdom", "prophecy"]
        case "science fiction", "sci-fi":
            return ["spaceship", "galaxy", "alien", "robot", "AI", "planet", "warp", "quantum"]
        case "mystery":
            return ["detective", "clue", "murder", "suspect", "evidence", "alibi", "witness"]
        case "romance":
            return ["love", "heart", "kiss", "passion", "desire", "soulmate", "wedding"]
        case "thriller":
            return ["danger", "escape", "chase", "conspiracy", "secret", "betrayal", "survival"]
        default:
            return []
        }
    }
    
    private func parseContextExtraction(from response: String) -> ContextExtraction {
        // Simple parsing logic - in production, use more sophisticated parsing
        var characters: [String] = []
        var themes: [String] = []
        var locations: [String] = []
        var chapter: String? = nil
        var mood: String = "neutral"
        
        let lines = response.components(separatedBy: .newlines)
        var currentSection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.lowercased().contains("character") {
                currentSection = "characters"
            } else if trimmed.lowercased().contains("theme") {
                currentSection = "themes"
            } else if trimmed.lowercased().contains("location") {
                currentSection = "locations"
            } else if trimmed.lowercased().contains("chapter") {
                currentSection = "chapter"
            } else if trimmed.lowercased().contains("mood") {
                currentSection = "mood"
            } else if !trimmed.isEmpty && trimmed.first != "-" {
                switch currentSection {
                case "characters":
                    characters.append(trimmed)
                case "themes":
                    themes.append(trimmed)
                case "locations":
                    locations.append(trimmed)
                case "chapter":
                    chapter = trimmed
                case "mood":
                    mood = trimmed.lowercased()
                default:
                    break
                }
            }
        }
        
        return ContextExtraction(
            characters: characters,
            themes: themes,
            locations: locations,
            chapter: chapter,
            mood: mood
        )
    }
    
    // MARK: - Public Methods
    
    func getContextForWhisperKit() -> [String] {
        currentContext?.contextualVocabulary ?? []
    }
    
    func getRecentCharacters() -> [String] {
        currentContext?.recentCharacters ?? []
    }
    
    func getCurrentMood() -> String {
        currentContext?.sessionMood ?? "neutral"
    }
    
    func clearContext() {
        currentContext = nil
        detectedCharacters.removeAll()
        detectedThemes.removeAll()
        detectedLocations.removeAll()
        recentTerms.removeAll()
    }
}

// MARK: - Constants

private let commonWords = Set([
    "the", "and", "for", "are", "but", "not", "you", "all", "can", "had",
    "her", "was", "one", "our", "out", "his", "has", "how", "its", "who",
    "will", "with", "what", "when", "where", "why", "this", "that", "these",
    "those", "been", "have", "from", "they", "were", "would", "could", "should",
    "said", "says", "very", "just", "only", "also", "more", "some", "such",
    "there", "their", "them", "then", "than", "other", "after", "before"
])

private let themeKeywords = [
    "love", "death", "power", "justice", "freedom", "identity", "family",
    "friendship", "betrayal", "redemption", "sacrifice", "courage", "hope",
    "fear", "destiny", "truth", "wisdom", "honor", "revenge", "faith"
]

private let positiveWords = [
    "amazing", "beautiful", "brilliant", "excellent", "fantastic", "wonderful",
    "love", "joy", "happy", "excited", "fascinating", "interesting", "compelling"
]

private let negativeWords = [
    "sad", "tragic", "terrible", "horrible", "awful", "disappointing", "boring",
    "confusing", "frustrating", "anger", "fear", "worry", "concern"
]