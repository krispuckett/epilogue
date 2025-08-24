import Foundation
import SwiftUI
import SwiftData

// MARK: - Multi-Step Command Support
enum ChainedCommand {
    case addBooks([String])
    case markAsStatus([String], ReadingStatus)
    case setReadingGoal(Book, pagesPerDay: Int)
    case createReminder(String, date: Date)
    case batchNote(String, books: [Book])
    case compound([ChainedCommand]) // For nested commands
    
    enum ReadingStatus {
        case wantToRead
        case currentlyReading
        case finished
    }
}

class MultiStepCommandParser {
    
    // MARK: - Parse Complex Commands
    static func parse(_ input: String, books: [Book]) -> [ChainedCommand] {
        var commands: [ChainedCommand] = []
        
        // Clean and prepare input
        let normalizedInput = input
            .replacingOccurrences(of: " and ", with: " & ")
            .lowercased()
        
        // Parse different command patterns
        if let addBooksCommand = parseAddBooksCommand(normalizedInput) {
            commands.append(addBooksCommand)
        }
        
        if let goalCommand = parseReadingGoalCommand(normalizedInput, books: books) {
            commands.append(goalCommand)
        }
        
        if let reminderCommand = parseReminderCommand(normalizedInput, books: books) {
            commands.append(reminderCommand)
        }
        
        if let batchCommand = parseBatchCommand(normalizedInput, books: books) {
            commands.append(batchCommand)
        }
        
        return commands
    }
    
    // MARK: - Add Multiple Books
    private static func parseAddBooksCommand(_ input: String) -> ChainedCommand? {
        // Pattern: "add [book1] & [book2] & [book3] to my library"
        let pattern = #"add (.+) to (?:my )?library"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let range = Range(match.range(at: 1), in: input) else {
            return nil
        }
        
        let booksList = String(input[range])
        let bookTitles = booksList
            .split(separator: "&")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Check if we should also mark status
        if input.contains("mark") || input.contains("as") {
            if input.contains("want to read") || input.contains("to read") {
                return .compound([
                    .addBooks(bookTitles),
                    .markAsStatus(bookTitles, .wantToRead)
                ])
            } else if input.contains("currently reading") || input.contains("reading") {
                return .compound([
                    .addBooks(bookTitles),
                    .markAsStatus(bookTitles, .currentlyReading)
                ])
            }
        }
        
        return .addBooks(bookTitles)
    }
    
    // MARK: - Reading Goals
    private static func parseReadingGoalCommand(_ input: String, books: [Book]) -> ChainedCommand? {
        // Pattern: "create a reading goal of X pages daily for @book"
        // Or: "set goal 20 pages per day @book"
        let patterns = [
            #"(?:create|set) (?:a )?(?:reading )?goal (?:of )?(\d+) pages? (?:per day|daily)"#,
            #"read (\d+) pages? (?:per day|daily|a day)"#,
            #"(\d+) pages? (?:per day|daily) goal"#
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
                  let range = Range(match.range(at: 1), in: input) else {
                continue
            }
            
            let pagesString = String(input[range])
            guard let pages = Int(pagesString) else { continue }
            
            // Extract book from @mention
            let (_, book) = BookMentionParser.extractBookContext(from: input, books: books)
            
            if let book = book {
                return .setReadingGoal(book, pagesPerDay: pages)
            }
        }
        
        return nil
    }
    
    // MARK: - Reminders with Natural Language
    private static func parseReminderCommand(_ input: String, books: [Book]) -> ChainedCommand? {
        // Pattern: "remind me to [action] [time expression]"
        let pattern = #"remind (?:me )?(?:to )?(.*?)(?:tomorrow|tonight|(?:in|after) \d+ (?:hour|day|week)|(?:at|by) \d+(?::\d+)?(?:am|pm)?)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }
        
        // Extract the reminder text
        guard let textRange = Range(match.range(at: 1), in: input) else { return nil }
        let reminderText = String(input[textRange]).trimmingCharacters(in: .whitespaces)
        
        // Parse the date/time
        if let date = NaturalLanguageDateParser.parse(from: input) {
            return .createReminder(reminderText, date: date)
        }
        
        return nil
    }
    
    // MARK: - Batch Operations
    private static func parseBatchCommand(_ input: String, books: [Book]) -> ChainedCommand? {
        // Pattern: "add note '[note text]' to @book1 & @book2"
        if input.contains("add note") || input.contains("create note") {
            // Extract note text (in quotes if present)
            var noteText = ""
            if let quotedRange = input.range(of: #"["'](.*?)["']"#, options: .regularExpression) {
                noteText = String(input[quotedRange])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            } else {
                // Extract text between "note" and first @
                if let noteStart = input.range(of: "note"),
                   let atIndex = input.firstIndex(of: "@") {
                    let textRange = noteStart.upperBound..<atIndex
                    noteText = String(input[textRange])
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Find all book mentions
            let mentions = BookMentionParser.detectMentions(in: input, books: books)
            if !mentions.isEmpty && !noteText.isEmpty {
                return .batchNote(noteText, books: mentions.map { $0.book })
            }
        }
        
        return nil
    }
}

// MARK: - Natural Language Date Parser
class NaturalLanguageDateParser {
    static func parse(from text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        // Tomorrow
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        
        // Tonight (today at 8 PM)
        if lowercased.contains("tonight") {
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)
        }
        
        // Next week
        if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }
        
        // In X minutes/hours/days/weeks
        let inPattern = #"in (\d+) (minute|hour|day|week)s?"#
        if let regex = try? NSRegularExpression(pattern: inPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {
            
            if let numberRange = Range(match.range(at: 1), in: lowercased),
               let unitRange = Range(match.range(at: 2), in: lowercased) {
                
                let number = Int(String(lowercased[numberRange])) ?? 0
                let unit = String(lowercased[unitRange])
                
                switch unit {
                case "minute":
                    return calendar.date(byAdding: .minute, value: number, to: now)
                case "hour":
                    return calendar.date(byAdding: .hour, value: number, to: now)
                case "day":
                    return calendar.date(byAdding: .day, value: number, to: now)
                case "week":
                    return calendar.date(byAdding: .weekOfYear, value: number, to: now)
                default:
                    break
                }
            }
        }
        
        // Specific time (at 3pm, at 15:00)
        let timePattern = #"at (\d{1,2}):?(\d{2})?\s?(am|pm)?"#
        if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {
            
            if let hourRange = Range(match.range(at: 1), in: lowercased) {
                var hour = Int(String(lowercased[hourRange])) ?? 0
                var minute = 0
                
                // Get minutes if specified
                if let minuteRange = Range(match.range(at: 2), in: lowercased) {
                    minute = Int(String(lowercased[minuteRange])) ?? 0
                }
                
                // Handle AM/PM
                if let ampmRange = Range(match.range(at: 3), in: lowercased) {
                    let ampm = String(lowercased[ampmRange])
                    if ampm == "pm" && hour < 12 {
                        hour += 12
                    } else if ampm == "am" && hour == 12 {
                        hour = 0
                    }
                }
                
                // Determine if today or tomorrow based on time
                if let targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) {
                    // If the time has already passed today, assume tomorrow
                    if targetDate < now {
                        return calendar.date(byAdding: .day, value: 1, to: targetDate)
                    }
                    return targetDate
                }
            }
        }
        
        // Day names (Monday, Tuesday, etc.)
        let weekdayPattern = #"(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
        if let regex = try? NSRegularExpression(pattern: weekdayPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
           let range = Range(match.range(at: 1), in: lowercased) {
            
            let dayName = String(lowercased[range])
            let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            
            if let targetWeekday = weekdays.firstIndex(of: dayName) {
                let currentWeekday = calendar.component(.weekday, from: now) - 1
                var daysToAdd = targetWeekday - currentWeekday
                
                // If the day has passed this week, get next week's
                if daysToAdd <= 0 {
                    daysToAdd += 7
                }
                
                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
            }
        }
        
        return nil
    }
}

// MARK: - Command Executor
// Note: The executor is implemented in CommandProcessingManager.swift
// This is kept here for reference of the command structure
/*
@MainActor
class MultiStepCommandExecutor {
    private let modelContext: ModelContext
    private let libraryViewModel: LibraryViewModel
    private let notesViewModel: NotesViewModel
    
    init(modelContext: ModelContext, libraryViewModel: LibraryViewModel, notesViewModel: NotesViewModel) {
        self.modelContext = modelContext
        self.libraryViewModel = libraryViewModel
        self.notesViewModel = notesViewModel
    }
    
    func execute(_ commands: [ChainedCommand]) async {
        for command in commands {
            await executeCommand(command)
        }
    }
    
    private func executeCommand(_ command: ChainedCommand) async {
        switch command {
        case .addBooks(let titles):
            for title in titles {
                // TODO: Search for book via API and add to library
                print("Adding book: \(title)")
            }
            
        case .markAsStatus(let titles, let status):
            // TODO: Update reading status for books
            print("Marking \(titles) as \(status)")
            
        case .setReadingGoal(let book, let pagesPerDay):
            // TODO: Create reading goal in SwiftData
            print("Setting goal of \(pagesPerDay) pages/day for \(book.title)")
            
        case .createReminder(let text, let date):
            // TODO: Schedule notification
            print("Creating reminder: '\(text)' for \(date)")
            
        case .batchNote(let note, let books):
            for book in books {
                // Create note for each book
                let capturedNote = CapturedNote(
                    content: note,
                    book: BookModel(from: book)
                )
                modelContext.insert(capturedNote)
            }
            try? modelContext.save()
            
        case .compound(let commands):
            for subCommand in commands {
                await executeCommand(subCommand)
            }
        }
    }
}
*/