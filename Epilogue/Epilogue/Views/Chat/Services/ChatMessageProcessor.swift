import Foundation
import SwiftData

// MARK: - Processed Content Types
enum ProcessedContentType {
    case quote
    case note
    case question
    case regular
}

struct ProcessedContent {
    let type: ProcessedContentType
    let content: String
    let saved: Bool
    let originalMessage: String
}

// MARK: - Chat Message Processor
class ChatMessageProcessor {
    
    static func processMessage(_ message: String, book: Book?) -> ProcessedContent {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for quote patterns
        if let quoteContent = detectQuote(in: trimmedMessage) {
            return ProcessedContent(
                type: .quote,
                content: quoteContent,
                saved: true,
                originalMessage: message
            )
        }
        
        // Check for note patterns
        if let noteContent = detectNote(in: trimmedMessage) {
            return ProcessedContent(
                type: .note,
                content: noteContent,
                saved: true,
                originalMessage: message
            )
        }
        
        // Check for questions
        if isQuestion(trimmedMessage) {
            return ProcessedContent(
                type: .question,
                content: trimmedMessage,
                saved: false,
                originalMessage: message
            )
        }
        
        // Regular message
        return ProcessedContent(
            type: .regular,
            content: message,
            saved: false,
            originalMessage: message
        )
    }
    
    // MARK: - Quote Detection
    
    private static func detectQuote(in message: String) -> String? {
        // Multiple quote patterns
        let patterns = [
            // Standard quotes with double quotes
            #"\"([^\"]+)\""#,
            // Smart quotes
            #""([^"]+)""#,
            // Single quotes (careful not to catch contractions)
            #"'([^']{10,})'"#,  // At least 10 chars to avoid contractions
            // Quote prefix
            #"^[Qq]uote:\s*(.+)"#,
            // Quote markers
            #"^>\s*(.+)"#  // Markdown-style quote
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) {
                if let range = Range(match.range(at: 1), in: message) {
                    return String(message[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Note Detection
    
    private static func detectNote(in message: String) -> String? {
        let lowercased = message.lowercased()
        
        // Note indicators
        let noteIndicators = [
            "note:", "note to self:", "remember:", "thought:",
            "reflection:", "insight:", "observation:"
        ]
        
        for indicator in noteIndicators {
            if lowercased.starts(with: indicator) {
                let startIndex = message.index(message.startIndex, offsetBy: indicator.count)
                return String(message[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Check for reflection-style messages (longer thoughtful messages)
        if message.count > 100 && 
           (lowercased.contains("realize") || 
            lowercased.contains("think") || 
            lowercased.contains("feel") ||
            lowercased.contains("reminds me")) {
            return message
        }
        
        return nil
    }
    
    // MARK: - Question Detection
    
    private static func isQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        return trimmed.contains("?") ||
               lowercased.starts(with: "why") ||
               lowercased.starts(with: "how") ||
               lowercased.starts(with: "what") ||
               lowercased.starts(with: "when") ||
               lowercased.starts(with: "where") ||
               lowercased.starts(with: "who") ||
               lowercased.contains("i wonder") ||
               lowercased.contains("i'm curious") ||
               lowercased.contains("do you think")
    }
}