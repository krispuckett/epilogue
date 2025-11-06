import Foundation
import NaturalLanguage

class IntelligentTitleGenerator {

    // MARK: - Generate Title from Content

    static func generateTitle(from content: String, maxLength: Int = 60) -> String {
        // Clean and prepare content
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanContent.isEmpty else {
            return "Untitled Note"
        }

        // Try different strategies in order of sophistication

        // 1. Try to extract key noun phrases
        if let nounPhraseTitle = extractKeyNounPhrase(from: cleanContent, maxLength: maxLength) {
            return nounPhraseTitle
        }

        // 2. Try to use first sentence intelligently
        if let sentenceTitle = extractFirstSentence(from: cleanContent, maxLength: maxLength) {
            return sentenceTitle
        }

        // 3. Fallback: use first line with smart truncation
        return fallbackTitle(from: cleanContent, maxLength: maxLength)
    }

    // MARK: - Extract Key Noun Phrase

    private static func extractKeyNounPhrase(from text: String, maxLength: Int) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text

        var nounPhrases: [(phrase: String, range: Range<String.Index>, score: Int)] = []

        // Extract noun phrases with scoring
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            guard let tag = tag else { return true }

            let word = String(text[range])
            var score = 0

            // Score based on part of speech
            switch tag {
            case .noun:
                score = 3
            case .adjective:
                score = 2
            case .verb:
                score = 1
            default:
                score = 0
            }

            // Boost score for capitalized words (likely proper nouns)
            if word.first?.isUppercase == true {
                score += 2
            }

            // Extract multi-word phrases
            if score > 0 {
                let phraseStart = range.lowerBound
                var phraseEnd = range.upperBound
                var phraseScore = score

                // Try to extend the phrase
                tagger.enumerateTags(in: phraseEnd..<text.endIndex, unit: .word, scheme: .lexicalClass) { nextTag, nextRange in
                    guard let nextTag = nextTag else { return false }

                    let nextWord = String(text[nextRange])

                    // Continue phrase if it's an adjective, noun, or connector
                    if nextTag == .noun || nextTag == .adjective ||
                       nextWord.lowercased() == "of" || nextWord.lowercased() == "in" ||
                       nextWord.lowercased() == "and" || nextWord.lowercased() == "the" {
                        phraseEnd = nextRange.upperBound
                        if nextTag == .noun {
                            phraseScore += 3
                        } else if nextTag == .adjective {
                            phraseScore += 2
                        }
                        return true
                    }

                    return false
                }

                let phrase = String(text[phraseStart..<phraseEnd]).trimmingCharacters(in: .whitespaces)
                if phrase.count >= 3 && phrase.count <= maxLength {
                    nounPhrases.append((phrase: phrase, range: phraseStart..<phraseEnd, score: phraseScore))
                }
            }

            return true
        }

        // Find the best noun phrase (highest score, preferably near the beginning)
        let sortedPhrases = nounPhrases.sorted { lhs, rhs in
            // Prefer phrases closer to the start
            let lhsPosition = text.distance(from: text.startIndex, to: lhs.range.lowerBound)
            let rhsPosition = text.distance(from: text.startIndex, to: rhs.range.lowerBound)

            // Weight: 70% score, 30% position
            let lhsWeight = Double(lhs.score) * 0.7 - Double(lhsPosition) * 0.0003
            let rhsWeight = Double(rhs.score) * 0.7 - Double(rhsPosition) * 0.0003

            return lhsWeight > rhsWeight
        }

        if let bestPhrase = sortedPhrases.first {
            // Capitalize properly
            return bestPhrase.phrase.prefix(1).uppercased() + bestPhrase.phrase.dropFirst()
        }

        return nil
    }

    // MARK: - Extract First Sentence

    private static func extractFirstSentence(from text: String, maxLength: Int) -> String? {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        guard let firstSentenceRange = tokenizer.tokens(for: text.startIndex..<text.endIndex).first else {
            return nil
        }

        var sentence = String(text[firstSentenceRange]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove trailing punctuation for title
        while let last = sentence.last, CharacterSet.punctuationCharacters.contains(last.unicodeScalars.first!) {
            sentence.removeLast()
        }

        // If sentence is too long, try to extract the main clause
        if sentence.count > maxLength {
            // Find first comma or dash and take content before it
            if let commaIndex = sentence.firstIndex(of: ",") ?? sentence.firstIndex(of: "—") ?? sentence.firstIndex(of: "-") {
                let mainClause = String(sentence[..<commaIndex]).trimmingCharacters(in: .whitespaces)
                if mainClause.count >= 10 {
                    return mainClause
                }
            }

            // Truncate intelligently at word boundary
            return truncateAtWordBoundary(sentence, maxLength: maxLength)
        }

        return sentence.isEmpty ? nil : sentence
    }

    // MARK: - Fallback Title

    private static func fallbackTitle(from text: String, maxLength: Int) -> String {
        // Get first line
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "Untitled Note"
        }

        if trimmed.count <= maxLength {
            return trimmed
        }

        return truncateAtWordBoundary(trimmed, maxLength: maxLength)
    }

    // MARK: - Helper: Truncate at Word Boundary

    private static func truncateAtWordBoundary(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }

        let truncated = String(text.prefix(maxLength))

        // Find last space
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }

        return truncated + "..."
    }

    // MARK: - Generate Smart Filename

    static func generateFilename(
        from content: String,
        bookTitle: String? = nil,
        author: String? = nil,
        isQuote: Bool = false
    ) -> String {
        let title = generateTitle(from: content, maxLength: 40)
        let prefix = isQuote ? "Quote" : "Note"

        // Sanitize title for filename
        let sanitizedTitle = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if let book = bookTitle, let author = author {
            return "\(prefix) - \(sanitizedTitle) - \(book) - \(author).md"
        } else if let book = bookTitle {
            return "\(prefix) - \(sanitizedTitle) - \(book).md"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy"
            let dateString = dateFormatter.string(from: Date())
            return "\(prefix) - \(sanitizedTitle) - \(dateString).md"
        }
    }
}
