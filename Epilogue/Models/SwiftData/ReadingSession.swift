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
    
    var book: Book?
    
    init(
        book: Book,
        startPage: Int
    ) {
        self.id = UUID()
        self.book = book
        self.startDate = Date()
        self.startPage = startPage
        self.endPage = startPage
        self.pagesRead = 0
        self.duration = 0
    }
    
    func endSession(at endPage: Int) {
        self.endDate = Date()
        self.endPage = endPage
        self.pagesRead = max(0, endPage - startPage)
        if let endDate = endDate {
            self.duration = endDate.timeIntervalSince(startDate)
        }
    }
    
    var readingSpeed: Double {
        guard duration > 0, pagesRead > 0 else { return 0 }
        return Double(pagesRead) / (duration / 60) // Pages per minute
    }
}