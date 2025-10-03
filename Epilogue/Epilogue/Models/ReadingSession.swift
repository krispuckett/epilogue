import SwiftData
import Foundation

@Model
final class ReadingSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval
    var startPage: Int
    var endPage: Int
    var pagesRead: Int
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
        return duration
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