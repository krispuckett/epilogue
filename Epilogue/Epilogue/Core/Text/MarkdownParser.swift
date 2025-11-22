import SwiftUI

// MARK: - Markdown Parser for Notes
/// High-performance markdown parser for rich text notes
/// Supports: Bold, Italic, Highlight, Headers, Block quotes, Lists

enum MarkdownSyntax {
    case bold
    case italic
    case highlight
    case blockquote
    case bulletList
    case numberedList
    case header1
    case header2

    var insertSyntax: (prefix: String, suffix: String) {
        switch self {
        case .bold:
            return ("**", "**")
        case .italic:
            return ("*", "*")
        case .highlight:
            return ("==", "==")
        case .blockquote:
            return ("> ", "")
        case .bulletList:
            return ("- ", "")
        case .numberedList:
            return ("1. ", "")
        case .header1:
            return ("# ", "")
        case .header2:
            return ("## ", "")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .highlight: return "Highlight"
        case .blockquote: return "Block Quote"
        case .bulletList: return "Bullet List"
        case .numberedList: return "Numbered List"
        case .header1: return "Heading 1"
        case .header2: return "Heading 2"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .bold: return "Makes text bold"
        case .italic: return "Makes text italic"
        case .highlight: return "Highlights text"
        case .blockquote: return "Formats as a quote"
        case .bulletList: return "Creates a bullet point"
        case .numberedList: return "Creates a numbered list item"
        case .header1: return "Creates a large heading"
        case .header2: return "Creates a medium heading"
        }
    }
}

struct MarkdownParser {

    // MARK: - Parsing to AttributedString

    /// Parses markdown string into AttributedString for display
    /// - Parameters:
    ///   - markdown: Raw markdown text
    ///   - fontSize: Base font size (default: 16)
    ///   - lineSpacing: Line spacing (default: 6)
    /// - Returns: Fully styled AttributedString
    static func parse(
        _ markdown: String,
        fontSize: CGFloat = 16,
        lineSpacing: CGFloat = 6
    ) -> AttributedString {
        var result = AttributedString(markdown)

        // Apply base styling
        result.font = .system(size: fontSize)
        result.foregroundColor = Color(red: 0.98, green: 0.97, blue: 0.96)

        // Parse markdown patterns
        result = parseHeaders(result, baseFontSize: fontSize)
        result = parseBlockquotes(result, baseFontSize: fontSize)
        result = parseHighlights(result)
        result = parseBold(result, baseFontSize: fontSize)
        result = parseItalic(result, baseFontSize: fontSize)

        return result
    }

    // MARK: - Pattern Parsing

    /// Parse headers: # Header 1, ## Header 2
    private static func parseHeaders(_ attributed: AttributedString, baseFontSize: CGFloat) -> AttributedString {
        var result = attributed
        let text = String(result.characters)
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            // Header 1: # Text
            if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                let headerText = String(line.dropFirst(2))
                if let range = text.range(of: line),
                   let attrRange = Range(range, in: result) {
                    result.replaceSubrange(attrRange, with: AttributedString(headerText))

                    // Apply H1 styling
                    let updatedText = String(result.characters)
                    if let headerRange = updatedText.range(of: headerText),
                       let headerAttrRange = Range(headerRange, in: result) {
                        result[headerAttrRange].font = .system(size: baseFontSize + 8, weight: .bold)
                        result[headerAttrRange].foregroundColor = .white
                    }
                }
            }

            // Header 2: ## Text
            else if line.hasPrefix("## ") {
                let headerText = String(line.dropFirst(3))
                if let range = text.range(of: line),
                   let attrRange = Range(range, in: result) {
                    result.replaceSubrange(attrRange, with: AttributedString(headerText))

                    // Apply H2 styling
                    let updatedText = String(result.characters)
                    if let headerRange = updatedText.range(of: headerText),
                       let headerAttrRange = Range(headerRange, in: result) {
                        result[headerAttrRange].font = .system(size: baseFontSize + 4, weight: .semibold)
                        result[headerAttrRange].foregroundColor = Color.white.opacity(0.95)
                    }
                }
            }
        }

        return result
    }

    /// Parse blockquotes: > Quote text
    private static func parseBlockquotes(_ attributed: AttributedString, baseFontSize: CGFloat) -> AttributedString {
        var result = attributed
        let text = String(result.characters)
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("> ") {
                let quoteText = String(line.dropFirst(2))
                if let range = text.range(of: line),
                   let attrRange = Range(range, in: result) {
                    // Add left border indicator (using em dash)
                    let styledQuote = "│ \(quoteText)"
                    result.replaceSubrange(attrRange, with: AttributedString(styledQuote))

                    // Apply blockquote styling
                    let updatedText = String(result.characters)
                    if let quoteRange = updatedText.range(of: styledQuote),
                       let quoteAttrRange = Range(quoteRange, in: result) {
                        result[quoteAttrRange].font = .custom("Georgia", size: baseFontSize)
                        result[quoteAttrRange].foregroundColor = DesignSystem.Colors.primaryAccent.opacity(0.9)
                    }
                }
            }
        }

        return result
    }

    /// Parse highlights: ==highlighted text==
    private static func parseHighlights(_ attributed: AttributedString) -> AttributedString {
        var result = attributed
        let text = String(result.characters)
        var searchRange = text.startIndex..<text.endIndex

        while let startRange = text.range(of: "==", range: searchRange) {
            guard let endRange = text.range(of: "==", range: startRange.upperBound..<text.endIndex) else { break }

            let contentStart = startRange.upperBound
            let contentEnd = endRange.lowerBound
            let fullRange = startRange.lowerBound..<endRange.upperBound

            if contentStart < contentEnd {
                let content = String(text[contentStart..<contentEnd])

                if let attributedFullRange = Range(fullRange, in: result) {
                    result.replaceSubrange(attributedFullRange, with: AttributedString(content))

                    // Apply highlight styling
                    let updatedText = String(result.characters)
                    if let contentRange = updatedText.range(of: content),
                       let attributedContentRange = Range(contentRange, in: result) {
                        result[attributedContentRange].backgroundColor = DesignSystem.Colors.primaryAccent.opacity(0.25)
                        result[attributedContentRange].foregroundColor = .white
                    }
                }
            }

            searchRange = endRange.upperBound..<text.endIndex
        }

        return result
    }

    /// Parse bold: **bold** or __bold__
    private static func parseBold(_ attributed: AttributedString, baseFontSize: CGFloat) -> AttributedString {
        var result = attributed

        // Parse **bold**
        result = parseBoldPattern(result, pattern: "**", baseFontSize: baseFontSize)

        // Parse __bold__
        result = parseBoldPattern(result, pattern: "__", baseFontSize: baseFontSize)

        return result
    }

    private static func parseBoldPattern(_ attributed: AttributedString, pattern: String, baseFontSize: CGFloat) -> AttributedString {
        var result = attributed
        let text = String(result.characters)
        var searchRange = text.startIndex..<text.endIndex

        while let startRange = text.range(of: pattern, range: searchRange) {
            guard let endRange = text.range(of: pattern, range: startRange.upperBound..<text.endIndex) else { break }

            let contentStart = startRange.upperBound
            let contentEnd = endRange.lowerBound
            let fullRange = startRange.lowerBound..<endRange.upperBound

            if contentStart < contentEnd {
                let content = String(text[contentStart..<contentEnd])

                if let attributedFullRange = Range(fullRange, in: result) {
                    result.replaceSubrange(attributedFullRange, with: AttributedString(content))

                    // Apply bold styling
                    let updatedText = String(result.characters)
                    if let contentRange = updatedText.range(of: content),
                       let attributedContentRange = Range(contentRange, in: result) {
                        result[attributedContentRange].font = .system(size: baseFontSize, weight: .bold)
                    }
                }
            }

            searchRange = endRange.upperBound..<text.endIndex
        }

        return result
    }

    /// Parse italic: *italic* or _italic_
    private static func parseItalic(_ attributed: AttributedString, baseFontSize: CGFloat) -> AttributedString {
        var result = attributed

        // Parse *italic*
        result = parseItalicPattern(result, pattern: "*", baseFontSize: baseFontSize)

        // Parse _italic_
        result = parseItalicPattern(result, pattern: "_", baseFontSize: baseFontSize)

        return result
    }

    private static func parseItalicPattern(_ attributed: AttributedString, pattern: String, baseFontSize: CGFloat) -> AttributedString {
        var result = attributed
        let text = String(result.characters)
        var searchRange = text.startIndex..<text.endIndex

        while let startRange = text.range(of: pattern, range: searchRange) {
            // Skip if it's part of a bold pattern
            if pattern == "*" || pattern == "_" {
                let doublePattern = String(repeating: pattern, count: 2)
                if startRange.lowerBound > text.startIndex {
                    let prevIndex = text.index(before: startRange.lowerBound)
                    if text[prevIndex...].hasPrefix(doublePattern) {
                        searchRange = startRange.upperBound..<text.endIndex
                        continue
                    }
                }
            }

            guard let endRange = text.range(of: pattern, range: startRange.upperBound..<text.endIndex) else { break }

            let contentStart = startRange.upperBound
            let contentEnd = endRange.lowerBound
            let fullRange = startRange.lowerBound..<endRange.upperBound

            if contentStart < contentEnd {
                let content = String(text[contentStart..<contentEnd])

                if let attributedFullRange = Range(fullRange, in: result) {
                    result.replaceSubrange(attributedFullRange, with: AttributedString(content))

                    // Apply italic styling
                    let updatedText = String(result.characters)
                    if let contentRange = updatedText.range(of: content),
                       let attributedContentRange = Range(contentRange, in: result) {
                        result[attributedContentRange].font = .system(size: baseFontSize, weight: .regular).italic()
                    }
                }
            }

            searchRange = endRange.upperBound..<text.endIndex
        }

        return result
    }

    // MARK: - Markdown Insertion for Editing

    /// Inserts markdown syntax at cursor position or wraps selected text
    /// - Parameters:
    ///   - text: Current text content
    ///   - syntax: Markdown syntax to insert
    ///   - cursorPosition: Current cursor position
    ///   - selectedRange: Selected text range (optional)
    /// - Returns: Tuple of (new text, new cursor position)
    static func insertMarkdown(
        in text: String,
        syntax: MarkdownSyntax,
        cursorPosition: Int,
        selectedRange: NSRange?
    ) -> (text: String, cursorPosition: Int) {

        let (prefix, suffix) = syntax.insertSyntax

        // If text is selected, wrap it
        if let range = selectedRange, range.length > 0 {
            let nsString = text as NSString
            let selectedText = nsString.substring(with: range)

            // For line-based syntax (headers, blockquotes, lists), apply per line
            if isLineSyntax(syntax) {
                let lines = selectedText.components(separatedBy: .newlines)
                let wrappedLines = lines.map { prefix + $0 }
                let wrapped = wrappedLines.joined(separator: "\n")

                let beforeSelection = nsString.substring(to: range.location)
                let afterSelection = nsString.substring(from: range.location + range.length)
                let newText = beforeSelection + wrapped + afterSelection
                let newCursor = range.location + wrapped.count

                return (newText, newCursor)
            }
            // For inline syntax (bold, italic, highlight), wrap selection
            else {
                let wrapped = prefix + selectedText + suffix
                let beforeSelection = nsString.substring(to: range.location)
                let afterSelection = nsString.substring(from: range.location + range.length)
                let newText = beforeSelection + wrapped + afterSelection
                let newCursor = range.location + wrapped.count

                return (newText, newCursor)
            }
        }
        // No selection - insert at cursor
        else {
            let nsString = text as NSString
            let beforeCursor = nsString.substring(to: cursorPosition)
            let afterCursor = nsString.substring(from: cursorPosition)

            // For line syntax, insert on new line if not at start of line
            if isLineSyntax(syntax) {
                let needsNewline = !beforeCursor.isEmpty && !beforeCursor.hasSuffix("\n")
                let insertion = (needsNewline ? "\n" : "") + prefix
                let newText = beforeCursor + insertion + afterCursor
                let newCursor = cursorPosition + insertion.count

                return (newText, newCursor)
            }
            // For wrapping syntax, insert both markers and place cursor between
            else {
                let insertion = prefix + suffix
                let newText = beforeCursor + insertion + afterCursor
                let newCursor = cursorPosition + prefix.count

                return (newText, newCursor)
            }
        }
    }

    /// Determines if syntax is line-based (headers, blockquotes, lists)
    private static func isLineSyntax(_ syntax: MarkdownSyntax) -> Bool {
        switch syntax {
        case .header1, .header2, .blockquote, .bulletList, .numberedList:
            return true
        case .bold, .italic, .highlight:
            return false
        }
    }

    // MARK: - Accessibility

    /// Generates accessible description for markdown content
    /// - Parameter markdown: Raw markdown text
    /// - Returns: Plain text description for VoiceOver
    static func accessibleDescription(_ markdown: String) -> String {
        var result = markdown

        // Remove syntax markers and add spoken descriptions
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        result = result.replacingOccurrences(of: "_", with: "")
        result = result.replacingOccurrences(of: "==", with: "")
        result = result.replacingOccurrences(of: "> ", with: "quote: ")
        result = result.replacingOccurrences(of: "# ", with: "heading: ")
        result = result.replacingOccurrences(of: "## ", with: "subheading: ")
        result = result.replacingOccurrences(of: "- ", with: "")

        return result
    }
}
