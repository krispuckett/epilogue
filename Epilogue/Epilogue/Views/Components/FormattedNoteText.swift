import SwiftUI

// MARK: - Formatted Note Text Component
/// Renders markdown-formatted text for notes with Epilogue styling
/// Used in note cards, detail views, and previews

struct FormattedNoteText: View {
    let markdown: String
    let fontSize: CGFloat
    let lineSpacing: CGFloat

    init(
        markdown: String,
        fontSize: CGFloat = 16,
        lineSpacing: CGFloat = 6
    ) {
        self.markdown = markdown
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        Text(attributedString)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(MarkdownParser.accessibleDescription(markdown))
            .accessibilityValue("Formatted note")
    }

    private var attributedString: AttributedString {
        MarkdownParser.parse(
            markdown,
            fontSize: fontSize,
            lineSpacing: lineSpacing
        )
    }
}

// MARK: - Preview Provider
struct FormattedNoteText_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Bold and italic
                FormattedNoteText(
                    markdown: "This note has **bold text** and *italic text* for emphasis."
                )

                Divider()

                // Highlights
                FormattedNoteText(
                    markdown: "Key insight: ==Memory is not a recording but a reconstruction.=="
                )

                Divider()

                // Block quote
                FormattedNoteText(
                    markdown: "> In the middle of the journey of our life I found myself within a dark wood where the straight way was lost."
                )

                Divider()

                // Headers
                FormattedNoteText(
                    markdown: """
                    # Chapter 3 Notes

                    ## Key Themes

                    The protagonist faces their **greatest challenge** yet.
                    """
                )

                Divider()

                // Complex mixed content
                FormattedNoteText(
                    markdown: """
                    # The Odyssey - Book IX

                    ## The Cyclops Encounter

                    > Nobody has hurt me!

                    Odysseus shows **cunning** and *intelligence* by:

                    - Calling himself "Nobody"
                    - Blinding the cyclops
                    - Escaping under sheep

                    ==This reveals his resourcefulness as a hero.==
                    """
                )

                Divider()

                // Simple plain text (backward compatible)
                FormattedNoteText(
                    markdown: "This is just a plain text note without any formatting."
                )
            }
            .padding(24)
        }
        .background(DesignSystem.Colors.surfaceBackground)
        .preferredColorScheme(.dark)
    }
}
