import SwiftData
import Foundation

@Model
final class ReadingSession {
    var id: UUID = UUID()  // CloudKit: no unique constraint, default value
    var startDate: Date = Date()  // CloudKit: default value
    var endDate: Date?
    var duration: TimeInterval = 0  // CloudKit: default value
    var startPage: Int = 0  // CloudKit: default value
    var endPage: Int = 0  // CloudKit: default value
    var pagesRead: Int = 0  // CloudKit: default value
    var isAmbientSession: Bool = false  // Default to preserve old data
    var lastInteraction: Date = Date()  // Default to preserve old data

    // MARK: - Analytics Metrics (added for reading pattern analysis)
    var quotesCapturedDuringSession: Int = 0  // Quotes captured during this session
    var notesCreatedDuringSession: Int = 0  // Notes created during this session
    var aiChatsDuringSession: Int = 0  // AI chat interactions during this session
    var bookLocalId: String?  // Cached for analytics queries without joining

    var bookModel: BookModel?

    init(
        bookModel: BookModel,
        startPage: Int,
        isAmbientSession: Bool = false
    ) {
        self.id = UUID()
        self.bookModel = bookModel
        self.bookLocalId = bookModel.localId  // Cache for analytics
        self.startDate = Date()
        self.startPage = startPage
        self.endPage = startPage
        self.pagesRead = 0
        self.duration = 0
        self.isAmbientSession = isAmbientSession
        self.lastInteraction = Date()
    }

    // MARK: - Time Pattern Helpers

    /// Hour of day when session started (0-23)
    var startHour: Int {
        Calendar.current.component(.hour, from: startDate)
    }

    /// Day of week when session started (1 = Sunday, 7 = Saturday)
    var dayOfWeek: Int {
        Calendar.current.component(.weekday, from: startDate)
    }

    /// Month when session occurred (1-12)
    var month: Int {
        Calendar.current.component(.month, from: startDate)
    }

    /// Year when session occurred
    var year: Int {
        Calendar.current.component(.year, from: startDate)
    }

    /// Time of day category
    var timeOfDay: TimeOfDay {
        switch startHour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    /// Increment quote counter
    func recordQuoteCapture() {
        quotesCapturedDuringSession += 1
        lastInteraction = Date()
    }

    /// Increment note counter
    func recordNoteCreation() {
        notesCreatedDuringSession += 1
        lastInteraction = Date()
    }

    /// Increment AI chat counter
    func recordAIChat() {
        aiChatsDuringSession += 1
        lastInteraction = Date()
    }

    func updateCurrentPage(_ page: Int) {
        self.endPage = page
        self.lastInteraction = Date()
    }

    func toggleAmbientMode() {
        self.isAmbientSession.toggle()
        self.lastInteraction = Date()
    }

    func endSession(at endPage: Int) {
        self.endDate = Date()
        self.endPage = endPage
        self.pagesRead = max(0, endPage - startPage)
        if let endDate = endDate {
            self.duration = endDate.timeIntervalSince(startDate)
        }
    }

    var currentDuration: TimeInterval {
        guard let endDate = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        // Calculate from endDate directly (for paused state before save)
        return endDate.timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        let totalSeconds = Int(currentDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var readingSpeed: Double {
        guard duration > 0, pagesRead > 0 else { return 0 }
        return Double(pagesRead) / (duration / 60) // Pages per minute
    }
}

// MARK: - Time of Day

enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "Morning"      // 5 AM - 12 PM
    case afternoon = "Afternoon"  // 12 PM - 5 PM
    case evening = "Evening"      // 5 PM - 9 PM
    case night = "Night"          // 9 PM - 5 AM

    var icon: String {
        switch self {
        case .morning: return "sun.horizon.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var hourRange: String {
        switch self {
        case .morning: return "5 AM - 12 PM"
        case .afternoon: return "12 PM - 5 PM"
        case .evening: return "5 PM - 9 PM"
        case .night: return "9 PM - 5 AM"
        }
    }
}