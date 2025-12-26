import SwiftUI
import UIKit

// MARK: - Export Format
/// Available export formats for quote cards
enum QuoteCardFormat: String, CaseIterable, Identifiable {
    case instagramStory = "Instagram Story"
    case instagramPost = "Instagram Post"
    case twitter = "Twitter/X"
    case custom = "Custom"

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .instagramStory: return CGSize(width: 1080, height: 1920)
        case .instagramPost: return CGSize(width: 1080, height: 1080)
        case .twitter: return CGSize(width: 1200, height: 675)
        case .custom: return CGSize(width: 1080, height: 1080) // Default, user can override
        }
    }

    var aspectRatio: CGFloat {
        size.width / size.height
    }

    var displayIcon: String {
        switch self {
        case .instagramStory: return "rectangle.portrait"
        case .instagramPost: return "square"
        case .twitter: return "rectangle"
        case .custom: return "square.resize"
        }
    }

    var previewHeight: CGFloat {
        // Scale down to fit in preview while maintaining aspect ratio
        switch self {
        case .instagramStory: return 400
        case .instagramPost: return 320
        case .twitter: return 220
        case .custom: return 320
        }
    }

    var previewWidth: CGFloat {
        previewHeight * aspectRatio
    }
}

// MARK: - Card Template
/// Design templates for quote cards
enum QuoteCardTemplate: String, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case bookColor = "Book Color"
    case paper = "Paper"
    case bold = "Bold"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .minimal: return "Clean & elegant"
        case .bookColor: return "Book palette"
        case .paper: return "Vintage texture"
        case .bold: return "High contrast"
        }
    }

    var icon: String {
        switch self {
        case .minimal: return "text.quote"
        case .bookColor: return "paintpalette"
        case .paper: return "doc.richtext"
        case .bold: return "bold"
        }
    }
}

// MARK: - Font Selection
/// Available fonts for quote cards
enum QuoteCardFont: String, CaseIterable, Identifiable {
    case georgia = "Georgia"
    case asul = "Asul"
    case faculty = "Faculty Glyphic"
    case newYork = "New York"
    case times = "Times New Roman"
    case typewriter = "American Typewriter"
    case palatino = "Palatino"
    case baskerville = "Baskerville"

    var id: String { rawValue }

    var fontName: String {
        switch self {
        case .georgia: return "Georgia"
        case .asul: return "Asul"
        case .faculty: return "FacultyGlyphic-Regular"
        case .newYork: return "NewYork-Regular"
        case .times: return "Times New Roman"
        case .typewriter: return "American Typewriter"
        case .palatino: return "Palatino"
        case .baskerville: return "Baskerville"
        }
    }

    var displayName: String { rawValue }

    /// Check if font is available on the system
    var isAvailable: Bool {
        UIFont(name: fontName, size: 12) != nil || fontName == "Georgia" || fontName == "Times New Roman"
    }

    /// Fonts suitable for specific templates
    static func fontsForTemplate(_ template: QuoteCardTemplate) -> [QuoteCardFont] {
        switch template {
        case .minimal:
            return [.georgia, .newYork, .palatino, .baskerville]
        case .bookColor:
            return [.georgia, .asul, .faculty, .palatino]
        case .paper:
            return [.typewriter, .baskerville, .times]
        case .bold:
            return allCases
        }
    }
}

// MARK: - Text Alignment
enum QuoteCardAlignment: String, CaseIterable, Identifiable {
    case leading = "Left"
    case center = "Center"
    case trailing = "Right"

    var id: String { rawValue }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var icon: String {
        switch self {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }
}

// MARK: - Color Scheme
enum QuoteCardColorScheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case auto = "From Book"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .auto: return "book.closed"
        }
    }
}

// MARK: - Card Configuration
/// Complete configuration for a quote card
struct QuoteCardConfiguration: Equatable {
    var template: QuoteCardTemplate = .minimal
    var format: QuoteCardFormat = .instagramPost
    var font: QuoteCardFont = .georgia
    var alignment: QuoteCardAlignment = .leading
    var colorScheme: QuoteCardColorScheme = .dark

    // Element visibility
    var showAuthor: Bool = true
    var showBookTitle: Bool = true
    var showPageNumber: Bool = false
    var showWatermark: Bool = true

    // Custom colors (optional overrides)
    var customBackgroundColor: Color?
    var customTextColor: Color?
    var customAccentColor: Color?

    // Custom size (for custom format)
    var customWidth: CGFloat = 1080
    var customHeight: CGFloat = 1080

    var effectiveSize: CGSize {
        if format == .custom {
            return CGSize(width: customWidth, height: customHeight)
        }
        return format.size
    }

    static let `default` = QuoteCardConfiguration()
}

// MARK: - Quote Card Data
/// Data needed to render a quote card
struct QuoteCardData {
    let text: String
    let author: String?
    let bookTitle: String?
    let pageNumber: Int?
    let bookCoverImage: UIImage?
    let bookPalette: ColorPalette?

    init(
        text: String,
        author: String? = nil,
        bookTitle: String? = nil,
        pageNumber: Int? = nil,
        bookCoverImage: UIImage? = nil,
        bookPalette: ColorPalette? = nil
    ) {
        self.text = text
        self.author = author
        self.bookTitle = bookTitle
        self.pageNumber = pageNumber
        self.bookCoverImage = bookCoverImage
        self.bookPalette = bookPalette
    }

    /// Create from a Quote model
    init(quote: Quote) {
        self.text = quote.text
        self.author = quote.book?.author
        self.bookTitle = quote.book?.title
        self.pageNumber = quote.pageNumber

        if let imageData = quote.book?.coverImageData {
            self.bookCoverImage = UIImage(data: imageData)
        } else {
            self.bookCoverImage = nil
        }

        self.bookPalette = nil // Will be extracted async if needed
    }
}

// MARK: - Export Result
enum QuoteCardExportResult {
    case success(UIImage)
    case failure(Error)
}

enum QuoteCardExportError: LocalizedError {
    case renderingFailed
    case saveFailed
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .renderingFailed: return "Failed to render quote card"
        case .saveFailed: return "Failed to save image"
        case .invalidConfiguration: return "Invalid card configuration"
        }
    }
}

// MARK: - Safe Array Access
private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
