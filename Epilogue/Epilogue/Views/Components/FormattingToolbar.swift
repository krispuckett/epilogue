import SwiftUI

// MARK: - Formatting Toolbar
/// Glass-effect keyboard toolbar for rich text formatting
/// Features minimal design with instant feedback - Raycast/Linear quality

struct FormattingToolbar: View {
    @Binding var text: String
    @ObservedObject var cursorTracker: TextEditorCursorTracker
    let onDismiss: () -> Void

    @State private var showingPreview = false

    var body: some View {
        HStack(spacing: 16) {
            // All formatting buttons in one clean row
            FormatButton(icon: MarkdownSyntax.bold.systemIcon, syntax: .bold) {
                insertMarkdown(.bold)
            }

            FormatButton(icon: MarkdownSyntax.italic.systemIcon, syntax: .italic) {
                insertMarkdown(.italic)
            }

            FormatButton(icon: MarkdownSyntax.highlight.systemIcon, syntax: .highlight) {
                insertMarkdown(.highlight)
            }

            FormatButton(icon: MarkdownSyntax.blockquote.systemIcon, syntax: .blockquote) {
                insertMarkdown(.blockquote)
            }

            FormatButton(icon: MarkdownSyntax.bulletList.systemIcon, syntax: .bulletList) {
                insertMarkdown(.bulletList)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(toolbarBackground)
    }

    @ViewBuilder
    private var toolbarBackground: some View {
        // iOS 26 Liquid Glass - Direct glass effect without .background()
        Rectangle()
            .fill(.clear)
            .glassEffect()
    }

    private func insertMarkdown(_ syntax: MarkdownSyntax) {
        print("📝 FormattingToolbar.insertMarkdown:")
        print("  - Current text: '\(text)'")
        print("  - Cursor position: \(cursorTracker.cursorPosition)")
        print("  - Selected range: \(cursorTracker.selectedRange?.description ?? "nil")")
        print("  - Syntax: \(syntax)")

        let result = MarkdownParser.insertMarkdown(
            in: text,
            syntax: syntax,
            cursorPosition: cursorTracker.cursorPosition,
            selectedRange: cursorTracker.selectedRange
        )

        print("  - New text: '\(result.text)'")
        print("  - New cursor: \(result.cursorPosition)")

        text = result.text
        cursorTracker.updateCursor(to: result.cursorPosition)

        print("  - Text after update: '\(text)'")
    }

    private func handleDone() {
        SensoryFeedback.light()
        onDismiss()
    }
}

// MARK: - Compact Formatting Toolbar (Alternative Design)
/// Even more minimal toolbar for constrained spaces
struct CompactFormattingToolbar: View {
    @Binding var text: String
    @ObservedObject var cursorTracker: TextEditorCursorTracker

    var body: some View {
        HStack(spacing: 8) {
            // Essential formatting only
            FormatButton(icon: MarkdownSyntax.bold.systemIcon, syntax: .bold) {
                insertMarkdown(.bold)
            }

            FormatButton(icon: MarkdownSyntax.italic.systemIcon, syntax: .italic) {
                insertMarkdown(.italic)
            }

            FormatButton(icon: MarkdownSyntax.blockquote.systemIcon, syntax: .blockquote) {
                insertMarkdown(.blockquote)
            }

            FormatButton(icon: MarkdownSyntax.bulletList.systemIcon, syntax: .bulletList) {
                insertMarkdown(.bulletList)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.clear)
                .glassEffect()
        )
    }

    private func insertMarkdown(_ syntax: MarkdownSyntax) {
        let result = MarkdownParser.insertMarkdown(
            in: text,
            syntax: syntax,
            cursorPosition: cursorTracker.cursorPosition,
            selectedRange: cursorTracker.selectedRange
        )

        text = result.text
        cursorTracker.updateCursor(to: result.cursorPosition)
    }
}

// MARK: - Preview Provider
struct FormattingToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()

            // Preview text area
            TextEditor(text: .constant("Sample note text"))
                .frame(height: 200)
                .padding()
                .background(DesignSystem.Colors.surfaceBackground)

            // Toolbar
            FormattingToolbar(
                text: .constant("Sample note text"),
                cursorTracker: TextEditorCursorTracker(),
                onDismiss: {}
            )
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
