import SwiftUI

/// Formats Bible verse text with proper verse number styling
/// Handles patterns like "1 In the beginning..." or "¹In the beginning..."
struct BibleVerseFormatter {

    /// Creates an AttributedString with styled verse numbers
    /// - Parameters:
    ///   - text: The raw Bible text with verse numbers
    ///   - baseFontSize: The base font size for the text
    ///   - textColor: The primary text color
    /// - Returns: An AttributedString with formatted verse numbers
    static func format(
        _ text: String,
        baseFontSize: CGFloat = 18,
        textColor: Color = Color(red: 0.98, green: 0.97, blue: 0.96)
    ) -> AttributedString {
        var result = AttributedString()

        // Pattern to match verse numbers at start of lines or after newlines
        // Matches: "1 ", "12 ", "123 " (number followed by space)
        // Also matches superscript numbers: ¹²³⁴⁵⁶⁷⁸⁹⁰
        let versePattern = #"(?:^|\n)(\d{1,3})\s"#
        let superscriptPattern = #"[¹²³⁴⁵⁶⁷⁸⁹⁰]+"#

        // Split text into segments, preserving verse numbers
        var currentIndex = text.startIndex

        // Try regex-based parsing
        if let regex = try? NSRegularExpression(pattern: versePattern, options: []) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                // Add text before this match
                if let swiftRange = Range(NSRange(location: nsText.substring(to: match.range.location).count, length: 0), in: text) {
                    let beforeRange = currentIndex..<swiftRange.lowerBound
                    if beforeRange.lowerBound < beforeRange.upperBound {
                        var beforeText = AttributedString(String(text[beforeRange]))
                        beforeText.font = .custom("Georgia", size: baseFontSize)
                        beforeText.foregroundColor = textColor
                        result += beforeText
                    }
                }

                // Extract and style the verse number
                if match.numberOfRanges > 1,
                   let numberRange = Range(match.range(at: 1), in: text) {
                    let verseNumber = String(text[numberRange])

                    // Check if there's a newline before (not at start of text)
                    let matchStart = text.index(text.startIndex, offsetBy: match.range.location)
                    if matchStart > text.startIndex && text[matchStart] == "\n" {
                        var newline = AttributedString("\n")
                        result += newline
                    }

                    // Style verse number - smaller, lighter, superscript-like
                    var verseAttr = AttributedString(verseNumber)
                    verseAttr.font = .system(size: baseFontSize * 0.6, weight: .medium)
                    verseAttr.foregroundColor = textColor.opacity(0.5)
                    verseAttr.baselineOffset = baseFontSize * 0.3  // Superscript effect
                    result += verseAttr

                    // Add a thin space after
                    var space = AttributedString(" ")
                    space.font = .custom("Georgia", size: baseFontSize * 0.5)
                    result += space
                }

                // Update current index
                if let endRange = Range(NSRange(location: match.range.location + match.range.length, length: 0), in: text) {
                    currentIndex = endRange.lowerBound
                }
            }
        }

        // Add remaining text
        if currentIndex < text.endIndex {
            var remainingText = AttributedString(String(text[currentIndex...]))
            remainingText.font = .custom("Georgia", size: baseFontSize)
            remainingText.foregroundColor = textColor
            result += remainingText
        }

        // If no verse numbers found, return simple styled text
        if result.characters.isEmpty {
            var simpleText = AttributedString(text)
            simpleText.font = .custom("Georgia", size: baseFontSize)
            simpleText.foregroundColor = textColor
            return simpleText
        }

        return result
    }

    /// Simpler formatter that just styles inline verse numbers without complex parsing
    static func formatSimple(
        _ text: String,
        baseFontSize: CGFloat = 18,
        textColor: Color = Color(red: 0.98, green: 0.97, blue: 0.96)
    ) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.font = .custom("Georgia", size: baseFontSize)
        attributed.foregroundColor = textColor

        // Find and style verse numbers (digits at start or after newline followed by space)
        let pattern = #"(?:^|\n)(\d{1,3}) "#

        if let regex = try? Regex(pattern) {
            for match in text.matches(of: regex) {
                if let range = Range(match.range, in: attributed) {
                    // Style the verse number portion smaller
                    attributed[range].font = .system(size: baseFontSize * 0.65, weight: .semibold, design: .rounded)
                    attributed[range].foregroundColor = textColor.opacity(0.4)
                }
            }
        }

        return attributed
    }
}

// MARK: - SwiftUI View for Bible Text

struct BibleVerseText: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let lineSpacing: CGFloat

    init(
        _ text: String,
        fontSize: CGFloat = 18,
        textColor: Color = Color(red: 0.98, green: 0.97, blue: 0.96),
        lineSpacing: CGFloat = 8
    ) {
        self.text = text
        self.fontSize = fontSize
        self.textColor = textColor
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        Text(formattedText)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var formattedText: AttributedString {
        // Use the simple formatter for better compatibility
        var attributed = AttributedString(text)
        attributed.font = .custom("Georgia", size: fontSize)
        attributed.foregroundColor = textColor

        // Style verse numbers inline
        // Pattern: number at start of string or after newline, followed by space
        let nsText = text as NSString
        let pattern = #"(?:^|\n)(\d{1,3})\s"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attributed
        }

        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        // Process matches in reverse to preserve ranges
        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let numberNSRange = match.range(at: 1)

            // Convert to AttributedString range
            if let lowerBound = AttributedString.Index(String.Index(utf16Offset: numberNSRange.location, in: text), within: attributed),
               let upperBound = AttributedString.Index(String.Index(utf16Offset: numberNSRange.location + numberNSRange.length, in: text), within: attributed) {
                let range = lowerBound..<upperBound

                // Style verse number
                attributed[range].font = .system(size: fontSize * 0.55, weight: .bold, design: .rounded)
                attributed[range].foregroundColor = textColor.opacity(0.35)
                attributed[range].baselineOffset = fontSize * 0.35
            }
        }

        return attributed
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        // Sample Bible text
        BibleVerseText(
            "1 In the beginning God created the heavens and the earth. 2 Now the earth was formless and empty, darkness was over the surface of the deep, and the Spirit of God was hovering over the waters. 3 And God said, \"Let there be light,\" and there was light.",
            fontSize: 18
        )

        Divider()

        // John 3:16
        BibleVerseText(
            "16 For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life. 17 For God did not send his Son into the world to condemn the world, but to save the world through him.",
            fontSize: 18
        )
    }
    .padding(24)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
