import Foundation
import SwiftData
import SwiftUI

@Model
class ChatThread {
    var id: UUID = UUID()
    var bookId: UUID? // nil for general chat
    var bookTitle: String?
    var bookAuthor: String?
    var bookCoverURL: String?
    var messages: [ThreadedChatMessage] = []
    var lastMessageDate: Date = Date()
    var createdDate: Date = Date()
    
    // New properties for ambient sessions
    var isAmbientSession: Bool = false
    var capturedItems: Int = 0
    var sessionDuration: TimeInterval = 0
    var sessionSummary: String?
    var isArchived: Bool = false
    
    init(book: Book? = nil) {
        if let book = book {
            self.bookId = book.localId
            self.bookTitle = book.title
            self.bookAuthor = book.author
            self.bookCoverURL = book.coverImageURL
        }
    }
    
    // Convenience initializer for ambient sessions
    convenience init(ambientSession: AmbientSession, processedData: ProcessedAmbientSession) {
        self.init(book: ambientSession.book)
        self.isAmbientSession = true
        self.capturedItems = processedData.quotes.count + processedData.notes.count + processedData.questions.count
        self.sessionDuration = ambientSession.duration
        self.sessionSummary = processedData.summary
        self.createdDate = ambientSession.startTime
        self.lastMessageDate = ambientSession.endTime ?? Date()
    }
}

// Create a SwiftData compatible version of ChatMessage
@Model
class ThreadedChatMessage {
    var id: UUID = UUID()
    var content: String
    var isUser: Bool
    var timestamp: Date
    var bookTitle: String?
    var bookAuthor: String?
    
    init(content: String, isUser: Bool, timestamp: Date = Date(), bookTitle: String? = nil, bookAuthor: String? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
    }
}

// MARK: - Color Palette Model
@Model
final class ColorPaletteModel {
    var id: UUID = UUID()
    var bookId: String
    var extractionDate: Date
    var extractionVersion: String = "1.0"
    
    // Color components stored as Data for SwiftData compatibility
    var primaryColorData: Data?
    var secondaryColorData: Data?
    var accentColorData: Data?
    var backgroundColorData: Data?
    var textColorData: Data?
    
    var luminance: Double
    var isMonochromatic: Bool
    var extractionQuality: Double
    var extractionTimeMs: Double
    
    // Performance metrics
    var sourceImageSize: String?
    var processedPixelCount: Int
    var blackPixelPercentage: Double
    
    init(bookId: String, palette: ColorPalette, extractionTimeMs: Double = 0) {
        self.bookId = bookId
        self.extractionDate = Date()
        
        // Convert colors to data
        self.primaryColorData = UIColor(palette.primary).encode()
        self.secondaryColorData = UIColor(palette.secondary).encode()
        self.accentColorData = UIColor(palette.accent).encode()
        self.backgroundColorData = UIColor(palette.background).encode()
        self.textColorData = UIColor(palette.textColor).encode()
        
        self.luminance = palette.luminance
        self.isMonochromatic = palette.isMonochromatic
        self.extractionQuality = palette.extractionQuality
        self.extractionTimeMs = extractionTimeMs
        self.processedPixelCount = 0
        self.blackPixelPercentage = 0
    }
    
    func toColorPalette() -> ColorPalette? {
        guard let primary = primaryColorData?.toColor(),
              let secondary = secondaryColorData?.toColor(),
              let accent = accentColorData?.toColor(),
              let background = backgroundColorData?.toColor(),
              let textColor = textColorData?.toColor() else {
            return nil
        }
        
        return ColorPalette(
            primary: primary,
            secondary: secondary,
            accent: accent,
            background: background,
            textColor: textColor,
            luminance: luminance,
            isMonochromatic: isMonochromatic,
            extractionQuality: extractionQuality
        )
    }
}

// MARK: - UIColor Data Extensions
extension UIColor {
    func encode() -> Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
    }
}

extension Data {
    func toColor() -> Color? {
        guard let uiColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(self) as? UIColor else {
            return nil
        }
        return Color(uiColor)
    }
}