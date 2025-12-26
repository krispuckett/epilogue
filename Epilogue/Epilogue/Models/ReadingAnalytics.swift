import Foundation
import SwiftData

// MARK: - Reading Analytics Model

/// Stores computed reading insights for efficient querying
/// This model caches aggregated analytics to avoid recomputing on every view
@Model
final class ReadingAnalytics {
    var id: UUID = UUID()
    var lastUpdated: Date = Date()

    // MARK: - Streak Tracking
    var currentStreak: Int = 0  // Consecutive days reading
    var longestStreak: Int = 0
    var lastReadingDate: Date?

    // MARK: - Time-Based Aggregates (updated periodically)
    var totalReadingTimeThisWeek: TimeInterval = 0
    var totalReadingTimeThisMonth: TimeInterval = 0
    var totalReadingTimeThisYear: TimeInterval = 0
    var totalReadingTimeAllTime: TimeInterval = 0

    // MARK: - Session Counts
    var sessionsThisWeek: Int = 0
    var sessionsThisMonth: Int = 0
    var sessionsThisYear: Int = 0
    var totalSessions: Int = 0

    // MARK: - Engagement Metrics
    var quotesThisWeek: Int = 0
    var quotesThisMonth: Int = 0
    var quotesThisYear: Int = 0
    var totalQuotes: Int = 0

    var notesThisWeek: Int = 0
    var notesThisMonth: Int = 0
    var notesThisYear: Int = 0
    var totalNotes: Int = 0

    var aiChatsThisWeek: Int = 0
    var aiChatsThisMonth: Int = 0
    var aiChatsThisYear: Int = 0
    var totalAiChats: Int = 0

    // MARK: - Book Metrics
    var booksStartedThisYear: Int = 0
    var booksFinishedThisYear: Int = 0
    var booksStartedAllTime: Int = 0
    var booksFinishedAllTime: Int = 0

    // MARK: - Patterns (stored as JSON strings for flexibility)
    var hourlyDistribution: String?  // JSON: [hour: minutes]
    var dayOfWeekDistribution: String?  // JSON: [dayIndex: minutes]
    var monthlyTrend: String?  // JSON: [monthIndex: minutes]

    // MARK: - Preferences
    var preferredReadingHour: Int?  // 0-23
    var preferredDayOfWeek: Int?  // 1-7 (Sunday = 1)

    init() {
        self.id = UUID()
        self.lastUpdated = Date()
    }

    // MARK: - Computed Properties

    var averageSessionLength: TimeInterval {
        guard totalSessions > 0 else { return 0 }
        return totalReadingTimeAllTime / Double(totalSessions)
    }

    var averageSessionLengthThisWeek: TimeInterval {
        guard sessionsThisWeek > 0 else { return 0 }
        return totalReadingTimeThisWeek / Double(sessionsThisWeek)
    }

    var quotesPerHour: Double {
        guard totalReadingTimeAllTime > 0 else { return 0 }
        let hours = totalReadingTimeAllTime / 3600
        return Double(totalQuotes) / hours
    }

    var notesPerHour: Double {
        guard totalReadingTimeAllTime > 0 else { return 0 }
        let hours = totalReadingTimeAllTime / 3600
        return Double(totalNotes) / hours
    }

    // MARK: - Streak Management

    func updateStreak(for date: Date = Date()) {
        let calendar = Calendar.current

        guard let lastDate = lastReadingDate else {
            // First ever reading session
            currentStreak = 1
            lastReadingDate = date
            longestStreak = max(longestStreak, currentStreak)
            return
        }

        let daysBetween = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: date)).day ?? 0

        switch daysBetween {
        case 0:
            // Same day, no change to streak
            break
        case 1:
            // Consecutive day
            currentStreak += 1
            longestStreak = max(longestStreak, currentStreak)
        default:
            // Streak broken
            currentStreak = 1
        }

        lastReadingDate = date
    }

    func checkStreakBroken() -> Bool {
        guard let lastDate = lastReadingDate else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)
        let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        return daysBetween > 1
    }

    // MARK: - JSON Helpers

    func getHourlyDistribution() -> [Int: TimeInterval] {
        guard let json = hourlyDistribution,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return [:]
        }
        return dict.reduce(into: [:]) { result, pair in
            if let hour = Int(pair.key) {
                result[hour] = pair.value
            }
        }
    }

    func setHourlyDistribution(_ distribution: [Int: TimeInterval]) {
        let stringDict = distribution.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value
        }
        if let data = try? JSONEncoder().encode(stringDict),
           let json = String(data: data, encoding: .utf8) {
            hourlyDistribution = json
        }
    }

    func getDayOfWeekDistribution() -> [Int: TimeInterval] {
        guard let json = dayOfWeekDistribution,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return [:]
        }
        return dict.reduce(into: [:]) { result, pair in
            if let day = Int(pair.key) {
                result[day] = pair.value
            }
        }
    }

    func setDayOfWeekDistribution(_ distribution: [Int: TimeInterval]) {
        let stringDict = distribution.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value
        }
        if let data = try? JSONEncoder().encode(stringDict),
           let json = String(data: data, encoding: .utf8) {
            dayOfWeekDistribution = json
        }
    }

    func getMonthlyTrend() -> [Int: TimeInterval] {
        guard let json = monthlyTrend,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return [:]
        }
        return dict.reduce(into: [:]) { result, pair in
            if let month = Int(pair.key) {
                result[month] = pair.value
            }
        }
    }

    func setMonthlyTrend(_ trend: [Int: TimeInterval]) {
        let stringDict = trend.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value
        }
        if let data = try? JSONEncoder().encode(stringDict),
           let json = String(data: data, encoding: .utf8) {
            monthlyTrend = json
        }
    }
}

// MARK: - Daily Reading Summary

/// Stores daily reading data for efficient calendar/heat map queries
@Model
final class DailyReadingSummary {
    var id: UUID = UUID()
    var date: Date = Date()  // Start of day
    var totalReadingTime: TimeInterval = 0
    var sessionCount: Int = 0
    var quotesCount: Int = 0
    var notesCount: Int = 0
    var aiChatsCount: Int = 0
    var pagesRead: Int = 0

    // Book tracking for the day
    var bookIdsRead: [String] = []  // localIds of books read this day

    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
    }

    var hasActivity: Bool {
        totalReadingTime > 0 || quotesCount > 0 || notesCount > 0
    }

    var formattedReadingTime: String {
        let hours = Int(totalReadingTime) / 3600
        let minutes = (Int(totalReadingTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
}

// MARK: - Book Reading Stats

/// Per-book reading statistics
@Model
final class BookReadingStats {
    var id: UUID = UUID()
    var bookLocalId: String = ""
    var bookTitle: String = ""  // Cached for display
    var bookAuthor: String = ""  // Cached for display

    var totalReadingTime: TimeInterval = 0
    var sessionCount: Int = 0
    var firstStartedDate: Date?
    var lastReadDate: Date?
    var completedDate: Date?

    var quotesCount: Int = 0
    var notesCount: Int = 0
    var aiChatsCount: Int = 0

    var averageSessionLength: TimeInterval {
        guard sessionCount > 0 else { return 0 }
        return totalReadingTime / Double(sessionCount)
    }

    var daysToComplete: Int? {
        guard let started = firstStartedDate, let completed = completedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: started, to: completed).day
    }

    init(bookLocalId: String, title: String, author: String) {
        self.id = UUID()
        self.bookLocalId = bookLocalId
        self.bookTitle = title
        self.bookAuthor = author
    }
}

// MARK: - Reading Milestone

/// Celebrates reading achievements
@Model
final class ReadingMilestone {
    var id: UUID = UUID()
    var type: String = ""  // MilestoneType.rawValue
    var achievedDate: Date = Date()
    var value: Int = 0  // e.g., 7 for "7-day streak"
    var bookLocalId: String?  // If milestone is book-specific
    var celebrated: Bool = false  // Has user seen celebration?

    init(type: MilestoneType, value: Int = 0, bookLocalId: String? = nil) {
        self.id = UUID()
        self.type = type.rawValue
        self.value = value
        self.bookLocalId = bookLocalId
        self.achievedDate = Date()
        self.celebrated = false
    }

    var milestoneType: MilestoneType {
        MilestoneType(rawValue: type) ?? .firstSession
    }
}

enum MilestoneType: String, Codable, CaseIterable {
    case firstSession = "first_session"
    case firstBook = "first_book"
    case firstQuote = "first_quote"
    case firstNote = "first_note"

    case streak7Days = "streak_7_days"
    case streak30Days = "streak_30_days"
    case streak100Days = "streak_100_days"
    case streak365Days = "streak_365_days"

    case hours10 = "hours_10"
    case hours50 = "hours_50"
    case hours100 = "hours_100"
    case hours500 = "hours_500"

    case books5 = "books_5"
    case books10 = "books_10"
    case books25 = "books_25"
    case books50 = "books_50"
    case books100 = "books_100"

    case quotes50 = "quotes_50"
    case quotes100 = "quotes_100"
    case quotes500 = "quotes_500"

    case notes50 = "notes_50"
    case notes100 = "notes_100"

    var displayName: String {
        switch self {
        case .firstSession: return "First Reading Session"
        case .firstBook: return "First Book Completed"
        case .firstQuote: return "First Quote Captured"
        case .firstNote: return "First Note Written"

        case .streak7Days: return "7-Day Streak"
        case .streak30Days: return "30-Day Streak"
        case .streak100Days: return "100-Day Streak"
        case .streak365Days: return "Year-Long Streak"

        case .hours10: return "10 Hours Read"
        case .hours50: return "50 Hours Read"
        case .hours100: return "100 Hours Read"
        case .hours500: return "500 Hours Read"

        case .books5: return "5 Books Completed"
        case .books10: return "10 Books Completed"
        case .books25: return "25 Books Completed"
        case .books50: return "50 Books Completed"
        case .books100: return "100 Books Completed"

        case .quotes50: return "50 Quotes Captured"
        case .quotes100: return "100 Quotes Captured"
        case .quotes500: return "500 Quotes Captured"

        case .notes50: return "50 Notes Written"
        case .notes100: return "100 Notes Written"
        }
    }

    var icon: String {
        switch self {
        case .firstSession, .streak7Days, .streak30Days, .streak100Days, .streak365Days:
            return "flame.fill"
        case .firstBook, .books5, .books10, .books25, .books50, .books100:
            return "book.closed.fill"
        case .firstQuote, .quotes50, .quotes100, .quotes500:
            return "quote.bubble.fill"
        case .firstNote, .notes50, .notes100:
            return "note.text"
        case .hours10, .hours50, .hours100, .hours500:
            return "clock.fill"
        }
    }

    var celebrationMessage: String {
        switch self {
        case .firstSession: return "You've started your reading journey!"
        case .firstBook: return "Congratulations on finishing your first book!"
        case .firstQuote: return "Great capture! Keep collecting wisdom."
        case .firstNote: return "Your thoughts matter. Keep reflecting."

        case .streak7Days: return "A whole week of reading! Keep it up!"
        case .streak30Days: return "A month of daily reading. You're building a habit!"
        case .streak100Days: return "100 days! Reading is part of who you are."
        case .streak365Days: return "A year of daily reading. Truly remarkable!"

        case .hours10: return "10 hours of reading completed!"
        case .hours50: return "50 hours! That's dedication."
        case .hours100: return "100 hours of reading. Impressive!"
        case .hours500: return "500 hours! You're a true bookworm."

        case .books5: return "5 books down, many more to discover!"
        case .books10: return "Double digits! 10 books completed."
        case .books25: return "25 books! You're well-read."
        case .books50: return "50 books! A remarkable library."
        case .books100: return "100 books! A true bibliophile."

        case .quotes50: return "50 quotes captured! Building a collection."
        case .quotes100: return "100 quotes! A treasure trove of wisdom."
        case .quotes500: return "500 quotes! You're a curator of words."

        case .notes50: return "50 notes! Your reflections are growing."
        case .notes100: return "100 notes! A rich tapestry of thoughts."
        }
    }
}
