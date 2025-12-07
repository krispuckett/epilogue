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

    var bookModel: BookModel?

    init(
        bookModel: BookModel,
        startPage: Int,
        isAmbientSession: Bool = false
    ) {
        self.id = UUID()
        self.bookModel = bookModel
        self.startDate = Date()
        self.startPage = startPage
        self.endPage = startPage
        self.pagesRead = 0
        self.duration = 0
        self.isAmbientSession = isAmbientSession
        self.lastInteraction = Date()
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