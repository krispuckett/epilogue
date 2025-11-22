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
        HStack(spacing: 12) {
            // Primary formatting buttons
            HStack(spacing: 8) {
                FormatButton(icon: MarkdownSyntax.bold.systemIcon, syntax: .bold) {
                    insertMarkdown(.bold)
                }

                FormatButton(icon: MarkdownSyntax.italic.systemIcon, syntax: .italic) {
                    insertMarkdown(.italic)
                }

                FormatButton(icon: MarkdownSyntax.highlight.systemIcon, syntax: .highlight) {
                    insertMarkdown(.highlight)
                }
            }

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.1))

            // Structure formatting
            HStack(spacing: 8) {
                FormatButton(icon: MarkdownSyntax.blockquote.systemIcon, syntax: .blockquote) {
                    insertMarkdown(.blockquote)
                }

                FormatButton(icon: MarkdownSyntax.bulletList.systemIcon, syntax: .bulletList) {
                    insertMarkdown(.bulletList)
                }

                FormatButton(icon: MarkdownSyntax.numberedList.systemIcon, syntax: .numberedList) {
                    insertMarkdown(.numberedList)
                }
            }

            Spacer()

            // Done button
            Button(action: handleDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Done editing")
            .accessibilityHint("Dismisses the keyboard")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(toolbarBackground)
        .overlay(alignment: .top) {
            // Subtle top border gradient
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var toolbarBackground: some View {
        // iOS 26 Liquid Glass - NO .background() before .glassEffect()
        Rectangle()
            .fill(.clear)
            .background(.ultraThinMaterial)
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
        .background(.ultraThinMaterial)
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
