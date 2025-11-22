import SwiftUI

// MARK: - Rich Text Editor
/// Markdown-aware text editor with formatting toolbar
/// Combines TrackedTextEditor with FormattingToolbar for seamless rich text editing

struct RichTextEditor: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var isFocused: Bool

    @StateObject private var cursorTracker = TextEditorCursorTracker()
    @Environment(\.dismiss) private var dismiss

    init(
        text: Binding<String>,
        placeholder: String = "Start writing...",
        isFocused: FocusState<Bool>.Binding
    ) {
        self._text = text
        self.placeholder = placeholder
        self._isFocused = isFocused
    }

    var body: some View {
        VStack(spacing: 0) {
            // Text editor area
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .allowsHitTesting(false)
                }

                // Custom tracked text editor
                TrackedTextEditor(
                    text: $text,
                    placeholder: placeholder,
                    font: UIFont.systemFont(ofSize: 16),
                    foregroundColor: UIColor.white,
                    tracker: cursorTracker
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                FormattingToolbar(
                    text: $text,
                    cursorTracker: cursorTracker,
                    onDismiss: {
                        isFocused = false
                    }
                )
            }
        }
    }
}

// MARK: - Simplified Rich Text Editor (No Cursor Tracking)
/// Fallback version using standard TextEditor with markdown toolbar
/// Use this if TrackedTextEditor has issues

struct SimpleRichTextEditor: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var isFocused: Bool

    @StateObject private var cursorTracker = TextEditorCursorTracker()

    var body: some View {
        VStack(spacing: 0) {
            // Standard TextEditor
            TextEditor(text: $text)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                // Simplified toolbar without precise cursor tracking
                HStack(spacing: 12) {
                    FormatButton(icon: MarkdownSyntax.bold.systemIcon, syntax: .bold) {
                        insertAtEnd(.bold)
                    }

                    FormatButton(icon: MarkdownSyntax.italic.systemIcon, syntax: .italic) {
                        insertAtEnd(.italic)
                    }

                    FormatButton(icon: MarkdownSyntax.highlight.systemIcon, syntax: .highlight) {
                        insertAtEnd(.highlight)
                    }

                    Divider()
                        .frame(height: 24)
                        .background(Color.white.opacity(0.1))

                    FormatButton(icon: MarkdownSyntax.blockquote.systemIcon, syntax: .blockquote) {
                        insertAtEnd(.blockquote)
                    }

                    FormatButton(icon: MarkdownSyntax.bulletList.systemIcon, syntax: .bulletList) {
                        insertAtEnd(.bulletList)
                    }

                    Spacer()

                    Button("Done") {
                        isFocused = false
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
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
        }
    }

    /// Insert markdown at end of text (fallback when cursor position unavailable)
    private func insertAtEnd(_ syntax: MarkdownSyntax) {
        let (prefix, suffix) = syntax.insertSyntax

        switch syntax {
        case .bold, .italic, .highlight:
            text += prefix + suffix
        case .blockquote, .bulletList, .numberedList, .header1, .header2:
            if !text.isEmpty && !text.hasSuffix("\n") {
                text += "\n"
            }
            text += prefix
        }
    }
}

// MARK: - Preview Provider
struct RichTextEditor_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var text = """
        # Sample Note

        This is a **bold** statement and this is *italic*.

        > A quote from the book

        - First point
        - Second point
        """
        @FocusState private var isFocused: Bool

        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    RichTextEditor(
                        text: $text,
                        placeholder: "Start writing...",
                        isFocused: $isFocused
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .background(DesignSystem.Colors.surfaceBackground)
                .navigationTitle("Edit Note")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    isFocused = true
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    static var previews: some View {
        PreviewContainer()
    }
}
