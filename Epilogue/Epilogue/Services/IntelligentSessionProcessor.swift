import Foundation
import SwiftUI
import Combine

// MARK: - Data Models

struct ProgressUpdate {
    let type: ProgressType
    let value: String
    let rawText: String
    let position: Int // Character position in original text
    
    enum ProgressType {
        case page(Int)
        case chapter(Int)
        case percentage(Int)
        case section(String)
        
        var displayText: String {
            switch self {
            case .page(let num):
                return "Page \(num)"
            case .chapter(let num):
                return "Chapter \(num)"
            case .percentage(let pct):
                return "\(pct)%"
            case .section(let name):
                return name
            }
        }
    }
}

struct BookReference {
    let bookTitle: String
    let matchedBook: Book?
    let confidence: Double // 0.0 to 1.0
    let context: String // Surrounding text
}

struct SessionSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    enum SuggestionType {
        case updateProgress
        case linkBook
        case changeStatus
        case addNote
        case scheduleReading
    }
}

// MARK: - Intelligent Session Processor

@MainActor
class IntelligentSessionProcessor: ObservableObject {
    static let shared = IntelligentSessionProcessor()
    
    // MARK: - Progress Detection
    
    func detectProgressUpdates(content: String) -> [ProgressUpdate] {
        var updates: [ProgressUpdate] = []
        _ = content.lowercased()
        
        // Page number patterns
        let pagePatterns = [
            #"page\s+(\d+)"#,
            #"p\.\s*(\d+)"#,
            #"pg\s*(\d+)"#,
            #"on page\s+(\d+)"#,
            #"reached page\s+(\d+)"#
        ]
        
        for pattern in pagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content),
                       let pageNum = Int(content[range]) {
                        guard let fullRange = Range(match.range, in: content) else { continue }
                        updates.append(ProgressUpdate(
                            type: .page(pageNum),
                            value: String(content[fullRange]),
                            rawText: String(content[fullRange]),
                            position: match.range.location
                        ))
                    }
                }
            }
        }
        
        // Chapter patterns
        let chapterPatterns = [
            #"chapter\s+(\d+)"#,
            #"ch\.\s*(\d+)"#,
            #"ch\s+(\d+)"#,
            #"starting chapter\s+(\d+)"#,
            #"finished chapter\s+(\d+)"#
        ]
        
        for pattern in chapterPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content),
                       let chapterNum = Int(content[range]) {
                        guard let fullRange = Range(match.range, in: content) else { continue }
                        updates.append(ProgressUpdate(
                            type: .chapter(chapterNum),
                            value: String(content[fullRange]),
                            rawText: String(content[fullRange]),
                            position: match.range.location
                        ))
                    }
                }
            }
        }
        
        // Percentage patterns
        let percentPatterns = [
            #"(\d+)%\s*(?:through|done|complete)"#,
            #"(\d+)\s*percent"#,
            #"about\s+(\d+)%"#
        ]
        
        for pattern in percentPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content),
                       let percent = Int(content[range]) {
                        guard let fullRange = Range(match.range, in: content) else { continue }
                        updates.append(ProgressUpdate(
                            type: .percentage(percent),
                            value: String(content[fullRange]),
                            rawText: String(content[fullRange]),
                            position: match.range.location
                        ))
                    }
                }
            }
        }
        
        // Remove duplicates
        return updates.reduce(into: [ProgressUpdate]()) { result, update in
            if !result.contains(where: { $0.rawText == update.rawText && $0.position == update.position }) {
                result.append(update)
            }
        }
    }
    
    // MARK: - Book Reference Detection
    
    func detectBookReferences(content: String, library: [Book]) -> [BookReference] {
        var references: [BookReference] = []
        _ = content.split(separator: " ").map(String.init)
        
        // Check each book in library
        for book in library {
            let bookTitle = book.title.lowercased()
            let contentLower = content.lowercased()
            
            // Direct title match
            if contentLower.contains(bookTitle) {
                // Extract context around the match
                if let range = contentLower.range(of: bookTitle) {
                    let startIndex = content.index(range.lowerBound, offsetBy: -min(30, content.distance(from: content.startIndex, to: range.lowerBound)))
                    let endIndex = content.index(range.upperBound, offsetBy: min(30, content.distance(from: range.upperBound, to: content.endIndex)))
                    let context = String(content[startIndex..<endIndex])
                    
                    references.append(BookReference(
                        bookTitle: book.title,
                        matchedBook: book,
                        confidence: 1.0,
                        context: context
                    ))
                }
            }
            
            // Fuzzy match for partial titles
            let titleWords = bookTitle.split(separator: " ")
            if titleWords.count >= 2 {
                var matchedWords = 0
                for titleWord in titleWords {
                    if contentLower.contains(titleWord) {
                        matchedWords += 1
                    }
                }
                
                let confidence = titleWords.isEmpty ? 0.0 : Double(matchedWords) / Double(titleWords.count)
                if confidence >= 0.6 && !references.contains(where: { $0.matchedBook?.id == book.id }) {
                    references.append(BookReference(
                        bookTitle: book.title,
                        matchedBook: book,
                        confidence: confidence,
                        context: content
                    ))
                }
            }
            
            // Check for author mentions near book-related words
            let author = book.author
            if !author.isEmpty {
                let authorLower = author.lowercased()
                if contentLower.contains(authorLower) {
                    let bookWords = ["book", "novel", "reading", "story", "by"]
                    for word in bookWords {
                        if contentLower.contains(word) && contentLower.contains(authorLower) {
                            references.append(BookReference(
                                bookTitle: book.title,
                                matchedBook: book,
                                confidence: 0.7,
                                context: "Mentioned author: \(author)"
                            ))
                            break
                        }
                    }
                }
            }
        }
        
        // Sort by confidence and remove duplicates
        return references
            .sorted { $0.confidence > $1.confidence }
            .reduce(into: [BookReference]()) { result, ref in
                if !result.contains(where: { $0.matchedBook?.id == ref.matchedBook?.id }) {
                    result.append(ref)
                }
            }
    }
    
    // MARK: - Actionable Suggestions
    
    func generateActionableSuggestions(session: AmbientSession, library: [Book]) -> [SessionSuggestion] {
        var suggestions: [SessionSuggestion] = []
        
        let content = session.rawTranscriptions.joined(separator: " ")
        
        // Progress updates
        let progressUpdates = detectProgressUpdates(content: content)
        if !progressUpdates.isEmpty {
            if let latestProgress = progressUpdates.last {
                suggestions.append(SessionSuggestion(
                    type: .updateProgress,
                    title: "Update Reading Progress",
                    description: "Set progress to \(latestProgress.type.displayText)",
                    icon: "bookmark.fill",
                    action: {
                        // Update progress action
                        NotificationCenter.default.post(
                            name: Notification.Name("UpdateBookProgress"),
                            object: latestProgress
                        )
                    }
                ))
            }
        }
        
        // Book references
        let bookRefs = detectBookReferences(content: content, library: library)
        for ref in bookRefs.prefix(2) {
            if let book = ref.matchedBook, ref.confidence >= 0.7 {
                suggestions.append(SessionSuggestion(
                    type: .linkBook,
                    title: "Link to \(book.title)",
                    description: "Connect this session to your book",
                    icon: "link.circle.fill",
                    action: {
                        NotificationCenter.default.post(
                            name: Notification.Name("LinkSessionToBook"),
                            object: book
                        )
                    }
                ))
            }
        }
        
        // Reading status detection
        let completionKeywords = ["finished", "completed", "done with", "finished reading", "just finished"]
        let startKeywords = ["started", "beginning", "starting to read", "just started"]
        
        let lowerContent = content.lowercased()
        
        if completionKeywords.contains(where: lowerContent.contains) {
            suggestions.append(SessionSuggestion(
                type: .changeStatus,
                title: "Mark as Completed",
                description: "Update your reading status",
                icon: "checkmark.circle.fill",
                action: {
                    NotificationCenter.default.post(
                        name: Notification.Name("UpdateReadingStatus"),
                        object: "completed"
                    )
                }
            ))
        } else if startKeywords.contains(where: lowerContent.contains) {
            suggestions.append(SessionSuggestion(
                type: .changeStatus,
                title: "Mark as Currently Reading",
                description: "Update your reading status",
                icon: "book.fill",
                action: {
                    NotificationCenter.default.post(
                        name: Notification.Name("UpdateReadingStatus"),
                        object: "reading"
                    )
                }
            ))
        }
        
        // Note creation suggestion
        if content.count > 50 && (content.contains("interesting") || content.contains("important") || content.contains("remember")) {
            suggestions.append(SessionSuggestion(
                type: .addNote,
                title: "Create Note",
                description: "Save this reflection as a note",
                icon: "note.text",
                action: {
                    NotificationCenter.default.post(
                        name: Notification.Name("CreateNoteFromSession"),
                        object: session
                    )
                }
            ))
        }
        
        // Schedule reading suggestion
        let timeKeywords = ["tomorrow", "later", "tonight", "weekend", "next"]
        if timeKeywords.contains(where: lowerContent.contains) {
            suggestions.append(SessionSuggestion(
                type: .scheduleReading,
                title: "Schedule Reading Time",
                description: "Set a reminder to continue reading",
                icon: "calendar.badge.plus",
                action: {
                    NotificationCenter.default.post(
                        name: Notification.Name("ScheduleReading"),
                        object: nil
                    )
                }
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Content Analysis
    
    func analyzeSessionMood(content: String) -> SessionMood {
        let positive = ["love", "amazing", "beautiful", "wonderful", "excellent", "fantastic", "enjoyed"]
        let negative = ["difficult", "struggled", "confused", "boring", "disappointed", "hard"]
        let thoughtful = ["interesting", "thought-provoking", "compelling", "fascinating", "insightful"]
        
        let lowerContent = content.lowercased()
        
        var positiveScore = 0
        var negativeScore = 0
        var thoughtfulScore = 0
        
        for word in positive {
            if lowerContent.contains(word) { positiveScore += 1 }
        }
        
        for word in negative {
            if lowerContent.contains(word) { negativeScore += 1 }
        }
        
        for word in thoughtful {
            if lowerContent.contains(word) { thoughtfulScore += 1 }
        }
        
        if thoughtfulScore > positiveScore && thoughtfulScore > negativeScore {
            return .thoughtful
        } else if positiveScore > negativeScore {
            return .positive
        } else if negativeScore > positiveScore {
            return .challenging
        } else {
            return .neutral
        }
    }
}

// SessionMood enum moved to AmbientSessionModels.swift to avoid duplication