import SwiftUI
import SwiftData

// MARK: - Bridge Extensions to convert SwiftData models to Note type

extension CapturedNote {
    func toNote() -> Note {
        Note(
            type: .note,
            content: self.content,
            bookId: self.book?.localId != nil ? UUID(uuidString: self.book?.localId ?? "") : nil,
            bookTitle: self.book?.title,
            author: self.book?.author,
            pageNumber: self.pageNumber,
            dateCreated: self.timestamp,
            id: self.id
        )
    }
}

extension CapturedQuote {
    func toNote() -> Note {
        Note(
            type: .quote,
            content: self.text,
            bookId: self.book?.localId != nil ? UUID(uuidString: self.book?.localId ?? "") : nil,
            bookTitle: self.book?.title,
            author: self.author ?? self.book?.author,
            pageNumber: self.pageNumber,
            dateCreated: self.timestamp,
            id: self.id
        )
    }
}

extension CapturedQuestion {
    func toNote() -> Note {
        Note(
            type: .note,  // Questions are stored as notes
            content: self.content,
            bookId: self.book?.localId != nil ? UUID(uuidString: self.book?.localId ?? "") : nil,
            bookTitle: self.book?.title,
            author: self.book?.author,
            pageNumber: self.pageNumber,
            dateCreated: self.timestamp,
            id: self.id
        )
    }
}