import SwiftUI

// MARK: - Highlighted Text
/// Displays text with search query matches highlighted

struct HighlightedText: View {
    let text: String
    let query: String
    var baseColor: Color = .white
    var highlightColor: Color = DesignSystem.Colors.primaryAccent
    var font: Font = .system(size: 15)

    var body: some View {
        if query.isEmpty {
            Text(text)
                .font(font)
                .foregroundStyle(baseColor)
        } else {
            highlightedContent
        }
    }

    @ViewBuilder
    private var highlightedContent: some View {
        let segments = splitTextByQuery()

        Text(segments.reduce(AttributedString()) { result, segment in
            var attributed = AttributedString(segment.text)

            if segment.isMatch {
                attributed.backgroundColor = highlightColor.opacity(0.3)
                attributed.foregroundColor = highlightColor
            } else {
                attributed.foregroundColor = Color(baseColor)
            }

            return result + attributed
        })
        .font(font)
    }

    // MARK: - Text Segmentation

    private struct TextSegment {
        let text: String
        let isMatch: Bool
    }

    private func splitTextByQuery() -> [TextSegment] {
        guard !query.isEmpty else {
            return [TextSegment(text: text, isMatch: false)]
        }

        var segments: [TextSegment] = []
        var remaining = text
        let lowercasedQuery = query.lowercased()

        while !remaining.isEmpty {
            if let range = remaining.range(of: lowercasedQuery, options: .caseInsensitive) {
                // Add non-matching prefix
                if range.lowerBound != remaining.startIndex {
                    let prefix = String(remaining[..<range.lowerBound])
                    segments.append(TextSegment(text: prefix, isMatch: false))
                }

                // Add matching portion (preserving original case)
                let match = String(remaining[range])
                segments.append(TextSegment(text: match, isMatch: true))

                // Continue with remainder
                remaining = String(remaining[range.upperBound...])
            } else {
                // No more matches, add remaining text
                segments.append(TextSegment(text: remaining, isMatch: false))
                break
            }
        }

        return segments
    }
}

// MARK: - Georgia Highlighted Text
/// Variant for quote cards using Georgia font

struct GeorgiaHighlightedText: View {
    let text: String
    let query: String
    var baseColor: Color = Color(red: 0.98, green: 0.97, blue: 0.96)
    var highlightColor: Color = DesignSystem.Colors.primaryAccent
    var fontSize: CGFloat = 18
    var lineSpacing: CGFloat = 6

    var body: some View {
        if query.isEmpty {
            Text(text)
                .font(.custom("Georgia", size: fontSize))
                .foregroundStyle(baseColor)
                .lineSpacing(lineSpacing)
        } else {
            highlightedContent
        }
    }

    @ViewBuilder
    private var highlightedContent: some View {
        let segments = splitTextByQuery()

        Text(segments.reduce(AttributedString()) { result, segment in
            var attributed = AttributedString(segment.text)
            attributed.font = .custom("Georgia", size: fontSize)

            if segment.isMatch {
                attributed.backgroundColor = highlightColor.opacity(0.25)
                attributed.foregroundColor = highlightColor
            } else {
                attributed.foregroundColor = Color(baseColor)
            }

            return result + attributed
        })
        .lineSpacing(lineSpacing)
    }

    private struct TextSegment {
        let text: String
        let isMatch: Bool
    }

    private func splitTextByQuery() -> [TextSegment] {
        guard !query.isEmpty else {
            return [TextSegment(text: text, isMatch: false)]
        }

        var segments: [TextSegment] = []
        var remaining = text
        let lowercasedQuery = query.lowercased()

        while !remaining.isEmpty {
            if let range = remaining.range(of: lowercasedQuery, options: .caseInsensitive) {
                if range.lowerBound != remaining.startIndex {
                    let prefix = String(remaining[..<range.lowerBound])
                    segments.append(TextSegment(text: prefix, isMatch: false))
                }

                let match = String(remaining[range])
                segments.append(TextSegment(text: match, isMatch: true))

                remaining = String(remaining[range.upperBound...])
            } else {
                segments.append(TextSegment(text: remaining, isMatch: false))
                break
            }
        }

        return segments
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Standard Text:")
                .font(.caption)
                .foregroundStyle(.gray)

            HighlightedText(
                text: "The quick brown fox jumps over the lazy dog",
                query: "fox"
            )
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Georgia Quote:")
                .font(.caption)
                .foregroundStyle(.gray)

            GeorgiaHighlightedText(
                text: "It is not the critic who counts; not the man who points out how the strong man stumbles.",
                query: "strong"
            )
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Multiple matches:")
                .font(.caption)
                .foregroundStyle(.gray)

            HighlightedText(
                text: "The the the - testing multiple 'the' matches",
                query: "the"
            )
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("No match:")
                .font(.caption)
                .foregroundStyle(.gray)

            HighlightedText(
                text: "This text has no matching query",
                query: "xyz"
            )
        }
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
